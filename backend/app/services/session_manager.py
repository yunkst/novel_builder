#!/usr/bin/env python3
"""
Session Manager - Scrapling 会话管理器

基于 Scrapling 最佳实践实现异步会话管理。
对于简单请求使用 AsyncFetcher 类方法，对于隐蔽请求使用 AsyncStealthySession。
"""

import asyncio
from typing import Any

from scrapling.fetchers import AsyncFetcher, AsyncStealthySession


class SessionManager:
    """
    网络会话管理器

    管理 Scrapling 的异步会话实例，支持连接复用和 Cookie 保持。

    特性:
    - 简单请求使用 AsyncFetcher 类方法（无会话开销）
    - 隐蔽请求使用 AsyncStealthySession（支持浏览器指纹伪装）
    - 异步安全，使用锁保护并发访问
    - 自动资源清理

    设计说明:
        Scrapling 的 AsyncFetcher 是类方法，不需要会话实例。
        AsyncStealthySession 需要会话来复用浏览器实例。

    使用示例:
        >>> manager = SessionManager()
        >>> # 简单请求 - 直接使用 AsyncFetcher 类方法
        >>> result = await manager.fetch("simple", "https://example.com")
        >>> # 隐蔽请求 - 使用会话
        >>> result = await manager.fetch("stealth", "https://protected.com")
        >>> await manager.close()
    """

    def __init__(self):
        """初始化会话管理器"""
        self._stealth_session: Any = None
        self._lock = asyncio.Lock()

    async def fetch(self, strategy: str, url: str, method: str = "GET", **kwargs) -> Any:
        """
        执行 HTTP 请求

        Args:
            strategy: 请求策略
                - "simple": 使用 AsyncFetcher，简单高效的 HTTP 请求
                - "stealth": 使用 AsyncStealthySession，最强的反爬能力
            url: 目标 URL
            method: HTTP 方法（GET、POST、PUT、DELETE）
            **kwargs: 其他请求参数

        Returns:
            Response 对象

        使用示例:
            >>> # GET 请求
            >>> result = await manager.fetch("simple", "https://example.com")
            >>> # POST 请求
            >>> result = await manager.fetch("simple", "https://example.com", method="POST", data={'key': 'value'})
        """
        if strategy == "stealth":
            # 隐蔽模式 - 使用 AsyncStealthySession
            session = await self._get_stealth_session()
            if method.upper() == "GET":
                return await session.fetch(url, **kwargs)
            else:
                return await session.fetch(url, method=method, **kwargs)
        else:
            # 简单模式 - 直接使用 AsyncFetcher 类方法
            # 这样可以获得最佳性能，无需会话开销
            method_lower = method.lower()
            if method_lower == "get":
                return await AsyncFetcher.get(url, **kwargs)
            elif method_lower == "post":
                return await AsyncFetcher.post(url, **kwargs)
            elif method_lower == "put":
                return await AsyncFetcher.put(url, **kwargs)
            elif method_lower == "delete":
                return await AsyncFetcher.delete(url, **kwargs)
            else:
                raise ValueError(f"不支持的 HTTP 方法: {method}")

    async def _get_stealth_session(self) -> AsyncStealthySession:
        """
        获取或创建隐蔽会话

        Returns:
            AsyncStealthySession 实例
        """
        async with self._lock:
            if self._stealth_session is None:
                # 隐蔽模式 - 最强的反爬能力
                # 使用 max_pages 创建页面池，复用浏览器实例
                self._stealth_session = AsyncStealthySession(
                    headless=True,
                    network_idle=True,  # 等待网络空闲
                    max_pages=3,  # 页面池大小
                )
            return self._stealth_session

    async def close(self):
        """
        关闭所有会话

        清理资源，关闭浏览器实例（如果有）

        使用示例:
            >>> await manager.close()
        """
        async with self._lock:
            if self._stealth_session is not None:
                try:
                    await self._stealth_session.close()
                except Exception as e:
                    # 记录错误但继续清理
                    print(f"关闭隐蔽会话时出错: {e}")
                finally:
                    self._stealth_session = None

    async def __aenter__(self):
        """支持异步上下文管理器"""
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """退出上下文时自动关闭所有会话"""
        await self.close()
