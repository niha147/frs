from typing import List, Optional
import uuid
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.student import StudentRepository
from app.schemas.student import StudentCreate, StudentUpdate
from app.models.student import Student

class StudentService:
    def __init__(self, db: AsyncSession):
        self.repo = StudentRepository(db)

    async def create_student(self, student_in: StudentCreate) -> Student:
        # Check roll number unique
        existing_roll = await self.repo.get_by_roll_number(student_in.roll_number)
        if existing_roll:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Student with roll number {student_in.roll_number} already exists."
            )
            
        # Check email unique
        if student_in.email:
            existing_email = await self.repo.get_by_email(student_in.email)
            if existing_email:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Student with email {student_in.email} already exists."
                )
                
        return await self.repo.create(student_in)

    async def get_student(self, student_id: uuid.UUID) -> Optional[Student]:
        student = await self.repo.get_by_id(student_id)
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student not found."
            )
        return student

    async def list_students(
        self,
        department: Optional[str] = None,
        year: Optional[int] = None,
        section: Optional[str] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Student]:
        return await self.repo.list_students(
            department=department, year=year, section=section, search=search, skip=skip, limit=limit
        )

    async def update_student(self, student_id: uuid.UUID, student_in: StudentUpdate) -> Student:
        student = await self.get_student(student_id)
        
        # Check unique constraint if roll_number is changing
        if student_in.roll_number and student_in.roll_number != student.roll_number:
            existing_roll = await self.repo.get_by_roll_number(student_in.roll_number)
            if existing_roll:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Roll number {student_in.roll_number} is already in use."
                )
                
        # Check unique constraint if email is changing
        if student_in.email and student_in.email != student.email:
            existing_email = await self.repo.get_by_email(student_in.email)
            if existing_email:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Email {student_in.email} is already in use."
                )
                
        return await self.repo.update(student, student_in)

    async def delete_student(self, student_id: uuid.UUID) -> Student:
        student = await self.get_student(student_id)
        return await self.repo.soft_delete(student)
