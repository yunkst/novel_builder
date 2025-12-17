"""update_user_input_field_in_role_card_tasks

Revision ID: e7b3ba19a7f3
Revises: 1cf2c108acc1
Create Date: 2025-12-17 02:51:07.728544

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'e7b3ba19a7f3'
down_revision = '1cf2c108acc1'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 将 user_input 字段设为可选，并设置默认值
    op.alter_column('role_card_tasks', 'user_input',
                    existing_type=sa.Text(),
                    nullable=True,
                    server_default='生成人物卡')


def downgrade() -> None:
    # 恢复 user_input 字段为必填
    op.alter_column('role_card_tasks', 'user_input',
                    existing_type=sa.Text(),
                    nullable=False,
                    server_default=None)