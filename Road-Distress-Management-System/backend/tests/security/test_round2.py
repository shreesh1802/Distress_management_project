"""
Round-2 hardening: admin-only registration, proxy-aware client IPs, fail-closed APP_ENV, platform markers,
bounded rate-limit memory, login timing equalisation, fatal production start-up, CORS 'null', weak secrets,
trimmed /health.
"""

import logging
import os
import types

import pytest

from app.core import rate_limit, security
from app.core.config import Settings, settings
from app.core.rate_limit import FailureLockout, SlidingWindowLimiter, client_ip
from app.core.startup_checks import collect_config_errors, collect_config_warnings, validate_runtime_config
from app.models.user import User
from tests.security.conftest import unique_email
from tests.security.route_inventory import inventory, concrete_path

GOOD_SECRET = "Kq7vZ3mT9xW2bN8cR5yH1jL4pD6sF0aGuE!"
PROD = dict(APP_ENV="production", SMTP_HOST="smtp.example.test", SMTP_FROM="noreply@example.test",
            DOWNLOAD_SIGNING_SECRET=GOOD_SECRET, BACKEND_CORS_ORIGINS="https://app.example.test")


def cfg(**kw) -> Settings:
    return Settings(_env_file=None, **kw)


def register(client, headers=None, **extra):
    body = {"email": unique_email("reg"), "password": "S3cure-pass!", **extra}
    return client.post("/api/v1/auth/register", json=body, headers=headers or {})


# =============================================================== ISSUE 1: registration
def test_registration_is_open_by_default_only_in_development(client):
    assert settings.allow_self_registration is True
    assert register(client).status_code == 201


@pytest.mark.parametrize("env", ["production", "prod", "staging", "live", "whatever"])
def test_anonymous_registration_is_refused_outside_development(client, monkeypatch, env, db):
    monkeypatch.setattr(settings, "APP_ENV", env)
    assert settings.allow_self_registration is False
    email = unique_email("anon")
    r = client.post("/api/v1/auth/register", json={"email": email, "password": "S3cure-pass!"})
    assert r.status_code == 401
    assert db.query(User).filter(User.email == email).count() == 0


def test_non_admin_cannot_register_accounts(client, monkeypatch, make_user):
    monkeypatch.setattr(settings, "APP_ENV", "production")
    _, _, headers = make_user("inspector")
    assert register(client, headers).status_code == 403
    _, _, emp = make_user("employee")
    assert register(client, emp).status_code == 403


def test_admin_can_register_accounts_and_they_are_only_inspectors(client, monkeypatch, admin, db):
    monkeypatch.setattr(settings, "APP_ENV", "production")
    _, _, headers = admin
    for requested in (None, "admin", "maintenance"):
        extra = {} if requested is None else {"role": requested}
        r = register(client, headers, **extra)
        assert r.status_code == 201, r.text
        assert r.json()["role"] == "inspector"  # registration never yields an admin, even when an admin calls it
    # admin-created accounts with other roles go through the admin-only users router
    r = client.post("/api/v1/users/", headers=headers,
                    json={"email": unique_email("m"), "password": "S3cure-pass!", "role": "maintenance"})
    assert r.status_code == 201 and r.json()["role"] == "maintenance"


def test_registration_flag_is_respected_both_ways(client, monkeypatch):
    monkeypatch.setattr(settings, "APP_ENV", "production")
    monkeypatch.setattr(settings, "ALLOW_SELF_REGISTRATION", "true")
    assert register(client).status_code == 201          # owner deliberately opened it
    monkeypatch.setattr(settings, "APP_ENV", "development")
    monkeypatch.setattr(settings, "ALLOW_SELF_REGISTRATION", "false")
    assert register(client).status_code == 401          # owner closed it even in development
    monkeypatch.setattr(settings, "ALLOW_SELF_REGISTRATION", "no")
    assert register(client).status_code == 401


def test_expired_or_invalid_session_cannot_register(client, monkeypatch):
    monkeypatch.setattr(settings, "APP_ENV", "production")
    assert register(client, {"Authorization": "Bearer " + "0" * 64}).status_code == 401


def test_every_route_rejects_anonymous_callers_in_locked_down_mode(client, monkeypatch):
    """Same matrix as test_route_auth, but with self-registration off: the ONLY anonymous POSTs left
    are the login steps; /auth/register is no longer public."""
    from app.main import app
    from tests.security.test_route_auth import PUBLIC_ROUTES, DEV_ONLY_PUBLIC
    monkeypatch.setattr(settings, "ALLOW_SELF_REGISTRATION", "false")
    still_public = set(PUBLIC_ROUTES) - {("POST", "/api/v1/auth/register")}
    offenders = []
    for kind, method, path in sorted(inventory(app)):
        if kind != "http" or (method, path) in still_public or (method, path) in DEV_ONLY_PUBLIC:
            continue
        r = client.request(method, concrete_path(path))
        if r.status_code != 401:
            offenders.append((method, path, r.status_code))
    assert not offenders, offenders


def test_production_warns_when_self_registration_is_enabled():
    warnings = collect_config_warnings(cfg(**PROD, ALLOW_SELF_REGISTRATION="true"))
    assert any("ALLOW_SELF_REGISTRATION" in w for w in warnings)
    assert not any("ALLOW_SELF_REGISTRATION" in w for w in collect_config_warnings(cfg(**PROD)))


# =============================================================== ISSUE 2: client IP behind proxies
def fake_request(peer="10.0.0.1", xff=None):
    headers = {} if xff is None else {"x-forwarded-for": xff}
    return types.SimpleNamespace(client=types.SimpleNamespace(host=peer), headers=headers)


def test_client_ip_without_trusted_proxies_ignores_forwarded_headers(monkeypatch):
    monkeypatch.setattr(settings, "TRUSTED_PROXY_COUNT", 0)
    assert client_ip(fake_request("10.0.0.1", "1.2.3.4")) == "10.0.0.1"
    assert client_ip(fake_request("10.0.0.1")) == "10.0.0.1"


@pytest.mark.parametrize(
    "trusted, xff, expected",
    [
        (1, "203.0.113.9", "203.0.113.9"),
        (1, "6.6.6.6, 203.0.113.9", "203.0.113.9"),                   # spoofed leftmost entry is ignored
        (1, "6.6.6.6, 7.7.7.7, 203.0.113.9", "203.0.113.9"),
        (2, "6.6.6.6, 203.0.113.9, 198.51.100.2", "203.0.113.9"),     # two proxies: second from the right
        (2, "203.0.113.9, 198.51.100.2", "203.0.113.9"),
        (1, " 203.0.113.9 ,  ", "203.0.113.9"),                       # whitespace / trailing comma
        (2, "203.0.113.9", "10.0.0.1"),                               # fewer hops than trusted proxies -> TCP peer
        (1, "", "10.0.0.1"),
    ],
)
def test_client_ip_uses_the_right_hand_entry_not_the_spoofable_left(monkeypatch, trusted, xff, expected):
    monkeypatch.setattr(settings, "TRUSTED_PROXY_COUNT", trusted)
    assert client_ip(fake_request("10.0.0.1", xff)) == expected


def test_client_ip_never_raises():
    assert client_ip(object()) == "unknown"
    assert client_ip(types.SimpleNamespace(client=None, headers={})) == "unknown"


def test_spoofed_header_cannot_dodge_the_per_ip_limit(client, monkeypatch):
    from app.services import otp_service
    monkeypatch.setattr(settings, "TRUSTED_PROXY_COUNT", 1)
    otp_service.ip_request_limiter.limit = 3
    try:
        # the attacker rotates the LEFT (client supplied) part; the proxy-appended right part is constant
        codes = [client.post("/api/v1/auth/request-otp", json={"email": unique_email("x")},
                             headers={"X-Forwarded-For": f"9.9.9.{i}, 203.0.113.50"}).status_code for i in range(5)]
    finally:
        otp_service.ip_request_limiter.limit = otp_service.OTP_REQUESTS_PER_IP
    assert codes == [200, 200, 200, 429, 429]


def test_production_logs_a_loud_warning_when_forwarded_headers_appear_with_zero_proxies(monkeypatch, caplog):
    rate_limit.reset_xff_warning()
    monkeypatch.setattr(settings, "APP_ENV", "production")
    monkeypatch.setattr(settings, "TRUSTED_PROXY_COUNT", 0)
    with caplog.at_level(logging.WARNING):
        client_ip(fake_request(xff="1.2.3.4"))
        client_ip(fake_request(xff="1.2.3.5"))
    records = [r for r in caplog.records if "TRUSTED_PROXY_COUNT" in r.getMessage()]
    assert len(records) == 1 and records[0].levelno == logging.CRITICAL  # once, not per request
    rate_limit.reset_xff_warning()


def test_no_warning_in_development_or_when_configured(monkeypatch, caplog):
    rate_limit.reset_xff_warning()
    with caplog.at_level(logging.WARNING):
        client_ip(fake_request(xff="1.2.3.4"))                      # development, 0 proxies
        monkeypatch.setattr(settings, "APP_ENV", "production")
        monkeypatch.setattr(settings, "TRUSTED_PROXY_COUNT", 1)
        client_ip(fake_request(xff="1.2.3.4"))                      # production, configured
    assert not [r for r in caplog.records if "TRUSTED_PROXY_COUNT" in r.getMessage()]


def test_startup_check_output_warns_about_zero_trusted_proxies_in_production():
    assert any("TRUSTED_PROXY_COUNT is 0" in w for w in collect_config_warnings(cfg(**PROD)))
    assert not any("TRUSTED_PROXY_COUNT" in w for w in collect_config_warnings(cfg(**PROD, TRUSTED_PROXY_COUNT=1)))
    returned = validate_runtime_config(cfg(**PROD))
    assert any("TRUSTED_PROXY_COUNT" in w for w in returned)


def test_docker_compose_sets_trusted_proxy_count_for_the_backend():
    compose = os.path.join(os.path.dirname(__file__), "..", "..", "..", "docker-compose.yml")
    text = open(compose, encoding="utf-8").read()
    backend = text.split("backend:", 1)[1].split("nginx:", 1)[0]
    assert 'TRUSTED_PROXY_COUNT: "1"' in backend


# =============================================================== ISSUE 3: fail-closed APP_ENV
@pytest.mark.parametrize(
    "value, production_like",
    [
        ("production", True), ("Production", True), (" production ", True), ("PROD", True), ("prod", True),
        ("prd", True), ("staging", True), ("live", True), ("stage", True), ("productio", True), ("1", True),
        ("", False), ("   ", False), ("dev", False), ("DEV", False), ("development", False),
        (" Development ", False), ("local", False), ("test", False),
    ],
)
def test_app_env_values(value, production_like):
    c = cfg(APP_ENV=value)
    assert c.is_production is production_like
    assert c.is_development is (not production_like)
    if production_like:
        assert c.otp_dev_mode is False and c.seed_demo_data is False and c.allow_mock_model is False
        assert c.cors_origins == [] and c.allow_self_registration is False
        assert collect_config_errors(c), "production-like environments must demand a full configuration"
    else:
        assert c.otp_dev_mode is True and c.seed_demo_data is True and c.allow_mock_model is True
        assert c.cors_origins == ["*"] and c.allow_self_registration is True
        assert collect_config_errors(c) == []


def test_unset_app_env_means_development(monkeypatch):
    monkeypatch.delenv("APP_ENV", raising=False)
    c = Settings(_env_file=None)
    assert c.APP_ENV == "" and c.is_development


@pytest.mark.parametrize("value", ["staging", "live", "prd", "typo"])
def test_unrecognised_env_names_are_flagged_and_refuse_to_start(value):
    c = cfg(APP_ENV=value)
    assert c.app_env_unrecognised is True
    assert any("not a recognised environment name" in w for w in collect_config_warnings(c))
    with pytest.raises(RuntimeError, match="strict production rules apply"):
        validate_runtime_config(c)
    assert cfg(APP_ENV="production").app_env_unrecognised is False
    assert cfg(APP_ENV="dev").app_env_unrecognised is False


def test_staging_with_full_configuration_starts_under_strict_rules():
    c = cfg(**{**PROD, "APP_ENV": "staging"})
    assert collect_config_errors(c) == []
    assert c.otp_dev_mode is False


@pytest.mark.parametrize("marker", ["RAILWAY_ENVIRONMENT", "RAILWAY_PROJECT_ID", "RAILWAY_SERVICE_ID",
                                    "DYNO", "K_SERVICE", "KUBERNETES_SERVICE_HOST"])
def test_platform_markers_refuse_dev_otp(monkeypatch, marker, caplog):
    c = cfg(APP_ENV="development")
    assert c.otp_dev_mode is True and c.dev_otp_blocked_by_platform is False
    monkeypatch.setenv(marker, "1")
    assert c.platform_markers == [marker]
    assert c.dev_otp_blocked_by_platform is True
    assert c.otp_dev_mode is False
    reasons = " ".join(collect_config_warnings(c))
    assert marker in reasons and "DISABLED" in reasons                 # the reason is logged at start-up
    monkeypatch.setenv("ALLOW_DEV_OTP_ON_PLATFORM", "true")
    assert cfg(APP_ENV="development").otp_dev_mode is True            # explicit override (read from the environment)
    assert any("ALLOW_DEV_OTP_ON_PLATFORM" in w for w in collect_config_warnings(cfg(APP_ENV="development")))


def test_platform_marker_makes_the_api_withhold_the_dev_code(client, make_user, monkeypatch):
    _, email, _ = make_user()
    assert client.post("/api/v1/auth/request-otp", json={"email": email}).json()["dev_otp"] is not None
    monkeypatch.setenv("RAILWAY_ENVIRONMENT", "production")
    body = client.post("/api/v1/auth/request-otp", json={"email": email}).json()
    assert body == {"sent": True, "dev_otp": None}
    monkeypatch.setattr(settings, "ALLOW_DEV_OTP_ON_PLATFORM", "true")
    assert client.post("/api/v1/auth/request-otp", json={"email": email}).json()["dev_otp"] is not None


def test_empty_marker_values_do_not_count(monkeypatch):
    monkeypatch.setenv("DYNO", "")
    assert cfg(APP_ENV="development").platform_markers == []


# =============================================================== ISSUE 4: bounded counters
class FakeClock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now


@pytest.fixture()
def clock(monkeypatch):
    c = FakeClock()
    monkeypatch.setattr(rate_limit.time, "monotonic", c)
    return c


def test_failure_lockout_enforces_a_hard_cap(clock):
    lockout = FailureLockout(3, window_seconds=600, lock_seconds=600, max_keys=50, sweep_interval=10_000)
    for i in range(2000):
        lockout.register_failure(f"ip-{i}")
        clock.now += 0.001
    assert lockout.size() <= 51
    assert lockout.is_locked("ip-1999") is False


def test_failure_lockout_sweeps_expired_keys(clock):
    lockout = FailureLockout(3, window_seconds=60, lock_seconds=60, max_keys=10_000, sweep_interval=30)
    for i in range(500):
        lockout.register_failure(f"k{i}")
    assert lockout.size() == 500
    clock.now += 120                                   # everything is past its window
    lockout.register_failure("fresh")                  # any later hit triggers the periodic sweep
    assert lockout.size() == 1


def test_locked_keys_survive_the_cap_until_they_expire(clock):
    lockout = FailureLockout(2, window_seconds=600, lock_seconds=600, max_keys=20, sweep_interval=10_000)
    for _ in range(2):
        lockout.register_failure("attacker")
    assert lockout.is_locked("attacker")
    for i in range(500):
        lockout.register_failure(f"noise-{i}")
        clock.now += 0.001
    assert lockout.size() <= 21
    assert lockout.is_locked("attacker"), "a flood of other keys must not evict an active lock"
    clock.now += 601
    assert lockout.is_locked("attacker") is False


def test_sliding_window_limiter_is_bounded_and_sweeps(clock):
    limiter = SlidingWindowLimiter(5, window_seconds=60, max_keys=40, sweep_interval=10_000)
    for i in range(1000):
        limiter.hit(f"ip-{i}")
        clock.now += 0.001
    assert limiter.size() <= 41
    limiter2 = SlidingWindowLimiter(5, window_seconds=60, max_keys=10_000, sweep_interval=30)
    for i in range(300):
        limiter2.hit(f"k{i}")
    clock.now += 100
    limiter2.hit("fresh")
    assert limiter2.size() == 1


def test_limits_still_work_with_the_bounding(clock):
    limiter = SlidingWindowLimiter(2, window_seconds=60)
    assert [limiter.hit("a"), limiter.hit("a"), limiter.hit("a")] == [True, True, False]
    clock.now += 61
    assert limiter.hit("a") is True
    lockout = FailureLockout(2, window_seconds=60, lock_seconds=30)
    assert lockout.register_failure("x") is False and lockout.register_failure("x") is True
    assert lockout.is_locked("x")
    clock.now += 31
    assert lockout.is_locked("x") is False


def test_flood_of_unknown_emails_does_not_grow_server_state(client):
    from app.services import otp_service
    otp_service.ip_lockout.max_failures = 10_000  # keep the IP lock out of the way for this test
    try:
        for _ in range(60):
            client.post("/api/v1/auth/verify-otp", json={"email": unique_email("flood"), "code": "123456"})
    finally:
        otp_service.ip_lockout.max_failures = otp_service.OTP_IP_MAX_FAILED_ATTEMPTS
    assert otp_service.email_lockout.size() == 0
    assert otp_service.email_request_limiter.size() == 0


# =============================================================== ISSUE 5: /auth/login timing
@pytest.fixture()
def hasher_calls(monkeypatch):
    calls = []
    real = security._pbkdf2

    def spy(password, salt, iterations):
        calls.append(iterations)
        return real(password, salt, iterations)

    monkeypatch.setattr(security, "_pbkdf2", spy)
    return calls


def test_login_does_equivalent_pbkdf2_work_in_every_branch(client, make_user, hasher_calls):
    security.dummy_password_hash()                       # precomputed at start-up in the real app
    _, otp_only, _ = make_user("admin")                  # unusable "!" hash
    password_email = unique_email("pw")
    client.post("/api/v1/auth/register", json={"email": password_email, "password": "S3cure-pass!"})
    hasher_calls.clear()

    results = {}
    for label, email in (("unknown", unique_email("ghost")), ("otp_only", otp_only), ("wrong_pw", password_email)):
        hasher_calls.clear()
        r = client.post("/api/v1/auth/login", json={"email": email, "password": "not-the-password"})
        results[label] = (r.status_code, r.text, list(hasher_calls))

    assert {v[0] for v in results.values()} == {401}
    assert len({v[1] for v in results.values()}) == 1, "identical error body in every case"
    for label, (_, _, calls) in results.items():
        assert calls == [security.PBKDF2_ITERATIONS], f"{label}: expected exactly one full-cost PBKDF2 run, got {calls}"


def test_the_unusable_hash_path_calls_the_hasher(client, make_user, hasher_calls):
    _, email, _ = make_user("admin")
    security.dummy_password_hash()
    hasher_calls.clear()
    assert client.post("/api/v1/auth/login", json={"email": email, "password": "!"}).status_code == 401
    assert len(hasher_calls) == 1


def test_successful_login_still_works_and_empty_password_vs_unusable_hash_is_rejected(client, make_user):
    email = unique_email("ok")
    client.post("/api/v1/auth/register", json={"email": email, "password": "S3cure-pass!"})
    assert client.post("/api/v1/auth/login", json={"email": email, "password": "S3cure-pass!"}).status_code == 200
    _, otp_only, _ = make_user("admin")
    for guess in ("", "!", "x"):
        assert client.post("/api/v1/auth/login", json={"email": otp_only, "password": guess}).status_code == 401


def test_is_usable_hash():
    assert security.is_usable_hash(security.get_password_hash("x"))
    for bad in ("!", "", None, "plaintext", "hashed_placeholder_admin", "a$b$c", "zz$zz"):
        assert not security.is_usable_hash(bad)


# =============================================================== ISSUE 7: tightening
def test_production_startup_errors_are_fatal_development_keeps_going(monkeypatch):
    import app.main as m

    def boom():
        raise RuntimeError("database unreachable")

    monkeypatch.setattr(m, "SessionLocal", boom)
    monkeypatch.setattr(settings, "APP_ENV", "development")
    assert m.startup_event() is None                    # swallowed (historical behaviour)
    for env in ("production", "staging"):
        monkeypatch.setattr(settings, "APP_ENV", env)
        with pytest.raises(RuntimeError, match="database unreachable"):
            m.startup_event()


def test_cors_null_origin_is_rejected():
    errors = collect_config_errors(cfg(**{**PROD, "BACKEND_CORS_ORIGINS": "https://a.example.test, null"}))
    assert any("'null'" in e for e in errors)
    assert any("'null'" in e for e in collect_config_errors(cfg(**{**PROD, "BACKEND_CORS_ORIGINS": "NULL"})))
    assert cfg(APP_ENV="development", BACKEND_CORS_ORIGINS="null, https://ok.example.test").cors_origins == ["https://ok.example.test"]


def test_health_is_status_only(client):
    r = client.get("/health")
    assert r.status_code == 200 and r.json() == {"status": "healthy"}
    assert "tables" not in r.text and "model" not in r.text and "weights" not in r.text


def test_health_details_is_authenticated_and_complete(client, make_user):
    assert client.get("/api/v1/health/details").status_code == 401
    _, _, headers = make_user()
    body = client.get("/api/v1/health/details", headers=headers).json()
    assert body["status"] == "healthy" and "tables" in body and "road_weights_present" in body["model"]
    assert client.get("/api/v1/health").json() == {"status": "ok"}


def test_the_mobile_app_does_not_use_the_detailed_health_endpoints():
    lib = os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", "mobile", "lib")
    for root, _, files in os.walk(lib):
        for name in files:
            if name.endswith(".dart"):
                assert "/health" not in open(os.path.join(root, name), encoding="utf-8").read(), name
