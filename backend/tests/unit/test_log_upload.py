#!/usr/bin/env python3

"""
Unit tests for client log upload API endpoint.

Tests cover:
- Normal upload with valid token
- Authentication rejection (missing / invalid token)
- Validation: empty list, oversized list, invalid level
- Single log entry upload
- Multiple log entries upload
"""

from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient


def _make_log_entry(
    level: str = "error",
    message: str = "test message",
    category: str = "general",
    tags: list[str] | None = None,
    stack_trace: str | None = None,
) -> dict:
    """Helper: construct a single log entry dict."""
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "level": level,
        "message": message,
        "category": category,
    }
    if tags is not None:
        entry["tags"] = tags
    if stack_trace is not None:
        entry["stack_trace"] = stack_trace
    return entry


class TestLogUploadAuthentication:
    """Test authentication requirements for log upload."""

    def test_upload_without_token(self, client: TestClient) -> None:
        """Upload without token should return 401."""
        payload = {"logs": [_make_log_entry()]}
        response = client.post("/api/logs/upload", json=payload)
        assert response.status_code == 401

    def test_upload_with_invalid_token(self, client: TestClient) -> None:
        """Upload with wrong token should return 401."""
        headers = {"X-API-TOKEN": "wrong-token"}
        payload = {"logs": [_make_log_entry()]}
        response = client.post("/api/logs/upload", json=payload, headers=headers)
        assert response.status_code == 401

    def test_upload_with_valid_token(self, client: TestClient, valid_token: str) -> None:
        """Upload with valid token should succeed."""
        headers = {"X-API-TOKEN": valid_token}
        payload = {"logs": [_make_log_entry()]}
        response = client.post("/api/logs/upload", json=payload, headers=headers)
        assert response.status_code == 200


class TestLogUploadValidation:
    """Test request validation for log upload."""

    def test_upload_empty_list(self, client: TestClient, valid_token: str) -> None:
        """Empty logs list should be rejected (min_length=1)."""
        headers = {"X-API-TOKEN": valid_token}
        response = client.post("/api/logs/upload", json={"logs": []}, headers=headers)
        assert response.status_code == 422

    def test_upload_oversized_list(self, client: TestClient, valid_token: str) -> None:
        """More than 50 entries should be rejected (max_length=50)."""
        headers = {"X-API-TOKEN": valid_token}
        payload = {"logs": [_make_log_entry(message=f"msg_{i}") for i in range(51)]}
        response = client.post("/api/logs/upload", json=payload, headers=headers)
        assert response.status_code == 422

    def test_upload_missing_required_fields(self, client: TestClient, valid_token: str) -> None:
        """Missing required fields should be rejected."""
        headers = {"X-API-TOKEN": valid_token}
        response = client.post(
            "/api/logs/upload",
            json={"logs": [{"level": "error"}]},  # missing timestamp, message
            headers=headers,
        )
        assert response.status_code == 422

    def test_upload_50_entries_max(self, client: TestClient, valid_token: str) -> None:
        """Exactly 50 entries should be accepted."""
        headers = {"X-API-TOKEN": valid_token}
        payload = {"logs": [_make_log_entry(message=f"msg_{i}") for i in range(50)]}
        response = client.post("/api/logs/upload", json=payload, headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["received"] == 50


class TestLogUploadContent:
    """Test log content handling."""

    def test_upload_single_error_log(self, client: TestClient, valid_token: str) -> None:
        """Upload a single error log with all fields."""
        headers = {"X-API-TOKEN": valid_token}
        payload = {
            "logs": [
                _make_log_entry(
                    level="error",
                    message="Critical failure",
                    category="network",
                    tags=["api", "timeout"],
                    stack_trace="Exception at line 42",
                )
            ]
        }
        response = client.post("/api/logs/upload", json=payload, headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["received"] == 1
        assert "成功" in data["message"]

    def test_upload_warning_log(self, client: TestClient, valid_token: str) -> None:
        """Upload a warning log."""
        headers = {"X-API-TOKEN": valid_token}
        payload = {"logs": [_make_log_entry(level="warning", message="Slow response")]}
        response = client.post("/api/logs/upload", json=payload, headers=headers)
        assert response.status_code == 200
        assert response.json()["received"] == 1

    def test_upload_info_log(self, client: TestClient, valid_token: str) -> None:
        """Upload an info log."""
        headers = {"X-API-TOKEN": valid_token}
        payload = {"logs": [_make_log_entry(level="info", message="App started")]}
        response = client.post("/api/logs/upload", json=payload, headers=headers)
        assert response.status_code == 200

    def test_upload_debug_log(self, client: TestClient, valid_token: str) -> None:
        """Upload a debug log."""
        headers = {"X-API-TOKEN": valid_token}
        payload = {"logs": [_make_log_entry(level="debug", message="Cache hit")]}
        response = client.post("/api/logs/upload", json=payload, headers=headers)
        assert response.status_code == 200

    def test_upload_mixed_levels(self, client: TestClient, valid_token: str) -> None:
        """Upload multiple logs of different levels."""
        headers = {"X-API-TOKEN": valid_token}
        payload = {
            "logs": [
                _make_log_entry(level="error", message="err1"),
                _make_log_entry(level="warning", message="warn1"),
                _make_log_entry(level="info", message="info1"),
                _make_log_entry(level="debug", message="debug1"),
            ]
        }
        response = client.post("/api/logs/upload", json=payload, headers=headers)
        assert response.status_code == 200
        assert response.json()["received"] == 4

    def test_upload_with_default_category(self, client: TestClient, valid_token: str) -> None:
        """Upload without explicit category uses default 'general'."""
        headers = {"X-API-TOKEN": valid_token}
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": "error",
            "message": "test",
        }
        response = client.post(
            "/api/logs/upload", json={"logs": [entry]}, headers=headers
        )
        assert response.status_code == 200

    def test_upload_with_empty_tags(self, client: TestClient, valid_token: str) -> None:
        """Upload with empty tags list should succeed."""
        headers = {"X-API-TOKEN": valid_token}
        entry = _make_log_entry(tags=[])
        response = client.post(
            "/api/logs/upload", json={"logs": [entry]}, headers=headers
        )
        assert response.status_code == 200

    def test_upload_without_stack_trace(self, client: TestClient, valid_token: str) -> None:
        """Upload without stack_trace (optional field) should succeed."""
        headers = {"X-API-TOKEN": valid_token}
        entry = _make_log_entry()  # no stack_trace
        response = client.post(
            "/api/logs/upload", json={"logs": [entry]}, headers=headers
        )
        assert response.status_code == 200
