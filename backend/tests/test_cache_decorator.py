#!/usr/bin/env python3
"""
缓存装饰器单元测试

测试缓存装饰器的核心功能。
"""

import pytest

from app.services.cache_decorator import cacheable
from app.services.cache_storage import CacheStorage
from app.services.cache_types import CacheType
from app.services.cache_validators import (
    ChapterContentValidator,
    ChapterListValidator,
    get_validator,
)


class TestCacheTypes:
    """测试缓存类型枚举"""

    def test_cache_type_values(self):
        """测试缓存类型值"""
        assert CacheType.CHAPTER_CONTENT.value == "chapter_content"
        assert CacheType.CHAPTER_LIST.value == "chapter_list"

    def test_cache_type_from_string(self):
        """测试从字符串获取缓存类型"""
        assert CacheType.from_string("chapter_content") == CacheType.CHAPTER_CONTENT
        assert CacheType.from_string("chapter_list") == CacheType.CHAPTER_LIST

    def test_cache_type_from_string_invalid(self):
        """测试无效的缓存类型字符串"""
        with pytest.raises(ValueError, match="Unknown cache type"):
            CacheType.from_string("invalid_type")


class TestChapterContentValidator:
    """测试章节内容验证器"""

    def setup_method(self):
        """每个测试方法前创建验证器实例"""
        self.validator = ChapterContentValidator()

    def test_valid_content(self):
        """测试有效的章节内容"""
        data = {
            "title": "第一章 开始",
            "content": "这是一个测试内容，长度足够超过三百个字。" * 10,
        }
        assert self.validator.is_valid(data, min_valid_length=300) is True
        assert self.validator.get_validation_error() is None

    def test_invalid_data_type(self):
        """测试无效的数据类型"""
        assert self.validator.is_valid("not a dict") is False
        assert "数据类型错误" in self.validator.get_validation_error()

    def test_missing_title(self):
        """测试缺少标题"""
        data = {"content": "内容" * 100}
        assert self.validator.is_valid(data) is False
        assert "缺少必需字段：title" in self.validator.get_validation_error()

    def test_missing_content(self):
        """测试缺少内容"""
        data = {"title": "标题"}
        assert self.validator.is_valid(data) is False
        assert "缺少必需字段：content" in self.validator.get_validation_error()

    def test_empty_content(self):
        """测试空内容"""
        data = {"title": "标题", "content": ""}
        assert self.validator.is_valid(data) is False
        assert "内容为空" in self.validator.get_validation_error()

    def test_content_too_short(self):
        """测试内容太短"""
        data = {"title": "标题", "content": "短内容"}
        assert self.validator.is_valid(data, min_valid_length=300) is False
        assert "内容字数不足" in self.validator.get_validation_error()

    def test_get_cache_type(self):
        """测试获取缓存类型"""
        assert self.validator.get_cache_type() == CacheType.CHAPTER_CONTENT


class TestChapterListValidator:
    """测试章节列表验证器"""

    def setup_method(self):
        """每个测试方法前创建验证器实例"""
        self.validator = ChapterListValidator()

    def test_valid_list(self):
        """测试有效的章节列表"""
        data = [
            {"title": "第一章", "url": "https://example.com/chapter/1"},
            {"title": "第二章", "url": "https://example.com/chapter/2"},
        ]
        assert self.validator.is_valid(data) is True
        assert self.validator.get_validation_error() is None

    def test_invalid_data_type(self):
        """测试无效的数据类型"""
        assert self.validator.is_valid("not a list") is False
        assert "数据类型错误" in self.validator.get_validation_error()

    def test_empty_list(self):
        """测试空列表"""
        assert self.validator.is_valid([]) is False
        assert "章节列表为空" in self.validator.get_validation_error()

    def test_missing_title(self):
        """测试缺少标题"""
        data = [{"url": "https://example.com/chapter/1"}]
        assert self.validator.is_valid(data) is False
        assert "缺少 title 字段" in self.validator.get_validation_error()

    def test_missing_url(self):
        """测试缺少 URL"""
        data = [{"title": "第一章"}]
        assert self.validator.is_valid(data) is False
        assert "缺少 url 字段" in self.validator.get_validation_error()

    def test_invalid_url_format(self):
        """测试无效的 URL 格式"""
        data = [{"title": "第一章", "url": "invalid-url"}]
        assert self.validator.is_valid(data) is False
        assert "URL 格式无效" in self.validator.get_validation_error()

    def test_minimum_chapter_count(self):
        """测试最小章节数量"""
        data = [{"title": "第一章", "url": "https://example.com/chapter/1"}]
        assert self.validator.is_valid(data, min_valid_length=3) is False
        assert "章节数量不足" in self.validator.get_validation_error()

    def test_get_cache_type(self):
        """测试获取缓存类型"""
        assert self.validator.get_cache_type() == CacheType.CHAPTER_LIST


class TestGetValidator:
    """测试验证器工厂函数"""

    def test_get_chapter_content_validator(self):
        """测试获取章节内容验证器"""
        validator = get_validator(CacheType.CHAPTER_CONTENT)
        assert isinstance(validator, ChapterContentValidator)

    def test_get_chapter_list_validator(self):
        """测试获取章节列表验证器"""
        validator = get_validator(CacheType.CHAPTER_LIST)
        assert isinstance(validator, ChapterListValidator)


class TestCacheStorage:
    """测试缓存存储层"""

    def test_init_without_db(self):
        """测试不提供数据库会话初始化"""
        storage = CacheStorage()
        assert storage._db is None
        assert storage._owns_session is True

    def test_context_manager(self):
        """测试上下文管理器"""
        with CacheStorage() as storage:
            assert storage._db is not None


class TestCacheableDecorator:
    """测试缓存装饰器"""

    def test_decorator_signature_preservation(self):
        """测试装饰器保留函数签名"""

        @cacheable(
            cache_type=CacheType.CHAPTER_CONTENT,
            key_params=["chapter_url", "novel_url"],
            min_valid_length=300,
        )
        async def get_chapter_content(
            self, chapter_url: str, novel_url: str = "", force_refresh: bool = False
        ):
            return {"title": "标题", "content": "内容" * 100}

        # 检查函数名称是否保留
        assert get_chapter_content.__name__ == "get_chapter_content"

    def test_sync_function_support(self):
        """测试同步函数支持"""

        @cacheable(
            cache_type=CacheType.CHAPTER_CONTENT,
            key_params=["chapter_url", "novel_url"],
            min_valid_length=10,
        )
        def sync_get_content(chapter_url: str, novel_url: str = "", force_refresh: bool = False):
            return {"title": "标题", "content": "内容" * 100}

        # 验证函数可以正常调用（不测试实际缓存，因为需要数据库）
        assert sync_get_content.__name__ == "sync_get_content"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])