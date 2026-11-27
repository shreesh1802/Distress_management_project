"""
Times: stored and sent in UTC, shown to people in their own time zone.

The database and the API always work in UTC (every API timestamp carries its "+00:00", so the app can
convert it to the phone's local time). Text the server writes for people to read -- report headers, a
live session's name, field-note times -- uses REPORT_TIMEZONE instead (default Asia/Kolkata, i.e. IST),
because a PDF or Excel file cannot adapt to whoever opens it.
"""

import logging
import os
from datetime import datetime, timedelta, timezone, tzinfo
from typing import Optional

logger = logging.getLogger(__name__)

DEFAULT_REPORT_TIMEZONE = "Asia/Kolkata"

# Used only when the operating system has no time zone database (e.g. Windows without the tzdata package).
_FIXED_ZONES = {
    "asia/kolkata": (timedelta(hours=5, minutes=30), "IST"),
    "asia/calcutta": (timedelta(hours=5, minutes=30), "IST"),
    "utc": (timedelta(0), "UTC"),
    "etc/utc": (timedelta(0), "UTC"),
}


def load_report_zone(name: Optional[str] = None) -> tzinfo:
    """The zone named by REPORT_TIMEZONE (or ``name``); unknown names fall back to UTC with a warning."""
    key = (name if name is not None else os.getenv("REPORT_TIMEZONE", DEFAULT_REPORT_TIMEZONE)).strip()
    key = key or DEFAULT_REPORT_TIMEZONE
    try:
        from zoneinfo import ZoneInfo

        return ZoneInfo(key)
    except Exception:
        fixed = _FIXED_ZONES.get(key.lower())
        if fixed is not None:
            return timezone(fixed[0], fixed[1])
        logger.warning("REPORT_TIMEZONE=%r is not a known time zone; report times will be in UTC.", key)
        return timezone.utc


REPORT_ZONE: tzinfo = load_report_zone()


def utc_now() -> datetime:
    """Now, as an aware UTC datetime (use this instead of datetime.utcnow() / datetime.now())."""
    return datetime.now(timezone.utc)


def as_utc(value: Optional[datetime]) -> Optional[datetime]:
    """An aware UTC datetime. A naive value is taken to be UTC already (that is how this app stores times)."""
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def to_report_time(value: Optional[datetime]) -> Optional[datetime]:
    """``value`` in the report time zone (for text people read)."""
    utc = as_utc(value)
    return None if utc is None else utc.astimezone(REPORT_ZONE)


def report_now() -> datetime:
    """Now, in the report time zone."""
    return utc_now().astimezone(REPORT_ZONE)


def format_report_time(value: Optional[datetime], fmt: str = "%Y-%m-%d %H:%M:%S", with_zone: bool = True) -> str:
    """e.g. "2026-11-28 02:00:00 IST"; an empty string for no time."""
    local = to_report_time(value)
    if local is None:
        return ""
    text = local.strftime(fmt)
    zone = local.tzname() if with_zone else None
    return f"{text} {zone}" if zone else text
