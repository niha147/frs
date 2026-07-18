from typing import List, Optional
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.attendance import Attendance

class AttendanceRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, attendance_id: int) -> Optional[Attendance]:
        """Fetch attendance record by primary key."""
        query = select(Attendance).where(Attendance.id == attendance_id)
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_student_attendance_for_class(self, student_id: uuid.UUID, class_id: int) -> Optional[Attendance]:
        """Fetch attendance record for a student in a specific class."""
        query = select(Attendance).where(
            (Attendance.student_id == student_id) & (Attendance.class_id == class_id)
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def list_class_attendance(self, class_id: int) -> List[Attendance]:
        """Fetch all attendance records for a class."""
        query = select(Attendance).where(Attendance.class_id == class_id)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def list_student_attendance(self, student_id: uuid.UUID) -> List[Attendance]:
        """Fetch attendance history of a student."""
        query = select(Attendance).where(Attendance.student_id == student_id).order_by(Attendance.marked_at.desc())
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def save(self, attendance: Attendance) -> Attendance:
        """Saves or updates an attendance record."""
        self.db.add(attendance)
        await self.db.flush()
        return attendance
