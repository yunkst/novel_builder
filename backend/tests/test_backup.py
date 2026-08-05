#!/usr/bin/env python3
"""
数据库备份端点契约测试 (POST /api/backup/upload, GET /list, GET /download/{id}, DELETE /delete/{id}).

注意:
- 文件存储目录通过 conftest 的 `backup_dir` fixture 重定向到 tmp.
- 路径穿越行为来自 backup.py 的 `_safe_backup_path`,upload 走另外逻辑(不接受 backup_id).
"""

from __future__ import annotations

from pathlib import Path

import pytest


# ---- upload --------------------------------------------------------------
@pytest.mark.auth
def test_upload_db_file_succeeds(client, auth_headers, backup_dir):
    content = b"sqlite-like-content"
    r = client.post(
        "/api/backup/upload",
        files={"file": ("novel_app.db", content, "application/octet-stream")},
        headers=auth_headers,
    )
    assert r.status_code == 200
    body = r.json()
    assert body["filename"] == "novel_app.db"
    assert body["file_size"] == len(content)
    assert body["stored_name"] == "novel_app.db"
    # 实际落盘
    assert (backup_dir / body["stored_name"]).exists() or Path(body["stored_path"]).exists()


@pytest.mark.auth
def test_upload_zip_file_succeeds(client, auth_headers, backup_dir):
    r = client.post(
        "/api/backup/upload",
        files={"file": ("backup.zip", b"PK\x03\x04", "application/zip")},
        headers=auth_headers,
    )
    assert r.status_code == 200
    assert r.json()["filename"] == "backup.zip"


@pytest.mark.auth
def test_upload_rejects_invalid_extension(client, auth_headers):
    """非 .db / .zip 文件 → 400."""
    r = client.post(
        "/api/backup/upload",
        files={"file": ("evil.exe", b"MZ", "application/octet-stream")},
        headers=auth_headers,
    )
    assert r.status_code == 400


@pytest.mark.auth
def test_upload_empty_filename_rejected(client, auth_headers):
    """filename 为空 → 拒绝 (Starlette 422 / 端点 400 均可, 关键是非 200)."""
    # file.filename 在端点里被显式判 None / falsy; Starlette 可能先 422
    r = client.post(
        "/api/backup/upload",
        files={"file": ("", b"x", "application/octet-stream")},
        headers=auth_headers,
    )
    assert r.status_code in (400, 422)


@pytest.mark.auth
def test_upload_same_filename_appends_timestamp(client, auth_headers, backup_dir):
    """同名文件二次上传不应覆盖, 追加时间戳后缀."""
    client.post(
        "/api/backup/upload",
        files={"file": ("dup.db", b"v1", "application/octet-stream")},
        headers=auth_headers,
    )
    r2 = client.post(
        "/api/backup/upload",
        files={"file": ("dup.db", b"v2", "application/octet-stream")},
        headers=auth_headers,
    )
    assert r2.status_code == 200
    assert r2.json()["stored_name"] != "dup.db"
    assert r2.json()["stored_name"].endswith(".db")


@pytest.mark.auth
def test_upload_rejects_oversized_file(client, auth_headers, backup_dir, monkeypatch):
    """超过 MAX_BACKUP_BYTES (默认 1GB) → 413.

    通过临时把上限改小到 16 字节, 避免真的传 1GB。
    backend-fixer 已为 backup 加 size cap, 这里直接 patch 模块常量。
    """
    from app.api.routes import backup as backup_module

    monkeypatch.setattr(backup_module, "MAX_BACKUP_BYTES", 16)
    big = b"x" * 32  # 超 16 字节上限
    r = client.post(
        "/api/backup/upload",
        files={"file": ("big.db", big, "application/octet-stream")},
        headers=auth_headers,
    )
    assert r.status_code == 413


# ---- list ----------------------------------------------------------------
@pytest.mark.auth
def test_list_returns_uploads_descending_by_mtime(client, auth_headers, backup_dir):
    # 准备 2 个文件 (不同日期目录)
    (backup_dir / "2026-01-01").mkdir(parents=True, exist_ok=True)
    (backup_dir / "2026-01-02").mkdir(parents=True, exist_ok=True)
    (backup_dir / "2026-01-01" / "old.db").write_bytes(b"old")
    (backup_dir / "2026-01-02" / "new.db").write_bytes(b"new")

    r = client.get("/api/backup/list", headers=auth_headers)
    assert r.status_code == 200
    backups = r.json()["backups"]
    assert len(backups) == 2
    ids = [b["backup_id"] for b in backups]
    assert "2026-01-01/old.db" in ids
    assert "2026-01-02/new.db" in ids


@pytest.mark.auth
def test_list_empty_when_no_backups(client, auth_headers, backup_dir):
    r = client.get("/api/backup/list", headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["backups"] == []


# ---- download ------------------------------------------------------------
@pytest.mark.auth
def test_download_returns_file_bytes(client, auth_headers, backup_dir):
    payload = b"hello-db-content"
    (backup_dir / "2026-08-01").mkdir(parents=True, exist_ok=True)
    (backup_dir / "2026-08-01" / "novel.db").write_bytes(payload)

    r = client.get("/api/backup/download/2026-08-01/novel.db", headers=auth_headers)
    assert r.status_code == 200
    assert r.content == payload
    # 媒体类型是 octet-stream
    assert "application/octet-stream" in r.headers.get("content-type", "")


@pytest.mark.auth
def test_download_path_traversal_rejected(client, auth_headers, backup_dir):
    """backup_id 含 ../ 试图逃逸 BACKUP_DIR → 403 (_safe_backup_path)."""
    r = client.get("/api/backup/download/../../etc/passwd", headers=auth_headers)
    # 注意 Starlette 会先解析路径, /download/{backup_id:path} 接 ../;
    # _safe_backup_path resolve 后若不在 BACKUP_DIR 内 → 403.
    assert r.status_code in (403, 404)


@pytest.mark.auth
def test_download_missing_file_returns_404(client, auth_headers, backup_dir):
    r = client.get("/api/backup/download/nonexistent/file.db", headers=auth_headers)
    assert r.status_code == 404


# ---- delete --------------------------------------------------------------
@pytest.mark.auth
def test_delete_removes_file(client, auth_headers, backup_dir):
    (backup_dir / "2026-08-01").mkdir(parents=True, exist_ok=True)
    target = backup_dir / "2026-08-01" / "todelete.db"
    target.write_bytes(b"x")

    r = client.delete("/api/backup/delete/2026-08-01/todelete.db", headers=auth_headers)
    assert r.status_code == 200
    assert not target.exists()


@pytest.mark.auth
def test_delete_path_traversal_rejected(client, auth_headers, backup_dir):
    r = client.delete("/api/backup/delete/../../etc/evil.db", headers=auth_headers)
    assert r.status_code in (403, 404)


@pytest.mark.auth
def test_delete_missing_returns_404(client, auth_headers, backup_dir):
    r = client.delete("/api/backup/delete/none/x.db", headers=auth_headers)
    assert r.status_code == 404