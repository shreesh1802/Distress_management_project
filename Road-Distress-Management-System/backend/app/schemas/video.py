"""
Pydantic schemas for UploadedVideo entity in the Road Distress Management System.
Supports both new /api/v1/videos/ schemas and legacy /api/v1/upload/ compatibility.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field, AliasChoices


class UploadedVideoBase(BaseModel):
    """
    Shared base schema properties for the updated Uploaded Video model.
    """
    filename: str = Field(..., max_length=255, description="Name of the video file")
    filepath: Optional[str] = Field(None, max_length=512, description="Physical path of the video file on disk")
    processing_status: str = Field("pending", max_length=50, description="Status of video processing: pending, processing, completed, failed")
    uploader_id: Optional[int] = Field(None, description="ID of the user who uploaded the video")
    processing_started_at: Optional[datetime] = Field(None, description="Start timestamp of video AI pipeline")
    processing_completed_at: Optional[datetime] = Field(None, description="End timestamp of video AI pipeline")
    processing_duration: Optional[float] = Field(None, description="Duration in seconds of video AI pipeline")
    processed_filepath: Optional[str] = Field(None, max_length=512, description="Physical path of the generated processed annotated video file")
    processed_video_path: Optional[str] = Field(None, max_length=512, description="Physical path of the final annotated MP4 video file")


class UploadedVideoCreate(UploadedVideoBase):
    """
    Properties required to register a new uploaded video log.
    """
    pass


class UploadedVideoUpdate(BaseModel):
    """
    Properties for updating processing status or details of a video.
    """
    processing_status: Optional[str] = Field(None, max_length=50)
    filepath: Optional[str] = Field(None, max_length=512)
    filename: Optional[str] = Field(None, max_length=255)
    uploader_id: Optional[int] = Field(None)
    processing_started_at: Optional[datetime] = None
    processing_completed_at: Optional[datetime] = None
    processing_duration: Optional[float] = None
    processed_filepath: Optional[str] = Field(None, max_length=512)
    processed_video_path: Optional[str] = Field(None, max_length=512)


class UploadedVideoResponse(UploadedVideoBase):
    """
    API response representation of an Uploaded Video.
    """
    id: int
    upload_timestamp: datetime
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# =====================================================================
# Legacy Compatibility Schemas (for /api/v1/upload/ and test_user_crud)
# =====================================================================

class LegacyUploadedVideoCreate(BaseModel):
    """
    Legacy creation schema mapping file_name and uploaded_by.
    """
    file_name: str = Field(..., max_length=255, description="Name of the video file")
    processing_status: str = Field("pending", max_length=50, description="Status of video processing")
    uploaded_by: Optional[int] = Field(None, description="ID of the user who uploaded the video")


class LegacyUploadedVideoResponse(BaseModel):
    """
    Legacy response schema that returns file_name, upload_time, and uploaded_by.
    Uses Pydantic AliasChoices to populate fields from the renamed model attributes.
    """
    id: int
    file_name: str = Field(
        ..., 
        validation_alias=AliasChoices("file_name", "filename"), 
        serialization_alias="file_name"
    )
    upload_time: datetime = Field(
        ..., 
        validation_alias=AliasChoices("upload_time", "upload_timestamp"), 
        serialization_alias="upload_time"
    )
    processing_status: str
    uploaded_by: Optional[int] = Field(
        None, 
        validation_alias=AliasChoices("uploaded_by", "uploader_id"), 
        serialization_alias="uploaded_by"
    )
    processing_started_at: Optional[datetime] = None
    processing_completed_at: Optional[datetime] = None
    processing_duration: Optional[float] = None
    processed_filepath: Optional[str] = None
    processed_video_path: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(
        from_attributes=True, 
        populate_by_name=True
    )
