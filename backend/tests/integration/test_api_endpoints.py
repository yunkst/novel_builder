#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Integration tests for API endpoints.
"""

import pytest
from httpx import AsyncClient
from unittest.mock import patch, AsyncMock


@pytest.mark.integration
@pytest.mark.auth
class TestAPIIntegration:
    """Integration tests for API endpoints."""

    async def test_full_search_flow(
        self,
        async_client: AsyncClient,
        valid_token: str,
        sample_novel_data: dict,
        sample_chapter_data: dict,
    ) -> None:
        """Test complete flow from search to chapter content."""
        # Mock the entire crawler chain
        with patch("app.main.get_enabled_crawlers") as mock_get_crawlers:
            # Setup mock crawler
            mock_crawler = AsyncMock()
            mock_crawler.search.return_value = [sample_novel_data]
            mock_crawler.get_chapters.return_value = [sample_chapter_data]
            mock_crawler.get_chapter_content.return_value = {
                "title": sample_chapter_data["title"],
                "content": "这是章节内容...",
                "next_chapter_url": None,
                "prev_chapter_url": None,
            }

            mock_get_crawlers.return_value = {"test_site": mock_crawler}

            headers = {"X-API-TOKEN": valid_token}

            # Step 1: Search for novels
            search_response = await async_client.get("/search?keyword=test", headers=headers)
            assert search_response.status_code == 200
            novels = search_response.json()
            assert len(novels) == 1
            assert novels[0]["title"] == sample_novel_data["title"]

            # Step 2: Get chapters for the novel
            novel_url = novels[0]["url"]
            chapters_response = await async_client.get(
                f"/chapters?novel_url={novel_url}", headers=headers
            )
            assert chapters_response.status_code == 200
            chapters = chapters_response.json()
            assert len(chapters) == 1
            assert chapters[0]["title"] == sample_chapter_data["title"]

            # Step 3: Get chapter content
            chapter_url = chapters[0]["url"]
            content_response = await async_client.get(
                f"/chapter-content?chapter_url={chapter_url}", headers=headers
            )
            assert content_response.status_code == 200
            content = content_response.json()
            assert content["title"] == sample_chapter_data["title"]
            assert "这是章节内容" in content["content"]

    async def test_error_propagation(
        self,
        async_client: AsyncClient,
        valid_token: str,
    ) -> None:
        """Test how errors propagate through the API."""
        with patch("app.main.get_enabled_crawlers") as mock_get_crawlers:
            # Setup mock crawler that raises exception
            mock_crawler = AsyncMock()
            mock_crawler.search.side_effect = Exception("Search failed")
            mock_get_crawlers.return_value = {"test_site": mock_crawler}

            headers = {"X-API-TOKEN": valid_token}
            response = await async_client.get("/search?keyword=test", headers=headers)

            # Should handle error gracefully
            assert response.status_code in [500, 200]

    async def test_concurrent_requests(
        self,
        async_client: AsyncClient,
        valid_token: str,
        sample_novel_data: dict,
    ) -> None:
        """Test handling of concurrent requests."""
        import asyncio

        with patch("app.main.get_enabled_crawlers") as mock_get_crawlers:
            # Setup mock crawler with delay to simulate real work
            mock_crawler = AsyncMock()

            async def slow_search(*args, **kwargs):
                await asyncio.sleep(0.1)  # Simulate network delay
                return [sample_novel_data]

            mock_crawler.search.side_effect = slow_search
            mock_get_crawlers.return_value = {"test_site": mock_crawler}

            headers = {"X-API-TOKEN": valid_token}

            # Make multiple concurrent requests
            tasks = [
                async_client.get("/search?keyword=test", headers=headers)
                for _ in range(5)
            ]

            responses = await asyncio.gather(*tasks)

            # All requests should succeed
            for response in responses:
                assert response.status_code == 200
                data = response.json()
                assert len(data) == 1

    async def test_api_rate_limiting(
        self,
        async_client: AsyncClient,
        valid_token: str,
    ) -> None:
        """Test API rate limiting (if implemented)."""
        headers = {"X-API-TOKEN": valid_token}

        # Make multiple requests in quick succession
        responses = []
        for _ in range(10):
            response = await async_client.get("/search?keyword=test", headers=headers)
            responses.append(response)

        # Check if any requests were rate limited
        rate_limited = any(r.status_code == 429 for r in responses)
        # Rate limiting might not be implemented, so this is informational
        print(f"Rate limiting detected: {rate_limited}")

    async def test_response_headers(
        self,
        async_client: AsyncClient,
        valid_token: str,
    ) -> None:
        """Test API response headers."""
        headers = {"X-API-TOKEN": valid_token}
        response = await async_client.get("/search?keyword=test", headers=headers)

        # Check for common response headers
        assert "content-type" in response.headers
        assert response.headers["content-type"] == "application/json"

        # Check for CORS headers
        cors_headers = [
            "access-control-allow-origin",
            "access-control-allow-methods",
            "access-control-allow-headers",
        ]

        for header in cors_headers:
            if header in response.headers:
                assert response.headers[header] is not None

    @pytest.mark.slow
    async def test_large_response_handling(
        self,
        async_client: AsyncClient,
        valid_token: str,
    ) -> None:
        """Test handling of large responses."""
        # Create mock data with many results
        large_novel_list = [
            {
                "title": f"测试小说 {i}",
                "author": f"测试作者 {i}",
                "url": f"https://example.com/novel/{i}",
                "cover_url": f"https://example.com/cover/{i}.jpg",
                "description": f"这是第{i}本测试小说的描述",
                "status": "ongoing",
                "last_updated": "2024-01-01T00:00:00Z"
            }
            for i in range(100)  # 100 novels
        ]

        with patch("app.main.get_enabled_crawlers") as mock_get_crawlers:
            mock_crawler = AsyncMock()
            mock_crawler.search.return_value = large_novel_list
            mock_get_crawlers.return_value = {"test_site": mock_crawler}

            headers = {"X-API-TOKEN": valid_token}
            response = await async_client.get("/search?keyword=test", headers=headers)

            assert response.status_code == 200
            data = response.json()
            assert len(data) == 100

            # Verify response size is reasonable
            response_size = len(response.content)
            assert response_size > 1000  # Should be substantial
            assert response_size < 10_000_000  # But not too large


@pytest.mark.integration
class TestHealthChecks:
    """Integration tests for health check endpoints."""

    async def test_health_check_under_load(
        self,
        async_client: AsyncClient,
    ) -> None:
        """Test health check under concurrent load."""
        import asyncio

        # Make many concurrent health check requests
        tasks = [
            async_client.get("/health") for _ in range(50)
        ]

        responses = await asyncio.gather(*tasks)

        # All health checks should succeed quickly
        for response in responses:
            assert response.status_code == 200
            assert response.json() == {"status": "ok"}

            # Response time should be fast
            assert response.elapsed.total_seconds() < 1.0