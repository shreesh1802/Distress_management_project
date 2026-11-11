"""
DB-backed opaque bearer session tokens, issued after a successful Google
sign-in (POST /auth/google) and resolved on every authenticated request
(app/core/deps.py). No JWT dependency -- a token is just a random row with
an expiry, which is enough for this app's scale.

Hardening (see SECURITY.md):
* only the SHA-256 hash of a token is stored; the raw token exists only in the login response and on the client,
  so a leaked database does not leak usable sessions;
* expired rows are purged opportunistically;
* ``revoke_token`` is server-side logout.
"""

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import delete
from sqlalchemy.orm import Session

from app.models.auth import AuthToken

TOKEN_TTL_DAYS = 30


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def hash_token(token: str) -> str:
    """SHA-256 hex digest -- the only form of a session token that is ever stored."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_token(db: Session, user_id: int) -> str:
    """Creates a session and returns the RAW token (shown to the client once; only its hash is stored)."""
    now = _utcnow()
    db.execute(delete(AuthToken).where(AuthToken.expires_at < now))  # purge expired sessions
    token = secrets.token_hex(32)
    db.add(AuthToken(token=hash_token(token), user_id=user_id, expires_at=now + timedelta(days=TOKEN_TTL_DAYS)))
    db.commit()
    return token


def resolve_token(db: Session, token: str) -> Optional[int]:
    """Returns the user_id for a valid, unexpired token, else None."""
    if not token:
        return None
    row = db.query(AuthToken).filter(AuthToken.token == hash_token(token)).first()
    if row is None:
        return None
    if _aware(row.expires_at) < _utcnow():
        return None
    return row.user_id


def revoke_token(db: Session, token: str) -> bool:
    """Server-side logout: deletes the presented session. True if a row was removed."""
    if not token:
        return False
    result = db.execute(delete(AuthToken).where(AuthToken.token == hash_token(token)))
    db.commit()
    return result.rowcount > 0
