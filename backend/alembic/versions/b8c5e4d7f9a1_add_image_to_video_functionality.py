"""add_image_to_video_functionality

Revision ID: b8c5e4d7f9a1
Revises: aba3a21b25b4
Create Date: 2025-12-16 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'b8c5e4d7f9a1'
down_revision = 'aba3a21b25b4'
branch_labels = None
depends_on = None


def upgrade():
    # 扩展 role_image_gallery 表
    op.add_column('role_image_gallery', sa.Column('video_status', sa.String(length=20), nullable=False, server_default='none', comment='视频生成状态: none/pending/running/completed/failed'))
    op.add_column('role_image_gallery', sa.Column('video_filename', sa.String(length=500), nullable=True, comment='生成的视频文件名'))
    op.add_column('role_image_gallery', sa.Column('video_prompt', sa.Text(), nullable=True, comment='视频生成提示词'))
    op.add_column('role_image_gallery', sa.Column('video_created_at', sa.DateTime(timezone=True), nullable=True, comment='视频创建时间'))

    # 创建 image_to_video_task 表
    op.create_table('image_to_video_task',
        sa.Column('id', sa.Integer(), nullable=False, comment='任务ID'),
        sa.Column('img_name', sa.String(length=255), nullable=False, comment='图片名称'),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='pending', comment='任务状态: pending/running/completed/failed'),
        sa.Column('model_name', sa.String(length=100), nullable=True, comment='图生视频模型名称'),
        sa.Column('user_input', sa.Text(), nullable=False, comment='用户要求'),
        sa.Column('video_prompt', sa.Text(), nullable=True, comment='处理后的视频生成提示词'),
        sa.Column('video_filename', sa.String(length=500), nullable=True, comment='生成的视频文件名'),
        sa.Column('result_message', sa.Text(), nullable=True, comment='处理结果消息'),
        sa.Column('error_message', sa.Text(), nullable=True, comment='错误信息'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False, comment='创建时间'),
        sa.Column('started_at', sa.DateTime(timezone=True), nullable=True, comment='开始处理时间'),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True, comment='完成时间'),
        sa.PrimaryKeyConstraint('id'),
        comment='图片转视频生成任务表'
    )

    # 创建索引
    op.create_index(op.f('ix_image_to_video_task_id'), 'image_to_video_task', ['id'], unique=False)
    op.create_index(op.f('ix_image_to_video_task_img_name'), 'image_to_video_task', ['img_name'], unique=False)


def downgrade():
    # 删除索引
    op.drop_index(op.f('ix_image_to_video_task_img_name'), table_name='image_to_video_task')
    op.drop_index(op.f('ix_image_to_video_task_id'), table_name='image_to_video_task')

    # 删除 image_to_video_task 表
    op.drop_table('image_to_video_task')

    # 从 role_image_gallery 表中删除视频相关字段
    op.drop_column('role_image_gallery', 'video_created_at')
    op.drop_column('role_image_gallery', 'video_prompt')
    op.drop_column('role_image_gallery', 'video_filename')
    op.drop_column('role_image_gallery', 'video_status')