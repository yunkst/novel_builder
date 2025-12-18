"""
人物卡异步任务服务.

提供人物卡图片生成的异步任务管理功能。
"""

import asyncio
import logging
from datetime import datetime

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from ..models.text2img import RoleCardTask, RoleImageGallery
from ..schemas import (
    RoleCardGenerateRequest,
    RoleCardTaskCreateResponse,
    RoleCardTaskStatusResponse,
)
from .role_card_service import role_card_service

logger = logging.getLogger(__name__)


class RoleCardAsyncService:
    """人物卡异步任务服务类."""

    def __init__(self):
        """初始化异步任务服务."""
        self.running_tasks: dict[int, asyncio.Task] = {}
        self.task_lock = asyncio.Lock()

    async def create_task(
        self,
        request: RoleCardGenerateRequest,
        db: Session
    ) -> RoleCardTaskCreateResponse:
        """创建人物卡生成任务.

        Args:
            request: 生成请求
            db: 数据库会话

        Returns:
            任务创建响应
        """
        try:
            # 创建任务记录
            task_record = RoleCardTask(
                role_id=request.role_id,
                status="pending",
                roles=[role.to_dict() for role in request.roles],
                user_input="生成人物卡",
                model=request.model_name,  # 保存模型信息
                total_prompts=0,
                generated_images=0
            )

            db.add(task_record)
            db.commit()
            db.refresh(task_record)

            # 启动后台任务
            await self._start_background_task(task_record.id, request, db)

            logger.info(f"创建人物卡生成任务: {task_record.id}")

            return RoleCardTaskCreateResponse(
                task_id=task_record.id,
                role_id=request.role_id,
                status="pending",
                message="任务创建成功，正在后台处理"
            )

        except SQLAlchemyError as e:
            db.rollback()
            logger.error(f"创建任务数据库操作失败: {e}")
            raise ValueError("创建任务失败")
        except Exception as e:
            logger.error(f"创建任务失败: {e}")
            raise ValueError("创建任务失败")

    async def get_task_status(
        self,
        task_id: int,
        db: Session
    ) -> RoleCardTaskStatusResponse | None:
        """获取任务状态.

        Args:
            task_id: 任务ID
            db: 数据库会话

        Returns:
            任务状态响应
        """
        try:
            task = db.query(RoleCardTask).filter(RoleCardTask.id == task_id).first()
            if not task:
                return None

            # 计算进度百分比
            progress_percentage = self._calculate_progress(task)

            return RoleCardTaskStatusResponse(
                task_id=task.id,
                role_id=task.role_id,
                status=task.status,
                total_prompts=task.total_prompts or 0,
                generated_images=task.generated_images or 0,
                result_message=task.result_message,
                error_message=task.error_message,
                created_at=task.created_at.isoformat(),
                started_at=task.started_at.isoformat() if task.started_at else None,
                completed_at=task.completed_at.isoformat() if task.completed_at else None,
                progress_percentage=progress_percentage
            )

        except Exception as e:
            logger.error(f"获取任务状态失败: {e}")
            return None

    async def _start_background_task(
        self,
        task_id: int,
        request: RoleCardGenerateRequest,
        db: Session
    ) -> None:
        """启动后台处理任务.

        Args:
            task_id: 任务ID
            request: 生成请求
            db: 数据库会话
        """
        async with self.task_lock:
            if task_id in self.running_tasks:
                logger.warning(f"任务 {task_id} 已在运行中")
                return

            # 创建后台任务
            background_task = asyncio.create_task(
                self._process_task_async(task_id, request)
            )
            self.running_tasks[task_id] = background_task

            # 任务完成后清理
            background_task.add_done_callback(
                lambda t: asyncio.create_task(self._cleanup_task(task_id))
            )

    async def _process_task_async(
        self,
        task_id: int,
        request: RoleCardGenerateRequest
    ) -> None:
        """异步处理任务的核心逻辑.

        Args:
            task_id: 任务ID
            request: 生成请求
        """
        from ..database import get_db

        # 获取数据库会话
        db = next(get_db())

        try:
            # 更新任务状态为运行中
            await self._update_task_status(
                db, task_id, "running", started_at=datetime.now()
            )

            logger.info(f"开始处理任务 {task_id}")

            # 1. 调用Dify生成提示词
            logger.info(f"任务 {task_id}: 生成提示词")
            prompts = await role_card_service.dify_client.generate_photo_prompts(
                roles=request.roles
            )

            if not prompts:
                await self._update_task_status(
                    db, task_id, "failed",
                    error_message="未生成任何提示词，请检查角色信息和用户要求",
                    completed_at=datetime.now()
                )
                return

            # 更新提示词数量
            await self._update_task_progress(db, task_id, total_prompts=len(prompts))
            logger.info(f"任务 {task_id}: 生成 {len(prompts)} 个提示词")

            # 2. 根据model参数创建ComfyUI客户端并生成图片
            logger.info(f"任务 {task_id}: 开始生成图片")

            # 获取任务记录中的模型信息
            task = db.query(RoleCardTask).filter(RoleCardTask.id == task_id).first()
            model_name = task.model if task else None

            # 创建对应的ComfyUI客户端
            from ..workflow_config import WorkflowType, workflow_config_manager
            from .comfyui_client import create_comfyui_client_for_model

            if model_name:
                logger.info(f"任务 {task_id}: 使用指定模型 {model_name}")
                comfyui_client = create_comfyui_client_for_model(model_name)
            else:
                default_workflow = workflow_config_manager.get_default_workflow(WorkflowType.T2I)
                logger.info(f"任务 {task_id}: 使用默认模型 {default_workflow.title}")
                comfyui_client = create_comfyui_client_for_model(default_workflow.title)

            # 逐个生成图片（ComfyUIClient只支持单张生成）
            image_filenames = []
            for i, prompt in enumerate(prompts):
                logger.info(f"任务 {task_id}: 生成第 {i+1}/{len(prompts)} 张图片")
                # 首先提交生成任务，获取ComfyUI任务ID
                comfyui_task_id = await comfyui_client.generate_image(prompt)
                if comfyui_task_id:
                    logger.info(f"任务 {task_id}: ComfyUI任务ID {comfyui_task_id}")
                    # 等待任务完成并获取实际图片文件名
                    completed_filenames = await comfyui_client.wait_for_completion(comfyui_task_id)
                    if completed_filenames and len(completed_filenames) > 0:
                        media_file = completed_filenames[0]  # 使用第一个生成的媒体文件
                        filename = media_file.filename  # 获取文件名
                        image_filenames.append(filename)
                        logger.info(f"任务 {task_id}: 第 {i+1} 张图片生成成功，文件名: {filename}")
                    else:
                        logger.warning(f"任务 {task_id}: 第 {i+1} 张图片生成失败（未获取到文件名）")
                else:
                    logger.warning(f"任务 {task_id}: 第 {i+1} 张图片生成失败（提交任务失败）")

            if not image_filenames:
                await self._update_task_status(
                    db, task_id, "failed",
                    error_message="图片生成失败",
                    completed_at=datetime.now()
                )
                return

            logger.info(f"任务 {task_id}: 成功生成 {len(image_filenames)} 张图片")

            # 3. 保存图片信息到数据库
            saved_count = 0
            for i, filename in enumerate(image_filenames):
                try:
                    prompt = prompts[i] if i < len(prompts) else "未知提示词"

                    # 检查是否已存在相同的图片
                    existing_image = db.query(RoleImageGallery).filter(
                        RoleImageGallery.role_id == request.role_id,
                        RoleImageGallery.img_url == filename
                    ).first()

                    if existing_image:
                        logger.warning(f"图片 {filename} 已存在，跳过保存")
                        continue

                    # 保存新图片记录
                    role_image = RoleImageGallery(
                        role_id=request.role_id,
                        img_url=filename,
                        prompt=prompt,
                        created_at=datetime.now()
                    )

                    db.add(role_image)
                    saved_count += 1

                    # 更新进度
                    int((i + 1) / len(image_filenames) * 100)
                    await self._update_task_progress(db, task_id, generated_images=i + 1)

                except Exception as e:
                    logger.error(f"保存图片 {filename} 失败: {e}")
                    continue

            # 提交数据库事务
            db.commit()

            # 4. 更新任务为完成状态
            await self._update_task_status(
                db, task_id, "completed",
                generated_images=saved_count,
                result_message=f"成功生成并保存 {saved_count} 张图片",
                completed_at=datetime.now()
            )

            logger.info(f"任务 {task_id}: 处理完成，生成 {saved_count} 张图片")

        except Exception as e:
            logger.error(f"处理任务 {task_id} 失败: {e}")
            await self._update_task_status(
                db, task_id, "failed",
                error_message=str(e),
                completed_at=datetime.now()
            )
        finally:
            db.close()

    async def _update_task_status(
        self,
        db: Session,
        task_id: int,
        status: str,
        **kwargs
    ) -> None:
        """更新任务状态.

        Args:
            db: 数据库会话
            task_id: 任务ID
            status: 新状态
            **kwargs: 其他要更新的字段
        """
        try:
            task = db.query(RoleCardTask).filter(RoleCardTask.id == task_id).first()
            if task:
                task.status = status
                for key, value in kwargs.items():
                    if hasattr(task, key):
                        setattr(task, key, value)
                db.commit()
        except Exception as e:
            logger.error(f"更新任务状态失败: {e}")

    async def _update_task_progress(
        self,
        db: Session,
        task_id: int,
        **kwargs
    ) -> None:
        """更新任务进度.

        Args:
            db: 数据库会话
            task_id: 任务ID
            **kwargs: 要更新的进度字段
        """
        try:
            task = db.query(RoleCardTask).filter(RoleCardTask.id == task_id).first()
            if task:
                for key, value in kwargs.items():
                    if hasattr(task, key):
                        setattr(task, key, value)
                db.commit()
        except Exception as e:
            logger.error(f"更新任务进度失败: {e}")

    def _calculate_progress(self, task: RoleCardTask) -> float:
        """计算任务进度百分比.

        Args:
            task: 任务对象

        Returns:
            进度百分比 (0-100)
        """
        if task.status == "completed":
            return 100.0
        elif task.status == "failed" or task.status == "pending":
            return 0.0
        elif task.status == "running":
            # 基于提示词和图片生成进度计算
            if task.total_prompts == 0:
                return 10.0  # 提示词生成阶段
            else:
                # 提示词生成完成，图片生成中
                prompt_progress = 30.0  # 提示词阶段占30%
                if task.generated_images and task.generated_images > 0:
                    image_progress = (task.generated_images / max(task.total_prompts, 1)) * 70.0
                    return min(prompt_progress + image_progress, 99.0)
                else:
                    return prompt_progress
        else:
            return 0.0

    async def _cleanup_task(self, task_id: int) -> None:
        """清理已完成的任务.

        Args:
            task_id: 任务ID
        """
        async with self.task_lock:
            if task_id in self.running_tasks:
                del self.running_tasks[task_id]
                logger.info(f"清理任务 {task_id}")

    async def get_running_tasks_count(self) -> int:
        """获取正在运行的任务数量.

        Returns:
            正在运行的任务数量
        """
        async with self.task_lock:
            return len(self.running_tasks)


# 创建全局服务实例
role_card_async_service = RoleCardAsyncService()
