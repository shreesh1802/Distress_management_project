"""
First-administrator bootstrap, shared by the app startup (app/main.py) and the manual
initializer (app/db/init_db.py).

No known passwords are ever created: administrators sign in with Email + OTP, so the
account is stored with an unusable-password marker that verify_password() always rejects.
"""

import logging

from sqlalchemy import text

from app.core.config import settings

logger = logging.getLogger(__name__)

# Default demo administrator (development only). OTP login needs no password, so the
# account gets an unusable-password marker that verify_password() always rejects.
DEV_ADMIN_EMAIL = "admin@roaddistress.org"
LEGACY_PLACEHOLDER_HASH = "hashed_placeholder_admin"


def bootstrap_admin(db) -> None:
    """
    Ensures a first administrator exists so OTP login is possible.

    * development: user id 1 = admin@roaddistress.org (as before) if user 1 is missing.
    * production: nothing is auto-created unless BOOTSTRAP_ADMIN_EMAIL is set, in which case an
      admin with that e-mail is created if no such user exists.
    """
    from app.models.user import User
    from app.core.security import UNUSABLE_PASSWORD, normalize_email
    from app.core.roles import Role

    # The old startup seeded a literal placeholder "hash"; verify_password no longer honours it,
    # replace it with the explicit unusable-password marker so nothing in the DB looks like a password.
    db.execute(
        text("UPDATE users SET hashed_password = :marker WHERE hashed_password = :legacy"),
        {"marker": UNUSABLE_PASSWORD, "legacy": LEGACY_PLACEHOLDER_HASH},
    )
    db.commit()

    if settings.is_production:
        email = normalize_email(settings.BOOTSTRAP_ADMIN_EMAIL)
        if not email:
            logger.info("Production startup: BOOTSTRAP_ADMIN_EMAIL not set; no admin account is auto-created.")
            return
        from app.crud.user import get_user_by_email
        if get_user_by_email(db, email) is None:
            db.add(User(email=email, full_name="Administrator", hashed_password=UNUSABLE_PASSWORD, role=Role.ADMIN))
            db.commit()
            logger.info("Bootstrap administrator account created from BOOTSTRAP_ADMIN_EMAIL.")
        if get_user_by_email(db, DEV_ADMIN_EMAIL) is not None and email != DEV_ADMIN_EMAIL:
            logger.warning(
                "The default demo account %s still exists in this production database. "
                "Change its e-mail to a mailbox you control or delete it (see SECURITY.md).",
                DEV_ADMIN_EMAIL,
            )
        return

    admin_user = db.query(User).filter(User.id == 1).first()
    if not admin_user:
        db.add(User(
            id=1,
            email=DEV_ADMIN_EMAIL,
            full_name="Monitoring Engineer (ME)",
            hashed_password=UNUSABLE_PASSWORD,
            role=Role.ADMIN,
        ))
        db.commit()


REVIEWER_DEMO_PROJECT_NAME = "Demo Project (app review)"


def bootstrap_reviewer(db) -> None:
    """
    App-store reviewer account (see Settings.REVIEWER_EMAIL / REVIEWER_CODE). When both are set, makes sure a
    NON-ADMIN account with that e-mail exists and is a member of a small demo project, so a reviewer who signs in
    with the fixed code lands on something to look at. Never creates or promotes an administrator: if the address
    already belongs to an admin it is left alone and reviewer sign-in stays refused for it.
    """
    if not settings.reviewer_access_enabled:
        return

    from app.models.user import User
    from app.models.project import Project, ProjectMember
    from app.core.security import UNUSABLE_PASSWORD
    from app.core.roles import Role
    from app.crud.user import get_user_by_email

    email = settings.reviewer_email
    user = get_user_by_email(db, email)
    if user is None:
        user = User(email=email, full_name="App Reviewer", hashed_password=UNUSABLE_PASSWORD, role=Role.EMPLOYEE)
        db.add(user)
        db.commit()
        db.refresh(user)
        logger.info("Reviewer account created from REVIEWER_EMAIL.")
    elif user.role == Role.ADMIN:
        logger.error("REVIEWER_EMAIL belongs to an administrator: reviewer sign-in is refused for it. Use another address.")
        return

    project = db.query(Project).filter(Project.name == REVIEWER_DEMO_PROJECT_NAME).first()
    if project is None:
        owner = db.query(User).filter(User.role == Role.ADMIN).order_by(User.id).first() or user
        project = Project(
            name=REVIEWER_DEMO_PROJECT_NAME,
            description="Sample project for app-store review. Contains no real survey data.",
            highway_name="Demo Highway",
            highway_number="NH-00",
            starting_chainage="0.000",
            ending_chainage="5.000",
            state="Demo",
            owner_id=owner.id,
        )
        db.add(project)
        db.flush()
    is_member = db.query(ProjectMember).filter(
        ProjectMember.project_id == project.id, ProjectMember.user_id == user.id
    ).first()
    if is_member is None:
        db.add(ProjectMember(project_id=project.id, user_id=user.id))
    db.commit()
