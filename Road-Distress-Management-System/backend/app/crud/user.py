"""
CRUD operations for the User entity.
"""

import secrets
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate
from app.core.security import get_password_hash


def get_user(db: Session, user_id: int) -> Optional[User]:
    """
    Retrieve a single user by ID.
    """
    return db.execute(select(User).where(User.id == user_id)).scalar_one_or_none()


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """
    Retrieve a single user by email address.
    """
    return db.execute(select(User).where(User.email == email)).scalar_one_or_none()


def get_users(db: Session, skip: int = 0, limit: int = 100) -> List[User]:
    """
    Retrieve a list of users with pagination.
    """
    return list(db.scalars(select(User).offset(skip).limit(limit)).all())


def create_user(db: Session, user_in: UserCreate) -> User:
    """
    Create a new user with password hashing.
    """
    db_user = User(
        email=user_in.email,
        full_name=user_in.full_name,
        role=user_in.role,
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
