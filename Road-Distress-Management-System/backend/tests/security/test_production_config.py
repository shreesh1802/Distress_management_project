"""
APP_ENV handling: production fails closed, development keeps the demo conveniences, demo seeding
and the mock model are gated, docs are hidden in production, CORS comes from configuration.
"""

import os
import subprocess
import sys

import pytest

from app.core.config import Settings, settings
from app.core.startup_checks import collect_config_errors, validate_runtime_config

BACKEND_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

GOOD_PROD_ENV = {
    "APP_ENV": "production",
    "SMTP_HOST": "smtp.example.test",
    "SMTP_FROM": "noreply@example.test",
    "DOWNLOAD_SIGNING_SECRET": "Kq7vZ3mT9xW2bN8cR5yH1jL4pD6sF0aGuE!",
    "BACKEND_CORS_ORIGINS": "https://app.example.test",
}


def cfg(**kw) -> Settings:
    return Settings(_env_file=None, **kw)


def run_import(env_overrides, code="import app.main as m; print('IMPORT_OK', m.app.docs_url, m.app.openapi_url)"):
    env = {k: v for k, v in os.environ.items() if not k.startswith(("SMTP_", "OTP_", "APP_ENV", "BACKEND_CORS", "DOWNLOAD_", "SEED_", "ALLOW_", "BOOTSTRAP", "RAILWAY_", "DYNO", "K_SERVICE", "KUBERNETES_"))}
    env.update(env_overrides)
    env["DATABASE_URL"] = os.environ["DATABASE_URL"]
    return subprocess.run([sys.executable, "-W", "ignore", "-c", code], cwd=BACKEND_ROOT, env=env,
                          capture_output=True, text=True, timeout=180)


# ----------------------------------------------------------------------------- unit level
def test_development_is_the_default_and_has_no_config_errors():
    c = cfg()
    assert c.APP_ENV in ("", "development") and not c.is_production
    assert collect_config_errors(c) == []
    assert c.otp_dev_mode is True and c.seed_demo_data is True and c.allow_mock_model is True
    assert c.cors_origins == ["*"]


def test_production_without_configuration_is_rejected_with_clear_errors():
    errors = collect_config_errors(cfg(APP_ENV="production"))
    text = "\n".join(errors)
    assert "SMTP is not configured" in text
    assert "DOWNLOAD_SIGNING_SECRET" in text
    with pytest.raises(RuntimeError, match="Refusing to start"):
        validate_runtime_config(cfg(APP_ENV="production"))


def test_production_rejects_dev_otp_and_wildcard_cors():
    errors = "\n".join(collect_config_errors(cfg(**{**GOOD_PROD_ENV, "OTP_DEV_MODE": "true", "BACKEND_CORS_ORIGINS": "*"})))
    assert "OTP_DEV_MODE" in errors and "BACKEND_CORS_ORIGINS" in errors
    assert "SMTP" not in errors


@pytest.mark.parametrize("secret", ["short", "a" * 64, "ab" * 32, "abcdefg" * 6, ""])
def test_production_requires_a_strong_signing_secret(secret):
    errors = collect_config_errors(cfg(**{**GOOD_PROD_ENV, "DOWNLOAD_SIGNING_SECRET": secret}))
    assert any("DOWNLOAD_SIGNING_SECRET" in e for e in errors)


def test_a_random_looking_signing_secret_is_accepted():
    assert collect_config_errors(cfg(**GOOD_PROD_ENV)) == []


def test_smtp_user_and_password_must_come_together():
    errors = collect_config_errors(cfg(**{**GOOD_PROD_ENV, "SMTP_USER": "me"}))
    assert any("SMTP_USER" in e for e in errors)


def test_a_complete_production_configuration_is_accepted():
    c = cfg(**GOOD_PROD_ENV)
    assert collect_config_errors(c) == []
    assert c.otp_dev_mode is False  # forced off even if someone sets the flag
    assert c.seed_demo_data is False and c.allow_mock_model is False
    assert c.cors_origins == ["https://app.example.test"]


def test_production_without_cors_setting_means_no_cross_origin_access():
    c = cfg(**{k: v for k, v in GOOD_PROD_ENV.items() if k != "BACKEND_CORS_ORIGINS"})
    assert c.cors_origins == []
    assert collect_config_errors(c) == []


def test_flags_can_be_overridden_explicitly():
    assert cfg(APP_ENV="production", SEED_DEMO_DATA="true").seed_demo_data is True
    assert cfg(APP_ENV="production", ALLOW_MOCK_MODEL="true").allow_mock_model is True
    assert cfg(SEED_DEMO_DATA="false").seed_demo_data is False
    assert cfg(OTP_DEV_MODE="false").otp_dev_mode is False


# ----------------------------------------------------------------------------- real process start-up
def test_process_refuses_to_start_in_production_without_smtp_and_cors():
    p = run_import({"APP_ENV": "production"})
    assert p.returncode != 0
    assert "Refusing to start" in (p.stderr + p.stdout)
    assert "SMTP" in (p.stderr + p.stdout)
    assert "IMPORT_OK" not in p.stdout


def test_process_refuses_dev_otp_and_wildcard_cors_in_production():
    p = run_import({**GOOD_PROD_ENV, "OTP_DEV_MODE": "true", "BACKEND_CORS_ORIGINS": "*"})
    assert p.returncode != 0
    out = p.stderr + p.stdout
    assert "OTP_DEV_MODE" in out and "BACKEND_CORS_ORIGINS" in out


def test_process_starts_in_production_when_configured_and_hides_docs():
    p = run_import(GOOD_PROD_ENV)
    assert p.returncode == 0, p.stderr[-2000:]
    assert "IMPORT_OK None None" in p.stdout, p.stdout


def test_process_starts_in_development_by_default_with_docs():
    p = run_import({})
    assert p.returncode == 0, p.stderr[-2000:]
    assert "IMPORT_OK /docs /api/v1/openapi.json" in p.stdout


def test_docs_are_not_routable_in_production():
    code = (
        "from fastapi.testclient import TestClient; import app.main as m\n"
        "c = TestClient(m.app)\n"
        "print('CODES', c.get('/docs').status_code, c.get('/redoc').status_code, c.get('/openapi.json').status_code, c.get('/api/v1/openapi.json').status_code)\n"
    )
    p = run_import(GOOD_PROD_ENV, code)
    assert p.returncode == 0, p.stderr[-2000:]
    assert "CODES 404 404 404 404" in p.stdout


# ----------------------------------------------------------------------------- bootstrap / seeding gates
@pytest.fixture()
def fresh_db(tmp_path):
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from app.db.base import Base
    engine = create_engine(f"sqlite:///{(tmp_path / 'fresh.db').as_posix()}")
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    yield session
    session.close()
    engine.dispose()


def test_bootstrap_admin_in_development_creates_user_one_with_unusable_password(fresh_db):
    from app.db.bootstrap import bootstrap_admin, DEV_ADMIN_EMAIL
    from app.core.security import verify_password, UNUSABLE_PASSWORD
    from app.models.user import User
    bootstrap_admin(fresh_db)
    admin = fresh_db.query(User).filter(User.id == 1).one()
    assert admin.email == DEV_ADMIN_EMAIL and admin.role == "admin"
    assert admin.hashed_password == UNUSABLE_PASSWORD
    assert not verify_password("", admin.hashed_password) and not verify_password("!", admin.hashed_password)


def test_bootstrap_replaces_the_legacy_placeholder_hash(fresh_db):
    from sqlalchemy import text
    from app.db.bootstrap import bootstrap_admin
    from app.core.security import UNUSABLE_PASSWORD
    from app.models.user import User
    fresh_db.add(User(id=1, email="admin@roaddistress.org", hashed_password="hashed_placeholder_admin", role="admin"))
    fresh_db.commit()
    bootstrap_admin(fresh_db)
    assert fresh_db.execute(text("select hashed_password from users where id=1")).scalar() == UNUSABLE_PASSWORD


def test_bootstrap_in_production_creates_nothing_without_an_env_email(fresh_db, monkeypatch):
    from app.db.bootstrap import bootstrap_admin
    from app.models.user import User
    monkeypatch.setattr(settings, "APP_ENV", "production")
    monkeypatch.setattr(settings, "BOOTSTRAP_ADMIN_EMAIL", None)
    bootstrap_admin(fresh_db)
    assert fresh_db.query(User).count() == 0


def test_bootstrap_in_production_uses_the_env_email(fresh_db, monkeypatch):
    from app.db.bootstrap import bootstrap_admin
    from app.core.security import UNUSABLE_PASSWORD
    from app.models.user import User
    monkeypatch.setattr(settings, "APP_ENV", "production")
    monkeypatch.setattr(settings, "BOOTSTRAP_ADMIN_EMAIL", "  Owner@Example.TEST ")
    bootstrap_admin(fresh_db)
    bootstrap_admin(fresh_db)  # idempotent
    users = fresh_db.query(User).all()
    assert len(users) == 1
    assert users[0].email == "owner@example.test" and users[0].role == "admin"
    assert users[0].hashed_password == UNUSABLE_PASSWORD


def test_demo_data_is_only_seeded_when_enabled(fresh_db, monkeypatch):
    import app.main as m
    from app.db.bootstrap import bootstrap_admin
    from app.models.video import UploadedVideo
    from app.models.distress import RoadDistress
    bootstrap_admin(fresh_db)
    m._seed_demo_data(fresh_db)
    assert fresh_db.query(UploadedVideo).filter(UploadedVideo.id == 20).count() == 1
    assert fresh_db.query(RoadDistress).filter(RoadDistress.video_id == 20).count() == 8
    monkeypatch.setattr(settings, "APP_ENV", "production")
    assert settings.seed_demo_data is False  # startup_event skips _seed_demo_data when this is False


def test_mock_model_is_forbidden_unless_explicitly_allowed(monkeypatch):
    from app.services.ai import model_loader
    monkeypatch.setattr(settings, "APP_ENV", "production")
    with pytest.raises(model_loader.ModelUnavailableError):
        model_loader._mock_or_raise("models/road_best.pth", "test")
    monkeypatch.setattr(settings, "ALLOW_MOCK_MODEL", "true")
    assert isinstance(model_loader._mock_or_raise("models/road_best.pth", "test"), model_loader.MockYOLO)
    monkeypatch.setattr(settings, "APP_ENV", "development")
    monkeypatch.setattr(settings, "ALLOW_MOCK_MODEL", "false")
    with pytest.raises(model_loader.ModelUnavailableError):
        model_loader._mock_or_raise("models/road_best.pth", "test")


def test_health_is_status_only_and_details_need_a_login(client, make_user):
    body = client.get("/health").json()
    assert body == {"status": "healthy"}
    _, _, headers = make_user()
    assert client.get("/api/v1/health/details").status_code == 401
    details = client.get("/api/v1/health/details", headers=headers).json()
    assert set(details["model"]) >= {"road_model", "signage_model", "mock_allowed", "yolox_runtime"}
    assert details["model"]["mock_allowed"] is True  # development default
    assert "users" in details["tables"]


def test_destructive_scripts_refuse_production_and_non_sqlite(monkeypatch):
    from app.core import env_guard
    monkeypatch.delenv(env_guard.OVERRIDE_VAR, raising=False)
    monkeypatch.setattr(settings, "APP_ENV", "production")
    with pytest.raises(SystemExit) as exc:
        env_guard.require_safe_environment("seed_data.py")
    assert exc.value.code == 2

    monkeypatch.setattr(settings, "APP_ENV", "development")
    monkeypatch.setattr(settings, "DATABASE_URL", "postgresql://u:p@db.example.test/prod")
    with pytest.raises(SystemExit):
        env_guard.require_safe_environment("reset_test_data.py")

    monkeypatch.setenv(env_guard.OVERRIDE_VAR, env_guard.OVERRIDE_VALUE)
    env_guard.require_safe_environment("reset_test_data.py")  # explicit override works

    monkeypatch.delenv(env_guard.OVERRIDE_VAR)
    monkeypatch.setattr(settings, "DATABASE_URL", "sqlite:///local.db")
    env_guard.require_safe_environment("seed_data.py")  # local sqlite in development is fine
