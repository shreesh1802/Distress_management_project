"""
Login allow-list, managed in the Firebase console (Firestore).

Who can sign in is decided by the Firestore collection `allowedUsers`: one
document per person, whose document ID is their Google email (lowercase),
with fields:
    role  -- "admin", "inspector" or "maintenance" (default "inspector")
    name  -- optional display name

The SQL users table is kept as a mirror of it, because projects, audits,
reports etc. reference users.id: sync_user() creates/updates a person's row
from their Firestore document, and access is re-checked on every request
(cached briefly), so deleting someone's document revokes their access
within ALLOWLIST_CACHE_SECONDS -- no redeploy or app update needed.
"""

import logging
import time

from firebase_admin import firestore
from sqlalchemy.orm import Session

from app.core.roles import ALL_ROLES
from app.crud.user import create_user, get_user_by_email
from app.models.user import User
from app.schemas.user import UserCreate
from app.services.firebase_service import get_firebase_app

logger = logging.getLogger(__name__)

ALLOWLIST_COLLECTION = "allowedUsers"
ALLOWLIST_CACHE_SECONDS = 60
DEFAULT_ROLE = "inspector"

# email -> (expires_at, document dict, or None when not on the list)
_cache: dict[str, tuple[float, dict | None]] = {}


def get_allowed_entry(email: str) -> dict | None:
    """The person's allowedUsers document, or None if they aren't on the list.
    Raises if Firestore can't be reached -- callers decide how to handle that."""
    email = email.strip().lower()
    cached = _cache.get(email)
    if cached and cached[0] > time.monotonic():
        return cached[1]

    client = firestore.client(app=get_firebase_app())
    snapshot = client.collection(ALLOWLIST_COLLECTION).document(email).get()
    entry = _normalize(snapshot.to_dict() or {}) if snapshot.exists else None
    _cache[email] = (time.monotonic() + ALLOWLIST_CACHE_SECONDS, entry)
    return entry


def _normalize(doc: dict) -> dict:
    # Documents are typed by hand in the Firebase console, where a stray
    # space or capital ("role ", "Name") is easy to miss -- accept those.
    return {
        str(k).strip().lower(): v.strip() if isinstance(v, str) else v
        for k, v in doc.items()
    }


def _role_of(entry: dict) -> str:
    """The role in the document; a typo or unknown value gets the least-privileged default, never admin by accident."""
    role = entry.get("role")
    role = role.strip().lower() if isinstance(role, str) and role.strip() else DEFAULT_ROLE
    return role if role in ALL_ROLES else DEFAULT_ROLE


def remove_allowed_entry(email: str) -> None:
    """Deletes the person's allowedUsers document (used when they delete their own account)."""
    email = email.strip().lower()
    client = firestore.client(app=get_firebase_app())
    client.collection(ALLOWLIST_COLLECTION).document(email).delete()
    _cache.pop(email, None)


def apply_entry(db: Session, user: User, entry: dict) -> User:
    """Copy role/name from the Firestore document onto the SQL row."""
    role = _role_of(entry)
    name = entry.get("name")
    changed = False
    if user.role != role:
        user.role = role
        changed = True
    if isinstance(name, str) and name.strip() and user.full_name != name.strip():
        user.full_name = name.strip()
        changed = True
    if changed:
        db.commit()
        db.refresh(user)
    return user


def sync_user(db: Session, email: str, fallback_name: str | None = None) -> User | None:
    """
    Returns the SQL user for an allowed email -- created on first sight and
    kept in step with Firestore -- or None if the email isn't on the list.
    """
    email = email.strip().lower()
    entry = get_allowed_entry(email)
    if entry is None:
        return None

    user = get_user_by_email(db, email=email)
    if user is None:
        name = entry.get("name") if isinstance(entry.get("name"), str) else fallback_name
        user = create_user(db, UserCreate(email=email, full_name=name, role=_role_of(entry)))
        logger.info(f"Created user {email} from the Firestore allow-list")
        return user
    return apply_entry(db, user, entry)
