"""Initial migration for cache tables

Revision ID: 001
Revises:
Create Date: 2025-10-23 12:40:00.000000

"""
import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = '001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create novel_cache_tasks table
    op.create_table('novel_cache_tasks',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('novel_url', sa.String(length=500), nullable=False),
        sa.Column('novel_title', sa.String(length=500), nullable=True),
        sa.Column('novel_author', sa.String(length=200), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=True),
        sa.Column('total_chapters', sa.Integer(), nullable=True),
        sa.Column('cached_chapters', sa.Integer(), nullable=True),
        sa.Column('failed_chapters', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.Column('completed_at', sa.DateTime(), nullable=True),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_novel_cache_tasks_id'), 'novel_cache_tasks', ['id'], unique=False)
    op.create_index(op.f('ix_novel_cache_tasks_novel_url'), 'novel_cache_tasks', ['novel_url'], unique=False)
    op.create_index(op.f('ix_novel_cache_tasks_status'), 'novel_cache_tasks', ['status'], unique=False)

    # Create novel_chapters_cache table
    op.create_table('novel_chapters_cache',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('task_id', sa.Integer(), nullable=False),
        sa.Column('chapter_index', sa.Integer(), nullable=False),
        sa.Column('chapter_title', sa.String(length=500), nullable=False),
        sa.Column('chapter_content', sa.Text(), nullable=False),
        sa.Column('chapter_url', sa.String(length=1000), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['task_id'], ['novel_cache_tasks.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_novel_chapters_cache_id'), 'novel_chapters_cache', ['id'], unique=False)
    op.create_index(op.f('ix_novel_chapters_cache_task_id'), 'novel_chapters_cache', ['task_id'], unique=False)
    op.create_index(op.f('ix_novel_chapters_cache_chapter_index'), 'novel_chapters_cache', ['chapter_index'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_novel_chapters_cache_chapter_index'), table_name='novel_chapters_cache')
    op.drop_index(op.f('ix_novel_chapters_cache_task_id'), table_name='novel_chapters_cache')
    op.drop_index(op.f('ix_novel_chapters_cache_id'), table_name='novel_chapters_cache')
    op.drop_table('novel_chapters_cache')
    op.drop_index(op.f('ix_novel_cache_tasks_status'), table_name='novel_cache_tasks')
    op.drop_index(op.f('ix_novel_cache_tasks_novel_url'), table_name='novel_cache_tasks')
    op.drop_index(op.f('ix_novel_cache_tasks_id'), table_name='novel_cache_tasks')
    op.drop_table('novel_cache_tasks')
