"""
Google sign-in (POST /auth/google): who gets in, what they get, and how the Firestore allow-list keeps controlling
access after the session exists. Firebase and Firestore are replaced by the fakes in conftest.
"""

from app.core.config import settings
from app.core.roles import Role
from app.models.user import User
from tests.security.conftest import unique_email


def _headers(token):
    return {"Authorization": f"Bearer {token}"}


def test_an_allowed_person_gets_a_session_and_an_account(google, allow_list, client, db):
    email = unique_email("tester")
    allow_list.allow(email, "inspector", name="Asha Tester")
    r = google(email)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["user"]["email"] == email and body["user"]["full_name"] == "Asha Tester"
    assert body["user"]["role"] == "inspector"
    assert "password" not in r.text and "hashed" not in r.text
    assert client.get("/api/v1/auth/me", headers=_headers(body["token"])).json()["email"] == email
    assert db.query(User).filter(User.email == email).count() == 1


def test_signing_in_again_reuses_the_account(google, allow_list, db):
    email = unique_email("again")
    allow_list.allow(email)
    assert google(email).status_code == 200 and google(email).status_code == 200
    assert db.query(User).filter(User.email == email).count() == 1


def test_a_person_who_is_not_on_the_list_is_refused_and_nothing_is_created(google, db):
    email = unique_email("stranger")
    r = google(email)
    assert r.status_code == 403
    assert db.query(User).filter(User.email == email).count() == 0


def test_the_email_must_be_verified_by_google(google, allow_list):
    email = "unverified." + unique_email("x")
    allow_list.allow(email)
    assert google(email).status_code == 401


def test_an_invalid_token_is_a_generic_401(client, google):
    r = client.post("/api/v1/auth/google", json={"id_token": "garbage"})
    assert r.status_code == 401 and r.json()["detail"] == "Invalid Google token"


def test_email_case_and_spaces_do_not_matter(google, allow_list, db):
    email = unique_email("casey")
    allow_list.allow(email)
    assert google(email.upper()).status_code == 200
    assert db.query(User).filter(User.email == email).count() == 1


def test_roles_come_from_the_allow_list_and_unknown_values_are_never_admin(google, allow_list):
    a, b, c = unique_email("a"), unique_email("b"), unique_email("c")
    allow_list.allow(a, "admin")
    allow_list.allow(b, "maintenance")
    allow_list.allow(c, "superadmin")            # a typo in the Firebase console must not grant anything
    assert google(a).json()["user"]["role"] == Role.ADMIN
    assert google(b).json()["user"]["role"] == "maintenance"
    assert google(c).json()["user"]["role"] == "inspector"


def test_the_deleted_user_placeholder_can_never_sign_in(google, allow_list):
    from app.services.account_deletion import DELETED_USER_EMAIL
    allow_list.allow(DELETED_USER_EMAIL)
    assert google(DELETED_USER_EMAIL).status_code == 403


def test_a_firestore_outage_during_sign_in_is_a_503_not_a_crash(google, allow_list):
    allow_list.unreachable = True
    r = google(unique_email("outage"))
    assert r.status_code == 503
    assert "Firestore" not in r.text and "unreachable" not in r.text   # internals stay in the server log


def test_sign_in_is_rate_limited_per_client(client, google, monkeypatch):
    from app.api.v1.routes import auth as auth_routes
    monkeypatch.setattr(auth_routes.google_limiter, "limit", 3)
    codes = [client.post("/api/v1/auth/google", json={"id_token": "x"}).status_code for _ in range(5)]
    assert codes == [401, 401, 401, 429, 429]


def test_oversized_tokens_are_rejected_before_any_work(client):
    assert client.post("/api/v1/auth/google", json={"id_token": "x" * 9000}).status_code == 422


def test_the_old_email_code_routes_are_gone(client):
    assert client.post("/api/v1/auth/request-otp", json={"email": "a@b.co"}).status_code in (404, 405)
    assert client.post("/api/v1/auth/verify-otp", json={"email": "a@b.co", "code": "123456"}).status_code in (404, 405)


def test_production_refuses_to_start_without_firebase_credentials():
    from app.core.config import Settings
    from app.core.startup_checks import collect_config_errors
    base = dict(APP_ENV="production", DOWNLOAD_SIGNING_SECRET="Kq7vZ3mT9xW2bN8cR5yH1jL4pD6sF0aGuE!")
    errors = collect_config_errors(Settings(_env_file=None, **base))
    assert any("Firebase credentials" in e for e in errors)
    assert not any("Firebase" in e for e in collect_config_errors(
        Settings(_env_file=None, FIREBASE_CREDENTIALS_JSON='{"type": "service_account"}', **base)))
    assert not any("Firebase" in e for e in collect_config_errors(
        Settings(_env_file=None, FIREBASE_CREDENTIALS_PATH="/secrets/firebase.json", **base)))


# ----------------------------------------------------------------------------------- access stays controlled
def test_removing_someone_from_the_list_ends_their_session(google, allow_list, client):
    email = unique_email("leaver")
    allow_list.allow(email)
    token = google(email).json()["token"]
    assert client.get("/api/v1/auth/me", headers=_headers(token)).status_code == 200
    allow_list.remove(email)
    r = client.get("/api/v1/auth/me", headers=_headers(token))
    assert r.status_code == 401 and "removed" in r.json()["detail"]
    assert google(email).status_code == 403


def test_a_role_change_in_firebase_applies_without_signing_in_again(google, allow_list, client):
    email = unique_email("promoted")
    allow_list.allow(email, "inspector")
    token = google(email).json()["token"]
    assert client.get("/api/v1/users/", headers=_headers(token)).status_code == 200
    assert client.post("/api/v1/users/", headers=_headers(token),
                       json={"email": unique_email("n")}).status_code == 403      # not an admin yet
    allow_list.allow(email, "admin")
    assert client.post("/api/v1/users/", headers=_headers(token),
                       json={"email": unique_email("n")}).status_code == 201      # now is


def test_if_firestore_is_unreachable_existing_sessions_keep_working(google, allow_list, client):
    email = unique_email("steady")
    allow_list.allow(email)
    token = google(email).json()["token"]
    allow_list.unreachable = True
    assert client.get("/api/v1/auth/me", headers=_headers(token)).status_code == 200


def test_deleting_my_account_also_removes_my_allow_list_entry(google, allow_list, client, db):
    email = unique_email("bye")
    allow_list.allow(email)
    token = google(email).json()["token"]
    r = client.post("/api/v1/auth/delete-account", json={"confirm_email": email}, headers=_headers(token))
    assert r.status_code == 204
    assert allow_list.removed == [email]
    assert db.query(User).filter(User.email == email).count() == 0
    assert google(email).status_code == 403


def test_account_deletion_still_succeeds_if_the_allow_list_cannot_be_updated(google, allow_list, client, monkeypatch, db):
    from app.api.v1.routes import auth as auth_routes
    email = unique_email("bye2")
    allow_list.allow(email)
    token = google(email).json()["token"]

    def boom(_email):
        raise RuntimeError("Firestore down")

    monkeypatch.setattr(auth_routes, "remove_allowed_entry", boom)
    r = client.post("/api/v1/auth/delete-account", json={"confirm_email": email}, headers=_headers(token))
    assert r.status_code == 204
    assert db.query(User).filter(User.email == email).count() == 0


def test_the_live_camera_websocket_also_stops_working_after_removal(google, allow_list, client):
    from starlette.websockets import WebSocketDisconnect
    import json
    import pytest
    email = unique_email("streamer")
    allow_list.allow(email)
    token = google(email).json()["token"]
    allow_list.remove(email)
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect("/api/v1/live/phone-stream") as ws:
            ws.send_text(json.dumps({"type": "auth", "token": token}))
            ws.receive_text()
