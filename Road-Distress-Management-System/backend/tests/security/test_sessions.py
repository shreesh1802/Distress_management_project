"""
Session tokens: server-side logout, hashed storage, expiry, purge, lifetime.
"""

import hashlib
from datetime import datetime, timedelta, timezone

from app.models.auth import AuthToken
from app.services import session_service


def login(google, allow_list, email):
    allow_list.allow(email)
    r = google(email)
    assert r.status_code == 200, r.text
    return r.json()["token"]


def test_logout_invalidates_the_token(client, make_user, google, allow_list):
    _, email, _ = make_user()
    token = login(google, allow_list, email)
    headers = {"Authorization": f"Bearer {token}"}
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 200
    assert client.post("/api/v1/auth/logout", headers=headers).status_code == 204
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 401
    assert client.get("/api/v1/projects/", headers=headers).status_code == 401
    # logging out twice is a plain 401, not an error page
    assert client.post("/api/v1/auth/logout", headers=headers).status_code == 401


def test_logout_only_revokes_the_presented_session(client, make_user, google, allow_list):
    _, email, _ = make_user()
    t1, t2 = login(google, allow_list, email), login(google, allow_list, email)
    client.post("/api/v1/auth/logout", headers={"Authorization": f"Bearer {t1}"})
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {t2}"}).status_code == 200


def test_database_stores_only_a_hash_of_the_token(make_user, db, google, allow_list):
    _, email, _ = make_user()
    token = login(google, allow_list, email)
    stored = [row.token for row in db.query(AuthToken).all()]
    assert token not in stored
    assert hashlib.sha256(token.encode()).hexdigest() in stored
    assert all(len(s) == 64 for s in stored)


def test_a_plaintext_token_row_does_not_authenticate(client, make_user, db):
    uid, _, _ = make_user()
    raw = "ab" * 32
    db.add(AuthToken(token=raw, user_id=uid, expires_at=datetime.now(timezone.utc) + timedelta(days=1)))
    db.commit()
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {raw}"}).status_code == 401


def test_expired_token_is_rejected(client, make_user, db, google, allow_list):
    _, email, _ = make_user()
    token = login(google, allow_list, email)
    db.query(AuthToken).filter(AuthToken.token == session_service.hash_token(token)).update(
        {"expires_at": datetime.now(timezone.utc) - timedelta(seconds=1)}
    )
    db.commit()
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"}).status_code == 401


def test_session_lifetime_is_thirty_days(make_user, db, google, allow_list):
    _, email, _ = make_user()
    token = login(google, allow_list, email)
    row = db.query(AuthToken).filter(AuthToken.token == session_service.hash_token(token)).one()
    expires = row.expires_at if row.expires_at.tzinfo else row.expires_at.replace(tzinfo=timezone.utc)
    remaining = expires - datetime.now(timezone.utc)
    assert timedelta(days=29, hours=23) < remaining <= timedelta(days=30)
    assert session_service.TOKEN_TTL_DAYS == 30


def test_expired_sessions_are_purged_when_a_new_one_is_issued(make_user, db):
    uid, _, _ = make_user()
    db.add(AuthToken(token="f" * 64, user_id=uid, expires_at=datetime.now(timezone.utc) - timedelta(days=1)))
    db.commit()
    session_service.issue_token(db, uid)
    db.expire_all()
    assert db.query(AuthToken).filter(AuthToken.token == "f" * 64).count() == 0


def test_deleted_user_session_stops_working(client, make_user, admin):
    uid, _, user_h = make_user()
    _, _, admin_h = admin
    assert client.get("/api/v1/auth/me", headers=user_h).status_code == 200
    assert client.delete(f"/api/v1/users/{uid}", headers=admin_h).status_code == 200
    assert client.get("/api/v1/auth/me", headers=user_h).status_code == 401
