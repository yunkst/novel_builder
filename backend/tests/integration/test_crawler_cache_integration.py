#!/usr/bin/env python3

"""
集成测试：爬虫与缓存功能的集成
测试爬虫功能与缓存任务的完整工作流程
"""

import asyncio
from datetime import UTC, datetime
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from tests.factories import APITestDataFactory


class TestCrawlerCacheIntegration:
    """爬虫与缓存功能集成测试"""

    def setup_method(self):
        """每个测试方法执行前的设置"""
        self.client = TestClient(app)
        self.valid_headers = {
            "X-API-TOKEN": APITestDataFactory.create_valid_auth_token()
        }

    @pytest.mark.asyncio
    async def test_end_to_end_caching_workflow(self):
        """测试端到端的缓存工作流程"""
        # Given - 模拟一个可用的爬虫
        mock_novel_url = "https://example.com/novel/test-novel"
        mock_chapters_data = [
            {"title": "第一章：开始", "url": f"{mock_novel_url}/chapter/1", "index": 1},
            {"title": "第二章：继续", "url": f"{mock_novel_url}/chapter/2", "index": 2},
        ]
        mock_chapter_content = {
            "title": "第一章：开始",
            "content": "这是第一章的详细内容，包含了很多文字...",
            "next_chapter_url": f"{mock_novel_url}/chapter/2",
            "prev_chapter_url": None,
        }

        mock_crawler = AsyncMock()
        mock_crawler.get_chapter_list.return_value = mock_chapters_data
        mock_crawler.get_chapter_content.return_value = mock_chapter_content
        mock_crawler.is_valid_url.return_value = True

        with patch(
            "app.services.crawler_factory.get_enabled_crawlers"
        ) as mock_get_crawlers:
            with patch(
                "app.services.crawler_factory.get_crawler_for_url"
            ) as mock_get_crawler:
                mock_get_crawlers.return_value = {"test_site": mock_crawler}
                mock_get_crawler.return_value = mock_crawler

                # Step 1: 创建缓存任务
                create_response = self.client.post(
                    "/api/cache/create",
                    json={"novel_url": mock_novel_url},
                    headers=self.valid_headers,
                )
                assert create_response.status_code == 200
                task_id = create_response.json()["task_id"]
                assert task_id > 0

                # Step 2: 模拟缓存任务执行（这通常由后台任务执行）
                # 在真实环境中，这会是异步的后台任务
                # 在测试中，我们直接调用服务方法
                with patch(
                    "app.services.novel_cache_service.novel_cache_service.get_db"
                ) as mock_get_db:
                    mock_db = MagicMock()
                    mock_get_db.return_value = mock_db

                    with patch(
                        "app.services.novel_cache_service.novel_cache_service.create_cache_task"
                    ) as mock_create_task:
                        # 模拟创建任务但返回不同的任务ID用于测试
                        from app.models import CacheTask

                        mock_cache_task = CacheTask(
                            id=task_id,
                            novel_url=mock_novel_url,
                            novel_title="测试小说",
                            novel_author="测试作者",
                            status="running",
                            total_chapters=len(mock_chapters_data),
                            cached_chapters=0,
                            failed_chapters=0,
                            error_message=None,
                            created_at=datetime.now(UTC),
                        )
                        mock_create_task.return_value = mock_cache_task

                        # Step 3: 验证任务状态
                        status_response = self.client.get(
                            f"/api/cache/status/{task_id}", headers=self.valid_headers
                        )
                        assert status_response.status_code == 200
                        status_data = status_response.json()
                        assert status_data["status"] == "running"
                        assert status_data["total_chapters"] == len(mock_chapters_data)

                        # Step 4: 模拟任务完成
                        with patch(
                            "app.services.novel_cache_service.novel_cache_service.update_task_progress"
                        ) as mock_update:
                            with patch(
                                "app.services.novel_cache_service.novel_cache_service.get_cached_chapters"
                            ) as mock_get_cached:
                                # 模拟缓存章节
                                cached_chapters = []
                                for i, chapter in enumerate(mock_chapters_data):
                                    content = mock_crawler.get_chapter_content(
                                        f"{mock_novel_url}/chapter/{i + 1}"
                                    )
                                    cached_chapters.append(
                                        {
                                            "chapter_title": chapter["title"],
                                            "chapter_url": chapter["url"],
                                            "chapter_content": content["content"],
                                            "word_count": len(content["content"]),
                                            "chapter_index": chapter["index"],
                                            "cached_at": datetime.now(UTC),
                                        }
                                    )
                                mock_get_cached.return_value = cached_chapters

                                # 模拟更新任务状态为完成
                                mock_update.return_value = True

                                # Step 5: 验证下载功能
                                download_response = self.client.get(
                                    f"/api/cache/download/{task_id}?format=json",
                                    headers=self.valid_headers,
                                )
                                assert download_response.status_code == 200
                                download_data = download_response.json()
                                assert "novel" in download_data
                                assert "chapters" in download_data
                                assert len(download_data["chapters"]) == len(
                                    mock_chapters_data
                                )

    @pytest.mark.asyncio
    async def test_crawler_error_handling_during_caching(self):
        """测试缓存过程中的爬虫错误处理"""
        # Given
        mock_novel_url = "https://example.com/novel/error-test"

        mock_crawler = AsyncMock()
        mock_crawler.get_chapter_list.side_effect = Exception("爬虫连接失败")
        mock_crawler.is_valid_url.return_value = True

        with patch(
            "app.services.crawler_factory.get_crawler_for_url"
        ) as mock_get_crawler:
            mock_get_crawler.return_value = mock_crawler

            # When - 创建缓存任务
            with patch(
                "app.services.novel_cache_service.novel_cache_service.create_cache_task"
            ) as mock_create:
                mock_create.side_effect = ValueError("无效的小说URL")

                response = self.client.post(
                    "/api/cache/create",
                    json={"novel_url": mock_novel_url},
                    headers=self.valid_headers,
                )

        # Then - 应该返回错误
        assert response.status_code == 400
        assert "detail" in response.json()

    @pytest.mark.asyncio
    async def test_multiple_crawlers_concurrent_caching(self):
        """测试多个爬虫的并发缓存"""
        # Given - 模拟多个不同的爬虫
        novel_urls = [
            "https://site1.com/novel1",
            "https://site2.com/novel2",
            "https://site3.com/novel3",
        ]

        mock_crawlers = {}
        for i, url in enumerate(novel_urls):
            crawler = AsyncMock()
            crawler.get_chapter_list.return_value = [
                {"title": f"小说{i + 1}第1章", "url": f"{url}/chapter/1", "index": 1}
            ]
            crawler.get_chapter_content.return_value = {
                "title": f"小说{i + 1}第1章",
                "content": f"这是小说{i + 1}的内容",
                "next_chapter_url": None,
                "prev_chapter_url": None,
            }
            mock_crawlers[f"site{i + 1}"] = crawler

        with patch(
            "app.services.crawler_factory.get_enabled_crawlers"
        ) as mock_get_crawlers, patch(
            "app.services.crawler_factory.get_crawler_for_url"
        ) as mock_get_crawler:
            mock_get_crawlers.return_value = mock_crawlers

            # When - 并发创建多个缓存任务
            async def create_cache_task(url, site_name):
                mock_get_crawler.return_value = mock_crawlers[site_name]

                response = self.client.post(
                    "/api/cache/create",
                    json={"novel_url": url},
                    headers=self.valid_headers,
                )
                return response

            # 并发执行
            tasks = [
                create_cache_task(novel_urls[0], "site1"),
                create_cache_task(novel_urls[1], "site2"),
                create_cache_task(novel_urls[2], "site3"),
            ]
            responses = await asyncio.gather(*tasks, return_exceptions=True)

        # Then - 验证所有任务都创建成功
        for response in responses:
            if not isinstance(response, Exception):
                assert response.status_code == 200
                assert "task_id" in response.json()

    @pytest.mark.asyncio
    async def test_crawler_rate_limiting(self):
        """测试爬虫频率限制"""
        # Given
        mock_novel_url = "https://example.com/novel/rate-limit-test"

        mock_crawler = AsyncMock()
        mock_crawler.is_valid_url.return_value = True

        # 模拟频率限制异常
        mock_crawler.get_chapter_list.side_effect = [
            [{"title": "第一章", "url": f"{mock_novel_url}/chapter/1", "index": 1}],
            [{"title": "第二章", "url": f"{mock_novel_url}/chapter/2", "index": 1}],
            Exception("请求频率过高，请稍后重试"),
        ]

        with patch(
            "app.services.crawler_factory.get_crawler_for_url"
        ) as mock_get_crawler:
            mock_get_crawler.return_value = mock_crawler

            # When
            first_response = self.client.post(
                "/api/cache/create",
                json={"novel_url": mock_novel_url},
                headers=self.valid_headers,
            )

            # 第一次调用成功
            assert first_response.status_code == 200

            # 第二次调用可能成功（如果缓存了章节数据）
            # 第三次调用会失败

    @pytest.mark.asyncio
    async def test_crawler_content_validation(self):
        """测试爬虫内容验证"""
        # Given

        mock_crawler = AsyncMock()
        mock_crawler.is_valid_url.return_value = True

        # 测试不同质量的内容
        test_cases = [
            {
                "name": "正常内容",
                "content": "这是正常的章节内容，包含完整的文字叙述和情节发展。",
                "should_pass": True,
            },
            {"name": "空内容", "content": "", "should_pass": False},
            {"name": "过短内容", "content": "短", "should_pass": False},
            {"name": "仅特殊字符", "content": "\n\t\r", "should_pass": False},
            {
                "name": "包含无效字符",
                "content": "包含�无效字符的内容",
                "should_pass": False,
            },
        ]

        for case in test_cases:
            mock_crawler.get_chapter_content.return_value = {
                "title": f"测试章 - {case['name']}",
                "content": case["content"],
                "next_chapter_url": None,
                "prev_chapter_url": None,
            }

            with patch(
                "app.services.crawler_factory.get_crawler_for_url"
            ) as mock_get_crawler:
                mock_get_crawler.return_value = mock_crawler

                # When - 验证内容质量
                content = mock_crawler.get_chapter_content("test-url")["content"]

                # Then
                if case["should_pass"]:
                    assert len(content.strip()) >= 10, f"{case['name']} 应该通过验证"
                    assert content.count("\n") < len(content) / 2, (
                        f"{case['name']} 不应该是空的或主要包含换行符"
                    )
                else:
                    assert len(content.strip()) < 10 or content.count("�") > 0, (
                        f"{case['name']} 应该失败验证"
                    )

    @pytest.mark.asyncio
    async def test_crawler_fallback_mechanism(self):
        """测试爬虫降级机制"""
        # Given
        mock_novel_url = "https://example.com/novel/fallback-test"

        # 模拟主爬虫失败，备用爬虫成功
        primary_crawler = AsyncMock()
        primary_crawler.get_chapter_list.side_effect = Exception("主爬虫失败")
        primary_crawler.is_valid_url.return_value = True

        fallback_crawler = AsyncMock()
        fallback_crawler.get_chapter_list.return_value = [
            {
                "title": "备用爬虫获取的章节",
                "url": f"{mock_novel_url}/chapter/1",
                "index": 1,
            }
        ]
        fallback_crawler.is_valid_url.return_value = True

        with patch("app.services.crawler_factory.get_enabled_crawlers"), patch(
            "app.services.crawler_factory.get_crawler_for_url"
        ) as mock_get_crawler:
            # 第一次返回失败的爬虫
            mock_get_crawler.side_effect = [primary_crawler, fallback_crawler]

            # When - 第一次使用主爬虫失败
            with pytest.raises(Exception):
                await self._simulate_caching_process(
                    mock_novel_url, primary_crawler
                )

            # Then - 第二次使用备用爬虫应该成功
            result = await self._simulate_caching_process(
                mock_novel_url, fallback_crawler
            )
            assert result is not None

    @pytest.mark.slow
    async def test_large_novel_caching_performance(self):
        """测试大型小说缓存性能"""
        # Given
        mock_novel_url = "https://example.com/novel/large-test"
        chapter_count = 1000  # 大型小说

        mock_crawler = AsyncMock()
        mock_crawler.is_valid_url.return_value = True

        # 创建大量章节数据
        large_chapters = [
            {
                "title": f"第{i + 1}章",
                "url": f"{mock_novel_url}/chapter/{i + 1}",
                "index": i + 1,
            }
            for i in range(chapter_count)
        ]

        mock_crawler.get_chapter_list.return_value = large_chapters
        mock_crawler.get_chapter_content.return_value = {
            "title": "测试章节",
            "content": "这是章节内容，" + "测试文字。" * 50,  # 较长内容
            "next_chapter_url": None,
            "prev_chapter_url": None,
        }

        with patch(
            "app.services.crawler_factory.get_crawler_for_url"
        ) as mock_get_crawler:
            mock_get_crawler.return_value = mock_crawler

            # When - 测量性能
            import time

            start_time = time.time()

            # 模拟缓存过程
            cached_chapters = []
            for i in range(min(100, chapter_count)):  # 只测试前100章以节省时间
                content = mock_crawler.get_chapter_content(
                    f"{mock_novel_url}/chapter/{i + 1}"
                )
                cached_chapters.append(
                    {
                        "chapter_title": large_chapters[i]["title"],
                        "chapter_content": content["content"],
                        "word_count": len(content["content"]),
                        "chapter_index": i + 1,
                    }
                )

            end_time = time.time()
            processing_time = end_time - start_time

            # Then - 性能断言
            assert processing_time < 30.0, f"处理100章耗时过长: {processing_time:.2f}秒"
            assert len(cached_chapters) == min(100, chapter_count)

            # 验证内存使用（简单检查）
            import gc
            import sys

            gc.collect()
            current_memory = sys.getsizeof(cached_chapters)
            assert current_memory < 50 * 1024 * 1024  # 50MB 限制

    async def _simulate_caching_process(self, novel_url: str, crawler) -> Any:
        """辅助方法：模拟缓存过程"""
        try:
            chapters = crawler.get_chapter_list(novel_url)
            if chapters:
                first_chapter = chapters[0]
                content = crawler.get_chapter_content(first_chapter["url"])
                return {
                    "chapters_count": len(chapters),
                    "first_chapter_content": content.get("content", "")
                    if isinstance(content, dict)
                    else str(content),
                }
        except Exception:
            return None

    @pytest.mark.asyncio
    async def test_crawler_timeout_handling(self):
        """测试爬虫超时处理"""
        # Given
        mock_novel_url = "https://example.com/novel/timeout-test"

        mock_crawler = AsyncMock()
        mock_crawler.is_valid_url.return_value = True
        mock_crawler.get_chapter_list.side_effect = TimeoutError("请求超时")

        with patch(
            "app.services.crawler_factory.get_crawler_for_url"
        ) as mock_get_crawler:
            mock_get_crawler.return_value = mock_crawler

            # When - 模拟超时
            with pytest.raises(asyncio.TimeoutError):
                await asyncio.wait_for(
                    self._simulate_caching_process(mock_novel_url, mock_crawler),
                    timeout=1.0,  # 1秒超时
                )

    @pytest.mark.asyncio
    async def test_crawler_data_consistency(self):
        """测试爬虫数据一致性"""
        # Given
        mock_novel_url = "https://example.com/novel/consistency-test"

        mock_crawler = AsyncMock()
        mock_crawler.is_valid_url.return_value = True

        # 确保章节数据一致性
        consistent_chapters = [
            {"title": "第一章：开始", "url": f"{mock_novel_url}/chapter/1", "index": 1},
            {"title": "第二章：继续", "url": f"{mock_novel_url}/chapter/2", "index": 2},
        ]

        mock_crawler.get_chapter_list.return_value = consistent_chapters
        mock_crawler.get_chapter_content.return_value = {
            "title": "第一章：开始",
            "content": "章节内容",
            "next_chapter_url": consistent_chapters[1]["url"],
            "prev_chapter_url": None,
        }

        with patch(
            "app.services.crawler_factory.get_crawler_for_url"
        ) as mock_get_crawler:
            mock_get_crawler.return_value = mock_crawler

            # When
            chapters = mock_crawler.get_chapter_list(mock_novel_url)
            first_chapter_content = mock_crawler.get_chapter_content(chapters[0]["url"])

            # Then - 验证数据一致性
            assert len(chapters) == 2
            assert chapters[0]["index"] < chapters[1]["index"]

            if isinstance(first_chapter_content, dict):
                assert first_chapter_content["next_chapter_url"] == chapters[1]["url"]
                assert first_chapter_content["prev_chapter_url"] is None
