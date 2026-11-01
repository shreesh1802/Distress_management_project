"""
User routes for the Road Distress Management System.

Access model:
  * GET /users/ and GET /users/{id}  -- any signed-in user, REDUCED view
    (id, full_name, role; e-mail only for admins or the user themself). The
    mobile app uses the list to label maintenance assignees.
  * POST / PUT / DELETE              -- admin only (role and password changes
    are therefore admin only as well).
"""

from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.core.deps import get_current_user, require_admin
from app.core.pagination import skip_param, user_limit_param
from app.core.roles import Role
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate, UserResponse, UserPublic
from app.services.user import UserService

router = APIRouter()


def _public_view(target: User, caller: User) -> UserPublic:
    show_email = caller.role == Role.ADMIN or caller.id == target.id
    return UserPublic(
        id=target.id,
        full_name=target.full_name,
        role=target.role,
        email=target.email if show_email else None,
    )


@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_new_user(
    user_in: UserCreate,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
) -> UserResponse:
    """
    Create a new user (admin only).
    """
    return UserService.create(db, user_in=user_in)


@router.get("/", response_model=List[UserPublic])
def read_users(
    skip: int = skip_param(),
    limit: int = user_limit_param(),
    db: Session = Depends(get_db),
    caller: User = Depends(get_current_user),
) -> List[UserPublic]:
    """
    List users (reduced view; e-mail visible to admins and for your own record).
    """
    return [_public_view(u, caller) for u in UserService.get_all(db, skip=skip, limit=limit)]


@router.get("/{id}", response_model=UserPublic)
def read_user_by_id(
    id: int,
    db: Session = Depends(get_db),
    caller: User = Depends(get_current_user),
) -> UserPublic:
    """
    Retrieve a user by ID (reduced view).
    """
    return _public_view(UserService.get_by_id(db, user_id=id), caller)


@router.put("/{id}", response_model=UserResponse)
def update_user_by_id(
    id: int,
    user_in: UserUpdate,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
) -> UserResponse:
    """
    Update user information, role or password (admin only).
    """
    return UserService.update(db, user_id=id, user_in=user_in)


@router.delete("/{id}", response_model=UserResponse)
def delete_user_by_id(
    id: int,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
) -> UserResponse:
    """
    Delete a user by ID (admin only).
    """
    return UserService.delete(db, user_id=id)
