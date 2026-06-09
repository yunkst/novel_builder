#!/usr/bin/env python3

from datetime import datetime
from typing import Any
from urllib.parse import urlparse

from sqlalchemy.orm import Session
from sqlalchemy.sql import func

from ..models import ChapterCache


class CacheService:
    """章节缓存服务"""

    @staticmethod
    def _extract_source(url: str) -> str:
        """从URL中提取来源站点"""
        try:
            parsed = urlparse(url)
            domain = parsed.netloc
            # 提取主域名
            if domain.startswith("www."):
                domain = domain[4:]
            return domain
        except (ValueError, AttributeError):
            return "unknown"

    @staticmethod
    def get_chapter_content(db: Session, chapter_url: str) -> dict[str, Any] | None:
        """
        获取缓存的章节内容

        Args:
            db: 数据库会话
            chapter_url: 章节URL

        Returns:
            章节内容字典，如果缓存不存在则返回 None
        """
        try:
            cache = (
                db.query(ChapterCache).filter(ChapterCache.url == chapter_url).first()
            )
            if cache:
                # 更新访问统计
                cache.access_count += 1
                cache.last_accessed_at = datetime.now()
                db.commit()
                return cache.to_dict()
            return None
        except (OSError, ValueError, AttributeError, TypeError) as e:
            print(f"⚠️ 获取缓存失败: {e}")
            db.rollback()
            return None

    @staticmethod
    def set_chapter_content(
        db: Session, chapter_url: str, title: str, content: str
    ) -> bool:
        """
        设置章节内容缓存（如果已存在则更新）

        Args:
            db: 数据库会话
            chapter_url: 章节URL
            title: 章节标题
            content: 章节内容

        Returns:
            是否设置成功
        """
        try:
            source = CacheService._extract_source(chapter_url)

            # 查找是否已存在
            cache = (
                db.query(ChapterCache).filter(ChapterCache.url == chapter_url).first()
            )

            if cache:
                # 更新现有缓存
                cache.title = title
                cache.content = content
                cache.updated_at = datetime.now()
                cache.access_count += 1
                cache.last_accessed_at = datetime.now()
            else:
                # 创建新缓存
                cache = ChapterCache(
                    url=chapter_url,
                    title=title,
                    content=content,
                    source=source,
                    access_count=1,
                )
                db.add(cache)

            db.commit()
            return True
        except (OSError, ValueError, AttributeError, TypeError) as e:
            print(f"⚠️ 设置缓存失败: {e}")
            db.rollback()
            return False

    @staticmethod
    def delete_chapter_content(db: Session, chapter_url: str) -> bool:
        """
        删除章节内容缓存

        Args:
            db: 数据库会话
            chapter_url: 章节URL

        Returns:
            是否删除成功
        """
        try:
            cache = (
                db.query(ChapterCache).filter(ChapterCache.url == chapter_url).first()
            )
            if cache:
                db.delete(cache)
                db.commit()
                return True
            return False
        except (OSError, ValueError, AttributeError, TypeError) as e:
            print(f"⚠️ 删除缓存失败: {e}")
            db.rollback()
            return False

    @staticmethod
    def get_cache_stats(db: Session) -> dict[str, Any]:
        """
        获取缓存统计信息

        Args:
            db: 数据库会话

        Returns:
            包含缓存统计信息的字典
        """
        try:
            total_count = db.query(ChapterCache).count()

            # 按来源统计
            source_stats = (
                db.query(
                    ChapterCache.source, func.count(ChapterCache.id).label("count")
                )
                .group_by(ChapterCache.source)
                .all()
            )

            # 最热门的章节
            hot_chapters = (
                db.query(ChapterCache)
                .order_by(ChapterCache.access_count.desc())
                .limit(10)
                .all()
            )

            return {
                "total_chapters": total_count,
                "by_source": {row.source: row.count for row in source_stats},
                "hot_chapters": [
                    {
                        "url": ch.url,
                        "title": ch.title,
                        "access_count": ch.access_count,
                        "last_accessed": ch.last_accessed_at.isoformat()
                        if ch.last_accessed_at
                        else None,
                    }
                    for ch in hot_chapters
                ],
            }
        except (OSError, ValueError, AttributeError, TypeError) as e:
            return {"error": f"获取统计信息失败: {e}"}

    @staticmethod
    def clear_old_cache(db: Session, days: int = 30) -> int:
        """
        清除旧缓存（超过指定天数未访问的章节）

        Args:
            db: 数据库会话
            days: 天数阈值

        Returns:
            删除的记录数
        """
        try:
            from datetime import datetime, timedelta

            threshold = datetime.now() - timedelta(days=days)

            result = (
                db.query(ChapterCache)
                .filter(ChapterCache.last_accessed_at < threshold)
                .delete()
            )

            db.commit()
            return result
        except (OSError, ValueError, AttributeError, TypeError) as e:
            print(f"⚠️ 清理缓存失败: {e}")
            db.rollback()
            return 0
