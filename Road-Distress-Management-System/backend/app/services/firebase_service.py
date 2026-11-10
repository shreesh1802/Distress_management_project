"""
Firebase Admin wrapper: verifies the Firebase ID token the mobile/web app
gets after Google login (see POST /auth/google), and provides the app that
app/services/access_service.py reads the Firestore allow-list with.
"""

import json

import firebase_admin
from firebase_admin import auth as firebase_auth, credentials

from app.core.config import settings


def get_firebase_app() -> firebase_admin.App:
    if firebase_admin._apps:
        return firebase_admin.get_app()
    if settings.FIREBASE_CREDENTIALS_JSON:
        cred = credentials.Certificate(json.loads(settings.FIREBASE_CREDENTIALS_JSON))
    elif settings.FIREBASE_CREDENTIALS_PATH:
        cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
    else:
        raise RuntimeError("Firebase credentials are not configured")
    return firebase_admin.initialize_app(cred)


def verify_google_id_token(id_token: str) -> dict:
    """Returns the decoded token claims (email, email_verified, uid, ...).
    Raises if the token is invalid, expired, or from another project."""
    return firebase_auth.verify_id_token(id_token, app=get_firebase_app())
