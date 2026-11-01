"""
Authentication routes for the Road Distress Management System.

Email + OTP login (request-otp / verify-otp) is what the app uses. The
password-based /login and the public /register are kept for compatibility:
/register ALWAYS creates a non-admin account (the role is chosen by the
server, never by the client).

Abuse protection (in-process counters, per instance -- see app/core/rate_limit.py):
request-otp / verify-otp / login / register are rate limited per client IP, and
OTP guessing is additionally limited per e-mail address.
"""

import logging
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, Depends, Header, HTTPException, Request, Response, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from app.core.config import settings
from app.core.rate_limit import SlidingWindowLimiter, client_ip
from app.db.session import get_db
from app.crud.user import get_user_by_email, create_user
from app.schemas.user import UserResponse, RegisterRequest
from app.core.security import verify_password, normalize_email, is_usable_hash, dummy_password_hash
from app.core.roles import SELF_REGISTER_ROLE
from app.core.deps import get_current_user, extract_bearer_token, registration_gate
from app.models.user import User
from app.services import otp_service
from app.services.otp_service import create_otp, deliver_otp_email, verify_otp, issue_token, revoke_token, OtpLocked

logger = logging.getLogger(__name__)

router = APIRouter()

# Per-IP throttles for the password routes (each login attempt costs a PBKDF2 run).
login_limiter = SlidingWindowLimiter(30, 60)
register_limiter = SlidingWindowLimiter(20, 3600)

def _too_many(detail: str = "Too many requests. Please try again later.") -> HTTPException:
    return HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, detail, headers={"Retry-After": "900"})


class LoginRequest(BaseModel):
    """
    Request model for user authentication.
    """
    email: str = Field(..., max_length=255)
    password: str = Field(..., max_length=128)


@router.post("/login", response_model=UserResponse)
def login(request: LoginRequest, http_request: Request, db: Session = Depends(get_db)) -> UserResponse:
    """
    Authenticate user using email and password.
    """
    if not login_limiter.hit(client_ip(http_request)):
        raise _too_many()
    user = get_user_by_email(db, email=request.email)
    # Every branch spends the same PBKDF2 time: unknown e-mails and OTP-only accounts (unusable hash)
    # are verified against a precomputed dummy hash, so response time does not reveal which case it was.
    usable = user is not None and is_usable_hash(user.hashed_password)
    password_ok = verify_password(request.password, user.hashed_password if usable else dummy_password_hash())
    if not (usable and password_ok):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    return user


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(
    user_in: RegisterRequest,
    http_request: Request,
    db: Session = Depends(get_db),
    _gate: Optional[User] = Depends(registration_gate),
) -> UserResponse:
    """
    Register a new account. Admin-only unless ALLOW_SELF_REGISTRATION is on (default: development only).
    The role is assigned by the server (always the non-admin SELF_REGISTER_ROLE); a role in the request
    body is ignored - use the admin-only POST /users/ to create other roles.
    """
    if not register_limiter.hit(client_ip(http_request)):
        raise _too_many()
    if get_user_by_email(db, email=user_in.email):
        # Deliberately generic: do not confirm which e-mails already have an account.
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Registration could not be completed"
        )
    return create_user(db, user_in=user_in, role=SELF_REGISTER_ROLE)


class RequestOtpRequest(BaseModel):
    email: str = Field(..., max_length=255)


class RequestOtpResponse(BaseModel):
    sent: bool
    dev_otp: str | None = None  # only ever populated in development mode (never in production)


@router.post("/request-otp", response_model=RequestOtpResponse)
def request_otp_route(
    req: RequestOtpRequest,
    http_request: Request,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
) -> RequestOtpResponse:
    """
    Step 1 of Email + OTP login: send a 6-digit code to an *existing*
    account's email. The response is identical for known and unknown e-mails
    (sent=true, dev_otp=null) so account existence is not revealed; in
    production the code is only ever delivered by e-mail. In development the
    code for a known account is returned in ``dev_otp``.
    """
    if not otp_service.ip_request_limiter.hit(client_ip(http_request)):
        raise _too_many()

    email = normalize_email(req.email)
    user = get_user_by_email(db, email=email)
    dev_otp: Optional[str] = None
    if user is not None:
        code = create_otp(db, email)
        if code is not None:
            if settings.otp_dev_mode:
                logger.info("[DEV MODE] OTP issued for a login request; the code is returned in the API response only.")
                dev_otp = code
            elif settings.smtp_configured:
                # Sent after the response so latency does not differ from the unknown-email path.
                background_tasks.add_task(deliver_otp_email, email, code)
            else:
                logger.error("Cannot deliver login code: SMTP is not configured and dev OTP mode is off.")
    return RequestOtpResponse(sent=True, dev_otp=dev_otp)


class VerifyOtpRequest(BaseModel):
    email: str = Field(..., max_length=255)
    code: str = Field(..., max_length=16)


class VerifyOtpResponse(BaseModel):
    token: str
    user: UserResponse


@router.post("/verify-otp", response_model=VerifyOtpResponse)
def verify_otp_route(
    req: VerifyOtpRequest,
    http_request: Request,
    db: Session = Depends(get_db),
) -> VerifyOtpResponse:
    """Step 2: verify the code and issue a bearer session token."""
    ip = client_ip(http_request)
    if otp_service.ip_lockout.is_locked(ip):
        raise _too_many("Too many failed attempts. Please try again later.")

    user = get_user_by_email(db, email=req.email)
    try:
        code_ok = verify_otp(db, req.email, req.code, account_exists=user is not None)
    except OtpLocked:
        # Deliberately the SAME answer as an ordinary wrong code: a per-e-mail lock only exists for real
        # accounts, so a distinct 429 here would reveal that the address has an account.
        code_ok = False

    if user is None or not code_ok:
        otp_service.ip_lockout.register_failure(ip)
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired code")
    token = issue_token(db, user.id)
    return VerifyOtpResponse(token=token, user=UserResponse.model_validate(user))


@router.get("/me", response_model=UserResponse)
def me(user: User = Depends(get_current_user)) -> UserResponse:
    """Resolve the current session token to the logged-in user -- used to
    restore a session on app launch without asking the user to log in
    again every time."""
    return UserResponse.model_validate(user)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    authorization: Optional[str] = Header(default=None),
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
) -> Response:
    """Server-side logout: invalidates the presented session token."""
    revoke_token(db, extract_bearer_token(authorization) or "")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
