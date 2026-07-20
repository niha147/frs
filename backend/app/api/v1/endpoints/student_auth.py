"""
Student Portal Auth Endpoints
- POST /student-auth/login  — student login using roll_number + password
- GET  /student-auth/me     — get current student profile
- GET  /student-auth/attendance  — subject-wise attendance summary
- GET  /student-auth/history  — full class-by-class history
"""
import uuid
from datetime import timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func

from app.api import deps
from app.core import security
from app.core.config import settings
from app.core.database import get_db
from app.models.student import Student
from app.models.attendance import Attendance
from app.models.class_session import ClassSession
from app.models.subject import Subject
from app.schemas.auth import Token
from pydantic import BaseModel
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm

router = APIRouter()

# --- Request / Response Schemas ---

class StudentLoginRequest(BaseModel):
    roll_number: str
    password: str
    device_id: Optional[str] = None

class StudentSetPasswordRequest(BaseModel):
    roll_number: str
    new_password: str

class StudentProfileOut(BaseModel):
    id: uuid.UUID
    roll_number: str
    name: str
    department: str
    year: int
    section: str
    email: str | None = None
    phone_number: str | None = None
    device_id: str | None = None
    is_active: bool

    class Config:
        from_attributes = True

class SubjectAttendanceSummary(BaseModel):
    subject_id: int
    subject_name: str
    subject_code: str
    total_classes: int
    attended: int
    percentage: float
    risk_status: str  # SAFE / WARNING / CRITICAL / NO_DATA

class AttendanceHistoryItem(BaseModel):
    class_id: int
    subject_name: str
    subject_code: str
    classroom: str
    scheduled_start: str
    status: str
    method: str

# --- Helpers ---

student_oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_STR}/student-auth/login/access-token",
    scheme_name="StudentOAuth2"
)

async def get_current_student(
    db: AsyncSession = Depends(get_db),
    token: str = Depends(student_oauth2_scheme)
) -> Student:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate student credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    payload = security.decode_token(token)
    if not payload or payload.get("type") != "access":
        raise credentials_exception

    student_id = payload.get("sub")
    if not student_id:
        raise credentials_exception

    try:
        sid = uuid.UUID(student_id)
    except ValueError:
        raise credentials_exception

    result = await db.execute(select(Student).where(Student.id == sid))
    student = result.scalars().first()

    if not student or not student.is_active:
        raise credentials_exception
    return student

# --- Endpoints ---

@router.post("/login", response_model=Token)
async def student_login(
    login_data: StudentLoginRequest,
    db: AsyncSession = Depends(get_db)
) -> Token:
    """Student login using roll number + password."""
    result = await db.execute(
        select(Student).where(Student.roll_number == login_data.roll_number)
    )
    student = result.scalars().first()

    if not student or not student.password_hash:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid roll number or password not set. Contact admin.",
        )
    if not security.verify_password(login_data.password, student.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect password.",
        )
    if not student.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Student account is inactive.",
        )

    # Validate/Bind Device ID
    if login_data.device_id:
        if student.device_id != login_data.device_id:
            # Rebind device ID on student login
            student.device_id = login_data.device_id
            db.add(student)
            await db.commit()

    access_token = security.create_access_token(
        student.id,
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    refresh_token = security.create_refresh_token(
        student.id,
        expires_delta=timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    )
    return Token(access_token=access_token, refresh_token=refresh_token, token_type="bearer")


@router.post("/login/access-token", response_model=Token)
async def student_login_form(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
) -> Token:
    """Student login using roll number + password (form-data for Swagger UI)."""
    result = await db.execute(
        select(Student).where(Student.roll_number == form_data.username)
    )
    student = result.scalars().first()

    if not student or not student.password_hash:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid roll number or password not set. Contact admin.",
        )
    if not security.verify_password(form_data.password, student.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect password.",
        )
    if not student.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Student account is inactive.",
        )

    access_token = security.create_access_token(
        student.id,
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    refresh_token = security.create_refresh_token(
        student.id,
        expires_delta=timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    )
    return Token(access_token=access_token, refresh_token=refresh_token, token_type="bearer")


@router.post("/set-password", status_code=200)
async def set_student_password(
    data: StudentSetPasswordRequest,
    db: AsyncSession = Depends(get_db),
    # Any faculty/admin can set a student's password
    _: deps.Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> dict:
    """Admin/Faculty sets a student's portal password (by roll number)."""
    result = await db.execute(
        select(Student).where(Student.roll_number == data.roll_number)
    )
    student = result.scalars().first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    student.password_hash = security.get_password_hash(data.new_password)
    db.add(student)
    await db.flush()
    return {"status": "ok", "message": f"Password set for {student.name}"}


@router.get("/me", response_model=StudentProfileOut)
async def get_student_me(
    current_student: Student = Depends(get_current_student)
) -> StudentProfileOut:
    """Get the currently logged-in student's profile."""
    return current_student


from sqlalchemy.orm import selectinload

@router.get("/attendance/summary", response_model=List[SubjectAttendanceSummary])
async def get_student_subject_summary(
    current_student: Student = Depends(get_current_student),
    db: AsyncSession = Depends(get_db)
) -> List[SubjectAttendanceSummary]:
    """
    Returns per-subject attendance breakdown for the logged-in student.
    Each subject shows: total classes, attended, percentage, risk status.
    """
    # Get all class sessions that match this student's dept/year/section
    classes_result = await db.execute(
        select(ClassSession).options(selectinload(ClassSession.subject)).where(
            ClassSession.department == current_student.department,
            ClassSession.year == current_student.year,
            ClassSession.section == current_student.section,
        )
    )
    class_sessions = classes_result.scalars().all()

    if not class_sessions:
        return []

    # Get this student's attendance records
    class_ids = [c.id for c in class_sessions]
    att_result = await db.execute(
        select(Attendance).where(
            Attendance.student_id == current_student.id,
            Attendance.class_id.in_(class_ids)
        )
    )
    attendance_records = att_result.scalars().all()
    att_by_class = {a.class_id: a.status for a in attendance_records}

    # Group by subject
    subject_map: dict[int, dict] = {}
    for cls in class_sessions:
        sid = cls.subject_id
        if sid not in subject_map:
            subject_map[sid] = {
                "subject_id": sid,
                "subject_name": cls.subject.name if cls.subject else "Unknown",
                "subject_code": cls.subject.code if cls.subject else "N/A",
                "total": 0,
                "attended": 0,
            }
        subject_map[sid]["total"] += 1
        att_status = att_by_class.get(cls.id, "absent")
        if att_status in ("present", "late"):
            subject_map[sid]["attended"] += 1

    summaries = []
    for sid, data in subject_map.items():
        total = data["total"]
        attended = data["attended"]
        pct = round((attended / total) * 100, 1) if total > 0 else 0.0
        if total == 0:
            risk = "NO_DATA"
        elif pct >= 85:
            risk = "SAFE"
        elif pct >= 75:
            risk = "WARNING"
        else:
            risk = "CRITICAL"

        summaries.append(SubjectAttendanceSummary(
            subject_id=sid,
            subject_name=data["subject_name"],
            subject_code=data["subject_code"],
            total_classes=total,
            attended=attended,
            percentage=pct,
            risk_status=risk,
        ))

    summaries.sort(key=lambda x: x.percentage)
    return summaries


@router.get("/attendance/history", response_model=List[AttendanceHistoryItem])
async def get_student_attendance_history(
    current_student: Student = Depends(get_current_student),
    db: AsyncSession = Depends(get_db)
) -> List[AttendanceHistoryItem]:
    """Full class-by-class attendance history for the logged-in student."""
    # Get all classes for student's dept/year/section
    classes_result = await db.execute(
        select(ClassSession).options(selectinload(ClassSession.subject)).where(
            ClassSession.department == current_student.department,
            ClassSession.year == current_student.year,
            ClassSession.section == current_student.section,
        ).order_by(ClassSession.scheduled_start.desc())
    )
    class_sessions = classes_result.scalars().all()

    if not class_sessions:
        return []

    class_ids = [c.id for c in class_sessions]
    att_result = await db.execute(
        select(Attendance).where(
            Attendance.student_id == current_student.id,
            Attendance.class_id.in_(class_ids)
        )
    )
    att_by_class = {a.class_id: a for a in att_result.scalars().all()}

    history = []
    for cls in class_sessions:
        att = att_by_class.get(cls.id)
        history.append(AttendanceHistoryItem(
            class_id=cls.id,
            subject_name=cls.subject.name if cls.subject else "Unknown",
            subject_code=cls.subject.code if cls.subject else "N/A",
            classroom=cls.classroom,
            scheduled_start=cls.scheduled_start.isoformat(),
            status=att.status if att else "absent",
            method=att.method if att else "not_recorded",
        ))

    return history
