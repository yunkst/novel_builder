"""
ComfyUI API客户端服务.

本章提供与ComfyUI服务器交互的客户端功能，包括图片生成、任务状态查询和图片获取。
支持基于YAML配置的多工作流动态选择。
"""

import asyncio
import base64
import json
import logging
import random
from enum import Enum
from pathlib import Path
from typing import Any

import requests
from requests.exceptions import RequestException

from ..workflow_config.workflow_config import workflow_config_manager

logger = logging.getLogger(__name__)


class WorkflowType(str, Enum):
    """工作流类型枚举"""

    TEXT_TO_IMAGE = "t2i"
    IMAGE_TO_VIDEO = "i2v"


class MediaFileType(str, Enum):
    """媒体文件类型枚举"""

    IMAGE = "image"
    VIDEO = "video"


class MediaFileResult:
    """媒体文件结果"""

    def __init__(self, filename: str, file_type: MediaFileType):
        self.filename = filename
        self.file_type = file_type

    def __repr__(self):
        return f"MediaFileResult(filename='{self.filename}', type='{self.file_type}')"


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
        self.workflow_json = None
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

            with open(workflow_file, encoding="utf-8") as f:
                self.workflow_json = json.load(f)

            logger.info(f"成功加载ComfyUI工作流: {full_path}")

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"加载ComfyUI工作流失败: {e}")
            raise

    async def generate_image(self, prompt: str) -> str | None:
        """生成图片.

        Args:
            prompt: 图片生成提示词

        Returns:
            任务ID，如果生成失败则返回None
        """
        if not self.workflow_json:
            logger.error("工作流JSON未加载")
            return None

        try:
            # 准备工作流数据（返回JSON字符串）
            workflow_json_str = self._prepare_workflow(prompt)

            # 调用ComfyUI API
            response = requests.post(
                f"{self.base_url}/prompt",
                json={"prompt": json.loads(workflow_json_str)},
                timeout=None,  # 移除超时限制
            )

            if response.status_code == 200:
                result = response.json()
                task_id = result.get("prompt_id")
                if task_id:
                    logger.info(f"ComfyUI图片生成任务已提交: {task_id}")
                    return task_id
                else:
                    logger.error("ComfyUI响应中未找到task_id")
                    return None
            else:
                logger.error(
                    f"ComfyUI API请求失败: {response.status_code} - {response.text}"
                )
                return None

        except RequestException as e:
            logger.error(f"ComfyUI API请求异常: {e}")
            return None
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"ComfyUI图片生成失败: {e}")
            return None

    async def generate_images_batch(self, prompts: list[str]) -> list[str] | None:
        """批量生成图片.

        Args:
            prompts: 图片生成提示词列表

        Returns:
            生成的图片文件名列表，如果生成失败则返回None
        """
        if not prompts:
            logger.error("提示词列表为空")
            return None

        image_filenames = []
        for i, prompt in enumerate(prompts):
            logger.info(f"生成第 {i + 1}/{len(prompts)} 张图片")
            try:
                # 提交生成任务，获取ComfyUI任务ID
                task_id = await self.generate_image(prompt)
                if task_id:
                    logger.info(f"ComfyUI任务ID: {task_id}")
                    # 等待任务完成并获取实际图片文件名
                    completed_files = await self.wait_for_completion(task_id)
                    if completed_files and len(completed_files) > 0:
                        media_file = completed_files[0]  # 使用第一个生成的媒体文件
                        filename = media_file.filename  # 获取文件名
                        image_filenames.append(filename)
                        logger.info(f"第 {i + 1} 张图片生成成功，文件名: {filename}")
                    else:
                        logger.warning(f"第 {i + 1} 张图片生成失败（未获取到文件名）")
                else:
                    logger.warning(f"第 {i + 1} 张图片生成失败（提交任务失败）")
            except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
                logger.error(f"生成第 {i + 1} 张图片时发生异常: {e}")
                continue

        if not image_filenames:
            logger.error("所有图片生成都失败了")
            return None

        logger.info(f"批量图片生成完成，共生成 {len(image_filenames)} 张图片")
        return image_filenames

    async def check_task_status(self, task_id: str) -> dict[str, Any]:
        """检查任务状态.

        Args:
            task_id: 任务ID

        Returns:
            任务状态信息
        """
        try:
            response = requests.get(f"{self.base_url}/history/{task_id}", timeout=10)

            if response.status_code == 200:
                history = response.json()
                return history.get(task_id, {})
            else:
                logger.error(f"查询任务状态失败: {response.status_code}")
                return {}

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"查询任务状态异常: {e}")
            return {}

    async def wait_for_completion(self, task_id: str) -> list[MediaFileResult] | None:
        """等待任务完成并获取生成的媒体文件名（支持图片和视频）.

        Args:
            task_id: 任务ID

        Returns:
            生成的媒体文件信息列表，失败则返回None
        """
        while True:
            # 查询任务状态
            task_info = await self.check_task_status(task_id)

            if not task_info:
                await asyncio.sleep(2)
                continue

            # 检查任务状态
            status = task_info.get("status", {})

            if status.get("status_str") in ["completed", "success"]:
                # 任务完成，获取媒体文件
                outputs = task_info.get("outputs", {})
                media_files = []

                # 遍历输出节点查找图片和视频
                for node_output in outputs.values():
                    # 处理图片文件
                    if "images" in node_output:
                        for image in node_output["images"]:
                            filename = image.get("filename")
                            if filename:
                                file_type_enum = (
                                    MediaFileType.VIDEO
                                    if filename.lower().endswith(".mp4")
                                    else MediaFileType.IMAGE
                                )
                                media_files.append(
                                    MediaFileResult(filename, file_type_enum)
                                )
                                logger.info(
                                    f"找到生成的{file_type_enum.value}: {filename}"
                                )

                    # 处理视频文件（可能在不同的输出字段）
                    if "videos" in node_output:
                        for video in node_output["videos"]:
                            filename = video.get("filename")
                            if filename:
                                media_files.append(
                                    MediaFileResult(filename, MediaFileType.VIDEO)
                                )
                                logger.info(f"找到生成的视频: {filename}")

                if media_files:
                    return media_files
                else:
                    logger.error("任务完成但未找到生成的媒体文件")
                    return None

            elif status.get("status_str") in ["error", "failed"]:
                error_msg = status.get("messages", [])
                logger.error(f"任务失败: {error_msg}")
                return None

            # 继续等待
            await asyncio.sleep(3)

    def get_media_url(self, filename: str) -> str:
        """获取媒体文件访问URL（支持图片和视频）.

        Args:
            filename: 媒体文件名

        Returns:
            媒体文件访问URL
        """
        return f"{self.base_url}/view?filename={filename}"

    def get_image_url(self, filename: str) -> str:
        """获取图片访问URL（保持向后兼容）.

        Args:
            filename: 图片文件名

        Returns:
            图片访问URL
        """
        return self.get_media_url(filename)

    async def get_media_data(self, filename: str) -> bytes | None:
        """获取媒体文件二进制数据（支持图片和视频）.

        Args:
            filename: 媒体文件名

        Returns:
            媒体文件二进制数据，失败则返回None
        """
        try:
            response = requests.get(
                self.get_media_url(filename),
                timeout=None,  # 移除超时限制
            )

            if response.status_code == 200:
                return response.content
            else:
                logger.error(f"获取媒体文件失败: {response.status_code}")
                return None

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
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
            upload_response = requests.post(
                f"{self.base_url}/upload/image", files=files, timeout=None
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
            response = requests.post(
                f"{self.base_url}/prompt",
                json={"prompt": json.loads(workflow_json_str)},
                timeout=None,  # 移除超时限制
            )

            if response.status_code == 200:
                result = response.json()
                task_id = result.get("prompt_id")
                if task_id:
                    logger.info(f"ComfyUI视频生成任务已提交: {task_id}")
                    return task_id
                else:
                    logger.error("ComfyUI响应中未找到task_id")
                    return None
            else:
                logger.error(
                    f"ComfyUI API请求失败: {response.status_code} - {response.text}"
                )
                return None

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"ComfyUI视频生成失败: {e}")
            return None

    def _prepare_workflow(self, prompt: str, image_base64: str | None = None) -> str:
        """准备ComfyUI工作流数据 - 使用固定字符串替换模式.

        Args:
            prompt: 图片生成提示词
            image_base64: 图片的base64编码（仅图生视频使用）

        Returns:
            准备好的工作流JSON字符串

        Raises:
            ValueError: 当输入参数无效时
        """
        # 输入验证
        if not prompt or not prompt.strip():
            raise ValueError("提示词不能为空")

        if image_base64 and not image_base64.strip():
            raise ValueError("图片base64数据不能为空字符串")

        # 将工作流JSON序列化为字符串
        workflow_content = json.dumps(self.workflow_json, ensure_ascii=False)

        # 执行固定替换
        workflow_content = workflow_content.replace("提示词在这里替换", prompt)
        workflow_content = workflow_content.replace(
            '"在这替换随机数"', str(random.randint(1, 999999))
        )

        # 图生视频时替换图片base64数据
        if image_base64:
            workflow_content = workflow_content.replace(
                "图片base64在这里替换", image_base64
            )
            logger.info("已注入图片base64数据到工作流")

        logger.info(f"工作流准备完成，提示词长度: {len(prompt)}")
        return workflow_content

    def _encode_image_to_base64(self, image_data: bytes) -> str:
        """将图片数据编码为base64字符串.

        Args:
            image_data: 图片二进制数据

        Returns:
            base64编码的字符串
        """
        return base64.b64encode(image_data).decode("utf-8")

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

        # 将工作流JSON序列化为字符串
        workflow_content = json.dumps(self.workflow_json, ensure_ascii=False)

        # 执行固定替换
        workflow_content = workflow_content.replace("提示词在这里替换", prompt)
        workflow_content = workflow_content.replace(
            '"在这替换随机数"', str(random.randint(1, 999999))
        )
        workflow_content = workflow_content.replace(
            "图片base64在这里替换", image_filename
        )

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
            response = requests.get(f"{self.base_url}/system_stats", timeout=5)
            return response.status_code == 200
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"ComfyUI健康检查失败: {e}")
            return False


def create_comfyui_client(
    workflow_path: str | None = None,
    model_title: str | None = None,
    workflow_type: str = "t2i",
) -> ComfyUIClient:
    """创建ComfyUI客户端实例.

    Args:
        workflow_path: 指定的工作流路径（可选）
        model_title: 模型标题，用于从配置中查找工作流（可选）
        workflow_type: 工作流类型，"t2i"（文生图）或 "i2v"（图生视频）

    Returns:
        ComfyUI客户端实例
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


def create_comfyui_client_for_model(
    model_title: str, workflow_type: str = "t2i"
) -> ComfyUIClient:
    """为指定模型创建ComfyUI客户端实例.

    Args:
        model_title: 模型标题
        workflow_type: 工作流类型，"t2i"（文生图）或 "i2v"（图生视频）

    Returns:
        ComfyUI客户端实例

    Raises:
        ValueError: 当模型不存在时
    """
    return create_comfyui_client(model_title=model_title, workflow_type=workflow_type)


def create_t2i_client(model_title: str | None = None) -> ComfyUIClient:
    """创建文生图客户端实例.

    Args:
        model_title: 模型标题（可选，使用默认模型）

    Returns:
        ComfyUI客户端实例
    """
    return create_comfyui_client(model_title=model_title, workflow_type="t2i")


def create_i2v_client(model_title: str | None = None) -> ComfyUIClient:
    """创建图生视频客户端实例.

    Args:
        model_title: 模型标题（可选，使用默认模型）

    Returns:
        ComfyUI客户端实例
    """
    return create_comfyui_client(model_title=model_title, workflow_type="i2v")
