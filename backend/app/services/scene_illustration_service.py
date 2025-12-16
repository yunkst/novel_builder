"""
场面绘制服务.

提供场面绘制的核心业务逻辑，包括任务管理、图片生成和结果存储。
"""

import logging
from datetime import datetime
from typing import Dict, Any, Optional, List
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from ..models.scene_illustration import SceneIllustrationTask, SceneImageGallery
from ..schemas import (
    SceneIllustrationRequest, SceneIllustrationResponse,
    SceneGalleryResponse, SceneImageDeleteRequest,
    EnhancedSceneIllustrationRequest, RoleInfo,
    SceneRegenerateRequest, SceneRegenerateResponse
)
from .dify_client import DifyClient
from .comfyui_client import create_comfyui_client_for_model, MediaFileResult

logger = logging.getLogger(__name__)


class SceneIllustrationService:
    """场面绘制服务类."""

    def __init__(self, dify_client: DifyClient):
        """初始化场面绘制服务.

        Args:
            dify_client: Dify客户端实例
        """
        self.dify_client = dify_client

    def _restore_roles_from_json(self, roles_json: str) -> Dict[str, Any]:
        """从JSON字符串恢复角色数据为字典格式

        Args:
            roles_json: 数据库中存储的JSON字符串

        Returns:
            角色信息字典，用于Dify客户端
        """
        if not roles_json or roles_json.strip() == "":
            return {}

        try:
            import json
            roles_data = json.loads(roles_json)

            # 如果是列表格式（新版本存储）
            if isinstance(roles_data, list):
                roles_dict = {}
                for role_data in roles_data:
                    if isinstance(role_data, dict) and 'name' in role_data:
                        # 重建RoleInfo对象以获取简单描述
                        role_info = RoleInfo.from_dict(role_data)
                        roles_dict[role_info.name] = role_info.to_simple_description()
                return roles_dict

            # 如果已经是字典格式（旧版本兼容）
            elif isinstance(roles_data, dict):
                return roles_data

            return {}

        except (json.JSONDecodeError, TypeError, Exception) as e:
            logger.error(f"解析角色数据失败: {e}")
            return {}

    async def generate_scene_images(
        self,
        request: EnhancedSceneIllustrationRequest,
        db: Session
    ) -> SceneIllustrationResponse:
        """生成场面图片.

        Args:
            request: 场面绘制请求
            db: 数据库会话

        Returns:
            任务创建响应

        Raises:
            ValueError: 当请求参数无效时
        """
        try:
            # 检查是否已存在相同task_id的任务
            existing_task = db.query(SceneIllustrationTask).filter(
                SceneIllustrationTask.task_id == request.task_id
            ).first()

            if existing_task:
                if existing_task.status in ["pending", "running"]:
                    return SceneIllustrationResponse(
                        task_id=request.task_id,
                        status=existing_task.status,
                        message="任务已存在，正在处理中"
                    )
                else:
                    # 删除已完成的任务数据，重新创建
                    db.query(SceneImageGallery).filter(
                        SceneImageGallery.task_id == request.task_id
                    ).delete()
                    db.delete(existing_task)
                    db.commit()

            # 创建任务记录 - 使用序列化后的JSON
            task_record = SceneIllustrationTask(
                task_id=request.task_id,
                status="pending",
                chapters_content=request.chapters_content,
                roles=request.to_roles_json(),  # 使用JSON字符串存储
                num=request.num,
                model_name=request.model_name,
                generated_images=0
            )

            db.add(task_record)
            db.commit()
            db.refresh(task_record)

            logger.info(f"创建场面绘制任务: {request.task_id}")

            # 启动异步任务处理
            import asyncio
            asyncio.create_task(self.process_scene_task(request.task_id, db))

            return SceneIllustrationResponse(
                task_id=request.task_id,
                status="pending",
                message="任务创建成功，正在处理"
            )

        except SQLAlchemyError as e:
            db.rollback()
            logger.error(f"创建任务数据库操作失败: {e}")
            raise ValueError("创建任务失败")
        except Exception as e:
            logger.error(f"创建任务失败: {e}")
            raise ValueError("创建任务失败")

    async def get_scene_gallery(
        self,
        task_id: str,
        db: Session
    ) -> SceneGalleryResponse:
        """获取场面图片列表.

        Args:
            task_id: 任务标识符
            db: 数据库会话

        Returns:
            图片列表响应

        Raises:
            ValueError: 当任务不存在时
        """
        try:
            # 检查任务是否存在
            task = db.query(SceneIllustrationTask).filter(
                SceneIllustrationTask.task_id == task_id
            ).first()

            if not task:
                raise ValueError("任务不存在")

            # 获取图片列表
            images = db.query(SceneImageGallery).filter(
                SceneImageGallery.task_id == task_id
            ).order_by(SceneImageGallery.created_at).all()

            image_list = [img.img_url for img in images]

            return SceneGalleryResponse(
                task_id=task_id,
                images=image_list
            )

        except SQLAlchemyError as e:
            logger.error(f"获取图片列表数据库操作失败: {e}")
            raise ValueError("获取图片列表失败")
        except Exception as e:
            logger.error(f"获取图片列表失败: {e}")
            raise ValueError("获取图片列表失败")

    async def delete_scene_image(
        self,
        request: SceneImageDeleteRequest,
        db: Session
    ) -> bool:
        """删除场面图片.

        Args:
            request: 删除图片请求
            db: 数据库会话

        Returns:
            删除是否成功

        Raises:
            ValueError: 当参数无效时
        """
        try:
            # 检查任务是否存在
            task = db.query(SceneIllustrationTask).filter(
                SceneIllustrationTask.task_id == request.task_id
            ).first()

            if not task:
                raise ValueError("任务不存在")

            # 删除指定图片
            deleted_count = db.query(SceneImageGallery).filter(
                SceneImageGallery.task_id == request.task_id,
                SceneImageGallery.img_url == request.filename
            ).delete()

            if deleted_count == 0:
                raise ValueError("图片不存在")

            db.commit()
            logger.info(f"删除场面图片成功: {request.task_id}/{request.filename}")
            return True

        except SQLAlchemyError as e:
            db.rollback()
            logger.error(f"删除图片数据库操作失败: {e}")
            raise ValueError("删除图片失败")
        except Exception as e:
            logger.error(f"删除图片失败: {e}")
            raise ValueError("删除图片失败")

    async def process_scene_task(
        self,
        task_id: str,
        db: Session
    ) -> bool:
        """处理场面绘制任务（异步处理逻辑）.

        Args:
            task_id: 任务标识符
            db: 数据库会话

        Returns:
            处理是否成功
        """
        try:
            # 获取任务记录
            task = db.query(SceneIllustrationTask).filter(
                SceneIllustrationTask.task_id == task_id
            ).first()

            if not task:
                logger.error(f"任务不存在: {task_id}")
                return False

            # 更新任务状态为运行中
            task.status = "running"
            task.started_at = datetime.now()
            db.commit()

            # 1. 调用Dify生成提示词
            logger.info(f"任务 {task_id}: 生成场面绘制提示词")
            # 恢复角色数据为字典格式
            roles_dict = self._restore_roles_from_json(task.roles)
            prompts = await self.dify_client.generate_scene_prompts(
                chapters_content=task.chapters_content,
                roles=roles_dict
            )

            if not prompts:
                await self._update_task_status(
                    db, task, "failed",
                    error_message="未生成任何提示词，请检查章节内容和角色信息"
                )
                return False

            # 更新提示词
            task.prompts = prompts
            db.commit()
            logger.info(f"任务 {task_id}: 生成提示词成功")

            # 2. 创建ComfyUI客户端并生成图片
            logger.info(f"任务 {task_id}: 开始生成图片")

            # 获取对应的ComfyUI客户端
            if task.model_name:
                logger.info(f"任务 {task_id}: 使用指定模型 {task.model_name}")
                comfyui_client = create_comfyui_client_for_model(task.model_name)
            else:
                from ..workflow_config.workflow_config import workflow_config_manager
                default_workflow = workflow_config_manager.get_default_t2i_workflow()
                logger.info(f"任务 {task_id}: 使用默认模型 {default_workflow.title}")
                comfyui_client = create_comfyui_client_for_model(default_workflow.title)

            # 生成指定数量的图片
            image_filenames = []
            for i in range(task.num):
                logger.info(f"任务 {task_id}: 生成第 {i+1}/{task.num} 张图片")

                # 提交生成任务
                comfyui_task_id = await comfyui_client.generate_image(prompts)
                if comfyui_task_id:
                    logger.info(f"任务 {task_id}: ComfyUI任务ID {comfyui_task_id}")

                    # 等待任务完成并获取图片文件名
                    completed_filenames = await comfyui_client.wait_for_completion(comfyui_task_id)
                    if completed_filenames and len(completed_filenames) > 0:
                        media_file = completed_filenames[0]  # 使用第一个生成的图片
                        filename = media_file.filename  # 获取文件名
                        image_filenames.append(filename)
                        logger.info(f"任务 {task_id}: 第 {i+1} 张图片生成成功，文件名: {filename}")
                    else:
                        logger.warning(f"任务 {task_id}: 第 {i+1} 张图片生成失败")
                else:
                    logger.warning(f"任务 {task_id}: 第 {i+1} 张图片生成失败（提交任务失败）")

            if not image_filenames:
                await self._update_task_status(
                    db, task, "failed",
                    error_message="图片生成失败"
                )
                return False

            logger.info(f"任务 {task_id}: 成功生成 {len(image_filenames)} 张图片")

            # 3. 保存图片信息到数据库
            saved_count = 0
            for filename in image_filenames:
                try:
                    # 检查是否已存在相同的图片
                    existing_image = db.query(SceneImageGallery).filter(
                        SceneImageGallery.task_id == task.task_id,
                        SceneImageGallery.img_url == filename
                    ).first()

                    if existing_image:
                        logger.warning(f"图片 {filename} 已存在，跳过保存")
                        continue

                    # 保存新图片记录
                    scene_image = SceneImageGallery(
                        task_id=task.task_id,
                        img_url=filename,
                        prompt=prompts,
                        created_at=datetime.now()
                    )

                    db.add(scene_image)
                    saved_count += 1

                except Exception as e:
                    logger.error(f"保存图片 {filename} 失败: {e}")
                    continue

            # 提交数据库事务
            db.commit()

            # 4. 更新任务为完成状态
            await self._update_task_status(
                db, task, "completed",
                generated_images=saved_count,
                result_message=f"成功生成并保存 {saved_count} 张图片"
            )

            logger.info(f"任务 {task_id}: 处理完成，生成 {saved_count} 张图片")
            return True

        except Exception as e:
            logger.error(f"处理任务 {task_id} 失败: {e}")
            if 'task' in locals():
                await self._update_task_status(
                    db, task, "failed",
                    error_message=str(e)
                )
            return False

    async def _update_task_status(
        self,
        db: Session,
        task: SceneIllustrationTask,
        status: str,
        **kwargs
    ) -> None:
        """更新任务状态.

        Args:
            db: 数据库会话
            task: 任务对象
            status: 新状态
            **kwargs: 其他要更新的字段
        """
        try:
            task.status = status
            for key, value in kwargs.items():
                if hasattr(task, key):
                    setattr(task, key, value)
            db.commit()
        except Exception as e:
            logger.error(f"更新任务状态失败: {e}")

    async def regenerate_scene_images(
        self,
        request: SceneRegenerateRequest,
        db: Session
    ) -> SceneRegenerateResponse:
        """基于现有任务重新生成场面图片

        Args:
            request: 重新生成请求
            db: 数据库会话

        Returns:
            生成响应

        Raises:
            ValueError: 当任务不存在或参数无效时
        """
        try:
            # 1. 查找原始任务
            original_task = db.query(SceneIllustrationTask).filter(
                SceneIllustrationTask.task_id == request.task_id
            ).first()

            if not original_task:
                raise ValueError("原始任务不存在")

            if original_task.status != "completed":
                raise ValueError("只能基于已完成的任务重新生成图片")

            # 2. 获取原始任务的提示词
            original_prompt = original_task.prompts
            if not original_prompt:
                raise ValueError("原始任务的提示词不存在")

            logger.info(f"基于任务 {request.task_id} 重新生成 {request.count} 张图片")

            # 3. 创建ComfyUI客户端
            if request.model:
                logger.info(f"使用指定模型重新生成图片: {request.model}")
                comfyui_client = create_comfyui_client_for_model(request.model)
            elif original_task.model_name:
                logger.info(f"使用原始任务模型重新生成图片: {original_task.model_name}")
                comfyui_client = create_comfyui_client_for_model(original_task.model_name)
            else:
                from ..workflow_config.workflow_config import workflow_config_manager
                default_workflow = workflow_config_manager.get_default_t2i_workflow()
                logger.info(f"使用默认模型重新生成图片: {default_workflow.title}")
                comfyui_client = create_comfyui_client_for_model(default_workflow.title)

            # 4. 生成多个相似的提示词（可以在这里添加提示词变体逻辑）
            prompts = [original_prompt] * request.count

            # 5. 批量生成图片
            image_filenames = []
            for i in range(request.count):
                logger.info(f"重新生成第 {i+1}/{request.count} 张图片")

                # 提交生成任务
                comfyui_task_id = await comfyui_client.generate_image(prompts)
                if comfyui_task_id:
                    # 等待任务完成并获取图片文件名
                    completed_filenames = await comfyui_client.wait_for_completion(comfyui_task_id)
                    if completed_filenames and len(completed_filenames) > 0:
                        media_file = completed_filenames[0]
                        filename = media_file.filename
                        image_filenames.append(filename)
                        logger.info(f"第 {i+1} 张图片重新生成成功，文件名: {filename}")

            if not image_filenames:
                logger.error("ComfyUI未生成任何图片")
                return SceneRegenerateResponse(
                    task_id=request.task_id,
                    total_prompts=len(prompts),
                    message="图片生成失败"
                )

            logger.info(f"成功重新生成 {len(image_filenames)} 张图片")

            # 6. 保存新图片到数据库
            saved_count = 0
            for filename in image_filenames:
                try:
                    # 检查是否已存在相同的图片
                    existing_image = db.query(SceneImageGallery).filter(
                        SceneImageGallery.task_id == request.task_id,
                        SceneImageGallery.img_url == filename
                    ).first()

                    if existing_image:
                        logger.warning(f"图片 {filename} 已存在，跳过保存")
                        continue

                    # 保存新图片记录
                    scene_image = SceneImageGallery(
                        task_id=request.task_id,
                        img_url=filename,
                        prompt=original_prompt,
                        created_at=datetime.now()
                    )

                    db.add(scene_image)
                    saved_count += 1

                except Exception as e:
                    logger.error(f"保存图片 {filename} 失败: {e}")
                    continue

            # 提交数据库事务
            try:
                db.commit()
                logger.info(f"成功保存 {saved_count} 张重新生成的图片到数据库")
            except SQLAlchemyError as e:
                db.rollback()
                logger.error(f"数据库提交失败: {e}")
                return SceneRegenerateResponse(
                    task_id=request.task_id,
                    total_prompts=len(prompts),
                    message="图片生成成功，但数据库保存失败"
                )

            return SceneRegenerateResponse(
                task_id=request.task_id,
                total_prompts=len(prompts),
                message=f"成功重新生成并保存 {saved_count} 张图片"
            )

        except ValueError as e:
            logger.error(f"参数错误: {e}")
            raise
        except Exception as e:
            logger.error(f"重新生成场面图片失败: {e}")
            raise ValueError(f"重新生成图片失败: {str(e)}")


# 创建服务实例（需要在调用时传入DifyClient）
def create_scene_illustration_service(dify_client: DifyClient) -> SceneIllustrationService:
    """创建场面绘制服务实例.

    Args:
        dify_client: Dify客户端实例

    Returns:
        场面绘制服务实例
    """
    return SceneIllustrationService(dify_client)