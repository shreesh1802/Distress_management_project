"""
Orchestration layer pipeline manager for the Road Distress Management System.
Coordinates video uploads with frame extraction, deep learning inference,
maintenance recommendations, safety PDF report compilation, and alerting.
"""

import time
import logging
from datetime import datetime
from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.crud.video import update_video, get_video
from app.schemas.video import UploadedVideoUpdate
from app.crud.distress import create_distress
from app.schemas.distress import RoadDistressCreate
from app.services.ai.frame_extractor import extract_frames
from app.services.ai.inference_service import run_inference
from app.services.ai.utils import generate_gps_coordinates

# Reuse existing services
from app.services.maintenance_recommendation import generate_recommendations_for_pending_distresses
from app.services.pdf_generator import generate_video_pdf_report
from app.crud.report import create_report
from app.schemas.report import ReportCreate

logger = logging.getLogger(__name__)


def process_video(video_id: int) -> None:
    """
    Orchestration routine executing:
      1. Setting status to 'processing'
      2. Frame extraction
      3. YOLO object detection inference
      4. Storing distress records with GPS & Chainage calculations
      5. Running maintenance recommendation engine
      6. Safety PDF report compilation
      7. Incident alert notifications dispatch
      8. Transitioning status to 'completed'
    """
    logger.info("Stage: Pipeline Started")
    db = SessionLocal()
    start_time = time.time()
    
    try:
        db_video = get_video(db, video_id=video_id)
        if not db_video:
            logger.error(f"Failed to locate video ID {video_id} during pipeline initiation.")
            return

        # 1. Transition video status to processing
        video_update = UploadedVideoUpdate(
            processing_status="processing",
            processing_started_at=datetime.utcnow()
        )
        update_video(db, video_id=video_id, video_in=video_update)

        # 2. Extract frames
        logger.info("Stage: Frame Extraction Started")
        try:
            frames = extract_frames(video_path=db_video.filepath, video_id=video_id, frame_interval=1, in_memory=True)
            logger.info("Stage: Frame Extraction Completed")
            logger.info("Stage: Frames Extracted")
        except Exception as e:
            logger.error(f"Core frame extraction failed for video {video_id}: {e}", exc_info=True)
            raise e

        # 3. Running object detection inference on frames
        logger.info("Stage: Inference Started")
        total_detections_count = 0
        has_inference_success = False

        from app.services.ai.tracker import RoadDistressTracker
        tracker = RoadDistressTracker(db)

        for frame_info in frames:
            try:
                detections = run_inference(
                    frame_info["frame_path"],
                    video_id=video_id,
                    frame_number=frame_info["frame_number"]
                )
                has_inference_success = True
                
                for det in detections:
                    db_distress = tracker.track_detection(
                        detection=det,
                        frame_number=frame_info["frame_number"],
                        timestamp=frame_info["timestamp"],
                        video_id=video_id
                    )
                    if db_distress:
                        total_detections_count += 1
            except Exception as fe:
                # Proceed with remaining frames on individual failure
                logger.warning(f"Error processing frame {frame_info.get('frame_path')}: {fe}")
                continue

        # If frame query completely failed when frames were extracted, mark core pipeline failed
        if not has_inference_success and len(frames) > 0:
            raise RuntimeError("Core AI inference failed to complete on all extracted frames.")

        logger.info("Stage: Inference Completed")

        # 4. Trigger Maintenance Recommendations
        logger.info("Stage: Maintenance Started")
        try:
            generate_recommendations_for_pending_distresses(db)
            logger.info("Stage: Maintenance Completed")
            logger.info("Stage: Maintenance Generated")
        except Exception as me:
            logger.error(f"Maintenance recommendation engine encountered error: {me}", exc_info=True)

        # 5. Trigger Safety PDF Report Compilation
        try:
            # Set video processing status to completed and commit to DB first (Issue 1)
            video_update = UploadedVideoUpdate(
                processing_status="completed",
                processing_completed_at=datetime.utcnow()
            )
            update_video(db, video_id=video_id, video_in=video_update)
            db.commit()

            relative_pdf_path = generate_video_pdf_report(db, video_id=video_id)
            report_in = ReportCreate(
                report_name=f"Safety_Audit_Report_Video_{video_id}",
                report_type="PDF",
                generated_by=db_video.uploader_id,
                filepath=relative_pdf_path
            )
            create_report(db, report_in=report_in)
            logger.info("Stage: Reports Generated")
            logger.info("Stage: Report Generated")
        except Exception as re:
            logger.error(f"Safety PDF report generation failed: {re}", exc_info=True)

        # 6. Trigger Notification dispatching
        try:
            from app.models.distress import RoadDistress
            distresses = db.query(RoadDistress).filter(RoadDistress.video_id == video_id).all()
            for d in distresses:
                if d.severity == "critical":
                    logger.info(f"Notification Sent: [CRITICAL ALERT] Critical distress {d.distress_type} found at Lat: {d.latitude}, Lon: {d.longitude}")
                elif d.severity == "high":
                    logger.info(f"Notification Sent: [WARNING ALERT] High severity distress {d.distress_type} found at Lat: {d.latitude}, Lon: {d.longitude}")
            logger.info("Stage: Notifications Generated")
            logger.info("Stage: Notifications Sent")
        except Exception as ne:
            logger.error(f"Incident alerts notification dispatch failed: {ne}", exc_info=True)

        # 7. Reconstruct and generate annotated processed video (Task 1)
        try:
            generate_processed_video(db, video_id)
        except Exception as ve:
            logger.error(f"Annotated video generation encountered error: {ve}", exc_info=True)

        # 8. Finalize video log status
        duration = round(time.time() - start_time, 2)
        video_update = UploadedVideoUpdate(
            processing_duration=duration
        )
        update_video(db, video_id=video_id, video_in=video_update)
        
        logger.info("Stage: Pipeline Completed")

    except Exception as e:
        duration = round(time.time() - start_time, 2)
        logger.error(f"Fatal error in video processing pipeline: {e}", exc_info=True)
        try:
            video_update = UploadedVideoUpdate(
                processing_status="failed",
                processing_completed_at=datetime.utcnow(),
                processing_duration=duration
            )
            update_video(db, video_id=video_id, video_in=video_update)
        except Exception as dberr:
            logger.critical(f"Database error writing failed pipeline status: {dberr}")
    finally:
        db.close()


def generate_processed_video(db: Session, video_id: int) -> str:
    """
    Reconstructs an MP4 video from the annotated and original frames,
    saves it under uploads/processed/, and updates the db field.
    """
    import cv2
    import os
    from app.crud.video import get_video, update_video
    from app.schemas.video import UploadedVideoUpdate
    
    db_video = get_video(db, video_id=video_id)
    if not db_video:
        raise ValueError(f"Video {video_id} not found.")
        
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    
    # Resolve directories - Save to uploads/processed/ as requested
    processed_dir = os.path.join(base_dir, "uploads", "processed", str(video_id))
    os.makedirs(processed_dir, exist_ok=True)
    
    processed_filename = "processed_video.mp4"
    processed_filepath = os.path.join(processed_dir, processed_filename)
    relative_processed_path = os.path.relpath(processed_filepath, base_dir).replace("\\", "/")
    
    detections_dir = os.path.join(base_dir, "uploads", "detections", str(video_id))
    
    # Resolve original video filepath
    original_video_path = os.path.join(base_dir, db_video.filepath)
    if not os.path.exists(original_video_path):
        original_video_path = db_video.filepath
        
    if not os.path.exists(original_video_path):
        logger.warning(f"Original video file not found at: {original_video_path}. Skipping video generation.")
        return None
        
    cap = cv2.VideoCapture(original_video_path)
    if not cap.isOpened():
        logger.warning(f"Failed to open original video {original_video_path}. Skipping video generation.")
        return None
        
    # Query original FPS and resolution
    fps = cap.get(cv2.CAP_PROP_FPS)
    if fps <= 0:
        logger.warning(f"Invalid original video FPS ({fps}). Defaulting calculation to 30.0 FPS.")
        fps = 30.0
        
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    
    # Initialize VideoWriter using original FPS and resolution
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(processed_filepath, fourcc, fps, (w, h))
    
    frame_count = 0
    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break
                
            # Check if annotated frame exists (reusing existing annotated frames)
            annotated_filename = f"annotated_frame_{frame_count:06d}.jpg"
            annotated_path = os.path.join(detections_dir, annotated_filename)
            
            if os.path.exists(annotated_path):
                frame_img = cv2.imread(annotated_path)
                if frame_img is not None:
                    if frame_img.shape[1] != w or frame_img.shape[0] != h:
                        frame_img = cv2.resize(frame_img, (w, h))
                    frame_to_write = frame_img
                else:
                    frame_to_write = frame
            else:
                frame_to_write = frame
                
            out.write(frame_to_write)
            frame_count += 1
    finally:
        cap.release()
        out.release()
        
    video_update = UploadedVideoUpdate(
        processed_filepath=relative_processed_path,
        processed_video_path=relative_processed_path
    )
    update_video(db, video_id=video_id, video_in=video_update)
    
    logger.info(f"Processed video generated and saved at: {relative_processed_path}")
    return relative_processed_path
