from typing import List, Optional
import uuid
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.faculty import FacultyRepository
from app.schemas.faculty import FacultyCreate, FacultyUpdate
from app.models.faculty import Faculty

class FacultyService:
    def __init__(self, db: AsyncSession):
        self.repo = FacultyRepository(db)

    async def create_faculty(self, faculty_in: FacultyCreate) -> Faculty:
        # Check email unique
        existing_email = await self.repo.get_by_email(faculty_in.email)
        if existing_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Faculty with email {faculty_in.email} already exists."
            )
        return await self.repo.create(faculty_in)

    async def get_faculty(self, faculty_id: uuid.UUID) -> Optional[Faculty]:
        faculty = await self.repo.get_by_id(faculty_id)
        if not faculty:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Faculty member not found."
            )
        return faculty

    async def list_faculty(
        self,
        department: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Faculty]:
        return await self.repo.list_faculty(department=department, skip=skip, limit=limit)

    async def update_faculty(self, faculty_id: uuid.UUID, faculty_in: FacultyUpdate) -> Faculty:
        faculty = await self.get_faculty(faculty_id)
        
        # Check email unique constraint if changing
        if faculty_in.email and faculty_in.email != faculty.email:
            existing_email = await self.repo.get_by_email(faculty_in.email)
            if existing_email:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Email {faculty_in.email} is already in use."
                )
        return await self.repo.update(faculty, faculty_in)

    async def delete_faculty(self, faculty_id: uuid.UUID) -> Faculty:
        faculty = await self.get_faculty(faculty_id)
        return await self.repo.soft_delete(faculty)
