from typing import List, Optional
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.faculty import Faculty
from app.schemas.faculty import FacultyCreate, FacultyUpdate
from app.core.security import get_password_hash

class FacultyRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, faculty_id: uuid.UUID) -> Optional[Faculty]:
        """Fetch faculty member by UUID primary key."""
        query = select(Faculty).where(Faculty.id == faculty_id)
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_by_email(self, email: str) -> Optional[Faculty]:
        """Fetch faculty member by email."""
        query = select(Faculty).where(Faculty.email == email)
        result = await self.db.execute(query)
        return result.scalars().first()

    async def create(self, obj_in: FacultyCreate) -> Faculty:
        """Create a new faculty record, hashing their password."""
        hashed_password = get_password_hash(obj_in.password)
        db_faculty = Faculty(
            id=uuid.uuid4(),
            name=obj_in.name,
            email=obj_in.email,
            phone=obj_in.phone,
            department=obj_in.department,
            password_hash=hashed_password,
            role=obj_in.role,
            is_active=True
        )
        self.db.add(db_faculty)
        await self.db.flush()
        return db_faculty

    async def list_faculty(
        self,
        department: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Faculty]:
        """List active faculty members with optional department filter."""
        query = select(Faculty).where(Faculty.is_active == True)
        if department:
            query = query.where(Faculty.department == department)
            
        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def update(self, db_faculty: Faculty, obj_in: FacultyUpdate) -> Faculty:
        """Update faculty profile. Hashes the password if provided."""
        update_data = obj_in.model_dump(exclude_unset=True)
        if "password" in update_data and update_data["password"]:
            update_data["password_hash"] = get_password_hash(update_data["password"])
            del update_data["password"]
            
        for field, value in update_data.items():
            setattr(db_faculty, field, value)
            
        self.db.add(db_faculty)
        await self.db.flush()
        return db_faculty

    async def soft_delete(self, db_faculty: Faculty) -> Faculty:
        """Soft delete faculty member."""
        db_faculty.is_active = False
        self.db.add(db_faculty)
        await self.db.flush()
        return db_faculty
