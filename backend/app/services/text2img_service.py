"""
文生图服务.

提供文生图功能的业务逻辑：提交生成任务、查询状态并获取图片。
设计为「提交即返回 task_id + 单接口取图」两步模式,不依赖 Dify。
"""

import logging
from datetime import datetime

import requests
from sqlalchemy.orm import Session

from ..config import settings
from ..constants import CACHE_ONE_DAY
from ..models.text2img import Text2ImgTask
from ..utils.model_validation import validate_and_get_model
from .comfyui_client import create_comfyui_client

logger = logging.getLogger(__name__)


class Text2ImgService:
    """文生图服务类."""

    async def generate(
        self,
        prompt: str,
        model_name: str | None,
        db: Session,
        negative_prompt: str | None = None,
    ) -> str:
        """提交文生图任务,立即返回 task_id(即 ComfyUI prompt_id).

        Args:
            prompt: 图片生成提示词
            model_name: 模型名称(可选)
            db: 数据库会话
            negative_prompt: 负向提示词(可选);工作流未置入对应占位符时由
                ComfyUIClient 静默忽略,不影响生成

        Returns:
            task_id (ComfyUI prompt_id)

        Raises:
            RuntimeError: ComfyUI 提交失败
        """
        model = validate_and_get_model(model_name, "T2I")
        client = create_comfyui_client(model_title=model, workflow_type="t2i")
        prompt_id = await client.generate_image(prompt, negative_prompt)

        if not prompt_id:
            raise RuntimeError("ComfyUI 提交失败")

        task = Text2ImgTask(
            prompt_id=prompt_id,
            prompt=prompt,
            negative_prompt=negative_prompt,
            model_name=model,
            status="pending",
        )
        db.add(task)
        db.commit()

        logger.info(f"文生图任务已提交: task_id={prompt_id}, model={model}")
        return prompt_id

    async def get_image(self, task_id: str, db: Session) -> tuple[bytes | None, int]:
        """根据 task_id 获取图片.

        Args:
            task_id: 任务ID(ComfyUI prompt_id)
            db: 数据库会话

        Returns:
            (data, http_status) 元组:
              - (bytes, 200): 图片二进制数据
              - (None, 202): 仍在生成中
              - (None, 404): 任务不存在或生成失败
        """
        task = db.query(Text2ImgTask).filter(Text2ImgTask.prompt_id == task_id).first()

        if not task:
            return None, 404

        if task.status == "failed":
            return None, 404

        if task.status == "completed" and task.filename:
            data = self._fetch_media(task.filename)
            if data:
                return data, 200
            # ComfyUI 上的文件可能已被清理
            logger.warning(f"图片文件在 ComfyUI 上不存在: {task.filename}")
            return None, 404

        # pending: 查询 ComfyUI history
        client = create_comfyui_client(
            model_title=task.model_name, workflow_type="t2i"
        )
        info = await client.check_task_status(task_id)

        if not info:
            # 还在排队/执行中,history 中暂无记录
            return None, 202

        status_str = info.get("status", {}).get("status_str", "")

        if status_str in ("completed", "success"):
            filename = self._extract_image_filename(info.get("outputs", {}))
            if not filename:
                task.status = "failed"
                task.error_message = "任务完成但未找到图片输出"
                db.commit()
                return None, 404

            task.status = "completed"
            task.filename = filename
            task.completed_at = datetime.now()
            db.commit()

            data = self._fetch_media(filename)
            if data:
                return data, 200
            return None, 404

        if status_str in ("error", "failed"):
            messages = info.get("status", {}).get("messages", [])
            task.status = "failed"
            task.error_message = f"ComfyUI 任务失败: {messages}"
            db.commit()
            return None, 404

        # 仍在运行中
        return None, 202

    def _extract_image_filename(self, outputs: dict) -> str | None:
        """从 ComfyUI outputs 中提取图片文件名.

        遍历所有输出节点,查找含 images 字段的节点,
        取第一个 type != 'temp' 的 filename。

        Args:
            outputs: ComfyUI 任务输出

        Returns:
            图片文件名,未找到返回 None
        """
        for node_output in outputs.values():
            if "images" in node_output:
                for image_info in node_output["images"]:
                    if image_info.get("type") == "temp":
                        continue
                    filename = image_info.get("filename")
                    if filename:
                        return filename
        return None

    def _fetch_media(self, filename: str) -> bytes | None:
        """从 ComfyUI 获取媒体文件二进制数据.

        Args:
            filename: 文件名

        Returns:
            二进制数据,失败返回 None
        """
        try:
            comfyui_url = settings.comfyui_api_url
            url = f"{comfyui_url}/view?filename={filename}"
            response = requests.get(url, timeout=60)
            if response.status_code == 200:
                return response.content
            logger.error(f"从 ComfyUI 获取文件失败: {response.status_code}")
            return None
        except requests.RequestException as e:
            logger.error(f"从 ComfyUI 获取文件异常: {e}")
            return None


# 全局服务实例
text2img_service = Text2ImgService()


def create_text2img_service() -> Text2ImgService:
    """创建文生图服务实例."""
    return text2img_service
