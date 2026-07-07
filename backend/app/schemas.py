#!/usr/bin/env python3
"""
Pydantic schemas for API request/response models.

This module contains data models used throughout the application
for request validation and response serialization.
"""

from pydantic import BaseModel, Field


class Novel(BaseModel):
    """Novel metadata schema."""

    title: str
    author: str
    url: str


class Chapter(BaseModel):
    """Chapter metadata schema."""

    title: str
    url: str


class NovelWithChapters(BaseModel):
    """Novel with chapters response schema."""

    novel: Novel
    chapters: list[Chapter]


class ChapterContent(BaseModel):
    """Chapter content schema."""

    title: str
    content: str
    from_cache: bool = False


class SourceSite(BaseModel):
    """Source site information schema."""

    id: str  # 站点标识 (alice_sw, shukuge, xspsw)
    name: str  # 站点名称
    base_url: str  # 站点基础URL
    description: str  # 站点描述
    enabled: bool  # 是否启用
    search_enabled: bool  # 是否支持搜索功能
    search_reason: str | None = None  # 不支持搜索的原因
    search_hint: str | None = None  # 搜索提示或替代方案


# ============================================================================
# 文生图功能相关API模式
# ============================================================================


class Text2ImgGenerateRequest(BaseModel):
    """文生图生成请求模式."""

    prompt: str = Field(..., min_length=1, max_length=5000, description="图片生成提示词")
    model_name: str | None = Field(
        None, max_length=100, description="模型名称(可选，默认使用默认模型)"
    )
    negative_prompt: str | None = Field(
        None,
        max_length=5000,
        description="负向提示词(可选，避免生成不想要的元素；仅当所选工作流"
        "含独立负向 CLIPTextEncode 且已置入「负向提示词在这里替换」占位符时生效，"
        "否则静默忽略)",
    )


# ============================================================================
# 模型管理相关API模式
# ============================================================================


class WorkflowInfo(BaseModel):
    """工作流信息模式."""

    title: str = Field(..., description="工作流标题")
    description: str = Field(..., description="工作流描述")
    path: str | None = Field(None, description="工作流文件路径")
    width: int | None = Field(None, description="图片宽度（仅T2I）")
    height: int | None = Field(None, description="图片高度（仅T2I）")
    is_default: bool = Field(False, description="是否为默认模型")
    prompt_skill: str | None = Field(
        None,
        description="提示词写作技巧(LLM 据此撰写正向/负向提示词；含具体写法建议)",
    )


class ModelsResponse(BaseModel):
    """模型列表响应模式."""

    text2img: list[WorkflowInfo] = Field(default=[], description="文生图模型列表")
    img2video: list[WorkflowInfo] = Field(default=[], description="图生视频模型列表")


# ============================================================================
# APP版本管理相关API模式
# ============================================================================


class AppVersionUploadRequest(BaseModel):
    """APP版本上传请求模式（已废弃，版本更新迁移到 GitHub Releases）."""

    version: str = Field(..., min_length=1, max_length=20, description="版本号 (如 1.0.1)")
    version_code: int = Field(..., ge=1, description="版本递增码")
    changelog: str | None = Field(None, max_length=2000, description="更新日志")
    force_update: bool = Field(False, description="是否强制更新")


class AppVersionResponse(BaseModel):
    """APP版本信息响应模式（已废弃，版本更新迁移到 GitHub Releases）."""

    version: str = Field(..., description="版本号")
    version_code: int = Field(..., description="版本递增码")
    download_url: str = Field(..., description="下载URL")
    file_size: int = Field(..., description="文件大小(字节)")
    changelog: str | None = Field(None, description="更新日志")
    force_update: bool = Field(False, description="是否强制更新")
    created_at: str = Field(..., description="发布时间")


# ============================================================================
# 数据库备份相关API模式
# ============================================================================


class BackupUploadResponse(BaseModel):
    """数据库备份上传响应模式."""

    filename: str = Field(..., description="原始文件名")
    stored_path: str = Field(..., description="存储路径")
    file_size: int = Field(..., description="文件大小(字节)")
    uploaded_at: str = Field(..., description="上传时间(ISO格式)")
    stored_name: str = Field(..., description="存储文件名")


class BackupInfo(BaseModel):
    """备份文件信息."""

    filename: str = Field(..., description="原始文件名")
    file_size: int = Field(..., description="文件大小(字节)")
    stored_name: str = Field(..., description="存储文件名")
    backup_id: str = Field(..., description="备份唯一标识(相对路径)")
    uploaded_at: str = Field(..., description="上传时间(ISO格式)")


class BackupListResponse(BaseModel):
    """备份列表响应."""

    backups: list[BackupInfo] = Field(
        default_factory=list, description="备份列表(按时间倒序)"
    )


# ================= 客户端日志上报 =================


from datetime import datetime as _dt
from typing import Optional as _Optional


class LogEntrySchema(BaseModel):
    """单条客户端日志条目"""

    timestamp: _dt = Field(..., description="客户端时间戳 (UTC ISO 8601)")
    level: str = Field(..., description="日志级别: debug/info/warning/error")
    message: str = Field(..., description="日志消息内容")
    stack_trace: _Optional[str] = Field(None, description="堆栈信息")
    category: str = Field("general", description="日志分类")
    tags: list[str] = Field(default_factory=list, description="日志标签列表")


class LogUploadRequest(BaseModel):
    """日志上报请求"""

    logs: list[LogEntrySchema] = Field(
        ...,
        min_length=1,
        max_length=50,
        description="待上报的日志列表（1-50条）",
    )


class LogUploadResponse(BaseModel):
    """日志上报响应"""

    received: int = Field(..., description="成功接收的日志条数")
    message: str = Field(..., description="响应消息")


# ============================================================================
# ComfyUI 模型文件分块上传相关 API 模式
# ============================================================================


class ModelDirInfo(BaseModel):
    """ComfyUI 模型目录下的一级子目录信息."""

    name: str = Field(..., description="子目录名")
    size_bytes: int = Field(0, description="目录占用大小估算(字节)")


class ModelDirsResponse(BaseModel):
    """模型子目录列表响应."""

    dirs: list[ModelDirInfo] = Field(default_factory=list, description="一级子目录列表")


class ModelUploadInitRequest(BaseModel):
    """分块上传初始化请求."""

    filename: str = Field(..., description="目标文件名")
    target_subdir: str = Field(..., description="目标一级子目录名")
    total_size: int = Field(..., description="文件总大小(字节)")
    chunk_size: int = Field(..., description="分块大小(字节)")
    total_chunks: int = Field(..., description="分块总数")


class ModelUploadInitResponse(BaseModel):
    """分块上传初始化响应."""

    upload_id: str = Field(..., description="上传任务唯一标识(UUID)")
    chunk_size: int = Field(..., description="实际使用的分块大小(字节)")
    total_chunks: int = Field(..., description="分块总数")


class ModelChunkUploadResponse(BaseModel):
    """分块上传响应."""

    index: int = Field(..., description="分块序号")
    received_bytes: int = Field(..., description="已接收字节数")


class ModelUploadStatusResponse(BaseModel):
    """分块上传状态响应."""

    upload_id: str = Field(..., description="上传任务唯一标识")
    total_chunks: int = Field(..., description="分块总数")
    received_indices: list[int] = Field(
        default_factory=list, description="已接收的分块序号集合"
    )
    complete: bool = Field(..., description="是否所有分块均已接收")


class ModelUploadCompleteResponse(BaseModel):
    """分块上传完成响应."""

    stored_path: str = Field(..., description="最终存储路径(绝对路径)")
    filename: str = Field(..., description="最终文件名")
    size: int = Field(..., description="文件大小(字节)")

