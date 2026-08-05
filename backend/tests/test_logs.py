#!/usr/bin/env python3
"""
客户端日志上报端点契约测试 (backend/app/api/routes/logs.py).

覆盖:
- POST /api/logs/upload - 1~50 条 → 成功 (received == N)
- >50 条 → 422 (schema min_length/max_length)
- 0 条 → 422
- 缺字段 → 422
- 处理失败应返 500 (backend-fixer 已把异常吞掉 → 200 的契约缺陷修掉)

DB 隔离: conftest 的 _override_get_db autouse fixture 注入内存 SQLite.
"""

from __future__ import annotations

from datetime import datetime, timezone

import pytest

from app.models import ClientLog


def _entry(i: int = 0, **overrides) -> dict:
    base = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "level": "info",
        "message": f"msg {i}",
        "stack_trace": None,
        "category": "general",
        "tags": [],
    }
    base.update(overrides)
    return base


def _payload(n: int = 3, **entry_overrides) -> dict:
    return {"logs": [_entry(i, **entry_overrides) for i in range(n)]}


# ---- 成功路径 -------------------------------------------------------------
@pytest.mark.auth
def test_upload_single_log_succeeds(client, auth_headers, db_session):
    r = client.post("/api/logs/upload", json=_payload(1), headers=auth_headers)
    assert r.status_code == 200
    body = r.json()
    assert body["received"] == 1
    assert "成功" in body["message"] or "1" in body["message"]
    # 落库
    assert db_session.query(ClientLog).count() == 1


@pytest.mark.auth
def test_upload_fifty_logs_succeeds(client, auth_headers, db_session):
    """正好 50 条 (max_length 边界) → 200."""
    r = client.post("/api/logs/upload", json=_payload(50), headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["received"] == 50
    assert db_session.query(ClientLog).count() == 50


@pytest.mark.auth
def test_upload_preserves_fields(client, auth_headers, db_session):
    """字段 (level/message/category/tags) 正确落库."""
    payload = {
        "logs": [
            {
                "timestamp": "2026-01-15T10:30:00+00:00",
                "level": "error",
                "message": "boom",
                "stack_trace": "Traceback...",
                "category": "database",
                "tags": ["bug", "ui"],
            }
        ]
    }
    r = client.post("/api/logs/upload", json=payload, headers=auth_headers)
    assert r.status_code == 200
    log = db_session.query(ClientLog).first()
    assert log.level == "error"
    assert log.message == "boom"
    assert log.category == "database"
    assert log.stack_trace == "Traceback..."
    # tags 存为 JSON 字符串
    assert "bug" in (log.tags or "")


# ---- schema 校验 ---------------------------------------------------------
@pytest.mark.auth
def test_upload_zero_logs_rejected(client, auth_headers):
    """0 条 → 422 (min_length=1)."""
    r = client.post("/api/logs/upload", json={"logs": []}, headers=auth_headers)
    assert r.status_code == 422


@pytest.mark.auth
def test_upload_too_many_logs_rejected(client, auth_headers):
    """51 条 → 422 (max_length=50)."""
    r = client.post("/api/logs/upload", json=_payload(51), headers=auth_headers)
    assert r.status_code == 422


@pytest.mark.auth
def test_upload_missing_logs_field_rejected(client, auth_headers):
    """缺 logs 字段 → 422."""
    r = client.post("/api/logs/upload", json={}, headers=auth_headers)
    assert r.status_code == 422


@pytest.mark.auth
def test_upload_missing_message_rejected(client, auth_headers):
    """单条缺 message → 422."""
    payload = {
        "logs": [
            {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "level": "info",
                # message 缺失
            }
        ]
    }
    r = client.post("/api/logs/upload", json=payload, headers=auth_headers)
    assert r.status_code == 422


# ---- 失败路径 ------------------------------------------------------------
@pytest.mark.auth
def test_upload_failure_returns_500_not_200(client, auth_headers, monkeypatch):
    """DB 写失败时端点应返 500, 不应吞异常返 200.

    backend-fixer 已修: logs.py 现在 except 块 raise HTTPException(500),
    而非返回 received=0 的伪 200 响应。这里通过 patch ClientLog.__init__
    抛异常来模拟 DB 写入失败。
    """
    real_init = ClientLog.__init__

    def boom(self, *a, **kw):
        raise RuntimeError("simulated DB failure")

    monkeypatch.setattr(ClientLog, "__init__", boom)
    try:
        r = client.post("/api/logs/upload", json=_payload(2), headers=auth_headers)
        assert r.status_code == 500, (
            f"处理失败应返 500 而非 {r.status_code}; "
            f"body={r.text[:200]}"
        )
        # 安全: 不向客户端回显异常细节
        assert "simulated" not in r.text
    finally:
        monkeypatch.setattr(ClientLog, "__init__", real_init)
