"""Response shape for field notes (snapshot / voice note added by hand to a live session's report)."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class FieldNoteResponse(BaseModel):
    id: int
    video_id: int
    created_at: Optional[datetime] = None
    note: Optional[str] = None
    has_image: bool
    has_audio: bool
    audio_duration_seconds: Optional[float] = None
    transcript: Optional[str] = None
    transcript_status: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    # Short-lived signed paths (relative to the server root): the picture / sound can be opened by an
    # <img> or an audio player, which cannot send a bearer token.
    image_url: Optional[str] = None
    audio_url: Optional[str] = None
