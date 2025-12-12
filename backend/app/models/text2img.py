"""
文生图功能相关的数据库模型.

本章包含用于跟踪章节配图任务状态和结果的数据库模型。
"""

from datetime import datetime
from typing import Optional

from sqlalchemy import Column, Integer, String, DateTime, JSON, Text, UniqueConstraint
from sqlalchemy.sql import func

from ..database import Base


class ChapterIllustration(Base):
    """章节配图任务模型.

    用于跟踪每个章节的文生图任务状态，包括生成进度和结果。
    """
    __tablename__ = "chapter_illustrations"

    id = Column(Integer, primary_key=True, index=True, comment="主键ID")
    chapter_id = Column(String(255), unique=True, nullable=False, index=True, comment="章节ID")
    status = Column(String(50), nullable=False, default="pending", comment="任务状态")

    # 任务计数
    total_images = Column(Integer, default=0, comment="需要生成的图片总数")
    completed_images = Column(Integer, default=0, comment="已完成的图片数量")

    # 输入数据
    novel_content = Column(Text, comment="小说内容")
    roles = Column(JSON, comment="角色信息")
    require = Column(Text, comment="配图要求")

    # 结果数据
    image_data = Column(JSON, comment="图片生成结果数据")
    error_message = Column(Text, comment="错误信息")

    # 时间戳
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        comment="创建时间"
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        comment="更新时间"
    )
    completed_at = Column(DateTime(timezone=True), comment="完成时间")

    def __repr__(self) -> str:
        """返回模型的字符串表示."""
        return f"<ChapterIllustration(chapter_id='{self.chapter_id}', status='{self.status}')>"

    @property
    def is_completed(self) -> bool:
        """检查任务是否完成."""
        return self.status == "completed"

    @property
    def is_failed(self) -> bool:
        """检查任务是否失败."""
        return self.status == "failed"

    @property
    def is_processing(self) -> bool:
        """检查任务是否正在处理."""
        return self.status in ["processing", "generating"]

    @property
    def progress_percentage(self) -> float:
        """计算完成进度百分比."""
        if self.total_images == 0:
            return 0.0
        return (self.completed_images / self.total_images) * 100.0


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