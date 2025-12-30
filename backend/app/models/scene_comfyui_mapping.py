"""
ComfyUI 映射关系数据模型.

本模块定义了用于存储 ComfyUI 任务 ID 与业务 task_id 之间映射关系的数据模型,
以及 ComfyUI 任务 ID 到生成图片列表的映射关系。
"""

from sqlalchemy import Boolean, Column, DateTime, Integer, String, UniqueConstraint

from ..database import Base

# 常量定义
MAX_IMAGES_JSON_LENGTH = 5000  # 图片列表JSON字符串的最大长度


class SceneComfyUITask(Base):
    """场面绘制任务到 ComfyUI prompt_id 的映射模型.

    存储业务 task_id 与 ComfyUI 返回的 prompt_id 之间的多对多关系。
    一个业务任务可能对应多个 ComfyUI 任务（生成多张图片）。
    """

    __tablename__ = "scene_comfyui_tasks"

    # 主键
    id = Column(Integer, primary_key=True, comment="主键ID")

    # 映射关系
    task_id = Column(String(255), nullable=False, index=True, comment="业务任务ID")
    comfyui_prompt_id = Column(
        String(255), nullable=False, comment="ComfyUI 返回的 prompt_id"
    )

    # 时间戳
    created_at = Column(
        DateTime(timezone=True), server_default="NOW()", comment="创建时间"
    )

    # 确保同一任务下不会有重复的 ComfyUI prompt_id
    __table_args__ = (
        UniqueConstraint("task_id", "comfyui_prompt_id", name="unique_task_prompt"),
    )

    def __repr__(self) -> str:
        """返回模型的字符串表示."""
        return f"<SceneComfyUITask(id={self.id}, task_id='{self.task_id}', comfyui_prompt_id='{self.comfyui_prompt_id}')>"


class SceneComfyUIImages(Base):
    """ComfyUI prompt_id 到图片列表的映射模型.

    存储 ComfyUI 任务生成的图片列表，支持懒加载：
    - 初次创建时 images 为空列表，status_fetched = False
    - 查询时如果为空，则调用 ComfyUI API 获取并更新
    """

    __tablename__ = "scene_comfyui_images"

    # 主键
    id = Column(Integer, primary_key=True, comment="主键ID")

    # 映射关系
    comfyui_prompt_id = Column(
        String(255),
        unique=True,
        nullable=False,
        index=True,
        comment="ComfyUI 返回的 prompt_id（唯一）",
    )

    # 图片数据
    images = Column(
        String(MAX_IMAGES_JSON_LENGTH),
        nullable=False,
        default="[]",
        comment="生成的图片文件名列表（JSON 数组字符串）",
    )

    # 状态标记
    status_fetched = Column(
        Boolean,
        nullable=False,
        default=False,
        comment="是否已从 ComfyUI API 获取过图片",
    )

    # 时间戳
    fetched_at = Column(DateTime(timezone=True), comment="从 ComfyUI 获取图片的时间")
    created_at = Column(
        DateTime(timezone=True), server_default="NOW()", comment="记录创建时间"
    )

    def __repr__(self) -> str:
        """返回模型的字符串表示."""
        return f"<SceneComfyUIImages(id={self.id}, comfyui_prompt_id='{self.comfyui_prompt_id}', status_fetched={self.status_fetched})>"
