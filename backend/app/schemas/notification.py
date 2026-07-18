from datetime import datetime
import uuid
from pydantic import BaseModel, Field

class NotificationOut(BaseModel):
    id: int
    recipient_type: str = Field(..., description="'student', 'faculty', or 'admin'")
    recipient_id: uuid.UUID = Field(..., description="ID of the recipient")
    type: str = Field(..., description="'low_attendance', 'defaulter_warning', or 'reminder'")
    title: str
    message: str
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True
