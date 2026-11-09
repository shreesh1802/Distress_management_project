"""
Self-service account deletion (a Google Play requirement for apps with accounts).

What is removed: the user's account, every session token and the user's project memberships. Records the user created inside shared projects (projects, audits, uploaded
documents) are kept for the other members but re-attributed to a neutral "Deleted user" placeholder
account, exactly as the privacy policy states; nullable references (videos, maintenance tasks,
reports) are simply cleared. The placeholder cannot sign in.
"""

import logging

from sqlalchemy import delete, func, update
from sqlalchemy.orm import Session

from app.core.roles import Role
from app.core.security import UNUSABLE_PASSWORD
from app.models.asset import ProjectAsset
from app.models.audit import SafetyAudit
from app.models.auth import AuthToken
from app.models.maintenance import MaintenanceTask
from app.models.project import Project, ProjectMember
from app.models.report import Report
from app.models.user import User
from app.models.video import UploadedVideo

logger = logging.getLogger(__name__)

# ".invalid" is reserved (RFC 2606): no mailbox can ever exist here.
DELETED_USER_EMAIL = "deleted-user@deleted.invalid"
DELETED_USER_NAME = "Deleted user"


class AccountDeletionError(Exception):
    """The account cannot be deleted right now; ``str(exc)`` is safe to show to the user."""


def is_placeholder_email(email: str) -> bool:
    return (email or "").strip().lower() == DELETED_USER_EMAIL


def _placeholder_user(db: Session) -> User:
    user = db.query(User).filter(func.lower(User.email) == DELETED_USER_EMAIL).first()
    if user is None:
        user = User(
            email=DELETED_USER_EMAIL,
            full_name=DELETED_USER_NAME,
            hashed_password=UNUSABLE_PASSWORD,
            role=Role.EMPLOYEE,
        )
        db.add(user)
        db.flush()
    return user


def delete_account(db: Session, user: User) -> None:
    """Deletes ``user`` and everything personal about them in a single transaction."""
    if is_placeholder_email(user.email):
        raise AccountDeletionError("This account cannot be deleted.")

    if user.role == Role.ADMIN:
        other_admins = (
            db.query(User)
            .filter(User.role == Role.ADMIN, User.id != user.id, func.lower(User.email) != DELETED_USER_EMAIL)
            .count()
        )
        if other_admins == 0:
            raise AccountDeletionError(
                "You are the only administrator. Make another account an administrator before deleting this one."
            )

    user_id = user.id
    try:
        placeholder = _placeholder_user(db)
        for model, column in (
            (Project, Project.owner_id),
            (SafetyAudit, SafetyAudit.created_by_id),
            (ProjectAsset, ProjectAsset.uploaded_by_id),
        ):
            db.execute(update(model).where(column == user_id).values({column.key: placeholder.id}))

        for model, column in (
            (UploadedVideo, UploadedVideo.uploader_id),
            (MaintenanceTask, MaintenanceTask.assigned_to),
            (Report, Report.generated_by),
        ):
            db.execute(update(model).where(column == user_id).values({column.key: None}))

        db.execute(delete(ProjectMember).where(ProjectMember.user_id == user_id))
        db.execute(delete(AuthToken).where(AuthToken.user_id == user_id))
        db.execute(delete(User).where(User.id == user_id))
        db.commit()
    except Exception:
        db.rollback()
        raise
    logger.info("Account %s deleted at the owner's request.", user_id)
