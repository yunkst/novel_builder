"""simplify_t2i_i2v: drop role/scene/video_status tables, create text2img_task, recreate image_to_video_task

Revision ID: 20260707_simplify_t2i_i2v
Revises: 87122bfc655a
Create Date: 2026-07-07

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20260707_simplify_t2i_i2v'
down_revision = '87122bfc655a'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Drop old business tables and create simplified t2i/i2v task tables."""
    # Drop old business tables (order matters for foreign key constraints)
    op.drop_table('scene_comfyui_images')
    op.drop_table('scene_comfyui_tasks')
    op.drop_table('scene_image_gallery')
    op.drop_table('scene_illustration_tasks')
    op.drop_table('role_image_gallery')
    op.drop_table('role_card_tasks')
    op.drop_table('image_video_status')

    # Drop old image_to_video_task (schema changed completely)
    op.drop_table('image_to_video_task')

    # Create new text2img_task table
    op.create_table(
        'text2img_task',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('prompt_id', sa.String(length=255), nullable=False),
        sa.Column('prompt', sa.Text(), nullable=False),
        sa.Column('model_name', sa.String(length=100), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='pending'),
        sa.Column('filename', sa.String(length=500), nullable=True),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_text2img_task_prompt_id', 'text2img_task', ['prompt_id'], unique=True)

    # Create new image_to_video_task table
    op.create_table(
        'image_to_video_task',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('prompt_id', sa.String(length=255), nullable=False),
        sa.Column('prompt', sa.Text(), nullable=False),
        sa.Column('model_name', sa.String(length=100), nullable=False),
        sa.Column('image_filename', sa.String(length=255), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='pending'),
        sa.Column('video_filename', sa.String(length=500), nullable=True),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_image_to_video_task_prompt_id', 'image_to_video_task', ['prompt_id'], unique=True)


def downgrade() -> None:
    """Downgrade is not supported for this destructive migration."""
    raise NotImplementedError("This migration drops tables with data. Downgrade is not supported.")
