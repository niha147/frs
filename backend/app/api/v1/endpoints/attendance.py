from typing import List
import uuid
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import BaseModel

from app.api import deps
from app.models.faculty import Faculty
from app.models.student import Student
from app.schemas.attendance import (
    AttendanceOut,
    AttendanceManualInput,
    AttendanceScanResponse,
)
from app.services.attendance import AttendanceService
from app.ai.image_utils import decode_image
from app.api.v1.endpoints.student_auth import get_current_student

router = APIRouter()

class BulkStudentStatus(BaseModel):
    student_id: uuid.UUID
    status: str  # 'present', 'absent', 'late'

class BulkAttendanceInput(BaseModel):
    class_id: int
    entries: List[BulkStudentStatus]
    reason: str | None = None

@router.post("/scan", response_model=AttendanceScanResponse)
async def classroom_bulk_scan(
    class_id: int = Form(..., description="ID of the class session"),
    file: UploadFile = File(..., description="Classroom photograph containing multiple students"),
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> AttendanceScanResponse:
    """
    Triggers initial classroom multi-student face scan.
    Identifies present students and records initial attendance.
    """
    service = AttendanceService(db)
    
    # Read file and decode OpenCV BGR matrix
    image_bytes = await file.read()
    try:
        image_matrix = decode_image(image_bytes)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid image file: {str(e)}"
        )
        
    return await service.process_bulk_scan(
        class_id=class_id,
        image_bytes=image_bytes,
        image_matrix=image_matrix,
        faculty_id=current_user.id
    )

@router.post("/verify-scan")
async def classroom_verification_scan(
    class_id: int = Form(..., description="ID of the class session"),
    file: UploadFile = File(..., description="Surprise classroom verification photo"),
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> dict:
    """
    Triggers a periodic surprise verification scan during class.
    Performs landmark alignment and checks for present/absent discrepancies.
    Automatically logs bunk flags and issues notifications on bunking.
    """
    service = AttendanceService(db)
    
    # Read file and decode OpenCV BGR matrix
    image_bytes = await file.read()
    try:
        image_matrix = decode_image(image_bytes)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid image file: {str(e)}"
        )
        
    await service.process_verification_scan(
        class_id=class_id,
        image_bytes=image_bytes,
        image_matrix=image_matrix,
        faculty_id=current_user.id
    )
    
    return {"status": "ok", "message": "Verification scan processed and bunk checks executed."}

@router.post("/manual", response_model=AttendanceOut)
async def manual_override(
    input_data: AttendanceManualInput,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> AttendanceOut:
    """
    Teacher/Admin manual attendance correction.
    Allows manual override of status and clears/resolves existing bunk flags.
    """
    service = AttendanceService(db)
    return await service.manual_override(input_data, current_user.id)

@router.get("/class/{class_id}", response_model=List[AttendanceOut])
async def list_class_attendance(
    class_id: int,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> List[AttendanceOut]:
    """Retrieve all attendance markings for a specific class session."""
    service = AttendanceService(db)
    return await service.attendance_repo.list_class_attendance(class_id)

@router.get("/student/{student_id}", response_model=List[AttendanceOut])
async def list_student_attendance(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> List[AttendanceOut]:
    """Retrieve full attendance history of a student."""
    service = AttendanceService(db)
    return await service.attendance_repo.list_student_attendance(student_id)

@router.post("/self-scan", response_model=AttendanceOut)
async def student_self_scan(
    class_id: int = Form(..., description="ID of the class session"),
    latitude: float = Form(..., description="Student current latitude"),
    longitude: float = Form(..., description="Student current longitude"),
    device_id: str = Form(..., description="Student device ID"),
    file: UploadFile = File(..., description="Selfie for face matching"),
    db: AsyncSession = Depends(deps.get_db),
    current_student: Student = Depends(get_current_student)
) -> AttendanceOut:
    """
    Allows a student to record their own attendance using face scanning,
    performing automatic geofence checks and device binding validation.
    """
    service = AttendanceService(db)
    image_bytes = await file.read()
    try:
        image_matrix = decode_image(image_bytes)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid image file: {str(e)}"
        )
    return await service.process_self_scan(
        student_id=current_student.id,
        class_id=class_id,
        latitude=latitude,
        longitude=longitude,
        device_id=device_id,
        image_bytes=image_bytes,
        image_matrix=image_matrix
    )
