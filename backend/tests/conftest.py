#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Pytest configuration and fixtures for Novel Builder Backend tests.
Focused on real testing with minimal mocking.
"""

import os
import sys
import pytest
import asyncio
from typing import AsyncGenerator, Generator, Dict, Any
from unittest.mock import AsyncMock, MagicMock

# Add app directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi.testclient import TestClient
from httpx import AsyncClient

from app.main import app
from app.config import settings

# Import test factories
from tests.factories import (
    NovelFactory, ChapterFactory, ChapterContentFactory,
    SearchResultsFactory, APITestDataFactory
)


@pytest.fixture(scope="session")
def event_loop() -> Generator[asyncio.AbstractEventLoop, None, None]:
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def client() -> Generator[TestClient, None, None]:
    """Create a FastAPI test client."""
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
async def async_client() -> AsyncGenerator[AsyncClient, None]:
    """Create an async HTTP client for testing."""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def mock_settings() -> MagicMock:
    """Mock settings for testing."""
    settings_mock = MagicMock()
    settings_mock.api_token = "test-token"
    settings_mock.enabled_sites = "test_site"
    settings_mock.secret_key = "test-secret-key"
    settings_mock.debug = True
    return settings_mock


@pytest.fixture
def valid_token() -> str:
    """Return a valid API token for testing."""
    return "test-token"


@pytest.fixture
def invalid_token() -> str:
    """Return an invalid API token for testing."""
    return "invalid-token"


@pytest.fixture
def sample_novel_data() -> dict:
    """Sample novel data for testing using factory."""
    return NovelFactory.create()

@pytest.fixture
def sample_chapter_data() -> dict:
    """Sample chapter data for testing using factory."""
    return ChapterFactory.create()

@pytest.fixture
def sample_chapter_content() -> dict:
    """Sample chapter content for testing using factory."""
    return ChapterContentFactory.create()

@pytest.fixture
def multiple_novel_data() -> list:
    """Multiple novel data for testing."""
    return NovelFactory.create_batch(5)

@pytest.fixture
def search_results_empty() -> list:
    """Empty search results for testing."""
    return SearchResultsFactory.create_empty_results()

@pytest.fixture
def search_results_single() -> list:
    """Single search result for testing."""
    return [SearchResultsFactory.create_single_result()]

@pytest.fixture
def search_results_multiple() -> list:
    """Multiple search results for testing."""
    return SearchResultsFactory.create_multiple_results(3)


@pytest.fixture
def mock_crawler() -> AsyncMock:
    """Mock crawler for testing."""
    crawler = AsyncMock()
    crawler.search.return_value = [
        {
            "title": "测试小说",
            "author": "测试作者",
            "url": "https://example.com/novel/123",
            "cover_url": "https://example.com/cover.jpg",
            "description": "测试描述",
            "status": "ongoing",
            "last_updated": "2024-01-01T00:00:00Z"
        }
    ]
    crawler.get_chapters.return_value = [
        {
            "title": "第一章：开始",
            "url": "https://example.com/chapter/1",
            "index": 1
        }
    ]
    crawler.get_chapter_content.return_value = {
        "title": "第一章：开始",
        "content": "这是第一章的内容...",
        "next_chapter_url": "https://example.com/chapter/2",
        "prev_chapter_url": None
    }
    return crawler


@pytest.fixture
def mock_crawler_factory(mock_crawler: AsyncMock) -> AsyncMock:
    """Mock crawler factory for testing."""
    factory = AsyncMock()
    factory.get_enabled_crawlers.return_value = {"test_site": mock_crawler}
    factory.get_crawler_for_url.return_value = mock_crawler
    return factory


# Markers for different test types
def pytest_configure(config):
    """Configure pytest markers."""
    config.addinivalue_line("markers", "unit: Unit tests")
    config.addinivalue_line("markers", "integration: Integration tests")
    config.addinivalue_line("markers", "slow: Slow running tests")
    config.addinivalue_line("markers", "auth: Tests requiring authentication")


@pytest.fixture(autouse=True)
def override_settings(monkeypatch):
    """Override settings for all tests."""
    monkeypatch.setenv("NOVEL_API_TOKEN", "test-token")
    monkeypatch.setenv("NOVEL_ENABLED_SITES", "test_site")
    monkeypatch.setenv("SECRET_KEY", "test-secret-key")
    monkeypatch.setenv("DEBUG", "true")