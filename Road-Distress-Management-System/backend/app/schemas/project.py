"""Pydantic schemas for the Project entity."""

from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field, field_validator


class ProjectBase(BaseModel):
    name: str = Field(..., max_length=255)
    description: Optional[str] = Field(None, max_length=2000)
    highway_name: Optional[str] = Field(None, max_length=255)
    highway_number: Optional[str] = Field(None, max_length=50)
    starting_chainage: Optional[str] = Field(None, max_length=50)
    ending_chainage: Optional[str] = Field(None, max_length=50)
    state: Optional[str] = Field(None, max_length=100)


class ProjectCreate(ProjectBase):
    member_emails: List[str] = Field(
        default_factory=list,
        max_length=100,
        description="Employees to assign to this project (max 100 addresses)",
    )

    @field_validator("member_emails")
    @classmethod
    def _limit_email_length(cls, v: List[str]) -> List[str]:
        if any(len(e) > 255 for e in v):
            raise ValueError("each member e-mail must be at most 255 characters")
        return v


class ProjectResponse(ProjectBase):
    id: int
    owner_id: int
    created_at: datetime
    updated_at: datetime
    member_emails: List[str] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)
