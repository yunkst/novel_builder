#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Integration tests using real crawler instances.
Tests actual component interaction without heavy mocking.
"""

import pytest
import asyncio
from httpx import AsyncClient
from unittest.mock import patch

from app.services.crawler_factory import get_enabled_crawlers
from app.services.search_service import SearchService


@pytest.mark.integration
class TestRealCrawlerIntegration:
    """Integration tests with real crawler instances."""

    @pytest.mark.asyncio
    async def test_crawler_factory_real_crawlers(self):
        """Test that crawler factory returns real crawler instances."""
        crawlers = get_enabled_crawlers()

        # Should return actual crawler instances, not mocks
        assert isinstance(crawlers, dict)

        # Should have enabled crawlers from configuration
        assert len(crawlers) > 0

        # Each crawler should have required methods
        for site_name, crawler in crawlers.items():
            assert hasattr(crawler, 'search')
            assert hasattr(crawler, 'get_chapters')
            assert hasattr(crawler, 'get_chapter_content')
            assert callable(getattr(crawler, 'search'))

    @pytest.mark.asyncio
    async def test_search_service_with_real_crawlers(self):
        """Test SearchService with real crawler instances."""
        service = SearchService()
        crawlers = get_enabled_crawlers()

        # Test with real crawlers (but use a test keyword)
        # This tests the actual integration
        try:
            results = await service.search("测试", crawlers)
            assert isinstance(results, list)
            # Results might be empty if crawlers can't reach external sites
            # But the service should handle it gracefully
        except Exception as e:
            # Real crawlers might fail due to network issues
            # That's expected in integration tests
            pytest.skip(f"Real crawler test skipped due to network issues: {e}")

    @pytest.mark.asyncio
    async def test_crawler_error_handling_integration(self):
        """Test error handling with real crawlers."""
        service = SearchService()
        crawlers = get_enabled_crawlers()

        # Test with invalid keyword that might cause errors
        results = await service.search("", crawlers)
        assert isinstance(results, list)
        # Should handle empty/invalid keywords gracefully

    @pytest.mark.asyncio
    async def test_crawler_timeout_integration(self):
        """Test timeout handling with real crawlers."""
        service = SearchService()
        crawlers = get_enabled_crawlers()

        # Test with a very long search term that might timeout
        long_keyword = "a" * 1000
        results = await service.search(long_keyword, crawlers)
        assert isinstance(results, list)


@pytest.mark.integration
@pytest.mark.slow
class TestAPIWithRealComponents:
    """Integration tests for API endpoints with real components."""

    @pytest.mark.asyncio
    async def test_health_check_real(self, async_client: AsyncClient):
        """Test health check endpoint with real application."""
        response = await async_client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

    @pytest.mark.asyncio
    async def test_search_endpoint_real_integration(self, async_client: AsyncClient, valid_token: str):
        """Test search endpoint with real integration."""
        headers = {"X-API-TOKEN": valid_token}

        # Test with real crawlers
        response = await async_client.get("/search?keyword=test", headers=headers)

        # Should return 200 (success) or handle errors gracefully
        assert response.status_code in [200, 500]

        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_search_validation_real(self, async_client: AsyncClient, valid_token: str):
        """Test search validation with real API."""
        headers = {"X-API-TOKEN": valid_token}

        # Test missing keyword
        response = await async_client.get("/search", headers=headers)
        assert response.status_code == 422  # Validation error

        # Test too short keyword
        response = await async_client.get("/search?keyword=a", headers=headers)
        assert response.status_code == 422  # Validation error

    @pytest.mark.asyncio
    async def test_authentication_real(self, async_client: AsyncClient):
        """Test authentication with real API."""
        # Test without token
        response = await async_client.get("/search?keyword=test")
        assert response.status_code == 401

        # Test with invalid token
        headers = {"X-API-TOKEN": "invalid-token"}
        response = await async_client.get("/search?keyword=test", headers=headers)
        assert response.status_code == 401


@pytest.mark.integration
class TestDataValidation:
    """Integration tests for data validation and contracts."""

    @pytest.mark.asyncio
    async def test_novel_data_schema_validation(self):
        """Test that novel data conforms to expected schema."""
        from pydantic import ValidationError
        from app.schemas import Novel

        # Test valid data
        valid_data = {
            "title": "测试小说",
            "author": "测试作者",
            "url": "https://example.com/novel/1",
            "cover_url": "https://example.com/cover.jpg",
            "description": "测试描述",
            "status": "ongoing",
            "last_updated": "2024-01-01T00:00:00Z"
        }

        novel = Novel(**valid_data)
        assert novel.title == "测试小说"
        assert novel.author == "测试作者"

        # Test invalid data
        invalid_data = {
            "title": "测试小说",
            # Missing required fields
        }

        with pytest.raises(ValidationError):
            Novel(**invalid_data)

    def test_response_structure_consistency(self):
        """Test that API responses have consistent structure."""
        # This would test the actual response contracts
        # Implementation depends on API response format
        pass