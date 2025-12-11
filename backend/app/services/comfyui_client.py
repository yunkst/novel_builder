"""
ComfyUI API客户端服务.

本章提供与ComfyUI服务器交互的客户端功能，包括图片生成、任务状态查询和图片获取。
"""

import json
import logging
import os
from typing import Dict, Any, Optional, List
import asyncio
from pathlib import Path

import requests
from requests.exceptions import RequestException, Timeout

logger = logging.getLogger(__name__)


class ComfyUIClient:
    """ComfyUI API客户端."""

    def __init__(self, base_url: str, workflow_path: str):
        """初始化ComfyUI客户端.

        Args:
            base_url: ComfyUI服务器基础URL
            workflow_path: 工作流JSON文件路径
        """
        self.base_url = base_url.rstrip('/')
        self.workflow_path = workflow_path
        self.workflow_json = None
        self._load_workflow()

        # 加载配置的环境变量
        self._load_target_titles_from_env()

    def _load_target_titles_from_env(self) -> None:
        """从环境变量加载目标标题配置."""
        # 从环境变量获取目标标题，用逗号分隔
        env_titles = os.getenv("COMFYUI_TARGET_TITLES", "")

        if env_titles:
            # 分割并清理标题列表
            self.target_titles = [title.strip() for title in env_titles.split(",") if title.strip()]
            logger.info(f"从环境变量加载目标标题: {self.target_titles}")
        else:
            # 使用默认的目标标题列表（正面提示词）
            self.target_titles = [
                "prompts",           # 最优先
                "提示词",             # 中文提示词
                "positive prompt",    # 正面提示词
                "positive",          # 正面
                "prompt",             # 英文提示词
                "text",               # 文本（优先级较低）
                "输入"                 # 中文输入
            ]
            logger.info("使用默认目标标题列表")

    def _load_workflow(self) -> None:
        """加载ComfyUI工作流JSON配置."""
        try:
            workflow_file = Path(self.workflow_path)
            if not workflow_file.exists():
                raise FileNotFoundError(f"工作流文件不存在: {self.workflow_path}")

            with open(workflow_file, 'r', encoding='utf-8') as f:
                self.workflow_json = json.load(f)

            logger.info(f"成功加载ComfyUI工作流: {self.workflow_path}")

        except Exception as e:
            logger.error(f"加载ComfyUI工作流失败: {e}")
            raise

    async def generate_image(self, prompt: str) -> Optional[str]:
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
            # 准备工作流数据
            workflow_data = self._prepare_workflow(prompt)

            # 调用ComfyUI API
            response = requests.post(
                f"{self.base_url}/prompt",
                json={"prompt": workflow_data},
                timeout=30
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
                logger.error(f"ComfyUI API请求失败: {response.status_code} - {response.text}")
                return None

        except Timeout:
            logger.error("ComfyUI API请求超时")
            return None
        except RequestException as e:
            logger.error(f"ComfyUI API请求异常: {e}")
            return None
        except Exception as e:
            logger.error(f"ComfyUI图片生成失败: {e}")
            return None

    async def check_task_status(self, task_id: str) -> Dict[str, Any]:
        """检查任务状态.

        Args:
            task_id: 任务ID

        Returns:
            任务状态信息
        """
        try:
            response = requests.get(
                f"{self.base_url}/history/{task_id}",
                timeout=10
            )

            if response.status_code == 200:
                history = response.json()
                return history.get(task_id, {})
            else:
                logger.error(f"查询任务状态失败: {response.status_code}")
                return {}

        except Exception as e:
            logger.error(f"查询任务状态异常: {e}")
            return {}

    async def wait_for_completion(self, task_id: str, timeout: int = 300) -> Optional[List[str]]:
        """等待任务完成并获取生成的图片文件名.

        Args:
            task_id: 任务ID
            timeout: 超时时间（秒）

        Returns:
            生成的图片文件名列表，失败则返回None
        """
        start_time = asyncio.get_event_loop().time()

        while True:
            # 检查超时
            if asyncio.get_event_loop().time() - start_time > timeout:
                logger.error(f"任务 {task_id} 超时")
                return None

            # 查询任务状态
            task_info = await self.check_task_status(task_id)

            if not task_info:
                await asyncio.sleep(2)
                continue

            # 检查任务状态
            status = task_info.get("status", {})

            if status.get("status_str") == "completed":
                # 任务完成，获取图片
                outputs = task_info.get("outputs", {})
                images = []

                # 遍历输出节点找到图片
                for node_id, node_output in outputs.items():
                    if "images" in node_output:
                        for image in node_output["images"]:
                            filename = image.get("filename")
                            if filename:
                                images.append(filename)
                                logger.info(f"找到生成的图片: {filename}")

                if images:
                    return images
                else:
                    logger.error("任务完成但未找到生成的图片")
                    return None

            elif status.get("status_str") in ["error", "failed"]:
                error_msg = status.get("messages", [])
                logger.error(f"任务失败: {error_msg}")
                return None

            # 继续等待
            await asyncio.sleep(3)

    def get_image_url(self, filename: str) -> str:
        """获取图片访问URL.

        Args:
            filename: 图片文件名

        Returns:
            图片访问URL
        """
        return f"{self.base_url}/view?filename={filename}"

    async def get_image_data(self, filename: str) -> Optional[bytes]:
        """获取图片二进制数据.

        Args:
            filename: 图片文件名

        Returns:
            图片二进制数据，失败则返回None
        """
        try:
            response = requests.get(
                self.get_image_url(filename),
                timeout=30
            )

            if response.status_code == 200:
                return response.content
            else:
                logger.error(f"获取图片失败: {response.status_code}")
                return None

        except Exception as e:
            logger.error(f"获取图片异常: {e}")
            return None

    def _prepare_workflow(self, prompt: str) -> Dict[str, Any]:
        """准备ComfyUI工作流数据 - 基于环境变量配置的标题替换.

        Args:
            prompt: 图片生成提示词

        Returns:
            准备好的工作流数据
        """
        workflow_data = json.loads(json.dumps(self.workflow_json))

        # 查找并替换匹配的节点
        replaced_nodes = []

        for node_id, node_data in workflow_data.items():
            if node_id == "config":
                continue

            # 检查节点标题是否匹配目标标题
            meta = node_data.get("_meta", {})
            title = meta.get("title", "")

            # 模糊匹配目标标题（正面提示词）
            for target_title in self.target_titles:
                if target_title.lower() in title.lower():
                    # 检查是否是提示词相关的节点类型
                    if node_data.get("class_type") in ["CLIPTextEncode", "PrimitiveStringMultiline"]:
                        inputs = node_data.get("inputs", {})

                        if "text" in inputs:
                            # 直接替换正面提示词
                            original_text = inputs["text"]
                            inputs["text"] = prompt
                            replaced_nodes.append({
                                "node_id": node_id,
                                "title": title,
                                "original": original_text[:50] + "..." if len(original_text) > 50 else original_text
                            })
                            logger.info(f"已替换节点 {node_id} ('{title}') 的提示词")
                            break  # 每个节点只替换一次

        # 记录日志
        if replaced_nodes:
            logger.info(f"总共替换了 {len(replaced_nodes)} 个节点的提示词")
            for node_info in replaced_nodes:
                logger.debug(f"节点 {node_info['node_id']}: '{node_info['title']}' 原={node_info['original']}")
        else:
            logger.warning(f"未找到合适的提示词节点，使用备用方案")
            # 备用方案：直接查找CLIPTextEncode节点
            self._fallback_prepare_workflow(workflow_data, prompt)

        return workflow_data

    def _fallback_prepare_workflow(self, workflow_data: Dict[str, Any], prompt: str) -> None:
        """备用方案：直接查找CLIPTextEncode节点进行替换."""
        logger.info("使用备用方案查找CLIPTextEncode节点")

        for node_id, node_data in workflow_data.items():
            if node_data.get("class_type") == "CLIPTextEncode":
                inputs = node_data.get("inputs", {})

                if "text" in inputs:
                    inputs["text"] = prompt
                    logger.info(f"备用方案：已替换CLIPTextEncode节点 {node_id}")
                    break

    async def health_check(self) -> bool:
        """检查ComfyUI服务健康状态.

        Returns:
            服务是否可用
        """
        try:
            response = requests.get(f"{self.base_url}/system_stats", timeout=5)
            return response.status_code == 200
        except Exception as e:
            logger.error(f"ComfyUI健康检查失败: {e}")
            return False


def create_comfyui_client() -> ComfyUIClient:
    """创建ComfyUI客户端实例."""
    base_url = os.getenv("COMFYUI_API_URL", "http://host.docker.internal:8000")
    workflow_path = os.getenv("COMFYUI_WORKFLOW_PATH", "./comfyui_json/text2img/image_netayume_lumina_t2i.json")

    return ComfyUIClient(base_url, workflow_path)