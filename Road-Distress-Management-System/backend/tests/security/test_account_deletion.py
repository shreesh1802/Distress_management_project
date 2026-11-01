"""
Self-service account deletion (POST /auth/delete-account) and the neutral "Deleted user" placeholder.
"""

from app.core.config import settings
from app.core.roles import Role
from app.models.asset import ProjectAsset
from app.models.audit import SafetyAudit
from app.models.auth import AuthToken, OtpCode
from app.models.project import Project, ProjectMember
from app.models.user import User
from app.services.account_deletion import DELETED_USER_EMAIL
from tests.security.conftest import unique_email

URL = "/api/v1/auth/delete-account"


def _user_row(db, user_id):
    db.expire_all()
    return db.get(User, user_id)


def test_requires_authentication(client):
    assert client.post(URL, json={"confirm_email": "x@example.test"}).status_code == 401


def test_wrong_confirmation_email_deletes_nothing(client, db, make_user):
    uid, _email, headers = make_user("employee")
    r = client.post(URL, json={"confirm_email": "someone.else@example.test"}, headers=headers)
    assert r.status_code == 400
    assert _user_row(db, uid) is not None


def test_deletes_account_sessions_and_codes(client, db, make_user):
    uid, email, headers = make_user("employee")
    db.add(OtpCode(email=email, code="111222", expires_at=__import__("datetime").datetime(2099, 1, 1)))
    db.commit()

    r = client.post(URL, json={"confirm_email": email.upper()}, headers=headers)  # case-insensitive confirmation
    assert r.status_code == 204

    assert _user_row(db, uid) is None
    assert db.query(AuthToken).filter(AuthToken.user_id == uid).count() == 0
    assert db.query(OtpCode).filter(OtpCode.email == email).count() == 0
    # the session that deleted the account no longer works
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 401


def test_shared_records_are_kept_but_reattributed(client, db, make_user, admin):
    admin_id, _admin_email, _ = admin
    uid, email, headers = make_user("employee")

    project = Project(name="Shared", owner_id=uid)
    db.add(project)
    db.flush()
    db.add(ProjectMember(project_id=project.id, user_id=uid))
    db.add(ProjectMember(project_id=project.id, user_id=admin_id))
    audit = SafetyAudit(project_id=project.id, title="Drive 1", created_by_id=uid)
    asset = ProjectAsset(project_id=project.id, uploaded_by_id=uid, filename="a.pdf", filepath="uploads/assets/a.pdf")
    db.add_all([audit, asset])
    db.commit()
    project_id, audit_id, asset_id = project.id, audit.id, asset.id

    assert client.post(URL, json={"confirm_email": email}, headers=headers).status_code == 204

    db.expire_all()
    placeholder = db.query(User).filter(User.email == DELETED_USER_EMAIL).one()
    assert placeholder.full_name == "Deleted user"
    assert db.get(Project, project_id).owner_id == placeholder.id
    assert db.get(SafetyAudit, audit_id).created_by_id == placeholder.id
    assert db.get(ProjectAsset, asset_id).uploaded_by_id == placeholder.id
    members = {m.user_id for m in db.query(ProjectMember).filter(ProjectMember.project_id == project_id)}
    assert members == {admin_id}  # the deleted user's membership is gone, the other member's stays


def test_placeholder_cannot_sign_in(client, db, make_user):
    uid, email, headers = make_user("employee")
    assert client.post(URL, json={"confirm_email": email}, headers=headers).status_code == 204

    r = client.post("/api/v1/auth/request-otp", json={"email": DELETED_USER_EMAIL})
    assert r.status_code == 200 and r.json()["dev_otp"] is None  # no code even in development mode
    assert db.query(OtpCode).filter(OtpCode.email == DELETED_USER_EMAIL).count() == 0
    assert client.post("/api/v1/auth/verify-otp", json={"email": DELETED_USER_EMAIL, "code": "000000"}).status_code == 401


def test_placeholder_account_cannot_be_deleted(db):
    from app.services.account_deletion import AccountDeletionError, delete_account, _placeholder_user
    placeholder = _placeholder_user(db)
    db.commit()
    try:
        delete_account(db, placeholder)
    except AccountDeletionError:
        return
    raise AssertionError("placeholder deletion should be refused")


def test_last_administrator_cannot_delete_themselves(client, db, make_user):
    db.query(User).filter(User.role == Role.ADMIN).delete()
    db.commit()
    aid, email, headers = make_user("admin", email=unique_email("onlyadmin"))
    r = client.post(URL, json={"confirm_email": email}, headers=headers)
    assert r.status_code == 409
    assert "only administrator" in r.json()["detail"].lower()
    assert _user_row(db, aid) is not None


def test_an_admin_can_delete_themselves_when_another_admin_exists(client, db, make_user):
    make_user("admin")
    aid, email, headers = make_user("admin")
    assert client.post(URL, json={"confirm_email": email}, headers=headers).status_code == 204
    assert _user_row(db, aid) is None


def test_unauthenticated_delete_does_not_depend_on_settings(client, monkeypatch):
    monkeypatch.setattr(settings, "APP_ENV", "production")
    assert client.post(URL, json={"confirm_email": "x@example.test"}).status_code == 401
