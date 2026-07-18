from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import deps
from app.models.faculty import Faculty
from app.schemas.class_session import ClassSessionCreate, ClassSessionOut
from app.services.class_session import ClassSessionService

router = APIRouter()

@router.post("/", response_model=ClassSessionOut, status_code=status.HTTP_201_CREATED)
async def create_class_session(
    class_in: ClassSessionCreate,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> ClassSessionOut:
    """Schedule a new class session (Admin & Faculty)."""
    service = ClassSessionService(db)
    
    # If the user is a faculty member, ensure they don't schedule a class for another faculty member
    if current_user.role == "faculty" and class_in.faculty_id != current_user.id:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Faculty members can only schedule class sessions for themselves."
        )
        
    return await service.create_class_session(class_in)

@router.get("/", response_model=List[ClassSessionOut])
async def list_class_sessions(
    subject_id: Optional[int] = Query(None, description="Filter by subject"),
    department: Optional[str] = Query(None, description="Filter by department"),
    year: Optional[int] = Query(None, description="Filter by academic year"),
    section: Optional[str] = Query(None, description="Filter by section"),
    scheduled_after: Optional[datetime] = Query(None, description="ISO datetime start range"),
    scheduled_before: Optional[datetime] = Query(None, description="ISO datetime end range"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> List[ClassSessionOut]:
    """List scheduled class sessions with optional filters and range parameters (Admin & Faculty)."""
    service = ClassSessionService(db)
    return await service.list_class_sessions(
        subject_id=subject_id,
        department=department,
        year=year,
        section=section,
        scheduled_after=scheduled_after,
        scheduled_before=scheduled_before,
        skip=skip,
        limit=limit
    )

@router.get("/{class_id}", response_model=ClassSessionOut)
async def get_class_session(
    class_id: int,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> ClassSessionOut:
    """Retrieve details of a scheduled class session by ID (Admin & Faculty)."""
    service = ClassSessionService(db)
    return await service.get_class_session(class_id)
