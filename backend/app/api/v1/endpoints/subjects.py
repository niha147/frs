from typing import List, Optional
import uuid
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import deps
from app.models.faculty import Faculty
from app.schemas.subject import SubjectCreate, SubjectUpdate, SubjectOut
from app.services.subject import SubjectService

router = APIRouter()

@router.post("/", response_model=SubjectOut, status_code=status.HTTP_201_CREATED)
async def create_subject(
    subject_in: SubjectCreate,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin"]))
) -> SubjectOut:
    """Create a new class subject (Admin Only)."""
    service = SubjectService(db)
    return await service.create_subject(subject_in)

@router.get("/", response_model=List[SubjectOut])
async def list_subjects(
    department: Optional[str] = Query(None, description="Filter by department"),
    faculty_id: Optional[uuid.UUID] = Query(None, description="Filter by assigned faculty member"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> List[SubjectOut]:
    """List and filter subjects (Admin & Faculty)."""
    service = SubjectService(db)
    return await service.list_subjects(
        department=department, faculty_id=faculty_id, skip=skip, limit=limit
    )

@router.put("/{subject_id}", response_model=SubjectOut)
async def update_subject(
    subject_id: int,
    subject_in: SubjectUpdate,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin"]))
) -> SubjectOut:
    """Update subject fields (Admin Only)."""
    service = SubjectService(db)
    return await service.update_subject(subject_id, subject_in)

@router.delete("/{subject_id}", response_model=SubjectOut)
async def delete_subject(
    subject_id: int,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin"]))
) -> SubjectOut:
    """Hard delete subject (Admin Only)."""
    service = SubjectService(db)
    return await service.delete_subject(subject_id)
