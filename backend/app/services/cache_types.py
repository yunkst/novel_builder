#!/usr/bin/env python3
"""
缓存类型枚举定义

定义支持的缓存类型，用于缓存装饰器和验证器。
"""

from enum import Enum


class CacheType(Enum):
    """缓存类型枚举"""

    CHAPTER_CONTENT = "chapter_content"  # 章节内容缓存
    CHAPTER_LIST = "chapter_list"  # 章节列表缓存

    @classmethod
    def from_string(cls, value: str) -> "CacheType":
        """
        从字符串获取缓存类型

        Args:
            value: 缓存类型字符串

        Returns:
            CacheType: 对应的缓存类型枚举

        Raises:
            ValueError: 当字符串不匹配任何缓存类型时
        """
        for cache_type in cls:
            if cache_type.value == value:
                return cache_type
        raise ValueError(f"Unknown cache type: {value}")
