"""add student password and bulk manual attendance

Revision ID: b234f567890c
Revises: a123e456789b
Create Date: 2026-07-18 09:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = 'b234f567890c'
down_revision: Union[str, None] = 'a123e456789b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add password_hash column to students table for student login portal
    op.add_column(
        'students',
        sa.Column('password_hash', sa.String(length=255), nullable=True)
    )


def downgrade() -> None:
    op.drop_column('students', 'password_hash')
