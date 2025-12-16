"""
图片生成功能相关的数据库模型.

本章包含用于角色卡图片生成和管理的数据库模型。
"""

from datetime import datetime
from typing import Optional

from sqlalchemy import Column, Integer, String, DateTime, JSON, Text, UniqueConstraint
from sqlalchemy.sql import func

from ..database import Base


class RoleImageGallery(Base):
    """角色图片图集模型.

    用于存储人物卡生成的图片信息，每个图片都有对应的生成提示词。
    """
    __tablename__ = "role_image_gallery"

    id = Column(Integer, primary_key=True, index=True, comment="主键ID")
    role_id = Column(String(255), nullable=False, index=True, comment="人物卡ID")
    img_url = Column(String(500), nullable=False, comment="图片URL（文件名）")
    prompt = Column(Text, nullable=False, comment="生成图片的提示词")

    # 时间戳
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        comment="创建时间"
    )

    # 确保每个角色的图片URL唯一
    __table_args__ = (
        UniqueConstraint('role_id', 'img_url', name='unique_role_img'),
    )

    def __repr__(self) -> str:
        """返回模型的字符串表示."""
        return f"<RoleImageGallery(role_id='{self.role_id}', img_url='{self.img_url}')>"


class RoleCardTask(Base):
    """人物卡图片生成任务模型."""

    __tablename__ = "role_card_tasks"

    # 主键
    id = Column(Integer, primary_key=True, comment="任务ID")

    # 任务信息
    role_id = Column(String(100), nullable=False, comment="人物卡ID")
    status = Column(
        String(20),
        nullable=False,
        default="pending",
        comment="任务状态: pending/running/completed/failed"
    )

    # 输入参数
    roles = Column(JSON, nullable=False, comment="人物卡设定信息")
    user_input = Column(Text, nullable=False, comment="用户要求")
    model = Column(String(100), nullable=True, comment="使用的模型名称")

    # 输出结果
    total_prompts = Column(Integer, default=0, comment="生成的提示词数量")
    generated_images = Column(Integer, default=0, comment="成功生成的图片数量")
    result_message = Column(Text, comment="处理结果消息")
    error_message = Column(Text, comment="错误信息")

    # 时间戳
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        comment="创建时间"
    )
    started_at = Column(DateTime(timezone=True), comment="开始处理时间")
    completed_at = Column(DateTime(timezone=True), comment="完成时间")

    def __repr__(self) -> str:
        """返回模型的字符串表示."""
        return f"<RoleCardTask(id={self.id}, role_id='{self.role_id}', status='{self.status}')>"