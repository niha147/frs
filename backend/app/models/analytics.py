import uuid
from datetime import datetime, date
from sqlalchemy import ForeignKey, DateTime, Date, Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.models.base import Base

class AttendanceAnalytics(Base):
    __tablename__ = "attendance_analytics"
    
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    subject_id: Mapped[int] = mapped_column(ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False)
    period_type: Mapped[str] = mapped_column(String(50), nullable=False)  # 'daily', 'monthly'
    period_start: Mapped[date] = mapped_column(Date, nullable=False)
    period_end: Mapped[date] = mapped_column(Date, nullable=False)
    classes_held: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    classes_attended: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    attendance_percentage: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    risk_score: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    computed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    
    student = relationship("Student", foreign_keys=[student_id])
    subject = relationship("Subject", foreign_keys=[subject_id])
