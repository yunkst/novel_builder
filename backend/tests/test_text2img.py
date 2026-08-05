#!/usr/bin/env python3
"""
文生图端点契约测试 (main.py 内联路由).

覆盖:
- POST /api/text2img/generate - 提交任务 → 返回 task_id
- GET  /api/text2img/image/{task_id} - 202 (进行中) / 200 (完成 png) / 404 (不存在/失败)

ComfyUI 是外部服务, 测试通过 monkeypatch
app.services.text2img_service.create_comfyui_client 返回 FakeComfyUIClient,
不真连 ComfyUI。服务是模块级单例 (text2img_service), 客户端工厂在 service 模块
命名空间内绑定 (from .comfyui_client import create_comfyui_client), 所以 patch
service 模块的 create_comfyui_client 即可拦截。
"""

from __future__ import annotations

import pytest

from app.models import Text2ImgTask
from tests.factories import make_text2img_task


class FakeComfyUIClient:
    """可控的 ComfyUI 客户端替身.

    - generate_image(prompt, negative_prompt) → 返回 prompt_id (或 None 模拟失败)
    - check_task_status(task_id) → 返回 history dict (或 {} 表示排队中)
    """

    def __init__(
        self,
        prompt_id: str | None = "fake-prompt-id-001",
        status_info: dict | None = None,
    ):
        self._prompt_id = prompt_id
        self._status_info = status_info or {}

    async def generate_image(self, prompt, negative_prompt=None):
        return self._prompt_id

    async def check_task_status(self, task_id):
        return self._status_info


@pytest.fixture
def patch_comfyui_generate(monkeypatch):
    """patch create_comfyui_client 返回 FakeComfyUIClient, 返回 fake 供测试微调."""

    def _patch(prompt_id="fake-prompt-id-001", status_info=None):
        fake = FakeComfyUIClient(prompt_id=prompt_id, status_info=status_info)
        import app.services.text2img_service as svc

        monkeypatch.setattr(svc, "create_comfyui_client", lambda *a, **kw: fake)
        return fake

    return _patch


# ---- generate ------------------------------------------------------------
@pytest.mark.auth
def test_generate_returns_task_id(client, auth_headers, patch_comfyui_generate, db_session):
    patch_comfyui_generate(prompt_id="t2i-task-001")
    r = client.post(
        "/api/text2img/generate",
        json={"prompt": "a cat"},
        headers=auth_headers,
    )
    assert r.status_code == 200
    assert r.json()["task_id"] == "t2i-task-001"
    # 落库
    task = db_session.query(Text2ImgTask).filter_by(prompt_id="t2i-task-001").first()
    assert task is not None
    assert task.prompt == "a cat"
    assert task.status == "pending"


@pytest.mark.auth
def test_generate_with_negative_prompt(client, auth_headers, patch_comfyui_generate, db_session):
    patch_comfyui_generate(prompt_id="t2i-neg-001")
    r = client.post(
        "/api/text2img/generate",
        json={"prompt": "a cat", "negative_prompt": "blurry"},
        headers=auth_headers,
    )
    assert r.status_code == 200
    task = db_session.query(Text2ImgTask).filter_by(prompt_id="t2i-neg-001").first()
    assert task.negative_prompt == "blurry"


@pytest.mark.auth
def test_generate_empty_prompt_rejected(client, auth_headers):
    """prompt 为空 → 422 (min_length=1)."""
    r = client.post(
        "/api/text2img/generate",
        json={"prompt": ""},
        headers=auth_headers,
    )
    assert r.status_code == 422


@pytest.mark.auth
def test_generate_missing_prompt_rejected(client, auth_headers):
    """缺 prompt → 422."""
    r = client.post(
        "/api/text2img/generate",
        json={},
        headers=auth_headers,
    )
    assert r.status_code == 422


@pytest.mark.auth
def test_generate_comfyui_failure_returns_500(client, auth_headers, monkeypatch):
    """ComfyUI 提交返回 None (RuntimeError) → 500 (handle_service_exception)."""

    class FailingClient:
        async def generate_image(self, prompt, negative_prompt=None):
            return None

    import app.services.text2img_service as svc

    monkeypatch.setattr(svc, "create_comfyui_client", lambda *a, **kw: FailingClient())

    r = client.post(
        "/api/text2img/generate",
        json={"prompt": "x"},
        headers=auth_headers,
    )
    assert r.status_code == 500


# ---- get_image -----------------------------------------------------------
@pytest.mark.auth
def test_get_image_nonexistent_task_returns_404(client, auth_headers):
    r = client.get("/api/text2img/image/no-such-task", headers=auth_headers)
    assert r.status_code == 404


@pytest.mark.auth
def test_get_image_pending_task_returns_202(client, auth_headers, db_session, patch_comfyui_generate):
    """pending 任务 + ComfyUI history 空 → 202."""
    db_session.add(make_text2img_task(prompt_id="pending-001", status="pending"))
    db_session.commit()
    patch_comfyui_generate(prompt_id="x", status_info={})  # 空 history = 排队中

    r = client.get("/api/text2img/image/pending-001", headers=auth_headers)
    assert r.status_code == 202
    assert r.json()["status"] == "pending"


@pytest.mark.auth
def test_get_image_failed_task_returns_404(client, auth_headers, db_session):
    """status=failed → 404."""
    db_session.add(make_text2img_task(prompt_id="failed-001", status="failed"))
    db_session.commit()

    r = client.get("/api/text2img/image/failed-001", headers=auth_headers)
    assert r.status_code == 404


@pytest.mark.auth
def test_get_image_completed_returns_png(client, auth_headers, db_session, monkeypatch):
    """status=completed + filename → 200 image/png.

    _fetch_media 用 httpx 拉 ComfyUI /view, 这里 patch service._fetch_media 返回固定字节。
    """
    db_session.add(
        make_text2img_task(
            prompt_id="done-001", status="completed", filename="out.png"
        )
    )
    db_session.commit()

    import app.services.text2img_service as svc

    png_bytes = b"\x89PNG\r\n\x1a\n" + b"\x00" * 100
    monkeypatch.setattr(svc.Text2ImgService, "_fetch_media", lambda self, fn: _async_return(png_bytes))

    r = client.get("/api/text2img/image/done-001", headers=auth_headers)
    assert r.status_code == 200
    assert r.content == png_bytes
    assert r.headers["content-type"] == "image/png"


@pytest.mark.auth
def test_get_image_pending_then_completed_via_history(
    client, auth_headers, db_session, patch_comfyui_generate, monkeypatch
):
    """pending 任务 + ComfyUI history 显示 completed + outputs → 200 (回填 DB)."""
    db_session.add(make_text2img_task(prompt_id="hist-001", status="pending"))
    db_session.commit()

    status_info = {
        "status": {"status_str": "success", "messages": []},
        "outputs": {
            "node1": {
                "images": [{"filename": "generated.png", "type": "output"}]
            }
        },
    }
    patch_comfyui_generate(prompt_id="x", status_info=status_info)

    import app.services.text2img_service as svc

    png_bytes = b"\x89PNG fake"
    monkeypatch.setattr(svc.Text2ImgService, "_fetch_media", lambda self, fn: _async_return(png_bytes))

    r = client.get("/api/text2img/image/hist-001", headers=auth_headers)
    assert r.status_code == 200
    assert r.content == png_bytes

    # DB 回填
    task = db_session.query(Text2ImgTask).filter_by(prompt_id="hist-001").first()
    assert task.status == "completed"
    assert task.filename == "generated.png"


@pytest.mark.auth
def test_get_image_history_failed_marks_task_failed(
    client, auth_headers, db_session, patch_comfyui_generate
):
    """pending 任务 + ComfyUI history 显示 error → 404 + DB 标 failed."""
    db_session.add(make_text2img_task(prompt_id="err-001", status="pending"))
    db_session.commit()

    status_info = {
        "status": {"status_str": "error", "messages": ["oom"]},
    }
    patch_comfyui_generate(prompt_id="x", status_info=status_info)

    r = client.get("/api/text2img/image/err-001", headers=auth_headers)
    assert r.status_code == 404

    task = db_session.query(Text2ImgTask).filter_by(prompt_id="err-001").first()
    assert task.status == "failed"


# ---- 辅助 ----------------------------------------------------------------
async def _async_return(value):
    """把同步值包成 awaitable (用于 patch async 方法返回固定值)."""
    return value
