#!/usr/bin/env python3
"""
图生视频端点契约测试 (main.py 内联路由).

覆盖:
- POST /api/image-to-video/generate - 提交任务 → 返回 task_id
- GET  /api/image-to-video/video/{task_id} - 202 / 200 mp4 / 404

ComfyUI 通过 monkeypatch app.services.image_to_video_service.create_comfyui_client
替换为 FakeComfyUIClient, 不真连。
"""

from __future__ import annotations

import io

import pytest

from app.models import ImageToVideoTask
from tests.factories import make_image_to_video_task


class FakeComfyUIClient:
    def __init__(self, prompt_id="fake-i2v-001", status_info=None):
        self._prompt_id = prompt_id
        self._status_info = status_info or {}

    async def generate_video(self, prompt, image_data, image_filename="input.png"):
        return self._prompt_id

    async def check_task_status(self, task_id):
        return self._status_info


@pytest.fixture
def patch_i2v_comfyui(monkeypatch):
    def _patch(prompt_id="fake-i2v-001", status_info=None):
        fake = FakeComfyUIClient(prompt_id=prompt_id, status_info=status_info)
        import app.services.image_to_video_service as svc

        monkeypatch.setattr(svc, "create_comfyui_client", lambda *a, **kw: fake)
        return fake

    return _patch


def _png_bytes(size: int = 100) -> bytes:
    return b"\x89PNG\r\n\x1a\n" + b"\x00" * size


# ---- generate ------------------------------------------------------------
@pytest.mark.auth
def test_generate_returns_task_id(client, auth_headers, patch_i2v_comfyui, db_session):
    patch_i2v_comfyui(prompt_id="i2v-001")
    r = client.post(
        "/api/image-to-video/generate",
        headers=auth_headers,
        data={"prompt": "slow zoom"},
        files={"image": ("input.png", io.BytesIO(_png_bytes()), "image/png")},
    )
    assert r.status_code == 200
    assert r.json()["task_id"] == "i2v-001"
    task = db_session.query(ImageToVideoTask).filter_by(prompt_id="i2v-001").first()
    assert task is not None
    assert task.prompt == "slow zoom"
    assert task.status == "pending"


@pytest.mark.auth
def test_generate_missing_prompt_rejected(client, auth_headers, patch_i2v_comfyui):
    """缺 prompt (Form 字段) → 422."""
    patch_i2v_comfyui()
    r = client.post(
        "/api/image-to-video/generate",
        headers=auth_headers,
        files={"image": ("input.png", io.BytesIO(_png_bytes()), "image/png")},
    )
    assert r.status_code == 422


@pytest.mark.auth
def test_generate_missing_image_rejected(client, auth_headers, patch_i2v_comfyui):
    """缺 image 文件 → 422."""
    patch_i2v_comfyui()
    r = client.post(
        "/api/image-to-video/generate",
        headers=auth_headers,
        data={"prompt": "x"},
    )
    assert r.status_code == 422


@pytest.mark.auth
def test_generate_empty_image_rejected(client, auth_headers, patch_i2v_comfyui):
    """图片为空 → 400."""
    patch_i2v_comfyui()
    r = client.post(
        "/api/image-to-video/generate",
        headers=auth_headers,
        data={"prompt": "x"},
        files={"image": ("empty.png", io.BytesIO(b""), "image/png")},
    )
    assert r.status_code == 400


@pytest.mark.auth
def test_generate_unsupported_mime_rejected(client, auth_headers, patch_i2v_comfyui):
    """不支持的 MIME (image/bmp) → 400."""
    patch_i2v_comfyui()
    r = client.post(
        "/api/image-to-video/generate",
        headers=auth_headers,
        data={"prompt": "x"},
        files={"image": ("a.bmp", io.BytesIO(b"BM" + b"\x00" * 50), "image/bmp")},
    )
    assert r.status_code == 400


@pytest.mark.auth
def test_generate_oversized_image_rejected(client, auth_headers, patch_i2v_comfyui):
    """图片超过 50MB → 413."""
    patch_i2v_comfyui()
    # 50MB + 1 byte
    big = b"\x00" * (50 * 1024 * 1024 + 1)
    r = client.post(
        "/api/image-to-video/generate",
        headers=auth_headers,
        data={"prompt": "x"},
        files={"image": ("big.png", io.BytesIO(big), "image/png")},
    )
    assert r.status_code == 413


@pytest.mark.auth
def test_generate_comfyui_failure_returns_500(client, auth_headers, monkeypatch):
    """ComfyUI 提交失败 (generate_video 返 None → RuntimeError) → 500."""

    class FailingClient:
        async def generate_video(self, prompt, image_data, image_filename="x.png"):
            return None

    import app.services.image_to_video_service as svc

    monkeypatch.setattr(svc, "create_comfyui_client", lambda *a, **kw: FailingClient())

    r = client.post(
        "/api/image-to-video/generate",
        headers=auth_headers,
        data={"prompt": "x"},
        files={"image": ("input.png", io.BytesIO(_png_bytes()), "image/png")},
    )
    assert r.status_code == 500


# ---- get_video -----------------------------------------------------------
@pytest.mark.auth
def test_get_video_nonexistent_returns_404(client, auth_headers):
    r = client.get("/api/image-to-video/video/no-such-task", headers=auth_headers)
    assert r.status_code == 404


@pytest.mark.auth
def test_get_video_pending_returns_202(client, auth_headers, db_session, patch_i2v_comfyui):
    db_session.add(make_image_to_video_task(prompt_id="i2v-pending", status="pending"))
    db_session.commit()
    patch_i2v_comfyui(status_info={})

    r = client.get("/api/image-to-video/video/i2v-pending", headers=auth_headers)
    assert r.status_code == 202
    assert r.json()["status"] == "pending"


@pytest.mark.auth
def test_get_video_failed_returns_404(client, auth_headers, db_session):
    db_session.add(make_image_to_video_task(prompt_id="i2v-failed", status="failed"))
    db_session.commit()

    r = client.get("/api/image-to-video/video/i2v-failed", headers=auth_headers)
    assert r.status_code == 404


@pytest.mark.auth
def test_get_video_completed_returns_mp4(client, auth_headers, db_session, monkeypatch):
    db_session.add(
        make_image_to_video_task(
            prompt_id="i2v-done", status="completed", video_filename="out.mp4"
        )
    )
    db_session.commit()

    import app.services.image_to_video_service as svc

    mp4_bytes = b"\x00\x00\x00\x18ftypmp42" + b"\x00" * 200
    monkeypatch.setattr(svc.ImageToVideoService, "_fetch_video", lambda self, fn: _async_return(mp4_bytes))

    r = client.get("/api/image-to-video/video/i2v-done", headers=auth_headers)
    assert r.status_code == 200
    assert r.content == mp4_bytes
    assert r.headers["content-type"] == "video/mp4"


@pytest.mark.auth
def test_get_video_pending_completed_via_history(
    client, auth_headers, db_session, patch_i2v_comfyui, monkeypatch
):
    """pending + history 显示 success + 视频输出 → 200 + DB 回填."""
    db_session.add(make_image_to_video_task(prompt_id="i2v-hist", status="pending"))
    db_session.commit()

    status_info = {
        "status": {"status_str": "success", "messages": []},
        "outputs": {
            "node1": {
                "_meta": {"class_type": "VideoCombine"},
                "videos": [{"filename": "gen.mp4", "type": "output"}],
            }
        },
    }
    patch_i2v_comfyui(status_info=status_info)

    import app.services.image_to_video_service as svc

    mp4_bytes = b"\x00\x00\x00\x18ftypmp42"
    monkeypatch.setattr(svc.ImageToVideoService, "_fetch_video", lambda self, fn: _async_return(mp4_bytes))

    r = client.get("/api/image-to-video/video/i2v-hist", headers=auth_headers)
    assert r.status_code == 200
    assert r.content == mp4_bytes

    task = db_session.query(ImageToVideoTask).filter_by(prompt_id="i2v-hist").first()
    assert task.status == "completed"
    assert "gen.mp4" in task.video_filename


@pytest.mark.auth
def test_get_video_history_failed_marks_failed(
    client, auth_headers, db_session, patch_i2v_comfyui
):
    db_session.add(make_image_to_video_task(prompt_id="i2v-err", status="pending"))
    db_session.commit()

    status_info = {"status": {"status_str": "error", "messages": ["oom"]}}
    patch_i2v_comfyui(status_info=status_info)

    r = client.get("/api/image-to-video/video/i2v-err", headers=auth_headers)
    assert r.status_code == 404

    task = db_session.query(ImageToVideoTask).filter_by(prompt_id="i2v-err").first()
    assert task.status == "failed"


# ---- 辅助 ----------------------------------------------------------------
async def _async_return(value):
    return value
