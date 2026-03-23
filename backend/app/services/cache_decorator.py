#!/usr/bin/env python3
"""
缓存装饰器

提供统一的缓存装饰器，用于自动缓存爬虫方法的返回值。
支持异步函数、force_refresh 参数、缓存验证等功能。
"""

import functools
import inspect
import logging
from collections.abc import Callable
from typing import Any, ParamSpec, TypeVar

from .cache_storage import CacheStorage
from .cache_types import CacheType
from .cache_validators import CacheValidator, get_validator

# 配置日志
logger = logging.getLogger(__name__)

# 类型变量定义
P = ParamSpec("P")
T = TypeVar("T")


def cacheable(
    cache_type: CacheType,
    key_params: list[str] | None = None,
    min_valid_length: int = 0,
    validator: CacheValidator | None = None,
) -> Callable:
    """
    缓存装饰器工厂函数

    为爬虫方法提供自动缓存功能，支持异步函数和 force_refresh 参数。

    Args:
        cache_type: 缓存类型（CHAPTER_CONTENT 或 CHAPTER_LIST）
        key_params: 用于构建缓存键的参数名列表
            - 对于 CHAPTER_CONTENT: 应包含 ["chapter_url", "novel_url"]
            - 对于 CHAPTER_LIST: 应包含 ["novel_url"]
        min_valid_length: 最小有效长度
            - 对于 CHAPTER_CONTENT: 内容最小字数（默认 300）
            - 对于 CHAPTER_LIST: 最小章节数（默认 0，不限制）
        validator: 自定义验证器（可选，默认根据 cache_type 自动选择）

    Returns:
        Callable: 装饰器函数

    使用示例:
        @cacheable(
            cache_type=CacheType.CHAPTER_CONTENT,
            key_params=["chapter_url", "novel_url"],
            min_valid_length=300
        )
        async def get_chapter_content(self, chapter_url: str, novel_url: str = "", force_refresh: bool = False):
            # 爬虫逻辑
            pass

        @cacheable(
            cache_type=CacheType.CHAPTER_LIST,
            key_params=["novel_url"]
        )
        async def get_chapter_list(self, novel_url: str, force_refresh: bool = False):
            # 爬虫逻辑
            pass
    """

    def decorator(func: Callable[P, T]) -> Callable[P, T]:
        # 检查函数是否是异步函数
        is_async = inspect.iscoroutinefunction(func)

        if is_async:
            @functools.wraps(func)
            async def async_wrapper(*args: P.args, **kwargs: P.kwargs) -> T:
                return await _execute_with_cache(
                    func, args, kwargs, cache_type, key_params,
                    min_valid_length, validator
                )

            return async_wrapper  # type: ignore
        else:
            @functools.wraps(func)
            def sync_wrapper(*args: P.args, **kwargs: P.kwargs) -> T:
                return _execute_with_cache_sync(
                    func, args, kwargs, cache_type, key_params,
                    min_valid_length, validator
                )

            return sync_wrapper  # type: ignore

    return decorator


async def _execute_with_cache(
    func: Callable,
    args: tuple,
    kwargs: dict,
    cache_type: CacheType,
    key_params: list[str] | None,
    min_valid_length: int,
    custom_validator: CacheValidator | None,
) -> Any:
    """
    执行带缓存的异步函数

    Args:
        func: 原始函数
        args: 位置参数
        kwargs: 关键字参数
        cache_type: 缓存类型
        key_params: 缓存键参数（用于验证必需参数）
        min_valid_length: 最小有效长度
        custom_validator: 自定义验证器

    Returns:
        Any: 函数执行结果
    """
    # 获取验证器
    validator = custom_validator or get_validator(cache_type)

    # 绑定参数
    bound_args = _bind_arguments(func, args, kwargs)

    # 验证必需的缓存键参数（如果提供了 key_params）
    # 如果缺少关键参数，直接执行原函数，不进行缓存
    if key_params:
        missing_params = [
            param for param in key_params
            if param not in bound_args or not bound_args[param]
        ]
        if missing_params:
            logger.warning(
                f"缺少必需的缓存键参数: {missing_params}，直接执行函数（跳过缓存）"
            )
            return await func(*args, **kwargs)

    # 提取 force_refresh 参数
    force_refresh = bound_args.pop("force_refresh", False)

    # 根据缓存类型处理
    if cache_type == CacheType.CHAPTER_CONTENT:
        return await _handle_chapter_content_cache(
            func, bound_args, force_refresh, validator, min_valid_length
        )
    elif cache_type == CacheType.CHAPTER_LIST:
        return await _handle_chapter_list_cache(
            func, bound_args, force_refresh, validator, min_valid_length
        )
    else:
        # 不支持的缓存类型，直接执行原函数
        logger.warning(f"Unsupported cache type: {cache_type}, executing without cache")
        return await func(*args, **kwargs)


def _execute_with_cache_sync(
    func: Callable,
    args: tuple,
    kwargs: dict,
    cache_type: CacheType,
    key_params: list[str] | None,
    min_valid_length: int,
    custom_validator: CacheValidator | None,
) -> Any:
    """
    执行带缓存的同步函数

    Args:
        func: 原始函数
        args: 位置参数
        kwargs: 关键字参数
        cache_type: 缓存类型
        key_params: 缓存键参数（用于验证必需参数）
        min_valid_length: 最小有效长度
        custom_validator: 自定义验证器

    Returns:
        Any: 函数执行结果
    """
    # 获取验证器
    validator = custom_validator or get_validator(cache_type)

    # 绑定参数
    bound_args = _bind_arguments(func, args, kwargs)

    # 验证必需的缓存键参数（如果提供了 key_params）
    # 如果缺少关键参数，直接执行原函数，不进行缓存
    if key_params:
        missing_params = [
            param for param in key_params
            if param not in bound_args or not bound_args[param]
        ]
        if missing_params:
            logger.warning(
                f"缺少必需的缓存键参数: {missing_params}，直接执行函数（跳过缓存）"
            )
            return func(*args, **kwargs)

    # 提取 force_refresh 参数
    force_refresh = bound_args.pop("force_refresh", False)

    # 根据缓存类型处理
    if cache_type == CacheType.CHAPTER_CONTENT:
        return _handle_chapter_content_cache_sync(
            func, bound_args, force_refresh, validator, min_valid_length
        )
    elif cache_type == CacheType.CHAPTER_LIST:
        return _handle_chapter_list_cache_sync(
            func, bound_args, force_refresh, validator, min_valid_length
        )
    else:
        # 不支持的缓存类型，直接执行原函数
        logger.warning(f"Unsupported cache type: {cache_type}, executing without cache")
        return func(*args, **kwargs)


def _bind_arguments(func: Callable, args: tuple, kwargs: dict) -> dict:
    """
    绑定函数参数

    将位置参数和关键字参数绑定到参数名称。

    Args:
        func: 函数对象
        args: 位置参数
        kwargs: 关键字参数

    Returns:
        dict: 参数名称到参数值的映射
    """
    # 获取函数签名
    sig = inspect.signature(func)
    parameters = sig.parameters

    # 构建参数字典
    bound_args = {}

    # 处理位置参数
    param_names = list(parameters.keys())
    for i, arg in enumerate(args):
        if i < len(param_names):
            bound_args[param_names[i]] = arg

    # 合并关键字参数
    bound_args.update(kwargs)

    # 填充默认值
    for param_name, param in parameters.items():
        if param_name not in bound_args and param.default is not param.empty:
            bound_args[param_name] = param.default

    return bound_args


async def _handle_chapter_content_cache(
    func: Callable,
    bound_args: dict,
    force_refresh: bool,
    validator: CacheValidator,
    min_valid_length: int,
) -> dict[str, Any]:
    """
    处理章节内容缓存

    Args:
        func: 原始函数
        bound_args: 绑定的参数
        force_refresh: 是否强制刷新
        validator: 缓存验证器
        min_valid_length: 最小有效长度

    Returns:
        dict: 章节内容
    """
    chapter_url = bound_args.get("chapter_url", "")
    novel_url = bound_args.get("novel_url", "")

    # 如果不强制刷新，尝试从缓存获取
    if not force_refresh:
        with CacheStorage() as storage:
            cached = storage.get_chapter_content(chapter_url)

            if cached:
                # 验证缓存有效性
                if validator.is_valid(cached, min_valid_length):
                    logger.info(f"缓存命中: {chapter_url}")
                    return cached
                else:
                    logger.warning(
                        f"缓存验证失败: {chapter_url}, 原因: {validator.get_validation_error()}"
                    )

    # 执行原函数
    logger.info(f"执行爬虫获取章节内容: {chapter_url}")
    result = await func(**bound_args)

    # 如果执行成功，保存到缓存
    if result and validator.is_valid(result, min_valid_length):
        try:
            with CacheStorage() as storage:
                chapter_title = result.get("title", "")
                chapter_content = result.get("content", "")
                word_count = result.get("word_count") or len(chapter_content)

                storage.save_chapter_content(
                    chapter_url=chapter_url,
                    chapter_title=chapter_title,
                    chapter_content=chapter_content,
                    novel_url=novel_url,
                    word_count=word_count,
                )
                logger.info(f"保存章节内容到缓存: {chapter_url}")

        except Exception as e:
            logger.error(f"保存章节内容缓存失败: {e}")

    # 标记结果（如果不是来自缓存）
    if isinstance(result, dict):
        result["from_cache"] = False

    return result


def _handle_chapter_content_cache_sync(
    func: Callable,
    bound_args: dict,
    force_refresh: bool,
    validator: CacheValidator,
    min_valid_length: int,
) -> dict[str, Any]:
    """
    处理章节内容缓存（同步版本）

    Args:
        func: 原始函数
        bound_args: 绑定的参数
        force_refresh: 是否强制刷新
        validator: 缓存验证器
        min_valid_length: 最小有效长度

    Returns:
        dict: 章节内容
    """
    chapter_url = bound_args.get("chapter_url", "")
    novel_url = bound_args.get("novel_url", "")

    # 如果不强制刷新，尝试从缓存获取
    if not force_refresh:
        with CacheStorage() as storage:
            cached = storage.get_chapter_content(chapter_url)

            if cached:
                # 验证缓存有效性
                if validator.is_valid(cached, min_valid_length):
                    logger.info(f"缓存命中: {chapter_url}")
                    return cached
                else:
                    logger.warning(
                        f"缓存验证失败: {chapter_url}, 原因: {validator.get_validation_error()}"
                    )

    # 执行原函数
    logger.info(f"执行爬虫获取章节内容: {chapter_url}")
    result = func(**bound_args)

    # 如果执行成功，保存到缓存
    if result and validator.is_valid(result, min_valid_length):
        try:
            with CacheStorage() as storage:
                chapter_title = result.get("title", "")
                chapter_content = result.get("content", "")
                word_count = result.get("word_count") or len(chapter_content)

                storage.save_chapter_content(
                    chapter_url=chapter_url,
                    chapter_title=chapter_title,
                    chapter_content=chapter_content,
                    novel_url=novel_url,
                    word_count=word_count,
                )
                logger.info(f"保存章节内容到缓存: {chapter_url}")

        except Exception as e:
            logger.error(f"保存章节内容缓存失败: {e}")

    # 标记结果（如果不是来自缓存）
    if isinstance(result, dict):
        result["from_cache"] = False

    return result


async def _handle_chapter_list_cache(
    func: Callable,
    bound_args: dict,
    force_refresh: bool,
    validator: CacheValidator,
    min_valid_length: int,
) -> list[dict[str, Any]]:
    """
    处理章节列表缓存

    Args:
        func: 原始函数
        bound_args: 绑定的参数
        force_refresh: 是否强制刷新
        validator: 缓存验证器
        min_valid_length: 最小有效长度

    Returns:
        list: 章节列表
    """
    novel_url = bound_args.get("novel_url", "")

    # 如果不强制刷新，尝试从缓存获取
    if not force_refresh:
        with CacheStorage() as storage:
            cached = storage.get_chapter_list(novel_url)

            if cached:
                # 验证缓存有效性
                if validator.is_valid(cached, min_valid_length):
                    logger.info(f"缓存命中: 章节列表 {novel_url}")
                    return cached
                else:
                    logger.warning(
                        f"缓存验证失败: 章节列表 {novel_url}, 原因: {validator.get_validation_error()}"
                    )

    # 执行原函数
    logger.info(f"执行爬虫获取章节列表: {novel_url}")
    result = await func(**bound_args)

    # 如果执行成功，保存到缓存
    if result and validator.is_valid(result, min_valid_length):
        try:
            with CacheStorage() as storage:
                storage.save_chapter_list(
                    novel_url=novel_url,
                    chapters=result,
                )
                logger.info(f"保存章节列表到缓存: {novel_url} ({len(result)} 章)")

        except Exception as e:
            logger.error(f"保存章节列表缓存失败: {e}")

    return result


def _handle_chapter_list_cache_sync(
    func: Callable,
    bound_args: dict,
    force_refresh: bool,
    validator: CacheValidator,
    min_valid_length: int,
) -> list[dict[str, Any]]:
    """
    处理章节列表缓存（同步版本）

    Args:
        func: 原始函数
        bound_args: 绑定的参数
        force_refresh: 是否强制刷新
        validator: 缓存验证器
        min_valid_length: 最小有效长度

    Returns:
        list: 章节列表
    """
    novel_url = bound_args.get("novel_url", "")

    # 如果不强制刷新，尝试从缓存获取
    if not force_refresh:
        with CacheStorage() as storage:
            cached = storage.get_chapter_list(novel_url)

            if cached:
                # 验证缓存有效性
                if validator.is_valid(cached, min_valid_length):
                    logger.info(f"缓存命中: 章节列表 {novel_url}")
                    return cached
                else:
                    logger.warning(
                        f"缓存验证失败: 章节列表 {novel_url}, 原因: {validator.get_validation_error()}"
                    )

    # 执行原函数
    logger.info(f"执行爬虫获取章节列表: {novel_url}")
    result = func(**bound_args)

    # 如果执行成功，保存到缓存
    if result and validator.is_valid(result, min_valid_length):
        try:
            with CacheStorage() as storage:
                storage.save_chapter_list(
                    novel_url=novel_url,
                    chapters=result,
                )
                logger.info(f"保存章节列表到缓存: {novel_url} ({len(result)} 章)")

        except Exception as e:
            logger.error(f"保存章节列表缓存失败: {e}")

    return result
