#!/usr/bin/env python3
"""
Scrapling Spider 框架集成

提供批量爬取、并发控制、暂停恢复等高级功能。
基于 Scrapling 的 Spider 类，提供小说批量处理能力。
"""

import asyncio
from typing import Any, AsyncGenerator

from scrapling.spiders import Spider, Request
from scrapling.fetchers import FetcherSession, StealthySession

from .page_response import PageResponse


class NovelCachingSpider(Spider):
    """
    小说缓存爬虫基类

    基于 Scrapling Spider 框架，提供：
    - 并发控制（可配置并发数）
    - 自动重试（阻塞检测）
    - 进度跟踪（实时统计）
    - 暂停恢复（检查点保存）
    - 错误容错（异常隔离）

    使用场景：
    - 批量缓存小说章节
    - 并发获取多个章节内容
    - 长时间运行的爬取任务
    """

    def __init__(self, crawler: "BaseCrawler", **kwargs):
        """
        初始化

        Args:
            crawler: 爬虫实例，用于复用配置
            **kwargs: Spider 参数
                - concurrent_requests: 并发数（默认 4）
                - download_delay: 请求间隔（默认 0）
                - max_blocked_retries: 最大重试次数（默认 3）
        """
        super().__init__(**kwargs)
        self.crawler = crawler
        self.fetcher = crawler.fetcher

    async def batch_fetch_chapters(
        self,
        chapter_urls: list[str],
        max_concurrent: int = 10,
    ) -> AsyncGenerator[dict[str, Any], None]:
        """
        批量获取章节内容

        Args:
            chapter_urls: 章节 URL 列表
            max_concurrent: 最大并发数

        Yields:
            dict: 章节内容字典，包含：
                - title: 章节标题
                - content: 章节内容
                - url: 章节 URL
                - success: 是否成功
                - error: 错误信息（如果失败）

        使用示例：
            >>> spider = NovelCachingSpider(crawler)
            >>> async for chapter in spider.batch_fetch_chapters(chapter_urls, max_concurrent=5):
            >>>     if chapter['success']:
            >>>         print(f"成功获取: {chapter['title']}")
            >>>     else:
            >>>         print(f"失败: {chapter['error']}")
        """
        self.concurrent_requests = max_concurrent
        self.start_urls = chapter_urls

        for url in chapter_urls:
            yield Request(url, callback=self.parse_chapter)

    async def parse_chapter(self, response):
        """
        解析章节内容

        Args:
            response: Scrapling 响应对象

        Returns:
            dict: 章节内容字典
        """
        try:
            # 创建 PageResponse
            page = PageResponse(response, self.fetcher)

            # 获取标题
            title_elem = page.css('h1').first or page.css('title').first
            title = title_elem.css('::text').get('').strip() if title_elem else "章节内容"

            # 获取内容
            content = self.crawler.extract_content(page)

            return {
                'title': title,
                'content': content,
                'url': response.url,
                'success': True,
                'error': None,
            }

        except Exception as e:
            return {
                'title': '',
                'content': '',
                'url': response.url if hasattr(response, 'url') else '',
                'success': False,
                'error': str(e),
            }

    def configure_sessions(self, manager):
        """
        配置会话

        Args:
            manager: SessionManager 实例
        """
        # 默认会话 - 用于简单请求
        manager.add("default", FetcherSession())

        # 隐蔽会话 - 用于反爬虫请求（懒加载）
        manager.add(
            "stealth",
            StealthySession(
                headless=True,
                os_randomize=True,
                network_idle=True,
            ),
            lazy=True,  # 按需启动
            default=False,  # 不作为默认会话
        )

    async def is_blocked(self, response) -> bool:
        """
        检测是否被阻塞

        Args:
            response: Scrapling 响应对象

        Returns:
            bool: 是否被阻塞
        """
        blocked_codes = {401, 403, 407, 429, 444, 500, 502, 503, 504}
        return response.status in blocked_codes

    async def retry_blocked_request(self, request: Request, response) -> Request:
        """
        重试被阻塞的请求

        Args:
            request: 原始请求
            response: 响应对象

        Returns:
            Request: 重试请求
        """
        # 切换到隐蔽模式重试
        request.sid = "stealth"
        return request


class ConcurrentChapterFetcher:
    """
    并发章节获取器

    提供简单的并发获取接口，无需使用 Spider 框架。
    适合小规模的并发获取场景。

    使用示例：
        >>> fetcher = ConcurrentChapterFetcher(crawler, max_concurrent=5)
        >>> results = await fetcher.fetch_all(chapter_urls)
        >>> for result in results:
        >>>     if result['success']:
        >>>         print(f"成功: {result['title']}")
    """

    def __init__(self, crawler: "BaseCrawler", max_concurrent: int = 10):
        """
        初始化

        Args:
            crawler: 爬虫实例
            max_concurrent: 最大并发数
        """
        self.crawler = crawler
        self.max_concurrent = max_concurrent

    async def fetch_all(
        self,
        chapter_urls: list[str],
    ) -> list[dict[str, Any]]:
        """
        并发获取所有章节

        Args:
            chapter_urls: 章节 URL 列表

        Returns:
            list[dict]: 章节内容列表
        """
        semaphore = asyncio.Semaphore(self.max_concurrent)

        async def fetch_with_limit(url: str) -> dict[str, Any]:
            async with semaphore:
                try:
                    return await self.crawler.get_chapter_content(url)
                except Exception as e:
                    return {
                        "title": "",
                        "content": f"获取失败: {e}",
                        "url": url,
                        "success": False,
                        "error": str(e),
                    }

        tasks = [fetch_with_limit(url) for url in chapter_urls]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        # 处理异常
        final_results = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                final_results.append({
                    "title": "",
                    "content": f"请求异常: {result}",
                    "url": chapter_urls[i],
                    "success": False,
                    "error": str(result),
                })
            else:
                final_results.append(result)

        return final_results

    async def fetch_stream(
        self,
        chapter_urls: list[str],
    ) -> AsyncGenerator[dict[str, Any], None]:
        """
        流式获取章节

        Args:
            chapter_urls: 章节 URL 列表

        Yields:
            dict: 章节内容字典
        """
        semaphore = asyncio.Semaphore(self.max_concurrent)
        pending = set()

        async def fetch_and_yield(url: str):
            async with semaphore:
                try:
                    result = await self.crawler.get_chapter_content(url)
                    yield result
                except Exception as e:
                    yield {
                        "title": "",
                        "content": f"获取失败: {e}",
                        "url": url,
                        "success": False,
                        "error": str(e),
                    }

        # 创建所有任务
        for url in chapter_urls:
            task = asyncio.create_task(fetch_and_yield(url))
            pending.add(task)
            task.add_done_callback(pending.discard)

        # 等待所有任务完成
        while pending:
            await asyncio.sleep(0.1)
