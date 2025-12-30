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
    RoleInfo,
    SceneGalleryResponse,
    SceneIllustrationResponse,
    SceneImageDeleteRequest,
    SceneRegenerateRequest,
    SceneRegenerateResponse,
)
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
                role_lines = []
                for i, role_data in enumerate(roles_data):
                    if isinstance(role_data, dict) and "name" in role_data:
                        # 重建RoleInfo对象
                        role_info = RoleInfo.from_dict(role_data)

                        # 添加角色序号和名称
                        role_lines.append(f"{i + 1}. {role_info.name}")

                        # 添加面部描述（如果存在且非空）
                        if (
                            hasattr(role_info, "face_prompts")
                            and role_info.face_prompts
                        ):
                            role_lines.append(f"   面部描述：{role_info.face_prompts}")

                        # 添加身材描述（如果存在且非空）
                        if (
                            hasattr(role_info, "body_prompts")
                            and role_info.body_prompts
                        ):
                            role_lines.append(f"   身材描述：{role_info.body_prompts}")

                        # 如果角色有描述信息，添加空行分隔（最后一个角色除外）
                        has_descriptions = (
                            hasattr(role_info, "face_prompts")
                            and role_info.face_prompts
                        ) or (
                            hasattr(role_info, "body_prompts")
                            and role_info.body_prompts
                        )
                        if has_descriptions and i < len(roles_data) - 1:
                            role_lines.append("")

                return "\n".join(role_lines)

            # 如果已经是字典格式（旧版本兼容，直接返回空字符串）
            elif isinstance(roles_data, dict):
                logger.warning("检测到旧版本角色数据格式，不支持转换为场景绘制格式")
                return ""

            return ""

        except (json.JSONDecodeError, TypeError, Exception) as e:
            logger.error(f"解析角色数据失败: {e}")
            return ""

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
            # 使用工具函数验证并获取有效的模型名称
            from ..utils.model_validation import validate_and_get_model

            model_name = validate_and_get_model(request.model_name, "T2I")

            # 检查是否已存在相同task_id的任务
            existing_task = (
                db.query(SceneIllustrationTask)
                .filter(SceneIllustrationTask.task_id == request.task_id)
                .first()
            )

            if existing_task:
                # 删除旧的映射记录（如果存在）
                db.query(SceneComfyUITask).filter(
                    SceneComfyUITask.task_id == request.task_id
                ).delete()
                db.delete(existing_task)
                db.commit()
                logger.info(f"删除已存在的任务记录: {request.task_id}")

            # 1. 生成提示词
            logger.info(f"任务 {request.task_id}: 开始生成提示词")
            roles_text = self._restore_roles_from_json(request.to_roles_json())
            logger.info(f"任务 {request.task_id}: 格式化的角色信息:\n{roles_text}")

            prompts = await self.dify_client.generate_scene_prompts(
                chapters_content=request.chapters_content, roles=roles_text
            )

            if not prompts:
                raise ValueError("未生成任何提示词，请检查章节内容和角色信息")

            logger.info(f"任务 {request.task_id}: 生成提示词成功")

            # 2. 创建ComfyUI客户端并提交任务
            logger.info(f"任务 {request.task_id}: 开始提交ComfyUI任务")
            comfyui_client = create_comfyui_client_for_model(model_name)

            # 3. 提交多个生成任务到ComfyUI
            comfyui_prompt_ids = []
            for i in range(request.num):
                logger.info(
                    f"任务 {request.task_id}: 提交第 {i + 1}/{request.num} 个ComfyUI任务"
                )

                # 提交到ComfyUI，获取prompt_id
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

            # 4. 创建任务记录（保留原表结构，但不使用status字段）
            task_record = SceneIllustrationTask(
                task_id=request.task_id,
                status="submitted",  # 新状态：已提交
                chapters_content=request.chapters_content,
                roles=request.to_roles_json(),
                num=request.num,
                model_name=model_name,
                prompts=prompts,
                generated_images=0,
            )

            db.add(task_record)

            # 5. 记录task_id到ComfyUI prompt_id的映射
            for prompt_id in comfyui_prompt_ids:
                task_mapping = SceneComfyUITask(
                    task_id=request.task_id, comfyui_prompt_id=prompt_id
                )
                db.add(task_mapping)

            # 6. 记录空的图片记录（标记为未获取）
            for prompt_id in comfyui_prompt_ids:
                image_record = SceneComfyUIImages(
                    comfyui_prompt_id=prompt_id,
                    images="[]",  # JSON字符串，空数组
                    status_fetched=False,
                )
                db.add(image_record)

            db.commit()

            logger.info(
                f"任务 {request.task_id}: 成功提交 {len(comfyui_prompt_ids)} 个ComfyUI任务"
            )

            # 7. 立即返回（不等待生成完成）
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
            logger.info(f"任务 {task_id}: 找到 {len(comfyui_prompt_ids)} 个ComfyUI任务")

            # 2. 批量查询所有 prompt_id 的图片记录（优化：一次查询）
            image_records = (
                db.query(SceneComfyUIImages)
                .filter(SceneComfyUIImages.comfyui_prompt_id.in_(comfyui_prompt_ids))
                .all()
            )

            # 构建字典方便查找
            records_dict = {r.comfyui_prompt_id: r for r in image_records}

            # 3. 遍历处理每个 prompt_id
            all_images: list[str] = []
            for prompt_id in comfyui_prompt_ids:
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

                # 解析图片列表（从JSON字符串）
                try:
                    images_str: str = cast("str", image_record.images) or "[]"
                    images_list = json.loads(images_str) if images_str else []
                except json.JSONDecodeError:
                    logger.error(f"ComfyUI任务 {prompt_id}: 图片数据格式错误")
                    images_list = []

                if images_list:
                    # 情况1：已有图片，直接使用
                    logger.info(
                        f"ComfyUI任务 {prompt_id}: 从数据库获取 {len(images_list)} 张图片"
                    )
                    all_images.extend(images_list)
                elif not image_record.status_fetched or (
                    image_record.status_fetched and not images_list
                ):
                    # 情况2：无图片且未获取过，或已获取过但结果为空（可能ComfyUI还在处理）
                    # 允许重新获取，避免ComfyUI未完成时过早标记为已获取
                    if image_record.status_fetched and not images_list:
                        logger.warning(
                            f"ComfyUI任务 {prompt_id}: 之前获取时无图片，尝试重新获取"
                        )

                    logger.info(f"ComfyUI任务 {prompt_id}: 从ComfyUI API获取图片")
                    prompt_id_str: str = cast("str", prompt_id)
                    images = await self._fetch_images_from_comfyui(prompt_id_str)

                    # 更新数据库
                    image_record.images = json.dumps(images)  # type: ignore[assignment]
                    image_record.status_fetched = True  # type: ignore[assignment]
                    image_record.fetched_at = datetime.now()  # type: ignore[assignment]
                    db.commit()

                    all_images.extend(images)
                else:
                    # 情况3：已获取过但无图片（ComfyUI 失败）
                    logger.warning(f"ComfyUI任务 {prompt_id}: 已获取过但无图片")

            return SceneGalleryResponse(task_id=task_id, images=all_images)

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

            return SceneGalleryResponse(task_id=task_id, images=image_list)
        except Exception as e:
            logger.error(f"从旧表获取图片失败: {e}")
            # 旧表查询失败，返回空列表而不是抛出异常
            return SceneGalleryResponse(task_id=task_id, images=[])

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
            deleted = False

            # 在每个 ComfyUI 图片记录中查找并删除指定图片
            for prompt_id in comfyui_prompt_ids:
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

                        # 检查图片是否在列表中
                        if request.filename in images_list:
                            # 删除图片
                            images_list.remove(request.filename)
                            # 更新数据库
                            image_record.images = json.dumps(images_list)  # type: ignore[assignment]
                            db.commit()
                            deleted = True
                            logger.info(
                                f"成功从 ComfyUI 任务 {prompt_id} 中删除图片: {request.filename}"
                            )
                    except json.JSONDecodeError:
                        logger.error(f"ComfyUI任务 {prompt_id}: 图片数据格式错误")
                        continue

            if not deleted:
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
                    task_id=request.task_id, comfyui_prompt_id=prompt_id
                )
                db.add(task_mapping)

                # 记录空的图片记录（标记为未获取）
                image_record = SceneComfyUIImages(
                    comfyui_prompt_id=prompt_id, images="[]", status_fetched=False
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
