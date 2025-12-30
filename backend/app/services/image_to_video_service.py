"""
图生视频服务.

本章提供图生视频功能的业务逻辑，包括任务管理、视频生成和状态查询。
"""

import base64
import json
import logging
from datetime import datetime
from typing import Any

from sqlalchemy.orm import Session

from ..constants import TIMEOUT_SLOW
from ..models.scene_illustration import SceneImageGallery
from ..models.text2img import ImageToVideoTask, RoleImageGallery
from ..models.video_status import ImageVideoStatus
from ..schemas import (
    ImageToVideoRequest,
    ImageToVideoResponse,
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

    async def create_video_generation_task(
        self, request: ImageToVideoRequest, db: Session
    ) -> ImageToVideoResponse:
        """创建视频生成任务.

        Args:
            request: 图生视频请求
            db: 数据库会话

        Returns:
            任务创建响应
        """
        try:
            # 1. 检查是否已经有正在进行的视频生成
            video_status = (
                db.query(ImageVideoStatus)
                .filter(ImageVideoStatus.img_name == request.img_name)
                .first()
            )

            if video_status and video_status.video_status in ["pending", "running"]:
                logger.info(f"图片 {request.img_name} 正在生成视频，返回现有任务")
                return ImageToVideoResponse(
                    task_id=video_status.current_task_id or 0,
                    img_name=request.img_name,
                    status=video_status.video_status,
                    message="正在生成视频，请稍候",
                )

            # 2. 查询图片信息（统一处理所有来源）
            image_record, source_type = self._find_image_record(request.img_name, db)

            if not image_record:
                raise ValueError(f"图片 {request.img_name} 不存在于数据库中")

            logger.info(f"找到图片 {request.img_name}，来源: {source_type}")

            # 从数据库记录获取原始prompt（所有来源统一处理）
            if image_record and hasattr(image_record, "prompt"):
                original_prompt = image_record.prompt
            else:
                # 兜底情况：如果没有prompt，使用user_input
                original_prompt = (
                    request.user_input if request.user_input else "一个美丽的场景"
                )

            # 使用工具函数验证并获取有效的模型名称
            from ..utils.model_validation import validate_and_get_model

            model_name = validate_and_get_model(request.model_name, "I2V")

            # 3. 创建或更新视频状态记录
            if not video_status:
                video_status = ImageVideoStatus(
                    img_name=request.img_name,
                    source_type=source_type,
                    original_prompt=original_prompt,
                    has_video=False,
                    video_status="none",
                )
                db.add(video_status)
                db.flush()

            # 4. 创建新的视频生成任务
            video_task = ImageToVideoTask(
                img_name=request.img_name,
                status="pending",
                model_name=model_name,  # 使用处理后的model_name
                user_input=request.user_input,
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
                # 创建异步任务并添加异常处理回调
                async_task = asyncio.create_task(
                    self._process_video_generation_async(
                        task_id=video_task.id,
                        img_name=request.img_name,
                        model_name=model_name,  # 使用处理后的model_name
                        user_input=request.user_input,
                        db=db,
                    )
                )

                # 添加异常回调，防止异常被静默忽略
                def handle_task_exception(task: asyncio.Task) -> None:
                    try:
                        exception = task.exception()
                        if exception:
                            logger.error(
                                f"异步视频生成任务失败: task_id={video_task.id}, error={exception}"
                            )
                            # 这里可以添加额外的错误恢复逻辑
                    except (AttributeError, RuntimeError) as e:
                        logger.error(f"处理任务异常时出错: {e}")

                async_task.add_done_callback(handle_task_exception)

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
                message="视频生成任务已创建，正在处理中",
            )

        except ValueError as e:
            logger.error(f"创建视频生成任务失败: {e}")
            raise
        except (OSError, AttributeError, KeyError, RuntimeError, TypeError) as e:
            logger.error(f"创建视频生成任务异常: {e}")
            db.rollback()
            raise RuntimeError(f"创建任务失败: {e!s}")

    def _find_image_record(self, img_name: str, db: Session) -> tuple:
        """查找图片记录，支持角色卡、场面绘制和ComfyUI任务三种来源.

        Args:
            img_name: 图片名称
            db: 数据库会话

        Returns:
            (image_record, source_type) - 图片记录和来源类型
            source_type: 'role' 或 'scene' 或 'comfyui'
        """
        # 1. 先从角色卡图片表中查找
        image_record = (
            db.query(RoleImageGallery)
            .filter(RoleImageGallery.img_url == img_name)
            .first()
        )

        if image_record:
            return image_record, "role"

        # 2. 再从场面绘制图片表中查找
        image_record = (
            db.query(SceneImageGallery)
            .filter(SceneImageGallery.img_url == img_name)
            .first()
        )

        if image_record:
            return image_record, "scene"

        # 3. 最后从ComfyUI任务映射表中查找（通过图片文件名）
        try:
            from ..models.scene_comfyui_mapping import (
                SceneComfyUITask,
                SceneComfyUIImages,
            )
            from ..models.scene_illustration import SceneIllustrationTask

            # 在所有ComfyUI任务的images字段中搜索该图片文件名
            comfyui_records = (
                db.query(SceneComfyUIImages)
                .filter(SceneComfyUIImages.images.like(f"%{img_name}%"))
                .all()
            )

            for comfyui_record in comfyui_records:
                # 解析图片列表
                images_list = (
                    json.loads(comfyui_record.images) if comfyui_record.images else []
                )
                # 精确匹配图片文件名
                if img_name in images_list:
                    # 查询对应的业务任务，获取原始prompts
                    task_mapping = (
                        db.query(SceneComfyUITask)
                        .filter(
                            SceneComfyUITask.comfyui_prompt_id
                            == comfyui_record.comfyui_prompt_id
                        )
                        .first()
                    )

                    if task_mapping:
                        # 查询业务任务表获取prompts
                        task_record = (
                            db.query(SceneIllustrationTask)
                            .filter(
                                SceneIllustrationTask.task_id == task_mapping.task_id
                            )
                            .first()
                        )

                        if task_record and task_record.prompts:
                            # 创建一个伪记录对象，包含原始prompt
                            class PseudoImageRecord:
                                def __init__(self, img_name, prompt, created_at):
                                    self.img_url = img_name
                                    self.prompt = prompt
                                    self.created_at = created_at

                            logger.info(
                                f"在ComfyUI任务表中找到图片: {img_name}, "
                                f"原始prompt: {task_record.prompts[:100]}..."
                            )
                            return (
                                PseudoImageRecord(
                                    img_name,
                                    task_record.prompts,
                                    comfyui_record.created_at,
                                ),
                                "comfyui",
                            )

                    # 如果找不到任务记录，返回默认prompt
                    logger.warning(
                        f"ComfyUI图片 {img_name} 找不到对应的任务记录，使用默认prompt"
                    )
                    class PseudoImageRecord:
                        def __init__(self, img_name, prompt, created_at):
                            self.img_url = img_name
                            self.prompt = prompt
                            self.created_at = created_at

                    return (
                        PseudoImageRecord(
                            img_name, "一个美丽的场景", comfyui_record.created_at
                        ),
                        "comfyui",
                    )
        except Exception as e:
            logger.warning(f"从ComfyUI映射表查找图片失败: {e}")

        return None, None

    async def _process_video_generation_async(
        self, task_id: int, img_name: str, model_name: str, user_input: str, db: Session
    ) -> None:
        """异步处理视频生成.

        Args:
            task_id: 任务ID
            img_name: 图片名称
            model_name: 模型名称（用于日志记录）
            user_input: 用户要求
            db: 数据库会话
        """
        try:
            task_db = db

            logger.info(
                f"开始处理视频生成任务 {task_id}, 使用模型: {model_name}, 图片: {img_name}"
            )

            # 更新任务状态为运行中
            task = (
                task_db.query(ImageToVideoTask)
                .filter(ImageToVideoTask.id == task_id)
                .first()
            )
            if not task:
                logger.error(f"任务 {task_id} 不存在")
                return

            task.status = "running"
            task.started_at = datetime.now()

            # 更新独立状态表为running
            video_status = (
                task_db.query(ImageVideoStatus)
                .filter(ImageVideoStatus.img_name == img_name)
                .first()
            )
            if video_status:
                video_status.video_status = "running"
                video_status.current_task_id = task_id

            task_db.commit()

            # 1. 查询图片信息（统一处理所有来源）
            image_record, source_type = self._find_image_record(img_name, task_db)

            if not image_record:
                raise ValueError(f"图片 {img_name} 不存在于数据库中")

            logger.info(f"找到图片 {img_name}，来源: {source_type}")

            # 从数据库记录获取原始prompt（所有来源统一处理）
            if image_record and hasattr(image_record, "prompt"):
                original_prompt = image_record.prompt
            else:
                # 兜底情况：如果没有prompt，使用user_input
                original_prompt = user_input if user_input else "一个美丽的场景"

            logger.info(f"调用Dify生成视频提示词，原始提示词: {original_prompt}")
            video_prompt = await self.dify_client.generate_video_prompts(
                prompts=original_prompt, user_input=user_input
            )

            if not video_prompt:
                raise ValueError("Dify生成视频提示词失败")

            # 更新任务的视频提示词
            task.video_prompt = video_prompt
            task_db.commit()

            # 3. 直接调用ComfyUI生成视频（ComfyUI会通过文件名自动下载图片）
            logger.info(f"调用ComfyUI生成视频，提示词: {video_prompt[:100]}...")
            comfyui_task_id = await self.comfyui_client.generate_video_from_image(
                video_prompt=video_prompt, image_filename=img_name
            )

            if not comfyui_task_id:
                raise ValueError("ComfyUI视频生成任务创建失败")

            # 4. 更新独立状态表，存储ComfyUI任务ID，但不等待完成
            video_status = (
                task_db.query(ImageVideoStatus)
                .filter(ImageVideoStatus.img_name == img_name)
                .first()
            )
            if video_status:
                video_status.video_prompt = video_prompt
                # 将ComfyUI任务ID存储在专用字段中
                video_status.video_comfyui_task_id = comfyui_task_id
                # 保持状态为running，让查询时检查
                video_status.current_task_id = None  # 清理当前任务ID

            # 5. 更新任务状态为已提交
            task.status = "running"  # 表示已提交到ComfyUI，等待查询时检查
            task.video_prompt = video_prompt
            task_db.commit()

            logger.info(
                f"ComfyUI视频任务已提交，任务ID: {comfyui_task_id}，等待用户查询时检查状态"
            )

        except (OSError, ValueError, AttributeError, KeyError, RuntimeError, TypeError) as e:
            logger.error(f"处理视频生成任务失败: {e}")
            try:
                task.status = "failed"
                task.error_message = str(e)
                task.completed_at = datetime.now()

                # 更新独立状态表为失败
                video_status = (
                    task_db.query(ImageVideoStatus)
                    .filter(ImageVideoStatus.img_name == img_name)
                    .first()
                )
                if video_status:
                    video_status.video_status = "failed"
                    video_status.error_message = str(e)
                    video_status.retry_count += 1
                    video_status.current_task_id = None

                task_db.commit()
            except (OSError, ValueError, AttributeError, KeyError):
                pass

    async def _get_image_base64(self, img_name: str) -> str | None:
        """获取图片的base64编码.

        Args:
            img_name: 图片名称

        Returns:
            图片base64编码，失败时返回None
        """
        try:
            # 使用同步requests获取图片数据，和图片代理接口相同的方式

            import requests

            from ..config import settings

            comfyui_url = settings.comfyui_api_url
            image_url = f"{comfyui_url}/view?filename={img_name}"

            response = requests.get(image_url, timeout=TIMEOUT_SLOW)
            if response.status_code == 200:
                image_data = response.content
                # 转换为base64
                image_base64 = base64.b64encode(image_data).decode("utf-8")
                logger.info(
                    f"成功获取图片 {img_name} 的base64数据，大小: {len(image_data)} bytes"
                )
                return image_base64
            else:
                logger.error(f"获取图片失败: {response.status_code}")
                return None

        except (OSError, requests.RequestException, ValueError, base64.binascii.Error) as e:
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
            video_status = (
                db.query(ImageVideoStatus)
                .filter(ImageVideoStatus.img_name == img_name)
                .first()
            )

            if not video_status:
                return VideoStatusResponse(
                    img_name=img_name, has_video=False, video_status="none"
                )

            # 如果状态已完成或失败，直接返回
            if video_status.video_status in ["completed", "failed", "none"]:
                return VideoStatusResponse(
                    img_name=img_name,
                    has_video=video_status.has_video
                    and video_status.video_filename is not None,
                    video_status=video_status.video_status,
                    video_filename=video_status.video_filename,
                )

            # 如果状态是pending或running，需要检查ComfyUI状态
            if video_status.video_status in ["pending", "running"]:
                logger.info(
                    f"图片 {img_name} 状态为 {video_status.video_status}，开始检查ComfyUI状态"
                )
                await self._check_and_update_video_status(video_status, db)
                # 重新查询更新后的状态
                db.refresh(video_status)

            # 返回最终状态
            return VideoStatusResponse(
                img_name=img_name,
                has_video=video_status.has_video
                and video_status.video_filename is not None,
                video_status=video_status.video_status,
                video_filename=video_status.video_filename,
            )

        except (OSError, ValueError, AttributeError, RuntimeError) as e:
            logger.error(f"查询视频状态失败: {e}")
            raise RuntimeError(f"查询视频状态失败: {e!s}")

    async def _check_and_update_video_status(
        self, video_status: ImageVideoStatus, db: Session
    ) -> None:
        """检查并更新视频状态（非阻塞，只检查状态不等待完成）.

        Args:
            video_status: 视频状态记录
            db: 数据库会话
        """
        try:
            # 从专用字段中获取ComfyUI任务ID
            comfyui_task_id = video_status.video_comfyui_task_id

            # 兼容旧数据：如果没有专用字段，尝试从error_message解析
            if not comfyui_task_id and video_status.error_message:
                if video_status.error_message.startswith("comfyui_task_id:"):
                    comfyui_task_id = video_status.error_message.replace(
                        "comfyui_task_id:", ""
                    ).strip()
                    # 迁移到新字段
                    video_status.video_comfyui_task_id = comfyui_task_id
                    video_status.error_message = None

            if not comfyui_task_id:
                logger.error(
                    f"找不到ComfyUI任务ID，无法检查状态: {video_status.img_name}"
                )
                return

            logger.info(f"检查ComfyUI任务状态: {comfyui_task_id}")

            # 只检查任务状态，不等待完成（非阻塞）
            task_info = await self.comfyui_client.check_video_generation_status(
                task_id=comfyui_task_id
            )

            if not task_info:
                # 无法获取任务信息，保持当前状态
                logger.warning(f"无法获取ComfyUI任务信息: {comfyui_task_id}")
                return

            # 检查任务状态
            status = task_info.get("status", {})
            status_str = status.get("status_str", "")

            if status_str in ["completed", "success"]:
                # 任务已完成，提取视频文件名
                outputs = task_info.get("outputs", {})
                video_info = self._extract_video_filename_from_outputs(outputs)

                if video_info:
                    # video_info 已经是完整路径 (subfolder/filename) 或只是 filename
                    video_filename = video_info

                    # 视频生成成功
                    video_status.has_video = True
                    video_status.video_status = "completed"
                    video_status.video_filename = video_filename
                    video_status.video_completed_at = datetime.now()
                    video_status.error_message = None
                    logger.info(
                        f"视频生成成功: {video_status.img_name} -> {video_filename}"
                    )
                else:
                    # 任务完成但未找到视频文件
                    logger.warning(
                        f"ComfyUI任务完成但未找到视频文件: {comfyui_task_id}"
                    )
                    video_status.video_status = "failed"
                    video_status.error_message = "ComfyUI任务完成但未找到视频输出"
                    video_status.retry_count += 1

            elif status_str in ["error", "failed"]:
                # 任务失败
                video_status.video_status = "failed"
                error_messages = status.get("messages", [])
                video_status.error_message = (
                    f"ComfyUI任务失败: {error_messages}"
                    if error_messages
                    else "ComfyUI视频生成失败"
                )
                video_status.retry_count += 1
                logger.error(
                    f"ComfyUI视频生成失败: {video_status.img_name}, 错误: {error_messages}"
                )
            else:
                # 任务仍在运行中，保持running状态
                logger.info(
                    f"ComfyUI任务仍在运行中: {comfyui_task_id}, 状态: {status_str}"
                )

            db.commit()

        except (OSError, ValueError, TimeoutError) as e:
            logger.error(f"检查视频状态异常: {e}")
            video_status.video_status = "failed"
            video_status.error_message = f"状态检查异常: {e!s}"
            video_status.retry_count += 1
            db.commit()

    def _extract_video_filename_from_outputs(self, outputs: dict) -> str | None:
        """从ComfyUI输出中提取视频文件名（通用方法）.

        策略：
        1. 优先查找标记为 save_output=true 的节点
        2. 查找视频合成节点（VHS_VideoCombine）
        3. 查找包含视频文件的任何字段（gifs/videos/images）
        4. 按文件扩展名过滤视频文件

        Args:
            outputs: ComfyUI任务输出

        Returns:
            视频文件完整路径 (subfolder/filename)，失败返回None
        """
        try:
            logger.info(f"ComfyUI返回的outputs结构: {json.dumps(outputs, indent=2, ensure_ascii=False)[:1000]}")

            # 第一优先级：查找save_output=true的节点（最终输出）
            for node_id, node_output in outputs.items():
                # 检查是否是视频合成节点
                if "_meta" in node_output and "class_type" in node_output.get("_meta", {}):
                    class_type = node_output["_meta"].get("class_type", "")
                    if "VideoCombine" in class_type or "Video" in class_type:
                        logger.info(f"找到视频合成节点: {node_id}, class_type: {class_type}")

                        # 检查所有可能的输出字段
                        for field_name in ["gifs", "videos", "images"]:
                            if field_name in node_output:
                                files = node_output[field_name]
                                if isinstance(files, list) and len(files) > 0:
                                    file_info = files[0]  # 取第一个文件
                                    filename = file_info.get("filename")
                                    subfolder = file_info.get("subfolder", "")
                                    file_type = file_info.get("type", "")

                                    if filename:
                                        # 处理Windows路径反斜杠
                                        subfolder = subfolder.replace("\\", "/") if subfolder else ""
                                        filepath = f"{subfolder}/{filename}" if subfolder else filename

                                        logger.info(
                                            f"从视频合成节点提取文件: {filepath}, "
                                            f"字段: {field_name}, type: {file_type}"
                                        )
                                        return filepath

            # 第二优先级：遍历所有节点，查找视频文件
            video_extensions = {".gif", ".mp4", ".webm", ".mkv", ".avi", ".mov", ".flv", ".wmv"}
            video_found = None

            for node_id, node_output in outputs.items():
                # 检查所有可能的输出字段
                for field_name in ["gifs", "videos", "images"]:
                    if field_name not in node_output:
                        continue

                    files = node_output[field_name]
                    if not isinstance(files, list):
                        continue
                    
                    for file_info in files:
                        filename = file_info.get("filename", "")
                        if not filename:
                            continue
                        if file_info['type']=='temp':
                            continue # 临时不要
                        # 检查文件扩展名
                        file_ext = f".{filename.rsplit('.', 1)[-1].lower()}" if "." in filename else ""
                        subfolder = file_info.get("subfolder", "")
                        file_type = file_info.get("type", "")

                        # 判断是否为视频文件
                        is_video = (
                            file_ext in video_extensions
                        )

                        if is_video:
                            # 处理Windows路径反斜杠
                            subfolder = subfolder.replace("\\", "/") if subfolder else ""
                            filepath = f"{subfolder}/{filename}" if subfolder else filename

                            # 优先选择save_output=true的节点
                            if not video_found:
                                video_found = filepath
                                logger.info(f"找到视频文件: {filepath}, 字段: {field_name}")
                            elif "Video/" in filepath or filepath.count("/") > 2:
                                # 看起来更像最终输出（路径包含Video/或层次更深）
                                video_found = filepath
                                logger.info(f"更新为更可能的最终输出: {filepath}")

            if video_found:
                return video_found

            logger.warning("任务完成但未找到视频文件")
            return None

        except (KeyError, AttributeError, TypeError) as e:
            logger.error(f"提取视频文件名失败: {e}")
            return None

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
            video_status = (
                db.query(ImageVideoStatus)
                .filter(ImageVideoStatus.img_name == img_name)
                .first()
            )

            if not video_status or not video_status.video_filename:
                raise ValueError(f"图片 {img_name} 没有对应的视频文件")

            # 从ComfyUI获取视频数据
            # 解析文件名和subfolder
            # 路径格式: "subfolder/filename" 或 "filename" (无subfolder)
            if "/" in video_status.video_filename:
                # 分割路径：最后一部分是filename，其余是subfolder
                path_parts = video_status.video_filename.split("/")
                filename = path_parts[-1]  # 最后一部分是文件名
                subfolder = "/".join(path_parts[:-1]) if len(path_parts) > 1 else ""  # 其余是subfolder
                video_data = await self.comfyui_client.get_video_data(
                    filename, subfolder
                )
            else:
                video_data = await self.comfyui_client.get_video_data(
                    video_status.video_filename
                )
            if not video_data:
                raise ValueError(f"获取视频文件 {video_status.video_filename} 失败")

            logger.info(
                f"成功获取视频文件 {video_status.video_filename}，大小: {len(video_data)} bytes"
            )
            return video_data

        except ValueError as e:
            logger.error(f"获取视频文件失败: {e}")
            raise
        except (OSError, AttributeError, RuntimeError, TimeoutError) as e:
            logger.error(f"获取视频文件异常: {e}")
            raise RuntimeError(f"获取视频文件失败: {e!s}")

    async def health_check(self) -> dict[str, Any]:
        """健康检查.

        Returns:
            健康状态信息
        """
        # 只检查ComfyUI服务
        comfyui_healthy = await self.comfyui_client.health_check()

        return {
            "status": "healthy" if comfyui_healthy else "unhealthy",
            "services": {"comfyui": comfyui_healthy},
        }


# 创建全局服务实例
image_to_video_service = ImageToVideoService()


def create_image_to_video_service() -> ImageToVideoService:
    """创建图生视频服务实例."""
    return image_to_video_service
