"""
图生视频服务.

本章提供图生视频功能的业务逻辑，包括任务管理、视频生成和状态查询。
"""

import logging
import base64
from datetime import datetime
from typing import Optional, Dict, Any

from sqlalchemy.orm import Session

from ..models.text2img import RoleImageGallery, ImageToVideoTask
from ..schemas import ImageToVideoRequest, ImageToVideoResponse, VideoStatusResponse, ImageToVideoTaskStatusResponse
from .dify_client import create_dify_client
from .comfyui_video_client import create_comfyui_video_client
from .http_client import HTTPClient

logger = logging.getLogger(__name__)


class ImageToVideoService:
    """图生视频服务类."""

    def __init__(self):
        """初始化图生视频服务."""
        self.dify_client = create_dify_client()
        self.comfyui_client = create_comfyui_video_client()
        self.http_client = HTTPClient()

    async def create_video_generation_task(self, request: ImageToVideoRequest, db: Session) -> ImageToVideoResponse:
        """创建视频生成任务.

        Args:
            request: 图生视频请求
            db: 数据库会话

        Returns:
            任务创建响应
        """
        try:
            # 1. 检查图片是否正在生成视频
            existing_task = db.query(ImageToVideoTask).filter(
                ImageToVideoTask.img_name == request.img_name,
                ImageToVideoTask.status.in_(["pending", "running"])
            ).first()

            if existing_task:
                logger.info(f"图片 {request.img_name} 正在生成视频，返回现有任务")
                return ImageToVideoResponse(
                    task_id=existing_task.id,
                    img_name=request.img_name,
                    status=existing_task.status,
                    message="正在生成视频，请稍候"
                )

            # 2. 检查图片是否存在并获取提示词
            image_record = db.query(RoleImageGallery).filter(
                RoleImageGallery.img_url == request.img_name
            ).first()

            if not image_record:
                raise ValueError(f"图片 {request.img_name} 不存在")

            # 3. 创建新的视频生成任务
            video_task = ImageToVideoTask(
                img_name=request.img_name,
                status="pending",
                model_name=request.model_name,
                user_input=request.user_input
            )
            db.add(video_task)
            db.flush()  # 获取任务ID

            # 4. 异步处理视频生成
            import asyncio
            asyncio.create_task(self._process_video_generation_async(
                task_id=video_task.id,
                img_name=request.img_name,
                model_name=request.model_name,
                user_input=request.user_input,
                db=db
            ))

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
            raise RuntimeError(f"创建任务失败: {str(e)}")

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
            # 使用新的会话
            with db.get_bind().connect() as conn:
                from sqlalchemy.orm import sessionmaker
                Session = sessionmaker(bind=conn)
                task_db = Session()

            # 更新任务状态为运行中
            task = task_db.query(ImageToVideoTask).filter(ImageToVideoTask.id == task_id).first()
            if not task:
                logger.error(f"任务 {task_id} 不存在")
                return

            task.status = "running"
            task.started_at = datetime.now()
            task_db.commit()

            # 1. 获取图片信息
            image_record = task_db.query(RoleImageGallery).filter(
                RoleImageGallery.img_url == img_name
            ).first()

            if not image_record:
                raise ValueError(f"图片 {img_name} 不存在")

            # 2. 检查并更新图片的视频状态
            if image_record.video_status in ["pending", "running"]:
                logger.info(f"图片 {img_name} 正在生成视频，跳过处理")
                return

            # 3. 调用Dify生成视频提示词
            logger.info(f"调用Dify生成视频提示词，原始提示词: {image_record.prompt}")
            video_prompt = await self.dify_client.generate_video_prompts(
                prompts=image_record.prompt,
                user_input=user_input
            )

            if not video_prompt:
                raise ValueError("Dify生成视频提示词失败")

            # 更新任务的视频提示词
            task.video_prompt = video_prompt
            task_db.commit()

            # 4. 获取图片base64数据
            image_base64 = await self._get_image_base64(img_name)
            if not image_base64:
                raise ValueError(f"获取图片 {img_name} 的base64数据失败")

            # 5. 调用ComfyUI生成视频
            logger.info(f"调用ComfyUI生成视频，提示词: {video_prompt[:100]}...")
            comfyui_task_id = await self.comfyui_client.generate_video_from_image(
                video_prompt=video_prompt,
                image_base64=image_base64
            )

            if not comfyui_task_id:
                raise ValueError("ComfyUI视频生成任务创建失败")

            # 6. 等待视频生成完成
            logger.info(f"等待ComfyUI视频生成完成，任务ID: {comfyui_task_id}")
            video_filename = await self.comfyui_client.wait_for_video_completion(
                task_id=comfyui_task_id,
                timeout=600  # 10分钟超时
            )

            if not video_filename:
                raise ValueError("ComfyUI视频生成失败或超时")

            # 7. 更新任务状态为完成
            task.status = "completed"
            task.video_filename = video_filename
            task.result_message = "视频生成成功"
            task.completed_at = datetime.now()
            task_db.commit()

            # 8. 更新图片记录的视频信息
            image_record.video_status = "completed"
            image_record.video_filename = video_filename
            image_record.video_prompt = video_prompt
            image_record.video_created_at = datetime.now()
            task_db.commit()

            logger.info(f"视频生成完成: {video_filename}")

        except Exception as e:
            logger.error(f"处理视频生成任务失败: {e}")
            try:
                task.status = "failed"
                task.error_message = str(e)
                task.completed_at = datetime.now()
                task_db.commit()

                # 更新图片记录状态
                if image_record:
                    image_record.video_status = "failed"
                    task_db.commit()
            except:
                pass

        finally:
            task_db.close()

    async def _get_image_base64(self, img_name: str) -> Optional[str]:
        """获取图片的base64编码.

        Args:
            img_name: 图片名称

        Returns:
            图片base64编码，失败时返回None
        """
        try:
            # 从ComfyUI获取图片数据
            comfyui_url = "http://host.docker.internal:8000"
            image_url = f"{comfyui_url}/view?filename={img_name}"

            response = await self.http_client.get_async(image_url, timeout=30)
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
            # 查询图片记录
            image_record = db.query(RoleImageGallery).filter(
                RoleImageGallery.img_url == img_name
            ).first()

            if not image_record:
                return VideoStatusResponse(
                    img_name=img_name,
                    has_video=False,
                    video_status="none"
                )

            has_video = image_record.video_status == "completed" and image_record.video_filename

            return VideoStatusResponse(
                img_name=img_name,
                has_video=has_video,
                video_status=image_record.video_status,
                video_filename=image_record.video_filename
            )

        except Exception as e:
            logger.error(f"查询视频状态失败: {e}")
            raise RuntimeError(f"查询视频状态失败: {str(e)}")

    async def get_video_file(self, img_name: str, db: Session) -> Optional[bytes]:
        """获取视频文件二进制数据.

        Args:
            img_name: 图片名称
            db: 数据库会话

        Returns:
            视频文件二进制数据，失败时返回None
        """
        try:
            # 查询图片记录
            image_record = db.query(RoleImageGallery).filter(
                RoleImageGallery.img_url == img_name
            ).first()

            if not image_record or not image_record.video_filename:
                raise ValueError(f"图片 {img_name} 没有对应的视频文件")

            # 从ComfyUI获取视频数据
            video_data = await self.comfyui_client.get_video_data(image_record.video_filename)
            if not video_data:
                raise ValueError(f"获取视频文件 {image_record.video_filename} 失败")

            logger.info(f"成功获取视频文件 {image_record.video_filename}，大小: {len(video_data)} bytes")
            return video_data

        except ValueError as e:
            logger.error(f"获取视频文件失败: {e}")
            raise
        except Exception as e:
            logger.error(f"获取视频文件异常: {e}")
            raise RuntimeError(f"获取视频文件失败: {str(e)}")

    async def get_task_status(self, task_id: int, db: Session) -> Optional[ImageToVideoTaskStatusResponse]:
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
            raise RuntimeError(f"查询任务状态失败: {str(e)}")

    async def health_check(self) -> Dict[str, Any]:
        """健康检查.

        Returns:
            健康状态信息
        """
        dify_healthy = await self.dify_client.health_check()
        comfyui_healthy = await self.comfyui_client.health_check()

        return {
            "status": "healthy" if dify_healthy and comfyui_healthy else "unhealthy",
            "services": {
                "dify": dify_healthy,
                "comfyui": comfyui_healthy
            }
        }


# 创建全局服务实例
image_to_video_service = ImageToVideoService()


def create_image_to_video_service() -> ImageToVideoService:
    """创建图生视频服务实例."""
    return image_to_video_service