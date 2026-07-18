from typing import List, Optional
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import and_
from app.models.subject import Subject
from app.schemas.subject import SubjectCreate, SubjectUpdate

class SubjectRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, subject_id: int) -> Optional[Subject]:
        """Fetch subject by integer ID."""
        query = select(Subject).where(Subject.id == subject_id)
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_by_code(self, code: str) -> Optional[Subject]:
        """Fetch subject by unique course code."""
        query = select(Subject).where(Subject.code == code)
        result = await self.db.execute(query)
        return result.scalars().first()

    async def create(self, obj_in: SubjectCreate) -> Subject:
        """Create a new subject."""
        db_subject = Subject(
            name=obj_in.name,
            code=obj_in.code,
            department=obj_in.department,
            year=obj_in.year,
            section=obj_in.section,
            credits=obj_in.credits,
            faculty_id=obj_in.faculty_id
        )
        self.db.add(db_subject)
        await self.db.flush()
        return db_subject

    async def list_subjects(
        self,
        department: Optional[str] = None,
        faculty_id: Optional[uuid.UUID] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Subject]:
        """List subjects with optional filters."""
        query = select(Subject)
        
        conditions = []
        if department:
            conditions.append(Subject.department == department)
        if faculty_id:
            conditions.append(Subject.faculty_id == faculty_id)
            
        if conditions:
            query = query.where(and_(*conditions))
            
        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def update(self, db_subject: Subject, obj_in: SubjectUpdate) -> Subject:
        """Update subject fields."""
        update_data = obj_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_subject, field, value)
        self.db.add(db_subject)
        await self.db.flush()
        return db_subject

    async def delete(self, db_subject: Subject) -> Subject:
        """Delete subject from database (hard delete)."""
        await self.db.delete(db_subject)
        await self.db.flush()
        return db_subject
