"""
Account hardening: registration cannot create admins, role matrix for the users router,
reduced user directory, pagination caps, password verification.
"""

import hashlib

import pytest

from app.core.roles import ALL_ROLES, RoleName
from app.core.security import (
    UNUSABLE_PASSWORD,
    get_password_hash,
    normalize_email,
    verify_password,
)
from app.models.user import User
from tests.security.conftest import unique_email


# ----------------------------------------------------------------------------- register
@pytest.mark.parametrize("role", ["admin", "ADMIN", "superuser", "maintenance", None])
def test_register_never_accepts_a_client_role(client, db, role):
    email = unique_email("reg")
    body = {"email": email, "password": "S3cure-pass!", "full_name": "Eve"}
    if role is not None:
        body["role"] = role
    r = client.post("/api/v1/auth/register", json=body)
    assert r.status_code == 201, r.text
    assert r.json()["role"] == "inspector"
    db.expire_all()
    assert db.query(User).filter(User.email == email).one().role == "inspector"


def test_register_stores_a_real_hash_not_the_password(client, db):
    email = unique_email("hash")
    client.post("/api/v1/auth/register", json={"email": email, "password": "S3cure-pass!"})
    row = db.query(User).filter(User.email == email).one()
    assert row.hashed_password.startswith("pbkdf2_sha256$")
    assert "S3cure-pass!" not in row.hashed_password
    # the freshly registered account can use the password login
    assert client.post("/api/v1/auth/login", json={"email": email, "password": "S3cure-pass!"}).status_code == 200
    assert client.post("/api/v1/auth/login", json={"email": email, "password": "wrong-pass!"}).status_code == 401


def test_register_duplicate_is_generic_and_case_insensitive(client):
    email = unique_email("dup")
    assert client.post("/api/v1/auth/register", json={"email": email, "password": "S3cure-pass!"}).status_code == 201
    dup = client.post("/api/v1/auth/register", json={"email": email.upper(), "password": "S3cure-pass!"})
    assert dup.status_code == 400
    assert "exist" not in dup.text.lower()  # does not confirm that the address is registered


def test_register_normalizes_email(client, db):
    email = unique_email("norm")
    r = client.post("/api/v1/auth/register", json={"email": email.upper(), "password": "S3cure-pass!"})
    assert r.status_code == 201
    assert r.json()["email"] == email


def test_register_is_rate_limited_per_ip(client):
    from app.api.v1.routes import auth as auth_routes
    auth_routes.register_limiter.limit = 3
    try:
        statuses = [
            client.post("/api/v1/auth/register", json={"email": unique_email("rl"), "password": "S3cure-pass!"}).status_code
            for _ in range(5)
        ]
    finally:
        auth_routes.register_limiter.limit = 20
    assert statuses[:3] == [201, 201, 201]
    assert statuses[3:] == [429, 429]


def test_role_allow_list_is_consistent():
    from typing import get_args
    assert set(get_args(RoleName)) == set(ALL_ROLES)
    assert "admin" in ALL_ROLES


# ----------------------------------------------------------------------------- users router matrix
USER_BODY = {"email": "created.by.admin@example.test", "password": "S3cure-pass!", "full_name": "Created", "role": "employee"}


def test_users_write_routes_role_matrix(client, make_user, admin):
    admin_id, _, admin_h = admin
    target_id, _, _ = make_user("inspector")
    _, _, insp_h = make_user("inspector")

    cases = [
        ("post", "/api/v1/users/", {"json": {**USER_BODY, "email": unique_email("c")}}),
        ("put", f"/api/v1/users/{target_id}", {"json": {"full_name": "Renamed"}}),
        ("put", f"/api/v1/users/{target_id}", {"json": {"role": "admin"}}),
        ("put", f"/api/v1/users/{target_id}", {"json": {"password": "N3w-password!"}}),
        ("delete", f"/api/v1/users/{target_id}", {}),
    ]
    for method, url, kwargs in cases:
        anon = getattr(client, method)(url, **kwargs)
        assert anon.status_code == 401, (method, url, kwargs)
        non_admin = getattr(client, method)(url, headers=insp_h, **kwargs)
        assert non_admin.status_code == 403, (method, url, kwargs)

    # nothing changed by the rejected calls
    assert client.get(f"/api/v1/users/{target_id}", headers=admin_h).json()["role"] == "inspector"

    ok_create = client.post("/api/v1/users/", headers=admin_h, json={**USER_BODY, "email": unique_email("ok")})
    assert ok_create.status_code == 201 and ok_create.json()["role"] == "employee"
    assert client.put(f"/api/v1/users/{target_id}", headers=admin_h, json={"role": "maintenance"}).json()["role"] == "maintenance"
    assert client.delete(f"/api/v1/users/{target_id}", headers=admin_h).status_code == 200


def test_admin_cannot_assign_unknown_roles(client, admin, make_user):
    _, _, admin_h = admin
    target_id, _, _ = make_user("inspector")
    assert client.put(f"/api/v1/users/{target_id}", headers=admin_h, json={"role": "root"}).status_code == 422
    r = client.post("/api/v1/users/", headers=admin_h, json={**USER_BODY, "email": unique_email("r"), "role": "root"})
    assert r.status_code == 422


def test_explicit_null_does_not_clear_required_fields(client, admin, make_user):
    _, _, admin_h = admin
    target_id, email, _ = make_user("inspector")
    r = client.put(f"/api/v1/users/{target_id}", headers=admin_h, json={"role": None, "email": None, "password": None})
    assert r.status_code == 200
    assert r.json()["role"] == "inspector" and r.json()["email"] == email


def test_user_directory_is_reduced_for_non_admins(client, make_user, admin):
    admin_id, admin_email, admin_h = admin
    me_id, me_email, me_h = make_user("inspector", full_name="Me Myself")
    other_id, other_email, _ = make_user("maintenance", full_name="Other Person")

    rows = client.get("/api/v1/users/?limit=200", headers=me_h).json()
    by_id = {u["id"]: u for u in rows}
    assert set(by_id[other_id]) == {"id", "full_name", "role", "email"}
    assert by_id[other_id]["full_name"] == "Other Person" and by_id[other_id]["role"] == "maintenance"
    assert by_id[other_id]["email"] is None, "other people's e-mail addresses are not exposed"
    assert by_id[admin_id]["email"] is None
    assert by_id[me_id]["email"] == me_email, "own e-mail is visible"
    for forbidden in ("hashed_password", "created_at", "updated_at"):
        assert all(forbidden not in u for u in rows)

    single = client.get(f"/api/v1/users/{other_id}", headers=me_h).json()
    assert single["email"] is None and single["full_name"] == "Other Person"

    admin_rows = {u["id"]: u for u in client.get("/api/v1/users/?limit=200", headers=admin_h).json()}
    assert admin_rows[other_id]["email"] == other_email
    assert "hashed_password" not in admin_rows[other_id]


@pytest.mark.parametrize(
    "url",
    [
        "/api/v1/users/?limit=201",
        "/api/v1/users/?limit=0",
        "/api/v1/users/?skip=-1",
        "/api/v1/videos/?limit=1001",
        "/api/v1/distress/?limit=5000",
        "/api/v1/reports/?limit=1001",
        "/api/v1/maintenance/schedule?limit=99999",
        "/api/v1/upload/videos?limit=1001",
    ],
)
def test_list_endpoints_cap_pagination(client, make_user, url):
    _, _, headers = make_user()
    assert client.get(url, headers=headers).status_code == 422


@pytest.mark.parametrize(
    "url",
    ["/api/v1/users/?limit=200", "/api/v1/videos/?limit=1000", "/api/v1/distress/?limit=1000",
     "/api/v1/reports/?limit=1000", "/api/v1/maintenance/schedule?limit=1000", "/api/v1/upload/videos?limit=1000"],
)
def test_limits_used_by_the_mobile_app_still_work(client, make_user, url):
    _, _, headers = make_user()
    assert client.get(url, headers=headers).status_code == 200


# ----------------------------------------------------------------------------- password handling
def test_verify_password_rejects_plaintext_and_placeholders():
    assert not verify_password("hashed_placeholder_admin", "hashed_placeholder_admin")
    assert not verify_password("secret", "secret")
    assert not verify_password("", "")
    assert not verify_password("!", UNUSABLE_PASSWORD)
    assert not verify_password("x", "nothex$nothex")
    assert not verify_password("x", "a$b$c")
    assert not verify_password("x", None)  # type: ignore[arg-type]


def test_verify_password_roundtrip_and_legacy_format():
    stored = get_password_hash("correct horse")
    assert stored.startswith("pbkdf2_sha256$600000$")
    assert verify_password("correct horse", stored)
    assert not verify_password("wrong horse", stored)

    # legacy "salt$hash" format (100,000 iterations) written by older versions keeps working
    salt = b"0123456789abcdef"
    legacy = f"{salt.hex()}${hashlib.pbkdf2_hmac('sha256', b'legacy-pw', salt, 100000).hex()}"
    assert verify_password("legacy-pw", legacy)
    assert not verify_password("other", legacy)


def test_normalize_email():
    assert normalize_email("  Foo@Example.COM \n") == "foo@example.com"
    assert normalize_email(None) == ""


def test_unusable_password_accounts_cannot_use_password_login(client, make_user):
    _, email, _ = make_user("admin")
    for guess in ("!", "", "password", "hashed_placeholder_admin"):
        assert client.post("/api/v1/auth/login", json={"email": email, "password": guess}).status_code == 401
