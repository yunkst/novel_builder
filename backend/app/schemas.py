#!/usr/bin/env python3
"""
Pydantic schemas for API request/response models.

This module contains data models used throughout the application
for request validation and response serialization.
"""

from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field, field_serializer, field_validator


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
# 通用文生图工具模式（保留供角色卡功能使用）
# ============================================================================

class ComfyUIPromptRequest(BaseModel):
    """ComfyUI生图请求模式."""

    prompt: str = Field(..., description="图片生成提示词")
    workflow_json: Dict[str, Any] = Field(..., description="ComfyUI工作流JSON")


class ComfyUIImageResponse(BaseModel):
    """ComfyUI图片响应模式."""

    filename: str = Field(..., description="图片文件名")
    subfolder: Optional[str] = Field(None, description="子文件夹")
    type: Optional[str] = Field("output", description="图片类型")


# ============================================================================
# 统一角色信息模型
# ============================================================================

class RoleInfo(BaseModel):
    """统一角色信息模型 - 增强版，支持自动序列化."""

    id: int = Field(..., description="Flutter自增ID")
    name: str = Field(..., description="角色姓名")
    gender: Optional[str] = Field(None, description="性别")
    age: Optional[int] = Field(None, description="年龄")
    occupation: Optional[str] = Field(None, description="职业")
    personality: Optional[str] = Field(None, description="性格特点")
    appearance_features: Optional[str] = Field(None, description="外貌特征")
    body_type: Optional[str] = Field(None, description="身材体型")
    clothing_style: Optional[str] = Field(None, description="穿衣风格")
    background_story: Optional[str] = Field(None, description="背景经历")
    face_prompts: Optional[str] = Field(None, description="AI绘图专用-面部描述")
    body_prompts: Optional[str] = Field(None, description="AI绘图专用-身材描述")

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式，用于数据库存储"""
        result = {"id": self.id, "name": self.name}

        # 动态添加非空字段
        optional_fields = [
            'gender', 'age', 'occupation', 'personality',
            'appearance_features', 'body_type', 'clothing_style',
            'background_story', 'face_prompts', 'body_prompts'
        ]

        for field in optional_fields:
            value = getattr(self, field)
            if value is not None:
                result[field] = value

        return result

    def to_simple_description(self) -> str:
        """生成简单描述，用于字典格式"""
        parts = []
        if self.age:
            parts.append(f"{self.age}岁")
        if self.gender:
            parts.append(self.gender)
        if self.occupation:
            parts.append(self.occupation)
        if self.appearance_features:
            parts.append(self.appearance_features)

        return "，".join(parts) if parts else self.name

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'RoleInfo':
        """从字典创建RoleInfo对象"""
        return cls(**data)

    def to_json_string(self) -> str:
        """转换为JSON字符串"""
        import json
        return json.dumps(self.to_dict(), ensure_ascii=False)

    @classmethod
    def from_json_string(cls, json_str: str) -> 'RoleInfo':
        """从JSON字符串创建RoleInfo对象"""
        import json
        data = json.loads(json_str)
        return cls(**data)


# ============================================================================
# 人物卡功能相关API模式
# ============================================================================

class RoleCardGenerateRequest(BaseModel):
    """人物卡图片生成请求模式."""

    role_id: str = Field(..., description="人物卡ID")
    roles: List[RoleInfo] = Field(..., description="人物卡设定信息列表")
    user_input: str = Field(..., description="用户要求")
    model: Optional[str] = Field(None, description="指定使用的模型名称，不填则使用默认模型")


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
    model: Optional[str] = Field(None, description="指定使用的模型名称，不填则使用默认模型")


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


# ============================================================================
# 场面绘制功能相关API模式
# ============================================================================

class SceneIllustrationRequest(BaseModel):
    """场面绘制请求模式."""

    chapters_content: str = Field(..., description="章节内容")
    task_id: str = Field(..., description="任务标识符")
    roles: List[RoleInfo] = Field(..., description="角色信息列表")
    num: int = Field(..., ge=1, le=10, description="生成图片数量")
    model_name: Optional[str] = Field(None, description="指定使用的模型名称，不填则使用默认模型")


class EnhancedSceneIllustrationRequest(BaseModel):
    """增强的场景插图请求模型 - 支持多种输入格式和自动序列化."""

    chapters_content: str = Field(..., description="章节内容")
    task_id: str = Field(..., description="任务标识符")
    roles: List[RoleInfo] = Field(..., description="角色信息列表")
    num: int = Field(..., ge=1, le=10, description="生成图片数量")
    model_name: Optional[str] = Field(None, description="指定使用的模型名称，不填则使用默认模型")

    @field_validator('roles', mode='before')
    @classmethod
    def validate_roles(cls, v):
        """支持多种输入格式的roles字段验证"""
        if isinstance(v, dict):
            # 从字典格式转换 {"主角": "描述"}
            role_list = []
            for i, (name, description) in enumerate(v.items()):
                role_list.append({
                    "id": i + 1,
                    "name": name,
                    "appearance_features": description
                })
            return [RoleInfo(**role) for role in role_list]
        elif isinstance(v, list):
            # 处理列表格式
            validated_roles = []
            for role in v:
                if isinstance(role, dict):
                    validated_roles.append(RoleInfo(**role))
                elif hasattr(role, 'name'):  # 已经是RoleInfo对象
                    validated_roles.append(role)
                else:
                    raise ValueError(f"无法解析角色数据: {role}")
            return validated_roles
        else:
            raise ValueError(f"不支持的roles格式: {type(v)}")

    def to_roles_dict(self) -> Dict[str, str]:
        """转换为Dify客户端期望的字典格式"""
        roles_dict = {}
        for role in self.roles:
            roles_dict[role.name] = role.to_simple_description()
        return roles_dict

    def to_roles_json(self) -> str:
        """转换为JSON字符串用于数据库存储"""
        import json
        roles_data = [role.to_dict() for role in self.roles]
        return json.dumps(roles_data, ensure_ascii=False)


class SceneIllustrationResponse(BaseModel):
    """场面绘制任务创建响应模式."""

    task_id: str = Field(..., description="任务标识符")
    status: str = Field(..., description="任务状态")
    message: str = Field(..., description="响应消息")


class SceneIllustrationStatusResponse(BaseModel):
    """场面绘制任务状态响应模式."""

    task_id: str = Field(..., description="任务标识符")
    status: str = Field(..., description="任务状态: pending/running/completed/failed")
    num: int = Field(..., description="请求生成的图片数量")
    generated_images: int = Field(..., description="已生成的图片数量")
    prompts: Optional[str] = Field(None, description="Dify生成的提示词")
    result_message: Optional[str] = Field(None, description="处理结果消息")
    error_message: Optional[str] = Field(None, description="错误信息")
    created_at: str = Field(..., description="创建时间")
    started_at: Optional[str] = Field(None, description="开始处理时间")
    completed_at: Optional[str] = Field(None, description="完成时间")
    progress_percentage: float = Field(..., description="进度百分比")


class SceneGalleryResponse(BaseModel):
    """场面图片列表响应模式."""

    task_id: str = Field(..., description="场面绘制任务ID")
    images: List[str] = Field(..., description="图片文件名列表")


class SceneImageDeleteRequest(BaseModel):
    """删除场面图片请求模式."""

    task_id: str = Field(..., description="场面绘制任务ID")
    filename: str = Field(..., description="要删除的图片文件名")
