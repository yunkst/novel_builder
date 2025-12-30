"""
视频状态管理模型
独立管理图片的视频生成状态，与图片来源解耦
"""

from sqlalchemy import Boolean, Column, DateTime, Index, Integer, String, Text
from sqlalchemy.sql import func

from app.database import Base


class ImageVideoStatus(Base):
    """图片视频状态表 - 独立管理所有图片的视频生成状态"""

    __tablename__ = "image_video_status"

    # 主键
    id = Column(Integer, primary_key=True, index=True, comment="主键ID")

    # 业务标识
    img_name = Column(
        String(500), unique=True, nullable=False, index=True, comment="图片文件名"
    )

    # 视频状态管理
    has_video = Column(Boolean, default=False, nullable=False, comment="是否已生成视频")
    video_status = Column(
        String(20),
        default="none",
        nullable=False,
        index=True,
        comment="视频生成状态: none/pending/running/completed/failed",
    )

    # 视频文件信息
    video_filename = Column(String(500), nullable=True, comment="生成的视频文件名")
    video_file_path = Column(String(1000), nullable=True, comment="视频文件完整路径")
    video_file_size = Column(Integer, nullable=True, comment="视频文件大小(字节)")

    # 生成参数记录
    source_type = Column(
        String(20), nullable=False, comment="图片来源类型: role/scene/comfyui"
    )
    original_prompt = Column(Text, nullable=True, comment="原始图片生成提示词")
    video_prompt = Column(Text, nullable=True, comment="视频生成提示词")
    model_name = Column(String(100), nullable=True, comment="使用的视频生成模型")
    user_input = Column(Text, nullable=True, comment="用户输入要求")

    # 任务关联
    current_task_id = Column(Integer, nullable=True, comment="当前视频生成任务ID")
    video_comfyui_task_id = Column(
        String(255), nullable=True, comment="ComfyUI视频生成任务ID"
    )

    # 时间戳
    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), comment="创建时间"
    )
    first_requested_at = Column(
        DateTime(timezone=True), nullable=True, comment="首次请求视频生成时间"
    )
    video_completed_at = Column(
        DateTime(timezone=True), nullable=True, comment="视频完成时间"
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        comment="更新时间",
    )

    # 错误信息
    error_message = Column(Text, nullable=True, comment="最近一次错误信息")
    retry_count = Column(Integer, default=0, nullable=False, comment="重试次数")

    # 索引定义
    __table_args__ = (
        Index("idx_img_name_status", "img_name", "video_status"),
        Index("idx_source_type_status", "source_type", "video_status"),
    )

    def __repr__(self) -> str:
        """返回模型的字符串表示."""
        return (
            f"<ImageVideoStatus(img_name='{self.img_name}', "
            f"has_video={self.has_video}, video_status='{self.video_status}')>"
        )

    def to_dict(self) -> dict:
        """转换为字典格式."""
        return {
            "id": self.id,
            "img_name": self.img_name,
            "has_video": self.has_video,
            "video_status": self.video_status,
            "video_filename": self.video_filename,
            "video_file_path": self.video_file_path,
            "video_file_size": self.video_file_size,
            "source_type": self.source_type,
            "original_prompt": self.original_prompt,
            "video_prompt": self.video_prompt,
            "model_name": self.model_name,
            "user_input": self.user_input,
            "current_task_id": self.current_task_id,
            "video_comfyui_task_id": self.video_comfyui_task_id,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "first_requested_at": self.first_requested_at.isoformat()
            if self.first_requested_at
            else None,
            "video_completed_at": self.video_completed_at.isoformat()
            if self.video_completed_at
            else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "error_message": self.error_message,
            "retry_count": self.retry_count,
        }
