from datetime import datetime
from typing import Optional
import uuid
from pydantic import BaseModel, EmailStr, Field

class StudentBase(BaseModel):
    roll_number: str = Field(..., max_length=100, description="Unique registration roll number")
    name: str = Field(..., max_length=255, description="Student full name")
    department: str = Field(..., max_length=100, description="Department name (e.g. CSE, ECE)")
    year: int = Field(..., ge=1, le=5, description="Academic year (1 to 5)")
    section: str = Field(..., max_length=50, description="Classroom section (e.g. A, B)")
    phone_number: Optional[str] = Field(None, max_length=50, description="Phone number")
    email: Optional[EmailStr] = Field(None, description="Optional email address")

class StudentCreate(StudentBase):
    pass

class StudentUpdate(BaseModel):
    roll_number: Optional[str] = Field(None, max_length=100)
    name: Optional[str] = Field(None, max_length=255)
    department: Optional[str] = Field(None, max_length=100)
    year: Optional[int] = Field(None, ge=1, le=5)
    section: Optional[str] = Field(None, max_length=50)
    phone_number: Optional[str] = Field(None, max_length=50)
    email: Optional[EmailStr] = None
    is_active: Optional[bool] = None

class StudentOut(StudentBase):
    id: uuid.UUID
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
