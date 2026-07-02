"""
UploadedVideo database model for the Road Distress Management System.
"""

from datetime import datetime
from typing import Optional, TYPE_CHECKING
from sqlalchemy import String, DateTime, ForeignKey, Float
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.database import Base

if TYPE_CHECKING:
    from app.models.user import User


class UploadedVideo(Base):
    """
    UploadedVideo model representing files uploaded by users to detect road distress.
    """
    __tablename__ = "uploaded_videos"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    filename: Mapped[str] = mapped_column(String(255), nullable=False)
    filepath: Mapped[str] = mapped_column(String(512), nullable=True)
    upload_timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        server_default=func.now(), 
        nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        server_default=func.now(), 
        nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        server_default=func.now(), 
        onupdate=func.now(),
        nullable=False
    )
    processing_status: Mapped[str] = mapped_column(String(50), default="pending", nullable=False)
    processing_started_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    processing_completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    processing_duration: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    processed_filepath: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    processed_video_path: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)

    uploader_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), 
        nullable=True
    )

    # Relationships
    uploader: Mapped[Optional["User"]] = relationship(
        "User",
        back_populates="uploaded_videos"
    )
