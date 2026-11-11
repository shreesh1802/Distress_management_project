"""
Lightweight server-side upload checks.

* The client supplied ``Content-Type`` is never trusted: the stored content type
  is derived from the (already allow-listed) file extension.
* Magic bytes are verified ONLY for formats where the signature is unambiguous
  (PDF, PNG, JPEG, ZIP-based docx/xlsx, RIFF/WAVE). Everything else (legacy
  doc/xls, csv/txt, and the audio containers webm/ogg/m4a/mp3/aac) is accepted
  on extension alone to avoid rejecting legitimate files.
"""

import os
from typing import Optional

CONTENT_TYPES = {
    ".pdf": "application/pdf",
    ".doc": "application/msword",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".xls": "application/vnd.ms-excel",
    ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".csv": "text/csv",
    ".txt": "text/plain",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".mp3": "audio/mpeg",
    ".wav": "audio/wav",
    ".m4a": "audio/mp4",
    ".aac": "audio/aac",
    ".ogg": "audio/ogg",
    ".webm": "audio/webm",
    ".mp4": "video/mp4",
    ".avi": "video/x-msvideo",
    ".mov": "video/quicktime",
}


def content_type_for(filename: str) -> str:
    ext = os.path.splitext(filename or "")[1].lower()
    return CONTENT_TYPES.get(ext, "application/octet-stream")


def magic_matches(filename: str, head: bytes) -> bool:
    """True if the first bytes are consistent with the extension (or the extension is not sniffed)."""
    ext = os.path.splitext(filename or "")[1].lower()
    if ext == ".pdf":
        return head.startswith(b"%PDF")
    if ext == ".png":
        return head.startswith(b"\x89PNG\r\n\x1a\n")
    if ext in (".jpg", ".jpeg"):
        return head.startswith(b"\xff\xd8\xff")
    if ext in (".docx", ".xlsx"):
        return head.startswith(b"PK")
    if ext == ".wav":
        return head[:4] == b"RIFF" and head[8:12] == b"WAVE"
    return True


def file_head(path: str, size: int = 16) -> Optional[bytes]:
    try:
        with open(path, "rb") as fh:
            return fh.read(size)
    except OSError:
        return None
