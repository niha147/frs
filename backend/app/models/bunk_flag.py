import uuid
from datetime import datetime
from sqlalchemy import String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.models.base import Base

class BunkFlag(Base):
    __tablename__ = "bunk_flags"
    
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    attendance_id: Mapped[int] = mapped_column(ForeignKey("attendance.id", ondelete="CASCADE"), nullable=False)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    detected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    reason: Mapped[str] = mapped_column(String(500), nullable=False)
    severity: Mapped[str] = mapped_column(String(50), default="medium", nullable=False)  # 'low', 'medium', 'high'
    resolved: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    
    attendance = relationship("Attendance", foreign_keys=[attendance_id])
    class_session = relationship("ClassSession", foreign_keys=[class_id])
    student = relationship("Student", foreign_keys=[student_id])
