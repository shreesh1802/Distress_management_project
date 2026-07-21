"""
CRUD operations for the RoadDistress entity.
"""

from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from app.models.distress import RoadDistress
from app.schemas.distress import RoadDistressCreate, RoadDistressUpdate


import logging

logger = logging.getLogger(__name__)


def get_distress(db: Session, distress_id: int) -> Optional[RoadDistress]:
    """
    Retrieve a single road distress log by ID.
    """
    return db.query(RoadDistress).filter(RoadDistress.id == distress_id).first()


def get_distresses(db: Session, skip: int = 0, limit: int = 100) -> List[RoadDistress]:
    """
    Retrieve a list of road distress logs with pagination.
    """
    return db.query(RoadDistress).offset(skip).limit(limit).all()


def create_distress(db: Session, distress_in: RoadDistressCreate) -> RoadDistress:
    """
    Create a new road distress log.
    """
    db_distress = RoadDistress(
        distress_type=distress_in.distress_type,
        severity=distress_in.severity,
        confidence_score=distress_in.confidence_score,
        latitude=distress_in.latitude,
        longitude=distress_in.longitude,
        image_url=distress_in.image_url,
        status=distress_in.status,
        detected_at=distress_in.detected_at or datetime.now(),
        video_id=distress_in.video_id,
        frame_number=distress_in.frame_number,
        video_timestamp=distress_in.video_timestamp,
        source_type=distress_in.source_type,
        detection_image_path=distress_in.detection_image_path,
        db_first_frame=distress_in.first_frame,
        db_last_frame=distress_in.last_frame,
        db_frames_visible=distress_in.frames_visible,
        model_source=distress_in.model_source,
    )
    try:
        db.add(db_distress)
        db.commit()
        db.refresh(db_distress)
    except Exception as e:
        db.rollback()
        logger.error(f"Error creating distress: {e}", exc_info=True)
        raise e
    return db_distress


def update_distress(db: Session, distress_id: int, distress_in: RoadDistressUpdate) -> Optional[RoadDistress]:
    """
    Update an existing road distress log.
    """
    db_distress = get_distress(db, distress_id)
    if not db_distress:
        return None

    update_data = distress_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_distress, field, value)

    db.add(db_distress)
    db.commit()
    db.refresh(db_distress)
    return db_distress


def delete_distress(db: Session, distress_id: int) -> Optional[RoadDistress]:
    """
    Delete a road distress log by ID.
    """
    db_distress = get_distress(db, distress_id)
    if db_distress:
        db.delete(db_distress)
        db.commit()
    return db_distress
