import uuid
from datetime import datetime
from sqlalchemy import String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from pgvector.sqlalchemy import Vector
from app.models.base import Base

class FaceEmbedding(Base):
    __tablename__ = "face_embeddings"
    
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    embedding: Mapped[list] = mapped_column(Vector(512), nullable=False)
    image_path: Mapped[str] = mapped_column(String(500), nullable=False)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    
    student = relationship("Student", foreign_keys=[student_id])
