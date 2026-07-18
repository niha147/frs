import uuid
from datetime import datetime
from sqlalchemy import String, ForeignKey, DateTime, Float, Boolean, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.models.base import Base

class Attendance(Base):
    __tablename__ = "attendance"
    
    __table_args__ = (
        Index("idx_attendance_student_status", "student_id", "status"),
    )
    
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id", ondelete="CASCADE"), nullable=False)
    status: Mapped[str] = mapped_column(String(50), default="absent", nullable=False)  # 'present', 'absent', 'late'
    marked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    marked_by: Mapped[uuid.UUID] = mapped_column(ForeignKey("faculty.id", ondelete="SET NULL"), nullable=True)
    confidence_score: Mapped[float] = mapped_column(Float, nullable=True)
    method: Mapped[str] = mapped_column(String(50), default="manual", nullable=False)  # 'face_scan', 'manual'
    is_flagged: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    flag_reason: Mapped[str] = mapped_column(String(500), nullable=True)
    
    student = relationship("Student", foreign_keys=[student_id])
    class_session = relationship("ClassSession", foreign_keys=[class_id])
    marked_by_faculty = relationship("Faculty", foreign_keys=[marked_by])
