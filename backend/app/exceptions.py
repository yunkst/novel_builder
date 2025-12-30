#!/usr/bin/env python3
"""
自定义异常类模块

定义应用程序中使用的各种自定义异常，提供更好的错误分类和处理。
"""

from typing import Any


class NovelBuilderException(Exception):
    """基础异常类，所有自定义异常的基类"""

    def __init__(
        self,
        message: str,
        error_code: str | None = None,
        details: dict[str, Any] | None = None,
    ):
        super().__init__(message)
        self.message = message
        self.error_code = error_code or self.__class__.__name__
        self.details = details or {}

    def to_dict(self) -> dict[str, Any]:
        """转换为字典格式，便于API响应"""
        return {
            "error": self.error_code,
            "message": self.message,
            "details": self.details,
        }


class AuthenticationError(NovelBuilderException):
    """认证相关错误"""

    def __init__(self, message: str = "认证失败", **kwargs):
        super().__init__(message, "AUTH_ERROR", **kwargs)


class ConfigurationError(NovelBuilderException):
    """配置相关错误"""

    def __init__(self, message: str = "配置错误", **kwargs):
        super().__init__(message, "CONFIG_ERROR", **kwargs)


class CrawlerError(NovelBuilderException):
    """爬虫相关错误"""

    def __init__(
        self,
        message: str = "爬虫操作失败",
        site_name: str | None = None,
        url: str | None = None,
        **kwargs,
    ):
        details = kwargs.get("details", {})
        if site_name:
            details["site_name"] = site_name
        if url:
            details["url"] = url
        kwargs["details"] = details

        super().__init__(message, "CRAWLER_ERROR", **kwargs)


class NetworkError(CrawlerError):
    """网络相关错误"""

    def __init__(
        self,
        message: str = "网络连接失败",
        timeout: float | None = None,
        status_code: int | None = None,
        **kwargs,
    ):
        details = kwargs.get("details", {})
        if timeout:
            details["timeout"] = timeout
        if status_code:
            details["status_code"] = status_code
        kwargs["details"] = details

        super().__init__(message, **kwargs)


class ParseError(CrawlerError):
    """内容解析错误"""

    def __init__(
        self,
        message: str = "内容解析失败",
        selector: str | None = None,
        html_length: int | None = None,
        **kwargs,
    ):
        details = kwargs.get("details", {})
        if selector:
            details["selector"] = selector
        if html_length:
            details["html_length"] = html_length
        kwargs["details"] = details

        super().__init__(message, **kwargs)


class DatabaseError(NovelBuilderException):
    """数据库相关错误"""

    def __init__(
        self,
        message: str = "数据库操作失败",
        operation: str | None = None,
        table: str | None = None,
        **kwargs,
    ):
        details = kwargs.get("details", {})
        if operation:
            details["operation"] = operation
        if table:
            details["table"] = table
        kwargs["details"] = details

        super().__init__(message, "DATABASE_ERROR", **kwargs)


class CacheError(NovelBuilderException):
    """缓存相关错误"""

    def __init__(
        self,
        message: str = "缓存操作失败",
        task_id: str | None = None,
        cache_key: str | None = None,
        **kwargs,
    ):
        details = kwargs.get("details", {})
        if task_id:
            details["task_id"] = task_id
        if cache_key:
            details["cache_key"] = cache_key
        kwargs["details"] = details

        super().__init__(message, "CACHE_ERROR", **kwargs)


class ValidationError(NovelBuilderException):
    """数据验证错误"""

    def __init__(
        self,
        message: str = "数据验证失败",
        field: str | None = None,
        value: Any | None = None,
        **kwargs,
    ):
        details = kwargs.get("details", {})
        if field:
            details["field"] = field
        if value is not None:
            details["value"] = str(value)
        kwargs["details"] = details

        super().__init__(message, "VALIDATION_ERROR", **kwargs)


class ContentNotFoundError(NovelBuilderException):
    """内容未找到错误"""

    def __init__(
        self,
        message: str = "请求的内容不存在",
        content_type: str | None = None,
        identifier: str | None = None,
        **kwargs,
    ):
        details = kwargs.get("details", {})
        if content_type:
            details["content_type"] = content_type
        if identifier:
            details["identifier"] = identifier
        kwargs["details"] = details

        super().__init__(message, "NOT_FOUND", **kwargs)


class RateLimitError(NovelBuilderException):
    """频率限制错误"""

    def __init__(
        self,
        message: str = "请求频率过高",
        retry_after: int | None = None,
        limit: int | None = None,
        **kwargs,
    ):
        details = kwargs.get("details", {})
        if retry_after:
            details["retry_after"] = retry_after
        if limit:
            details["limit"] = limit
        kwargs["details"] = details

        super().__init__(message, "RATE_LIMIT", **kwargs)


class ExternalServiceError(NovelBuilderException):
    """外部服务错误"""

    def __init__(
        self,
        message: str = "外部服务调用失败",
        service_name: str | None = None,
        service_url: str | None = None,
        **kwargs,
    ):
        details = kwargs.get("details", {})
        if service_name:
            details["service_name"] = service_name
        if service_url:
            details["service_url"] = service_url
        kwargs["details"] = details

        super().__init__(message, "EXTERNAL_SERVICE_ERROR", **kwargs)


def handle_exception(exc: Exception, logger=None) -> NovelBuilderException:
    """
    将标准异常转换为自定义异常。

    Args:
        exc: 原始异常
        logger: 日志记录器

    Returns:
        NovelBuilderException: 转换后的自定义异常
    """
    if logger:
        logger.exception(f"处理异常: {exc}")

    # 已经是自定义异常，直接返回
    if isinstance(exc, NovelBuilderException):
        return exc

    # 根据异常类型进行转换
    if isinstance(exc, ConnectionError):
        return NetworkError(f"网络连接错误: {exc}")
    elif isinstance(exc, TimeoutError):
        return NetworkError(f"请求超时: {exc}", timeout=None)
    elif isinstance(exc, ValueError):
        return ValidationError(f"数据验证错误: {exc}")
    elif isinstance(exc, KeyError):
        return ValidationError(f"缺少必需字段: {exc}")
    elif isinstance(exc, AttributeError):
        return ParseError(f"属性访问错误: {exc}")
    else:
        return NovelBuilderException(f"未知错误: {exc}", "UNKNOWN_ERROR")
