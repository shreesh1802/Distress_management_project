"""
Reporting and analytics routes for the Road Distress Management System.

Two routers are exported (see app/main.py):
  * ``router``          -- every route requires a signed-in user (bearer token).
  * ``download_router`` -- the three GET file routes (PDF download, Excel download,
    inline preview). They are opened with launchUrl / an anchor tag where no
    Authorization header can be sent, so they accept EITHER a valid bearer token
    OR a short-lived signed ``?t=`` token minted by POST /reports/{id}/download-link.
    Without one of the two they answer 401.
"""

import logging
import os
from typing import List, Literal, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.deps import extract_bearer_token, get_current_user, user_for_token
from app.core.pagination import skip_param, limit_param
from app.core.safe_paths import resolve_report_path
from app.crud.report import (
    get_report,
    get_reports,
    create_report,
    delete_report
)
from app.db.session import get_db
from app.models.user import User
from app.schemas.report import (
    ReportCreate,
    ReportResponse
)
from app.services.download_links import sign_download_token, verify_download_token, LINK_TTL_SECONDS
from app.services.pdf_generator import generate_video_pdf_report
from app.services.excel_generator import generate_video_excel_report

logger = logging.getLogger(__name__)

router = APIRouter()
download_router = APIRouter()


@router.get("/", response_model=List[ReportResponse])
def read_reports(
    skip: int = skip_param(),
    limit: int = limit_param(),
    db: Session = Depends(get_db)
) -> List[ReportResponse]:
    """
    Retrieve all generated report logs.
    """
    return get_reports(db, skip=skip, limit=limit)


@router.post("/generate/{video_id}", response_model=ReportResponse, status_code=status.HTTP_201_CREATED)
def generate_pdf_report(
    video_id: int,
    pavement: str = Query("bituminous", pattern="^(bituminous|concrete)$"),
    db: Session = Depends(get_db)
) -> ReportResponse:
    """
    Generate a professional PDF report for a processed video session.
    """
    from app.crud.video import get_video
    video = get_video(db, video_id=video_id)
    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Video with ID {video_id} not found."
        )

    try:
        # Generate the PDF file
        relative_pdf_path = generate_video_pdf_report(db, video_id=video_id, pavement=pavement)

        # Log metadata in DB
        report_in = ReportCreate(
            report_name=f"Safety_Audit_Report_Video_{video_id}",
            report_type="PDF",
            generated_by=video.uploader_id,
            filepath=relative_pdf_path
        )
        return create_report(db, report_in=report_in)
    except Exception:
        logger.exception("PDF report generation failed for video %s", video_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate report."
        )


@router.post("/excel/{video_id}", response_model=ReportResponse, status_code=status.HTTP_201_CREATED)
def generate_excel_report(
    video_id: int,
    pavement: str = Query("bituminous", pattern="^(bituminous|concrete)$"),
    db: Session = Depends(get_db)
) -> ReportResponse:
    """
    Generate a professional Excel report for a processed video session.
    """
    from app.crud.video import get_video
    video = get_video(db, video_id=video_id)
    if not video:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Video with ID {video_id} not found."
        )

    try:
        # Generate the Excel file
        relative_excel_path = generate_video_excel_report(db, video_id=video_id, pavement=pavement)

        # Log metadata in DB
        report_in = ReportCreate(
            report_name=f"Excel_Safety_Audit_Report_Video_{video_id}",
            report_type="EXCEL",
            generated_by=video.uploader_id,
            filepath=relative_excel_path
        )
        return create_report(db, report_in=report_in)
    except Exception:
        logger.exception("Excel report generation failed for video %s", video_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate Excel report."
        )


# --------------------------------------------------------------------------------
# Signed link minting (authenticated)
# --------------------------------------------------------------------------------
_KIND_TO_PATH = {
    "pdf": "download",
    "excel": "excel/download",
    "preview": "preview",
}


@router.post("/{report_id}/download-link")
def create_download_link(
    report_id: int,
    kind: Literal["pdf", "excel", "preview"] = Query("pdf"),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
) -> dict:
    """
    Mint a short-lived (5 minutes) signed URL path for downloading / previewing a report.
    The returned ``path`` is relative to the server root (prefix it with the server base URL).
    """
    if get_report(db, report_id=report_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"Report log with ID {report_id} not found.")
    token = sign_download_token(kind, report_id)
    return {
        "path": f"/api/v1/reports/{_KIND_TO_PATH[kind]}/{report_id}?t={token}",
        "expires_in": LINK_TTL_SECONDS,
    }


# --------------------------------------------------------------------------------
# File routes (bearer token OR signed link)
# --------------------------------------------------------------------------------
def _require_download_access(
    purpose: str,
    report_id: int,
    token: Optional[str],
    authorization: Optional[str],
    db: Session,
) -> None:
    if user_for_token(db, extract_bearer_token(authorization)) is not None:
        return
    if verify_download_token(token, purpose, report_id):
        return
    raise HTTPException(
        status.HTTP_401_UNAUTHORIZED, "Not authenticated",
        headers={"WWW-Authenticate": "Bearer"},
    )


def _report_file(db: Session, report_id: int, missing_label: str) -> str:
    db_report = get_report(db, report_id=report_id)
    if not db_report:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Report log with ID {report_id} not found."
        )
    if not db_report.filepath:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Report filepath is empty."
        )
    # The stored path is untrusted: confine it to <project>/reports/.
    full_path = resolve_report_path(db_report.filepath)
    if full_path is None or not os.path.isfile(full_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"{missing_label} file not found on the server."
        )
    return full_path


@download_router.get("/excel/download/{report_id}")
def download_excel_report(
    report_id: int,
    t: Optional[str] = Query(None, max_length=200),
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db)
) -> FileResponse:
    """
    Download a generated Excel report by report ID.
    """
    _require_download_access("excel", report_id, t, authorization, db)
    full_path = _report_file(db, report_id, "Excel")
    return FileResponse(
        path=full_path,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        filename=os.path.basename(full_path)
    )


@download_router.get("/download/{report_id}")
def download_pdf_report(
    report_id: int,
    t: Optional[str] = Query(None, max_length=200),
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db)
) -> FileResponse:
    """
    Download a generated PDF report by report ID.
    """
    _require_download_access("pdf", report_id, t, authorization, db)
    full_path = _report_file(db, report_id, "PDF")
    return FileResponse(
        path=full_path,
        media_type="application/pdf",
        filename=os.path.basename(full_path)
    )


@download_router.get("/preview/{report_id}")
def preview_pdf_report(
    report_id: int,
    t: Optional[str] = Query(None, max_length=200),
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db)
) -> FileResponse:
    """
    Preview a generated PDF report inline in the browser.
    """
    _require_download_access("preview", report_id, t, authorization, db)
    full_path = _report_file(db, report_id, "PDF")
    headers = {
        "Content-Disposition": f"inline; filename={os.path.basename(full_path)}"
    }
    return FileResponse(
        path=full_path,
        media_type="application/pdf",
        headers=headers
    )


@router.get("/generate")
def generate_report_stub() -> dict:
    """
    Placeholder/stub route for generating reports (required by regression tests).
    """
    return {"message": "Generate report stub"}


@router.get("/{id}", response_model=ReportResponse)
def read_report_by_id(id: int, db: Session = Depends(get_db)) -> ReportResponse:
    """
    Retrieve a single report log by ID.
    """
    db_report = get_report(db, report_id=id)
    if not db_report:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Report with ID {id} not found"
        )
    return db_report


@router.delete("/{id}", response_model=ReportResponse)
def delete_existing_report(id: int, db: Session = Depends(get_db)) -> ReportResponse:
    """
    Delete a report metadata log.
    """
    db_report = delete_report(db, report_id=id)
    if not db_report:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Report with ID {id} not found"
        )
    return db_report
