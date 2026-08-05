#!/usr/bin/env python3
"""
ComfyUI 模型分块上传端点契约测试.

端点 (backend/app/api/routes/models.py):
- GET  /api/models/dirs
- POST /api/models/upload/init
- POST /api/models/upload/{upload_id}/chunk/{index}
- GET  /api/models/upload/{upload_id}/status
- POST /api/models/upload/{upload_id}/complete
- DELETE /api/models/upload/{upload_id}

文件存储目录通过 conftest 的 `models_root` fixture 重定向到 tmp.
"""

from __future__ import annotations

from pathlib import Path

import pytest


# ---- init ----------------------------------------------------------------
@pytest.mark.auth
def test_init_creates_upload_task(client, auth_headers, models_root):
    r = client.post(
        "/api/models/upload/init",
        json={
            "filename": "model.safetensors",
            "target_subdir": "checkpoints",
            "total_size": 1024,
            "chunk_size": 512,
            "total_chunks": 2,
        },
        headers=auth_headers,
    )
    assert r.status_code == 200
    body = r.json()
    assert "upload_id" in body
    # UUID 格式
    assert len(body["upload_id"]) == 36
    assert body["chunk_size"] == 512
    assert body["total_chunks"] == 2
    # 临时目录 + meta.json 已建
    meta = models_root / ".tmp" / body["upload_id"] / "meta.json"
    assert meta.exists()


@pytest.mark.auth
def test_init_rejects_path_traversal_subdir(client, auth_headers, models_root):
    """target_subdir 含 / 或 ../ → 400/403 (_safe_subdir)."""
    for bad in ["../evil", "a/b", "..\\evil", ".hidden"]:
        r = client.post(
            "/api/models/upload/init",
            json={
                "filename": "m.safetensors",
                "target_subdir": bad,
                "total_size": 1,
                "chunk_size": 1,
                "total_chunks": 1,
            },
            headers=auth_headers,
        )
        assert r.status_code in (400, 403), f"{bad} should be rejected"


@pytest.mark.auth
def test_init_rejects_invalid_size(client, auth_headers, models_root):
    """total_size / chunk_size / total_chunks <= 0 → 400."""
    base = {
        "filename": "m.safetensors",
        "target_subdir": "checkpoints",
    }
    for overrides in [
        {**base, "total_size": 0, "chunk_size": 1, "total_chunks": 1},
        {**base, "total_size": 1, "chunk_size": 0, "total_chunks": 1},
        {**base, "total_size": 1, "chunk_size": 1, "total_chunks": 0},
    ]:
        r = client.post("/api/models/upload/init", json=overrides, headers=auth_headers)
        assert r.status_code == 400


@pytest.mark.auth
def test_init_rejects_too_many_chunks(client, auth_headers, models_root):
    """total_chunks > 100000 → 400."""
    r = client.post(
        "/api/models/upload/init",
        json={
            "filename": "m.safetensors",
            "target_subdir": "checkpoints",
            "total_size": 1,
            "chunk_size": 1,
            "total_chunks": 100001,
        },
        headers=auth_headers,
    )
    assert r.status_code == 400


# ---- chunk + status + complete ------------------------------------------
def _init_upload(client, headers, total_chunks=2, filename="model.safetensors", subdir="checkpoints"):
    r = client.post(
        "/api/models/upload/init",
        json={
            "filename": filename,
            "target_subdir": subdir,
            "total_size": 10,
            "chunk_size": 5,
            "total_chunks": total_chunks,
        },
        headers=headers,
    )
    assert r.status_code == 200, r.text
    return r.json()["upload_id"]


@pytest.mark.auth
def test_chunk_upload_writes_part_file(client, auth_headers, models_root):
    upload_id = _init_upload(client, auth_headers)

    r = client.post(
        f"/api/models/upload/{upload_id}/chunk/0",
        content=b"hello",
        headers={**auth_headers, "Content-Type": "application/octet-stream"},
    )
    assert r.status_code == 200
    assert r.json()["index"] == 0
    assert r.json()["received_bytes"] == 5

    part = models_root / ".tmp" / upload_id / "0.part"
    assert part.exists()
    assert part.read_bytes() == b"hello"


@pytest.mark.auth
def test_chunk_rejects_index_out_of_range(client, auth_headers, models_root):
    upload_id = _init_upload(client, auth_headers, total_chunks=2)

    r = client.post(
        f"/api/models/upload/{upload_id}/chunk/5",
        content=b"x",
        headers={**auth_headers, "Content-Type": "application/octet-stream"},
    )
    assert r.status_code == 400


@pytest.mark.auth
def test_chunk_rejects_negative_index(client, auth_headers, models_root):
    upload_id = _init_upload(client, auth_headers)

    r = client.post(
        f"/api/models/upload/{upload_id}/chunk/-1",
        content=b"x",
        headers={**auth_headers, "Content-Type": "application/octet-stream"},
    )
    assert r.status_code == 400


@pytest.mark.auth
def test_chunk_rejects_invalid_upload_id(client, auth_headers, models_root):
    r = client.post(
        "/api/models/upload/not-a-uuid/chunk/0",
        content=b"x",
        headers={**auth_headers, "Content-Type": "application/octet-stream"},
    )
    assert r.status_code == 400


@pytest.mark.auth
def test_chunk_rejects_oversized_single_chunk(client, auth_headers, models_root):
    """单个分块累计字节超过 init 声明的 total_size → 413.

    backend-fixer 已在 chunk 上传时按 total_size 做单块上限校验。
    init 声明 total_size=10 (chunk_size=5, total_chunks=2),
    上传一个 50 字节的大块 → 413。
    """
    upload_id = _init_upload(client, auth_headers, total_chunks=1)
    r = client.post(
        f"/api/models/upload/{upload_id}/chunk/0",
        content=b"x" * 50,
        headers={**auth_headers, "Content-Type": "application/octet-stream"},
    )
    assert r.status_code == 413


@pytest.mark.auth
def test_status_reflects_received_chunks(client, auth_headers, models_root):
    upload_id = _init_upload(client, auth_headers, total_chunks=3)

    # 初始空
    r = client.get(f"/api/models/upload/{upload_id}/status", headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["received_indices"] == []
    assert r.json()["complete"] is False

    # 上传 chunk 0 + 2
    for idx, data in [(0, b"aa"), (2, b"cc")]:
        client.post(
            f"/api/models/upload/{upload_id}/chunk/{idx}",
            content=data,
            headers={**auth_headers, "Content-Type": "application/octet-stream"},
        )

    r = client.get(f"/api/models/upload/{upload_id}/status", headers=auth_headers)
    assert r.json()["received_indices"] == [0, 2]
    assert r.json()["complete"] is False


@pytest.mark.auth
def test_complete_merges_chunks_to_target(client, auth_headers, models_root):
    upload_id = _init_upload(client, auth_headers, total_chunks=2, filename="merged.safetensors")

    client.post(f"/api/models/upload/{upload_id}/chunk/0", content=b"hello-", headers={**auth_headers, "Content-Type": "application/octet-stream"})
    client.post(f"/api/models/upload/{upload_id}/chunk/1", content=b"world", headers={**auth_headers, "Content-Type": "application/octet-stream"})

    r = client.post(f"/api/models/upload/{upload_id}/complete", headers=auth_headers)
    assert r.status_code == 200
    body = r.json()
    assert body["filename"] == "merged.safetensors"
    assert body["size"] == 11  # "hello-world"

    final = models_root / "checkpoints" / "merged.safetensors"
    assert final.exists()
    assert final.read_bytes() == b"hello-world"
    # 临时目录清理
    assert not (models_root / ".tmp" / upload_id).exists()


@pytest.mark.auth
def test_complete_rejects_incomplete_chunks(client, auth_headers, models_root):
    upload_id = _init_upload(client, auth_headers, total_chunks=3)
    client.post(f"/api/models/upload/{upload_id}/chunk/0", content=b"a", headers={**auth_headers, "Content-Type": "application/octet-stream"})

    r = client.post(f"/api/models/upload/{upload_id}/complete", headers=auth_headers)
    assert r.status_code == 409  # 缺 chunk 1


@pytest.mark.auth
def test_complete_same_filename_appends_timestamp(client, auth_headers, models_root):
    """目标已存在同名文件 → 追加时间戳, 不覆盖."""
    target = models_root / "checkpoints" / "dup.safetensors"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(b"original")

    upload_id = _init_upload(client, auth_headers, total_chunks=1, filename="dup.safetensors")
    client.post(f"/api/models/upload/{upload_id}/chunk/0", content=b"new", headers={**auth_headers, "Content-Type": "application/octet-stream"})

    r = client.post(f"/api/models/upload/{upload_id}/complete", headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["filename"] != "dup.safetensors"
    assert target.read_bytes() == b"original"  # 原文件未被覆盖


# ---- cancel --------------------------------------------------------------
@pytest.mark.auth
def test_cancel_removes_upload_dir(client, auth_headers, models_root):
    upload_id = _init_upload(client, auth_headers)
    upload_dir = models_root / ".tmp" / upload_id
    assert upload_dir.exists()

    r = client.delete(f"/api/models/upload/{upload_id}", headers=auth_headers)
    assert r.status_code == 200
    assert not upload_dir.exists()


@pytest.mark.auth
def test_cancel_nonexistent_returns_ok(client, auth_headers, models_root):
    """删除不存在的 upload_id 也返 200 (幂等)."""
    import uuid

    fake_id = str(uuid.uuid4())
    r = client.delete(f"/api/models/upload/{fake_id}", headers=auth_headers)
    assert r.status_code == 200


@pytest.mark.auth
def test_cancel_rejects_invalid_upload_id(client, auth_headers, models_root):
    r = client.delete("/api/models/upload/not-a-uuid", headers=auth_headers)
    assert r.status_code == 400


# ---- dirs ----------------------------------------------------------------
@pytest.mark.auth
def test_list_dirs_returns_subdirs(client, auth_headers, models_root):
    (models_root / "checkpoints").mkdir(exist_ok=True)
    (models_root / "loras").mkdir(exist_ok=True)
    (models_root / "checkpoints" / "a.safetensors").write_bytes(b"x")

    r = client.get("/api/models/dirs", headers=auth_headers)
    assert r.status_code == 200
    names = [d["name"] for d in r.json()["dirs"]]
    assert "checkpoints" in names
    assert "loras" in names
    # .tmp 被跳过
    assert ".tmp" not in names
    # 大小估算非负
    for d in r.json()["dirs"]:
        assert d["size_bytes"] >= 0


@pytest.mark.auth
def test_list_dirs_when_root_missing_returns_empty(client, auth_headers, models_root, monkeypatch):
    """根目录不存在 → 空列表 (不抛 500)."""
    from app.config import settings

    monkeypatch.setattr(settings, "comfyui_models_dir", str(models_root / "nonexistent"))
    r = client.get("/api/models/dirs", headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["dirs"] == []