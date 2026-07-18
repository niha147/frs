from datetime import datetime
from typing import List, Optional
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import and_, or_
from app.models.class_session import ClassSession
from app.schemas.class_session import ClassSessionCreate

class ClassSessionRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, class_id: int) -> Optional[ClassSession]:
        """Fetch class session by integer ID."""
        query = select(ClassSession).where(ClassSession.id == class_id)
        result = await self.db.execute(query)
        return result.scalars().first()

    async def create(self, obj_in: ClassSessionCreate) -> ClassSession:
        """Create a new class session."""
        db_class = ClassSession(
            subject_id=obj_in.subject_id,
            faculty_id=obj_in.faculty_id,
            department=obj_in.department,
            year=obj_in.year,
            section=obj_in.section,
            scheduled_start=obj_in.scheduled_start,
            scheduled_end=obj_in.scheduled_end,
            classroom=obj_in.classroom,
            latitude=obj_in.latitude,
            longitude=obj_in.longitude,
            radius_meters=obj_in.radius_meters
        )
        self.db.add(db_class)
        await self.db.flush()
        return db_class

    async def list_classes(
        self,
        subject_id: Optional[int] = None,
        department: Optional[str] = None,
        year: Optional[int] = None,
        section: Optional[str] = None,
        scheduled_after: Optional[datetime] = None,
        scheduled_before: Optional[datetime] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[ClassSession]:
        """List scheduled class sessions with optional filters and range queries."""
        query = select(ClassSession)
        
        conditions = []
        if subject_id:
            conditions.append(ClassSession.subject_id == subject_id)
        if department:
            conditions.append(ClassSession.department == department)
        if year:
            conditions.append(ClassSession.year == year)
        if section:
            conditions.append(ClassSession.section == section)
        if scheduled_after:
            conditions.append(ClassSession.scheduled_start >= scheduled_after)
        if scheduled_before:
            conditions.append(ClassSession.scheduled_end <= scheduled_before)
            
        if conditions:
            query = query.where(and_(*conditions))
            
        # Order by scheduled start descending to get latest classes first
        query = query.order_by(ClassSession.scheduled_start.desc()).offset(skip).limit(limit)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def check_faculty_overlap(
        self,
        faculty_id: uuid.UUID,
        start: datetime,
        end: datetime,
        exclude_class_id: Optional[int] = None
    ) -> bool:
        """Checks if a faculty member has a scheduling overlap."""
        query = select(ClassSession).where(
            and_(
                ClassSession.faculty_id == faculty_id,
                or_(
                    and_(ClassSession.scheduled_start <= start, ClassSession.scheduled_end > start),
                    and_(ClassSession.scheduled_start < end, ClassSession.scheduled_end >= end),
                    and_(ClassSession.scheduled_start >= start, ClassSession.scheduled_end <= end)
                )
            )
        )
        if exclude_class_id:
            query = query.where(ClassSession.id != exclude_class_id)
            
        result = await self.db.execute(query)
        return result.scalars().first() is not None

    async def check_classroom_overlap(
        self,
        classroom: str,
        start: datetime,
        end: datetime,
        exclude_class_id: Optional[int] = None
    ) -> bool:
        """Checks if a classroom has a scheduling overlap."""
        query = select(ClassSession).where(
            and_(
                ClassSession.classroom == classroom,
                or_(
                    and_(ClassSession.scheduled_start <= start, ClassSession.scheduled_end > start),
                    and_(ClassSession.scheduled_start < end, ClassSession.scheduled_end >= end),
                    and_(ClassSession.scheduled_start >= start, ClassSession.scheduled_end <= end)
                )
            )
        )
        if exclude_class_id:
            query = query.where(ClassSession.id != exclude_class_id)
            
        result = await self.db.execute(query)
        return result.scalars().first() is not None
