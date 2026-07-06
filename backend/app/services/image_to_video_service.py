"""
图生视频服务.

提供图生视频功能的业务逻辑：提交生成任务、查询状态并获取视频。
设计为「提交即返回 task_id + 单接口取视频」两步模式,不依赖 Dify。
"""

import logging
from datetime import datetime

import requests
from sqlalchemy.orm import Session

from ..config import settings
from ..models.text2img import ImageToVideoTask
from ..utils.model_validation import validate_and_get_model
from .comfyui_client import create_comfyui_client

logger = logging.getLogger(__name__)


class ImageToVideoService:
    """图生视频服务类."""

    async def generate(
        self,
        prompt: str,
        model_name: str | None,
        image_bytes: bytes,
        image_filename: str,
        db: Session,
    ) -> str:
        """提交图生视频任务,立即返回 task_id(即 ComfyUI prompt_id).

        Args:
            prompt: 视频生成提示词
            model_name: 模型名称(可选)
            image_bytes: 上传图片的二进制数据
            image_filename: 上传图片的文件名
            db: 数据库会话

        Returns:
            task_id (ComfyUI prompt_id)

        Raises:
            RuntimeError: ComfyUI 提交失败
        """
        model = validate_and_get_model(model_name, "I2V")
        client = create_comfyui_client(model_title=model, workflow_type="i2v")
        prompt_id = await client.generate_video(prompt, image_bytes, image_filename)

        if not prompt_id:
            raise RuntimeError("ComfyUI 提交失败")

        task = ImageToVideoTask(
            prompt_id=prompt_id,
            prompt=prompt,
            model_name=model,
            image_filename=image_filename,
            status="pending",
        )
        db.add(task)
        db.commit()

        logger.info(f"图生视频任务已提交: task_id={prompt_id}, model={model}")
        return prompt_id

    async def get_video(self, task_id: str, db: Session) -> tuple[bytes | None, int]:
        """根据 task_id 获取视频.

        Args:
            task_id: 任务ID(ComfyUI prompt_id)
            db: 数据库会话

        Returns:
            (data, http_status) 元组:
              - (bytes, 200): 视频二进制数据
              - (None, 202): 仍在生成中
              - (None, 404): 任务不存在或生成失败
        """
        task = (
            db.query(ImageToVideoTask)
            .filter(ImageToVideoTask.prompt_id == task_id)
            .first()
        )

        if not task:
            return None, 404

        if task.status == "failed":
            return None, 404

        if task.status == "completed" and task.video_filename:
            data = self._fetch_video(task.video_filename)
            if data:
                return data, 200
            logger.warning(f"视频文件在 ComfyUI 上不存在: {task.video_filename}")
            return None, 404

        # pending: 查询 ComfyUI history
        client = create_comfyui_client(
            model_title=task.model_name, workflow_type="i2v"
        )
        info = await client.check_task_status(task_id)

        if not info:
            return None, 202

        status_str = info.get("status", {}).get("status_str", "")

        if status_str in ("completed", "success"):
            video_filename = self._extract_video_filename(info.get("outputs", {}))
            if not video_filename:
                task.status = "failed"
                task.error_message = "任务完成但未找到视频输出"
                db.commit()
                return None, 404

            task.status = "completed"
            task.video_filename = video_filename
            task.completed_at = datetime.now()
            db.commit()

            data = self._fetch_video(video_filename)
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

    def _extract_video_filename(self, outputs: dict) -> str | None:
        """从 ComfyUI outputs 中提取视频文件名.

        策略:
        1. 优先查找 _meta.class_type 含 VideoCombine/Video 的节点
        2. 按文件扩展名(.mp4/.gif/.webm 等)过滤
        3. 跳过 type=='temp' 的临时文件
        4. 返回 subfolder/filename 完整路径(如有 subfolder)

        Args:
            outputs: ComfyUI 任务输出

        Returns:
            视频文件路径,未找到返回 None
        """
        video_extensions = {
            ".gif", ".mp4", ".webm", ".mkv", ".avi", ".mov", ".flv", ".wmv"
        }

        # 第一优先级: 查找视频合成节点
        for node_id, node_output in outputs.items():
            if "_meta" in node_output:
                class_type = node_output.get("_meta", {}).get("class_type", "")
                if "VideoCombine" in class_type or "Video" in class_type:
                    for field_name in ("gifs", "videos", "images"):
                        if field_name in node_output:
                            files = node_output[field_name]
                            if isinstance(files, list) and len(files) > 0:
                                file_info = files[0]
                                filename = file_info.get("filename")
                                subfolder = file_info.get("subfolder", "")
                                if filename and file_info.get("type") != "temp":
                                    subfolder = subfolder.replace("\\", "/") if subfolder else ""
                                    return (
                                        f"{subfolder}/{filename}"
                                        if subfolder
                                        else filename
                                    )

        # 第二优先级: 按扩展名遍历所有节点
        for node_output in outputs.values():
            for field_name in ("gifs", "videos", "images"):
                if field_name not in node_output:
                    continue
                files = node_output[field_name]
                if not isinstance(files, list):
                    continue
                for file_info in files:
                    filename = file_info.get("filename", "")
                    if not filename or file_info.get("type") == "temp":
                        continue
                    file_ext = (
                        f".{filename.rsplit('.', 1)[-1].lower()}" if "." in filename else ""
                    )
                    if file_ext in video_extensions:
                        subfolder = file_info.get("subfolder", "")
                        subfolder = subfolder.replace("\\", "/") if subfolder else ""
                        return f"{subfolder}/{filename}" if subfolder else filename

        return None

    def _fetch_video(self, video_filename: str) -> bytes | None:
        """从 ComfyUI 获取视频二进制数据.

        Args:
            video_filename: 视频文件路径(可能含 subfolder/filename)

        Returns:
            二进制数据,失败返回 None
        """
        try:
            comfyui_url = settings.comfyui_api_url
            # 解析 filename 和 subfolder
            if "/" in video_filename:
                path_parts = video_filename.split("/")
                filename = path_parts[-1]
                subfolder = "/".join(path_parts[:-1])
                url = f"{comfyui_url}/api/view?filename={filename}&type=output&subfolder={subfolder}"
            else:
                url = f"{comfyui_url}/api/view?filename={video_filename}&type=output"

            response = requests.get(url, timeout=120)
            if response.status_code == 200:
                logger.info(
                    f"成功获取视频: {video_filename}, 大小: {len(response.content)} bytes"
                )
                return response.content
            logger.error(f"从 ComfyUI 获取视频失败: {response.status_code}")
            return None
        except requests.RequestException as e:
            logger.error(f"从 ComfyUI 获取视频异常: {e}")
            return None

    async def health_check(self) -> dict[str, bool]:
        """健康检查."""
        try:
            comfyui_url = settings.comfyui_api_url
            response = requests.get(f"{comfyui_url}/system_stats", timeout=5)
            return {"comfyui": response.status_code == 200}
        except requests.RequestException:
            return {"comfyui": False}


# 全局服务实例
image_to_video_service = ImageToVideoService()


def create_image_to_video_service() -> ImageToVideoService:
    """创建图生视频服务实例."""
    return image_to_video_service
