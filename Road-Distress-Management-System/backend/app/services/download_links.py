"""
Short-lived signed download links for report files.

Browsers and the OS cannot attach an ``Authorization`` header when they open a
download URL (``launchUrl``, ``<a href>``), so the app asks an AUTHENTICATED
endpoint (POST /reports/{id}/download-link) for a link carrying a token:
``t=<expiry>.<HMAC-SHA256(secret, purpose:report_id:expiry)>``.

The token is bound to the report id and to the purpose (pdf / excel / preview),
expires after ``LINK_TTL_SECONDS`` and is verified in constant time. The secret
comes from ``DOWNLOAD_SIGNING_SECRET`` (required in production; in development
a random per-process secret is used, so links do not survive a restart).
"""

import hashlib
import hmac
import secrets
import time
from typing import Optional

from app.core.config import settings

LINK_TTL_SECONDS = 300
PURPOSES = ("pdf", "excel", "preview")

_dev_secret = secrets.token_bytes(32)


def _secret() -> bytes:
    configured = (settings.DOWNLOAD_SIGNING_SECRET or "").encode("utf-8")
    return configured if configured else _dev_secret


def _mac(purpose: str, report_id: int, expires_at: int) -> str:
    msg = f"{purpose}:{int(report_id)}:{int(expires_at)}".encode("utf-8")
    return hmac.new(_secret(), msg, hashlib.sha256).hexdigest()


def sign_download_token(purpose: str, report_id: int, ttl_seconds: int = LINK_TTL_SECONDS) -> str:
    if purpose not in PURPOSES:
        raise ValueError("unknown download purpose")
    expires_at = int(time.time()) + int(ttl_seconds)
    return f"{expires_at}.{_mac(purpose, report_id, expires_at)}"


def verify_download_token(token: Optional[str], purpose: str, report_id: int) -> bool:
    if not token or purpose not in PURPOSES or "." not in token or len(token) > 200:
        return False
    exp_str, _, mac = token.partition(".")
    try:
        expires_at = int(exp_str)
    except ValueError:
        return False
    if expires_at < int(time.time()):
        return False
    return hmac.compare_digest(_mac(purpose, report_id, expires_at), mac)
