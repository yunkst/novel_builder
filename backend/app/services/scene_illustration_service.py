"""
场面绘制服务.

提供场面绘制的核心业务逻辑，包括任务管理、图片生成和结果存储。
"""

import json
import logging
from datetime import datetime
from typing import cast

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from ..models.scene_comfyui_mapping import SceneComfyUIImages, SceneComfyUITask
from ..models.scene_illustration import SceneIllustrationTask
from ..schemas import (
    EnhancedSceneIllustrationRequest,
    ImageWithModel,
    RoleInfo,
    SceneGalleryResponse,
    SceneIllustrationResponse,
    SceneImageDeleteRequest,
    SceneRegenerateRequest,
    SceneRegenerateResponse,
)
from ..workflow_config import WorkflowType
from ..workflow_config.workflow_config import workflow_config_manager
from .comfyui_client import create_comfyui_client_for_model
from .dify_client import DifyClient

logger = logging.getLogger(__name__)


class SceneIllustrationService:
    """场面绘制服务类."""

    def __init__(self, dify_client: DifyClient):
        """初始化场面绘制服务.

        Args:
            dify_client: Dify客户端实例
        """
        self.dify_client = dify_client

    def _restore_roles_from_json(self, roles_json: str) -> str:
        """从JSON字符串恢复角色数据并格式化为场景绘制的文本格式

        Args:
            roles_json: 数据库中存储的JSON字符串

        Returns:
            格式化的角色信息字符串，用于Dify客户端
            只包含名字、face_prompts、body_prompts字段
        """
        if not roles_json or roles_json.strip() == "":
            return ""

        try:
            roles_data = json.loads(roles_json)

            # 如果是列表格式（新版本存储）
            if isinstance(roles_data, list):
                return self._format_roles_list(roles_data)

            # 如果已经是字典格式（旧版本兼容，直接返回空字符串）
            if isinstance(roles_data, dict):
                logger.warning("检测到旧版本角色数据格式，不支持转换为场景绘制格式")
                return ""

            return ""

        except (json.JSONDecodeError, TypeError, Exception) as e:
            logger.error(f"解析角色数据失败: {e}")
            return ""

    def _format_roles_list(self, roles_data: list) -> str:
        """格式化角色列表为场景绘制的文本格式

        Args:
            roles_data: 角色数据列表

        Returns:
            格式化的角色信息字符串
        """
        role_lines = []
        for i, role_data in enumerate(roles_data):
            if not isinstance(role_data, dict) or "name" not in role_data:
                continue

            role_info = RoleInfo.from_dict(role_data)

            # 添加角色序号和名称
            role_lines.append(f"{i + 1}. {role_info.name}")

            # 添加面部描述（如果存在且非空）
            if role_info.face_prompts:
                role_lines.append(f"   面部描述：{role_info.face_prompts}")

            # 添加身材描述（如果存在且非空）
            if role_info.body_prompts:
                role_lines.append(f"   身材描述：{role_info.body_prompts}")

            # 如果角色有描述信息，添加空行分隔（最后一个角色除外）
            has_descriptions = bool(role_info.face_prompts or role_info.body_prompts)
            if has_descriptions and i < len(roles_data) - 1:
                role_lines.append("")

        return "\n".join(role_lines)

    async def generate_scene_images(
        self, request: EnhancedSceneIllustrationRequest, db: Session
    ) -> SceneIllustrationResponse:
        """生成场面图片（新架构：立即返回，不等待生成完成）.

        Args:
            request: 场面绘制请求
            db: 数据库会话

        Returns:
            任务创建响应

        Raises:
            ValueError: 当请求参数无效时
        """
        try:
            from ..utils.model_validation import validate_and_get_model

            model_name = validate_and_get_model(request.model_name, "T2I")

            # 删除已存在的任务
            self._delete_existing_task(request.task_id, db)

            # 生成提示词
            prompts = await self._generate_prompts(request)

            # 提交ComfyUI任务
            comfyui_prompt_ids = await self._submit_comfyui_tasks(
                request, model_name, prompts
            )

            # 保存任务记录
            self._save_task_records(request, model_name, prompts, comfyui_prompt_ids, db)

            logger.info(
                f"任务 {request.task_id}: 成功提交 {len(comfyui_prompt_ids)} 个ComfyUI任务"
            )

            return SceneIllustrationResponse(
                task_id=request.task_id,
                status="submitted",
                message=f"任务已提交到ComfyUI，共 {len(comfyui_prompt_ids)} 个生成任务",
            )

        except SQLAlchemyError as e:
            db.rollback()
            logger.error(f"创建任务数据库操作失败: {e}")
            raise ValueError(f"数据库操作失败: {e!s}")
        except Exception as e:
            logger.error(f"创建任务失败: {e}")
            raise ValueError(f"创建任务失败: {e!s}")

    def _delete_existing_task(self, task_id: str, db: Session) -> None:
        """删除已存在的任务记录

        Args:
            task_id: 任务ID
            db: 数据库会话
        """
        existing_task = (
            db.query(SceneIllustrationTask)
            .filter(SceneIllustrationTask.task_id == task_id)
            .first()
        )

        if existing_task:
            db.query(SceneComfyUITask).filter(
                SceneComfyUITask.task_id == task_id
            ).delete()
            db.delete(existing_task)
            db.commit()
            logger.info(f"删除已存在的任务记录: {task_id}")

    async def _generate_prompts(
        self, request: EnhancedSceneIllustrationRequest
    ) -> str:
        """生成场面提示词

        Args:
            request: 场面绘制请求

        Returns:
            生成的提示词

        Raises:
            ValueError: 当未生成任何提示词时
        """
        logger.info(f"任务 {request.task_id}: 开始生成提示词")
        roles_text = self._restore_roles_from_json(request.to_roles_json())
        logger.info(f"任务 {request.task_id}: 格式化的角色信息:\n{roles_text}")

        # 获取工作流配置中的 prompt_skill
        from ..workflow_config import WorkflowType

        workflow = workflow_config_manager.get_t2i_workflow_by_title(request.model_name)
        prompt_skill = workflow.prompt_skill if workflow else None

        prompts = await self.dify_client.generate_scene_prompts(
            chapters_content=request.chapters_content,
            roles=roles_text,
            prompt_skill=prompt_skill,
        )

        if not prompts:
            raise ValueError("未生成任何提示词，请检查章节内容和角色信息")

        logger.info(f"任务 {request.task_id}: 生成提示词成功")
        return prompts

    async def _submit_comfyui_tasks(
        self, request: EnhancedSceneIllustrationRequest, model_name: str, prompts: str
    ) -> list[str]:
        """提交ComfyUI任务

        Args:
            request: 场面绘制请求
            model_name: 模型名称
            prompts: 提示词

        Returns:
            ComfyUI prompt_id列表

        Raises:
            ValueError: 当所有任务提交失败时
        """
        logger.info(f"任务 {request.task_id}: 开始提交ComfyUI任务")
        comfyui_client = create_comfyui_client_for_model(model_name)

        comfyui_prompt_ids = []
        for i in range(request.num):
            logger.info(
                f"任务 {request.task_id}: 提交第 {i + 1}/{request.num} 个ComfyUI任务"
            )

            prompt_id = await comfyui_client.generate_image(prompts)
            if prompt_id:
                comfyui_prompt_ids.append(prompt_id)
                logger.info(
                    f"任务 {request.task_id}: 第 {i + 1} 个ComfyUI任务ID: {prompt_id}"
                )
            else:
                logger.warning(
                    f"任务 {request.task_id}: 第 {i + 1} 个ComfyUI任务提交失败"
                )

        if not comfyui_prompt_ids:
            raise ValueError("所有ComfyUI任务提交失败，请检查ComfyUI服务")

        return comfyui_prompt_ids

    def _save_task_records(
        self,
        request: EnhancedSceneIllustrationRequest,
        model_name: str,
        prompts: str,
        comfyui_prompt_ids: list[str],
        db: Session,
    ) -> None:
        """保存任务记录到数据库

        Args:
            request: 场面绘制请求
            model_name: 模型名称
            prompts: 提示词
            comfyui_prompt_ids: ComfyUI prompt_id列表
            db: 数据库会话
        """
        # 创建任务记录
        task_record = SceneIllustrationTask(
            task_id=request.task_id,
            status="submitted",
            chapters_content=request.chapters_content,
            roles=request.to_roles_json(),
            num=request.num,
            model_name=model_name,
            prompts=prompts,
            generated_images=0,
        )
        db.add(task_record)

        # 记录task_id到ComfyUI prompt_id的映射
        for prompt_id in comfyui_prompt_ids:
            task_mapping = SceneComfyUITask(
                task_id=request.task_id, comfyui_prompt_id=prompt_id
            )
            db.add(task_mapping)

            # 记录空的图片记录（标记为未获取）
            image_record = SceneComfyUIImages(
                comfyui_prompt_id=prompt_id,
                images="[]",
                status_fetched=False,
            )
            db.add(image_record)

        db.commit()

    async def get_scene_gallery(
        self, task_id: str, db: Session
    ) -> SceneGalleryResponse:
        """获取场面图片列表（新架构：从映射表和ComfyUI获取）.

        Args:
            task_id: 任务标识符
            db: 数据库会话

        Returns:
            图片列表响应

        Raises:
            ValueError: 当任务不存在时
        """
        try:
            logger.info(f"🔍 [DEBUG] 开始获取任务 {task_id} 的图片列表")

            # 1. 查找任务对应的所有 ComfyUI prompt_id
            mappings = (
                db.query(SceneComfyUITask)
                .filter(SceneComfyUITask.task_id == task_id)
                .all()
            )

            if not mappings:
                # 兼容旧架构：尝试从 scene_image_gallery 查询
                logger.info(f"任务 {task_id}: 未找到ComfyUI映射记录，尝试从旧表查询")
                return await self._get_gallery_from_legacy_table(task_id, db)

            comfyui_prompt_ids = [m.comfyui_prompt_id for m in mappings]
            logger.info(f"任务 {task_id}: 找到 {len(comfyui_prompt_ids)} 个ComfyUI任务: {comfyui_prompt_ids}")

            # 2. 批量查询所有 prompt_id 的图片记录（优化：一次查询）
            image_records = (
                db.query(SceneComfyUIImages)
                .filter(SceneComfyUIImages.comfyui_prompt_id.in_(comfyui_prompt_ids))
                .all()
            )

            # 构建字典方便查找
            records_dict = {r.comfyui_prompt_id: r for r in image_records}

            # 3. 遍历处理每个 prompt_id
            from ..schemas import ImageWithModel

            all_images: list[ImageWithModel] = []  # 使用明确类型
            for prompt_id in comfyui_prompt_ids:
                logger.info(f"🔍 [DEBUG] 处理 prompt_id: {prompt_id}")

                image_record = records_dict.get(prompt_id)

                if not image_record:
                    # 异常情况：数据库无记录，创建空记录
                    logger.warning(f"ComfyUI任务 {prompt_id}: 无数据库记录，创建空记录")
                    image_record = SceneComfyUIImages(
                        comfyui_prompt_id=prompt_id, images="[]", status_fetched=False
                    )
                    db.add(image_record)
                    db.commit()
                    # 更新字典
                    records_dict[prompt_id] = image_record

                # 打印数据库状态
                logger.info(f"  📊 [DEBUG] 数据库状态: status_fetched={image_record.status_fetched}, images_count={len(image_record.images) if image_record.images else 0}")

                # 获取模型名称
                model_name = image_record.model_name
                logger.info(f"  🎨 [DEBUG] 模型名称: {model_name}")

                # 解析图片列表（从JSON字符串）
                try:
                    images_str: str = cast("str", image_record.images) or "[]"
                    images_list = json.loads(images_str) if images_str else []
                    logger.info(f"  📷 [DEBUG] 数据库中的图片列表: {images_list}")
                except json.JSONDecodeError as e:
                    logger.error(f"ComfyUI任务 {prompt_id}: 图片数据格式错误: {e}")
                    images_list = []

                if images_list:
                    # 情况1：已有图片，直接使用
                    logger.info(
                        f"  ✅ [DEBUG] 从数据库获取 {len(images_list)} 张图片，不需要重新获取"
                    )
                    # 为每张图片创建 ImageWithModel 对象
                    for img_url in images_list:
                        all_images.append(
                            ImageWithModel(url=img_url, model_name=model_name)
                        )
                elif not image_record.status_fetched or (
                    image_record.status_fetched and not images_list
                ):
                    # 情况2：无图片且未获取过，或已获取过但结果为空（可能ComfyUI还在处理）
                    # 允许重新获取，避免ComfyUI未完成时过早标记为已获取

                    logger.info(f"  🔄 [DEBUG] 判断条件: not status_fetched={not image_record.status_fetched}")
                    logger.info(f"  🔄 [DEBUG] 判断条件: status_fetched and not images_list={image_record.status_fetched and not images_list}")

                    if image_record.status_fetched and not images_list:
                        logger.warning(
                            f"ComfyUI任务 {prompt_id}: 之前获取时无图片，尝试重新获取"
                        )

                    logger.info(f"  🌐 [DEBUG] 从ComfyUI API获取图片...")
                    prompt_id_str: str = cast("str", prompt_id)
                    images = await self._fetch_images_from_comfyui(prompt_id_str)
                    logger.info(f"  📷 [DEBUG] ComfyUI API返回的图片列表: {images}")

                    # 更新数据库
                    image_record.images = json.dumps(images)  # type: ignore[assignment]
                    image_record.status_fetched = True  # type: ignore[assignment]
                    image_record.fetched_at = datetime.now()  # type: ignore[assignment]
                    db.commit()
                    logger.info(f"  💾 [DEBUG] 已更新数据库: status_fetched=True, images_count={len(images)}")

                    # 为每张图片创建 ImageWithModel 对象
                    for img_url in images:
                        all_images.append(
                            ImageWithModel(url=img_url, model_name=model_name)
                        )
                else:
                    # 情况3：已获取过但无图片（ComfyUI 失败）
                    logger.warning(f"ComfyUI任务 {prompt_id}: 已获取过但无图片")

            logger.info(f"🎯 [DEBUG] 最终返回 {len(all_images)} 张图片")

            # 查询任务信息，获取模型宽高（作为默认值）
            model_width = None
            model_height = None

            try:
                task_record = (
                    db.query(SceneIllustrationTask)
                    .filter(SceneIllustrationTask.task_id == task_id)
                    .first()
                )

                if task_record and task_record.model_name:
                    # 从工作流配置中获取模型的宽高信息
                    workflow = workflow_config_manager.get_t2i_workflow_by_title(
                        task_record.model_name
                    )
                    if workflow:
                        model_width = workflow.width
                        model_height = workflow.height
                        logger.info(
                            f"✅ 找到模型信息: {task_record.model_name}, 尺寸: {model_width}x{model_height}"
                        )
                    else:
                        logger.warning(f"⚠️ 未找到模型配置: {task_record.model_name}")
            except Exception as e:
                logger.error(f"❌ 查询模型信息失败: {e}")

            return SceneGalleryResponse(
                task_id=task_id,
                images=all_images,  # 直接使用 list[ImageWithModel]
                model_name=None,  # 已废弃，每张图片有自己的model_name
                model_width=model_width,
                model_height=model_height,
            )

        except SQLAlchemyError as e:
            logger.error(f"获取图片列表数据库操作失败: {e}")
            raise ValueError(f"数据库操作失败: {e!s}")
        except Exception as e:
            logger.error(f"获取图片列表失败: {e}")
            raise ValueError(f"获取图片列表失败: {e!s}")

    async def _fetch_images_from_comfyui(self, prompt_id: str) -> list[str]:
        """从 ComfyUI API 获取图片列表.

        Args:
            prompt_id: ComfyUI prompt_id

        Returns:
            图片文件名列表
        """
        try:
            # 获取默认的ComfyUI客户端
            from ..workflow_config import WorkflowType

            default_workflow = workflow_config_manager.get_default_workflow(
                WorkflowType.T2I
            )
            comfyui_client = create_comfyui_client_for_model(default_workflow.title)

            # 获取任务历史（使用 check_task_status 方法）
            history = await comfyui_client.check_task_status(prompt_id)

            if not history:
                logger.warning(f"ComfyUI任务 {prompt_id}: 未找到历史记录")
                return []

            # 解析图片列表 - ComfyUI的结构是 outputs.node_id.images
            outputs = history.get("outputs", {})
            if not outputs:
                logger.warning(f"ComfyUI任务 {prompt_id}: 无输出数据，history响应: {history.keys()}")
                return []

            # 遍历所有节点输出，查找图片
            filenames = []
            for node_id, node_output in outputs.items():
                images = node_output.get("images", [])
                if images:
                    logger.info(f"ComfyUI任务 {prompt_id}: 节点 {node_id} 有 {len(images)} 张图片")
                    for img in images:
                        filename = img.get("filename", "")
                        subfolder = img.get("subfolder", "")
                        if filename:
                            full_path = f"{subfolder}/{filename}" if subfolder else filename
                            filenames.append(full_path)
                            logger.debug(f"找到图片: {full_path}")

            if not filenames:
                logger.warning(
                    f"ComfyUI任务 {prompt_id}: 无图片数据。outputs键: {list(outputs.keys())}"
                )
                # 输出详细的调试信息
                for node_id, node_output in outputs.items():
                    logger.warning(f"节点 {node_id} 的输出: {list(node_output.keys())}")
                return []

            logger.info(f"ComfyUI任务 {prompt_id}: 从API获取 {len(filenames)} 张图片")

            return filenames

        except Exception as e:
            logger.error(f"从ComfyUI获取图片失败 (prompt_id={prompt_id}): {e}")
            return []

    async def _get_gallery_from_legacy_table(
        self, task_id: str, db: Session
    ) -> SceneGalleryResponse:
        """从旧的 scene_image_gallery 表获取图片（兼容旧数据）.

        Args:
            task_id: 任务标识符
            db: 数据库会话

        Returns:
            图片列表响应
        """
        try:
            from ..models.scene_illustration import SceneImageGallery

            images = (
                db.query(SceneImageGallery)
                .filter(SceneImageGallery.task_id == task_id)
                .order_by(SceneImageGallery.created_at)
                .all()
            )

            image_list = [cast("str", img.img_url) for img in images]
            logger.info(f"任务 {task_id}: 从旧表获取 {len(image_list)} 张图片")

            # 旧表也可能有对应的任务记录，尝试获取模型信息
            model_name = None
            model_width = None
            model_height = None

            try:
                task_record = (
                    db.query(SceneIllustrationTask)
                    .filter(SceneIllustrationTask.task_id == task_id)
                    .first()
                )

                if task_record and task_record.model_name:
                    model_name = task_record.model_name
                    workflow = workflow_config_manager.get_t2i_workflow_by_title(
                        model_name
                    )
                    if workflow:
                        model_width = workflow.width
                        model_height = workflow.height
                        logger.info(
                            f"✅ 旧表数据也找到模型信息: {model_name}, 尺寸: {model_width}x{model_height}"
                        )
            except Exception as e:
                logger.error(f"❌ 查询旧表模型信息失败: {e}")

            return SceneGalleryResponse(
                task_id=task_id,
                images=image_list,
                model_name=model_name,
                model_width=model_width,
                model_height=model_height,
            )
        except Exception as e:
            logger.error(f"从旧表获取图片失败: {e}")
            # 旧表查询失败，返回空列表而不是抛出异常
            return SceneGalleryResponse(
                task_id=task_id,
                images=[],
                model_name=None,
                model_width=None,
                model_height=None,
            )

    async def delete_scene_image(
        self, request: SceneImageDeleteRequest, db: Session
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
            logger.info(f"🗑️ [DEBUG] 开始删除图片: task_id={request.task_id}, filename={request.filename}")

            # 检查任务是否存在
            task = (
                db.query(SceneIllustrationTask)
                .filter(SceneIllustrationTask.task_id == request.task_id)
                .first()
            )

            if not task:
                raise ValueError("任务不存在")

            # 查找所有相关的图片记录
            mappings = (
                db.query(SceneComfyUITask)
                .filter(SceneComfyUITask.task_id == request.task_id)
                .all()
            )

            if not mappings:
                raise ValueError("任务无相关图片记录")

            comfyui_prompt_ids = [m.comfyui_prompt_id for m in mappings]
            logger.info(f"  📋 [DEBUG] 找到 {len(comfyui_prompt_ids)} 个ComfyUI任务: {comfyui_prompt_ids}")
            deleted = False

            # 在每个 ComfyUI 图片记录中查找并删除指定图片
            for prompt_id in comfyui_prompt_ids:
                logger.info(f"  🔍 [DEBUG] 检查 prompt_id: {prompt_id}")

                image_record = (
                    db.query(SceneComfyUIImages)
                    .filter(SceneComfyUIImages.comfyui_prompt_id == prompt_id)
                    .first()
                )

                if image_record and image_record.images:
                    try:
                        # 解析 JSON 数组
                        images_str: str = cast("str", image_record.images) or "[]"
                        images_list = json.loads(images_str) if images_str else []

                        logger.info(f"    📷 [DEBUG] 当前图片列表 ({len(images_list)}张): {images_list}")

                        # 检查图片是否在列表中
                        if request.filename in images_list:
                            # 删除整个记录（因为一个 ComfyUI 任务对应一张图）
                            logger.info(f"    ❌ [DEBUG] 找到要删除的图片，删除整个任务记录: {prompt_id}")

                            # 删除图片记录
                            db.delete(image_record)

                            # 删除映射关系
                            mapping_to_delete = (
                                db.query(SceneComfyUITask)
                                .filter(
                                    SceneComfyUITask.task_id == request.task_id,
                                    SceneComfyUITask.comfyui_prompt_id == prompt_id
                                )
                                .first()
                            )
                            if mapping_to_delete:
                                db.delete(mapping_to_delete)

                            db.commit()
                            deleted = True
                            logger.info(
                                f"成功删除 ComfyUI 任务 {prompt_id} 及其图片记录"
                            )
                        else:
                            logger.info(f"    ⏭️ [DEBUG] 图片不在此列表中，跳过")
                    except json.JSONDecodeError:
                        logger.error(f"ComfyUI任务 {prompt_id}: 图片数据格式错误")
                        continue

            if not deleted:
                raise ValueError("图片不存在")

            db.commit()
            logger.info(f"✅ [DEBUG] 删除场面图片成功: {request.task_id}/{request.filename}")
            return True

        except SQLAlchemyError as e:
            db.rollback()
            logger.error(f"删除图片数据库操作失败: {e}")
            raise ValueError("删除图片失败")
        except Exception as e:
            logger.error(f"删除图片失败: {e}")
            raise ValueError(f"删除图片失败: {e!s}")

    async def regenerate_scene_images(
        self, request: SceneRegenerateRequest, db: Session
    ) -> SceneRegenerateResponse:
        """基于现有任务重新生成场面图片（新架构：记录映射关系后立即返回）.

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
            original_task = (
                db.query(SceneIllustrationTask)
                .filter(SceneIllustrationTask.task_id == request.task_id)
                .first()
            )

            if not original_task:
                raise ValueError("原始任务不存在")

            # 移除 status 检查：任何任务都可以重新生成
            # if original_task.status != "completed":
            #     raise ValueError("只能基于已完成的任务重新生成图片")

            # 2. 获取原始任务的提示词
            original_prompt: str = cast("str", original_task.prompts)
            if not original_prompt:
                raise ValueError("原始任务的提示词不存在")

            logger.info(f"基于任务 {request.task_id} 重新生成 {request.count} 张图片")

            # 3. 确定使用的模型（优先级：request > original_task > 默认）
            requested_model = request.model_name or cast("str", original_task.model_name)

            # 使用工具函数验证并获取有效的模型名称
            from ..utils.model_validation import validate_and_get_model

            model_name = validate_and_get_model(requested_model, "T2I")

            logger.info(f"使用模型重新生成图片: {model_name}")
            comfyui_client = create_comfyui_client_for_model(model_name)

            # 4. 提交多个生成任务到ComfyUI（不等待完成）
            comfyui_prompt_ids = []
            for i in range(request.count):
                logger.info(f"重新生成：提交第 {i + 1}/{request.count} 个ComfyUI任务")

                # 提交到ComfyUI，获取prompt_id
                prompt_id = await comfyui_client.generate_image(str(original_prompt))
                if prompt_id:
                    comfyui_prompt_ids.append(prompt_id)
                    logger.info(f"重新生成：第 {i + 1} 个ComfyUI任务ID: {prompt_id}")
                else:
                    logger.warning(f"重新生成：第 {i + 1} 个ComfyUI任务提交失败")

            if not comfyui_prompt_ids:
                raise ValueError("所有ComfyUI任务提交失败，请检查ComfyUI服务")

            # 5. 记录新的映射关系
            for prompt_id in comfyui_prompt_ids:
                # 记录task_id到ComfyUI prompt_id的映射
                task_mapping = SceneComfyUITask(
                    task_id=request.task_id,
                    comfyui_prompt_id=prompt_id,
                    model_name=model_name,  # 记录使用的模型
                )
                db.add(task_mapping)

                # 记录空的图片记录（标记为未获取）
                image_record = SceneComfyUIImages(
                    comfyui_prompt_id=prompt_id,
                    images="[]",
                    status_fetched=False,
                    model_name=model_name,  # 记录使用的模型
                )
                db.add(image_record)

            db.commit()

            logger.info(
                f"任务 {request.task_id}: 成功提交 {len(comfyui_prompt_ids)} 个重新生成任务"
            )

            # 6. 立即返回（不等待生成完成）
            return SceneRegenerateResponse(
                task_id=request.task_id,
                total_prompts=len(comfyui_prompt_ids),
                message=f"成功提交 {len(comfyui_prompt_ids)} 个重新生成任务",
            )

        except ValueError as e:
            logger.error(f"参数错误: {e}")
            raise
        except Exception as e:
            logger.error(f"重新生成图片失败: {e}")
            raise ValueError(f"重新生成图片失败: {e!s}")


# 创建服务实例（需要在调用时传入DifyClient）
def create_scene_illustration_service(
    dify_client: DifyClient,
) -> SceneIllustrationService:
    """创建场面绘制服务实例.

    Args:
        dify_client: Dify客户端实例

    Returns:
        场面绘制服务实例
    """
    return SceneIllustrationService(dify_client)
