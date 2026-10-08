"""create books table

Revision ID: 0001
Revises:
Create Date: 2026-10-08
"""
import sqlalchemy as sa
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "books",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("title", sa.String(120), nullable=False),
        sa.Column("author", sa.String(80), nullable=False),
        sa.Column("course_code", sa.String(12), nullable=False),
        sa.Column("condition", sa.String(10), nullable=False, server_default="good"),
        sa.Column("owner_name", sa.String(60), nullable=False),
        sa.Column("status", sa.String(10), nullable=False, server_default="available"),
        sa.Column("reserved_by", sa.String(60), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_books_course_code", "books", ["course_code"])
    op.create_index("ix_books_status", "books", ["status"])


def downgrade():
    op.drop_index("ix_books_status", table_name="books")
    op.drop_index("ix_books_course_code", table_name="books")
    op.drop_table("books")
