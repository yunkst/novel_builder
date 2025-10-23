#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Test data factories for creating realistic test data.
"""

import factory
from datetime import datetime, timezone
from typing import Dict, Any, List


class NovelFactory(factory.Factory):
    """Factory for creating novel test data."""

    class Meta:
        model = dict

    title = factory.Faker("sentence", nb_words=3)
    author = factory.Faker("name")
    url = factory.Faker("url")
    cover_url = factory.Faker("image_url")
    description = factory.Faker("paragraph", nb_sentences=2)
    status = factory.fuzzy.FuzzyChoice(["ongoing", "completed", "hiatus"])
    last_updated = factory.LazyFunction(
        lambda: datetime.now(timezone.utc).isoformat()
    )

    @classmethod
    def create_batch(cls, size, **kwargs) -> List[Dict[str, Any]]:
        """Create a batch of novel data."""
        return [cls.create(**kwargs) for _ in range(size)]


class ChapterFactory(factory.Factory):
    """Factory for creating chapter test data."""

    class Meta:
        model = dict

    title = factory.Faker("sentence", nb_words=5)
    url = factory.Faker("url")
    index = factory.Sequence(lambda n: n + 1)
    is_cached = factory.Faker("boolean")


class ChapterContentFactory(factory.Factory):
    """Factory for creating chapter content test data."""

    class Meta:
        model = dict

    title = factory.Faker("sentence", nb_words=5)
    content = factory.Faker("paragraph", nb_sentences=10)
    next_chapter_url = factory.Faker("url")
    prev_chapter_url = factory.Maybe(factory.Faker("url"))


class SearchResultsFactory:
    """Factory for creating realistic search results."""

    @staticmethod
    def create_empty_results() -> List[Dict[str, Any]]:
        """Create empty search results."""
        return []

    @staticmethod
    def create_single_result(**overrides) -> Dict[str, Any]:
        """Create a single search result with optional overrides."""
        result = NovelFactory.create()
        result.update(overrides)
        return result

    @staticmethod
    def create_multiple_results(count: int, **overrides) -> List[Dict[str, Any]]:
        """Create multiple search results."""
        return NovelFactory.create_batch(count, **overrides)

    @staticmethod
    def create_mixed_quality_results() -> List[Dict[str, Any]]:
        """Create results with varying quality for testing filtering."""
        results = [
            NovelFactory.create(title="高质量小说", author="知名作者"),
            NovelFactory.create(title="低质量小说", author="", description=""),  # Missing author/description
            NovelFactory.create(title="正常小说", author="普通作者", status="completed"),
            NovelFactory.create(title="连载小说", author="新人作者", status="ongoing"),
        ]
        return results


class APITestDataFactory:
    """Factory for API-specific test data."""

    @staticmethod
    def create_valid_auth_token() -> str:
        """Create a valid API token for testing."""
        return "test-api-token-12345"

    @staticmethod
    def create_invalid_auth_token() -> str:
        """Create an invalid API token for testing."""
        return "invalid-token"

    @staticmethod
    def create_search_request_data(keyword: str = None) -> Dict[str, Any]:
        """Create search request data."""
        return {
            "keyword": keyword or "测试关键词",
            "site": "test_site",
            "limit": 20
        }

    @staticmethod
    def create_expected_response_structure() -> Dict[str, Any]:
        """Create expected API response structure."""
        return {
            "status": "success",
            "data": [],
            "total": 0,
            "page": 1,
            "limit": 20
        }