import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from app.models.base import Base

class Notification(Base):
    __tablename__ = "notifications"
    
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    recipient_type: Mapped[str] = mapped_column(String(50), nullable=False)  # 'student', 'faculty', 'admin'
    recipient_id: Mapped[uuid.UUID] = mapped_column(nullable=False)
    type: Mapped[str] = mapped_column(String(50), nullable=False)  # 'low_attendance', 'defaulter_warning', 'reminder'
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    message: Mapped[str] = mapped_column(String(500), nullable=False)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
