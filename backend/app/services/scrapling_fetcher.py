#!/usr/bin/env python3
"""
Scrapling 网络层 - 统一的请求接口

基于 Scrapling 库提供高性能、反爬虫能力强的网络请求功能。
支持简单请求、隐蔽反爬请求、动态 JS 渲染、会话复用和代理轮换。
"""

import time
from typing import Optional

from scrapling.fetchers import (
    FetcherSession,
    StealthySession,
    DynamicSession,
)
from scrapling.parser import Selector

from .http_client import Response, RequestConfig, RequestStrategy


class ScraplingFetcher:
    """
    Scrapling 网络请求统一接口

    支持的功能：
    - 简单 HTTP 请求 (FetcherSession)
    - 隐蔽反爬请求 (StealthySession) - 自动绕过 Cloudflare
    - 动态 JS 渲染 (DynamicSession) - 支持复杂网站
    - 会话复用 - Cookie 和连接复用
    - 代理轮换 - 支持代理配置

    性能特点：
    - 解析速度比 BeautifulSoup4 快 784 倍
    - 内置反爬虫检测和绕过
    - 自动重试和容错机制
    """

    def __init__(self, strategy: RequestStrategy = RequestStrategy.HYBRID):
        """
        初始化 Fetcher

        Args:
            strategy: 请求策略，决定使用哪种 Session
                - SIMPLE: 使用 FetcherSession，简单高效的 HTTP 请求
                - BROWSER: 使用 DynamicSession，支持 JS 渲染
                - HYBRID: 自动选择最佳策略（默认）
                - STEALTH: 使用 StealthySession，最强的反爬能力
        """
        self.strategy = strategy
        self._sessions: dict[str, any] = {}

    def _get_session(self, config: RequestConfig):
        """
        获取或创建会话

        Args:
            config: 请求配置

        Returns:
            Session: Scrapling Session 实例
        """
        # 优先使用配置中的策略
        actual_strategy = config.strategy or self.strategy

        if actual_strategy == RequestStrategy.STEALTH:
            if "stealth" not in self._sessions:
                # 隐蔽模式 - 最强的反爬能力
                self._sessions["stealth"] = StealthySession(
                    headless=True,
                    os_randomize=True,  # 随机化操作系统指纹
                    network_idle=True,  # 等待网络空闲
                    hide_canvas=True,  # 隐藏 Canvas 指纹
                    block_webrtc=True,  # 阻止 WebRTC 泄露 IP
                )
            return self._sessions["stealth"]

        elif actual_strategy == RequestStrategy.BROWSER:
            if "dynamic" not in self._sessions:
                # 浏览器模式 - 支持 JS 渲染
                self._sessions["dynamic"] = DynamicSession(
                    headless=True,
                    network_idle=True,
                )
            return self._sessions["dynamic"]

        else:  # SIMPLE or HYBRID
            if "simple" not in self._sessions:
                # 简单模式 - 最快的请求方式
                self._sessions["simple"] = FetcherSession(
                    impersonate="chrome"  # 模拟 Chrome 浏览器
                )
            return self._sessions["simple"]

    async def fetch(self, url: str, config: RequestConfig) -> Response:
        """
        统一的请求接口

        Args:
            url: 目标 URL
            config: 请求配置

        Returns:
            Response: 标准响应对象，与原接口保持兼容
        """
        session = self._get_session(config)
        start_time = time.time()

        try:
            # 构造请求参数
            kwargs: dict[str, any] = {
                "timeout": (config.timeout * 1000) if config.timeout else 30000,
            }

            # 添加代理配置
            if config.proxy:
                kwargs["proxy"] = config.proxy

            # 添加自定义请求头
            if config.custom_headers:
                kwargs["extra_headers"] = config.custom_headers

            # 发起请求
            result = await session.fetch(url, **kwargs)
            elapsed = time.time() - start_time

            # 转换为标准 Response 格式
            return Response(
                url=result.url,
                status_code=result.status,
                headers=dict(result.headers),
                content=result.html,
                encoding="utf-8",
                cookies={},
                elapsed=elapsed,
                strategy_used=self.strategy,
                from_cache=False,
            )

        except Exception as e:
            elapsed = time.time() - start_time
            # 包装异常信息
            raise Exception(f"Scrapling 请求失败 ({self.strategy.value}): {e}")

    def create_selector(self, html_content: str) -> Selector:
        """
        创建 Scrapling Selector

        Args:
            html_content: HTML 内容

        Returns:
            Selector: Scrapling 解析器，比 BeautifulSoup4 快 784 倍

        使用示例:
            >>> selector = fetcher.create_selector(html)
            >>> # CSS 选择器
            >>> title = selector.css('h1::text').get()
            >>> # XPath 选择器
            >>> links = selector.xpath('//a[@href]')
            >>> # 文本搜索
            >>> element = selector.find_by_text('搜索文本')
        """
        return Selector(html_content)

    async def close(self):
        """
        关闭所有会话

        清理资源，关闭浏览器实例（如果有）
        """
        for session in self._sessions.values():
            try:
                if hasattr(session, '__aexit__'):
                    # 异步上下文管理器
                    await session.__aexit__(None, None, None)
                elif hasattr(session, 'close'):
                    # 普通关闭方法
                    await session.close()
            except Exception as e:
                # 忽略关闭错误，继续清理其他会话
                print(f"关闭会话时出错: {e}")
        self._sessions.clear()
