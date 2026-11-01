"""
Outgoing e-mail via the standard library (smtplib) -- no provider is hard-coded.

Configure with environment variables (see SECURITY.md):
  SMTP_HOST, SMTP_PORT (default 587), SMTP_USER, SMTP_PASSWORD,
  SMTP_FROM, SMTP_STARTTLS (default true; port 465 uses implicit TLS).

The OTP code is never written to the log.
"""

import logging
import re
import smtplib
import ssl
from email.message import EmailMessage

from app.core.config import settings

logger = logging.getLogger(__name__)

_SIMPLE_EMAIL = re.compile(r"^[^@\s\r\n<>]+@[^@\s\r\n<>]+\.[^@\s\r\n<>]+$")
SMTP_TIMEOUT_SECONDS = 15


def smtp_configured() -> bool:
    return settings.smtp_configured


def _build_message(to_email: str, subject: str, body: str) -> EmailMessage:
    msg = EmailMessage()
    msg["From"] = settings.SMTP_FROM
    msg["To"] = to_email
    msg["Subject"] = subject
    msg.set_content(body)
    return msg


def send_email(to_email: str, subject: str, body: str) -> bool:
    """Sends a plain-text e-mail. Returns True on success; never raises (errors are logged)."""
    if not _SIMPLE_EMAIL.match(to_email or ""):
        logger.warning("Refusing to send e-mail to a malformed address.")
        return False
    if not settings.smtp_configured:
        logger.error("E-mail not sent: SMTP is not configured (SMTP_HOST / SMTP_FROM).")
        return False

    host = settings.SMTP_HOST.strip()
    port = int(settings.SMTP_PORT)
    try:
        msg = _build_message(to_email, subject, body)
        context = ssl.create_default_context()
        if port == 465:
            server: smtplib.SMTP = smtplib.SMTP_SSL(host, port, timeout=SMTP_TIMEOUT_SECONDS, context=context)
        else:
            server = smtplib.SMTP(host, port, timeout=SMTP_TIMEOUT_SECONDS)
        with server:
            server.ehlo()
            if port != 465 and settings.smtp_starttls:
                server.starttls(context=context)
                server.ehlo()
            if settings.SMTP_USER:
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD or "")
            server.send_message(msg)
        return True
    except Exception as exc:  # network/auth/TLS problems must not leak to the client
        logger.error("Failed to send e-mail via SMTP (%s): %s", type(exc).__name__, exc)
        return False


def send_otp_email(to_email: str, code: str, ttl_minutes: int) -> bool:
    subject = "Your Road Inspection login code"
    body = (
        f"Your one-time login code is: {code}\n\n"
        f"It expires in {ttl_minutes} minutes and can be used once.\n"
        "If you did not request this code you can ignore this e-mail."
    )
    return send_email(to_email, subject, body)
