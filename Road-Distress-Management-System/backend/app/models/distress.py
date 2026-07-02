"""
RoadDistress database model for the Road Distress Management System.
"""

from datetime import datetime
from typing import List, Optional, TYPE_CHECKING
from sqlalchemy import String, Float, DateTime, ForeignKey, Integer
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.database import Base

if TYPE_CHECKING:
    from app.models.maintenance import MaintenanceTask
    from app.models.video import UploadedVideo


class RoadDistress(Base):
    """
    RoadDistress model representing detected road distress instances (potholes, cracks, ruts, etc.).
    """
    __tablename__ = "road_distresses"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    distress_type: Mapped[str] = mapped_column(String(100), nullable=False)
    severity: Mapped[str] = mapped_column(String(50), nullable=False)
    confidence_score: Mapped[float] = mapped_column(Float, nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    image_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    detected_at: Mapped[datetime] = mapped_column(
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
    status: Mapped[str] = mapped_column(String(50), default="detected", nullable=False)
    
    # Video pipeline metadata fields
    video_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("uploaded_videos.id", ondelete="SET NULL"), 
        nullable=True
    )
    frame_number: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    video_timestamp: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    source_type: Mapped[Optional[str]] = mapped_column(String(50), default="manual", nullable=True)
    detection_image_path: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    tracking_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    db_first_frame: Mapped[Optional[int]] = mapped_column("first_frame", Integer, nullable=True)
    db_last_frame: Mapped[Optional[int]] = mapped_column("last_frame", Integer, nullable=True)
    db_frames_visible: Mapped[Optional[int]] = mapped_column("frames_visible", Integer, nullable=True)

    # Relationships
    video: Mapped[Optional["UploadedVideo"]] = relationship("UploadedVideo")
    maintenance_tasks: Mapped[List["MaintenanceTask"]] = relationship(
        "MaintenanceTask",
        back_populates="distress",
        cascade="all, delete-orphan"
    )

    @property
    def video_timestamp_formatted(self) -> Optional[str]:
        if self.video_timestamp is None:
            return None
        from app.services.ai.utils import format_seconds_to_hhmmss_mmm
        return format_seconds_to_hhmmss_mmm(self.video_timestamp)

    @property
    def first_frame(self) -> Optional[int]:
        if self.db_first_frame is not None:
            return self.db_first_frame
        return self.frame_number

    @property
    def first_timestamp(self) -> Optional[float]:
        return self.video_timestamp

    @property
    def last_frame(self) -> Optional[int]:
        if self.db_last_frame is not None:
            return self.db_last_frame
        if not self.detection_image_path:
            return self.frame_number
        if "?" in self.detection_image_path:
            try:
                params = dict(q.split("=") for q in self.detection_image_path.split("?")[1].split("&"))
                return int(params.get("last_frame", self.frame_number))
            except Exception:
                pass
        return self.frame_number

    @property
    def last_timestamp(self) -> Optional[float]:
        if not self.detection_image_path:
            return self.video_timestamp
        if "?" in self.detection_image_path:
            try:
                params = dict(q.split("=") for q in self.detection_image_path.split("?")[1].split("&"))
                return float(params.get("last_timestamp", self.video_timestamp))
            except Exception:
                pass
        return self.video_timestamp

    @property
    def frames_visible(self) -> Optional[int]:
        if self.db_frames_visible is not None:
            return self.db_frames_visible
        return self.detection_count

    @property
    def detection_count(self) -> int:
        if not self.detection_image_path:
            return 1
        if "?" in self.detection_image_path:
            try:
                params = dict(q.split("=") for q in self.detection_image_path.split("?")[1].split("&"))
                return int(params.get("detection_count", 1))
            except Exception:
                pass
        return 1

    @property
    def box_width(self) -> float:
        if self.detection_image_path and "?" in self.detection_image_path:
            try:
                params = dict(q.split("=") for q in self.detection_image_path.split("?")[1].split("&"))
                if "damage_width_pixels" in params:
                    return float(params["damage_width_pixels"])
            except Exception:
                pass
        from app.services.ai.utils import estimate_damage_metrics
        metrics = estimate_damage_metrics(self.severity, self.distress_type)
        return metrics["damage_width_pixels"]

    @property
    def box_height(self) -> float:
        if self.detection_image_path and "?" in self.detection_image_path:
            try:
                params = dict(q.split("=") for q in self.detection_image_path.split("?")[1].split("&"))
                if "damage_height_pixels" in params:
                    return float(params["damage_height_pixels"])
            except Exception:
                pass
        from app.services.ai.utils import estimate_damage_metrics
        metrics = estimate_damage_metrics(self.severity, self.distress_type)
        return metrics["damage_height_pixels"]

    @property
    def box_area(self) -> float:
        if self.detection_image_path and "?" in self.detection_image_path:
            try:
                params = dict(q.split("=") for q in self.detection_image_path.split("?")[1].split("&"))
                if "damage_area_pixels" in params:
                    return float(params["damage_area_pixels"])
            except Exception:
                pass
        from app.services.ai.utils import estimate_damage_metrics
        metrics = estimate_damage_metrics(self.severity, self.distress_type)
        return metrics["damage_area_pixels"]

    @property
    def damage_percentage_of_frame(self) -> float:
        if self.detection_image_path and "?" in self.detection_image_path:
            try:
                params = dict(q.split("=") for q in self.detection_image_path.split("?")[1].split("&"))
                if "damage_percentage_of_frame" in params:
                    return float(params["damage_percentage_of_frame"])
            except Exception:
                pass
        from app.services.ai.utils import estimate_damage_metrics
        metrics = estimate_damage_metrics(self.severity, self.distress_type)
        return metrics["damage_percentage_of_frame"]

    @property
    def crack_length(self) -> Optional[float]:
        if "crack" in self.distress_type.lower():
            from app.core.pipeline_config import PIXEL_TO_METER_SCALE
            val = max(self.box_width, self.box_height) * PIXEL_TO_METER_SCALE
            return round(val, 3)
        return None

    @property
    def pothole_diameter(self) -> Optional[float]:
        if "pothole" in self.distress_type.lower():
            from app.core.pipeline_config import PIXEL_TO_METER_SCALE
            val = ((self.box_width + self.box_height) / 2.0) * PIXEL_TO_METER_SCALE
            return round(val, 3)
        return None

    @property
    def affected_area(self) -> float:
        from app.core.pipeline_config import PIXEL_TO_METER_SCALE
        val = self.box_area * (PIXEL_TO_METER_SCALE ** 2)
        return round(val, 4)
