"""
OTP hardening: production mode never exposes the code, lockout, single use, invalidation of
older codes, uniform responses, normalised e-mails, nothing sensitive in the logs.
"""

import logging
from concurrent.futures import ThreadPoolExecutor

import pytest

from app.core.config import settings
from app.db.session import SessionLocal
from app.models.auth import OtpCode
from app.services import email_sender, otp_service
from tests.security.conftest import unique_email


@pytest.fixture()
def mailbox(monkeypatch):
    """Production-like settings with a fake mail transport that records every message."""
    sent = []
    monkeypatch.setattr(settings, "APP_ENV", "production")
    monkeypatch.setattr(settings, "SMTP_HOST", "smtp.invalid")
    monkeypatch.setattr(settings, "SMTP_FROM", "noreply@example.test")

    def fake_send(to_email, subject, body):
        sent.append({"to": to_email, "subject": subject, "body": body})
        return True

    monkeypatch.setattr(email_sender, "send_email", fake_send)
    return sent


def last_code(mailbox_msgs, to):
    msgs = [m for m in mailbox_msgs if m["to"] == to]
    assert msgs, f"no e-mail delivered to {to}"
    return next(tok for tok in msgs[-1]["body"].split() if tok.isdigit() and len(tok) == 6)


def request(client, email):
    return client.post("/api/v1/auth/request-otp", json={"email": email})


def verify(client, email, code):
    return client.post("/api/v1/auth/verify-otp", json={"email": email, "code": code})


# ----------------------------------------------------------------------------- development mode
def test_dev_mode_still_returns_the_code_for_known_accounts(client, make_user):
    _, email, _ = make_user()
    r = request(client, email)
    assert r.status_code == 200 and r.json()["sent"] is True
    code = r.json()["dev_otp"]
    assert code and len(code) == 6 and code.isdigit()
    login = verify(client, email, code)
    assert login.status_code == 200 and login.json()["user"]["email"] == email
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {login.json()['token']}"}).status_code == 200


def test_dev_mode_unknown_email_gets_null_code_same_shape(client):
    r = request(client, unique_email("ghost"))
    assert r.status_code == 200 and r.json() == {"sent": True, "dev_otp": None}


def test_missing_dev_otp_is_a_valid_response_shape_for_the_app(client, make_user, mailbox):
    _, email, _ = make_user()
    body = request(client, email).json()
    assert set(body) == {"sent", "dev_otp"} and body["dev_otp"] is None  # the login screen handles null


# ----------------------------------------------------------------------------- production mode
def test_production_never_returns_or_logs_the_code(client, make_user, mailbox, caplog):
    _, email, _ = make_user()
    with caplog.at_level(logging.DEBUG):
        r = request(client, email)
    assert r.status_code == 200
    assert r.json() == {"sent": True, "dev_otp": None}
    code = last_code(mailbox, email)
    assert code not in r.text
    assert code not in caplog.text, "the OTP must never be written to the log"
    assert verify(client, email, code).status_code == 200


def test_production_ignores_otp_dev_mode_env_flag(client, make_user, mailbox, monkeypatch):
    monkeypatch.setattr(settings, "OTP_DEV_MODE", "true")
    _, email, _ = make_user()
    assert request(client, email).json()["dev_otp"] is None


def test_known_and_unknown_emails_are_indistinguishable_in_production(client, make_user, mailbox):
    _, known, _ = make_user()
    a = request(client, known)
    b = request(client, unique_email("ghost"))
    assert a.status_code == b.status_code == 200
    assert a.json() == b.json() == {"sent": True, "dev_otp": None}
    assert dict(a.headers).keys() >= {"content-type"} and a.headers["content-type"] == b.headers["content-type"]
    # failed verification looks the same too
    bad_known = verify(client, known, "000000")
    bad_unknown = verify(client, unique_email("ghost2"), "000000")
    assert bad_known.status_code == bad_unknown.status_code == 401
    assert bad_known.json() == bad_unknown.json()


def test_unknown_email_sends_no_mail(client, mailbox):
    request(client, unique_email("ghost"))
    assert mailbox == []


# ----------------------------------------------------------------------------- code lifecycle
def test_new_request_invalidates_the_previous_code(client, make_user, mailbox):
    _, email, _ = make_user()
    request(client, email)
    first = last_code(mailbox, email)
    request(client, email)
    second = last_code(mailbox, email)
    if first != second:  # 1-in-a-million collision would make the assertion meaningless
        assert verify(client, email, first).status_code == 401
    assert verify(client, email, second).status_code == 200


def test_code_is_single_use(client, make_user, mailbox):
    _, email, _ = make_user()
    request(client, email)
    code = last_code(mailbox, email)
    assert verify(client, email, code).status_code == 200
    assert verify(client, email, code).status_code == 401


def test_expired_code_is_rejected(client, make_user, mailbox, db):
    from datetime import datetime, timedelta, timezone
    _, email, _ = make_user()
    request(client, email)
    code = last_code(mailbox, email)
    db.query(OtpCode).filter(OtpCode.email == email).update({"expires_at": datetime.now(timezone.utc) - timedelta(minutes=1)})
    db.commit()
    assert verify(client, email, code).status_code == 401


def test_lockout_after_too_many_wrong_codes_even_for_the_right_code(client, make_user, mailbox):
    _, email, _ = make_user()
    request(client, email)
    good = last_code(mailbox, email)
    wrong = "000000" if good != "000000" else "111111"
    statuses = [verify(client, email, wrong).status_code for _ in range(otp_service.OTP_MAX_FAILED_ATTEMPTS)]
    assert statuses == [401] * otp_service.OTP_MAX_FAILED_ATTEMPTS
    assert otp_service.email_lockout.is_locked(email)
    # the correct code is refused while locked - with the SAME 401 body as any wrong code
    # (a distinct status would reveal that the address has an account)
    locked = verify(client, email, good)
    ordinary = verify(client, unique_email("ghost"), "123456")
    assert locked.status_code == ordinary.status_code == 401
    assert locked.json() == ordinary.json()
    # requesting a fresh code does not lift the lock (no reset-by-request trick)
    request(client, email)
    assert len([m for m in mailbox if m["to"] == email]) == 1
    assert verify(client, email, good).status_code == 401


def test_unknown_emails_create_no_per_email_state_and_look_identical(client, make_user, mailbox):
    ghost_statuses = {verify(client, unique_email("ghost"), "123456").status_code
                      for _ in range(otp_service.OTP_MAX_FAILED_ATTEMPTS + 3)}
    assert ghost_statuses == {401}
    assert otp_service.email_lockout.size() == 0, "failures for non-existent accounts must not be tracked per e-mail"
    bodies = {verify(client, unique_email("ghost"), "123456").text for _ in range(3)}
    assert len(bodies) == 1


def test_per_ip_throttling_still_covers_unknown_emails(client):
    otp_service.ip_lockout.max_failures = 4
    try:
        statuses = [verify(client, unique_email("g"), "123456").status_code for _ in range(6)]
    finally:
        otp_service.ip_lockout.max_failures = otp_service.OTP_IP_MAX_FAILED_ATTEMPTS
    assert statuses == [401, 401, 401, 401, 429, 429]


def test_request_otp_is_throttled_per_email_and_per_ip(client, make_user, mailbox):
    _, email, _ = make_user()
    for _ in range(otp_service.OTP_REQUESTS_PER_EMAIL + 3):
        assert request(client, email).status_code == 200
    assert len([m for m in mailbox if m["to"] == email]) == otp_service.OTP_REQUESTS_PER_EMAIL

    otp_service.reset_abuse_counters()
    otp_service.ip_request_limiter.limit = 3
    try:
        results = [request(client, unique_email("ip")).status_code for _ in range(5)]
    finally:
        otp_service.ip_request_limiter.limit = otp_service.OTP_REQUESTS_PER_IP
    assert results == [200, 200, 200, 429, 429]


def test_ip_lockout_after_many_failures(client):
    otp_service.ip_lockout.max_failures = 4
    try:
        statuses = [verify(client, unique_email("g"), "123456").status_code for _ in range(6)]
    finally:
        otp_service.ip_lockout.max_failures = otp_service.OTP_IP_MAX_FAILED_ATTEMPTS
    assert statuses[:4] == [401] * 4
    assert statuses[4:] == [429, 429]


def test_emails_are_normalised_everywhere(client, make_user, mailbox):
    _, email, _ = make_user()
    messy = f"  {email.upper()} "
    assert request(client, messy).status_code == 200
    code = last_code(mailbox, email)
    r = verify(client, messy.upper(), f" {code} ")
    assert r.status_code == 200 and r.json()["user"]["email"] == email


def test_codes_come_from_a_csprng_and_are_zero_padded(monkeypatch):
    seen = []
    monkeypatch.setattr(otp_service.secrets, "randbelow", lambda n: (seen.append(n), 42)[1])
    assert otp_service._generate_code() == "000042"
    assert seen == [10 ** 6]


def test_otp_can_only_be_consumed_once_under_concurrency(make_user, mailbox):
    _, email, _ = make_user()
    session = SessionLocal()
    try:
        code = otp_service.create_otp(session, email)
    finally:
        session.close()

    def attempt(_):
        s = SessionLocal()
        try:
            return otp_service.verify_otp(s, email, code)
        except Exception:
            return False
        finally:
            s.close()

    with ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(attempt, range(6)))
    assert results.count(True) == 1


def test_wrong_code_length_and_garbage_are_rejected(client, make_user, mailbox):
    _, email, _ = make_user()
    request(client, email)
    for junk in ("", "1", "abcdef", "1234567", " ", "123 456"):
        assert verify(client, email, junk).status_code in (401, 422, 429)
    assert verify(client, email, "x" * 100).status_code == 422  # over the schema limit


def test_no_otp_in_logs_in_dev_mode_either(client, make_user, caplog):
    _, email, _ = make_user()
    with caplog.at_level(logging.DEBUG):
        code = request(client, email).json()["dev_otp"]
    assert code and code not in caplog.text


def test_unconfigured_smtp_outside_dev_mode_does_not_crash_or_leak(client, make_user, monkeypatch, caplog):
    monkeypatch.setattr(settings, "OTP_DEV_MODE", "false")  # dev environment, but dev OTP explicitly off
    _, email, _ = make_user()
    r = request(client, email)
    assert r.status_code == 200 and r.json() == {"sent": True, "dev_otp": None}
