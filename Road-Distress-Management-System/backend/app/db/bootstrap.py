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
