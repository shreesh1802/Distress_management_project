"""CRUD operations for Project, with Admin/Employee visibility scoping."""

from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.project import Project, ProjectMember
from app.models.user import User
from app.schemas.project import ProjectCreate
from app.services.access_service import sync_user


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
    """Admins see every project; employees only see ones they're a member of."""
    if user.role == "admin":
        return db.query(Project).order_by(Project.id.desc()).all()
    return (
        db.query(Project)
        .join(ProjectMember, ProjectMember.project_id == Project.id)
        .filter(ProjectMember.user_id == user.id)
        .order_by(Project.id.desc())
        .all()
    )


def user_can_access_project(db: Session, user: User, project: Project) -> bool:
    if user.role == "admin" or project.owner_id == user.id:
        return True
    return (
        db.query(ProjectMember)
        .filter(ProjectMember.project_id == project.id, ProjectMember.user_id == user.id)
        .first()
        is not None
    )


def _resolve_member(db: Session, email: str) -> Optional[User]:
    """A member email may belong to someone who's on the Firestore allow-list
    but hasn't signed in yet (so has no users row) -- create it from the list."""
    email = email.strip().lower()
    user = db.query(User).filter(User.email == email).first()
    if user is not None:
        return user
    try:
        return sync_user(db, email)
    except Exception:
        return None


def create_project(db: Session, project_in: ProjectCreate, owner: User) -> Project:
    # Resolve members first: sync_user may create users rows (and commit).
    members = [m for m in (_resolve_member(db, e) for e in project_in.member_emails) if m is not None]

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

    for member_user in {m.id: m for m in members}.values():
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
