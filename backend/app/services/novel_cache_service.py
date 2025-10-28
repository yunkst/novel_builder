#!/usr/bin/env python3

import asyncio
import logging
from datetime import datetime

from fastapi import WebSocket
from sqlalchemy.orm import Session

from ..database import DatabaseSession
from ..models.cache import CacheTask
from ..models.cache import ChapterCache as NovelChapterCache
from .crawler_factory import get_crawler_for_url

logger = logging.getLogger(__name__)


class NovelCacheService:
    """小说缓存服务类"""

    def __init__(self):
        self.active_tasks: dict[int, str] = {}  # task_id -> status
        self.websocket_connections: dict[
            int, list[WebSocket]
        ] = {}  # task_id -> list of websockets

    async def create_cache_task(self, novel_url: str, db: Session) -> CacheTask:
        """
        创建缓存任务

        Args:
            novel_url: 小说URL
            db: 数据库会话

        Returns:
            CacheTask: 创建的缓存任务
        """
        logger.info(f"创建缓存任务: {novel_url}")

        # 1. 获取爬虫实例
        crawler = get_crawler_for_url(novel_url)
        if not crawler:
            raise ValueError(f"不支持的网站: {novel_url}")

        # 2. 获取章节列表
        try:
            chapters = crawler.get_chapter_list(novel_url)
            if not chapters:
                raise ValueError("无法获取章节列表")
        except Exception as e:
            logger.error(f"获取章节列表失败: {e}")
            raise ValueError(f"获取章节列表失败: {e!s}")

        # 3. 创建缓存任务记录
        novel_title = chapters[0].get("novel_title", "") if chapters else ""
        novel_author = chapters[0].get("novel_author", "") if chapters else ""

        # 检查是否已有相同URL的未完成任务
        existing_task = (
            db.query(CacheTask)
            .filter(
                CacheTask.novel_url == novel_url,
                CacheTask.status.in_(["pending", "running"]),
            )
            .first()
        )

        if existing_task:
            logger.info(f"发现已存在的缓存任务: {existing_task.id}")
            return existing_task

        task = CacheTask(
            novel_url=novel_url,
            novel_title=novel_title,
            novel_author=novel_author,
            total_chapters=len(chapters),
            status="pending",
        )

        db.add(task)
        db.commit()
        db.refresh(task)

        logger.info(
            f"缓存任务创建成功: task_id={task.id}, total_chapters={len(chapters)}"
        )

        # 4. 启动后台缓存任务 (fire-and-forget 任务，无需等待完成)
        asyncio.create_task(self._cache_chapters(int(task.id), chapters, novel_url))  # noqa: RUF006

        return task

    async def _cache_chapters(self, task_id: int, chapters: list[dict], novel_url: str):
        """
        后台缓存章节内容

        Args:
            task_id: 任务ID
            chapters: 章节列表
            novel_url: 小说URL
        """
        self.active_tasks[task_id] = "running"
        logger.info(f"开始后台缓存任务: {task_id}")

        try:
            # 更新任务状态为运行中
            with DatabaseSession() as db:
                task = db.query(CacheTask).filter(CacheTask.id == task_id).first()
                if not task:
                    logger.error(f"任务不存在: {task_id}")
                    return

                task.status = "running"
                task.updated_at = datetime.now()
                db.commit()

            # 获取爬虫实例
            crawler = get_crawler_for_url(novel_url)

            if not crawler:
                raise ValueError(f"不支持的网站: {novel_url}")

            # 遍历章节进行缓存
            for i, chapter in enumerate(chapters):
                # 检查任务是否被取消
                if (
                    task_id not in self.active_tasks
                    or self.active_tasks[task_id] == "cancelled"
                ):
                    logger.info(f"任务被取消: {task_id}")
                    break

                chapter_url = chapter.get("url", "")
                chapter_title = chapter.get("title", f"第{i + 1}章")

                logger.info(f"缓存章节 {i + 1}/{len(chapters)}: {chapter_title}")

                try:
                    # 检查章节是否已缓存
                    with DatabaseSession() as db:
                        existing_chapter = (
                            db.query(NovelChapterCache)
                            .filter(NovelChapterCache.chapter_url == chapter_url)
                            .first()
                        )

                        if existing_chapter:
                            logger.info(f"章节已存在，跳过: {chapter_title}")
                        else:
                            # 获取章节内容
                            content_data = crawler.get_chapter_content(chapter_url)
                            content = content_data.get("content", "")

                            if not content:
                                logger.warning(f"章节内容为空: {chapter_title}")
                                continue

                            # 保存到数据库
                            cached_chapter = NovelChapterCache(
                                task_id=task_id,
                                novel_url=novel_url,
                                chapter_title=chapter_title,
                                chapter_url=chapter_url,
                                chapter_content=content,
                                chapter_index=i,
                                word_count=len(content),
                            )
                            db.add(cached_chapter)

                        # 更新任务进度
                        task = (
                            db.query(CacheTask).filter(CacheTask.id == task_id).first()
                        )
                        task.cached_chapters = i + 1
                        task.updated_at = datetime.now()

                        # 发送进度更新到WebSocket连接
                        await self._notify_progress_update(task_id, db)

                    # 添加延迟避免过于频繁的请求
                    await asyncio.sleep(1)

                except Exception as e:
                    logger.error(f"缓存章节失败 {chapter_title}: {e}")

                    # 记录失败的章节
                    with DatabaseSession() as db:
                        task = (
                            db.query(CacheTask).filter(CacheTask.id == task_id).first()
                        )
                        task.failed_chapters += 1

                    continue

            # 标记任务完成
            with DatabaseSession() as db:
                task = db.query(CacheTask).filter(CacheTask.id == task_id).first()
                task.status = "completed"
                task.completed_at = datetime.now()
                task.updated_at = datetime.now()

            logger.info(f"缓存任务完成: {task_id}")

        except Exception as e:
            logger.error(f"缓存任务失败 {task_id}: {e}")

            # 标记任务失败
            try:
                with DatabaseSession() as db:
                    task = db.query(CacheTask).filter(CacheTask.id == task_id).first()
                    if task:
                        task.status = "failed"
                        task.error_message = str(e)
                        task.updated_at = datetime.now()
            except Exception as db_error:
                logger.error(f"更新任务状态失败: {db_error}")

        finally:
            self.active_tasks.pop(task_id, None)
            # 发送最终状态更新
            await self._notify_progress_update(task_id, None)

    async def _notify_progress_update(self, task_id: int, db: Session | None):
        """通知进度更新到WebSocket连接"""
        if task_id not in self.websocket_connections:
            return

        try:
            # 获取任务进度
            if db:
                task = db.query(CacheTask).filter(CacheTask.id == task_id).first()
            else:
                with DatabaseSession() as db_session:
                    task = (
                        db_session.query(CacheTask)
                        .filter(CacheTask.id == task_id)
                        .first()
                    )

            if not task:
                return

            progress_data = {
                "task_id": task_id,
                "status": task.status,
                "total_chapters": task.total_chapters,
                "cached_chapters": task.cached_chapters,
                "failed_chapters": task.failed_chapters,
                "progress": (task.cached_chapters / task.total_chapters * 100)
                if task.total_chapters > 0
                else 0,
                "updated_at": task.updated_at.isoformat() if task.updated_at else None,
                "error_message": task.error_message,
            }

            # 发送到所有连接的WebSocket
            disconnected_websockets = []
            for websocket in self.websocket_connections[task_id]:
                try:
                    await websocket.send_json(progress_data)
                except Exception as e:
                    logger.warning(f"WebSocket发送失败: {e}")
                    disconnected_websockets.append(websocket)

            # 清理断开的连接
            for ws in disconnected_websockets:
                self.websocket_connections[task_id].remove(ws)

        except Exception as e:
            logger.error(f"发送进度更新失败: {e}")

    async def get_task_status(self, task_id: int, db: Session) -> CacheTask | None:
        """获取任务状态"""
        return db.query(CacheTask).filter(CacheTask.id == task_id).first()

    async def get_cache_tasks(
        self,
        status: str | None = None,
        limit: int = 20,
        offset: int = 0,
        db: Session | None = None,
    ) -> list[CacheTask]:
        """获取缓存任务列表"""
        if db is None:
            with DatabaseSession() as session:
                db = session
        query = db.query(CacheTask)

        if status:
            query = query.filter(CacheTask.status == status)

        return (
            query.order_by(CacheTask.created_at.desc())
            .offset(offset)
            .limit(limit)
            .all()
        )

    async def get_cached_chapters(
        self, task_id: int, db: Session
    ) -> list[NovelChapterCache]:
        """获取已缓存的章节"""
        return (
            db.query(NovelChapterCache)
            .filter(NovelChapterCache.task_id == task_id)
            .order_by(NovelChapterCache.chapter_index)
            .all()
        )

    async def cancel_task(self, task_id: int, db: Session) -> bool:
        """取消缓存任务"""
        task = db.query(CacheTask).filter(CacheTask.id == task_id).first()
        if not task:
            return False

        if task.status in ["pending", "running"]:
            db.query(CacheTask).filter(CacheTask.id == task_id).update(
                {"status": "cancelled", "updated_at": datetime.now()}
            )
            db.commit()

            # 标记后台任务为取消
            self.active_tasks[task_id] = "cancelled"

            logger.info(f"任务已取消: {task_id}")
            return True

        return False

    async def add_websocket_connection(self, task_id: int, websocket: WebSocket):
        """添加WebSocket连接"""
        if task_id not in self.websocket_connections:
            self.websocket_connections[task_id] = []
        self.websocket_connections[task_id].append(websocket)

    async def remove_websocket_connection(self, task_id: int, websocket: WebSocket):
        """移除WebSocket连接"""
        if task_id in self.websocket_connections:
            try:
                self.websocket_connections[task_id].remove(websocket)
                if not self.websocket_connections[task_id]:
                    del self.websocket_connections[task_id]
            except ValueError:
                pass


# 全局缓存服务实例
novel_cache_service = NovelCacheService()
