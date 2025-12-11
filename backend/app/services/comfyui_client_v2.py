"""
增强版ComfyUI客户端 - 支持通用工作流替换
"""

import json
import logging
import os
from typing import Dict, Any, Optional, List, Set
import asyncio
from pathlib import Path

import requests
from requests.exceptions import RequestException, Timeout

logger = logging.getLogger(__name__)


class ComfyUIClientV2:
    """增强版ComfyUI客户端，支持标准化工作流替换"""

    def __init__(self, base_url: str, workflow_path: str):
        """初始化ComfyUI客户端.

        Args:
            base_url: ComfyUI服务器基础URL
            workflow_path: 工作流JSON文件路径
        """
        self.base_url = base_url.rstrip('/')
        self.workflow_path = workflow_path
        self.workflow_json = None
        self.replace_config = None
        self._load_workflow()

    def _load_workflow(self) -> None:
        """加载ComfyUI工作流JSON配置."""
        try:
            workflow_file = Path(self.workflow_path)
            if not workflow_file.exists():
                raise FileNotFoundError(f"工作流文件不存在: {self.workflow_path}")

            with open(workflow_file, 'r', encoding='utf-8') as f:
                self.workflow_json = json.load(f)

            # 提取替换配置
            self.replace_config = self.workflow_json.get("config", {}).get("replace_targets", {})

            logger.info(f"成功加载ComfyUI工作流: {self.workflow_path}")
            logger.info(f"替换配置: {self.replace_config}")

        except Exception as e:
            logger.error(f"加载ComfyUI工作流失败: {e}")
            raise

    def _find_replaceable_nodes(self) -> Dict[str, Dict[str, Any]]:
        """查找所有可替换的节点."""
        replaceable_nodes = {}

        for node_id, node_data in self.workflow_json.items():
            # 跳过配置节点
            if node_id == "config":
                continue

            meta = node_data.get("_meta", {})

            # 方法1: 检查元数据标记
            if meta.get("auto_replace") or meta.get("editable"):
                replaceable_nodes[node_id] = {
                    "class_type": node_data.get("class_type"),
                    "method": "meta_tag",
                    "target": meta.get("replace_target", "value"),
                    "prompt_type": meta.get("prompt_type", "user")
                }
                continue

            # 方法2: 检查占位符
            if "inputs" in node_data:
                for key, value in node_data["inputs"].items():
                    if isinstance(value, str) and self._has_placeholders(value):
                        if node_id not in replaceable_nodes:
                            replaceable_nodes[node_id] = {
                                "class_type": node_data.get("class_type"),
                                "method": "placeholder",
                                "targets": {}
                            }
                        replaceable_nodes[node_id]["targets"][key] = self._extract_placeholders(value)

            # 方法3: 基于节点类型和内容的启发式检测
            class_type = node_data.get("class_type")
            if class_type == "PrimitiveStringMultiline":
                value = node_data.get("inputs", {}).get("value", "")
                if self._is_likely_prompt_node(node_id, value):
                    replaceable_nodes[node_id] = {
                        "class_type": class_type,
                        "method": "heuristic",
                        "target": "value",
                        "prompt_type": self._detect_prompt_type(value)
                    }

        return replaceable_nodes

    def _has_placeholders(self, text: str) -> bool:
        """检查文本是否包含占位符."""
        placeholders = ["{{PROMPT}}", "{{USER_PROMPT}}", "{{NEGATIVE_PROMPT}}",
                       "{{STYLE_PREFIX}}", "{{STYLE_SUFFIX}}", "{{STEPS}}", "{{CFG}}"]
        return any(placeholder in text for placeholder in placeholders)

    def _extract_placeholders(self, text: str) -> List[str]:
        """提取文本中的占位符."""
        import re
        pattern = r'\{\{([^}]+)\}\}'
        return re.findall(pattern, text)

    def _is_likely_prompt_node(self, node_id: str, value: str) -> bool:
        """启发式判断是否为提示词节点."""
        # 基于节点ID的启发式规则
        prompt_keywords = ["prompt", "text", "input", "description"]
        negative_keywords = ["negative", "bad", "worst"]

        node_id_lower = node_id.lower()

        # 检查是否包含提示词关键词
        if any(keyword in node_id_lower for keyword in prompt_keywords):
            # 进一步检查是否不是负面提示词
            if not any(neg_keyword in node_id_lower for neg_keyword in negative_keywords):
                return True

        # 检查内容长度（提示词通常较长）
        if len(value) > 100:
            return True

        return False

    def _detect_prompt_type(self, value: str) -> str:
        """检测提示词类型."""
        value_lower = value.lower()

        if any(neg_word in value_lower for neg_word in ["blurry", "worst quality", "low quality", "jpeg artifacts"]):
            return "negative"
        elif any(pos_word in value_lower for pos_word in ["high quality", "masterpiece", "best quality"]):
            return "positive"
        else:
            return "user"

    def _prepare_workflow_v2(self, user_prompt: str, negative_prompt: str = None,
                           style_prefix: str = None, style_suffix: str = None,
                           steps: int = None, cfg: float = None) -> Dict[str, Any]:
        """准备ComfyUI工作流数据 - 增强版.

        Args:
            user_prompt: 主要的用户提示词
            negative_prompt: 负面提示词
            style_prefix: 风格前缀
            style_suffix: 风格后缀
            steps: 采样步数
            cfg: CFG值

        Returns:
            准备好的工作流数据
        """
        workflow_data = json.loads(json.dumps(self.workflow_json))
        replaceable_nodes = self._find_replaceable_nodes()

        logger.info(f"找到 {len(replaceable_nodes)} 个可替换节点")

        # 替换映射
        replacements = {
            "{{PROMPT}}": user_prompt,
            "{{USER_PROMPT}}": user_prompt,
            "{{NEGATIVE_PROMPT}}": negative_prompt or "",
            "{{STYLE_PREFIX}}": style_prefix or "",
            "{{STYLE_SUFFIX}}": style_suffix or "",
            "{{STEPS}}": str(steps) if steps else "",
            "{{CFG}}": str(cfg) if cfg else ""
        }

        # 执行替换
        for node_id, node_info in replaceable_nodes.items():
            if node_id not in workflow_data:
                continue

            node_data = workflow_data[node_id]
            method = node_info.get("method")

            if method == "placeholder":
                # 处理占位符替换
                inputs = node_data.get("inputs", {})
                for input_key, placeholders in node_info.get("targets", {}).items():
                    if input_key in inputs:
                        original_value = inputs[input_key]
                        for placeholder in placeholders:
                            replacement_key = f"{{{{{placeholder}}}}"
                            if replacement_key in replacements:
                                original_value = original_value.replace(replacement_key, replacements[replacement_key])
                        inputs[input_key] = original_value

            elif method == "meta_tag" or method == "heuristic":
                # 直接替换指定字段
                target_field = node_info.get("target", "value")
                prompt_type = node_info.get("prompt_type", "user")
                inputs = node_data.get("inputs", {})

                if target_field in inputs:
                    if prompt_type == "negative" and negative_prompt:
                        inputs[target_field] = negative_prompt
                    elif prompt_type == "positive" and user_prompt:
                        # 组合完整提示词
                        full_prompt = user_prompt
                        if style_prefix:
                            full_prompt = f"{style_prefix} {full_prompt}"
                        if style_suffix:
                            full_prompt = f"{full_prompt} {style_suffix}"
                        inputs[target_field] = full_prompt
                    elif prompt_type == "user":
                        inputs[target_field] = user_prompt

            # 处理特殊参数
            if steps is not None:
                self._set_parameter(workflow_data, steps, "steps")
            if cfg is not None:
                self._set_parameter(workflow_data, cfg, "cfg")

        return workflow_data

    def _set_parameter(self, workflow_data: Dict[str, Any], value: Any, param_name: str):
        """设置工作流参数."""
        for node_id, node_data in workflow_data.items():
            if node_id == "config":
                continue

            class_type = node_data.get("class_type")
            if class_type == "KSampler":
                inputs = node_data.get("inputs", {})
                if param_name in inputs:
                    inputs[param_name] = value
                    logger.info(f"设置 {param_name} = {value} 在节点 {node_id}")
                    break

    async def generate_image_v2(self, user_prompt: str, negative_prompt: str = None,
                               style_prefix: str = None, style_suffix: str = None,
                               steps: int = None, cfg: float = None) -> Optional[str]:
        """生成图片 - 增强版.

        Args:
            user_prompt: 主要的用户提示词
            negative_prompt: 负面提示词
            style_prefix: 风格前缀
            style_suffix: 风格后缀
            steps: 采样步数
            cfg: CFG值

        Returns:
            任务ID，如果生成失败则返回None
        """
        if not self.workflow_json:
            logger.error("工作流JSON未加载")
            return None

        try:
            # 准备工作流数据
            workflow_data = self._prepare_workflow_v2(
                user_prompt=user_prompt,
                negative_prompt=negative_prompt,
                style_prefix=style_prefix,
                style_suffix=style_suffix,
                steps=steps,
                cfg=cfg
            )

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

    # 保持原有的其他方法...
    async def check_task_status(self, task_id: str) -> Dict[str, Any]:
        """检查任务状态."""
        try:
            response = requests.get(
                f"{self.base_url}/history/{task_id}",
                timeout=10
            )
            if response.status_code == 200:
                return response.json().get(task_id, {})
            else:
                logger.error(f"查询任务状态失败: {response.status_code}")
                return {}
        except Exception as e:
            logger.error(f"查询任务状态异常: {e}")
            return {}

    async def wait_for_completion(self, task_id: str, timeout: int = 300) -> Optional[List[str]]:
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
                for node_id, node_output in outputs.items():
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

    async def get_image_data(self, filename: str) -> Optional[bytes]:
        """获取图片二进制数据."""
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

    async def health_check(self) -> bool:
        """检查ComfyUI服务健康状态."""
        try:
            response = requests.get(f"{self.base_url}/system_stats", timeout=5)
            return response.status_code == 200
        except Exception as e:
            logger.error(f"ComfyUI健康检查失败: {e}")
            return False


def create_comfyui_client_v2() -> ComfyUIClientV2:
    """创建增强版ComfyUI客户端实例."""
    base_url = os.getenv("COMFYUI_API_URL", "http://host.docker.internal:8000")
    workflow_path = os.getenv("COMFYUI_WORKFLOW_PATH", "./comfyui_json/text2img/image_netayume_lumina_t2i.json")

    return ComfyUIClientV2(base_url, workflow_path)