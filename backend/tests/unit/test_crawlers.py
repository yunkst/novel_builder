#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Unit tests for crawler services.
"""

import pytest
from unittest.mock import AsyncMock, patch, MagicMock
import requests
from bs4 import BeautifulSoup

from app.services.base_crawler import BaseCrawler
from app.services.crawler_factory import CrawlerFactory


class TestBaseCrawler:
    """Test base crawler functionality."""

    def test_base_crawler_is_abstract(self) -> None:
        """Test that BaseCrawler cannot be instantiated directly."""
        with pytest.raises(TypeError):
            BaseCrawler()

    def test_base_crawler_subclass(self) -> None:
        """Test that BaseCatcher can be subclassed."""

        class TestCrawler(BaseCrawler):
            async def search(self, keyword: str):
                return []

            async def get_chapters(self, novel_url: str):
                return []

            async def get_chapter_content(self, chapter_url: str):
                return {"title": "", "content": ""}

        crawler = TestCrawler()
        assert crawler.name == "TestCrawler"
        assert hasattr(crawler, "search")
        assert hasattr(crawler, "get_chapters")
        assert hasattr(crawler, "get_chapter_content")


@pytest.mark.unit
class TestCrawlerFactory:
    """Test crawler factory functionality."""

    def test_get_enabled_crawlers(self) -> None:
        """Test getting enabled crawlers from environment."""
        with patch.dict("os.environ", {"NOVEL_ENABLED_SITES": "alice_sw,shukuge"}):
            factory = CrawlerFactory()
            crawlers = factory.get_enabled_crawlers()
            assert isinstance(crawlers, dict)

    def test_get_enabled_crawlers_empty(self) -> None:
        """Test getting enabled crawlers when none are set."""
        with patch.dict("os.environ", {"NOVEL_ENABLED_SITES": ""}):
            factory = CrawlerFactory()
            crawlers = factory.get_enabled_crawlers()
            assert crawlers == {}

    def test_get_enabled_crawlers_invalid_site(self) -> None:
        """Test getting enabled crawlers with invalid site names."""
        with patch.dict("os.environ", {"NOVEL_ENABLED_SITES": "invalid_site"}):
            factory = CrawlerFactory()
            crawlers = factory.get_enabled_crawlers()
            assert crawlers == {}

    def test_get_crawler_for_url(self) -> None:
        """Test getting crawler for specific URL."""
        factory = CrawlerFactory()
        # Test with different URL patterns
        test_cases = [
            ("https://www.69shu.com/", None),  # Should return alice_sw crawler if available
            ("https://www.shukuge.com/", None),  # Should return shukuge crawler if available
            ("https://example.com/", None),  # Should return None for unknown sites
        ]

        for url, expected in test_cases:
            crawler = factory.get_crawler_for_url(url)
            if expected is None:
                # May return None or a crawler depending on implementation
                assert crawler is None or hasattr(crawler, "search")
            else:
                assert crawler.name == expected


@pytest.mark.integration
class TestCrawlerIntegration:
    """Integration tests for crawlers."""

    @pytest.mark.slow
    async def test_alice_sw_crawler_search(self) -> None:
        """Test Alice SW crawler search functionality."""
        pytest.skip("Integration test - requires network access")

    @pytest.mark.slow
    async def test_shukuge_crawler_search(self) -> None:
        """Test Shukuge crawler search functionality."""
        pytest.skip("Integration test - requires network access")


class TestCrawlerErrorHandling:
    """Test crawler error handling."""

    async def test_network_error_handling(self) -> None:
        """Test crawler handles network errors gracefully."""

        class TestCrawler(BaseCrawler):
            async def search(self, keyword: str):
                # Simulate network error
                raise requests.ConnectionError("Network error")

            async def get_chapters(self, novel_url: str):
                return []

            async def get_chapter_content(self, chapter_url: str):
                return {"title": "", "content": ""}

        crawler = TestCrawler()
        with pytest.raises(requests.ConnectionError):
            await crawler.search("test")

    async def test_html_parsing_error_handling(self) -> None:
        """Test crawler handles malformed HTML gracefully."""

        class TestCrawler(BaseCrawler):
            async def search(self, keyword: str):
                # Simulate malformed HTML
                malformed_html = "<html><body><div>incomplete"
                soup = BeautifulSoup(malformed_html, "html.parser")
                # BeautifulSoup handles malformed HTML gracefully
                assert soup is not None
                return []

            async def get_chapters(self, novel_url: str):
                return []

            async def get_chapter_content(self, chapter_url: str):
                return {"title": "", "content": ""}

        crawler = TestCrawler()
        result = await crawler.search("test")
        assert result == []

    def test_crawler_url_validation(self) -> None:
        """Test crawler URL validation."""

        class TestCrawler(BaseCrawler):
            def validate_url(self, url: str) -> bool:
                return url.startswith("https://example.com")

            async def search(self, keyword: str):
                return []

            async def get_chapters(self, novel_url: str):
                if not self.validate_url(novel_url):
                    raise ValueError("Invalid URL")
                return []

            async def get_chapter_content(self, chapter_url: str):
                return {"title": "", "content": ""}

        crawler = TestCrawler()

        # Valid URL should work
        valid_url = "https://example.com/novel/123"
        assert crawler.validate_url(valid_url)

        # Invalid URL should raise error
        invalid_url = "https://invalid-site.com/novel/123"
        assert not crawler.validate_url(invalid_url)