"""
Road distress monitoring routes for the Road Distress Management System.
"""

from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.core.pagination import skip_param, limit_param
from app.crud.distress import (
    get_distress,
    get_distresses,
    create_distress,
    update_distress,
    delete_distress
)
from app.schemas.distress import (
    RoadDistressCreate,
    RoadDistressClientCreate,
    RoadDistressUpdate,
    RoadDistressResponse
)

router = APIRouter()


@router.get("/", response_model=List[RoadDistressResponse])
def read_distresses(
    skip: int = skip_param(),
    limit: int = limit_param(),
    db: Session = Depends(get_db)
) -> List[RoadDistressResponse]:
    """
    Retrieve road distress logs from PostgreSQL database with pagination.
    """
    return get_distresses(db, skip=skip, limit=limit)


@router.get("/{id}", response_model=RoadDistressResponse)
def read_distress_by_id(id: int, db: Session = Depends(get_db)) -> RoadDistressResponse:
    """
    Retrieve a single road distress log by ID.
    """
    db_distress = get_distress(db, distress_id=id)
    if not db_distress:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Road distress log with ID {id} not found"
        )
    return db_distress


@router.post("/", response_model=RoadDistressResponse, status_code=status.HTTP_201_CREATED)
def create_new_distress(
    distress_in: RoadDistressClientCreate,
    db: Session = Depends(get_db)
) -> RoadDistressResponse:
    """
    Create a new road distress log in the database. Server-side file references
    (detection_image_path) cannot be supplied by clients.
    """
    return create_distress(db, distress_in=RoadDistressCreate(**distress_in.model_dump()))


@router.put("/{id}", response_model=RoadDistressResponse)
def update_existing_distress(
    id: int,
    distress_in: RoadDistressUpdate,
    db: Session = Depends(get_db)
) -> RoadDistressResponse:
    """
    Update an existing road distress log.
    """
    db_distress = update_distress(db, distress_id=id, distress_in=distress_in)
    if not db_distress:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Road distress log with ID {id} not found"
        )
    return db_distress


@router.delete("/{id}", response_model=RoadDistressResponse)
def delete_existing_distress(id: int, db: Session = Depends(get_db)) -> RoadDistressResponse:
    """
    Delete a road distress log.
    """
    db_distress = delete_distress(db, distress_id=id)
    if not db_distress:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Road distress log with ID {id} not found"
        )
    return db_distress
