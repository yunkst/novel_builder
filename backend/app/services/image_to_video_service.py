"""
图生视频服务.

本章提供图生视频功能的业务逻辑，包括任务管理、视频生成和状态查询。
"""

import base64
import logging
from datetime import datetime
from typing import Any

from sqlalchemy.orm import Session

from ..models.scene_illustration import SceneImageGallery
from ..models.text2img import ImageToVideoTask, RoleImageGallery
from ..models.video_status import ImageVideoStatus
from ..schemas import (
    ImageToVideoRequest,
    ImageToVideoResponse,
    ImageToVideoTaskStatusResponse,
    VideoStatusResponse,
)
from .comfyui_video_client import create_comfyui_video_client
from .dify_client import create_dify_client
from .http_client import RequestsClient

logger = logging.getLogger(__name__)


class ImageToVideoService:
    """图生视频服务类."""

    def __init__(self):
        """初始化图生视频服务."""
        self.dify_client = create_dify_client()
        self.comfyui_client = create_comfyui_video_client()
        self.http_client = RequestsClient()

    async def create_video_generation_task(self, request: ImageToVideoRequest, db: Session) -> ImageToVideoResponse:
        """创建视频生成任务.

        Args:
            request: 图生视频请求
            db: 数据库会话

        Returns:
            任务创建响应
        """
        try:
            # 1. 检查是否已经有正在进行的视频生成
            video_status = db.query(ImageVideoStatus).filter(
                ImageVideoStatus.img_name == request.img_name
            ).first()

            if video_status and video_status.video_status in ["pending", "running"]:
                logger.info(f"图片 {request.img_name} 正在生成视频，返回现有任务")
                return ImageToVideoResponse(
                    task_id=video_status.current_task_id or 0,
                    img_name=request.img_name,
                    status=video_status.video_status,
                    message="正在生成视频，请稍候"
                )

            # 2. 检查图片是否存在并获取来源信息
            image_record, source_type = self._find_image_record(request.img_name, db)

            if not image_record:
                raise ValueError(f"图片 {request.img_name} 不存在")

            logger.info(f"找到图片 {request.img_name}，来源: {source_type}")

            # 获取可用的图生视频模型和默认模型
            try:
                from ..workflow_config import WorkflowType, workflow_config_manager
                workflows_response = workflow_config_manager.list_workflows(WorkflowType.I2V)
                available_models = [wf.title for wf in workflows_response.workflows]
                default_workflow = workflow_config_manager.get_default_workflow(WorkflowType.I2V)
                default_model = default_workflow.title
            except Exception as e:
                logger.warning(f"获取图生视频模型配置失败，使用默认值: {e}")
                available_models = ["视频生成"]
                default_model = "视频生成"

            # 处理model_name，实现智能默认值替换
            model_name = request.model_name
            if model_name:
                if model_name not in available_models:
                    logger.warning(f"指定的model_name '{model_name}' 不在可用模型列表中，将使用默认模型: {default_model}")
                    model_name = default_model
                else:
                    logger.info(f"使用指定的model_name '{model_name}'")
            else:
                model_name = default_model
                logger.info(f"未指定model_name，使用默认模型: {default_model}")

            # 3. 创建或更新视频状态记录
            if not video_status:
                video_status = ImageVideoStatus(
                    img_name=request.img_name,
                    source_type=source_type,
                    original_prompt=image_record.prompt,
                    has_video=False,
                    video_status="none"
                )
                db.add(video_status)
                db.flush()

            # 4. 创建新的视频生成任务
            video_task = ImageToVideoTask(
                img_name=request.img_name,
                status="pending",
                model_name=model_name,  # 使用处理后的model_name
                user_input=request.user_input
            )
            db.add(video_task)
            db.flush()  # 获取任务ID

            # 5. 更新视频状态为pending
            video_status.video_status = "pending"
            video_status.current_task_id = video_task.id
            video_status.model_name = model_name  # 使用处理后的model_name
            video_status.user_input = request.user_input
            video_status.first_requested_at = datetime.now()
            video_status.retry_count = 0
            video_status.error_message = None

            # 6. 异步处理视频生成
            import asyncio
            try:
                loop = asyncio.get_running_loop()
                loop.create_task(self._process_video_generation_async(
                    task_id=video_task.id,
                    img_name=request.img_name,
                    model_name=model_name,  # 使用处理后的model_name
                    user_input=request.user_input,
                    db=db
                ))
                logger.info(f"异步视频生成任务已创建: {video_task.id}")
            except RuntimeError as e:
                logger.error(f"获取事件循环失败: {e}")
                raise RuntimeError(f"无法创建异步任务: {e!s}")

            db.commit()

            logger.info(f"创建图生视频任务成功: {video_task.id}")

            return ImageToVideoResponse(
                task_id=video_task.id,
                img_name=request.img_name,
                status="pending",
                message="视频生成任务已创建，正在处理中"
            )

        except ValueError as e:
            logger.error(f"创建视频生成任务失败: {e}")
            raise
        except Exception as e:
            logger.error(f"创建视频生成任务异常: {e}")
            db.rollback()
            raise RuntimeError(f"创建任务失败: {e!s}")

    def _find_image_record(self, img_name: str, db: Session) -> tuple:
        """查找图片记录，支持角色卡和场面绘制两种来源.

        Args:
            img_name: 图片名称
            db: 数据库会话

        Returns:
            (image_record, source_type) - 图片记录和来源类型
            source_type: 'role' 或 'scene'
        """
        # 先从角色卡图片表中查找
        image_record = db.query(RoleImageGallery).filter(
            RoleImageGallery.img_url == img_name
        ).first()

        if image_record:
            return image_record, 'role'

        # 再从场面绘制图片表中查找
        image_record = db.query(SceneImageGallery).filter(
            SceneImageGallery.img_url == img_name
        ).first()

        if image_record:
            return image_record, 'scene'

        return None, None

    async def _process_video_generation_async(self, task_id: int, img_name: str, model_name: str,
                                            user_input: str, db: Session) -> None:
        """异步处理视频生成.

        Args:
            task_id: 任务ID
            img_name: 图片名称
            model_name: 模型名称
            user_input: 用户要求
            db: 数据库会话
        """
        try:
            task_db = db

            # 更新任务状态为运行中
            task = task_db.query(ImageToVideoTask).filter(ImageToVideoTask.id == task_id).first()
            if not task:
                logger.error(f"任务 {task_id} 不存在")
                return

            task.status = "running"
            task.started_at = datetime.now()

            # 更新独立状态表为running
            video_status = task_db.query(ImageVideoStatus).filter(
                ImageVideoStatus.img_name == img_name
            ).first()
            if video_status:
                video_status.video_status = "running"
                video_status.current_task_id = task_id

            task_db.commit()

            # 1. 获取图片信息
            image_record, source_type = self._find_image_record(img_name, task_db)

            if not image_record:
                raise ValueError(f"图片 {img_name} 不存在")

            logger.info(f"找到图片 {img_name}，来源: {source_type}")

            # 2. 获取图片的提示词并调用Dify生成视频提示词
            if source_type == 'role':
                original_prompt = image_record.prompt
            else:  # scene
                # 场面绘制的图片，直接使用其prompt字段
                original_prompt = getattr(image_record, 'prompt', '一个美丽的场景')

            logger.info(f"调用Dify生成视频提示词，原始提示词: {original_prompt}")
            video_prompt = await self.dify_client.generate_video_prompts(
                prompts=original_prompt,
                user_input=user_input
            )

            if not video_prompt:
                raise ValueError("Dify生成视频提示词失败")

            # 更新任务的视频提示词
            task.video_prompt = video_prompt
            task_db.commit()

            # 4. 验证图片是否存在（直接使用文件名）
            logger.info(f"使用图片文件名进行视频生成: {img_name}")

            # 5. 调用ComfyUI生成视频
            logger.info(f"调用ComfyUI生成视频，提示词: {video_prompt[:100]}...")
            comfyui_task_id = await self.comfyui_client.generate_video_from_image(
                video_prompt=video_prompt,
                image_filename=img_name
            )

            if not comfyui_task_id:
                raise ValueError("ComfyUI视频生成任务创建失败")

            # 6. 更新独立状态表，存储ComfyUI任务ID，但不等待完成
            video_status = task_db.query(ImageVideoStatus).filter(
                ImageVideoStatus.img_name == img_name
            ).first()
            if video_status:
                video_status.video_prompt = video_prompt
                # 将ComfyUI任务ID存储在自定义字段中
                video_status.error_message = f"comfyui_task_id:{comfyui_task_id}"
                # 保持状态为running，让查询时检查
                video_status.current_task_id = None  # 清理当前任务ID

            # 7. 更新任务状态为已提交
            task.status = "running"  # 表示已提交到ComfyUI，等待查询时检查
            task.video_prompt = video_prompt
            task_db.commit()

            logger.info(f"ComfyUI视频任务已提交，任务ID: {comfyui_task_id}，等待用户查询时检查状态")

        except Exception as e:
            logger.error(f"处理视频生成任务失败: {e}")
            try:
                task.status = "failed"
                task.error_message = str(e)
                task.completed_at = datetime.now()

                # 更新独立状态表为失败
                video_status = task_db.query(ImageVideoStatus).filter(
                    ImageVideoStatus.img_name == img_name
                ).first()
                if video_status:
                    video_status.video_status = "failed"
                    video_status.error_message = str(e)
                    video_status.retry_count += 1
                    video_status.current_task_id = None

                task_db.commit()
            except Exception:
                pass

        finally:
            task_db.close()

    async def _get_image_base64(self, img_name: str) -> str | None:
        """获取图片的base64编码.

        Args:
            img_name: 图片名称

        Returns:
            图片base64编码，失败时返回None
        """
        try:
            # 使用同步requests获取图片数据，和图片代理接口相同的方式
            import os

            import requests

            comfyui_url = os.getenv("COMFYUI_API_URL", "http://host.docker.internal:8000")
            image_url = f"{comfyui_url}/view?filename={img_name}"

            response = requests.get(image_url, timeout=30)
            if response.status_code == 200:
                image_data = response.content
                # 转换为base64
                image_base64 = base64.b64encode(image_data).decode('utf-8')
                logger.info(f"成功获取图片 {img_name} 的base64数据，大小: {len(image_data)} bytes")
                return image_base64
            else:
                logger.error(f"获取图片失败: {response.status_code}")
                return None

        except Exception as e:
            logger.error(f"获取图片base64数据异常: {e}")
            return None

    async def get_video_status(self, img_name: str, db: Session) -> VideoStatusResponse:
        """查询图片是否有视频.

        Args:
            img_name: 图片名称
            db: 数据库会话

        Returns:
            视频状态响应
        """
        try:
            # 查询独立的视频状态表
            video_status = db.query(ImageVideoStatus).filter(
                ImageVideoStatus.img_name == img_name
            ).first()

            if not video_status:
                return VideoStatusResponse(
                    img_name=img_name,
                    has_video=False,
                    video_status="none"
                )

            # 如果状态已完成或失败，直接返回
            if video_status.video_status in ["completed", "failed", "none"]:
                return VideoStatusResponse(
                    img_name=img_name,
                    has_video=video_status.has_video and video_status.video_filename is not None,
                    video_status=video_status.video_status,
                    video_filename=video_status.video_filename
                )

            # 如果状态是pending或running，需要检查ComfyUI状态
            if video_status.video_status in ["pending", "running"]:
                logger.info(f"图片 {img_name} 状态为 {video_status.video_status}，开始检查ComfyUI状态")
                await self._check_and_update_video_status(video_status, db)
                # 重新查询更新后的状态
                db.refresh(video_status)

            # 返回最终状态
            return VideoStatusResponse(
                img_name=img_name,
                has_video=video_status.has_video and video_status.video_filename is not None,
                video_status=video_status.video_status,
                video_filename=video_status.video_filename
            )

        except Exception as e:
            logger.error(f"查询视频状态失败: {e}")
            raise RuntimeError(f"查询视频状态失败: {e!s}")

    async def _check_and_update_video_status(self, video_status: ImageVideoStatus, db: Session) -> None:
        """检查并更新视频状态.

        Args:
            video_status: 视频状态记录
            db: 数据库会话
        """
        try:
            # 从error_message中提取ComfyUI任务ID
            comfyui_task_id = None
            if video_status.error_message and video_status.error_message.startswith("comfyui_task_id:"):
                comfyui_task_id = video_status.error_message.replace("comfyui_task_id:", "").strip()

            if not comfyui_task_id:
                logger.error(f"找不到ComfyUI任务ID，无法检查状态: {video_status.img_name}")
                return

            logger.info(f"开始检查ComfyUI任务状态: {comfyui_task_id}")

            # 等待视频生成完成（1小时超时）
            video_info = await self.comfyui_client.wait_for_video_completion(
                task_id=comfyui_task_id,
                timeout=3600  # 1小时超时
            )

            if video_info:
                # 解析文件名和subfolder
                if "|" in video_info:
                    filename, subfolder = video_info.split("|", 1)
                    video_filename = f"{subfolder}/{filename}"  # 保存为完整路径
                else:
                    video_filename = video_info

                # 视频生成成功
                video_status.has_video = True
                video_status.video_status = "completed"
                video_status.video_filename = video_filename
                video_status.video_completed_at = datetime.now()
                video_status.error_message = None
                logger.info(f"视频生成成功: {video_status.img_name} -> {video_filename}")
            else:
                # 视频生成失败或超时
                video_status.video_status = "failed"
                video_status.error_message = "ComfyUI视频生成失败或超时"
                video_status.retry_count += 1
                logger.error(f"视频生成失败: {video_status.img_name}")

            db.commit()

        except Exception as e:
            logger.error(f"检查视频状态异常: {e}")
            video_status.video_status = "failed"
            video_status.error_message = f"状态检查异常: {e!s}"
            video_status.retry_count += 1
            db.commit()

    async def get_video_file(self, img_name: str, db: Session) -> bytes | None:
        """获取视频文件二进制数据.

        Args:
            img_name: 图片名称
            db: 数据库会话

        Returns:
            视频文件二进制数据，失败时返回None
        """
        try:
            # 查询视频状态记录
            video_status = db.query(ImageVideoStatus).filter(
                ImageVideoStatus.img_name == img_name
            ).first()

            if not video_status or not video_status.video_filename:
                raise ValueError(f"图片 {img_name} 没有对应的视频文件")

            # 从ComfyUI获取视频数据
            # 解析文件名和subfolder
            if "/" in video_status.video_filename:
                subfolder, filename = video_status.video_filename.split("/", 1)
                video_data = await self.comfyui_client.get_video_data(filename, subfolder)
            else:
                video_data = await self.comfyui_client.get_video_data(video_status.video_filename)
            if not video_data:
                raise ValueError(f"获取视频文件 {video_status.video_filename} 失败")

            logger.info(f"成功获取视频文件 {video_status.video_filename}，大小: {len(video_data)} bytes")
            return video_data

        except ValueError as e:
            logger.error(f"获取视频文件失败: {e}")
            raise
        except Exception as e:
            logger.error(f"获取视频文件异常: {e}")
            raise RuntimeError(f"获取视频文件失败: {e!s}")

    async def get_task_status(self, task_id: int, db: Session) -> ImageToVideoTaskStatusResponse | None:
        """查询视频生成任务状态.

        Args:
            task_id: 任务ID
            db: 数据库会话

        Returns:
            任务状态响应，任务不存在时返回None
        """
        try:
            task = db.query(ImageToVideoTask).filter(ImageToVideoTask.id == task_id).first()
            if not task:
                return None

            return ImageToVideoTaskStatusResponse(
                task_id=task.id,
                img_name=task.img_name,
                status=task.status,
                model_name=task.model_name,
                user_input=task.user_input,
                video_prompt=task.video_prompt,
                video_filename=task.video_filename,
                result_message=task.result_message,
                error_message=task.error_message,
                created_at=task.created_at.isoformat() if task.created_at else "",
                started_at=task.started_at.isoformat() if task.started_at else None,
                completed_at=task.completed_at.isoformat() if task.completed_at else None
            )

        except Exception as e:
            logger.error(f"查询任务状态失败: {e}")
            raise RuntimeError(f"查询任务状态失败: {e!s}")

    async def health_check(self) -> dict[str, Any]:
        """健康检查.

        Returns:
            健康状态信息
        """
        # 只检查ComfyUI服务
        comfyui_healthy = await self.comfyui_client.health_check()

        return {
            "status": "healthy" if comfyui_healthy else "unhealthy",
            "services": {
                "comfyui": comfyui_healthy
            }
        }


# 创建全局服务实例
image_to_video_service = ImageToVideoService()


def create_image_to_video_service() -> ImageToVideoService:
    """创建图生视频服务实例."""
    return image_to_video_service
