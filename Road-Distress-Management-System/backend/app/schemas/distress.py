"""
Pydantic schemas for RoadDistress entity in the Road Distress Management System.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


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
    Properties required to create a new road distress log.
    """
    detected_at: Optional[datetime] = Field(None, description="Time the distress was detected")


class RoadDistressUpdate(BaseModel):
    """
    Properties for updating an existing road distress log.
    """
    distress_type: Optional[str] = Field(None, max_length=100)
    severity: Optional[str] = Field(None, max_length=50)
    confidence_score: Optional[float] = Field(None, ge=0.0, le=1.0)
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    image_url: Optional[str] = Field(None, max_length=512)
    status: Optional[str] = Field(None, max_length=50)
    detected_at: Optional[datetime] = None
    model_source: Optional[str] = Field(None, max_length=50)


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
