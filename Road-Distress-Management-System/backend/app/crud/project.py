"""CRUD operations for Project, with Admin/Employee visibility scoping."""

from typing import List, Optional
from sqlalchemy import or_, func
from sqlalchemy.orm import Session
from app.core.roles import Role
from app.core.security import normalize_email
from app.models.project import Project, ProjectMember
from app.models.user import User
from app.schemas.project import ProjectCreate


def _member_emails(db: Session, project_id: int) -> List[str]:
    rows = (
        db.query(User.email)
        .join(ProjectMember, ProjectMember.user_id == User.id)
        .filter(ProjectMember.project_id == project_id)
        .all()
    )
    return [r[0] for r in rows]


def get_project(db: Session, project_id: int) -> Optional[Project]:
    return db.get(Project, project_id)


def get_visible_projects(db: Session, user: User) -> List[Project]:
    """Admins see every project; everyone else sees projects they own or are a member of."""
    if user.role == Role.ADMIN:
        return db.query(Project).order_by(Project.id.desc()).all()
    member_project_ids = db.query(ProjectMember.project_id).filter(ProjectMember.user_id == user.id)
    return (
        db.query(Project)
        .filter(or_(Project.owner_id == user.id, Project.id.in_(member_project_ids)))
        .order_by(Project.id.desc())
        .all()
    )


def user_can_access_project(db: Session, user: User, project: Project) -> bool:
    if user.role == Role.ADMIN or project.owner_id == user.id:
        return True
    return (
        db.query(ProjectMember)
        .filter(ProjectMember.project_id == project.id, ProjectMember.user_id == user.id)
        .first()
        is not None
    )


def create_project(db: Session, project_in: ProjectCreate, owner: User) -> Project:
    project = Project(
        name=project_in.name,
        description=project_in.description,
        highway_name=project_in.highway_name,
        highway_number=project_in.highway_number,
        starting_chainage=project_in.starting_chainage,
        ending_chainage=project_in.ending_chainage,
        state=project_in.state,
        owner_id=owner.id,
    )
    db.add(project)
    db.flush()  # get project.id before adding members

    added_user_ids = set()
    for email in project_in.member_emails:
        member_user = db.query(User).filter(func.lower(User.email) == normalize_email(email)).first()
        if member_user is not None and member_user.id not in added_user_ids:
            added_user_ids.add(member_user.id)
            db.add(ProjectMember(project_id=project.id, user_id=member_user.id))

    db.commit()
    db.refresh(project)
    return project


def to_response_dict(db: Session, project: Project) -> dict:
    return {
        "id": project.id,
        "name": project.name,
        "description": project.description,
        "highway_name": project.highway_name,
        "highway_number": project.highway_number,
        "starting_chainage": project.starting_chainage,
        "ending_chainage": project.ending_chainage,
        "state": project.state,
        "owner_id": project.owner_id,
        "created_at": project.created_at,
        "updated_at": project.updated_at,
        "member_emails": _member_emails(db, project.id),
    }
