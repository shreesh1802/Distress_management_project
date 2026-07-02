"""
API Routes for triggering and querying AI video detection pipeline and statistics.
"""

from typing import List, Dict, Any
from fastapi import APIRouter, Depends, BackgroundTasks, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.crud.video import get_video
from app.models.distress import RoadDistress
from app.schemas.distress import RoadDistressResponse
from app.services.pipeline.pipeline_manager import process_video
from app.services.ai.analytics_service import get_detection_analytics

router = APIRouter()


@router.post("/video/{video_id}", status_code=status.HTTP_202_ACCEPTED)
def trigger_video_detection(
    video_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
) -> Dict[str, Any]:
    """
    Trigger the object detection pipeline on an uploaded surveillance video.
    Executes frame extraction and YOLO predictions asynchronously in the background.
    """
    db_video = get_video(db, video_id=video_id)
    if not db_video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Video upload log with ID {video_id} not found."
        )

    # Idempotent start: if not already running or completed, launch task
    if db_video.processing_status not in ["processing", "completed"]:
        background_tasks.add_task(process_video, video_id=video_id)

    return {
        "status": "processing",
        "video_id": video_id,
        "message": "AI detection pipeline initiated in the background."
    }


@router.get("/results/{video_id}", response_model=List[RoadDistressResponse])
def get_video_detection_results(
    video_id: int,
    db: Session = Depends(get_db)
) -> List[RoadDistressResponse]:
    """
    Fetch all geo-tagged road distress anomalies detected from a specific video processing run.
    """
    db_video = get_video(db, video_id=video_id)
    if not db_video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Video upload log with ID {video_id} not found."
        )

    # Query distress anomalies linked to the target video_id
    results = db.query(RoadDistress).filter(RoadDistress.video_id == video_id).all()
    return results


@router.get("/summary", response_model=Dict[str, Any])
def get_detection_summary(db: Session = Depends(get_db)) -> Dict[str, Any]:
    """
    Retrieve aggregated analytical insights, distress distribution charts,
    confidence metrics, and per-video anomaly totals.
    """
    return get_detection_analytics(db)
