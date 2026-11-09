"""
Pydantic schemas for User entity in the Road Distress Management System.
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator

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
    role: str = Field("inspector", max_length=50, description="Role of the user, e.g., inspector, admin, maintenance")


def _normalize_email(value: Optional[str]) -> Optional[str]:
    # Google returns emails lowercased; store them the same way so an admin
    # typing "Priya@Gmail.com" still matches that person's Google sign-in.
    return value.strip().lower() if isinstance(value, str) else value


class UserCreate(UserBase):
    """
    Properties required to create a new user. Login is Google sign-in, so
    the password is optional -- a random one is stored when it's omitted.
    """
    password: Optional[str] = Field(None, min_length=6, description="Plain text password of the user")

    _normalize_email = field_validator("email", mode="before")(_normalize_email)


class UserUpdate(BaseModel):
    """
    Properties for updating an existing user. All fields are optional.
    """
    email: Optional[str] = Field(None, max_length=255, pattern=EMAIL_REGEX)
    full_name: Optional[str] = Field(None, max_length=255)
    role: Optional[str] = Field(None, max_length=50)
    password: Optional[str] = Field(None, min_length=6)

    _normalize_email = field_validator("email", mode="before")(_normalize_email)


class UserResponse(UserBase):
    """
    API response representation of a User.
    """
    id: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
