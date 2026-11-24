"""
Field notes: what a surveyor adds by hand during a live session -- a snapshot of the camera picture and / or a
voice note (with an optional typed caption) -- for something the camera detection missed or got wrong.
Each note belongs to the live session's report (an ``UploadedVideo`` row), so it appears in that report.
"""

from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.db.database import Base

# transcript_status: "none" (no voice note), "pending", "done", "failed", "unavailable"
TRANSCRIPT_NONE = "none"


class SessionObservation(Base):
    __tablename__ = "session_observations"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    video_id: Mapped[int] = mapped_column(
        ForeignKey("uploaded_videos.id", ondelete="CASCADE"), nullable=False, index=True
    )
    created_by_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    image_path: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    audio_path: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    audio_filename: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    audio_duration_seconds: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    transcript: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    transcript_status: Mapped[str] = mapped_column(String(20), default=TRANSCRIPT_NONE, nullable=False)

    latitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
