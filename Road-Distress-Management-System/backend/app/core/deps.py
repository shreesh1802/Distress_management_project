"""
Auth dependencies: resolve the current user from a Bearer session token
(issued by /auth/google), re-check them against the Firestore allow-list,
and gate admin-only routes.
"""

import logging
from typing import Optional

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.core.roles import Role
from app.db.session import get_db
from app.models.user import User
from app.services.access_service import apply_entry, get_allowed_entry
from app.services.session_service import resolve_token

logger = logging.getLogger(__name__)


def extract_bearer_token(authorization: Optional[str]) -> Optional[str]:
    """Returns the raw token from an ``Authorization: Bearer <token>`` header, else None."""
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    token = authorization.split(" ", 1)[1].strip()
    return token or None


def _still_allowed(db: Session, user: User) -> Optional[User]:
    """
    Re-checks the person against the Firestore allow-list. Removing someone from allowedUsers in the Firebase
    console revokes an existing session too, and role changes there apply without re-login (both within
    access_service's cache window). If Firestore itself is unreachable, keep the session working on the last
    synced role rather than logging everyone out. Returns None when the person has been removed.
    """
    try:
        entry = get_allowed_entry(user.email)
    except Exception:
        logger.warning("Couldn't reach the Firestore allow-list; using last synced role")
        return user
    if entry is None:
        return None
    return apply_entry(db, user, entry)


def user_for_token(db: Session, token: Optional[str]) -> Optional[User]:
    """Resolves a raw session token to its User (or None) - used by the WebSocket endpoints as well."""
    if not token:
        return None
    user_id = resolve_token(db, token)
    if user_id is None:
        return None
    user = db.get(User, user_id)
    return _still_allowed(db, user) if user is not None else None


def get_current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> User:
    token = extract_bearer_token(authorization)
    if token is None:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user_id = resolve_token(db, token)
    if user_id is None:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Session expired or invalid, please log in again",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "User no longer exists",
            headers={"WWW-Authenticate": "Bearer"},
        )

    allowed = _still_allowed(db, user)
    if allowed is None:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Your access has been removed",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return allowed


def require_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != Role.ADMIN:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Admin access required")
    return user
