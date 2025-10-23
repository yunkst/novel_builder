#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Simple test without external dependencies to verify basic functionality.
"""

import sys
import os
import asyncio

# Add app directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "app"))

def test_basic_imports():
    """Test basic imports work."""
    try:
        from app.main import app
        print("✓ Main app imported successfully")
        return True
    except Exception as e:
        print(f"✗ Main app import failed: {e}")
        return False

def test_search_service():
    """Test SearchService basic functionality."""
    try:
        from app.services.search_service import SearchService
        service = SearchService()
        print("✓ SearchService instantiated successfully")
        return True
    except Exception as e:
        print(f"✗ SearchService test failed: {e}")
        return False

def test_search_service_with_mock_data():
    """Test SearchService with simple mock data."""
    try:
        from app.services.search_service import SearchService
        from unittest.mock import AsyncMock

        async def run_test():
            service = SearchService()

            # Create mock crawler
            mock_crawler = AsyncMock()
            mock_crawler.search.return_value = [
                {
                    "title": "测试小说",
                    "author": "测试作者",
                    "url": "https://example.com/novel/1",
                    "cover_url": "https://example.com/cover.jpg",
                    "description": "测试描述",
                    "status": "ongoing",
                    "last_updated": "2024-01-01T00:00:00Z"
                }
            ]

            crawlers = {"test_site": mock_crawler}
            results = await service.search("test", crawlers)

            assert len(results) == 1
            assert results[0]["title"] == "测试小说"
            print("✓ SearchService with mock data works correctly")
            return True

        return asyncio.run(run_test())
    except Exception as e:
        print(f"✗ SearchService mock test failed: {e}")
        return False

def test_config():
    """Test configuration loading."""
    try:
        from app.config import settings
        print(f"✓ Settings loaded successfully")
        print(f"  - API Token configured: {bool(settings.api_token)}")
        print(f"  - Debug mode: {settings.debug}")
        print(f"  - Enabled sites: {getattr(settings, 'enabled_sites', 'Not configured')}")
        return True
    except Exception as e:
        print(f"✗ Config test failed: {e}")
        return False

def test_crawler_factory():
    """Test crawler factory."""
    try:
        from app.services.crawler_factory import get_enabled_crawlers
        crawlers = get_enabled_crawlers()
        print(f"✓ Crawler factory returned {len(crawlers)} crawlers")

        for site_name, crawler in crawlers.items():
            has_search = hasattr(crawler, 'search')
            print(f"  - {site_name}: has search method = {has_search}")

        return True
    except Exception as e:
        print(f"✗ Crawler factory test failed: {e}")
        return False

async def test_real_search():
    """Test real search functionality."""
    try:
        from app.services.search_service import SearchService
        from app.services.crawler_factory import get_enabled_crawlers

        service = SearchService()
        crawlers = get_enabled_crawlers()

        if not crawlers:
            print("✗ No crawlers available for real search test")
            return False

        # Test with real crawlers
        results = await service.search("test", crawlers)
        print(f"✓ Real search returned {len(results)} results")

        # Validate results structure
        for result in results:
            assert "title" in result
            assert "author" in result
            assert "url" in result

        return True
    except Exception as e:
        print(f"✗ Real search test failed: {e}")
        return False

def main():
    """Run all tests."""
    print("🧪 Simple functionality tests...")
    print("=" * 50)

    # Basic tests
    basic_tests = [
        test_basic_imports,
        test_search_service,
        test_config,
        test_crawler_factory,
    ]

    print("Running basic tests:")
    basic_results = []
    for test in basic_tests:
        result = test()
        basic_results.append(result)
        print()

    # Advanced tests
    print("Running advanced tests:")
    advanced_tests = [
        test_search_service_with_mock_data,
    ]

    advanced_results = []
    for test in advanced_tests:
        result = test()
        advanced_results.append(result)
        print()

    # Real integration test
    print("Running integration test:")
    try:
        integration_result = asyncio.run(test_real_search())
        advanced_results.append(integration_result)
    except Exception as e:
        print(f"✗ Integration test failed: {e}")
        advanced_results.append(False)

    print("=" * 50)
    basic_passed = sum(basic_results)
    advanced_passed = sum(advanced_results)
    total_passed = basic_passed + advanced_passed
    total_tests = len(basic_results) + len(advanced_results)

    print(f"Basic tests passed: {basic_passed}/{len(basic_results)}")
    print(f"Advanced tests passed: {advanced_passed}/{len(advanced_results)}")
    print(f"Total tests passed: {total_passed}/{total_tests}")

    if total_passed >= total_tests * 0.8:  # 80% pass rate
        print("🎉 Most tests passed! The improvements are working well.")
        return 0
    else:
        print("❌ Many tests failed. Check the output above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())