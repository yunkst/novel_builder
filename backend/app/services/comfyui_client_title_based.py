"""
基于节点标题的通用ComfyUI客户端
"""

import asyncio
import json
import logging
import os
from pathlib import Path
from typing import Any

import requests
from requests.exceptions import RequestException, Timeout

logger = logging.getLogger(__name__)


class ComfyUIClientTitleBased:
    """基于节点标题的通用ComfyUI客户端"""

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

    def _load_workflow(self) -> None:
        """加载ComfyUI工作流JSON配置."""
        try:
            workflow_file = Path(self.workflow_path)
            if not workflow_file.exists():
                raise FileNotFoundError(f"工作流文件不存在: {self.workflow_path}")

            with open(workflow_file, encoding="utf-8") as f:
                self.workflow_json = json.load(f)

            logger.info(f"成功加载ComfyUI工作流: {self.workflow_path}")

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"加载ComfyUI工作流失败: {e}")
            raise

    def find_nodes_by_title(
        self, target_titles: list[str]
    ) -> dict[str, dict[str, Any]]:
        """根据节点标题查找节点.

        Args:
            target_titles: 目标标题列表

        Returns:
            匹配的节点字典
        """
        matching_nodes = {}

        for node_id, node_data in self.workflow_json.items():
            if node_id == "config":
                continue

            meta = node_data.get("_meta", {})
            title = meta.get("title", "")

            # 检查标题是否匹配任何目标标题
            for target_title in target_titles:
                if target_title.lower() in title.lower():
                    matching_nodes[node_id] = {
                        "title": title,
                        "class_type": node_data.get("class_type"),
                        "inputs": node_data.get("inputs", {}),
                    }
                    break

        return matching_nodes

    def prepare_workflow_by_title(
        self, prompt: str, target_titles: list[str] | None = None
    ) -> dict[str, Any]:
        """根据节点标题准备工作流.

        Args:
            prompt: 图片生成提示词
            target_titles: 目标标题列表，默认为常用的提示词标题

        Returns:
            准备好的工作流数据
        """
        if target_titles is None:
            target_titles = [
                "prompts",
                "提示词",
                "CLIP Text Encode",
                "prompt",
                "positive",
                "text",
                "文本编码",
                "CLIP文本编码",
            ]

        workflow_data = json.loads(json.dumps(self.workflow_json))

        # 查找匹配的节点
        matching_nodes = self.find_nodes_by_title(target_titles)
        logger.info(f"找到 {len(matching_nodes)} 个匹配标题的节点")

        # 执行替换
        replaced_count = 0
        for node_id, node_info in matching_nodes.items():
            if "text" in node_info["inputs"]:
                workflow_data[node_id]["inputs"]["text"]
                workflow_data[node_id]["inputs"]["text"] = prompt
                logger.info(f"已替换节点 {node_id} ({node_info['title']})")
                replaced_count += 1

        logger.info(f"总共替换了 {replaced_count} 个节点的提示词")
        return workflow_data

    async def generate_image_by_title(
        self, prompt: str, target_titles: list[str] | None = None
    ) -> str | None:
        """根据节点标题生成图片.

        Args:
            prompt: 图片生成提示词
            target_titles: 目标标题列表

        Returns:
            任务ID，如果生成失败则返回None
        """
        if not self.workflow_json:
            logger.error("工作流JSON未加载")
            return None

        try:
            # 准备工作流数据
            workflow_data = self.prepare_workflow_by_title(prompt, target_titles)

            # 调用ComfyUI API
            response = requests.post(
                f"{self.base_url}/prompt", json={"prompt": workflow_data}, timeout=30
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

        except Timeout:
            logger.error("ComfyUI API请求超时")
            return None
        except RequestException as e:
            logger.error(f"ComfyUI API请求异常: {e}")
            return None
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"ComfyUI图片生成失败: {e}")
            return None

    # 保持原有的其他方法...
    async def check_task_status(self, task_id: str) -> dict[str, Any]:
        """检查任务状态."""
        try:
            response = requests.get(f"{self.base_url}/history/{task_id}", timeout=10)
            if response.status_code == 200:
                return response.json().get(task_id, {})
            else:
                logger.error(f"查询任务状态失败: {response.status_code}")
                return {}
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"查询任务状态异常: {e}")
            return {}

    async def wait_for_completion(
        self, task_id: str, timeout: int = 300
    ) -> list[str] | None:
        """等待任务完成并获取生成的图片文件名."""
        start_time = asyncio.get_event_loop().time()

        while True:
            if asyncio.get_event_loop().time() - start_time > timeout:
                logger.error(f"任务 {task_id} 超时")
                return None

            task_info = await self.check_task_status(task_id)
            if not task_info:
                await asyncio.sleep(2)
                continue

            status = task_info.get("status", {})
            if status.get("status_str") == "completed":
                outputs = task_info.get("outputs", {})
                images = []
                for node_output in outputs.values():
                    if "images" in node_output:
                        for image in node_output["images"]:
                            filename = image.get("filename")
                            if filename:
                                images.append(filename)
                                logger.info(f"找到生成的图片: {filename}")
                return images if images else None
            elif status.get("status_str") in ["error", "failed"]:
                logger.error(f"任务失败: {status.get('messages', [])}")
                return None

            await asyncio.sleep(3)

    def get_image_url(self, filename: str) -> str:
        """获取图片访问URL."""
        return f"{self.base_url}/view?filename={filename}"

    async def get_image_data(self, filename: str) -> bytes | None:
        """获取图片二进制数据."""
        try:
            response = requests.get(self.get_image_url(filename), timeout=30)
            if response.status_code == 200:
                return response.content
            else:
                logger.error(f"获取图片失败: {response.status_code}")
                return None
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"获取图片异常: {e}")
            return None

    async def health_check(self) -> bool:
        """检查ComfyUI服务健康状态."""
        try:
            response = requests.get(f"{self.base_url}/system_stats", timeout=5)
            return response.status_code == 200
        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError) as e:
            logger.error(f"ComfyUI健康检查失败: {e}")
            return False

    def analyze_workflow(self) -> dict[str, Any]:
        """分析工作流结构."""
        if not self.workflow_json:
            return {"error": "工作流未加载"}

        analysis = {
            "total_nodes": 0,
            "nodes_with_titles": 0,
            "clip_text_nodes": 0,
            "node_details": {},
        }

        for node_id, node_data in self.workflow_json.items():
            if node_id == "config":
                continue

            analysis["total_nodes"] += 1

            meta = node_data.get("_meta", {})
            title = meta.get("title", "")
            class_type = node_data.get("class_type", "")

            if title:
                analysis["nodes_with_titles"] += 1

            if class_type == "CLIPTextEncode":
                analysis["clip_text_nodes"] += 1

            analysis["node_details"][node_id] = {
                "class_type": class_type,
                "title": title,
                "has_text_input": "text" in node_data.get("inputs", {}),
                "is_target": any(
                    keyword.lower() in title.lower()
                    for keyword in ["prompts", "提示词", "text", "prompt"]
                ),
            }

        return analysis


def create_comfyui_client_title_based() -> ComfyUIClientTitleBased:
    """创建基于标题的ComfyUI客户端实例."""
    from ..config import settings

    base_url = settings.comfyui_api_url
    workflow_path = os.getenv(
        "COMFYUI_WORKFLOW_PATH",
        "./comfyui_json/text2img/image_netayume_lumina_t2i.json",
    )

    return ComfyUIClientTitleBased(base_url, workflow_path)
