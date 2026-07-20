from typing import List
import uuid
import random
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import BaseModel

from app.api import deps
from app.models.faculty import Faculty
from app.models.student import Student
from app.models.class_session import ClassSession
from app.schemas.attendance import (
    AttendanceOut,
    AttendanceManualInput,
    AttendanceScanResponse,
)
from app.services.attendance import AttendanceService
from app.ai.image_utils import decode_image
from app.ai.liveness import LivenessService
from app.api.v1.endpoints.student_auth import get_current_student

router = APIRouter()
liveness_service = LivenessService()

# Active challenge sessions cache
# Key: challenge_id (UUID str) -> Dict containing student_id, class_id, challenge_type, expires_at
ACTIVE_CHALLENGES: dict[str, dict] = {}

def cleanup_expired_challenges():
    now = datetime.now()
    expired = [cid for cid, info in ACTIVE_CHALLENGES.items() if info["expires_at"] < now]
    for cid in expired:
        ACTIVE_CHALLENGES.pop(cid, None)

@router.post("/challenge")
async def request_liveness_challenge(
    class_id: int = Form(..., description="ID of the class session"),
    db: AsyncSession = Depends(deps.get_db),
    current_student: Student = Depends(get_current_student)
) -> dict:
    """
    Generates a random real-time liveness challenge for student attendance verification.
    """
    class_session = await db.get(ClassSession, class_id)
    if not class_session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Class session not found."
        )

    challenges = [
        {"type": "blink", "instruction": "Blink both eyes"},
        {"type": "smile", "instruction": "Smile for liveness check"},
        {"type": "turn_left_right", "instruction": "Turn your head left or right"},
        {"type": "look_up_down", "instruction": "Look up or down"}
    ]
    selected = random.choice(challenges)
    challenge_id = str(uuid.uuid4())
    expires_in = 30
    expires_at = datetime.now() + timedelta(seconds=expires_in)

    cleanup_expired_challenges()

    ACTIVE_CHALLENGES[challenge_id] = {
        "student_id": current_student.id,
        "class_id": class_id,
        "challenge_type": selected["type"],
        "expires_at": expires_at
    }

    return {
        "challenge_id": challenge_id,
        "challenge_type": selected["type"],
        "instruction": selected["instruction"],
        "expires_in_seconds": expires_in
    }

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
    challenge_id: str = Form(..., description="Liveness challenge ID fetched from /attendance/challenge"),
    file: UploadFile = File(..., description="Selfie for face matching"),
    blink_simulated: bool = Form(True, description="Simulation flag for eye blink"),
    yaw_simulated: bool = Form(True, description="Simulation flag for head turn"),
    smile_simulated: bool = Form(True, description="Simulation flag for smile"),
    pitch_simulated: bool = Form(True, description="Simulation flag for look up/down"),
    db: AsyncSession = Depends(deps.get_db),
    current_student: Student = Depends(get_current_student)
) -> AttendanceOut:
    """
    Allows a student to record their own attendance using face scanning,
    verifying real-time liveness challenge, geofence, and device binding.
    """
    cleanup_expired_challenges()
    challenge_data = ACTIVE_CHALLENGES.get(challenge_id)
    if not challenge_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Liveness challenge is invalid or expired. Please request a new challenge."
        )

    if challenge_data["student_id"] != current_student.id or challenge_data["class_id"] != class_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Challenge session parameters mismatch."
        )

    image_bytes = await file.read()
    try:
        image_matrix = decode_image(image_bytes)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid image file: {str(e)}"
        )

    # Perform real-time challenge-based liveness verification
    liveness_passed, reason = liveness_service.verify_liveness(
        image_matrix,
        challenge_type=challenge_data["challenge_type"],
        blink_simulated=blink_simulated,
        yaw_simulated=yaw_simulated,
        smile_simulated=smile_simulated,
        pitch_simulated=pitch_simulated
    )
    if not liveness_passed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=reason
        )

    # Invalidate consumed challenge
    ACTIVE_CHALLENGES.pop(challenge_id, None)

    service = AttendanceService(db)
    return await service.process_self_scan(
        student_id=current_student.id,
        class_id=class_id,
        latitude=latitude,
        longitude=longitude,
        device_id=device_id,
        image_bytes=image_bytes,
        image_matrix=image_matrix
    )

