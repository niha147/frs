from datetime import datetime
from typing import List, Optional
import uuid
from pydantic import BaseModel, Field

class AttendanceOut(BaseModel):
    id: int
    student_id: uuid.UUID
    class_id: int
    status: str
    marked_at: datetime
    marked_by: Optional[uuid.UUID] = None
    confidence_score: Optional[float] = None
    method: str
    is_flagged: bool
    flag_reason: Optional[str] = None

    class Config:
        from_attributes = True

class AttendanceManualInput(BaseModel):
    student_id: uuid.UUID = Field(..., description="ID of the student")
    class_id: int = Field(..., description="ID of the class session")
    status: str = Field(..., description="Attendance status: 'present', 'absent', or 'late'")
    reason: Optional[str] = Field(None, description="Optional reason details for manual override")

class RecognizedStudent(BaseModel):
    student_id: uuid.UUID
    name: str
    roll_number: str
    confidence: float

class AttendanceScanResponse(BaseModel):
    class_id: int
    total_recognized: int
    recognized_students: List[RecognizedStudent]

class BunkFlagOut(BaseModel):
    id: int
    attendance_id: int
    class_id: int
    student_id: uuid.UUID
    detected_at: datetime
    reason: str
    severity: str
    resolved: bool

    class Config:
        from_attributes = True
