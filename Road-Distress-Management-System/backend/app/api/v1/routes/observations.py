"""
Field notes -- what the surveyor adds by hand while a live session is running: a snapshot of the camera
picture and / or a voice note (with an optional typed caption) for something the detection missed. Each note
belongs to the live session's report and is included in that report's PDF and Excel files.

Endpoints:
  POST   /observations/live           add a note to the RUNNING live session (multipart form)
  GET    /observations?video_id=N     the notes of a report, oldest first
  DELETE /observations/{id}           remove a note and its files
  GET    /observations/{id}/image     the snapshot  (bearer token or signed link)
  GET    /observations/{id}/audio     the voice note (bearer token or signed link)

The first three need a bearer token (router-level dependency in app/main.py); the two file routes also accept
a short-lived signed link, because an <img> or an audio player cannot attach an Authorization header.
"""

import os
from typing import List, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, Header, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.deps import extract_bearer_token, get_current_user, user_for_token
from app.core.safe_paths import resolve_upload_path
from app.core.upload_checks import content_type_for
from app.db.session import get_db
from app.models.observation import SessionObservation
from app.models.user import User
from app.schemas.observation import FieldNoteResponse
from app.services import observation_service as svc
from app.services.download_links import sign_download_token, verify_download_token
from app.services.live.live_camera_service import LiveCameraManager

router = APIRouter()        # bearer token required (see app/main.py)
file_router = APIRouter()   # bearer token OR signed link

LINK_TTL_SECONDS = 3600


def _link(kind: str, obs_id: int) -> str:
    token = sign_download_token(f"obs-{kind}", obs_id, ttl_seconds=LINK_TTL_SECONDS)
    return f"/api/v1/observations/{obs_id}/{kind}?t={token}"


def to_response(obs: SessionObservation) -> FieldNoteResponse:
    return FieldNoteResponse(
        id=obs.id,
        video_id=obs.video_id,
        created_at=obs.created_at,
        note=obs.note,
        has_image=bool(obs.image_path),
        has_audio=bool(obs.audio_path),
        audio_duration_seconds=obs.audio_duration_seconds,
        transcript=obs.transcript,
        transcript_status=obs.transcript_status,
        latitude=obs.latitude,
        longitude=obs.longitude,
        image_url=_link("image", obs.id) if obs.image_path else None,
        audio_url=_link("audio", obs.id) if obs.audio_path else None,
    )


@router.post("/live", response_model=FieldNoteResponse, status_code=status.HTTP_201_CREATED)
async def add_live_note(
    background_tasks: BackgroundTasks,
    snapshot: bool = Form(False),
    note: Optional[str] = Form(None, max_length=svc.MAX_NOTE_CHARS),
    audio_duration_seconds: Optional[float] = Form(None, ge=0, le=3600, allow_inf_nan=False),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> FieldNoteResponse:
    """
    Adds a note to the live session that is running right now: ``snapshot=true`` saves the newest camera
    picture, ``file`` is a voice recording, ``note`` is an optional typed caption. At least one is needed.
    """
    has_audio = file is not None and bool(file.filename)
    if not snapshot and not has_audio and not (note or "").strip():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Add a snapshot, a voice note or some text.")

    manager = LiveCameraManager.instance()
    if not manager.is_running():
        raise HTTPException(status.HTTP_409_CONFLICT, "Start live detection first, then add notes to it.")

    frame = None
    if snapshot:
        frame = manager.snapshot_frame()
        if frame is None:
            raise HTTPException(status.HTTP_409_CONFLICT, "No camera picture has arrived yet. Try again in a moment.")

    video_id = manager.ensure_session_video(db)
    if svc.count_for_video(db, video_id) >= svc.MAX_NOTES_PER_SESSION:
        raise HTTPException(status.HTTP_409_CONFLICT, "This session already has the maximum number of notes.")

    image_path = svc.save_snapshot(frame) if frame is not None else None
    audio_path = audio_name = None
    if has_audio:
        try:
            audio_path, audio_name = await svc.save_audio(file)
        except Exception:
            if image_path:  # do not leave the snapshot behind when the voice note is refused
                full = resolve_upload_path(image_path)
                if full and os.path.exists(full):
                    os.remove(full)
            raise

    latitude, longitude = manager.session_location()
    obs = svc.create_observation(
        db,
        video_id=video_id,
        user_id=user.id,
        note=note,
        image_path=image_path,
        audio_path=audio_path,
        audio_filename=audio_name,
        audio_duration_seconds=audio_duration_seconds,
        latitude=latitude,
        longitude=longitude,
    )
    if audio_path:
        background_tasks.add_task(svc.run_transcription_job, obs.id)
    return to_response(obs)


@router.get("", response_model=List[FieldNoteResponse])
def list_notes(
    video_id: int = Query(..., ge=1),
    db: Session = Depends(get_db),
) -> List[FieldNoteResponse]:
    return [to_response(o) for o in svc.list_for_video(db, video_id)]


@router.delete("/{observation_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_note(observation_id: int, db: Session = Depends(get_db)) -> None:
    obs = db.get(SessionObservation, observation_id)
    if obs is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Note not found")
    svc.delete_observation(db, obs)


def _file_for(kind: str, observation_id: int, token: Optional[str], authorization: Optional[str], db: Session):
    if user_for_token(db, extract_bearer_token(authorization)) is None and not verify_download_token(
        token, f"obs-{kind}", observation_id
    ):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Not authenticated", headers={"WWW-Authenticate": "Bearer"})
    obs = db.get(SessionObservation, observation_id)
    stored = None if obs is None else (obs.image_path if kind == "image" else obs.audio_path)
    full = resolve_upload_path(stored) if stored else None
    if full is None or not os.path.isfile(full):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "File not found")
    return FileResponse(full, media_type=content_type_for(full), headers={"X-Content-Type-Options": "nosniff"})


@file_router.get("/{observation_id}/image")
def get_note_image(
    observation_id: int,
    t: Optional[str] = Query(None),
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db),
):
    return _file_for("image", observation_id, t, authorization, db)


@file_router.get("/{observation_id}/audio")
def get_note_audio(
    observation_id: int,
    t: Optional[str] = Query(None),
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db),
):
    return _file_for("audio", observation_id, t, authorization, db)
