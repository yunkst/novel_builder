#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from sqlalchemy import Column, String, Text, DateTime, Integer, Index
from sqlalchemy.sql import func
from .database import Base


class ChapterCache(Base):
    """章节缓存表"""

    __tablename__ = "chapter_cache"

    # 主键：章节URL的哈希值（避免URL过长）
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)

    # 章节URL（唯一索引）
    url = Column(String(512), unique=True, nullable=False, index=True)

    # 章节标题
    title = Column(String(256), nullable=False)

    # 章节内容
    content = Column(Text, nullable=False)

    # 来源站点（用于分类统计）
    source = Column(String(64), nullable=True, index=True)

    # 创建时间
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # 更新时间
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # 访问次数（用于统计热门章节）
    access_count = Column(Integer, default=0, nullable=False)

    # 最后访问时间
    last_accessed_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # 创建索引
    __table_args__ = (
        Index('idx_source_created', 'source', 'created_at'),
        Index('idx_updated_at', 'updated_at'),
    )

    def __repr__(self):
        return f"<ChapterCache(url='{self.url[:50]}...', title='{self.title}')>"

    def to_dict(self):
        """转换为字典"""
        return {
            "title": self.title,
            "content": self.content
        }
