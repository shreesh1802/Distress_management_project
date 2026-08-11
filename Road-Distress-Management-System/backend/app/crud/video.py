"""
CRUD operations for the UploadedVideo entity.
Refactored to reference the updated model field names: filename, filepath, uploader_id.
"""

from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.video import UploadedVideo
from app.schemas.video import UploadedVideoCreate, UploadedVideoUpdate


def get_video(db: Session, video_id: int) -> Optional[UploadedVideo]:
    """
    Retrieve a single uploaded video record by ID.
    """
    return db.query(UploadedVideo).filter(UploadedVideo.id == video_id).first()


def get_videos(db: Session, skip: int = 0, limit: int = 100) -> List[UploadedVideo]:
    """
    Retrieve a list of uploaded video records with pagination, most recent
    first. Without an explicit order, SQL gives no ordering guarantee at all
    -- the frontend's "default to the first video in the list" behavior (the
    Video Review screen, when no specific video ID is requested) would show
    whatever arbitrary row the database happened to return first, not the
    most recently uploaded/processed one.
    """
    return (
        db.query(UploadedVideo)
        .order_by(UploadedVideo.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def create_video(db: Session, video_in: UploadedVideoCreate) -> UploadedVideo:
    """
    Create a new uploaded video record.
    """
    db_video = UploadedVideo(
        filename=video_in.filename,
        filepath=video_in.filepath,
        processing_status=video_in.processing_status,
        uploader_id=video_in.uploader_id,
    )
    db.add(db_video)
    db.commit()
    db.refresh(db_video)
    return db_video


def update_video(db: Session, video_id: int, video_in: UploadedVideoUpdate) -> Optional[UploadedVideo]:
    """
    Update the status or metadata of an uploaded video record.
    """
    db_video = get_video(db, video_id)
    if not db_video:
        return None

    update_data = video_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_video, field, value)

    db.add(db_video)
    db.commit()
    db.refresh(db_video)
    return db_video


def delete_video(db: Session, video_id: int) -> Optional[UploadedVideo]:
    """
    Delete an uploaded video record by ID.
    """
    db_video = get_video(db, video_id)
    if db_video:
        db.delete(db_video)
        db.commit()
    return db_video
