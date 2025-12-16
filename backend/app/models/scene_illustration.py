"""
场面绘制功能相关的数据库模型.

本章包含用于章节场面绘制任务和图片管理的数据模型。
"""

from datetime import datetime
from typing import Optional

from sqlalchemy import Column, Integer, String, DateTime, JSON, Text, UniqueConstraint
from sqlalchemy.sql import func

from ..database import Base


class SceneIllustrationTask(Base):
    """场面绘制任务模型.

    用于跟踪每个场面绘制任务的状态、参数和进度。
    """
    __tablename__ = "scene_illustration_tasks"

    # 主键
    id = Column(Integer, primary_key=True, comment="任务ID")

    # 任务信息
    task_id = Column(String(255), unique=True, nullable=False, index=True, comment="任务标识符")
    status = Column(
        String(20),
        nullable=False,
        default="pending",
        comment="任务状态: pending/running/completed/failed"
    )

    # 输入参数
    chapters_content = Column(Text, nullable=False, comment="章节内容")
    roles = Column(JSON, nullable=False, comment="角色信息")
    num = Column(Integer, nullable=False, comment="生成图片数量")
    model_name = Column(String(100), nullable=True, comment="使用的模型名称")
    prompts = Column(Text, nullable=True, comment="Dify生成的提示词")

    # 输出结果
    generated_images = Column(Integer, default=0, comment="已生成的图片数量")
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
        return f"<SceneIllustrationTask(id={self.id}, task_id='{self.task_id}', status='{self.status}')>"


class SceneImageGallery(Base):
    """场面图片图集模型.

    用于存储场面绘制生成的图片信息。
    """
    __tablename__ = "scene_image_gallery"

    id = Column(Integer, primary_key=True, index=True, comment="主键ID")
    task_id = Column(String(255), nullable=False, index=True, comment="场面绘制任务ID")
    img_url = Column(String(500), nullable=False, comment="图片URL（文件名）")
    prompt = Column(Text, nullable=False, comment="生成图片的提示词")

    # 时间戳
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        comment="创建时间"
    )

    # 确保每个任务的图片URL唯一
    __table_args__ = (
        UniqueConstraint('task_id', 'img_url', name='unique_scene_task_img'),
    )

    def __repr__(self) -> str:
        """返回模型的字符串表示."""
        return f"<SceneImageGallery(task_id='{self.task_id}', img_url='{self.img_url}')>"