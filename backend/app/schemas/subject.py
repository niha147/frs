from typing import Optional
import uuid
from pydantic import BaseModel, Field

class SubjectBase(BaseModel):
    name: str = Field(..., max_length=255, description="Subject name")
    code: str = Field(..., max_length=100, description="Unique subject code (e.g. CS101)")
    department: str = Field(..., max_length=100, description="Department running the course")
    year: int = Field(..., ge=1, le=5, description="Intended year of study")
    section: str = Field(..., max_length=50, description="Intended section")
    credits: int = Field(3, ge=1, le=6, description="Course credits count")
    faculty_id: Optional[uuid.UUID] = Field(None, description="Assigned Faculty ID")

class SubjectCreate(SubjectBase):
    pass

class SubjectUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=255)
    code: Optional[str] = Field(None, max_length=100)
    department: Optional[str] = Field(None, max_length=100)
    year: Optional[int] = Field(None, ge=1, le=5)
    section: Optional[str] = Field(None, max_length=50)
    credits: Optional[int] = Field(None, ge=1, le=6)
    faculty_id: Optional[uuid.UUID] = None

class SubjectOut(SubjectBase):
    id: int

    class Config:
        from_attributes = True
