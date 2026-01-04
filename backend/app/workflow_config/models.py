"""
工作流配置响应模型

使用方法：
    from app.workflow_config.models import WorkflowType, WorkflowResponse, WorkflowListResponse

    # 获取工作流列表
    response = workflow_config_manager.list_workflows(WorkflowType.T2I)
    workflows = response.workflows
"""

from enum import Enum

from pydantic import BaseModel


class WorkflowType(str, Enum):
    """工作流类型枚举"""

    T2I = "t2i"  # 文生图
    I2V = "i2v"  # 图生视频


class WorkflowResponse(BaseModel):
    """工作流响应模型"""

    title: str
    description: str
    path: str
    width: int | None = None
    height: int | None = None

    class Config:
        json_schema_extra = {
            "example": {
                "title": "动漫风",
                "description": "用于生成角色卡的标准文生图工作流",
                "path": "./comfyui_json/text2img/t2i_704x1408.json",
                "width": 704,
                "height": 1280,
            }
        }


class WorkflowListResponse(BaseModel):
    """工作流列表响应模型"""

    workflows: list[WorkflowResponse]
    total_count: int
    workflow_type: WorkflowType

    class Config:
        json_schema_extra = {
            "example": {
                "workflows": [
                    {
                        "title": "动漫风",
                        "description": "用于生成角色卡的标准文生图工作流",
                        "path": "./comfyui_json/text2img/t2i_704x1408.json",
                    }
                ],
                "total_count": 1,
                "workflow_type": "t2i",
            }
        }
