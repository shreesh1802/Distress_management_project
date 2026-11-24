"""Summary of one past live detection session, for the History screen."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class LiveSessionSummary(BaseModel):
    id: int                                   # the session's report id (an uploaded_videos row)
    name: str
    started_at: Optional[datetime] = None
    duration_seconds: Optional[float] = None
    detection_count: int = 0                  # detections saved during the session
    serious_count: int = 0                    # of those, how many were high or critical severity
    field_note_count: int = 0                 # snapshots / voice notes the surveyor added by hand
