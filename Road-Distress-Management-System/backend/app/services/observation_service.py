"""
Storage and bookkeeping for field notes (see app/models/observation.py): the snapshot and voice-note files a
surveyor adds by hand to a live session's report.

Files live under ``uploads/observations/`` (images and audio, UUID-prefixed names). Every stored path is
treated as untrusted when it is read back (see app/core/safe_paths.py). Voice notes are transcribed in the
background when speech-to-text is installed; the note never waits for that.
"""

import logging
import os
import re
import uuid
from typing import List, Optional, Tuple

import cv2
from fastapi import HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.core.safe_paths import resolve_upload_path
from app.core.upload_checks import file_head, magic_matches
from app.models.observation import TRANSCRIPT_NONE, SessionObservation

logger = logging.getLogger(__name__)

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
IMAGE_DIR = os.path.join(BASE_DIR, "uploads", "observations", "images")
AUDIO_DIR = os.path.join(BASE_DIR, "uploads", "observations", "audio")

MAX_AUDIO_BYTES = 25 * 1024 * 1024      # a spoken note, not a recording of the whole drive
MAX_NOTE_CHARS = 1000
MAX_NOTES_PER_SESSION = 200
ALLOWED_AUDIO_EXTENSIONS = {".m4a", ".aac", ".mp3", ".wav", ".ogg", ".webm"}


def _relative(path: str) -> str:
    return os.path.relpath(path, BASE_DIR).replace("\\", "/")


def _sanitize_filename(filename: str) -> str:
    base = os.path.basename(filename or "")
    cleaned = re.sub(r"[^a-zA-Z0-9_\.\-]", "_", base)
    if not cleaned or cleaned.startswith("."):
        cleaned = f"voice_note{os.path.splitext(base)[1]}"
    return cleaned[:100]


def save_snapshot(frame) -> str:
    """Writes a camera picture (a BGR array) as a JPEG and returns its stored (relative) path."""
    os.makedirs(IMAGE_DIR, exist_ok=True)
    ok, buffer = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 88])
    if not ok:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Could not save the snapshot.")
    path = os.path.join(IMAGE_DIR, f"{uuid.uuid4().hex}.jpg")
    with open(path, "wb") as fh:
        fh.write(buffer.tobytes())
    return _relative(path)


async def save_audio(file: UploadFile) -> Tuple[str, str]:
    """Validates and stores an uploaded voice note. Returns (stored relative path, original file name)."""
    original = file.filename or "voice_note.webm"
    ext = os.path.splitext(original)[1].lower()
    if ext not in ALLOWED_AUDIO_EXTENSIONS:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Invalid audio format. Supported formats: {', '.join(sorted(ALLOWED_AUDIO_EXTENSIONS))}",
        )
    os.makedirs(AUDIO_DIR, exist_ok=True)
    target = os.path.join(AUDIO_DIR, f"{uuid.uuid4().hex}_{_sanitize_filename(original)}")

    total = 0
    try:
        with open(target, "wb") as buffer:
            while True:
                chunk = await file.read(1024 * 1024)
                if not chunk:
                    break
                total += len(chunk)
                if total > MAX_AUDIO_BYTES:
                    buffer.close()
                    _remove_quietly(target)
                    raise HTTPException(
                        status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        "The voice note is too large (the limit is 25 MB).",
                    )
                buffer.write(chunk)
    except HTTPException:
        raise
    except Exception:
        logger.exception("Could not write a voice note to disk")
        _remove_quietly(target)
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Could not save the voice note.")

    if total == 0:
        _remove_quietly(target)
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "The voice note is empty.")
    head = file_head(target)
    if head is None or not magic_matches(original, head):
        _remove_quietly(target)
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "File content does not match its extension.")
    return _relative(target), original[:255]


def _remove_quietly(path: str) -> None:
    try:
        if os.path.exists(path):
            os.remove(path)
    except OSError:
        logger.warning("Could not remove %s", path)


def remove_stored_files(obs: SessionObservation) -> None:
    """Deletes a note's files from disk (never anything outside uploads/)."""
    for stored in (obs.image_path, obs.audio_path):
        if not stored:
            continue
        full = resolve_upload_path(stored)
        if full is None:
            logger.warning("Refusing to delete a field-note path outside uploads/.")
            continue
        _remove_quietly(full)


def count_for_video(db: Session, video_id: int) -> int:
    return db.query(SessionObservation).filter(SessionObservation.video_id == video_id).count()


def list_for_video(db: Session, video_id: int) -> List[SessionObservation]:
    return (
        db.query(SessionObservation)
        .filter(SessionObservation.video_id == video_id)
        .order_by(SessionObservation.created_at.asc(), SessionObservation.id.asc())
        .all()
    )


def create_observation(
    db: Session,
    *,
    video_id: int,
    user_id: Optional[int],
    note: Optional[str],
    image_path: Optional[str],
    audio_path: Optional[str],
    audio_filename: Optional[str],
    audio_duration_seconds: Optional[float],
    latitude: Optional[float],
    longitude: Optional[float],
) -> SessionObservation:
    obs = SessionObservation(
        video_id=video_id,
        created_by_id=user_id,
        note=(note or "").strip() or None,
        image_path=image_path,
        audio_path=audio_path,
        audio_filename=audio_filename,
        audio_duration_seconds=audio_duration_seconds,
        transcript_status="pending" if audio_path else TRANSCRIPT_NONE,
        latitude=latitude,
        longitude=longitude,
    )
    db.add(obs)
    db.commit()
    db.refresh(obs)
    return obs


def delete_observation(db: Session, obs: SessionObservation) -> None:
    remove_stored_files(obs)
    db.delete(obs)
    db.commit()


def delete_observations_for_video(db: Session, video_id: int) -> None:
    """Removes every field note (and its files) of a report that is being deleted."""
    for obs in list_for_video(db, video_id):
        remove_stored_files(obs)
        db.delete(obs)
    db.commit()


def run_transcription_job(observation_id: int) -> None:
    """Background task: transcribes a note's voice recording and stores the text (best effort)."""
    from app.db.session import SessionLocal
    from app.services.transcription_service import TRANSCRIPTION_ENABLED, transcribe_audio_file

    db = SessionLocal()
    try:
        obs = db.get(SessionObservation, observation_id)
        if obs is None or not obs.audio_path:
            return
        if not TRANSCRIPTION_ENABLED:
            obs.transcript_status = "unavailable"
            db.commit()
            return
        full = resolve_upload_path(obs.audio_path)
        text = transcribe_audio_file(full) if full else None
        obs.transcript = text
        obs.transcript_status = "done" if text else "failed"
        db.commit()
    except Exception:
        logger.exception("Field note transcription failed")
        db.rollback()
    finally:
        db.close()
