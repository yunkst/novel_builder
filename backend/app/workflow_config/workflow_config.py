"""
ComfyUI工作流配置管理器
负责加载和管理YAML格式的工作流配置
"""

import logging
import os
from pathlib import Path
from typing import Any

import yaml
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)


class WorkflowInfo(BaseModel):
    """工作流信息模型"""
    title: str = Field(..., description="工作流标题")
    path: str = Field(..., description="工作流文件路径")
    description: str | None = Field(None, description="工作流描述")
    model_type: str | None = Field(None, description="模型类型")


class WorkflowSettings(BaseModel):
    """全局工作流设置"""
    default_t2i_model: str = Field(..., description="默认t2i模型")
    api_timeout: int = Field(300, description="API超时时间（秒）")
    max_concurrent_tasks: int = Field(5, description="最大并发任务数")


class WorkflowConfig(BaseModel):
    """完整工作流配置模型"""
    t2i: list[WorkflowInfo] = Field(default_factory=list, description="文生图工作流列表")
    i2v: list[WorkflowInfo] = Field(default_factory=list, description="图生视频工作流列表")
    settings: WorkflowSettings = Field(..., description="全局设置")


class WorkflowConfigManager:
    """工作流配置管理器"""

    def __init__(self, config_path: str | None = None):
        """
        初始化配置管理器

        Args:
            config_path: 配置文件路径，默认为backend/workflows.yaml
        """
        if config_path is None:
            # 根据运行环境确定配置文件路径
            # 在Docker容器中，backend目录挂载到/app，所以配置文件在/app/workflows.yaml
            # 在本地开发中，相对于当前文件的路径

            # 检查是否在Docker容器中运行（通过检查/app目录是否存在）
            if Path("/app").exists() and Path("/app/app").exists():
                # 在Docker容器中
                config_path = Path("/app/workflows.yaml")
            else:
                # 在本地开发环境
                current_dir = Path(__file__).parent.parent
                config_path = current_dir / "workflows.yaml"

        self.config_path = Path(config_path)
        self._config: WorkflowConfig | None = None
        self._load_config()

    def _load_config(self) -> None:
        """加载YAML配置文件"""
        try:
            if not self.config_path.exists():
                raise FileNotFoundError(f"工作流配置文件不存在: {self.config_path}")

            with self.config_path.open(encoding='utf-8') as f:
                config_data = yaml.safe_load(f)

            if not config_data:
                raise ValueError("配置文件为空")

            self._config = WorkflowConfig(**config_data)
            logger.info(f"成功加载工作流配置: {self.config_path}")

        except Exception as e:
            logger.error(f"加载工作流配置失败: {e}")
            raise

    def get_config(self) -> WorkflowConfig:
        """获取完整配置"""
        if self._config is None:
            raise RuntimeError("配置未初始化")
        return self._config

    def get_t2i_workflow_by_title(self, title: str) -> WorkflowInfo | None:
        """
        根据标题获取t2i工作流

        Args:
            title: 工作流标题

        Returns:
            工作流信息，如果未找到返回None
        """
        config = self.get_config()
        for workflow in config.t2i:
            if workflow.title == title:
                return workflow
        return None

    def get_i2v_workflow_by_title(self, title: str) -> WorkflowInfo | None:
        """
        根据标题获取i2v工作流

        Args:
            title: 工作流标题

        Returns:
            工作流信息，如果未找到返回None
        """
        config = self.get_config()
        for workflow in config.i2v:
            if workflow.title == title:
                return workflow
        return None

    def get_default_t2i_workflow(self) -> WorkflowInfo:
        """
        获取默认t2i工作流

        Returns:
            默认工作流信息

        Raises:
            ValueError: 当没有可用的t2i工作流时
        """
        config = self.get_config()

        # 首先尝试使用配置中指定的默认模型
        default_title = config.settings.default_t2i_model
        default_workflow = self.get_t2i_workflow_by_title(default_title)

        if default_workflow:
            return default_workflow

        # 如果指定的默认模型不存在，使用第一个可用的
        if config.t2i:
            logger.warning(f"指定的默认模型 '{default_title}' 不存在，使用第一个可用模型")
            return config.t2i[0]

        raise ValueError("没有可用的t2i工作流配置")

    def get_default_i2v_workflow(self) -> WorkflowInfo:
        """
        获取默认i2v工作流

        Returns:
            默认工作流信息

        Raises:
            ValueError: 当没有可用的i2v工作流时
        """
        config = self.get_config()

        if config.i2v:
            return config.i2v[0]

        raise ValueError("没有可用的i2v工作流配置")

    def list_t2i_workflows(self) -> list[dict[str, Any]]:
        """
        列出所有可用的t2i工作流

        Returns:
            工作流信息列表
        """
        config = self.get_config()
        return [
            {
                "title": workflow.title,
                "path": workflow.path,
                "description": workflow.description,
                "model_type": workflow.model_type
            }
            for workflow in config.t2i
        ]

    def validate_workflow_path(self, workflow_path: str) -> bool:
        """
        验证工作流文件是否存在

        Args:
            workflow_path: 工作流文件路径

        Returns:
            文件是否存在
        """
        # 如果是相对路径，需要根据环境确定基础路径
        if not os.path.isabs(workflow_path):
            # 检查是否在Docker容器中运行
            if Path("/app").exists() and Path("/app/app").exists():
                # 在Docker容器中，直接使用/app作为基础路径
                backend_dir = Path("/app")
            else:
                # 在本地开发环境，使用相对路径
                backend_dir = Path(__file__).parent.parent
            full_path = backend_dir / workflow_path
        else:
            full_path = Path(workflow_path)

        return full_path.exists()

    def get_full_workflow_path(self, workflow_path: str) -> str:
        """
        获取工作流文件的完整路径

        Args:
            workflow_path: 工作流文件路径

        Returns:
            完整路径
        """
        if os.path.isabs(workflow_path):
            return workflow_path

        # 检查是否在Docker容器中运行
        if Path("/app").exists() and Path("/app/app").exists():
            # 在Docker容器中，直接使用/app作为基础路径
            backend_dir = Path("/app")
        else:
            # 在本地开发环境，使用相对路径
            backend_dir = Path(__file__).parent.parent

        full_path = backend_dir / workflow_path
        return str(full_path.resolve())

    def reload_config(self) -> None:
        """重新加载配置文件"""
        self._config = None
        self._load_config()


# 全局配置管理器实例
workflow_config_manager = WorkflowConfigManager()
