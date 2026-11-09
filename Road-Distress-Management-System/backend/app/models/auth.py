"""
Session authentication model. Login is Google sign-in via Firebase
(POST /auth/google); a successful sign-in issues one of these opaque,
DB-backed bearer tokens with an expiry (see app/services/session_service.py).
"""

from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column
from app.db.database import Base


class AuthToken(Base):
    """An opaque bearer session token issued after a successful Google sign-in."""
    __tablename__ = "auth_tokens"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    token: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
