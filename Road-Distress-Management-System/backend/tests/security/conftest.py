"""
Shared fixtures for the security test-suite.

Everything runs IN-PROCESS against FastAPI's TestClient and a TEMPORARY SQLite
database -- the real road_distress.db, uploads/ and reports/ are never touched
(storage roots are redirected to a temp directory by the ``sandbox_storage`` fixture).

IMPORTANT: the environment is prepared at import time, BEFORE ``app`` is imported,
because app.core.config / app.db.session read it once.
"""

import os
import shutil
import sys
import tempfile
import uuid

_TMP_ROOT = tempfile.mkdtemp(prefix="rdms_sec_tests_")
_DB_FILE = os.path.join(_TMP_ROOT, "test.db").replace("\\", "/")

# Hermetic configuration: never inherit a developer's real settings.
for _var in (
    "SEED_DEMO_DATA", "ALLOW_MOCK_MODEL", "DOWNLOAD_SIGNING_SECRET", "BACKEND_CORS_ORIGINS", "TRUSTED_PROXY_COUNT",
    "FIREBASE_CREDENTIALS_JSON", "FIREBASE_CREDENTIALS_PATH", "MODEL_BASE_URL", "MODEL_DOWNLOAD_TOKEN",
    "RAILWAY_ENVIRONMENT", "RAILWAY_PROJECT_ID", "RAILWAY_SERVICE_ID", "DYNO", "K_SERVICE", "KUBERNETES_SERVICE_HOST",
):
    os.environ.pop(_var, None)
os.environ["APP_ENV"] = "development"
os.environ["DATABASE_URL"] = f"sqlite:///{_DB_FILE}"
os.environ["TRANSCRIPTION_ENABLED"] = "false"  # never load Whisper / hit the network from tests

# Make `import app` work no matter where pytest is started from.
_BACKEND_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _BACKEND_ROOT not in sys.path:
    sys.path.insert(0, _BACKEND_ROOT)

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.core.config import settings  # noqa: E402

assert settings.sqlalchemy_database_uri.endswith("test.db"), "tests must run on the temporary database"

import app.main as app_main  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.core import safe_paths  # noqa: E402
from app.core.security import UNUSABLE_PASSWORD, normalize_email  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services import session_service  # noqa: E402
from app.api.v1.routes import auth as auth_routes  # noqa: E402


def pytest_sessionfinish(session, exitstatus):
    from app.db.session import engine
    engine.dispose()  # release the SQLite file handle so the temp directory can be removed on Windows
    shutil.rmtree(_TMP_ROOT, ignore_errors=True)


@pytest.fixture(scope="session")
def client():
    with TestClient(app_main.app) as c:
        yield c


@pytest.fixture(autouse=True)
def _reset_state(monkeypatch):
    """Fresh abuse counters + development settings for every test."""
    auth_routes.google_limiter.reset()
    auth_routes.login_limiter.reset()
    auth_routes.register_limiter.reset()
    for marker in ("RAILWAY_ENVIRONMENT", "RAILWAY_PROJECT_ID", "RAILWAY_SERVICE_ID", "DYNO", "K_SERVICE", "KUBERNETES_SERVICE_HOST"):
        monkeypatch.delenv(marker, raising=False)  # tests must not depend on the machine they run on
    monkeypatch.setattr(settings, "TRUSTED_PROXY_COUNT", 0)
    monkeypatch.setattr(settings, "APP_ENV", "development")
    monkeypatch.setattr(settings, "FIREBASE_CREDENTIALS_JSON", None)
    monkeypatch.setattr(settings, "FIREBASE_CREDENTIALS_PATH", None)
    # Tests never talk to Firebase: pretend the Firebase Admin app is configured (a test below checks the 503 when it is not).
    monkeypatch.setattr(auth_routes, "get_firebase_app", lambda: object())
    yield


@pytest.fixture()
def db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


def unique_email(prefix="user") -> str:
    return f"{prefix}.{uuid.uuid4().hex[:10]}@example.test"


@pytest.fixture()
def make_user(db):
    """Creates a user directly in the DB and returns (user_id, email, bearer_headers)."""

    def _make(role="inspector", email=None, full_name=None):
        email = normalize_email(email or unique_email(role))
        user = User(email=email, full_name=full_name or role.title(), hashed_password=UNUSABLE_PASSWORD, role=role)
        db.add(user)
        db.commit()
        db.refresh(user)
        token = session_service.issue_token(db, user.id)
        return user.id, email, {"Authorization": f"Bearer {token}"}

    return _make


@pytest.fixture()
def admin(make_user):
    return make_user("admin", full_name="Test Admin")


@pytest.fixture()
def sandbox_storage(tmp_path, monkeypatch):
    """Redirects every storage root to a temp dir so no test can touch the real uploads/ or reports/."""
    backend = tmp_path / "backend"
    uploads = backend / "uploads"
    reports = tmp_path / "reports"
    for d in (uploads / "videos", uploads / "assets", uploads / "audio", reports / "generated", reports / "excel"):
        d.mkdir(parents=True, exist_ok=True)

    monkeypatch.setattr(safe_paths, "BACKEND_ROOT", str(backend))
    monkeypatch.setattr(safe_paths, "UPLOADS_ROOT", str(uploads))
    monkeypatch.setattr(safe_paths, "PROJECT_ROOT", str(tmp_path))
    monkeypatch.setattr(safe_paths, "REPORTS_ROOT", str(reports))

    from app.services import asset as asset_service, audit as audit_service, video as video_service
    for mod, sub in ((asset_service, "assets"), (audit_service, "audio"), (video_service, "videos")):
        monkeypatch.setattr(mod, "BASE_DIR", str(backend))
        monkeypatch.setattr(mod, "UPLOAD_DIR", str(uploads / sub))

    class Sandbox:
        root = tmp_path
        backend_dir = backend
        uploads_dir = uploads
        reports_dir = reports

    return Sandbox


# ------------------------------------------------------------------------------------ fake Google sign-in
class FakeAllowList:
    """Stands in for the Firestore ``allowedUsers`` collection."""

    def __init__(self):
        self.entries = {}
        self.removed = []
        self.unreachable = False

    def allow(self, email, role="inspector", name=None):
        entry = {"role": role}
        if name:
            entry["name"] = name
        self.entries[normalize_email(email)] = entry

    def remove(self, email):
        self.entries.pop(normalize_email(email), None)

    def get(self, email):
        if self.unreachable:
            raise RuntimeError("Firestore unreachable")
        return self.entries.get(normalize_email(email))

    def delete_entry(self, email):
        self.removed.append(normalize_email(email))
        self.entries.pop(normalize_email(email), None)


@pytest.fixture()
def allow_list(monkeypatch):
    """A fake Firestore allow-list wired into the access service, the auth dependency and the delete-account route."""
    from app.core import deps
    from app.services import access_service

    fake = FakeAllowList()
    monkeypatch.setattr(access_service, "get_allowed_entry", fake.get)
    monkeypatch.setattr(deps, "get_allowed_entry", fake.get)
    monkeypatch.setattr(auth_routes, "remove_allowed_entry", fake.delete_entry)
    return fake


@pytest.fixture()
def google(client, monkeypatch, allow_list):
    """
    Fake Google sign-in. ``google(email)`` posts a token of the form ``fake:<email>`` to POST /auth/google; the
    Firebase verification is replaced by one that accepts those tokens. Emails starting with ``unverified.`` come
    back with email_verified = False. Returns the HTTP response.
    """

    def fake_verify(id_token):
        if not id_token.startswith("fake:"):
            raise ValueError("not a valid Google token")
        email = id_token[len("fake:"):]
        return {"email": email, "email_verified": not email.startswith("unverified."), "name": "Test Person"}

    monkeypatch.setattr(auth_routes, "verify_google_id_token", fake_verify)

    def login(email):
        return client.post("/api/v1/auth/google", json={"id_token": f"fake:{email}"})

    return login
