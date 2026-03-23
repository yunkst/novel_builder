#!/usr/bin/env python3
"""
爬虫服务模块

提供统一的小说爬虫服务和缓存功能。
"""

from .cache_decorator import cacheable
from .cache_storage import CacheStorage
from .cache_types import CacheType
from .cache_validators import (
    CacheValidator,
    ChapterContentValidator,
    ChapterListValidator,
    get_validator,
)
from .crawler_factory import (
    SOURCE_SITES_METADATA,
    get_crawler_for_url,
    get_enabled_crawlers,
    get_source_sites_info,
)
from .session_manager import SessionManager

__all__ = [
    # 缓存装饰器
    "cacheable",
    # 缓存存储
    "CacheStorage",
    # 缓存类型
    "CacheType",
    # 缓存验证器
    "CacheValidator",
    "ChapterContentValidator",
    "ChapterListValidator",
    "get_validator",
    # 爬虫工厂
    "get_enabled_crawlers",
    "get_crawler_for_url",
    "get_source_sites_info",
    "SOURCE_SITES_METADATA",
    # 会话管理
    "SessionManager",
]