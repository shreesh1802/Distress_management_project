"""
Maintenance work orders and scheduling routes for the Road Distress Management System.
"""

from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.core.pagination import skip_param, limit_param
from app.crud.maintenance import (
    get_maintenance_task,
    get_maintenance_tasks,
    create_maintenance_task,
    update_maintenance_task,
    delete_maintenance_task
)
from app.schemas.maintenance import (
    MaintenanceTaskCreate,
    MaintenanceTaskUpdate,
    MaintenanceTaskResponse
)

router = APIRouter()


@router.get("/schedule", response_model=List[MaintenanceTaskResponse])
def get_maintenance_schedule(
    skip: int = skip_param(),
    limit: int = limit_param(),
    db: Session = Depends(get_db)
) -> List[MaintenanceTaskResponse]:
    """
    Retrieve upcoming road maintenance tasks.
    """
    return get_maintenance_tasks(db, skip=skip, limit=limit)


@router.get("/recommendations", response_model=List[MaintenanceTaskResponse])
def get_recommendations(db: Session = Depends(get_db)) -> List[MaintenanceTaskResponse]:
    """
    Run the Recommendation Engine on all unassigned road distresses,
    save the computed recommendations as MaintenanceTasks, and return them.
    """
    from app.services.maintenance_recommendation import generate_recommendations_for_pending_distresses
    return generate_recommendations_for_pending_distresses(db)


@router.get("/summary")
def get_summary(db: Session = Depends(get_db)):
    """
    Retrieve maintenance task summary metrics and KPIs for the dashboard.
    """
    from app.services.maintenance_recommendation import get_maintenance_summary_statistics
    return get_maintenance_summary_statistics(db)


@router.get("/{id}", response_model=MaintenanceTaskResponse)
def get_task_by_id(id: int, db: Session = Depends(get_db)) -> MaintenanceTaskResponse:
    """
    Retrieve a single maintenance task by ID.
    """
    db_task = get_maintenance_task(db, task_id=id)
    if not db_task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Maintenance task with ID {id} not found"
        )
    return db_task


@router.post("/", response_model=MaintenanceTaskResponse, status_code=status.HTTP_201_CREATED)
def create_new_task(
    task_in: MaintenanceTaskCreate,
    db: Session = Depends(get_db)
) -> MaintenanceTaskResponse:
    """
    Create a new maintenance task.
    """
    return create_maintenance_task(db, task_in=task_in)


@router.put("/{id}", response_model=MaintenanceTaskResponse)
def update_existing_task(
    id: int,
    task_in: MaintenanceTaskUpdate,
    db: Session = Depends(get_db)
) -> MaintenanceTaskResponse:
    """
    Update details/status of an existing maintenance task.
    """
    db_task = update_maintenance_task(db, task_id=id, task_in=task_in)
    if not db_task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Maintenance task with ID {id} not found"
        )
    return db_task


@router.delete("/{id}", response_model=MaintenanceTaskResponse)
def delete_existing_task(id: int, db: Session = Depends(get_db)) -> MaintenanceTaskResponse:
    """
    Delete a maintenance task.
    """
    db_task = delete_maintenance_task(db, task_id=id)
    if not db_task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Maintenance task with ID {id} not found"
        )
    return db_task
