#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Simple test script to validate our testing improvements.
This can be run inside Docker to verify our changes work.
"""

import sys
import os

# Add app directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "app"))

def test_imports():
    """Test that all our new test modules can be imported."""
    try:
        from tests.factories import NovelFactory, ChapterFactory
        print("✓ Factories imported successfully")

        # Test factory creates data
        novel = NovelFactory.create()
        assert "title" in novel
        assert "author" in novel
        print("✓ NovelFactory creates valid data")

        chapter = ChapterFactory.create()
        assert "title" in chapter
        assert "url" in chapter
        print("✓ ChapterFactory creates valid data")

        return True
    except Exception as e:
        print(f"✗ Import test failed: {e}")
        return False

def test_app_imports():
    """Test that main app can be imported."""
    try:
        from app.main import app
        print("✓ Main app imported successfully")

        from app.services.search_service import SearchService
        service = SearchService()
        print("✓ SearchService instantiated successfully")

        return True
    except Exception as e:
        print(f"✗ App import test failed: {e}")
        return False

def test_config():
    """Test configuration loading."""
    try:
        from app.config import settings
        print(f"✓ Settings loaded successfully")
        print(f"  - API Token configured: {bool(settings.api_token)}")
        print(f"  - Debug mode: {settings.debug}")
        return True
    except Exception as e:
        print(f"✗ Config test failed: {e}")
        return False

def main():
    """Run all tests."""
    print("🧪 Testing our improved testing setup...")
    print("=" * 50)

    tests = [
        test_imports,
        test_app_imports,
        test_config,
    ]

    results = []
    for test in tests:
        result = test()
        results.append(result)
        print()

    print("=" * 50)
    passed = sum(results)
    total = len(results)
    print(f"Tests passed: {passed}/{total}")

    if passed == total:
        print("🎉 All tests passed! The improvements are working.")
        return 0
    else:
        print("❌ Some tests failed. Check the output above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())