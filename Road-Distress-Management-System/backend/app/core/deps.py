"""
Auth dependencies: resolve the current user from a Bearer session token
(issued by /auth/google), re-check them against the Firestore allow-list,
and gate admin-only routes.
"""

import logging

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.user import User
from app.services.access_service import apply_entry, get_allowed_entry
from app.services.session_service import resolve_token

logger = logging.getLogger(__name__)

# auto_error=False so a missing/malformed header still gets our own 401
# message below; HTTPBearer also adds the "Authorize" button to /docs.
_bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Not authenticated")
    token = credentials.credentials.strip()
    user_id = resolve_token(db, token)
    if user_id is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Session expired or invalid, please log in again")
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User no longer exists")

    # Removing someone from allowedUsers in the Firebase console revokes an
    # existing session too, and role changes there apply without re-login
    # (both within access_service's cache window). If Firestore itself is
    # unreachable, keep the session working on the last synced role rather
    # than logging everyone out.
    try:
        entry = get_allowed_entry(user.email)
    except Exception:
        logger.warning("Couldn't reach the Firestore allow-list; using last synced role", exc_info=True)
        return user
    if entry is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Your access has been removed")
    return apply_entry(db, user, entry)


def require_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != "admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Admin access required")
    return user
