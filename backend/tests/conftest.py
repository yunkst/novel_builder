#!/usr/bin/env python3

"""
Pytest configuration and fixtures for Novel Builder Backend tests.
"""

import os
import sys
from collections.abc import AsyncGenerator, Generator

import pytest
from fastapi.testclient import TestClient
from httpx import AsyncClient

# Add app directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.main import app


@pytest.fixture
def client() -> Generator[TestClient, None, None]:
    """Create a FastAPI test client."""
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
async def async_client() -> AsyncGenerator[AsyncClient, None]:
    """Create an async HTTP client for testing."""
    async with AsyncClient(base_url="http://localhost:8000") as ac:
        yield ac


@pytest.fixture
def valid_token() -> str:
    """Return a valid API token for testing."""
    return "test_token_123"


@pytest.fixture
def invalid_token() -> str:
    """Return an invalid API token for testing."""
    return "invalid-token"


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
    monkeypatch.setenv("NOVEL_API_TOKEN", "test_token_123")
    monkeypatch.setenv("SECRET_KEY", "test-secret-key")
    monkeypatch.setenv("DEBUG", "true")
