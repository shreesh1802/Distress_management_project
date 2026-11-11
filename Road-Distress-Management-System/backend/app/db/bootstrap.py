"""
Development-only bootstrap, shared by the app startup (app/main.py) and the manual
initializer (app/db/init_db.py).

Login is Google sign-in and who may sign in is the Firestore ``allowedUsers`` collection (admins included), so
nothing is created in production. In development user id 1 (admin@roaddistress.org) is seeded because the
demo data and a few scripts expect it; it has an unusable password (verify_password() always rejects it).
"""

import logging

from sqlalchemy import text

from app.core.config import settings

logger = logging.getLogger(__name__)

# Default demo administrator (development only).
DEV_ADMIN_EMAIL = "admin@roaddistress.org"
LEGACY_PLACEHOLDER_HASH = "hashed_placeholder_admin"


def bootstrap_admin(db) -> None:
    """
    * development: user id 1 = admin@roaddistress.org (as before) if user 1 is missing.
    * production: nothing is auto-created. Administrators are the people with role "admin" in the Firestore
      allow-list; they are created in the users table on their first Google sign-in.
    """
    from app.models.user import User
    from app.core.security import UNUSABLE_PASSWORD
    from app.core.roles import Role

    # The old startup seeded a literal placeholder "hash"; verify_password no longer honours it,
    # replace it with the explicit unusable-password marker so nothing in the DB looks like a password.
    db.execute(
        text("UPDATE users SET hashed_password = :marker WHERE hashed_password = :legacy"),
        {"marker": UNUSABLE_PASSWORD, "legacy": LEGACY_PLACEHOLDER_HASH},
    )
    db.commit()

    if settings.is_production:
        from app.crud.user import get_user_by_email
        if get_user_by_email(db, DEV_ADMIN_EMAIL) is not None:
            logger.warning(
                "The default demo account %s still exists in this production database. It cannot sign in "
                "unless that address is on the Firestore allow-list; delete it (see SECURITY.md).",
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
