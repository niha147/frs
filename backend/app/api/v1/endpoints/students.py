from typing import List, Optional
import uuid
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import deps
from app.models.faculty import Faculty
from app.schemas.student import StudentCreate, StudentUpdate, StudentOut
from app.services.student import StudentService

router = APIRouter()

@router.post("/", response_model=StudentOut, status_code=status.HTTP_201_CREATED)
async def create_student(
    student_in: StudentCreate,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin"]))
) -> StudentOut:
    """Create a new student record (Admin Only)."""
    service = StudentService(db)
    return await service.create_student(student_in)

@router.get("/", response_model=List[StudentOut])
async def list_students(
    department: Optional[str] = Query(None, description="Filter by department"),
    year: Optional[int] = Query(None, description="Filter by academic year"),
    section: Optional[str] = Query(None, description="Filter by section"),
    search: Optional[str] = Query(None, description="Search name or roll number"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> List[StudentOut]:
    """List and filter active students (Admin & Faculty)."""
    service = StudentService(db)
    return await service.list_students(
        department=department, year=year, section=section, search=search, skip=skip, limit=limit
    )

@router.get("/{student_id}", response_model=StudentOut)
async def get_student(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> StudentOut:
    """Retrieve details of a specific student by ID (Admin & Faculty)."""
    service = StudentService(db)
    return await service.get_student(student_id)

@router.put("/{student_id}", response_model=StudentOut)
async def update_student(
    student_id: uuid.UUID,
    student_in: StudentUpdate,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin"]))
) -> StudentOut:
    """Update student record (Admin Only)."""
    service = StudentService(db)
    return await service.update_student(student_id, student_in)

@router.delete("/{student_id}", response_model=StudentOut)
async def delete_student(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin"]))
) -> StudentOut:
    """Soft delete student record (Admin Only)."""
    service = StudentService(db)
    return await service.delete_student(student_id)
