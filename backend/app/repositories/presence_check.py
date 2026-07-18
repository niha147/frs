from typing import List, Optional, Tuple
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func
from app.models.presence_check import PresenceCheck

class PresenceCheckRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(
        self,
        class_id: int,
        student_id: uuid.UUID,
        is_present: bool,
        confidence_score: Optional[float] = None
    ) -> PresenceCheck:
        """Saves a single student surprise check record."""
        db_check = PresenceCheck(
            class_id=class_id,
            student_id=student_id,
            is_present=is_present,
            confidence_score=confidence_score
        )
        self.db.add(db_check)
        await self.db.flush()
        return db_check

    async def list_by_class(self, class_id: int) -> List[PresenceCheck]:
        """Fetch all verification checks for a class session."""
        query = select(PresenceCheck).where(PresenceCheck.class_id == class_id).order_by(PresenceCheck.checked_at.desc())
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def get_student_presence_stats(self, class_id: int, student_id: uuid.UUID) -> Tuple[int, int]:
        """
        Returns (total_scans_run, scans_detected_present) for a student in a class.
        Used to compute presence percentage.
        """
        # Count total scans run for this class
        total_query = select(func.count(PresenceCheck.id)).where(
            (PresenceCheck.class_id == class_id) & (PresenceCheck.student_id == student_id)
        )
        total_result = await self.db.execute(total_query)
        total = total_result.scalar_one_or_none() or 0
        
        # Count scans where student was present
        present_query = select(func.count(PresenceCheck.id)).where(
            (PresenceCheck.class_id == class_id) & 
            (PresenceCheck.student_id == student_id) & 
            (PresenceCheck.is_present == True)
        )
        present_result = await self.db.execute(present_query)
        present = present_result.scalar_one_or_none() or 0
        
        return total, present
