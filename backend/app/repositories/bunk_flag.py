from typing import List, Optional
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.bunk_flag import BunkFlag

class BunkFlagRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(
        self,
        attendance_id: int,
        class_id: int,
        student_id: uuid.UUID,
        reason: str,
        severity: str = "medium"
    ) -> BunkFlag:
        """Create a new bunk flag record."""
        db_flag = BunkFlag(
            attendance_id=attendance_id,
            class_id=class_id,
            student_id=student_id,
            reason=reason,
            severity=severity,
            resolved=False
        )
        self.db.add(db_flag)
        await self.db.flush()
        return db_flag

    async def get_active_flags_for_student(self, student_id: uuid.UUID) -> List[BunkFlag]:
        """Fetch all unresolved bunk flags for a student."""
        query = select(BunkFlag).where(
            (BunkFlag.student_id == student_id) & (BunkFlag.resolved == False)
        )
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def get_by_attendance_id(self, attendance_id: int) -> List[BunkFlag]:
        """Fetch all bunk flags associated with an attendance record."""
        query = select(BunkFlag).where(BunkFlag.attendance_id == attendance_id)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def resolve_flags_for_attendance(self, attendance_id: int) -> None:
        """Resolve all bunk flags associated with a specific attendance record."""
        query = select(BunkFlag).where(
            (BunkFlag.attendance_id == attendance_id) & (BunkFlag.resolved == False)
        )
        result = await self.db.execute(query)
        flags = result.scalars().all()
        for flag in flags:
            flag.resolved = True
            self.db.add(flag)
        await self.db.flush()
