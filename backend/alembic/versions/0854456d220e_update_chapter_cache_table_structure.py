"""update_chapter_cache_table_structure

Revision ID: 0854456d220e
Revises: 001
Create Date: 2025-10-28 02:42:06.228083

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '0854456d220e'
down_revision = '001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add missing columns to novel_chapters_cache table
    op.add_column('novel_chapters_cache', sa.Column('novel_url', sa.String(length=500), nullable=True))
    op.add_column('novel_chapters_cache', sa.Column('word_count', sa.Integer(), nullable=True, default=0))
    op.add_column('novel_chapters_cache', sa.Column('cached_at', sa.DateTime(), nullable=True))
    op.add_column('novel_chapters_cache', sa.Column('retry_count', sa.Integer(), nullable=True, default=0))

    # Add new indexes
    op.create_index('idx_task_chapter', 'novel_chapters_cache', ['task_id', 'chapter_index'])
    op.create_index('idx_novel_url', 'novel_chapters_cache', ['novel_url'])

    # Add new indexes for novel_cache_tasks
    op.create_index('idx_status_created', 'novel_cache_tasks', ['status', 'created_at'])
    op.create_index('idx_novel_url_status', 'novel_cache_tasks', ['novel_url', 'status'])


def downgrade() -> None:
    # Drop indexes
    op.drop_index('idx_novel_url_status', table_name='novel_cache_tasks')
    op.drop_index('idx_status_created', table_name='novel_cache_tasks')
    op.drop_index('idx_novel_url', table_name='novel_chapters_cache')
    op.drop_index('idx_task_chapter', table_name='novel_chapters_cache')

    # Drop columns from novel_chapters_cache table
    op.drop_column('novel_chapters_cache', 'retry_count')
    op.drop_column('novel_chapters_cache', 'cached_at')
    op.drop_column('novel_chapters_cache', 'word_count')
    op.drop_column('novel_chapters_cache', 'novel_url')