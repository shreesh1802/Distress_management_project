"""
Main entry point for the Road Distress Management System backend.
Initializes FastAPI, configures CORS, and registers versioned API endpoints.
"""

from fastapi import FastAPI, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.v1.routes import (
    auth,
    distress,
    gis,
    reports,
    maintenance,
    upload,
    users,
    videos,
    detection,
    live
)

# Initialize FastAPI application
app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    version="1.0.0"
)

# CORS middleware configuration
if settings.BACKEND_CORS_ORIGINS:
    origins = [origin.strip() for origin in settings.BACKEND_CORS_ORIGINS.split(",") if origin.strip()]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text, inspect
from app.db.session import get_db, SessionLocal
import logging

# Application loggers (pipeline_manager, model_loader, etc.) call logger.info()
# extensively for per-stage/per-frame progress. Without this, Python's root
# logger defaults to WARNING with no handler, so only warnings/errors reach
# the console (via the logging module's stderr "handler of last resort") and
# all pipeline progress is silently swallowed -- making a slow-but-working
# video processing job indistinguishable from a stuck one in the terminal.
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s [%(name)s] %(message)s")

logger = logging.getLogger(__name__)


@app.on_event("startup")
def startup_event() -> None:
    """
    FastAPI startup hook to validate connection to PostgreSQL and auto-run dynamic migrations.
    """
    logger.info("Validating database connection on startup...")
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        logger.info("Database connection validated successfully.")
        
        # Self-healing migration for processed_filepath column
        try:
            db.execute(text("SELECT processed_filepath FROM uploaded_videos LIMIT 1"))
            logger.info("Database Schema Check: processed_filepath column already exists.")
        except Exception:
            db.rollback()
            try:
                db.execute(text("ALTER TABLE uploaded_videos ADD COLUMN processed_filepath VARCHAR(512)"))
                db.commit()
                logger.info("Database Schema Migration: Added processed_filepath column to uploaded_videos table.")
            except Exception as alt_err:
                logger.warning(f"ALTER TABLE query for processed_filepath failed: {alt_err}")

        # Self-healing migration for processed_video_path column
        try:
            db.execute(text("SELECT processed_video_path FROM uploaded_videos LIMIT 1"))
            logger.info("Database Schema Check: processed_video_path column already exists.")
        except Exception:
            db.rollback()
            try:
                db.execute(text("ALTER TABLE uploaded_videos ADD COLUMN processed_video_path VARCHAR(512)"))
                db.commit()
                logger.info("Database Schema Migration: Added processed_video_path column to uploaded_videos table.")
            except Exception as alt_err:
                logger.warning(f"ALTER TABLE query for processed_video_path failed: {alt_err}")

        # Self-healing migration for road_distresses.detection_image_path to TEXT type
        try:
            db.execute(text("ALTER TABLE road_distresses ALTER COLUMN detection_image_path TYPE TEXT"))
            db.commit()
            logger.info("Database Schema Migration: Altered road_distresses.detection_image_path column to TEXT type.")
        except Exception as alt_col_err:
            db.rollback()
            logger.warning(f"ALTER COLUMN query for detection_image_path failed: {alt_col_err}")

        # Self-healing migration for uploaded_videos.progress column
        try:
            db.execute(text("SELECT progress FROM uploaded_videos LIMIT 1"))
            logger.info("Database Schema Check: progress column already exists.")
        except Exception:
            db.rollback()
            try:
                db.execute(text("ALTER TABLE uploaded_videos ADD COLUMN progress INTEGER DEFAULT 0"))
                db.commit()
                logger.info("Database Schema Migration: Added progress column to uploaded_videos table.")
            except Exception as e_progress:
                logger.warning(f"ALTER TABLE query for progress column failed: {e_progress}")

        # Self-healing migration for uploaded_videos.processing_stage column
        try:
            db.execute(text("SELECT processing_stage FROM uploaded_videos LIMIT 1"))
            logger.info("Database Schema Check: processing_stage column already exists.")
        except Exception:
            db.rollback()
            try:
                db.execute(text("ALTER TABLE uploaded_videos ADD COLUMN processing_stage VARCHAR(100) DEFAULT 'Idle'"))
                db.commit()
                logger.info("Database Schema Migration: Added processing_stage column to uploaded_videos table.")
            except Exception as e_stage:
                logger.warning(f"ALTER TABLE query for processing_stage column failed: {e_stage}")

        # Self-healing migration for road_distresses.model_source column
        try:
            db.execute(text("SELECT model_source FROM road_distresses LIMIT 1"))
            logger.info("Database Schema Check: model_source column already exists.")
        except Exception:
            db.rollback()
            try:
                db.execute(text("ALTER TABLE road_distresses ADD COLUMN model_source VARCHAR(50) DEFAULT 'road'"))
                db.commit()
                logger.info("Database Schema Migration: Added model_source column to road_distresses table.")
            except Exception as e_model_source:
                logger.warning(f"ALTER TABLE query for model_source failed: {e_model_source}")

        db.close()
    except Exception as e:
        logger.critical(f"Database connection validation failed: {e}")


@app.get("/health", tags=["Health"])
def health_check(db: Session = Depends(get_db)) -> dict:
    """
    Enhanced health check validating the database connection and verifying tables.
    """
    try:
        # Perform actual database connection validation
        db.execute(text("SELECT 1"))
        
        # Verify table presence
        inspector = inspect(db.bind)
        tables = inspector.get_table_names()
        
        required_tables = ["users", "road_distresses", "uploaded_videos", "maintenance_tasks", "reports"]
        for table in required_tables:
            if table not in tables:
                raise HTTPException(
                    status_code=500,
                    detail=f"Database table verification failed. Missing table: {table}"
                )
        
        return {
            "status": "healthy",
            "database": "connected",
            "tables": required_tables
        }
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(
            status_code=503,
            detail=f"Database connection is unhealthy: {str(e)}"
        )


# Centralized router registry for API v1 routes
from app.api.routes import health

api_router = APIRouter()
api_router.include_router(health.router, tags=["Health"])
api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(distress.router, prefix="/distress", tags=["Road Distress Monitoring"])
api_router.include_router(gis.router, prefix="/gis", tags=["GIS Map Integration"])
api_router.include_router(reports.router, prefix="/reports", tags=["Reporting & Analytics"])
api_router.include_router(maintenance.router, prefix="/maintenance", tags=["Maintenance Scheduling"])
api_router.include_router(users.router, prefix="/users", tags=["Users"])
api_router.include_router(videos.router, prefix="/videos", tags=["Video Management"])
api_router.include_router(upload.router, prefix="/upload", tags=["Media Upload & Processing"])
api_router.include_router(detection.router, prefix="/detection", tags=["AI Distress Detection"])
api_router.include_router(live.router, prefix="/live", tags=["Live Camera Detection"])

# Bind centralized API version 1 router to application
app.include_router(api_router, prefix=settings.API_V1_STR)

# Serve uploads/ (video frames, detection snapshots, live-camera snapshots) so the
# frontend can reference them directly, e.g. /uploads/detections/live/<file>.jpg
import os
from fastapi.staticfiles import StaticFiles
_uploads_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "uploads")
os.makedirs(_uploads_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=_uploads_dir), name="uploads")
