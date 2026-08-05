"""
Video service layer handling file storage, validation, and metadata processing
for the Road Distress Management System.
"""

import os
import re
import uuid
import logging
from typing import List, Optional
from fastapi import UploadFile, HTTPException, status
from sqlalchemy.orm import Session

from app.models.video import UploadedVideo
from app.schemas.video import UploadedVideoCreate, UploadedVideoUpdate
from app.crud.video import (
    get_video as crud_get_video,
    get_videos as crud_get_videos,
    create_video as crud_create_video,
    delete_video as crud_delete_video
)

logger = logging.getLogger(__name__)

# Enforce 100MB max file size
MAX_FILE_SIZE_BYTES = 100 * 1024 * 1024

# Setup target uploads directory relative to backend root
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads", "videos")
os.makedirs(UPLOAD_DIR, exist_ok=True)


def sanitize_filename(filename: str) -> str:
    """
    Sanitize filename to prevent directory traversal and remove unsafe characters.
    """
    # Extract only the base name in case of path injection attempts
    base = os.path.basename(filename)
    # Replace any character that is not alphanumeric, dot, dash, or underscore
    sanitized = re.sub(r"[^a-zA-Z0-9_\.\-]", "_", base)
    # Fallback if empty or purely special characters
    if not sanitized or sanitized.startswith("."):
        sanitized = f"upload_{uuid.uuid4().hex[:8]}" + os.path.splitext(base)[1]
    return sanitized


async def handle_video_upload(
    db: Session, 
    file: UploadFile, 
    uploader_id: Optional[int] = None
) -> UploadedVideo:
    """
    Validates, saves to disk in chunks, and registers video metadata in DB.
    """
    # 1. Validate extension
    allowed_extensions = {".mp4", ".avi", ".mov"}
    original_filename = file.filename or "unnamed_video.mp4"
    ext = os.path.splitext(original_filename)[1].lower()
    
    if ext not in allowed_extensions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid video format. Supported formats: {', '.join(allowed_extensions)}"
        )

    # 2. Check if content_type matches video format (if provided)
    allowed_mimes = {"video/mp4", "video/x-msvideo", "video/quicktime", "video/avi", "video/mpeg"}
    if file.content_type and file.content_type not in allowed_mimes:
        # Warn but proceed if extension matches, since CLI or client content-types can be generic
        logger.warning(f"Video mime-type warning: {file.content_type} uploaded for {original_filename}")

    # 3. Generate unique filename for storage
    sanitized = sanitize_filename(original_filename)
    unique_filename = f"{uuid.uuid4().hex}_{sanitized}"
    target_filepath = os.path.join(UPLOAD_DIR, unique_filename)

    # Re-ensure the directory exists at save time, not just at import time:
    # module-level `os.makedirs(UPLOAD_DIR, exist_ok=True)` above only runs
    # once when this module is first imported, so if the directory is
    # removed afterward (e.g. by a data-reset script) while the server
    # keeps running, every upload fails with ENOENT until the process is
    # restarted. This makes a save resilient to that without requiring one.
    os.makedirs(UPLOAD_DIR, exist_ok=True)

    # 4. Stream file in chunks to disk to enforce file size and preserve memory
    total_bytes = 0
    try:
        with open(target_filepath, "wb") as buffer:
            while True:
                # Read 1MB chunk
                chunk = await file.read(1024 * 1024)
                if not chunk:
                    break
                total_bytes += len(chunk)
                
                if total_bytes > MAX_FILE_SIZE_BYTES:
                    # Close and clean up file on size violation
                    buffer.close()
                    if os.path.exists(target_filepath):
                        os.remove(target_filepath)
                    raise HTTPException(
                        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        detail=f"Video file exceeds maximum size limit of 100MB."
                    )
                buffer.write(chunk)
    except HTTPException:
        # Re-raise size limit HTTPExceptions
        raise
    except Exception as e:
        # Clean up any partially written files on generic write failure
        if os.path.exists(target_filepath):
            os.remove(target_filepath)
        logger.error(f"Failed to write video file to disk: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Could not save video file to server disk: {str(e)}"
        )

    # 5. Populate database record
    # Calculate the path relative to the backend root workspace directory
    relative_filepath = os.path.relpath(target_filepath, BASE_DIR).replace("\\", "/")
    
    try:
        video_in = UploadedVideoCreate(
            filename=original_filename,
            filepath=relative_filepath,
            uploader_id=uploader_id,
            processing_status="pending"
        )
        return crud_create_video(db, video_in=video_in)
    except Exception as e:
        # Clean up video file on database insertion failure
        if os.path.exists(target_filepath):
            os.remove(target_filepath)
        logger.error(f"Database insertion failed for video: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to register video metadata in the database."
        )


def retrieve_video_metadata(db: Session, video_id: int) -> UploadedVideo:
    """
    Fetch metadata of a single video record by ID.
    """
    video = crud_get_video(db, video_id=video_id)
    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Video record with ID {video_id} not found."
        )
    return video


def retrieve_videos_list(db: Session, skip: int = 0, limit: int = 100) -> List[UploadedVideo]:
    """
    Fetch all video metadata records with pagination.
    """
    return crud_get_videos(db, skip=skip, limit=limit)


def remove_video(db: Session, video_id: int) -> UploadedVideo:
    """
    Deletes the video metadata from DB and removes its physical file from disk.
    """
    # 1. Retrieve the metadata first to know the filepath
    video = retrieve_video_metadata(db, video_id=video_id)
    
    # 2. Delete database record
    crud_delete_video(db, video_id=video_id)

    # 3. Delete file from disk
    if video.filepath:
        full_path = os.path.join(BASE_DIR, video.filepath)
        if os.path.exists(full_path):
            try:
                os.remove(full_path)
                logger.info(f"Successfully deleted video file from disk: {full_path}")
            except Exception as e:
                logger.error(f"Failed to delete video file {full_path} from disk: {e}")
        else:
            logger.warning(f"Video file not found on disk during deletion: {full_path}")

    # Delete processed annotated video file from disk
    if getattr(video, "processed_filepath", None):
        processed_full_path = os.path.join(BASE_DIR, video.processed_filepath)
        if os.path.exists(processed_full_path):
            try:
                os.remove(processed_full_path)
                logger.info(f"Successfully deleted processed video file from disk: {processed_full_path}")
            except Exception as e:
                logger.error(f"Failed to delete processed video file {processed_full_path} from disk: {e}")

    return video
