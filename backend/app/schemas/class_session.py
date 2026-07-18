from datetime import datetime
from typing import Optional
import uuid
from pydantic import BaseModel, Field

class ClassSessionBase(BaseModel):
    subject_id: int = Field(..., description="ID of the subject")
    faculty_id: Optional[uuid.UUID] = Field(None, description="Faculty teaching this session")
    department: str = Field(..., max_length=100, description="Department")
    year: int = Field(..., ge=1, le=5, description="Year")
    section: str = Field(..., max_length=50, description="Section")
    scheduled_start: datetime = Field(..., description="Class start timestamp")
    scheduled_end: datetime = Field(..., description="Class end timestamp")
    classroom: str = Field(..., max_length=100, description="Classroom location (e.g. Room 402)")
    latitude: Optional[float] = Field(None, description="Classroom latitude")
    longitude: Optional[float] = Field(None, description="Classroom longitude")
    radius_meters: Optional[float] = Field(50.0, description="Geofence radius in meters")

class ClassSessionCreate(ClassSessionBase):
    pass

class ClassSessionOut(ClassSessionBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True
