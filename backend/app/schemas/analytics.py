from datetime import datetime, date
from typing import List, Optional
import uuid
from pydantic import BaseModel, Field

class AnalyticsOut(BaseModel):
    id: int
    student_id: uuid.UUID
    subject_id: int
    period_type: str
    period_start: date
    period_end: date
    classes_held: int
    classes_attended: int
    attendance_percentage: float
    risk_score: float
    computed_at: datetime

    class Config:
        from_attributes = True

class DefaulterOut(BaseModel):
    student_id: uuid.UUID
    name: str
    roll_number: str
    department: str
    year: int
    section: str
    attendance_percentage: float
    risk_score: float
    bunk_flags_count: int

class DepartmentStats(BaseModel):
    department: str
    overall_attendance_percentage: float
    total_students: int
    defaulters_count: int

class DailyTrend(BaseModel):
    date_str: str = Field(..., description="Date label (e.g. YYYY-MM-DD)")
    attendance_percentage: float

class MonthlyTrend(BaseModel):
    month_str: str = Field(..., description="Month label (e.g. YYYY-MM)")
    attendance_percentage: float
