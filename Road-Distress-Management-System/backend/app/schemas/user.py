"""
Pydantic schemas for User entity in the Road Distress Management System.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.roles import RoleName, SELF_REGISTER_ROLE

# Regular expression pattern to validate standard email format
EMAIL_REGEX = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"


class UserBase(BaseModel):
    """
    Shared base schema properties for User.
    """
    email: str = Field(
        ...,
        max_length=255,
        pattern=EMAIL_REGEX,
        description="Unique email address of the user"
    )
    full_name: Optional[str] = Field(None, max_length=255, description="Full name of the user")


class RegisterRequest(UserBase):
    """
    Public self-registration payload. There is deliberately NO role field: any
    ``role`` sent by the client is ignored and the server assigns SELF_REGISTER_ROLE.
    """
    password: str = Field(..., min_length=8, max_length=128, description="Plain text password of the user")


def _normalize_email(value: Optional[str]) -> Optional[str]:
    # Google returns emails lowercased; store them the same way so an admin
    # typing "Priya@Gmail.com" still matches that person's Google sign-in.
    return value.strip().lower() if isinstance(value, str) else value


class UserCreate(UserBase):
    """
    Admin-only creation payload (POST /users/). Login is Google sign-in, so the password is optional -- a random
    one is stored when it is omitted. The role must be one of the known roles.
    """
    role: RoleName = Field(SELF_REGISTER_ROLE, description="Role of the user: admin, inspector, employee or maintenance")
    password: Optional[str] = Field(None, min_length=8, max_length=128, description="Plain text password of the user (optional)")

    _normalize_email = field_validator("email", mode="before")(_normalize_email)


class UserUpdate(BaseModel):
    """
    Properties for updating an existing user (admin-only route). All fields are optional.
    """
    email: Optional[str] = Field(None, max_length=255, pattern=EMAIL_REGEX)
    full_name: Optional[str] = Field(None, max_length=255)
    role: Optional[RoleName] = None
    password: Optional[str] = Field(None, min_length=8, max_length=128)

    _normalize_email = field_validator("email", mode="before")(_normalize_email)


class UserResponse(UserBase):
    """
    API response representation of a User (own profile, admin views).
    """
    role: str
    id: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class UserPublic(BaseModel):
    """
    Reduced user view for the shared user directory (assignee pickers).
    ``email`` is only populated for admins and for the caller's own record.
    """
    id: int
    full_name: Optional[str] = None
    role: str
    email: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)
