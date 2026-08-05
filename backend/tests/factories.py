#!/usr/bin/env python3
"""
Test data factories for backend tests.

轻量函数式工厂: 每个工厂返回一个已构造但未提交的 ORM 对象(由调用方 commit),
传入 `**overrides` 覆盖默认字段,降低重复样板。
"""

from __future__ import annotations

import json
from datetime import datetime, timezone

from app.models import ClientLog, ImageToVideoTask, Text2ImgTask


def make_text2img_task(
    prompt_id: str = "test-prompt-id-001",
    prompt: str = "a beautiful sunset",
    negative_prompt: str | None = None,
    model_name: str = "default-t2i",
    status: str = "pending",
    filename: str | None = None,
    error_message: str | None = None,
    **overrides,
) -> Text2ImgTask:
    """构造 Text2ImgTask(未持久化)。"""
    return Text2ImgTask(
        prompt_id=prompt_id,
        prompt=prompt,
        negative_prompt=negative_prompt,
        model_name=model_name,
        status=status,
        filename=filename,
        error_message=error_message,
        **overrides,
    )


def make_image_to_video_task(
    prompt_id: str = "test-i2v-id-001",
    prompt: str = "slow motion",
    model_name: str = "default-i2v",
    image_filename: str | None = None,
    status: str = "pending",
    video_filename: str | None = None,
    error_message: str | None = None,
    **overrides,
) -> ImageToVideoTask:
    """构造 ImageToVideoTask(未持久化)。"""
    return ImageToVideoTask(
        prompt_id=prompt_id,
        prompt=prompt,
        model_name=model_name,
        image_filename=image_filename,
        status=status,
        video_filename=video_filename,
        error_message=error_message,
        **overrides,
    )


def make_client_log(
    level: str = "info",
    message: str = "test message",
    stack_trace: str | None = None,
    category: str = "general",
    tags: list[str] | None = None,
    timestamp: datetime | None = None,
    **overrides,
) -> ClientLog:
    """构造 ClientLog(未持久化)。"""
    if timestamp is None:
        timestamp = datetime.now(timezone.utc)
    return ClientLog(
        level=level,
        message=message,
        stack_trace=stack_trace,
        category=category,
        tags=json.dumps(tags) if tags else None,
        timestamp=timestamp,
        **overrides,
    )


def make_log_upload_payload(
    n: int = 3,
    level: str = "info",
    message_prefix: str = "log",
) -> dict:
    """构造符合 LogUploadRequest 的 JSON dict,供 POST /api/logs/upload 使用。

    - n: 条数
    - level / message_prefix: 通用覆盖
    """
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc).isoformat()
    return {
        "logs": [
            {
                "timestamp": now,
                "level": level,
                "message": f"{message_prefix} {i}",
                "stack_trace": None,
                "category": "general",
                "tags": [],
            }
            for i in range(n)
        ]
    }