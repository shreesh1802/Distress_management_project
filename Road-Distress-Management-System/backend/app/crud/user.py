"""
CRUD operations for the User entity.
"""

import secrets
from typing import List, Optional
from sqlalchemy import select, func
from sqlalchemy.orm import Session
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate
from app.core.security import get_password_hash, normalize_email
from app.core.roles import SELF_REGISTER_ROLE


def get_user(db: Session, user_id: int) -> Optional[User]:
    """
    Retrieve a single user by ID.
    """
    return db.execute(select(User).where(User.id == user_id)).scalar_one_or_none()


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """
    Retrieve a single user by email address. The lookup is normalised
    (strip + case-insensitive) so "A@x.com " and "a@x.com" are the same account.
    """
    normalized = normalize_email(email)
    if not normalized:
        return None
    return db.execute(
        select(User).where(func.lower(User.email) == normalized).order_by(User.id)
    ).scalars().first()


def get_users(db: Session, skip: int = 0, limit: int = 100) -> List[User]:
    """
    Retrieve a list of users with pagination.
    """
    return list(db.scalars(select(User).offset(skip).limit(limit)).all())


def create_user(db: Session, user_in, role: Optional[str] = None) -> User:
    """
    Create a new user with password hashing. ``user_in`` is a UserCreate (admin route,
    carries a validated role) or a RegisterRequest (public route, no role -- pass
    ``role=`` explicitly, the server decides). The e-mail is stored normalised.
    """
    chosen_role = role or getattr(user_in, "role", None) or SELF_REGISTER_ROLE
    db_user = User(
        email=normalize_email(user_in.email),
        full_name=user_in.full_name,
        role=chosen_role,
        hashed_password=get_password_hash(user_in.password or secrets.token_urlsafe(32)),
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def update_user(db: Session, user_id: int, user_in: UserUpdate) -> Optional[User]:
    """
    Update an existing user.
    """
    db_user = get_user(db, user_id)
    if not db_user:
        return None

    update_data = user_in.model_dump(exclude_unset=True)
    for required_field in ("email", "role", "password"):
        if update_data.get(required_field, "") is None:
            update_data.pop(required_field)  # explicit null means "leave unchanged", never "clear"
    if update_data.get("email"):
        update_data["email"] = normalize_email(update_data["email"])
    if "password" in update_data:
        hashed_password = get_password_hash(update_data.pop("password"))
        db_user.hashed_password = hashed_password

    for field, value in update_data.items():
        setattr(db_user, field, value)

    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def delete_user(db: Session, user_id: int) -> Optional[User]:
    """
    Delete a user by ID.
    """
    db_user = get_user(db, user_id)
    if db_user:
        db.delete(db_user)
        db.commit()
    return db_user
