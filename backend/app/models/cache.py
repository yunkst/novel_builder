#!/usr/bin/env python3
"""
Cache models for novel caching functionality.

This module contains database models for managing cache tasks and chapter storage.
"""

from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import relationship

from ..database import Base


class CacheTask(Base):
    """缓存任务表"""

    __tablename__ = "novel_cache_tasks"

    id = Column(Integer, primary_key=True, index=True)
    novel_url = Column(String(500), nullable=False, index=True)
    novel_title = Column(String(200), nullable=False)
    novel_author = Column(String(100), nullable=False)
    status = Column(
        String(20), default="pending", index=True
    )  # pending, running, completed, failed, cancelled
    total_chapters = Column(Integer, default=0)
    cached_chapters = Column(Integer, default=0)
    failed_chapters = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)
    completed_at = Column(DateTime, nullable=True)
    error_message = Column(Text, nullable=True)

    # 关联章节缓存
    chapters = relationship(
        "ChapterCache", back_populates="task", cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index("idx_status_created", "status", "created_at"),
        Index("idx_novel_url_status", "novel_url", "status"),
    )


class ChapterCache(Base):
    """章节缓存表"""

    __tablename__ = "novel_chapters_cache"

    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("novel_cache_tasks.id"), nullable=False)
    novel_url = Column(String(500), nullable=False, index=True)
    chapter_title = Column(String(500), nullable=False)
    chapter_url = Column(String(500), nullable=False, unique=True)
    chapter_content = Column(Text, nullable=False)
    chapter_index = Column(Integer, nullable=False)
    word_count = Column(Integer, default=0)
    cached_at = Column(DateTime, default=datetime.now)
    retry_count = Column(Integer, default=0)

    # 关联缓存任务
    task = relationship("CacheTask", back_populates="chapters")

    __table_args__ = (
        Index("idx_task_chapter", "task_id", "chapter_index"),
        Index("idx_novel_url", "novel_url"),
    )
