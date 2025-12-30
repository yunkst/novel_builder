"""
模型验证工具函数.

提供模型名称验证和默认值处理的通用功能。
"""

import logging
from typing import Literal

from ..workflow_config import WorkflowType, workflow_config_manager

logger = logging.getLogger(__name__)


def validate_and_get_model(
    model_name: str | None, workflow_type: Literal["T2I", "I2V", "IMG2VID"]
) -> str:
    """验证并返回有效的模型名称.

    Args:
        model_name: 用户指定的模型名称（可选）
        workflow_type: 工作流类型（T2I、I2V、IMG2VID）

    Returns:
        有效的模型名称（如果输入无效则返回默认模型）

    Raises:
        ValueError: 当工作流类型无效时
    """
    try:
        # 映射工作流类型
        workflow_type_enum = WorkflowType[workflow_type]

        # 获取可用模型列表和默认模型
        workflows_response = workflow_config_manager.list_workflows(workflow_type_enum)
        available_models = [wf.title for wf in workflows_response.workflows]
        default_workflow = workflow_config_manager.get_default_workflow(
            workflow_type_enum
        )
        default_model = default_workflow.title

    except KeyError as e:
        logger.error(f"无效的工作流类型: {workflow_type}")
        raise ValueError(f"无效的工作流类型: {workflow_type}") from e
    except Exception as e:
        logger.warning(f"获取模型配置失败，使用默认值: {e}")
        available_models = ["默认模型"]
        default_model = "默认模型"

    # 处理model_name，实现智能默认值替换
    if model_name:
        if model_name not in available_models:
            logger.warning(
                f"指定的model_name '{model_name}' 不在可用模型列表中，"
                f"将使用默认模型: {default_model}"
            )
            return default_model
        else:
            logger.info(f"使用指定的model_name '{model_name}'")
            return model_name
    else:
        logger.info(f"未指定model_name，使用默认模型: {default_model}")
        return default_model
