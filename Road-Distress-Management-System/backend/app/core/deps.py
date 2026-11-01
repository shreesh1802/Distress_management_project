"""
Auth dependencies: resolve the current user from a Bearer session token
(issued by /auth/verify-otp), and gate admin-only routes.
"""

from typing import Optional

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.roles import Role
from app.db.session import get_db
from app.models.user import User
from app.services.otp_service import resolve_token


def extract_bearer_token(authorization: Optional[str]) -> Optional[str]:
    """Returns the raw token from an ``Authorization: Bearer <token>`` header, else None."""
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    token = authorization.split(" ", 1)[1].strip()
    return token or None


def user_for_token(db: Session, token: Optional[str]) -> Optional[User]:
    """Resolves a raw session token to its User (or None)."""
    if not token:
        return None
    user_id = resolve_token(db, token)
    if user_id is None:
        return None
    return db.get(User, user_id)


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
    return user


def require_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != Role.ADMIN:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Admin access required")
    return user


def registration_gate(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> Optional[User]:
    """
    Guards POST /auth/register. Open self-registration (ALLOW_SELF_REGISTRATION, default on only in
    development) lets any mailbox owner obtain a working login, so everywhere else registering an account
    needs an admin session: 401 without a valid session, 403 for non-admins.
    """
    if settings.allow_self_registration:
        return None
    user = user_for_token(db, extract_bearer_token(authorization))
    if user is None:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if user.role != Role.ADMIN:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Admin access required")
    return user
