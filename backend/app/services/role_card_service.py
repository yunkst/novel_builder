"""
人物卡图片生成服务.

提供人物卡图片生成、管理、查询等核心业务逻辑。
"""

import json
import logging
from datetime import datetime
from typing import Dict, Any, List, Optional

from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from ..models.text2img import RoleImageGallery
from ..schemas import (
    RoleCardGenerateRequest, RoleGalleryResponse,
    RoleImageDeleteRequest, RoleRegenerateRequest, RoleGenerateResponse
)
from .dify_client import create_dify_client
from .comfyui_client import create_comfyui_client_for_model
from .comfyui_client_v2 import create_comfyui_client_v2
from ..workflow_config.workflow_config import workflow_config_manager

logger = logging.getLogger(__name__)


class RoleCardService:
    """人物卡服务类."""

    def __init__(self):
        """初始化人物卡服务."""
        self.dify_client = None
        self.comfyui_client = None
        self._init_clients()

    def _init_clients(self):
        """初始化外部服务客户端."""
        try:
            self.dify_client = create_dify_client()
            logger.info("Dify客户端初始化成功")
        except Exception as e:
            logger.error(f"Dify客户端初始化失败: {e}")
            self.dify_client = None

        try:
            self.comfyui_client = create_comfyui_client_v2()
            logger.info("ComfyUI客户端初始化成功")
        except Exception as e:
            logger.error(f"ComfyUI客户端初始化失败: {e}")
            self.comfyui_client = None

    async def generate_role_images(self, request: RoleCardGenerateRequest, db: Session, model: Optional[str] = None) -> RoleGenerateResponse:
        """生成人物卡图片.

        Args:
            request: 生成请求
            db: 数据库会话
            model: 指定的模型名称，如果为None则使用默认模型

        Returns:
            生成响应
        """
        if not self.dify_client:
            raise ValueError("Dify客户端未正确初始化")

        try:
            # 根据model参数创建ComfyUI客户端
            if model:
                logger.info(f"使用指定模型生成图片: {model}")
                comfyui_client = create_comfyui_client_for_model(model)
            else:
                # 使用默认模型
                default_workflow = workflow_config_manager.get_default_t2i_workflow()
                logger.info(f"使用默认模型生成图片: {default_workflow.title}")
                comfyui_client = create_comfyui_client_for_model(default_workflow.title)

            # 1. 调用Dify生成提示词
            logger.info(f"为角色 {request.role_id} 生成拍照提示词")
            prompts = await self.dify_client.generate_photo_prompts(
                roles=request.roles,
                user_input=request.user_input
            )

            if not prompts:
                logger.warning("Dify未返回任何提示词")
                return RoleGenerateResponse(
                    role_id=request.role_id,
                    total_prompts=0,
                    message="未生成任何提示词，请检查角色信息和用户要求"
                )

            logger.info(f"Dify返回 {len(prompts)} 个提示词")

            # 2. 批量调用ComfyUI生成图片
            logger.info(f"开始批量生成 {len(prompts)} 张图片")
            image_filenames = await comfyui_client.generate_images_batch(prompts)

            if not image_filenames:
                logger.error("ComfyUI未生成任何图片")
                return RoleGenerateResponse(
                    role_id=request.role_id,
                    total_prompts=len(prompts),
                    message="提示词生成成功，但图片生成失败"
                )

            logger.info(f"ComfyUI成功生成 {len(image_filenames)} 张图片")

            # 3. 保存图片信息到数据库
            saved_count = 0
            for i, filename in enumerate(image_filenames):
                try:
                    # 确保提示词和图片数量匹配
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

                except Exception as e:
                    logger.error(f"保存图片 {filename} 失败: {e}")
                    continue

            # 提交数据库事务
            try:
                db.commit()
                logger.info(f"成功保存 {saved_count} 张图片到数据库")
            except SQLAlchemyError as e:
                db.rollback()
                logger.error(f"数据库提交失败: {e}")
                return RoleGenerateResponse(
                    role_id=request.role_id,
                    total_prompts=len(prompts),
                    message="图片生成成功，但数据库保存失败"
                )

            return RoleGenerateResponse(
                role_id=request.role_id,
                total_prompts=len(prompts),
                message=f"成功生成并保存 {saved_count} 张图片"
            )

        except ValueError as e:
            # 处理模型不存在的错误
            logger.error(f"模型错误: {e}")
            return RoleGenerateResponse(
                role_id=request.role_id,
                total_prompts=0,
                message=str(e)
            )
        except Exception as e:
            logger.error(f"生成人物卡图片失败: {e}")
            raise

    async def get_role_gallery(self, role_id: str, db: Session) -> RoleGalleryResponse:
        """获取角色图集.

        Args:
            role_id: 角色ID
            db: 数据库会话

        Returns:
            角色图集响应
        """
        try:
            # 查询角色的所有图片
            images = db.query(RoleImageGallery).filter(
                RoleImageGallery.role_id == role_id
            ).order_by(RoleImageGallery.created_at.desc()).all()

            # 提取图片URL列表，直接使用 img_url（文件名）
            image_urls = [img.img_url for img in images]

            logger.info(f"角色 {role_id} 有 {len(image_urls)} 张图片")

            return RoleGalleryResponse(
                role_id=role_id,
                images=image_urls
            )

        except Exception as e:
            logger.error(f"获取角色图集失败: {e}")
            raise

    async def delete_role_image(self, request: RoleImageDeleteRequest, db: Session) -> bool:
        """删除角色图片.

        Args:
            request: 删除请求
            db: 数据库会话

        Returns:
            是否删除成功
        """
        try:
            # 查找要删除的图片
            image_to_delete = db.query(RoleImageGallery).filter(
                RoleImageGallery.role_id == request.role_id,
                RoleImageGallery.img_url == request.img_url
            ).first()

            if not image_to_delete:
                logger.warning(f"未找到要删除的图片: role_id={request.role_id}, img_url={request.img_url}")
                return False

            # 删除图片记录（注意：这里只删除数据库记录，实际的图片文件需要手动清理）
            db.delete(image_to_delete)
            db.commit()

            logger.info(f"成功删除图片: {request.img_url}")
            return True

        except SQLAlchemyError as e:
            db.rollback()
            logger.error(f"删除图片数据库操作失败: {e}")
            raise
        except Exception as e:
            logger.error(f"删除图片失败: {e}")
            raise

    async def regenerate_similar_images(self, request: RoleRegenerateRequest, db: Session, model: Optional[str] = None) -> RoleGenerateResponse:
        """基于现有图片重新生成相似图片.

        Args:
            request: 重新生成请求
            db: 数据库会话
            model: 指定的模型名称，如果为None则使用默认模型

        Returns:
            生成响应
        """
        try:
            # 根据model参数创建ComfyUI客户端
            if model:
                logger.info(f"使用指定模型重新生成图片: {model}")
                comfyui_client = create_comfyui_client_for_model(model)
            else:
                # 使用默认模型
                default_workflow = workflow_config_manager.get_default_t2i_workflow()
                logger.info(f"使用默认模型重新生成图片: {default_workflow.title}")
                comfyui_client = create_comfyui_client_for_model(default_workflow.title)

            # 1. 查询参考图片的生成提示词
            reference_image = db.query(RoleImageGallery).filter(
                RoleImageGallery.img_url == request.img_url
            ).first()

            if not reference_image:
                logger.error(f"未找到参考图片: {request.img_url}")
                raise ValueError("参考图片不存在")

            original_prompt = reference_image.prompt
            role_id = reference_image.role_id

            logger.info(f"基于图片 {request.img_url} 重新生成 {request.count} 张相似图片")
            logger.info(f"原始提示词: {original_prompt}")

            # 2. 生成多个相似的提示词（简单重复使用原始提示词）
            # 在实际应用中，可以在这里使用更智能的提示词变体生成
            prompts = [original_prompt] * request.count

            # 3. 批量生成图片
            image_filenames = await comfyui_client.generate_images_batch(prompts)

            if not image_filenames:
                logger.error("ComfyUI未生成任何图片")
                return RoleGenerateResponse(
                    role_id=role_id,
                    total_prompts=len(prompts),
                    message="图片生成失败"
                )

            logger.info(f"ComfyUI成功生成 {len(image_filenames)} 张相似图片")

            # 4. 保存新图片到数据库
            saved_count = 0
            for i, filename in enumerate(image_filenames):
                try:
                    # 检查是否已存在相同的图片
                    existing_image = db.query(RoleImageGallery).filter(
                        RoleImageGallery.role_id == role_id,
                        RoleImageGallery.img_url == filename
                    ).first()

                    if existing_image:
                        logger.warning(f"图片 {filename} 已存在，跳过保存")
                        continue

                    # 保存新图片记录，使用相同的提示词
                    role_image = RoleImageGallery(
                        role_id=role_id,
                        img_url=filename,
                        prompt=original_prompt,
                        created_at=datetime.now()
                    )

                    db.add(role_image)
                    saved_count += 1

                except Exception as e:
                    logger.error(f"保存图片 {filename} 失败: {e}")
                    continue

            # 提交数据库事务
            try:
                db.commit()
                logger.info(f"成功保存 {saved_count} 张相似图片到数据库")
            except SQLAlchemyError as e:
                db.rollback()
                logger.error(f"数据库提交失败: {e}")
                return RoleGenerateResponse(
                    role_id=role_id,
                    total_prompts=len(prompts),
                    message="图片生成成功，但数据库保存失败"
                )

            return RoleGenerateResponse(
                role_id=role_id,
                total_prompts=len(prompts),
                message=f"成功生成并保存 {saved_count} 张相似图片"
            )

        except ValueError as e:
            # 处理模型不存在的错误
            logger.error(f"模型错误: {e}")
            return RoleGenerateResponse(
                role_id="",  # 这里role_id暂时为空，因为可能在查询参考图片前就出错
                total_prompts=0,
                message=str(e)
            )
        except Exception as e:
            logger.error(f"重新生成相似图片失败: {e}")
            raise

    async def health_check(self) -> Dict[str, bool]:
        """检查服务健康状态.

        Returns:
            各服务的健康状态
        """
        health_status = {
            "dify": False,
            "comfyui": False
        }

        # 检查Dify服务
        if self.dify_client:
            try:
                health_status["dify"] = await self.dify_client.health_check()
            except Exception as e:
                logger.error(f"Dify健康检查异常: {e}")

        # 检查ComfyUI服务
        if self.comfyui_client:
            try:
                health_status["comfyui"] = await self.comfyui_client.health_check()
            except Exception as e:
                logger.error(f"ComfyUI健康检查异常: {e}")

        return health_status


# 创建全局服务实例
role_card_service = RoleCardService()