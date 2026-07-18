from datetime import datetime
from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.class_session import ClassSessionRepository
from app.schemas.class_session import ClassSessionCreate
from app.models.class_session import ClassSession

class ClassSessionService:
    def __init__(self, db: AsyncSession):
        self.repo = ClassSessionRepository(db)

    async def create_class_session(self, class_in: ClassSessionCreate) -> ClassSession:
        # Validate time sequence
        if class_in.scheduled_start >= class_in.scheduled_end:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Scheduled start time must be before end time."
            )
            
        # Verify Faculty overlapping schedule
        if class_in.faculty_id:
            faculty_busy = await self.repo.check_faculty_overlap(
                class_in.faculty_id, class_in.scheduled_start, class_in.scheduled_end
            )
            if faculty_busy:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Faculty member is already scheduled for another class during this time period."
                )
                
        # Verify Classroom availability
        classroom_occupied = await self.repo.check_classroom_overlap(
            class_in.classroom, class_in.scheduled_start, class_in.scheduled_end
        )
        if classroom_occupied:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Classroom '{class_in.classroom}' is already occupied during this time period."
            )
            
        return await self.repo.create(class_in)

    async def get_class_session(self, class_id: int) -> Optional[ClassSession]:
        class_session = await self.repo.get_by_id(class_id)
        if not class_session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Class session not found."
            )
        return class_session

    async def list_class_sessions(
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
        return await self.repo.list_classes(
            subject_id=subject_id,
            department=department,
            year=year,
            section=section,
            scheduled_after=scheduled_after,
            scheduled_before=scheduled_before,
            skip=skip,
            limit=limit
        )
