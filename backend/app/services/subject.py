from typing import List, Optional
import uuid
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.subject import SubjectRepository
from app.schemas.subject import SubjectCreate, SubjectUpdate
from app.models.subject import Subject

class SubjectService:
    def __init__(self, db: AsyncSession):
        self.repo = SubjectRepository(db)

    async def create_subject(self, subject_in: SubjectCreate) -> Subject:
        # Check course code unique
        existing_subject = await self.repo.get_by_code(subject_in.code)
        if existing_subject:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Subject with code {subject_in.code} already exists."
            )
        return await self.repo.create(subject_in)

    async def get_subject(self, subject_id: int) -> Optional[Subject]:
        subject = await self.repo.get_by_id(subject_id)
        if not subject:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subject not found."
            )
        return subject

    async def list_subjects(
        self,
        department: Optional[str] = None,
        faculty_id: Optional[uuid.UUID] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Subject]:
        return await self.repo.list_subjects(
            department=department, faculty_id=faculty_id, skip=skip, limit=limit
        )

    async def update_subject(self, subject_id: int, subject_in: SubjectUpdate) -> Subject:
        subject = await self.get_subject(subject_id)
        
        # Check course code unique constraint if changing
        if subject_in.code and subject_in.code != subject.code:
            existing_subject = await self.repo.get_by_code(subject_in.code)
            if existing_subject:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Subject code {subject_in.code} is already in use."
                )
        return await self.repo.update(subject, subject_in)

    async def delete_subject(self, subject_id: int) -> Subject:
        subject = await self.get_subject(subject_id)
        return await self.repo.delete(subject)
