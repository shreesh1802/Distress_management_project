"""
Report sections for field notes (see app/models/observation.py): the snapshots and voice notes a surveyor
added by hand to a live session. A PDF section (with the pictures) and an Excel sheet. Reports without notes
are left exactly as they were -- these helpers add nothing when there are none.
"""

import logging
import os
from typing import Any, List, Optional
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import Image as RLImage
from reportlab.platypus import KeepTogether, Paragraph, Spacer
from sqlalchemy.orm import Session

from app.core.safe_paths import resolve_upload_path
from app.services.observation_service import list_for_video
from app.core.timezones import format_report_time

logger = logging.getLogger(__name__)

MAX_PICTURE_WIDTH = 9.5 * cm
MAX_PICTURE_HEIGHT = 6.5 * cm


def _plain(value: str) -> str:
    """Typed and spoken text is user-controlled: stop a spreadsheet from treating it as a formula."""
    return "\u2060" + value if value[:1] in ("=", "+", "-", "@", "\t", "\r") else value


def _notes_for(db: Session, video_id: int) -> list:
    """The report's notes -- or none if they cannot be read: a field-notes problem must never stop the
    main report from being built."""
    try:
        return list_for_video(db, video_id)
    except Exception:
        logger.warning("Could not read the field notes for report %s; leaving that section out", video_id, exc_info=True)
        db.rollback()
        return []


def _when(obs: Any) -> str:
    created = getattr(obs, "created_at", None)
    return format_report_time(created, "%d %b %Y %H:%M:%S") if created else ""


def _place(obs: Any) -> str:
    lat, lon = getattr(obs, "latitude", None), getattr(obs, "longitude", None)
    return f"{lat:.6f}, {lon:.6f}" if lat is not None and lon is not None else ""


def _length(seconds: Optional[float]) -> str:
    if not seconds or seconds < 0:
        return ""
    total = int(round(seconds))
    return f"{total // 60}:{total % 60:02d}"


def _voice_text(obs: Any) -> str:
    """What to print for a voice note: its transcript, or why there is none."""
    if not getattr(obs, "audio_path", None):
        return ""
    if obs.transcript:
        return obs.transcript
    if obs.transcript_status == "pending":
        return "(transcript still being prepared)"
    return "(recorded; no transcript available -- the recording is kept in the app)"


def _picture_size(path: str) -> Optional[tuple]:
    try:
        from PIL import Image

        with Image.open(path) as im:
            width, height = im.size
    except Exception:
        return None
    if not width or not height:
        return None
    scale = min(MAX_PICTURE_WIDTH / width, MAX_PICTURE_HEIGHT / height)
    return width * scale, height * scale


# --------------------------------------------------------------------------------------------------- PDF
def field_notes_flowables(db: Session, video_id: int) -> list:
    """Platypus flowables for the 'Surveyor Field Notes' section ([] when the report has no notes)."""
    notes = _notes_for(db, video_id)
    if not notes:
        return []

    base = getSampleStyleSheet()["Normal"]
    h1 = ParagraphStyle("NotesH1", parent=base, fontName="Helvetica-Bold", fontSize=13, leading=16,
                        textColor=colors.HexColor("#1e3a8a"), spaceBefore=6, spaceAfter=6)
    body = ParagraphStyle("NotesBody", parent=base, fontSize=8.5, leading=11)
    intro = ParagraphStyle("NotesIntro", parent=body, fontName="Helvetica-Oblique", textColor=colors.HexColor("#475569"))
    title = ParagraphStyle("NotesTitle", parent=body, fontName="Helvetica-Bold", fontSize=10, leading=13, spaceBefore=8)

    flow: List[Any] = [
        Paragraph("Surveyor Field Notes", h1),
        Paragraph(
            "Snapshots and voice notes added by the surveyor during the survey, for locations the camera "
            "detection did not pick up (or got wrong).",
            intro,
        ),
        Spacer(1, 4),
    ]
    for number, obs in enumerate(notes, start=1):
        place = _place(obs)
        heading = f"Note {number} &nbsp;<font size=8 color='#64748b'>{escape(_when(obs))}" + (
            f" &middot; {escape(place)}" if place else "") + "</font>"
        block: List[Any] = [Paragraph(heading, title)]
        if obs.note:
            block.append(Paragraph(f"<b>Note:</b> {escape(obs.note)}", body))
        if obs.audio_path:
            length = _length(obs.audio_duration_seconds)
            block.append(Paragraph(
                f"<b>Voice note{f' ({length})' if length else ''}:</b> {escape(_voice_text(obs))}", body))
        if obs.image_path:
            picture = _picture(obs.image_path)
            block.append(picture if picture is not None else Paragraph("(snapshot file not available)", body))
        block.append(Spacer(1, 6))
        flow.append(KeepTogether(block))
    flow.append(Spacer(1, 10))
    return flow


def _picture(stored: str):
    full = resolve_upload_path(stored)
    if full is None or not os.path.isfile(full):
        return None
    size = _picture_size(full)
    if size is None:
        return None
    try:
        picture = RLImage(full, width=size[0], height=size[1])
        picture.hAlign = "LEFT"
        return picture
    except Exception:
        logger.warning("Could not embed a field-note snapshot in the PDF", exc_info=True)
        return None


# ------------------------------------------------------------------------------------------------- Excel
def add_field_notes_sheet(wb: Any, db: Session, video_id: int) -> Optional[Any]:
    """Adds the 'Field Notes' worksheet (with the snapshots as thumbnails) and returns it; None when there are none."""
    notes = _notes_for(db, video_id)
    if not notes:
        return None

    from openpyxl.styles import Alignment, Border, Font, PatternFill, Side

    ws = wb.create_sheet(title="Field Notes")
    font = "Segoe UI"
    side = Side(border_style="thin", color="D3D3D3")
    border = Border(left=side, right=side, top=side, bottom=side)
    headers = ["#", "Time", "Location", "Note", "Voice note", "Voice note transcript", "Snapshot"]
    widths = [5, 20, 24, 40, 12, 60, 34]

    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=len(headers))
    title = ws.cell(row=1, column=1, value="SURVEYOR FIELD NOTES")
    title.font = Font(name=font, size=14, bold=True, color="FFFFFF")
    title.alignment = Alignment(horizontal="center", vertical="center")
    for c in range(1, len(headers) + 1):
        ws.cell(row=1, column=c).fill = PatternFill(start_color="1F4E78", end_color="1F4E78", fill_type="solid")
    ws.row_dimensions[1].height = 28

    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=len(headers))
    sub = ws.cell(row=2, column=1, value=(
        "Snapshots and voice notes added by the surveyor during the survey, for locations the camera "
        "detection did not pick up (or got wrong)."))
    sub.font = Font(name=font, size=9, italic=True, color="595959")
    sub.alignment = Alignment(wrap_text=True, vertical="top")
    ws.row_dimensions[2].height = 28

    for col, text in enumerate(headers, start=1):
        cell = ws.cell(row=4, column=col, value=text)
        cell.font = Font(name=font, size=11, bold=True, color="FFFFFF")
        cell.fill = PatternFill(start_color="1F4E78", end_color="1F4E78", fill_type="solid")
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        cell.border = border
        ws.column_dimensions[cell.column_letter].width = widths[col - 1]

    for index, obs in enumerate(notes, start=1):
        row = 4 + index
        values = [
            index, _when(obs), _place(obs), _plain(obs.note or ""),
            _length(obs.audio_duration_seconds) if obs.audio_path else "",
            _plain(_voice_text(obs)), "" if obs.image_path else "(no snapshot)",
        ]
        for col, value in enumerate(values, start=1):
            cell = ws.cell(row=row, column=col, value=value)
            cell.font = Font(name=font, size=10)
            cell.alignment = Alignment(wrap_text=True, vertical="top")
            cell.border = border
        has_picture = obs.image_path and _embed_thumbnail(ws, obs.image_path, row, len(headers))
        ws.row_dimensions[row].height = 105 if has_picture else 45
    ws.freeze_panes = "A5"
    return ws


def _embed_thumbnail(ws: Any, stored: str, row: int, column: int) -> bool:
    try:
        from openpyxl.drawing.image import Image as XLImage
        from PIL import Image

        full = resolve_upload_path(stored)
        if full is None or not os.path.isfile(full):
            return False
        with Image.open(full) as im:
            width, height = im.size
        scale = min(220 / width, 130 / height)
        picture = XLImage(full)
        picture.width, picture.height = int(width * scale), int(height * scale)
        ws.add_image(picture, ws.cell(row=row, column=column).coordinate)
        return True
    except Exception:
        logger.warning("Could not embed a field-note snapshot in the Excel sheet", exc_info=True)
        return False
