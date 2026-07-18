from datetime import datetime
import uuid
from pydantic import BaseModel, Field

class FaceOut(BaseModel):
    id: int = Field(..., description="Unique database ID of the face record")
    student_id: uuid.UUID = Field(..., description="ID of the associated student")
    image_path: str = Field(..., description="Path/URL to the stored face image")
    is_primary: bool = Field(..., description="True if this is the primary identification face")
    created_at: datetime = Field(..., description="Timestamp of upload")

    class Config:
        from_attributes = True
