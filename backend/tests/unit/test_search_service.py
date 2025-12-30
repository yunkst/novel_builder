#!/usr/bin/env python3

"""
Unit tests for SearchService - focus on business logic without external dependencies.
"""

from unittest.mock import AsyncMock

import pytest

from app.services.search_service import SearchService


class TestSearchService:
    """Test SearchService business logic."""

    def test_search_service_initialization(self):
        """Test SearchService can be initialized."""
        service = SearchService()
        assert service is not None

    @pytest.mark.asyncio
    async def test_search_with_empty_crawler_list(self):
        """Test search with no crawlers returns empty list."""
        service = SearchService()
        results = await service.search("test", {})
        assert results == []

    @pytest.mark.asyncio
    async def test_search_with_single_crawler_success(self):
        """Test search with one working crawler."""
        service = SearchService()

        # Create a real mock crawler that behaves like real one
        mock_crawler = AsyncMock()
        # 使用正确的方法名 search_novels
        mock_crawler.search_novels.return_value = [
            {
                "title": "测试小说",
                "author": "测试作者",
                "url": "https://example.com/novel/1",
                "cover_url": "https://example.com/cover.jpg",
                "description": "测试描述",
                "status": "ongoing",
                "last_updated": "2024-01-01T00:00:00Z",
            }
        ]

        crawlers = {"test_site": mock_crawler}
        results = await service.search("test", crawlers)

        assert len(results) == 1
        assert results[0]["title"] == "测试小说"
        assert results[0]["author"] == "测试作者"
        mock_crawler.search_novels.assert_called_once_with("test")

    @pytest.mark.asyncio
    async def test_search_with_multiple_crawlers(self):
        """Test search with multiple crawlers aggregates results."""
        service = SearchService()

        # Create multiple crawlers with different results
        crawler1 = AsyncMock()
        crawler1.search_novels.return_value = [
            {
                "title": "小说1",
                "author": "作者1",
                "url": "https://example.com/1",
                "cover_url": "",
                "description": "",
                "status": "ongoing",
                "last_updated": "2024-01-01T00:00:00Z",
            }
        ]

        crawler2 = AsyncMock()
        crawler2.search_novels.return_value = [
            {
                "title": "小说2",
                "author": "作者2",
                "url": "https://example.com/2",
                "cover_url": "",
                "description": "",
                "status": "ongoing",
                "last_updated": "2024-01-01T00:00:00Z",
            }
        ]

        crawlers = {"site1": crawler1, "site2": crawler2}
        results = await service.search("test", crawlers)

        assert len(results) == 2
        titles = [r["title"] for r in results]
        assert "小说1" in titles
        assert "小说2" in titles

    @pytest.mark.asyncio
    async def test_search_crawler_error_handling(self):
        """Test search handles crawler errors gracefully."""
        service = SearchService()

        # One crawler fails, one succeeds
        failing_crawler = AsyncMock()
        # 添加 search_novels 方法使 hasattr 检查通过
        failing_crawler.search_novels.side_effect = Exception("Network error")

        working_crawler = AsyncMock()
        working_crawler.search_novels.return_value = [
            {
                "title": "正常小说",
                "author": "正常作者",
                "url": "https://example.com/normal",
                "cover_url": "",
                "description": "",
                "status": "ongoing",
                "last_updated": "2024-01-01T00:00:00Z",
            }
        ]

        crawlers = {"failing": failing_crawler, "working": working_crawler}
        results = await service.search("test", crawlers)

        # Should return results from working crawler only
        assert len(results) == 1
        assert results[0]["title"] == "正常小说"

    @pytest.mark.asyncio
    async def test_search_crawler_timeout_handling(self):
        """Test search handles crawler timeouts."""

        service = SearchService()

        # Create a crawler that times out
        slow_crawler = AsyncMock()
        slow_crawler.search_novels.side_effect = TimeoutError("Timeout")

        fast_crawler = AsyncMock()
        fast_crawler.search_novels.return_value = [
            {
                "title": "快速结果",
                "author": "快速作者",
                "url": "https://example.com/fast",
                "cover_url": "",
                "description": "",
                "status": "ongoing",
                "last_updated": "2024-01-01T00:00:00Z",
            }
        ]

        crawlers = {"slow": slow_crawler, "fast": fast_crawler}
        results = await service.search("test", crawlers)

        # Should return results from fast crawler
        assert len(results) == 1
        assert results[0]["title"] == "快速结果"

    def test_result_validation(self):
        """Test that search results are properly validated."""
        # Placeholder for future validation implementation
        # This would test result format validation in SearchService
        assert True  # Temporary placeholder
