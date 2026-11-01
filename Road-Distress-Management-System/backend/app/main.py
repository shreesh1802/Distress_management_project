"""
Main entry point for the Road Distress Management System backend.
Initializes FastAPI, configures CORS, and registers versioned API endpoints.

Security posture is selected by APP_ENV (see app/core/config.py and SECURITY.md):
"development" (default) keeps the original local-demo behaviour, "production"
fails closed on misconfiguration, disables /docs and /openapi.json and turns the
demo conveniences off.
"""

import os

from fastapi import FastAPI, APIRouter, Depends, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.core.deps import get_current_user
from app.core.security_headers import SecurityHeadersMiddleware
from app.core.startup_checks import validate_runtime_config
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
    live,
    projects,
    audits,
    assets,
)

# Fail closed BEFORE the app object exists: in production a missing SMTP / CORS / signing
# secret configuration (or OTP_DEV_MODE=true) aborts startup with a clear message.
validate_runtime_config(settings)

# Initialize FastAPI application (interactive docs and the OpenAPI schema are not exposed in production)
_docs_enabled = not settings.is_production
app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json" if _docs_enabled else None,
    docs_url="/docs" if _docs_enabled else None,
    redoc_url="/redoc" if _docs_enabled else None,
    version="1.0.0"
)

# CORS middleware configuration: origins come from BACKEND_CORS_ORIGINS
# ("*" only by default in development; production requires an explicit list or none).
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(SecurityHeadersMiddleware)


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """
    422 responses keep FastAPI's {"detail": [{loc, msg, type}]} shape but never echo the rejected
    input back: values such as NaN/Infinity are not JSON-serialisable (the default handler would
    crash with a 500) and echoing request data is unnecessary information disclosure.
    """
    errors = [
        {"loc": list(err.get("loc", ())), "msg": str(err.get("msg", "")), "type": str(err.get("type", ""))}
        for err in exc.errors()
    ]
    return JSONResponse(status_code=422, content={"detail": errors})


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

from app.db.bootstrap import bootstrap_admin as _bootstrap_admin  # noqa: E402

def _seed_demo_data(db) -> None:
    """Demo video 20 + 8 demo detections and the demo display name for user 1 (SEED_DEMO_DATA)."""
    # Auto-seed Demo Data for Video 20 if missing
    from app.models.video import UploadedVideo
    from app.models.distress import RoadDistress
    from app.models.user import User
    from datetime import datetime

    admin_user = db.query(User).filter(User.id == 1).first()
    if admin_user is None:
        logger.info("Demo seeding skipped: user id 1 does not exist.")
        return
    admin_user.full_name = "Monitoring Engineer (ME)"
    db.commit()

    video_20 = db.query(UploadedVideo).filter(UploadedVideo.id == 20).first()
    if not video_20:
        logger.info("Auto-seeding Video 20 demo record...")
        video_rel_raw = "uploads/videos/99613c95ecb2483994062e8d72cef840_Client_Test_Video.mp4"
        video_rel_proc = "uploads/processed/20/processed_video.mp4"
        video_20 = UploadedVideo(
            id=20,
            filename="Highway_Distress_Inspection_Feed.mp4",
            filepath=video_rel_raw,
            processed_filepath=video_rel_proc,
            processed_video_path=video_rel_proc,
            processing_status="completed",
            progress=100,
            processing_stage="Completed",
            processing_duration=48.5,
            upload_timestamp=datetime.now(),
            created_at=datetime.now(),
            updated_at=datetime.now(),
            uploader_id=1
        )
        db.add(video_20)
        db.commit()

    distress_count = db.query(RoadDistress).filter(RoadDistress.video_id == 20).count()
    if distress_count == 0:
        logger.info("Auto-seeding 8 road distress records for Video 20...")
        detections_config = [
            {"timestamp": 4.5, "type": "Pothole", "severity": "high", "lat": 19.0760, "lng": 72.8777, "conf": 0.94},
            {"timestamp": 9.2, "type": "Alligator Cracks", "severity": "critical", "lat": 19.0768, "lng": 72.8785, "conf": 0.96},
            {"timestamp": 14.8, "type": "Rutting", "severity": "medium", "lat": 19.0775, "lng": 72.8792, "conf": 0.89},
            {"timestamp": 20.1, "type": "Edge Break", "severity": "high", "lat": 19.0782, "lng": 72.8801, "conf": 0.91},
            {"timestamp": 26.5, "type": "Pothole", "severity": "critical", "lat": 19.0790, "lng": 72.8810, "conf": 0.95},
            {"timestamp": 33.0, "type": "Longitudinal Crack", "severity": "medium", "lat": 19.0798, "lng": 72.8820, "conf": 0.88},
            {"timestamp": 39.4, "type": "Patching Defect", "severity": "low", "lat": 19.0805, "lng": 72.8829, "conf": 0.86},
            {"timestamp": 46.2, "type": "Pothole", "severity": "high", "lat": 19.0812, "lng": 72.8838, "conf": 0.93},
        ]
        for idx, det in enumerate(detections_config, start=1):
            crop_rel = f"uploads/crops/crop_v20_{idx}.jpg"
            frame_no = int(det["timestamp"] * 30.0)
            record = RoadDistress(
                video_id=20,
                distress_type=det["type"],
                severity=det["severity"],
                confidence_score=det["conf"],
                latitude=det["lat"],
                longitude=det["lng"],
                detected_at=datetime.now(),
                status="detected",
                image_url=crop_rel,
                frame_number=frame_no,
                video_timestamp=det["timestamp"],
                tracking_id=100 + idx
            )
            db.add(record)
        db.commit()


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

        # Ensure all tables exist
        from app.db.base import Base
        Base.metadata.create_all(bind=db.bind)

        # Pay the PBKDF2 cost of the login dummy hash now, not on the first unknown-email login
        from app.core.security import dummy_password_hash
        dummy_password_hash()

        # First-admin bootstrap (development: user id 1; production: only from BOOTSTRAP_ADMIN_EMAIL)
        _bootstrap_admin(db)

        # Demo data (video 20, 8 demo detections, demo display name) only when SEED_DEMO_DATA is on
        if settings.seed_demo_data:
            _seed_demo_data(db)
        else:
            logger.info("Demo data seeding disabled (SEED_DEMO_DATA is off).")

        db.close()
    except Exception as e:
        logger.critical(f"Database connection validation failed: {e}")
        if settings.is_production:
            # Production must not limp along half-initialised (missing tables / no bootstrap admin):
            # fail the start-up so the platform restarts or alerts instead of serving errors.
            raise
        # development keeps the historical behaviour: log and carry on


REQUIRED_TABLES = ["users", "road_distresses", "uploaded_videos", "maintenance_tasks", "reports"]


def _verify_database(db: Session) -> None:
    """Raises HTTPException with a GENERIC message (details only go to the server log)."""
    try:
        # Perform actual database connection validation
        db.execute(text("SELECT 1"))

        # Verify table presence
        tables = inspect(db.bind).get_table_names()
        missing = [table for table in REQUIRED_TABLES if table not in tables]
        if missing:
            logger.error("Health check: missing database tables: %s", missing)
            raise HTTPException(status_code=500, detail="Database schema verification failed.")
    except HTTPException:
        raise
    except Exception:
        logger.exception("Health check failed")
        raise HTTPException(status_code=503, detail="Database connection is unhealthy.")


@app.get("/health", tags=["Health"])
def health_check(db: Session = Depends(get_db)) -> dict:
    """
    Public health probe: status only. The HTTP status code carries the result (200 healthy, 500/503
    otherwise); table names, model files and error details are NOT exposed here - see the
    authenticated GET /api/v1/health/details.
    """
    _verify_database(db)
    return {"status": "healthy"}


_authenticated = [Depends(get_current_user)]

# Centralized router registry for API v1 routes.
# Every router below except health/auth requires a signed-in user (bearer token); that is
# enforced once, here, so a new legacy route can never be added without authentication.
from app.api.routes import health

api_router = APIRouter()
api_router.include_router(health.router, tags=["Health"])

details_router = APIRouter()


@details_router.get("/health/details")
def health_details(db: Session = Depends(get_db)) -> dict:
    """Detailed health (database tables, AI model status). Requires a signed-in user."""
    from app.services.ai.model_status import get_model_status
    _verify_database(db)
    return {"status": "healthy", "database": "connected", "tables": REQUIRED_TABLES, "model": get_model_status()}


api_router.include_router(details_router, tags=["Health"], dependencies=_authenticated)
api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])  # per-route auth (login flow is public)
api_router.include_router(distress.router, prefix="/distress", tags=["Road Distress Monitoring"], dependencies=_authenticated)
api_router.include_router(gis.router, prefix="/gis", tags=["GIS Map Integration"], dependencies=_authenticated)
api_router.include_router(reports.router, prefix="/reports", tags=["Reporting & Analytics"], dependencies=_authenticated)
# Report file downloads: bearer token OR short-lived signed link (opened via launchUrl, no headers possible)
api_router.include_router(reports.download_router, prefix="/reports", tags=["Reporting & Analytics"])
api_router.include_router(maintenance.router, prefix="/maintenance", tags=["Maintenance Scheduling"], dependencies=_authenticated)
api_router.include_router(users.router, prefix="/users", tags=["Users"])  # per-route: signed-in for reads, admin for writes
api_router.include_router(videos.router, prefix="/videos", tags=["Video Management"], dependencies=_authenticated)
api_router.include_router(upload.router, prefix="/upload", tags=["Media Upload & Processing"], dependencies=_authenticated)
api_router.include_router(detection.router, prefix="/detection", tags=["AI Distress Detection"], dependencies=_authenticated)
api_router.include_router(live.router, prefix="/live", tags=["Live Camera Detection"], dependencies=_authenticated)
# Live WebSockets authenticate with a first-message token (browsers cannot send headers on a WS handshake)
api_router.include_router(live.ws_router, prefix="/live", tags=["Live Camera Detection"])
api_router.include_router(projects.router, prefix="/projects", tags=["Projects (Module Platform)"])
api_router.include_router(audits.router, prefix="/audits", tags=["M2 Road Safety Audit"])
api_router.include_router(assets.router, prefix="/assets", tags=["M3 Asset Management"])

# Bind centralized API version 1 router to application
app.include_router(api_router, prefix=settings.API_V1_STR)

from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

_uploads_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "uploads")
os.makedirs(_uploads_dir, exist_ok=True)

# NOTE: /download-apk MUST be registered BEFORE app.mount("/uploads") because
# FastAPI's StaticFiles mount acts as a catch-all sub-app and will shadow any
# routes registered after it at the same router level.
# PUBLIC by design (sideloading link for the owner's own APK). Remove or protect this before a
# Play Store release: the store build must update through Google Play only.
@app.get("/download-apk", tags=["APK Download"])
@app.get("/app-release.apk", tags=["APK Download"])
def download_apk():
    """
    Download the Road Distress Monitoring System Android APK installer.
    """
    apk_path = os.path.join(_uploads_dir, "RoadDistress.apk")
    if os.path.exists(apk_path):
        return FileResponse(
            path=apk_path,
            filename="RoadDistress_v1.0.0.apk",
            media_type="application/vnd.android.package-archive"
        )
    raise HTTPException(status_code=404, detail="APK build file not found.")

# Serve uploads/ (video frames, detection snapshots, live-camera snapshots) so the
# frontend can reference them directly, e.g. /uploads/detections/live/<file>.jpg
# KNOWN RESIDUAL RISK (ATK-009): this mount is still public; files are reachable by path only
# (UUID-prefixed names for audio/assets). Replacing it with signed URLs is a planned redesign.
# IMPORTANT: This mount must come LAST — after all @app.get() routes are registered.
app.mount("/uploads", StaticFiles(directory=_uploads_dir), name="uploads")
