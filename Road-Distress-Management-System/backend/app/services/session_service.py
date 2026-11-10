"""
DB-backed opaque bearer session tokens, issued after a successful Google
sign-in (POST /auth/google) and resolved on every authenticated request
(app/core/deps.py). No JWT dependency -- a token is just a random row with
an expiry, which is enough for this app's scale.
"""

import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.models.auth import AuthToken

TOKEN_TTL_DAYS = 30


def issue_token(db: Session, user_id: int) -> str:
    token = secrets.token_hex(32)
    expires_at = datetime.now(timezone.utc) + timedelta(days=TOKEN_TTL_DAYS)
    db.add(AuthToken(token=token, user_id=user_id, expires_at=expires_at))
    db.commit()
    return token


def resolve_token(db: Session, token: str) -> int | None:
    """Returns the user_id for a valid, unexpired token, else None."""
    row = db.query(AuthToken).filter(AuthToken.token == token).first()
    if row is None:
        return None
    expires_at = row.expires_at if row.expires_at.tzinfo else row.expires_at.replace(tzinfo=timezone.utc)
    if expires_at < datetime.now(timezone.utc):
        return None
    return row.user_id
