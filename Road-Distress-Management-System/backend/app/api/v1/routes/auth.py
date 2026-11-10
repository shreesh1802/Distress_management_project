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
"""

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.db.session import get_db
from app.crud.user import get_user_by_email, create_user
from app.schemas.user import UserResponse, UserCreate
from app.core.security import verify_password
from app.core.deps import get_current_user, require_admin
from app.models.user import User
from app.services.session_service import issue_token
from app.services.access_service import sync_user
from app.services.firebase_service import get_firebase_app, verify_google_id_token

router = APIRouter()
logger = logging.getLogger(__name__)


class LoginRequest(BaseModel):
    """
    Request model for user authentication.
    """
    email: str
    password: str


@router.post("/login", response_model=UserResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)) -> UserResponse:
    """
    Authenticate user using email and password.
    """
    user = get_user_by_email(db, email=request.email)
    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    return user


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(
    user_in: UserCreate,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
) -> UserResponse:
    """
    Register a new inspector or user in the database (admin only -- the
    users table is the login allow-list, so self-registration is closed).
    """
    user = get_user_by_email(db, email=user_in.email)
    if user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this email already exists"
        )
    return create_user(db, user_in=user_in)


class GoogleLoginRequest(BaseModel):
    id_token: str


class SessionResponse(BaseModel):
    token: str
    user: UserResponse


@router.post("/google", response_model=SessionResponse)
def google_login_route(req: GoogleLoginRequest, db: Session = Depends(get_db)) -> SessionResponse:
    """
    Google sign-in via Firebase: verify the Firebase ID token, check the
    email against the Firestore allow-list, and issue a bearer session
    token. An email that isn't on the list gets a 403.
    """
    try:
        get_firebase_app()
    except Exception as e:
        # A server-side setup problem (e.g. the service-account key file is
        # missing) -- not the user's fault, so don't report it as a bad token.
        logger.error(f"Firebase Admin isn't configured: {type(e).__name__}: {e}")
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Sign-in isn't configured on the server. Please contact an administrator.",
        )

    try:
        claims = verify_google_id_token(req.id_token)
    except Exception as e:
        logger.warning(f"Rejected Google ID token: {type(e).__name__}: {e}")
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid Google token")

    email = claims.get("email")
    if not email or not claims.get("email_verified"):
        logger.warning(f"Rejected Google sign-in for unverified email: {email!r}")
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Google email not verified")

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
