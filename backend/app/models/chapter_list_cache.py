#!/usr/bin/env python3
"""
Chapter list cache model for caching novel chapter lists.

This module provides database model for caching chapter lists to avoid
repeated crawling of the same novel's chapter directory.
"""

from datetime import datetime

from sqlalchemy import Column, DateTime, Index, String, Text
from sqlalchemy.dialects.postgresql import JSONB

from ..database import Base


class ChapterListCache(Base):
    """章节列表缓存表

    缓存小说的章节列表，避免重复爬取章节目录。
    缓存永久有效，除非手动清除或使用 force_refresh 强制刷新。
    """

    __tablename__ = "chapter_list_cache"

    # 小说 URL 作为主键
    novel_url = Column(String(500), primary_key=True, nullable=False)

    # 章节列表（JSONB 格式存储完整响应）
    chapters_json = Column(JSONB, nullable=False)

    # 缓存时间
    cached_at = Column(DateTime, default=datetime.now, nullable=False)

    # 更新时间
    updated_at = Column(
        DateTime, default=datetime.now, onupdate=datetime.now, nullable=False
    )

    # 索引
    __table_args__ = (
        Index("idx_cached_at", "cached_at"),
        Index("idx_updated_at", "updated_at"),
    )
