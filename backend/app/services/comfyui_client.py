"""
ComfyUI API客户端服务.

本章提供与ComfyUI服务器交互的客户端功能，包括图片生成、任务状态查询和图片获取。
支持基于YAML配置的多工作流动态选择。
"""

import json
import logging
import random
from pathlib import Path
from typing import Any

import httpx

from ..workflow_config.workflow_config import workflow_config_manager

logger = logging.getLogger(__name__)


# 各类 ComfyUI 调用的超时配置（秒）。
# ComfyUI 提交 prompt 是异步落队,通常很快返回,但偶尔会卡顿,留 30s 余量。
TIMEOUT_SUBMIT_PROMPT = 30.0
# history 查询应当很快。
TIMEOUT_CHECK_STATUS = 10.0
# 拉取生成的图片/视频二进制:大视频可能很慢,留 120s。
TIMEOUT_GET_MEDIA = 120.0
# 健康检查。
TIMEOUT_HEALTH_CHECK = 5.0


class ComfyUIClient:
    """ComfyUI API客户端."""

    def __init__(self, base_url: str, workflow_path: str):
        """初始化ComfyUI客户端.

        Args:
            base_url: ComfyUI服务器基础URL
            workflow_path: 工作流JSON文件路径
        """
        self.base_url = base_url.rstrip("/")
        self.workflow_path = workflow_path
        self.workflow_json: dict | None = None
        self._load_workflow()
        logger.info("ComfyUI客户端初始化完成")

    def _load_workflow(self) -> None:
        """加载ComfyUI工作流JSON配置."""
        try:
            # 获取工作流的完整路径
            full_path = workflow_config_manager.get_full_workflow_path(
                self.workflow_path
            )
            workflow_file = Path(full_path)

            if not workflow_file.exists():
                raise FileNotFoundError(f"工作流文件不存在: {full_path}")

            with workflow_file.open(encoding="utf-8") as f:
                self.workflow_json = json.load(f)

            logger.info(f"成功加载ComfyUI工作流: {full_path}")

        except (OSError, ValueError, json.JSONDecodeError) as e:
            logger.error(f"加载ComfyUI工作流失败: {e}")
            raise

    async def generate_image(
        self, prompt: str, negative_prompt: str | None = None
    ) -> str | None:
        """生成图片.

        Args:
            prompt: 图片生成提示词
            negative_prompt: 负向提示词(可选);仅当工作流 JSON 含
                「负向提示词在这里替换」占位符时生效,找不到则静默忽略

        Returns:
            任务ID，如果生成失败则返回None
        """
        if not self.workflow_json:
            logger.error("工作流JSON未加载")
            return None

        try:
            # 准备工作流数据（返回JSON字符串）
            workflow_json_str = self._prepare_workflow(prompt, negative_prompt)

            # 调用ComfyUI API（httpx 异步,带超时,不阻塞事件循环）
            async with httpx.AsyncClient(timeout=TIMEOUT_SUBMIT_PROMPT) as client:
                response = await client.post(
                    f"{self.base_url}/prompt",
                    json={"prompt": json.loads(workflow_json_str)},
                )

            if response.status_code == 200:
                result = response.json()
                task_id = result.get("prompt_id")
                if task_id:
                    logger.info(f"ComfyUI图片生成任务已提交: {task_id}")
                    return task_id
                logger.error("ComfyUI响应中未找到task_id")
                return None

            logger.error(
                f"ComfyUI API请求失败: {response.status_code} - {response.text}"
            )
            return None

        except (OSError, ValueError, json.JSONDecodeError, httpx.HTTPError) as e:
            logger.error(f"ComfyUI API请求异常: {e}")
            return None

    async def check_task_status(self, task_id: str) -> dict[str, Any]:
        """检查任务状态.

        Args:
            task_id: 任务ID

        Returns:
            任务状态信息
        """
        try:
            async with httpx.AsyncClient(timeout=TIMEOUT_CHECK_STATUS) as client:
                response = await client.get(f"{self.base_url}/history/{task_id}")

            if response.status_code == 200:
                history = response.json()
                return history.get(task_id, {})
            logger.error(f"查询任务状态失败: {response.status_code}")
            return {}

        except (OSError, ValueError, json.JSONDecodeError, httpx.HTTPError) as e:
            logger.error(f"查询任务状态异常: {e}")
            return {}

    async def get_media_data(self, filename: str) -> bytes | None:
        """获取媒体文件二进制数据（支持图片和视频）.

        Args:
            filename: 媒体文件名

        Returns:
            媒体文件二进制数据，失败则返回None
        """
        try:
            url = f"{self.base_url}/view?filename={filename}"
            async with httpx.AsyncClient(timeout=TIMEOUT_GET_MEDIA) as client:
                response = await client.get(url)

            if response.status_code == 200:
                return response.content
            logger.error(f"获取媒体文件失败: {response.status_code}")
            return None

        except (OSError, ValueError, httpx.HTTPError) as e:
            logger.error(f"获取媒体文件异常: {e}")
            return None

    async def get_image_data(self, filename: str) -> bytes | None:
        """获取图片二进制数据（保持向后兼容）.

        Args:
            filename: 图片文件名

        Returns:
            图片二进制数据，失败则返回None
        """
        return await self.get_media_data(filename)

    async def generate_video(
        self, prompt: str, image_data: bytes, image_filename: str = "input_image.png"
    ) -> str | None:
        """生成视频（图生视频）.

        Args:
            prompt: 视频生成提示词
            image_data: 输入图片的二进制数据
            image_filename: 图片文件名（用于ComfyUI内部处理）

        Returns:
            任务ID，如果生成失败则返回None
        """
        if not self.workflow_json:
            logger.error("工作流JSON未加载")
            return None

        try:
            # 第一步：上传图片到ComfyUI
            files = {"image": (image_filename, image_data, "image/png")}
            async with httpx.AsyncClient(timeout=TIMEOUT_SUBMIT_PROMPT) as client:
                upload_response = await client.post(
                    f"{self.base_url}/upload/image", files=files
                )

            if upload_response.status_code != 200:
                logger.error(
                    f"图片上传失败: {upload_response.status_code} - {upload_response.text}"
                )
                return None

            upload_result = upload_response.json()
            uploaded_filename = upload_result.get("name")

            if not uploaded_filename:
                logger.error("图片上传成功但未获取到文件名")
                return None

            logger.info(f"图片上传成功: {uploaded_filename}")

            # 第二步：准备工作流数据（使用上传的文件名）
            workflow_json_str = self._prepare_workflow_with_filename(
                prompt, uploaded_filename
            )

            # 调用ComfyUI API
            async with httpx.AsyncClient(timeout=TIMEOUT_SUBMIT_PROMPT) as client:
                response = await client.post(
                    f"{self.base_url}/prompt",
                    json={"prompt": json.loads(workflow_json_str)},
                )

            if response.status_code == 200:
                result = response.json()
                task_id = result.get("prompt_id")
                if task_id:
                    logger.info(f"ComfyUI视频生成任务已提交: {task_id}")
                    return task_id
                logger.error("ComfyUI响应中未找到task_id")
                return None

            logger.error(
                f"ComfyUI API请求失败: {response.status_code} - {response.text}"
            )
            return None

        except (OSError, ValueError, json.JSONDecodeError, httpx.HTTPError) as e:
            logger.error(f"ComfyUI视频生成失败: {e}")
            return None

    def _prepare_workflow(
        self,
        prompt: str,
        negative_prompt: str | None = None,
    ) -> str:
        """准备ComfyUI工作流数据 - 使用固定字符串替换模式.

        通过递归遍历工作流 JSON,按「占位符字符串」原值匹配后替换:
        - "提示词在这里替换"        → 正向提示词 prompt
        - "负向提示词在这里替换"    → 负向提示词 negative_prompt
          (negative_prompt 为空时,占位符原样保留,工作流可保留其默认值)
        - "在这替换随机数"          → 1~999999 随机 seed

        找不到对应占位符的工作流不会受影响(如某些工作流用
        ConditioningZeroOut 模拟负向,不含该字面量)。

        Args:
            prompt: 图片生成提示词
            negative_prompt: 负向提示词（可选）

        Returns:
            准备好的工作流JSON字符串

        Raises:
            ValueError: 当输入参数无效时
        """
        # 输入验证
        if not prompt or not prompt.strip():
            raise ValueError("提示词不能为空")

        # 负向提示词白名单 trim(空串视为不提供,保留工作流占位符/默认值)
        negative_prompt_trimmed = negative_prompt.strip() if negative_prompt else None

        # 创建工作流副本并修改（避免修改原始workflow_json）
        workflow_json_copy = json.loads(json.dumps(self.workflow_json))

        # 在JSON对象中查找并替换提示词
        def replace_prompt_in_workflow(workflow_dict):
            """递归查找并替换工作流中的提示词占位符"""
            if isinstance(workflow_dict, dict):
                for key, value in workflow_dict.items():
                    if isinstance(value, str) and value == "提示词在这里替换":
                        workflow_dict[key] = prompt
                    elif (
                        isinstance(value, str)
                        and value == "负向提示词在这里替换"
                        and negative_prompt_trimmed
                    ):
                        workflow_dict[key] = negative_prompt_trimmed
                    elif isinstance(value, str) and value == "在这替换随机数":
                        workflow_dict[key] = random.randint(1, 999999)
                    elif isinstance(value, (dict, list)):
                        replace_prompt_in_workflow(value)
            elif isinstance(workflow_dict, list):
                for item in workflow_dict:
                    replace_prompt_in_workflow(item)

        replace_prompt_in_workflow(workflow_json_copy)

        # 序列化为JSON字符串
        workflow_content = json.dumps(workflow_json_copy, ensure_ascii=False)

        if negative_prompt_trimmed:
            logger.info(f"已注入负向提示词(长度: {len(negative_prompt_trimmed)})")

        logger.info(f"工作流准备完成，提示词长度: {len(prompt)}")
        return workflow_content

    def _prepare_workflow_with_filename(self, prompt: str, image_filename: str) -> str:
        """准备ComfyUI工作流数据 - 使用图片文件名替换模式（用于图生视频）.

        Args:
            prompt: 视频生成提示词
            image_filename: 上传后的图片文件名

        Returns:
            准备好的工作流JSON字符串

        Raises:
            ValueError: 当输入参数无效时
        """
        # 输入验证
        if not prompt or not prompt.strip():
            raise ValueError("提示词不能为空")

        if not image_filename or not image_filename.strip():
            raise ValueError("图片文件名不能为空")

        # 创建工作流副本并修改（避免修改原始workflow_json）
        workflow_json_copy = json.loads(json.dumps(self.workflow_json))

        # 在JSON对象中查找并替换提示词
        def replace_prompt_in_workflow(workflow_dict):
            """递归查找并替换工作流中的提示词占位符"""
            if isinstance(workflow_dict, dict):
                for key, value in workflow_dict.items():
                    if isinstance(value, str) and value == "提示词在这里替换":
                        workflow_dict[key] = prompt
                    elif isinstance(value, str) and value == "在这替换随机数":
                        workflow_dict[key] = random.randint(1, 999999)
                    elif isinstance(value, str) and value == "图片base64在这里替换":
                        workflow_dict[key] = image_filename
                    elif isinstance(value, (dict, list)):
                        replace_prompt_in_workflow(value)
            elif isinstance(workflow_dict, list):
                for item in workflow_dict:
                    replace_prompt_in_workflow(item)

        replace_prompt_in_workflow(workflow_json_copy)

        # 序列化为JSON字符串
        workflow_content = json.dumps(workflow_json_copy, ensure_ascii=False)

        logger.info(
            f"图生视频工作流准备完成，提示词长度: {len(prompt)}, 图片: {image_filename}"
        )
        return workflow_content

    async def health_check(self) -> bool:
        """检查ComfyUI服务健康状态.

        Returns:
            服务是否可用
        """
        try:
            async with httpx.AsyncClient(timeout=TIMEOUT_HEALTH_CHECK) as client:
                response = await client.get(f"{self.base_url}/system_stats")
            return response.status_code == 200
        except (OSError, ValueError, httpx.HTTPError) as e:
            logger.error(f"ComfyUI健康检查失败: {e}")
            return False


# === 客户端缓存 ===
# ComfyUIClient 构造时会读 YAML + 工作流 JSON 文件,频繁创建有磁盘开销。
# 这里按 (workflow_type, model_title) 缓存客户端实例,假设运行时工作流文件不变。
# 如需热加载工作流,需手动清空此缓存或重启进程。
_client_cache: dict[tuple[str, str | None], ComfyUIClient] = {}


def _get_or_create_client(workflow_type: str, model_title: str | None) -> ComfyUIClient:
    """从缓存取或新建 ComfyUIClient."""
    cache_key = (workflow_type, model_title)
    cached = _client_cache.get(cache_key)
    if cached is not None:
        return cached
    client = _build_client(model_title=model_title, workflow_type=workflow_type)
    _client_cache[cache_key] = client
    return client


def _build_client(
    workflow_path: str | None = None,
    model_title: str | None = None,
    workflow_type: str = "t2i",
) -> ComfyUIClient:
    """实际构造 ComfyUIClient 实例（无缓存）.

    Args:
        workflow_path: 指定的工作流路径（可选）
        model_title: 模型标题，用于从配置中查找工作流（可选）
        workflow_type: 工作流类型，"t2i"（文生图）或 "i2v"（图生视频）

    Returns:
        ComfyUIClient客户端实例
    """
    from ..config import settings

    base_url = settings.comfyui_api_url  # 固定的ComfyUI服务地址

    # 根据参数确定工作流路径
    if workflow_path is None and model_title is not None:
        # 根据模型标题和工作流类型查找工作流
        if workflow_type == "t2i":
            workflow_info = workflow_config_manager.get_t2i_workflow_by_title(
                model_title
            )
        elif workflow_type == "i2v":
            workflow_info = workflow_config_manager.get_i2v_workflow_by_title(
                model_title
            )
        else:
            raise ValueError(f"不支持的工作流类型: {workflow_type}")

        if workflow_info is None:
            raise ValueError(
                f"未找到模型 '{model_title}' 对应的{workflow_type}工作流配置"
            )
        workflow_path = workflow_info.path
    elif workflow_path is None:
        # 使用默认工作流
        from ..workflow_config import WorkflowType

        if workflow_type == "t2i":
            default_workflow = workflow_config_manager.get_default_workflow(
                WorkflowType.T2I
            )
        elif workflow_type == "i2v":
            default_workflow = workflow_config_manager.get_default_workflow(
                WorkflowType.I2V
            )
        else:
            raise ValueError(f"不支持的工作流类型: {workflow_type}")
        workflow_path = default_workflow.path

    return ComfyUIClient(base_url, workflow_path)


def create_comfyui_client(
    workflow_path: str | None = None,
    model_title: str | None = None,
    workflow_type: str = "t2i",
) -> ComfyUIClient:
    """创建ComfyUI客户端实例（带缓存）.

    Args:
        workflow_path: 指定的工作流路径（可选,传入则不走缓存）
        model_title: 模型标题，用于从配置中查找工作流（可选）
        workflow_type: 工作流类型，"t2i"（文生图）或 "i2v"（图生视频）

    Returns:
        ComfyUIClient客户端实例
    """
    # 显式指定 workflow_path 时无法稳定缓存(参数组合不唯一),直接构造。
    if workflow_path is not None:
        return _build_client(
            workflow_path=workflow_path,
            model_title=model_title,
            workflow_type=workflow_type,
        )
    return _get_or_create_client(workflow_type, model_title)


def create_comfyui_client_for_model(
    model_title: str, workflow_type: str = "t2i"
) -> ComfyUIClient:
    """为指定模型创建ComfyUI客户端实例.

    Args:
        model_title: 模型标题
        workflow_type: 工作流类型，"t2i"（文生图）或 "i2v"（图生视频）

    Returns:
        ComfyUIClient客户端实例

    Raises:
        ValueError: 当模型不存在时
    """
    return create_comfyui_client(model_title=model_title, workflow_type=workflow_type)


def create_t2i_client(model_title: str | None = None) -> ComfyUIClient:
    """创建文生图客户端实例.

    Args:
        model_title: 模型标题（可选，使用默认模型）

    Returns:
        ComfyUIClient客户端实例
    """
    return create_comfyui_client(model_title=model_title, workflow_type="t2i")


def create_i2v_client(model_title: str | None = None) -> ComfyUIClient:
    """创建图生视频客户端实例.

    Args:
        model_title: 模型标题（可选，使用默认模型）

    Returns:
        ComfyUIClient客户端实例
    """
    return create_comfyui_client(model_title=model_title, workflow_type="i2v")
