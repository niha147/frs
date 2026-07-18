from typing import List, Optional
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_, and_
from app.models.student import Student
from app.schemas.student import StudentCreate, StudentUpdate

class StudentRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, student_id: uuid.UUID) -> Optional[Student]:
        """Fetch student by UUID primary key."""
        query = select(Student).where(Student.id == student_id)
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_by_roll_number(self, roll_number: str) -> Optional[Student]:
        """Fetch student by roll number."""
        query = select(Student).where(Student.roll_number == roll_number)
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_by_email(self, email: str) -> Optional[Student]:
        """Fetch student by email."""
        query = select(Student).where(Student.email == email)
        result = await self.db.execute(query)
        return result.scalars().first()

    async def create(self, obj_in: StudentCreate) -> Student:
        """Create a new student record."""
        db_student = Student(
            id=uuid.uuid4(),
            roll_number=obj_in.roll_number,
            name=obj_in.name,
            department=obj_in.department,
            year=obj_in.year,
            section=obj_in.section,
            phone_number=obj_in.phone_number,
            email=obj_in.email,
            is_active=True
        )
        self.db.add(db_student)
        await self.db.flush()
        return db_student

    async def list_students(
        self,
        department: Optional[str] = None,
        year: Optional[int] = None,
        section: Optional[str] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Student]:
        """List active students with optional filtering, search, and pagination."""
        query = select(Student).where(Student.is_active == True)
        
        conditions = []
        if department:
            conditions.append(Student.department == department)
        if year:
            conditions.append(Student.year == year)
        if section:
            conditions.append(Student.section == section)
            
        if conditions:
            query = query.where(and_(*conditions))
            
        if search:
            search_filter = or_(
                Student.name.ilike(f"%{search}%"),
                Student.roll_number.ilike(f"%{search}%")
            )
            query = query.where(search_filter)
            
        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def update(self, db_student: Student, obj_in: StudentUpdate) -> Student:
        """Update a student record."""
        update_data = obj_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_student, field, value)
        self.db.add(db_student)
        await self.db.flush()
        return db_student

    async def soft_delete(self, db_student: Student) -> Student:
        """Soft delete student by setting is_active = False."""
        db_student.is_active = False
        self.db.add(db_student)
        await self.db.flush()
        return db_student
