"""add_negative_prompt_to_text2img: text2img_task.negative_prompt 列（nullable，可选）

Revision ID: 20260707_add_negative_prompt
Revises: 20260707_simplify_t2i_i2v
Create Date: 2026-07-07

"""

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = "20260707_add_negative_prompt"
down_revision = "20260707_simplify_t2i_i2v"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """为 text2img_task 增加 nullable 列 negative_prompt。"""
    op.add_column(
        "text2img_task",
        sa.Column(
            "negative_prompt",
            sa.Text(),
            nullable=True,
            comment="用户提供的负向提示词（可选；工作流不支持时静默忽略）",
        ),
    )


def downgrade() -> None:
    """回滚：删除 negative_prompt 列。"""
    op.drop_column("text2img_task", "negative_prompt")
