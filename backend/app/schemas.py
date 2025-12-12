#!/usr/bin/env python3
"""
Pydantic schemas for API request/response models.

This module contains data models used throughout the application
for request validation and response serialization.
"""

from typing import List, Optional, Dict, Any
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


class ChapterContent(BaseModel):
    """Chapter content schema."""

    title: str
    content: str
    from_cache: bool = False


class SourceSite(BaseModel):
    """Source site information schema."""

    id: str              # 站点标识 (alice_sw, shukuge, xspsw)
    name: str            # 站点名称
    base_url: str        # 站点基础URL
    description: str     # 站点描述
    enabled: bool        # 是否启用
    search_enabled: bool # 是否支持搜索功能


# ============================================================================
# 文生图功能相关API模式
# ============================================================================

class Text2ImgStartRequest(BaseModel):
    """开始配图请求模式."""

    novel_content: str = Field(..., description="需要插入图片的小说内容")
    roles: Optional[Dict[str, Any]] = Field(None, description="出场角色信息")
    require: Optional[str] = Field("", description="配图要求")
    chapter_id: str = Field(..., description="章节ID，唯一标识章节")


class IllustrationItem(BaseModel):
    """配图项目模式."""

    index: int = Field(..., description="插入在第index段的后面")
    img_url: str = Field(..., description="图片的地址")


class Text2ImgStatusResponse(BaseModel):
    """获取配图状态响应模式."""

    status: str = Field(..., description="配图状态：processing/completed")
    message: Optional[str] = Field(None, description="状态描述")
    illustrations: Optional[List[IllustrationItem]] = Field(None, description="配图列表")
    total_images: Optional[int] = Field(None, description="需要生成的图片总数")
    completed_images: Optional[int] = Field(None, description="已完成的图片数量")


class DifyPromptResult(BaseModel):
    """Dify工作流返回的提示词结果."""

    index: int = Field(..., description="插入的段落位置")
    img_prompt: str = Field(..., description="提示词信息")


class ComfyUIPromptRequest(BaseModel):
    """ComfyUI生图请求模式."""

    prompt: str = Field(..., description="图片生成提示词")
    workflow_json: Dict[str, Any] = Field(..., description="ComfyUI工作流JSON")


class ComfyUIImageResponse(BaseModel):
    """ComfyUI图片响应模式."""

    filename: str = Field(..., description="图片文件名")
    subfolder: Optional[str] = Field(None, description="子文件夹")
    type: Optional[str] = Field("output", description="图片类型")


class Text2ImgErrorResponse(BaseModel):
    """文生图错误响应模式."""

    error: str = Field(..., description="错误类型")
    message: str = Field(..., description="错误信息")
    chapter_id: Optional[str] = Field(None, description="章节ID")


# ============================================================================
# 人物卡功能相关API模式
# ============================================================================

class RoleCardGenerateRequest(BaseModel):
    """人物卡图片生成请求模式."""

    role_id: str = Field(..., description="人物卡ID")
    roles: Dict[str, Any] = Field(..., description="人物卡设定信息")
    user_input: str = Field(..., description="用户要求")


class RoleImageInfo(BaseModel):
    """角色图片信息模式."""

    img_url: str = Field(..., description="图片URL")
    prompt: str = Field(..., description="生成提示词")
    created_at: str = Field(..., description="创建时间")


class RoleGalleryResponse(BaseModel):
    """角色图集响应模式."""

    role_id: str = Field(..., description="人物卡ID")
    images: List[str] = Field(..., description="图片URL列表")


class RoleImageDeleteRequest(BaseModel):
    """删除角色图片请求模式."""

    role_id: str = Field(..., description="人物卡ID")
    img_url: str = Field(..., description="要删除的图片URL")


class RoleRegenerateRequest(BaseModel):
    """重新生成相似图片请求模式."""

    img_url: str = Field(..., description="参考图片URL")
    count: int = Field(..., ge=1, le=10, description="生成图片数量")


class RoleGenerateResponse(BaseModel):
    """人物卡图片生成响应模式."""

    role_id: str = Field(..., description="人物卡ID")
    total_prompts: int = Field(..., description="生成的提示词数量")
    message: str = Field(..., description="处理消息")


class DifyPhotoResult(BaseModel):
    """Dify拍照工作流返回结果."""

    content: List[str] = Field(..., description="生成的提示词列表")


class RoleCardErrorResponse(BaseModel):
    """人物卡错误响应模式."""

    error: str = Field(..., description="错误类型")
    message: str = Field(..., description="错误信息")
    role_id: Optional[str] = Field(None, description="人物卡ID")


# ============================================================================
# 异步任务相关API模式
# ============================================================================

class RoleCardTaskCreateResponse(BaseModel):
    """人物卡任务创建响应模式."""

    task_id: int = Field(..., description="任务ID")
    role_id: str = Field(..., description="人物卡ID")
    status: str = Field(..., description="任务状态")
    message: str = Field(..., description="响应消息")


class RoleCardTaskStatusResponse(BaseModel):
    """人物卡任务状态响应模式."""

    task_id: int = Field(..., description="任务ID")
    role_id: str = Field(..., description="人物卡ID")
    status: str = Field(..., description="任务状态: pending/running/completed/failed")
    total_prompts: int = Field(..., description="生成的提示词数量")
    generated_images: int = Field(..., description="成功生成的图片数量")
    result_message: Optional[str] = Field(None, description="处理结果消息")
    error_message: Optional[str] = Field(None, description="错误信息")
    created_at: str = Field(..., description="创建时间")
    started_at: Optional[str] = Field(None, description="开始处理时间")
    completed_at: Optional[str] = Field(None, description="完成时间")
    progress_percentage: float = Field(..., description="进度百分比")
