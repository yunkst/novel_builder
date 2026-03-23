#!/usr/bin/env python3
"""
缓存验证器接口和实现

提供缓存验证的抽象接口和具体实现，用于验证缓存数据的有效性。
"""

from abc import ABC, abstractmethod
from typing import Any

from .cache_types import CacheType


class CacheValidator(ABC):
    """
    缓存验证器接口

    定义缓存数据验证的抽象方法，所有具体验证器都必须实现此接口。
    """

    @abstractmethod
    def is_valid(self, data: Any, min_valid_length: int = 0) -> bool:
        """
        验证缓存数据是否有效

        Args:
            data: 要验证的缓存数据
            min_valid_length: 最小有效长度（用于章节内容验证）

        Returns:
            bool: 数据是否有效
        """
        pass

    @abstractmethod
    def get_cache_type(self) -> CacheType:
        """
        获取验证器对应的缓存类型

        Returns:
            CacheType: 缓存类型枚举
        """
        pass

    @abstractmethod
    def get_validation_error(self) -> str | None:
        """
        获取最后一次验证的错误信息

        Returns:
            str | None: 错误信息，如果没有错误则返回 None
        """
        pass


class ChapterContentValidator(CacheValidator):
    """
    章节内容缓存验证器

    验证章节内容是否符合基本要求：
    - 内容非空
    - 字数达到最小要求（默认 300 字）
    - 包含标题和内容
    """

    def __init__(self):
        """初始化验证器"""
        self._last_error: str | None = None

    def is_valid(self, data: Any, min_valid_length: int = 300) -> bool:
        """
        验证章节内容是否有效

        Args:
            data: 章节内容数据，应为字典，包含 title 和 content
            min_valid_length: 内容最小字数（默认 300）

        Returns:
            bool: 内容是否有效
        """
        # 重置错误信息
        self._last_error = None

        # 检查数据类型
        if not isinstance(data, dict):
            self._last_error = f"数据类型错误：期望 dict，实际 {type(data).__name__}"
            return False

        # 检查必需字段
        if "title" not in data:
            self._last_error = "缺少必需字段：title"
            return False

        if "content" not in data:
            self._last_error = "缺少必需字段：content"
            return False

        # 检查标题
        title = data.get("title", "")
        if not isinstance(title, str) or not title.strip():
            self._last_error = "标题为空或不是字符串"
            return False

        # 检查内容
        content = data.get("content", "")
        if not isinstance(content, str):
            self._last_error = "内容不是字符串"
            return False

        # 检查内容长度
        content_stripped = content.strip()
        if not content_stripped:
            self._last_error = "内容为空"
            return False

        # 计算字数（中文按字符计算，英文按单词计算）
        word_count = len(content_stripped)

        if word_count < min_valid_length:
            self._last_error = (
                f"内容字数不足：{word_count} 字，最小要求 {min_valid_length} 字"
            )
            return False

        return True

    def get_cache_type(self) -> CacheType:
        """获取缓存类型"""
        return CacheType.CHAPTER_CONTENT

    def get_validation_error(self) -> str | None:
        """获取最后一次验证的错误信息"""
        return self._last_error


class ChapterListValidator(CacheValidator):
    """
    章节列表缓存验证器

    验证章节列表是否符合基本要求：
    - 列表非空
    - 每个章节包含 title 和 url
    - URL 格式有效
    """

    def __init__(self):
        """初始化验证器"""
        self._last_error: str | None = None

    def is_valid(self, data: Any, min_valid_length: int = 0) -> bool:
        """
        验证章节列表是否有效

        Args:
            data: 章节列表数据，应为列表，每个元素是包含 title 和 url 的字典
            min_valid_length: 最小章节数量（默认 0，表示不限制）

        Returns:
            bool: 列表是否有效
        """
        # 重置错误信息
        self._last_error = None

        # 检查数据类型
        if not isinstance(data, list):
            self._last_error = f"数据类型错误：期望 list，实际 {type(data).__name__}"
            return False

        # 检查列表是否为空
        if not data:
            self._last_error = "章节列表为空"
            return False

        # 检查最小章节数量
        if min_valid_length > 0 and len(data) < min_valid_length:
            self._last_error = (
                f"章节数量不足：{len(data)} 章，最小要求 {min_valid_length} 章"
            )
            return False

        # 验证每个章节
        for idx, chapter in enumerate(data):
            if not isinstance(chapter, dict):
                self._last_error = f"第 {idx + 1} 个章节数据类型错误：期望 dict，实际 {type(chapter).__name__}"
                return False

            # 检查必需字段
            if "title" not in chapter:
                self._last_error = f"第 {idx + 1} 个章节缺少 title 字段"
                return False

            if "url" not in chapter:
                self._last_error = f"第 {idx + 1} 个章节缺少 url 字段"
                return False

            # 检查标题
            title = chapter.get("title", "")
            if not isinstance(title, str) or not title.strip():
                self._last_error = f"第 {idx + 1} 个章节标题为空"
                return False

            # 检查 URL
            url = chapter.get("url", "")
            if not isinstance(url, str) or not url.strip():
                self._last_error = f"第 {idx + 1} 个章节 URL 为空"
                return False

            # 简单的 URL 格式验证
            if not (url.startswith("http://") or url.startswith("https://")):
                self._last_error = f"第 {idx + 1} 个章节 URL 格式无效：{url}"
                return False

        return True

    def get_cache_type(self) -> CacheType:
        """获取缓存类型"""
        return CacheType.CHAPTER_LIST

    def get_validation_error(self) -> str | None:
        """获取最后一次验证的错误信息"""
        return self._last_error


# 验证器工厂函数
def get_validator(cache_type: CacheType) -> CacheValidator:
    """
    根据缓存类型获取对应的验证器

    Args:
        cache_type: 缓存类型枚举

    Returns:
        CacheValidator: 对应的验证器实例

    Raises:
        ValueError: 当缓存类型不支持时
    """
    validators = {
        CacheType.CHAPTER_CONTENT: ChapterContentValidator,
        CacheType.CHAPTER_LIST: ChapterListValidator,
    }

    validator_class = validators.get(cache_type)
    if not validator_class:
        raise ValueError(f"Unsupported cache type: {cache_type}")

    return validator_class()
