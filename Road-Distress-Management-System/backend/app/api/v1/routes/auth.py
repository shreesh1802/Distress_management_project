"""
Authentication routes for the Road Distress Management System.

Login is Google sign-in via Firebase (POST /auth/google): the app signs the
user in with Google, sends the Firebase ID token here, and gets back an
opaque bearer session token. Only emails on the allow-list can sign in --
the Firestore `allowedUsers` collection, managed in the Firebase console
(see app/services/access_service.py).

The original password-based /login and /register are kept: /login doesn't
issue a session token (so it grants no API access), and /register is
admin-only like POST /users/.

Abuse protection (in-process counters, per instance -- see app/core/rate_limit.py): /google, /login and
/register are rate limited per client IP.
"""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request, Response, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field

from app.core.deps import extract_bearer_token, get_current_user, require_admin
from app.core.rate_limit import SlidingWindowLimiter, client_ip
from app.core.security import dummy_password_hash, is_usable_hash, normalize_email, verify_password
from app.crud.user import create_user, get_user_by_email
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserResponse
from app.services.access_service import remove_allowed_entry, sync_user
from app.services.account_deletion import AccountDeletionError, delete_account, is_placeholder_email
from app.services.firebase_service import verify_google_id_token
from app.services.session_service import issue_token, revoke_token

logger = logging.getLogger(__name__)

router = APIRouter()

# Per-IP throttles (each password login attempt costs a PBKDF2 run; each Google login a token verification).
login_limiter = SlidingWindowLimiter(30, 60)
register_limiter = SlidingWindowLimiter(20, 3600)
google_limiter = SlidingWindowLimiter(30, 60)


def _too_many(detail: str = "Too many requests. Please try again later.") -> HTTPException:
    return HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, detail, headers={"Retry-After": "60"})


class LoginRequest(BaseModel):
    """
    Request model for user authentication.
    """
    email: str = Field(..., max_length=255)
    password: str = Field(..., max_length=128)


@router.post("/login", response_model=UserResponse)
def login(request: LoginRequest, http_request: Request, db: Session = Depends(get_db)) -> UserResponse:
    """
    Authenticate user using email and password. Grants no API access (no session is issued).
    """
    if not login_limiter.hit(client_ip(http_request)):
        raise _too_many()
    user = get_user_by_email(db, email=request.email)
    # Every branch spends the same PBKDF2 time: unknown e-mails are verified against a precomputed dummy hash,
    # so response time does not reveal which case it was.
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
    user_in: UserCreate,
    http_request: Request,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
) -> UserResponse:
    """
    Register a new inspector or user in the database (admin only -- the
    users table mirrors the login allow-list, so self-registration is closed).
    Note this does not grant login access: that is the Firestore allowedUsers list.
    """
    if not register_limiter.hit(client_ip(http_request)):
        raise _too_many()
    if get_user_by_email(db, email=user_in.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this email already exists"
        )
    return create_user(db, user_in=user_in)


class GoogleLoginRequest(BaseModel):
    id_token: str = Field(..., max_length=8192)


class SessionResponse(BaseModel):
    token: str
    user: UserResponse


@router.post("/google", response_model=SessionResponse)
def google_login_route(
    req: GoogleLoginRequest,
    http_request: Request,
    db: Session = Depends(get_db),
) -> SessionResponse:
    """
    Google sign-in via Firebase: verify the Firebase ID token, check the
    email against the Firestore allow-list, and issue a bearer session
    token. An email that isn't on the list gets a 403.
    """
    if not google_limiter.hit(client_ip(http_request)):
        raise _too_many()
    try:
        claims = verify_google_id_token(req.id_token)
    except Exception:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid Google token")

    email = normalize_email(claims.get("email"))
    if not email or not claims.get("email_verified"):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Google email not verified")
    if is_placeholder_email(email):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No account for this email")

    try:
        user = sync_user(db, email, fallback_name=claims.get("name"))
    except Exception:
        logger.exception("Couldn't read the Firestore allow-list")
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Couldn't check the access list. Please try again shortly.",
        )
    if user is None:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No account for this email")

    token = issue_token(db, user.id)
    return SessionResponse(token=token, user=UserResponse.model_validate(user))


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


class DeleteAccountRequest(BaseModel):
    confirm_email: str = Field(..., max_length=255)


@router.post("/delete-account", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_account(
    req: DeleteAccountRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Response:
    """
    Permanently deletes the signed-in user's own account (Google Play account-deletion requirement).
    The caller must type their own e-mail address as confirmation. See app.services.account_deletion
    for exactly what is removed and what is kept (anonymised) for other project members. The person's
    entry in the Firestore allow-list is removed as well, so they can no longer sign in.
    """
    if normalize_email(req.confirm_email) != normalize_email(user.email):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "The e-mail address does not match your account.")
    email = user.email
    try:
        delete_account(db, user)
    except AccountDeletionError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc))
    try:
        remove_allowed_entry(email)
    except Exception:
        logger.exception("Account deleted, but the Firestore allow-list entry could not be removed")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
