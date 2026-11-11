"""
Path confinement for files whose location is stored in the database.

Every ``FileResponse`` / ``os.remove`` / ``os.path.exists`` / ``Image(...)`` that
operates on a path read from the DB (``filepath``, ``processed_filepath``,
report ``filepath`` ...) MUST go through :func:`resolve_stored_path` (or one of
its wrappers). The stored value is treated as untrusted: it is resolved with
``realpath`` against a fixed base directory and rejected unless the result
lies inside one of the allowed root directories. Absolute paths, drive
letters, UNC paths, ``..`` traversal, NUL bytes and symlinks that escape the
roots are all rejected.

Layout (``BACKEND_ROOT`` = ``.../backend``):
  * uploads (videos, processed videos, crops, detections, audio, assets):
        ``BACKEND_ROOT/uploads``              -- stored paths are relative to BACKEND_ROOT
  * reports (generated PDF / Excel):
        ``PROJECT_ROOT/reports``              -- stored paths are relative to PROJECT_ROOT
    where ``PROJECT_ROOT`` is the parent of ``backend`` (the legacy layout the
    report generators have always used).
"""

import os
import re
from typing import Iterable, Optional

BACKEND_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PROJECT_ROOT = os.path.abspath(os.path.join(BACKEND_ROOT, ".."))
UPLOADS_ROOT = os.path.join(BACKEND_ROOT, "uploads")
REPORTS_ROOT = os.path.join(PROJECT_ROOT, "reports")

_WINDOWS_DRIVE = re.compile(r"^[A-Za-z]:")


def _is_foreign_absolute(value: str) -> bool:
    """True for anything that is absolute on *any* OS (posix, drive letter, UNC)."""
    return (
        value.startswith("/")
        or value.startswith("\\")
        or bool(_WINDOWS_DRIVE.match(value))
        or os.path.isabs(value)
    )


def resolve_stored_path(
    stored: Optional[str],
    base: str,
    allowed_roots: Iterable[str],
) -> Optional[str]:
    """
    Resolves ``stored`` (a path read from the DB / a client) against ``base`` and
    returns the real absolute path, or ``None`` if it is empty, absolute,
    contains NUL bytes, or resolves (after symlinks) outside ``allowed_roots``.
    The file does not have to exist.
    """
    if not stored or not isinstance(stored, str):
        return None
    if "\x00" in stored:
        return None
    candidate = stored.strip()
    # Strip a "?query" suffix some detection paths carry (tracker appends stats)
    candidate = candidate.split("?", 1)[0]
    if not candidate:
        return None
    # Treat both separators as separators regardless of the host OS.
    candidate = candidate.replace("\\", "/")
    if _is_foreign_absolute(candidate):
        return None

    real_base = os.path.realpath(base)
    real = os.path.realpath(os.path.join(real_base, candidate))
    for root in allowed_roots:
        real_root = os.path.realpath(root)
        try:
            if os.path.commonpath([real, real_root]) == real_root and real != real_root:
                return real
        except ValueError:
            # Different drives on Windows -> definitely not inside this root.
            continue
    return None


def resolve_upload_path(stored: Optional[str]) -> Optional[str]:
    """Stored path relative to the backend root, confined to ``uploads/``."""
    return resolve_stored_path(stored, BACKEND_ROOT, [UPLOADS_ROOT])


def resolve_report_path(stored: Optional[str]) -> Optional[str]:
    """Stored report path (relative to the project root), confined to ``reports/``."""
    return resolve_stored_path(stored, PROJECT_ROOT, [REPORTS_ROOT])


def safe_remove(real_path: Optional[str]) -> bool:
    """Removes an already-resolved path if it is a regular file. Never raises on a missing file."""
    if not real_path or not os.path.isfile(real_path):
        return False
    os.remove(real_path)
    return True


_SAFE_NAME = re.compile(r"[^a-zA-Z0-9_.\-]")


def sanitize_file_name(name: Optional[str], default: str = "file") -> str:
    """
    Reduces a client supplied file name to a harmless base name: no directory
    parts (either separator), no leading dots, only ``[A-Za-z0-9_.-]``, max 120 chars.
    """
    base = (name or "").replace("\\", "/").split("/")[-1]
    base = _SAFE_NAME.sub("_", base).lstrip(".")
    base = base[:120]
    return base or default
