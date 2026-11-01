"""
OTP generation/verification and session tokens for Email + OTP login.

Delivery
--------
* Development (``APP_ENV`` unset/"development", the default): the code is
  returned in the /auth/request-otp response as ``dev_otp`` so the whole flow
  works locally without a mailbox. The code is NEVER written to the log.
* Production (``APP_ENV=production``): the code is e-mailed through stdlib
  SMTP (``app.services.email_sender``) and is never returned or logged.

Hardening (see SECURITY.md)
---------------------------
* codes come from ``secrets.randbelow`` (CSPRNG);
* requesting a new code invalidates every older unused code for the e-mail;
* e-mails are normalised (strip + lower) everywhere;
* verification uses ``hmac.compare_digest`` and an atomic
  ``UPDATE ... WHERE used = false`` so a code is single-use even under races;
* wrong guesses are counted per e-mail and per IP; N failures lock the key
  (in-process counters -- per instance, cleared on restart);
* session tokens are stored only as a SHA-256 hash (the raw token exists only
  in the login response and the client), expire after 7 days and expired rows
  are purged opportunistically; ``revoke_token`` implements server-side logout.
"""

import hashlib
import hmac
import logging
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import update, delete
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.rate_limit import FailureLockout, SlidingWindowLimiter
from app.core.roles import Role
from app.core.security import normalize_email
from app.models.auth import OtpCode, AuthToken
from app.services import email_sender

logger = logging.getLogger(__name__)

OTP_LENGTH = 6
OTP_TTL_MINUTES = 10
TOKEN_TTL_DAYS = 7

# --- abuse limits (in-process, per instance) -------------------------------------
OTP_MAX_FAILED_ATTEMPTS = 5          # wrong codes per e-mail before lockout
OTP_IP_MAX_FAILED_ATTEMPTS = 100     # wrong codes per client IP before lockout (backstop; the per-e-mail limit is the main control)
OTP_LOCKOUT_SECONDS = 15 * 60
OTP_FAILURE_WINDOW_SECONDS = 15 * 60
OTP_REQUESTS_PER_EMAIL = 5           # new codes per e-mail per 10 minutes
OTP_REQUESTS_PER_IP = 60             # request-otp calls per client IP per 10 minutes

email_lockout = FailureLockout(OTP_MAX_FAILED_ATTEMPTS, OTP_FAILURE_WINDOW_SECONDS, OTP_LOCKOUT_SECONDS)
ip_lockout = FailureLockout(OTP_IP_MAX_FAILED_ATTEMPTS, OTP_FAILURE_WINDOW_SECONDS, OTP_LOCKOUT_SECONDS)
email_request_limiter = SlidingWindowLimiter(OTP_REQUESTS_PER_EMAIL, 600)
ip_request_limiter = SlidingWindowLimiter(OTP_REQUESTS_PER_IP, 600)


class OtpLocked(Exception):
    """Raised when verification is refused because the e-mail is temporarily locked."""


def reset_abuse_counters() -> None:
    """Clears all in-process counters (used by tests)."""
    email_lockout.reset()
    ip_lockout.reset()
    email_request_limiter.reset()
    ip_request_limiter.reset()


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _generate_code() -> str:
    return f"{secrets.randbelow(10 ** OTP_LENGTH):0{OTP_LENGTH}d}"


def create_otp(db: Session, email: str) -> Optional[str]:
    """
    Issues a fresh code for ``email`` and invalidates all older unused codes.
    Returns the code, or None if the e-mail is currently throttled/locked
    (callers must respond identically either way).
    """
    email = normalize_email(email)
    if email_lockout.is_locked(email):
        return None
    if not email_request_limiter.hit(email):
        return None

    now = _utcnow()
    # Opportunistic cleanup of old rows (>1 day) so the table cannot grow forever.
    db.execute(delete(OtpCode).where(OtpCode.expires_at < now - timedelta(days=1)))
    # One active code per e-mail: burn every previous unused code.
    db.execute(update(OtpCode).where(OtpCode.email == email, OtpCode.used == False).values(used=True))  # noqa: E712

    code = _generate_code()
    db.add(OtpCode(email=email, code=code, expires_at=now + timedelta(minutes=OTP_TTL_MINUTES)))
    db.commit()
    return code


def deliver_otp_email(email: str, code: str) -> None:
    """Background-task entry point: e-mails the code (never logs it)."""
    if not email_sender.send_otp_email(email, code, OTP_TTL_MINUTES):
        logger.error("OTP e-mail could not be delivered for a login request.")


def request_otp(db: Session, email: str) -> Optional[str]:
    """
    Convenience helper: issues a code and, outside dev mode, delivers it
    synchronously by e-mail. Returns the code ONLY in development mode.
    (The HTTP route uses create_otp + a background task instead.)
    """
    code = create_otp(db, email)
    if code is None:
        return None
    if settings.otp_dev_mode:
        logger.info("[DEV MODE] OTP issued (expires in %d min); code is returned in the API response only.", OTP_TTL_MINUTES)
        return code
    deliver_otp_email(normalize_email(email), code)
    return None


def is_reviewer_email(email: str) -> bool:
    """True when ``email`` is the app-store reviewer account and reviewer access is configured."""
    return settings.reviewer_access_enabled and normalize_email(email) == settings.reviewer_email


def reviewer_code_matches(user, code: str) -> bool:
    """
    App-store reviewer sign-in: the designated REVIEWER_EMAIL account may use the fixed REVIEWER_CODE.
    Never applies to an administrator (a reviewer address that is, or later becomes, an admin is refused),
    honours the per-e-mail lockout, and wrong guesses are counted by the normal verify_otp path that
    the caller falls through to.
    """
    if user is None or not is_reviewer_email(user.email) or user.role == Role.ADMIN:
        return False
    email = normalize_email(user.email)
    if email_lockout.is_locked(email):
        return False
    expected = (settings.REVIEWER_CODE or "").strip().encode("utf-8")
    if not hmac.compare_digest(expected, (code or "").strip().encode("utf-8")):
        return False
    email_lockout.register_success(email)
    return True


def verify_otp(db: Session, email: str, code: str, account_exists: bool = True) -> bool:
    """
    True if ``code`` is the current, unused, unexpired code for ``email``; the code is
    consumed atomically. Raises OtpLocked while the e-mail is locked out.

    ``account_exists=False`` (the e-mail belongs to no account) never creates per-e-mail state: otherwise an
    attacker submitting endless distinct addresses could grow the lockout table without bound. Such guesses
    are still throttled per client IP by the caller. The caller must answer the locked and the plain-failure
    case identically so account existence stays hidden.
    """
    email = normalize_email(email)
    if not account_exists:
        # same constant-time comparison work, no per-e-mail bookkeeping
        hmac.compare_digest(("0" * OTP_LENGTH).encode("utf-8"), (code or "").strip().encode("utf-8"))
        return False
    if email_lockout.is_locked(email):
        raise OtpLocked()

    code = (code or "").strip()
    now = _utcnow()
    otp = (
        db.query(OtpCode)
        .filter(OtpCode.email == email, OtpCode.used == False)  # noqa: E712
        .order_by(OtpCode.id.desc())
        .first()
    )

    expected = otp.code if otp is not None else "0" * OTP_LENGTH
    code_matches = hmac.compare_digest(expected.encode("utf-8"), code.encode("utf-8"))
    valid = otp is not None and code_matches and _aware(otp.expires_at) >= now

    if valid:
        # Atomic single-use: only one concurrent request can flip used false -> true.
        result = db.execute(
            update(OtpCode).where(OtpCode.id == otp.id, OtpCode.used == False).values(used=True)  # noqa: E712
        )
        db.commit()
        if result.rowcount == 1:
            email_lockout.register_success(email)
            return True

    locked = email_lockout.register_failure(email)
    if locked and otp is not None:
        # Burn the active code so even the right code no longer works after a lockout.
        db.execute(update(OtpCode).where(OtpCode.email == email, OtpCode.used == False).values(used=True))  # noqa: E712
        db.commit()
    return False


# ---------------------------------------------------------------- sessions
def hash_token(token: str) -> str:
    """SHA-256 hex digest -- the only form of a session token that is ever stored."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_token(db: Session, user_id: int) -> str:
    """Creates a session and returns the RAW token (shown to the client once; only its hash is stored)."""
    now = _utcnow()
    db.execute(delete(AuthToken).where(AuthToken.expires_at < now))  # purge expired sessions
    token = secrets.token_hex(32)
    db.add(AuthToken(token=hash_token(token), user_id=user_id, expires_at=now + timedelta(days=TOKEN_TTL_DAYS)))
    db.commit()
    return token


def resolve_token(db: Session, token: str) -> Optional[int]:
    """Returns the user_id for a valid, unexpired token, else None."""
    if not token:
        return None
    row = db.query(AuthToken).filter(AuthToken.token == hash_token(token)).first()
    if row is None:
        return None
    if _aware(row.expires_at) < _utcnow():
        return None
    return row.user_id


def revoke_token(db: Session, token: str) -> bool:
    """Server-side logout: deletes the presented session. True if a row was removed."""
    if not token:
        return False
    result = db.execute(delete(AuthToken).where(AuthToken.token == hash_token(token)))
    db.commit()
    return result.rowcount > 0
