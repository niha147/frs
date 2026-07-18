import uuid
from sqlalchemy import String, Integer, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base

class Subject(Base):
    __tablename__ = "subjects"
    
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    code: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    department: Mapped[str] = mapped_column(String(100), nullable=False)
    year: Mapped[int] = mapped_column(Integer, nullable=False)
    section: Mapped[str] = mapped_column(String(50), nullable=False)
    credits: Mapped[int] = mapped_column(Integer, nullable=False, default=3)
    faculty_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("faculty.id", ondelete="SET NULL"), nullable=True)
    
    faculty = relationship("Faculty", foreign_keys=[faculty_id])
