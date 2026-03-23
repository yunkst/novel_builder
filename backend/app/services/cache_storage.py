#!/usr/bin/env python3
"""
缓存存储层

封装数据库操作，提供统一的缓存读写接口。
支持章节内容和章节列表的缓存存储。
"""

from datetime import datetime
from typing import Any

from sqlalchemy.orm import Session

from ..database import SESSION_LOCAL
from ..models.cache import ChapterCache
from ..models.chapter_list_cache import ChapterListCache
from .cache_types import CacheType


class CacheStorage:
    """
    缓存存储层

    封装所有数据库操作，提供统一的缓存读写接口。
    支持章节内容和章节列表两种缓存类型。
    """

    def __init__(self, db: Session | None = None):
        """
        初始化缓存存储层

        Args:
            db: 可选的数据库会话，如果不提供则使用上下文管理器创建
        """
        self._db = db
        self._owns_session = db is None

    def __enter__(self):
        """上下文管理器入口"""
        if self._owns_session:
            self._db = SESSION_LOCAL()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """上下文管理器出口"""
        if self._owns_session and self._db:
            if exc_type:
                self._db.rollback()
            else:
                self._db.commit()
            self._db.close()

    @property
    def db(self) -> Session:
        """获取数据库会话"""
        if not self._db:
            raise RuntimeError("Database session not initialized")
        return self._db

    def get_chapter_content(self, chapter_url: str) -> dict[str, Any] | None:
        """
        获取章节内容缓存

        Args:
            chapter_url: 章节 URL

        Returns:
            dict | None: 缓存的章节内容，包含 title 和 content，如果不存在则返回 None
        """
        cache_entry = (
            self.db.query(ChapterCache)
            .filter(ChapterCache.chapter_url == chapter_url)
            .first()
        )

        if not cache_entry:
            return None

        return {
            "title": cache_entry.chapter_title,
            "content": cache_entry.chapter_content,
            "word_count": cache_entry.word_count,
            "from_cache": True,
        }

    def save_chapter_content(
        self,
        chapter_url: str,
        chapter_title: str,
        chapter_content: str,
        novel_url: str,
        word_count: int | None = None,
        chapter_index: int = 0,
        task_id: int | None = None,
    ) -> ChapterCache:
        """
        保存章节内容缓存

        Args:
            chapter_url: 章节 URL
            chapter_title: 章节标题
            chapter_content: 章节内容
            novel_url: 小说 URL
            word_count: 字数（可选，如果不提供则自动计算）
            chapter_index: 章节索引
            task_id: 缓存任务 ID（可选）

        Returns:
            ChapterCache: 保存的缓存记录
        """
        # 计算字数（如果未提供）
        if word_count is None:
            word_count = len(chapter_content.strip())

        # 查找是否已存在
        existing = (
            self.db.query(ChapterCache)
            .filter(ChapterCache.chapter_url == chapter_url)
            .first()
        )

        if existing:
            # 更新现有记录
            existing.chapter_title = chapter_title
            existing.chapter_content = chapter_content
            existing.word_count = word_count
            existing.novel_url = novel_url
            existing.chapter_index = chapter_index
            existing.cached_at = datetime.now()
            if task_id is not None:
                existing.task_id = task_id

            self.db.commit()
            self.db.refresh(existing)
            return existing

        # 创建新记录
        cache_entry = ChapterCache(
            chapter_url=chapter_url,
            chapter_title=chapter_title,
            chapter_content=chapter_content,
            word_count=word_count,
            novel_url=novel_url,
            chapter_index=chapter_index,
            cached_at=datetime.now(),
            task_id=task_id,
        )

        self.db.add(cache_entry)
        self.db.commit()
        self.db.refresh(cache_entry)

        return cache_entry

    def delete_chapter_content(self, chapter_url: str) -> bool:
        """
        删除章节内容缓存

        Args:
            chapter_url: 章节 URL

        Returns:
            bool: 是否删除成功
        """
        deleted = (
            self.db.query(ChapterCache)
            .filter(ChapterCache.chapter_url == chapter_url)
            .delete()
        )

        self.db.commit()
        return deleted > 0

    def get_chapter_list(self, novel_url: str) -> list[dict[str, Any]] | None:
        """
        获取章节列表缓存

        Args:
            novel_url: 小说 URL

        Returns:
            list[dict] | None: 缓存的章节列表，每个元素包含 title 和 url，如果不存在则返回 None
        """
        cache_entry = (
            self.db.query(ChapterListCache)
            .filter(ChapterListCache.novel_url == novel_url)
            .first()
        )

        if not cache_entry:
            return None

        # 返回章节数据，标记来自缓存
        chapters = cache_entry.chapters_json
        if chapters:
            # 确保返回的是列表
            if isinstance(chapters, list):
                return chapters
            # 如果是字典，尝试提取 chapters 字段
            if isinstance(chapters, dict) and "chapters" in chapters:
                return chapters["chapters"]

        return None

    def save_chapter_list(
        self,
        novel_url: str,
        chapters: list[dict[str, Any]],
    ) -> ChapterListCache:
        """
        保存章节列表缓存

        Args:
            novel_url: 小说 URL
            chapters: 章节列表，每个元素应包含 title 和 url

        Returns:
            ChapterListCache: 保存的缓存记录
        """
        # 查找是否已存在
        existing = (
            self.db.query(ChapterListCache)
            .filter(ChapterListCache.novel_url == novel_url)
            .first()
        )

        current_time = datetime.now()

        if existing:
            # 更新现有记录
            existing.chapters_json = chapters
            existing.updated_at = current_time
            self.db.commit()
            self.db.refresh(existing)
            return existing

        # 创建新记录
        cache_entry = ChapterListCache(
            novel_url=novel_url,
            chapters_json=chapters,
            cached_at=current_time,
            updated_at=current_time,
        )

        self.db.add(cache_entry)
        self.db.commit()
        self.db.refresh(cache_entry)

        return cache_entry

    def delete_chapter_list(self, novel_url: str) -> bool:
        """
        删除章节列表缓存

        Args:
            novel_url: 小说 URL

        Returns:
            bool: 是否删除成功
        """
        deleted = (
            self.db.query(ChapterListCache)
            .filter(ChapterListCache.novel_url == novel_url)
            .delete()
        )

        self.db.commit()
        return deleted > 0

    def clear_all_cache(self, cache_type: CacheType | None = None) -> int:
        """
        清除所有缓存

        Args:
            cache_type: 缓存类型，如果为 None 则清除所有类型

        Returns:
            int: 清除的记录数
        """
        total_deleted = 0

        if cache_type is None or cache_type == CacheType.CHAPTER_CONTENT:
            deleted = self.db.query(ChapterCache).delete()
            total_deleted += deleted

        if cache_type is None or cache_type == CacheType.CHAPTER_LIST:
            deleted = self.db.query(ChapterListCache).delete()
            total_deleted += deleted

        self.db.commit()
        return total_deleted

    def get_cache_stats(self) -> dict[str, Any]:
        """
        获取缓存统计信息

        Returns:
            dict: 包含各类缓存数量的统计信息
        """
        from sqlalchemy import func

        chapter_content_count = self.db.query(ChapterCache).count()
        chapter_list_count = self.db.query(ChapterListCache).count()

        # 使用聚合函数计算总字数，避免内存问题
        total_word_count = (
            self.db.query(func.sum(ChapterCache.word_count))
            .scalar()
        ) or 0

        return {
            "chapter_content_count": chapter_content_count,
            "chapter_list_count": chapter_list_count,
            "total_word_count": total_word_count,
        }
