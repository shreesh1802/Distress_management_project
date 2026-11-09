"""
User CRUD routes for the Road Distress Management System.
"""

from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.deps import require_admin
from app.db.session import get_db
from app.models.auth import AuthToken
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate, UserResponse
from app.services.user import UserService

router = APIRouter()


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_new_user(
    user_in: UserCreate,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
) -> UserResponse:
    """
    Create a new user (admin only). Note this does *not* grant login access:
    that's the Firestore allowedUsers list in the Firebase console (see
    app/services/access_service.py), which this table mirrors.
    """
    return UserService.create(db, user_in=user_in)


@router.get("/", response_model=List[UserResponse])
def read_users(
    skip: int = 0, limit: int = 100, db: Session = Depends(get_db)
) -> List[UserResponse]:
    """
    Retrieve all users with pagination.
    """
    return UserService.get_all(db, skip=skip, limit=limit)


@router.get("/{id}", response_model=UserResponse)
def read_user_by_id(id: int, db: Session = Depends(get_db)) -> UserResponse:
    """
    Retrieve a user by ID.
    """
    return UserService.get_by_id(db, user_id=id)


@router.put("/{id}", response_model=UserResponse)
def update_user_by_id(
    id: int,
    user_in: UserUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
) -> UserResponse:
    """
    Update user information (admin only). Admins can't remove their own
    admin role, so the last admin can't lock everyone out by accident.
    """
    if id == admin.id and user_in.role is not None and user_in.role != "admin":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You can't remove your own admin role")
    return UserService.update(db, user_id=id, user_in=user_in)


@router.delete("/{id}", response_model=UserResponse)
def delete_user_by_id(
    id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
) -> UserResponse:
    """
    Delete a user by ID (admin only, and not yourself). This also revokes their access: their
    session tokens are removed first, so they're logged out everywhere (and
    the auth_tokens foreign key doesn't block the delete on Postgres).
    """
    if id == admin.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You can't delete your own account")
    db.query(AuthToken).filter(AuthToken.user_id == id).delete()
    return UserService.delete(db, user_id=id)
