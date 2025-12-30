"""
ComfyUI图生视频客户端.

本章提供与ComfyUI进行图生视频交互的客户端功能。
"""

import asyncio
import json
import logging
import random
from pathlib import Path
from typing import Any

import requests
from requests.exceptions import RequestException, Timeout

from ..config import settings

logger = logging.getLogger(__name__)


class ComfyUIVideoClient:
    """ComfyUI图生视频客户端."""

    def __init__(self, base_url: str, workflow_path: str):
        """初始化ComfyUI视频客户端.

        Args:
            base_url: ComfyUI服务器基础URL
            workflow_path: 图生视频工作流JSON文件路径
        """
        self.base_url = base_url.rstrip("/")
        self.workflow_path = workflow_path
        self.workflow_json = None
        self._load_workflow()

    def _load_workflow(self) -> None:
        """加载ComfyUI图生视频工作流JSON配置."""
        try:
            workflow_file = Path(self.workflow_path)
            if not workflow_file.exists():
                raise FileNotFoundError(
                    f"图生视频工作流文件不存在: {self.workflow_path}"
                )

            with open(workflow_file, encoding="utf-8") as f:
                self.workflow_json = json.load(f)

            logger.info(f"成功加载ComfyUI图生视频工作流: {self.workflow_path}")

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"加载ComfyUI图生视频工作流失败: {e}")
            raise

    def replace_image_placeholder(
        self, workflow_data: dict[str, Any], image_filename: str
    ) -> dict[str, Any]:
        """替换工作流中的图片占位符.

        Args:
            workflow_data: 工作流数据
            image_filename: 图片文件名

        Returns:
            替换后的工作流数据
        """
        if not self.workflow_json:
            logger.error("工作流JSON未加载")
            return {}

        try:
            # 深拷贝工作流数据
            updated_workflow = json.loads(json.dumps(workflow_data))

            # 遍历所有节点，查找并替换图片占位符
            for node_id, node_data in updated_workflow.items():
                if node_id == "config":
                    continue

                inputs = node_data.get("inputs", {})
                for key, value in inputs.items():
                    if isinstance(value, str) and "图片base64在这里替换" in value:
                        # 替换占位符为文件名
                        new_value = value.replace(
                            "图片base64在这里替换", image_filename
                        )
                        inputs[key] = new_value
                        logger.info(
                            f"在节点 {node_id} 的字段 {key} 中替换了图片占位符为文件名: {image_filename}"
                        )

            return updated_workflow

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"替换图片占位符失败: {e}")
            return workflow_data

    async def generate_video_from_image(
        self, video_prompt: str, image_filename: str
    ) -> str | None:
        """从图片生成视频.

        Args:
            video_prompt: 视频生成提示词
            image_filename: 图片文件名

        Returns:
            任务ID，如果生成失败则返回None
        """
        if not self.workflow_json:
            logger.error("图生视频工作流JSON未加载")
            return None

        try:
            comfyui_url = settings.comfyui_api_url
            image_url = f"{comfyui_url}/view?filename={image_filename}"
            response = requests.get(image_url, timeout=30)
            upload_url = f"{comfyui_url}/upload/image"
            response = requests.post(
                upload_url,
                files={"image": (image_filename, response.content, "image/png")},
                timeout=30,
            )

            # 准备工作流数据
            workflow_data = open(self.workflow_path, encoding="utf-8").read()

            # 替换图片占位符
            workflow_data = workflow_data.replace(
                "图片base64在这里替换", image_filename
            )

            # 设置视频提示词
            workflow_data = workflow_data.replace("提示词在这里替换", video_prompt)

            # 设置随机种子
            workflow_data = workflow_data.replace(
                '"在这替换随机数"', str(random.randint(1, 999999999))
            )

            # 调用ComfyUI API
            response = requests.post(
                f"{self.base_url}/prompt",
                json={"prompt": json.loads(workflow_data)},
                timeout=30,
            )

            if response.status_code == 200:
                result = response.json()
                task_id = result.get("prompt_id")
                if task_id:
                    logger.info(f"ComfyUI图生视频任务已提交: {task_id}")
                    return task_id
                else:
                    logger.error("ComfyUI响应中未找到task_id")
                    return None
            else:
                logger.error(
                    f"ComfyUI图生视频API请求失败: {response.status_code} - {response.text}"
                )
                return None

        except Timeout:
            logger.error("ComfyUI图生视频API请求超时")
            return None
        except RequestException as e:
            logger.error(f"ComfyUI图生视频API请求异常: {e}")
            return None
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"ComfyUI图生视频生成失败: {e}")
            return None

    def _set_video_prompt(
        self, workflow_data: dict[str, Any], video_prompt: str
    ) -> dict[str, Any]:
        """设置视频提示词.

        Args:
            workflow_data: 工作流数据
            video_prompt: 视频生成提示词

        Returns:
            更新后的工作流数据
        """
        try:
            # 查找CLIPTextEncode节点或其他文本输入节点
            for node_id, node_data in workflow_data.items():
                if node_id == "config":
                    continue

                class_type = node_data.get("class_type")
                if class_type in ["CLIPTextEncode", "PrimitiveStringMultiline"]:
                    inputs = node_data.get("inputs", {})

                    # 查找text或value字段
                    if "text" in inputs:
                        inputs["text"] = video_prompt
                        logger.info(f"在节点 {node_id} 中设置了视频提示词")
                    elif "value" in inputs:
                        inputs["value"] = video_prompt
                        logger.info(f"在节点 {node_id} 中设置了视频提示词")

            return workflow_data

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"设置视频提示词失败: {e}")
            return workflow_data

    def _set_random_seed(
        self, workflow_data: dict[str, Any], seed: int | None = None
    ) -> dict[str, Any]:
        """设置随机种子.

        Args:
            workflow_data: 工作流数据
            seed: 随机种子，如果为None则生成随机种子

        Returns:
            更新后的工作流数据
        """
        import random

        if seed is None:
            # 生成随机种子
            seed = random.randint(0, 2**31 - 1)
            logger.info(f"生成随机种子: {seed}")
        else:
            logger.info(f"使用指定种子: {seed}")

        try:
            for node_id, node_data in workflow_data.items():
                if node_id == "config":
                    continue

                class_type = node_data.get("class_type")
                if class_type == "KSampler":
                    inputs = node_data.get("inputs", {})
                    if "seed" in inputs:
                        inputs["seed"] = seed
                        logger.info(f"设置种子 = {seed} 在KSampler节点 {node_id}")
                        break

            return workflow_data

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"设置随机种子失败: {e}")
            return workflow_data

    async def check_video_generation_status(self, task_id: str) -> dict[str, Any]:
        """检查视频生成任务状态.

        Args:
            task_id: 任务ID

        Returns:
            任务状态信息
        """
        try:
            response = requests.get(f"{self.base_url}/history/{task_id}", timeout=10)
            if response.status_code == 200:
                return response.json().get(task_id, {})
            else:
                logger.error(f"查询视频生成任务状态失败: {response.status_code}")
                return {}
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"查询视频生成任务状态异常: {e}")
            return {}

    async def wait_for_video_completion(
        self, task_id: str, timeout: int = 3600
    ) -> str | None:
        """等待视频生成完成并获取视频文件名.

        Args:
            task_id: 任务ID
            timeout: 超时时间（秒）

        Returns:
            生成的视频文件名，失败时返回None
        """
        start_time = asyncio.get_event_loop().time()

        while True:
            if asyncio.get_event_loop().time() - start_time > timeout:
                logger.error(f"视频生成任务 {task_id} 超时")
                return None

            task_info = await self.check_video_generation_status(task_id)
            if not task_info:
                await asyncio.sleep(5)
                continue

            status = task_info.get("status", {})
            if status.get("status_str") in ["completed", "success"]:
                outputs = task_info.get("outputs", {})
                # 查找视频文件
                for node_output in outputs.values():
                    # 优先检查videos字段
                    if "videos" in node_output:
                        for video in node_output["videos"]:
                            filename = video.get("filename")
                            if filename:
                                logger.info(f"找到生成的视频: {filename}")
                                return filename
                    # 检查images字段（ComfyUI可能将视频放在这里）
                    if "images" in node_output:
                        for image in node_output["images"]:
                            filename = image.get("filename")
                            subfolder = image.get("subfolder", "")
                            # 检查文件扩展名或subfolder是否为video
                            if filename and (
                                filename.lower().endswith((".gif", ".mp4", ".webm"))
                                or subfolder == "video"
                            ):
                                logger.info(
                                    f"找到生成的视频文件: {filename}, subfolder: {subfolder}"
                                )
                                # 返回格式化的文件路径
                                if subfolder:
                                    return f"{filename}|{subfolder}"  # 用|分隔文件名和子文件夹
                                else:
                                    return filename
                logger.warning("任务完成但未找到视频文件")
                return None
            elif status.get("status_str") in ["error", "failed"]:
                logger.error(f"视频生成任务失败: {status.get('messages', [])}")
                return None

            await asyncio.sleep(5)

    async def get_video_data(
        self, filename: str, subfolder: str | None = None
    ) -> bytes | None:
        """获取视频二进制数据.

        Args:
            filename: 视频文件名
            subfolder: 子文件夹(如'video')

        Returns:
            视频二进制数据，失败时返回None
        """
        try:
            # 构建API URL - 使用正确的端点 /api/view
            url = f"{self.base_url}/api/view?filename={filename}&type=output"
            if subfolder:
                url += f"&subfolder={subfolder}"

            logger.info(f"从ComfyUI API获取视频: {url}")
            response = requests.get(url, timeout=60)
            if response.status_code == 200:
                logger.info(
                    f"✅ 成功获取视频: {filename}, 大小: {len(response.content)} bytes"
                )
                return response.content
            else:
                logger.error(f"获取视频失败: {response.status_code}")
                return None
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"获取视频异常: {e}")
            return None

    async def health_check(self) -> bool:
        """检查ComfyUI服务健康状态."""
        try:
            response = requests.get(f"{self.base_url}/system_stats", timeout=5)
            return response.status_code == 200
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"ComfyUI健康检查失败: {e}")
            return False


def create_comfyui_video_client() -> ComfyUIVideoClient:
    """创建ComfyUI图生视频客户端实例."""
    from ..workflow_config import WorkflowType, workflow_config_manager

    base_url = settings.comfyui_api_url

    # 从workflow配置中获取默认的i2v工作流
    try:
        i2v_workflow = workflow_config_manager.get_default_workflow(WorkflowType.I2V)
        workflow_path = i2v_workflow.path
        logger.info(f"使用i2v工作流: {i2v_workflow.title}, 路径: {workflow_path}")
    except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
        logger.error(f"获取i2v工作流失败: {e}")
        # 使用fallback路径
        workflow_path = "./comfyui_json/img2video/i2v.json"

    return ComfyUIVideoClient(base_url, workflow_path)
