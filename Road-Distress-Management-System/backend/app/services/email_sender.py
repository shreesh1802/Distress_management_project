"""
Outgoing e-mail, standard library only. Two delivery paths:

* HTTPS API (Brevo) when BREVO_API_KEY and SMTP_FROM are set. Use this where outbound SMTP is blocked
  (Railway Free/Hobby plans): the connection is ordinary HTTPS on port 443.
* SMTP (smtplib) otherwise: SMTP_HOST, SMTP_PORT (default 587), SMTP_USER, SMTP_PASSWORD,
  SMTP_FROM, SMTP_STARTTLS (default true; port 465 uses implicit TLS).

Configure with environment variables (see SECURITY.md). The OTP code and the API key are never written to the log.
"""

import json
import logging
import re
import smtplib
import ssl
import urllib.error
import urllib.request
from email.message import EmailMessage
from email.utils import parseaddr

from app.core.config import settings

logger = logging.getLogger(__name__)

_SIMPLE_EMAIL = re.compile(r"^[^@\s\r\n<>]+@[^@\s\r\n<>]+\.[^@\s\r\n<>]+$")
SMTP_TIMEOUT_SECONDS = 15
BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"  # a constant on purpose: not configurable, always HTTPS


def smtp_configured() -> bool:
    return settings.smtp_configured


def _build_message(to_email: str, subject: str, body: str) -> EmailMessage:
    msg = EmailMessage()
    msg["From"] = settings.SMTP_FROM
    msg["To"] = to_email
    msg["Subject"] = subject
    msg.set_content(body)
    return msg


def _send_via_brevo(to_email: str, subject: str, body: str) -> bool:
    name, address = parseaddr(settings.SMTP_FROM or "")
    sender = {"email": address}
    if name:
        sender["name"] = name
    payload = json.dumps({"sender": sender, "to": [{"email": to_email}], "subject": subject, "textContent": body})
    request = urllib.request.Request(
        BREVO_API_URL,
        data=payload.encode("utf-8"),
        method="POST",
        headers={
            "api-key": (settings.BREVO_API_KEY or "").strip(),
            "content-type": "application/json",
            "accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=SMTP_TIMEOUT_SECONDS) as response:
            return 200 <= response.status < 300
    except urllib.error.HTTPError as exc:
        try:
            detail = json.loads(exc.read().decode("utf-8", "replace")).get("message", "")
        except Exception:
            detail = ""
        logger.error("Failed to send e-mail via the Brevo API (HTTP %s): %s", exc.code, str(detail)[:200])
        return False
    except Exception as exc:  # network/TLS problems must not leak to the client
        logger.error("Failed to send e-mail via the Brevo API (%s): %s", type(exc).__name__, exc)
        return False


def send_email(to_email: str, subject: str, body: str) -> bool:
    """Sends a plain-text e-mail. Returns True on success; never raises (errors are logged)."""
    if not _SIMPLE_EMAIL.match(to_email or ""):
        logger.warning("Refusing to send e-mail to a malformed address.")
        return False
    if settings.email_api_configured:
        return _send_via_brevo(to_email, subject, body)
    if not settings.smtp_configured:
        logger.error("E-mail not sent: no delivery configured (BREVO_API_KEY or SMTP_HOST, plus SMTP_FROM).")
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
