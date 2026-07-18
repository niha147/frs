from datetime import datetime
from typing import Optional
import uuid
from pydantic import BaseModel, EmailStr, Field

class FacultyBase(BaseModel):
    name: str = Field(..., max_length=255, description="Faculty full name")
    email: EmailStr = Field(..., description="Faculty official email")
    phone: Optional[str] = Field(None, max_length=50, description="Faculty contact number")
    department: str = Field(..., max_length=100, description="Department name")
    role: str = Field("faculty", description="Role (either 'admin' or 'faculty')")

class FacultyCreate(FacultyBase):
    password: str = Field(..., min_length=6, description="Minimum 6 character password")

class FacultyUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=255)
    email: Optional[EmailStr] = None
    phone: Optional[str] = Field(None, max_length=50)
    department: Optional[str] = Field(None, max_length=100)
    role: Optional[str] = None
    password: Optional[str] = Field(None, min_length=6)
    is_active: Optional[bool] = None

class FacultyOut(FacultyBase):
    id: uuid.UUID
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
