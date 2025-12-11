"""
文生图核心业务服务.

本章整合Dify和ComfyUI调用流程，提供完整的文生图业务逻辑。
"""

import asyncio
import logging
from datetime import datetime
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session

from ..models.text2img import ChapterIllustration
from ..schemas import DifyPromptResult, IllustrationItem, Text2ImgStatusResponse
from .comfyui_client import ComfyUIClient, create_comfyui_client
from .dify_client import DifyClient, create_dify_client

logger = logging.getLogger(__name__)


class Text2ImgService:
    """文生图业务服务."""

    def __init__(self, comfyui_client: ComfyUIClient, dify_client: DifyClient):
        """初始化文生图服务.

        Args:
            comfyui_client: ComfyUI客户端
            dify_client: Dify客户端
        """
        self.comfyui_client = comfyui_client
        self.dify_client = dify_client

    async def start_illustration(self, db: Session, chapter_id: str, novel_content: str,
                               roles: Optional[Dict[str, Any]] = None,
                               require: str = "") -> bool:
        """开始章节配图任务.

        Args:
            db: 数据库会话
            chapter_id: 章节ID
            novel_content: 小说内容
            roles: 角色信息
            require: 配图要求

        Returns:
            任务是否成功启动
        """
        try:
            # 检查是否已存在任务
            existing_task = db.query(ChapterIllustration).filter(
                ChapterIllustration.chapter_id == chapter_id
            ).first()

            if existing_task and existing_task.is_processing:
                logger.warning(f"章节 {chapter_id} 已有正在进行的配图任务")
                return False

            # 创建或更新任务记录
            if existing_task:
                task = existing_task
                task.status = "pending"
                task.novel_content = novel_content
                task.roles = roles
                task.require = require
                task.error_message = None
                task.completed_images = 0
                task.total_images = 0
                task.image_data = None
            else:
                task = ChapterIllustration(
                    chapter_id=chapter_id,
                    status="pending",
                    novel_content=novel_content,
                    roles=roles,
                    require=require
                )
                db.add(task)

            db.commit()
            db.refresh(task)

            # 异步启动配图流程
            asyncio.create_task(self._process_illustration_task(db, task.id))

            logger.info(f"章节 {chapter_id} 配图任务已启动")
            logger.info(f"内容长度: {len(novel_content)} 字符")
            logger.info(f"角色信息: {roles if roles else '无'}")
            logger.info(f"配图要求: {require if require else '无'}")
            return True

        except Exception as e:
            logger.error(f"启动章节配图任务失败: {e}")
            db.rollback()
            return False

    async def _process_illustration_task(self, db: Session, task_id: int) -> None:
        """处理配图任务的核心逻辑.

        Args:
            db: 数据库会话
            task_id: 任务ID
        """
        task = None
        try:
            # 获取任务记录
            task = db.query(ChapterIllustration).filter(
                ChapterIllustration.id == task_id
            ).first()

            if not task:
                logger.error(f"任务 {task_id} 不存在")
                return

            # 更新任务状态为处理中
            task.status = "processing"
            task.updated_at = datetime.utcnow()
            db.commit()

            logger.info(f"开始处理章节 {task.chapter_id} 的配图任务")

            # 步骤1: 调用Dify工作流生成提示词
            logger.info("调用Dify工作流生成图片提示词...")
            prompt_results = await self.dify_client.generate_prompts(
                novel_content=task.novel_content,
                roles=task.roles,
                require=task.require
            )

            if not prompt_results:
                raise Exception("Dify工作流未返回有效的提示词结果")

            logger.info(f"Dify返回 {len(prompt_results)} 个图片提示词")

            # 更新任务状态为生成中
            task.status = "generating"
            task.total_images = len(prompt_results)
            task.image_data = []  # 初始化结果数组
            db.commit()

            # 步骤2: 并行调用ComfyUI生成图片
            image_results = await self._generate_images_parallel(prompt_results)

            # 步骤3: 更新任务结果
            task.completed_images = len(image_results)
            task.image_data = image_results

            if len(image_results) == len(prompt_results):
                # 全部图片生成成功
                task.status = "completed"
                task.completed_at = datetime.utcnow()
                logger.info(f"章节 {task.chapter_id} 配图任务完成")
            else:
                # 部分图片生成失败
                task.status = "partial_completed"
                task.error_message = f"部分图片生成失败: {len(image_results)}/{len(prompt_results)}"
                logger.warning(f"章节 {task.chapter_id} 配图任务部分完成")

            db.commit()

        except Exception as e:
            logger.error(f"处理配图任务失败: {e}")
            if task:
                task.status = "failed"
                task.error_message = str(e)
                task.updated_at = datetime.utcnow()
                db.commit()

    async def _generate_images_parallel(self, prompt_results: List[DifyPromptResult]) -> List[Dict[str, Any]]:
        """并行生成图片.

        Args:
            prompt_results: 提示词结果列表

        Returns:
            图片生成结果列表
        """
        tasks = []
        for prompt_result in prompt_results:
            task = self._generate_single_image(prompt_result)
            tasks.append(task)

        # 并行执行所有图片生成任务
        results = await asyncio.gather(*tasks, return_exceptions=True)

        # 处理结果
        image_results = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                logger.error(f"图片 {i} 生成失败: {result}")
            elif result:
                image_results.append(result)

        return image_results

    async def _generate_single_image(self, prompt_result: DifyPromptResult) -> Optional[Dict[str, Any]]:
        """生成单张图片.

        Args:
            prompt_result: 提示词结果

        Returns:
            图片生成结果，失败则返回None
        """
        try:
            logger.info(f"生成第 {prompt_result.index} 段的图片: {prompt_result.img_prompt[:50]}...")

            # 提交ComfyUI图片生成任务
            task_id = await self.comfyui_client.generate_image(prompt_result.img_prompt)

            if not task_id:
                logger.error(f"提交ComfyUI任务失败")
                return None

            # 等待图片生成完成
            image_filenames = await self.comfyui_client.wait_for_completion(task_id)

            if not image_filenames:
                logger.error(f"ComfyUI任务 {task_id} 未生成图片")
                return None

            # 使用第一个生成的图片
            filename = image_filenames[0]
            image_url = self.comfyui_client.get_image_url(filename)

            logger.info(f"图片生成成功: {filename}")

            return {
                "index": prompt_result.index,
                "img_url": image_url,
                "filename": filename,
                "img_prompt": prompt_result.img_prompt
            }

        except Exception as e:
            logger.error(f"生成图片失败: {e}")
            return None

    async def get_illustration_status(self, db: Session, chapter_id: str) -> Text2ImgStatusResponse:
        """获取配图状态.

        Args:
            db: 数据库会话
            chapter_id: 章节ID

        Returns:
            配图状态响应
        """
        task = db.query(ChapterIllustration).filter(
            ChapterIllustration.chapter_id == chapter_id
        ).first()

        if not task:
            return Text2ImgStatusResponse(
                status="not_found",
                message="配图任务不存在"
            )

        if task.status in ["pending", "processing", "generating"]:
            return Text2ImgStatusResponse(
                status="processing",
                message="图片生成中",
                total_images=task.total_images,
                completed_images=task.completed_images
            )

        elif task.status == "completed":
            # 转换图片数据为IllustrationItem列表
            illustrations = []
            if task.image_data:
                for img_data in task.image_data:
                    illustrations.append(IllustrationItem(
                        index=img_data["index"],
                        img_url=img_data["img_url"]
                    ))

            return Text2ImgStatusResponse(
                status="completed",
                message="配图生成完成",
                illustrations=illustrations,
                total_images=task.total_images,
                completed_images=task.completed_images
            )

        elif task.status == "partial_completed":
            # 部分完成
            illustrations = []
            if task.image_data:
                for img_data in task.image_data:
                    illustrations.append(IllustrationItem(
                        index=img_data["index"],
                        img_url=img_data["img_url"]
                    ))

            return Text2ImgStatusResponse(
                status="partial_completed",
                message=f"部分图片生成完成 ({task.completed_images}/{task.total_images})",
                illustrations=illustrations,
                total_images=task.total_images,
                completed_images=task.completed_images
            )

        elif task.status == "failed":
            return Text2ImgStatusResponse(
                status="failed",
                message=task.error_message or "配图任务失败",
                total_images=task.total_images,
                completed_images=task.completed_images
            )

        else:
            return Text2ImgStatusResponse(
                status="unknown",
                message=f"未知状态: {task.status}",
                total_images=task.total_images,
                completed_images=task.completed_images
            )

    async def get_image_data(self, filename: str) -> Optional[bytes]:
        """获取图片二进制数据.

        Args:
            filename: 图片文件名

        Returns:
            图片二进制数据，失败则返回None
        """
        return await self.comfyui_client.get_image_data(filename)

    async def health_check(self) -> Dict[str, bool]:
        """检查文生图服务健康状态.

        Returns:
            各服务组件的健康状态
        """
        comfyui_healthy = await self.comfyui_client.health_check()
        dify_healthy = await self.dify_client.health_check()

        return {
            "comfyui": comfyui_healthy,
            "dify": dify_healthy,
            "overall": comfyui_healthy and dify_healthy
        }


def create_text2img_service() -> Text2ImgService:
    """创建文生图服务实例."""
    comfyui_client = create_comfyui_client()
    dify_client = create_dify_client()

    return Text2ImgService(comfyui_client, dify_client)