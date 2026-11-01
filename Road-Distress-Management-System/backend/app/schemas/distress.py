"""
Pydantic schemas for RoadDistress entity in the Road Distress Management System.
"""

from datetime import datetime
from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator

Severity = Literal["low", "medium", "high", "critical"]
ModelSource = Literal["road", "signage"]


def _validate_relative_ref(value: Optional[str]) -> Optional[str]:
    """Image references from clients must be plain relative paths (no scheme, no absolute path, no ..)."""
    if value is None:
        return value
    v = value.replace("\\", "/")
    if v.startswith("/") or ".." in v.split("/") or "://" in v or v[1:2] == ":" or "\x00" in v:
        raise ValueError("image_url must be a relative path inside uploads/")
    return value


class RoadDistressBase(BaseModel):
    """
    Shared base schema properties for Road Distress.
    """
    distress_type: str = Field(..., max_length=100, description="Type of distress, e.g. pothole, crack")
    severity: str = Field(..., max_length=50, description="Severity level: low, medium, high")
    confidence_score: float = Field(..., ge=0.0, le=1.0, description="Model prediction confidence score")
    latitude: float = Field(..., description="GPS Latitude coordinate")
    longitude: float = Field(..., description="GPS Longitude coordinate")
    image_url: Optional[str] = Field(None, max_length=512, description="Optional URL to distress image frame")
    status: str = Field("detected", max_length=50, description="Status of the distress record")
    video_id: Optional[int] = Field(None, description="Associated video ID")
    frame_number: Optional[int] = Field(None, description="Frame number within video")
    video_timestamp: Optional[float] = Field(None, description="Timestamp offset in seconds within video")
    source_type: Optional[str] = Field("manual", max_length=50, description="Source: video, image, manual")
    detection_image_path: Optional[str] = Field(None, description="Path to bounding box detection image file")
    model_source: Optional[str] = Field("road", max_length=50, description="Model source: road or signage")
    first_frame: Optional[int] = Field(None, description="First frame number where distress was seen")
    last_frame: Optional[int] = Field(None, description="Last frame number where distress was seen")
    frames_visible: Optional[int] = Field(None, description="Total frames distress was visible")


class RoadDistressCreate(RoadDistressBase):
    """
    INTERNAL creation schema (the AI tracker writes ``detection_image_path`` through it).
    Never bind it directly to an HTTP route -- use RoadDistressClientCreate.
    """
    detected_at: Optional[datetime] = Field(None, description="Time the distress was detected")


class RoadDistressClientCreate(BaseModel):
    """
    Client-facing creation schema (POST /distress/). Unlike the internal model it has no
    ``detection_image_path`` (a server-side file reference) and constrains severity,
    coordinates and string lengths.
    """
    distress_type: str = Field(..., min_length=1, max_length=100)
    severity: Severity
    confidence_score: float = Field(..., ge=0.0, le=1.0, allow_inf_nan=False)
    latitude: float = Field(..., ge=-90, le=90, allow_inf_nan=False)
    longitude: float = Field(..., ge=-180, le=180, allow_inf_nan=False)
    image_url: Optional[str] = Field(None, max_length=512)
    status: str = Field("detected", max_length=50)
    video_id: Optional[int] = None
    frame_number: Optional[int] = Field(None, ge=0)
    video_timestamp: Optional[float] = Field(None, ge=0, allow_inf_nan=False)
    source_type: Optional[str] = Field("manual", max_length=50)
    model_source: Optional[ModelSource] = "road"
    first_frame: Optional[int] = Field(None, ge=0)
    last_frame: Optional[int] = Field(None, ge=0)
    frames_visible: Optional[int] = Field(None, ge=0)
    detected_at: Optional[datetime] = None

    _check_image_url = field_validator("image_url")(_validate_relative_ref)


class RoadDistressUpdate(BaseModel):
    """
    Properties for updating an existing road distress log.
    """
    distress_type: Optional[str] = Field(None, min_length=1, max_length=100)
    severity: Optional[Severity] = None
    confidence_score: Optional[float] = Field(None, ge=0.0, le=1.0, allow_inf_nan=False)
    latitude: Optional[float] = Field(None, ge=-90, le=90, allow_inf_nan=False)
    longitude: Optional[float] = Field(None, ge=-180, le=180, allow_inf_nan=False)
    image_url: Optional[str] = Field(None, max_length=512)
    status: Optional[str] = Field(None, max_length=50)
    detected_at: Optional[datetime] = None
    model_source: Optional[ModelSource] = None

    _check_image_url = field_validator("image_url")(_validate_relative_ref)


class RoadDistressResponse(RoadDistressBase):
    """
    API response representation of a Road Distress.
    """
    id: int
    detected_at: datetime
    created_at: datetime
    updated_at: datetime
    video_timestamp_formatted: Optional[str] = None
    tracking_id: Optional[int] = None
    box_width: Optional[float] = None
    box_height: Optional[float] = None
    box_area: Optional[float] = None
    crack_length: Optional[float] = None
    pothole_diameter: Optional[float] = None
    affected_area: Optional[float] = None
    first_frame: Optional[int] = None
    last_frame: Optional[int] = None
    first_timestamp: Optional[float] = None
    last_timestamp: Optional[float] = None
    detection_count: Optional[int] = None
    frames_visible: Optional[int] = None
    damage_percentage_of_frame: Optional[float] = None

    model_config = ConfigDict(from_attributes=True)
