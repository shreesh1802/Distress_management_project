"""
Final-gate fixes: an UNSET APP_ENV on a hosting platform is production-like for every dev default; an explicit
development name is the owner's choice; a laptop with nothing set stays in development. Plus the O(1) cap eviction.
"""

import pytest

from app.core import rate_limit
from app.core.config import PLATFORM_MARKERS, Settings, settings
from app.core.rate_limit import FailureLockout, SlidingWindowLimiter
from app.core.startup_checks import collect_config_errors, collect_config_warnings, validate_runtime_config
from tests.security.conftest import unique_email
from tests.security.test_production_config import GOOD_PROD_ENV, run_import

STRICT_CONFIG = {k: v for k, v in GOOD_PROD_ENV.items() if k != "APP_ENV"}


def cfg(**kw) -> Settings:
    return Settings(_env_file=None, **kw)


@pytest.mark.parametrize("marker", PLATFORM_MARKERS)
@pytest.mark.parametrize("unset", ["", "   "])
def test_marker_plus_unset_app_env_is_strict_for_every_dev_default(monkeypatch, marker, unset):
    monkeypatch.setenv(marker, "1")
    c = cfg(APP_ENV=unset)
    assert c.app_env_implicit_production is True
    assert c.is_development is False and c.is_production is True
    assert c.allow_self_registration is False
    assert c.seed_demo_data is False and c.allow_mock_model is False
    assert c.otp_dev_mode is False
    assert c.cors_origins == []                      # CORS must be explicit
    assert collect_config_errors(c), "a platform deployment with no APP_ENV must be fully configured"
    assert any("APP_ENV is not set" in w for w in collect_config_warnings(c))
    with pytest.raises(RuntimeError, match="APP_ENV is unset on a hosting platform"):
        validate_runtime_config(c)


def test_marker_plus_unset_app_env_with_full_configuration_starts_strictly(monkeypatch):
    monkeypatch.setenv("RAILWAY_ENVIRONMENT", "production")
    c = cfg(APP_ENV="", **STRICT_CONFIG)
    assert collect_config_errors(c) == []
    assert c.allow_self_registration is False and c.otp_dev_mode is False


@pytest.mark.parametrize("name", ["development", "dev", "local", "test", " Development "])
def test_marker_plus_explicit_development_is_the_owners_choice(monkeypatch, name):
    monkeypatch.setenv("RAILWAY_ENVIRONMENT", "production")
    c = cfg(APP_ENV=name)
    assert c.app_env_implicit_production is False
    assert c.is_development is True
    assert c.allow_self_registration is True and c.seed_demo_data is True and c.allow_mock_model is True
    assert c.cors_origins == ["*"]
    assert collect_config_errors(c) == []
    # ...but the dev OTP shortcut stays refused on a platform unless explicitly overridden
    assert c.otp_dev_mode is False
    assert cfg(APP_ENV=name, ALLOW_DEV_OTP_ON_PLATFORM="true").otp_dev_mode is True


def test_no_marker_and_unset_app_env_behaves_exactly_as_before():
    c = cfg(APP_ENV="")
    assert c.app_env_implicit_production is False
    assert c.is_development is True
    assert c.otp_dev_mode is True and c.allow_self_registration is True
    assert c.seed_demo_data is True and c.allow_mock_model is True and c.cors_origins == ["*"]
    assert collect_config_errors(c) == []


def test_empty_marker_values_do_not_trigger_the_strict_default(monkeypatch):
    for marker in PLATFORM_MARKERS:
        monkeypatch.setenv(marker, "")
    assert cfg(APP_ENV="").is_development is True


def test_api_marker_plus_unset_app_env_registration_is_admin_only(client, monkeypatch, admin):
    monkeypatch.setenv("RAILWAY_ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "APP_ENV", "")
    body = {"email": unique_email("plat"), "password": "S3cure-pass!"}
    assert client.post("/api/v1/auth/register", json=body).status_code == 401
    assert client.post("/api/v1/auth/register", json=body, headers=admin[2]).status_code == 201
    # and the explicit development choice reopens it
    monkeypatch.setattr(settings, "APP_ENV", "development")
    body2 = {"email": unique_email("plat2"), "password": "S3cure-pass!"}
    assert client.post("/api/v1/auth/register", json=body2).status_code == 201


def test_process_marker_plus_unset_app_env_refuses_to_start_without_configuration():
    p = run_import({"RAILWAY_ENVIRONMENT": "production"})
    assert p.returncode != 0
    out = p.stderr + p.stdout
    assert "Refusing to start" in out and "APP_ENV is unset on a hosting platform" in out


def test_process_marker_plus_unset_app_env_hides_docs_when_configured():
    p = run_import({"RAILWAY_ENVIRONMENT": "production", **STRICT_CONFIG})
    assert p.returncode == 0, p.stderr[-1500:]
    assert "IMPORT_OK None None" in p.stdout


def test_process_marker_plus_explicit_development_keeps_docs_and_starts_unconfigured():
    p = run_import({"RAILWAY_ENVIRONMENT": "production", "APP_ENV": "development"})
    assert p.returncode == 0, p.stderr[-1500:]
    assert "IMPORT_OK /docs /api/v1/openapi.json" in p.stdout


def test_process_no_marker_unset_app_env_is_unchanged_development():
    p = run_import({})
    assert p.returncode == 0 and "IMPORT_OK /docs /api/v1/openapi.json" in p.stdout


# --------------------------------------------------------------------------- cap eviction is cheap
def test_over_cap_insert_does_not_scan_every_key(monkeypatch):
    clock = [1000.0]
    monkeypatch.setattr(rate_limit.time, "monotonic", lambda: clock[0])
    limiter = SlidingWindowLimiter(5, window_seconds=60, max_keys=100, sweep_interval=10_000)
    for i in range(100):
        limiter.hit(f"k{i}")
    prunes = []
    original = limiter._prune
    monkeypatch.setattr(limiter, "_prune", lambda key, now: (prunes.append(key), original(key, now))[1])
    for i in range(100, 200):
        limiter.hit(f"k{i}")
    assert limiter.size() <= 101
    assert len(prunes) <= 200, "each over-cap insert must touch O(1) keys, not sweep all of them"
    assert limiter.hit("k150") in (True, False)

    lockout = FailureLockout(3, window_seconds=600, lock_seconds=600, max_keys=100, sweep_interval=10_000)
    for _ in range(3):
        lockout.register_failure("locked")
    for i in range(500):
        lockout.register_failure(f"n{i}")
    assert lockout.size() <= 101 and lockout.is_locked("locked")
