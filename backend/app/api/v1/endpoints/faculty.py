from typing import List, Optional
import uuid
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import deps
from app.models.faculty import Faculty
from app.schemas.faculty import FacultyCreate, FacultyUpdate, FacultyOut
from app.services.faculty import FacultyService

router = APIRouter()

@router.post("/", response_model=FacultyOut, status_code=status.HTTP_201_CREATED)
async def create_faculty(
    faculty_in: FacultyCreate,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin"]))
) -> FacultyOut:
    """Register a new faculty or admin member (Admin Only)."""
    service = FacultyService(db)
    return await service.create_faculty(faculty_in)

@router.get("/", response_model=List[FacultyOut])
async def list_faculty(
    department: Optional[str] = Query(None, description="Filter by department"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin"]))
) -> List[FacultyOut]:
    """List active faculty profiles (Admin Only)."""
    service = FacultyService(db)
    return await service.list_faculty(department=department, skip=skip, limit=limit)

@router.get("/{faculty_id}", response_model=FacultyOut)
async def get_faculty(
    faculty_id: uuid.UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> FacultyOut:
    """Retrieve details of a faculty member by ID (Admin & Faculty)."""
    service = FacultyService(db)
    # A faculty member can retrieve their own profile, admins can retrieve any profile
    if current_user.role != "admin" and current_user.id != faculty_id:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to view other faculty profiles."
        )
    return await service.get_faculty(faculty_id)

@router.put("/{faculty_id}", response_model=FacultyOut)
async def update_faculty(
    faculty_id: uuid.UUID,
    faculty_in: FacultyUpdate,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin"]))
) -> FacultyOut:
    """Update faculty details (Admin Only)."""
    service = FacultyService(db)
    return await service.update_faculty(faculty_id, faculty_in)

@router.delete("/{faculty_id}", response_model=FacultyOut)
async def delete_faculty(
    faculty_id: uuid.UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin"]))
) -> FacultyOut:
    """Soft delete faculty member (Admin Only)."""
    service = FacultyService(db)
    return await service.delete_faculty(faculty_id)
