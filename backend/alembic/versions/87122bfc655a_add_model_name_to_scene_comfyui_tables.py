"""add_model_name_to_scene_comfyui_tables

Revision ID: 87122bfc655a
Revises: 20241230_video_task_id
Create Date: 2026-01-25 06:23:57.735596

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '87122bfc655a'
down_revision = '20241230_video_task_id'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """添加 model_name 字段到 scene_comfyui_tasks 和 scene_comfyui_images 表"""
    # 为 scene_comfyui_tasks 表添加 model_name 字段
    op.add_column(
        'scene_comfyui_tasks',
        sa.Column('model_name', sa.String(length=100), nullable=True)
    )

    # 为 scene_comfyui_images 表添加 model_name 字段
    op.add_column(
        'scene_comfyui_images',
        sa.Column('model_name', sa.String(length=100), nullable=True)
    )


def downgrade() -> None:
    """回滚：删除 model_name 字段"""
    # 从 scene_comfyui_images 表删除 model_name 字段
    op.drop_column('scene_comfyui_images', 'model_name')

    # 从 scene_comfyui_tasks 表删除 model_name 字段
    op.drop_column('scene_comfyui_tasks', 'model_name')