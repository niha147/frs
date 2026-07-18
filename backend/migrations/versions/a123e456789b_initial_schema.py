"""initial schema

Revision ID: a123e456789b
Revises: 
Create Date: 2026-07-17 11:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from pgvector.sqlalchemy import Vector

# revision identifiers, used by Alembic.
revision: str = 'a123e456789b'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Enable pgvector
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    # 2. Create faculty table
    op.create_table(
        'faculty',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=False),
        sa.Column('phone', sa.String(length=50), nullable=True),
        sa.Column('department', sa.String(length=100), nullable=False),
        sa.Column('password_hash', sa.String(length=255), nullable=False),
        sa.Column('role', sa.String(length=50), nullable=False, server_default='faculty'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_faculty_email'), 'faculty', ['email'], unique=True)
    op.create_index(op.f('ix_faculty_id'), 'faculty', ['id'], unique=False)

    # 3. Create students table
    op.create_table(
        'students',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('roll_number', sa.String(length=100), nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('department', sa.String(length=100), nullable=False),
        sa.Column('year', sa.Integer(), nullable=False),
        sa.Column('section', sa.String(length=50), nullable=False),
        sa.Column('phone_number', sa.String(length=50), nullable=True),
        sa.Column('email', sa.String(length=255), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_students_email'), 'students', ['email'], unique=True)
    op.create_index(op.f('ix_students_id'), 'students', ['id'], unique=False)
    op.create_index(op.f('ix_students_roll_number'), 'students', ['roll_number'], unique=True)

    # 4. Create subjects table
    op.create_table(
        'subjects',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('code', sa.String(length=100), nullable=False),
        sa.Column('department', sa.String(length=100), nullable=False),
        sa.Column('year', sa.Integer(), nullable=False),
        sa.Column('section', sa.String(length=50), nullable=False),
        sa.Column('credits', sa.Integer(), nullable=False, server_default='3'),
        sa.Column('faculty_id', sa.UUID(), nullable=True),
        sa.ForeignKeyConstraint(['faculty_id'], ['faculty.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_subjects_code'), 'subjects', ['code'], unique=True)

    # 5. Create classes table
    op.create_table(
        'classes',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('subject_id', sa.Integer(), nullable=False),
        sa.Column('faculty_id', sa.UUID(), nullable=True),
        sa.Column('department', sa.String(length=100), nullable=False),
        sa.Column('year', sa.Integer(), nullable=False),
        sa.Column('section', sa.String(length=50), nullable=False),
        sa.Column('scheduled_start', sa.DateTime(timezone=True), nullable=False),
        sa.Column('scheduled_end', sa.DateTime(timezone=True), nullable=False),
        sa.Column('classroom', sa.String(length=100), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['faculty_id'], ['faculty.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['subject_id'], ['subjects.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    # 6. Create attendance table
    op.create_table(
        'attendance',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('student_id', sa.UUID(), nullable=False),
        sa.Column('class_id', sa.Integer(), nullable=False),
        sa.Column('status', sa.String(length=50), nullable=False, server_default='absent'),
        sa.Column('marked_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('marked_by', sa.UUID(), nullable=True),
        sa.Column('confidence_score', sa.Float(), nullable=True),
        sa.Column('method', sa.String(length=50), nullable=False, server_default='manual'),
        sa.Column('is_flagged', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('flag_reason', sa.String(length=500), nullable=True),
        sa.ForeignKeyConstraint(['class_id'], ['classes.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['marked_by'], ['faculty.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['student_id'], ['students.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_attendance_class_id'), 'attendance', ['class_id'], unique=False)
    op.create_index(op.f('ix_attendance_student_id'), 'attendance', ['student_id'], unique=False)

    # 7. Create face_embeddings table
    op.create_table(
        'face_embeddings',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('student_id', sa.UUID(), nullable=False),
        sa.Column('embedding', Vector(512), nullable=False),
        sa.Column('image_path', sa.String(length=500), nullable=False),
        sa.Column('is_primary', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['student_id'], ['students.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_face_embeddings_student_id'), 'face_embeddings', ['student_id'], unique=False)

    # 8. Create presence_checks table
    op.create_table(
        'presence_checks',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('class_id', sa.Integer(), nullable=False),
        sa.Column('student_id', sa.UUID(), nullable=False),
        sa.Column('checked_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('is_present', sa.Boolean(), nullable=False),
        sa.Column('confidence_score', sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(['class_id'], ['classes.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['student_id'], ['students.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    # 9. Create notifications table
    op.create_table(
        'notifications',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('recipient_type', sa.String(length=50), nullable=False),
        sa.Column('recipient_id', sa.UUID(), nullable=False),
        sa.Column('type', sa.String(length=50), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('message', sa.String(length=500), nullable=False),
        sa.Column('is_read', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )

    # 10. Create attendance_analytics table
    op.create_table(
        'attendance_analytics',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('student_id', sa.UUID(), nullable=False),
        sa.Column('subject_id', sa.Integer(), nullable=False),
        sa.Column('period_type', sa.String(length=50), nullable=False),
        sa.Column('period_start', sa.Date(), nullable=False),
        sa.Column('period_end', sa.Date(), nullable=False),
        sa.Column('classes_held', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('classes_attended', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('attendance_percentage', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('risk_score', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('computed_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['student_id'], ['students.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['subject_id'], ['subjects.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    # 11. Create bunk_flags table
    op.create_table(
        'bunk_flags',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('attendance_id', sa.Integer(), nullable=False),
        sa.Column('class_id', sa.Integer(), nullable=False),
        sa.Column('student_id', sa.UUID(), nullable=False),
        sa.Column('detected_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('reason', sa.String(length=500), nullable=False),
        sa.Column('severity', sa.String(length=50), nullable=False, server_default='medium'),
        sa.Column('resolved', sa.Boolean(), nullable=False, server_default='false'),
        sa.ForeignKeyConstraint(['attendance_id'], ['attendance.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['class_id'], ['classes.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['student_id'], ['students.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )


def downgrade() -> None:
    op.drop_table('bunk_flags')
    op.drop_table('attendance_analytics')
    op.drop_table('notifications')
    op.drop_table('presence_checks')
    op.drop_index(op.f('ix_face_embeddings_student_id'), table_name='face_embeddings')
    op.drop_table('face_embeddings')
    op.drop_index(op.f('ix_attendance_class_id'), table_name='attendance')
    op.drop_index(op.f('ix_attendance_student_id'), table_name='attendance')
    op.drop_table('attendance')
    op.drop_table('classes')
    op.drop_index(op.f('ix_subjects_code'), table_name='subjects')
    op.drop_table('subjects')
    op.drop_index(op.f('ix_students_roll_number'), table_name='students')
    op.drop_index(op.f('ix_students_id'), table_name='students')
    op.drop_index(op.f('ix_students_email'), table_name='students')
    op.drop_table('students')
    op.drop_index(op.f('ix_faculty_id'), table_name='faculty')
    op.drop_index(op.f('ix_faculty_email'), table_name='faculty')
    op.drop_table('faculty')
    op.execute("DROP EXTENSION IF EXISTS vector")
