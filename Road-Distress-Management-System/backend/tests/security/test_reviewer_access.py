"""
App-store reviewer access: one non-admin account that signs in with a fixed 6-digit code.
"""

import pytest

from app.core.config import Settings, settings
from app.core.roles import Role
from app.core.startup_checks import collect_config_errors, reviewer_config_errors, weak_reviewer_code_reason
from app.db.bootstrap import REVIEWER_DEMO_PROJECT_NAME, bootstrap_reviewer
from app.models.auth import OtpCode
from app.models.project import Project, ProjectMember
from app.models.user import User
from app.services import otp_service
from tests.security.conftest import unique_email

REVIEWER_CODE = "483920"


@pytest.fixture()
def reviewer(monkeypatch, db):
    email = unique_email("reviewer")
    monkeypatch.setattr(settings, "REVIEWER_EMAIL", email)
    monkeypatch.setattr(settings, "REVIEWER_CODE", REVIEWER_CODE)
    bootstrap_reviewer(db)
    return email


def _verify(client, email, code):
    return client.post("/api/v1/auth/verify-otp", json={"email": email, "code": code})


def test_disabled_by_default(client, db, make_user):
    _uid, email, _h = make_user("employee")
    assert not settings.reviewer_access_enabled
    assert _verify(client, email, REVIEWER_CODE).status_code == 401


def test_reviewer_signs_in_with_the_fixed_code_as_a_non_admin(client, reviewer):
    r = _verify(client, reviewer, REVIEWER_CODE)
    assert r.status_code == 200
    body = r.json()
    assert body["user"]["role"] == Role.EMPLOYEE
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {body['token']}"})
    assert me.status_code == 200 and me.json()["email"] == reviewer


def test_reviewer_sees_only_the_demo_project(client, db, reviewer):
    token = _verify(client, reviewer, REVIEWER_CODE).json()["token"]
    projects = client.get("/api/v1/projects/", headers={"Authorization": f"Bearer {token}"}).json()
    assert [p["name"] for p in projects] == [REVIEWER_DEMO_PROJECT_NAME]


def test_bootstrap_is_idempotent(db, reviewer):
    bootstrap_reviewer(db)
    bootstrap_reviewer(db)
    assert db.query(Project).filter(Project.name == REVIEWER_DEMO_PROJECT_NAME).count() == 1
    user = db.query(User).filter(User.email == reviewer).one()
    assert db.query(ProjectMember).filter(ProjectMember.user_id == user.id).count() == 1


def test_wrong_code_is_rejected_and_locks_after_repeated_failures(client, reviewer):
    for _ in range(otp_service.OTP_MAX_FAILED_ATTEMPTS):
        assert _verify(client, reviewer, "000001").status_code == 401
    # locked: even the right code is now refused (same answer as a wrong code)
    assert _verify(client, reviewer, REVIEWER_CODE).status_code == 401


def test_the_fixed_code_works_for_no_other_account(client, reviewer, make_user):
    _uid, other_email, _h = make_user("employee")
    assert _verify(client, other_email, REVIEWER_CODE).status_code == 401


def test_the_fixed_code_never_opens_an_administrator_account(client, db, monkeypatch):
    email = unique_email("adminrev")
    db.add(User(email=email, full_name="Admin", hashed_password="!", role=Role.ADMIN))
    db.commit()
    monkeypatch.setattr(settings, "REVIEWER_EMAIL", email)
    monkeypatch.setattr(settings, "REVIEWER_CODE", REVIEWER_CODE)
    bootstrap_reviewer(db)  # refuses to touch the admin
    assert _verify(client, email, REVIEWER_CODE).status_code == 401
    # the admin still receives a normal code in dev mode
    r = client.post("/api/v1/auth/request-otp", json={"email": email})
    assert r.json()["dev_otp"] is not None


def test_no_code_is_issued_for_the_reviewer_address(client, db, reviewer):
    r = client.post("/api/v1/auth/request-otp", json={"email": reviewer})
    assert r.status_code == 200 and r.json() == {"sent": True, "dev_otp": None}
    assert db.query(OtpCode).filter(OtpCode.email == reviewer).count() == 0


def test_deleting_the_reviewer_account_works_like_any_other(client, db, reviewer):
    token = _verify(client, reviewer, REVIEWER_CODE).json()["token"]
    r = client.post("/api/v1/auth/delete-account", json={"confirm_email": reviewer},
                    headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 204
    assert _verify(client, reviewer, REVIEWER_CODE).status_code == 401  # account gone until the next restart re-creates it


# ----------------------------------------------------------------- startup validation
@pytest.mark.parametrize("code", ["12345", "1234567", "abcdef", "111111", "123456", "000000", "121212", ""])
def test_weak_or_malformed_codes_are_rejected(code):
    assert weak_reviewer_code_reason(code)


def test_a_good_code_passes():
    assert weak_reviewer_code_reason(REVIEWER_CODE) == ""


def _cfg(**kw):
    return Settings(_env_file=None, **kw)


def test_both_variables_must_be_set_together():
    assert reviewer_config_errors(_cfg(REVIEWER_EMAIL="r@example.test"))
    assert reviewer_config_errors(_cfg(REVIEWER_CODE=REVIEWER_CODE))
    assert reviewer_config_errors(_cfg()) == []


def test_reviewer_address_may_not_be_the_bootstrap_admin():
    cfg = _cfg(REVIEWER_EMAIL="Boss@Example.test", REVIEWER_CODE=REVIEWER_CODE, BOOTSTRAP_ADMIN_EMAIL="boss@example.test")
    assert any("administrator address" in e for e in reviewer_config_errors(cfg))


def test_production_refuses_to_start_with_a_bad_reviewer_setup():
    cfg = _cfg(
        APP_ENV="production", SMTP_HOST="smtp.example.test", SMTP_FROM="x@example.test",
        DOWNLOAD_SIGNING_SECRET="aB3dE5fG7hJ9kL1mN3pQ5rS7tU9vW1xY3zA5", REVIEWER_EMAIL="r@example.test", REVIEWER_CODE="111111",
    )
    assert any("REVIEWER_CODE" in e for e in collect_config_errors(cfg))
