#!/usr/bin/env python3
"""
X-API-TOKEN 鉴权契约测试.

只验证三种行为的契约: 有 token 通过 / 无 token 拒绝 / 错 token 拒绝,
不依赖内部比较实现 (== vs secrets.compare_digest).
"""

from __future__ import annotations

import pytest


# 抽样几个明确需要鉴权的端点,既覆盖 GET 也覆盖 POST + multipart
PROTECTED_GETS = [
    "/api/models",
    "/api/backup/list",
    "/api/models/dirs",
    "/text2img/health",
]
PROTECTED_POSTS = [
    "/api/text2img/generate",
    "/api/backup/upload",
    "/api/logs/upload",
    "/api/models/upload/init",
]


@pytest.mark.auth
@pytest.mark.parametrize("endpoint", PROTECTED_GETS)
def test_get_without_token_returns_401(client, endpoint):
    """GET 受保护端点, 无 token → 401."""
    r = client.get(endpoint)
    assert r.status_code == 401


@pytest.mark.auth
@pytest.mark.parametrize("endpoint", PROTECTED_GETS)
def test_get_with_wrong_token_returns_401(client, bad_headers, endpoint):
    """GET 受保护端点, 错 token → 401."""
    r = client.get(endpoint, headers=bad_headers)
    assert r.status_code == 401


@pytest.mark.auth
@pytest.mark.parametrize("endpoint", PROTECTED_POSTS)
def test_post_without_token_returns_401(client, endpoint):
    """POST 受保护端点, 无 token → 401."""
    # 不同端点要不同 payload, 这里只关心鉴权层.
    if endpoint == "/api/text2img/generate":
        r = client.post(endpoint, json={"prompt": "x"})
    elif endpoint == "/api/backup/upload":
        r = client.post(endpoint, files={"file": ("a.db", b"x", "application/octet-stream")})
    elif endpoint == "/api/logs/upload":
        r = client.post(endpoint, json={"logs": [{"timestamp": "2026-01-01T00:00:00Z", "level": "info", "message": "x"}]})
    elif endpoint == "/api/models/upload/init":
        r = client.post(endpoint, json={"filename": "m.safetensors", "target_subdir": "checkpoints", "total_size": 1, "chunk_size": 1, "total_chunks": 1})
    else:
        r = client.post(endpoint)
    assert r.status_code == 401


@pytest.mark.auth
@pytest.mark.parametrize("endpoint", PROTECTED_POSTS)
def test_post_with_wrong_token_returns_401(client, bad_headers, endpoint):
    """POST 受保护端点, 错 token → 401."""
    if endpoint == "/api/text2img/generate":
        r = client.post(endpoint, json={"prompt": "x"}, headers=bad_headers)
    elif endpoint == "/api/backup/upload":
        r = client.post(endpoint, files={"file": ("a.db", b"x", "application/octet-stream")}, headers=bad_headers)
    elif endpoint == "/api/logs/upload":
        r = client.post(endpoint, json={"logs": [{"timestamp": "2026-01-01T00:00:00Z", "level": "info", "message": "x"}]}, headers=bad_headers)
    elif endpoint == "/api/models/upload/init":
        r = client.post(endpoint, json={"filename": "m.safetensors", "target_subdir": "checkpoints", "total_size": 1, "chunk_size": 1, "total_chunks": 1}, headers=bad_headers)
    else:
        r = client.post(endpoint, headers=bad_headers)
    assert r.status_code == 401


@pytest.mark.auth
def test_public_endpoint_health_no_token(client):
    """GET /health 是公开端点, 无 token 也应 200."""
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


@pytest.mark.auth
def test_public_endpoint_root_no_token(client):
    """GET / 是公开端点, 无 token 也应 200."""
    r = client.get("/")
    assert r.status_code == 200
    body = r.json()
    assert "endpoints" in body
    assert "features" in body


@pytest.mark.auth
def test_get_with_correct_token_passes_auth_layer(client, auth_headers):
    """正确 token 至少要过鉴权层(具体业务可能 200/500 都行, 但不能 401)."""
    r = client.get("/api/models", headers=auth_headers)
    assert r.status_code != 401
    assert r.status_code != 403