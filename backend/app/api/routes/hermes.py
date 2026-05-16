#!/usr/bin/env python3
"""
Hermes AI Chat API endpoints.

This module provides API endpoints for Hermes AI chat functionality,
including streaming chat completions and health checks.
"""

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse

from ...deps.auth import verify_token
from ...services.hermes_client import get_hermes_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/hermes", tags=["hermes"])


@router.post(
    "/chat/completions",
    dependencies=[Depends(verify_token)],
)
async def chat_completions(request: Request):
    """
    Hermes AI Chat Completions (Streaming).

    Proxies chat completion requests to the Hermes API Server with
    streaming response support.

    **Request Body:**
    - **messages**: List of chat messages with role and content
    - **model**: (Optional) Model name to use
    - **stream**: (Optional) Enable streaming, defaults to true
    - **session_id**: (Optional) Session ID for conversation continuity
    - Any other parameters supported by the Hermes API

    **Response:**
    - SSE stream with chat completion chunks
    - X-Hermes-Session-Id header for session tracking
    """
    try:
        body = await request.json()
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid JSON body") from exc

    client = get_hermes_client()

    if not client.is_configured:
        raise HTTPException(
            status_code=503,
            detail=(
                "Hermes API is not configured. "
                "Please set HERMES_API_URL and HERMES_API_KEY."
            ),
        )

    # Ensure stream is enabled
    body.setdefault("stream", True)

    session_id = body.pop("session_id", None)
    if session_id:
        body.setdefault("extra_headers", {})
        body["extra_headers"]["X-Hermes-Session-Id"] = session_id

    async def stream_generator():
        try:
            async for chunk in client.chat_completions_stream(body):
                yield chunk
        except ValueError as e:
            logger.error("Hermes configuration error: %s", e)
            yield b'data: {"error": "Hermes API not configured"}\n\n'
        except Exception as e:
            logger.error("Hermes streaming error: %s", e)
            yield f'data: {{"error": "{e!s}"}}\n\n'.encode()

    return StreamingResponse(
        stream_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.get(
    "/health",
    dependencies=[Depends(verify_token)],
)
async def hermes_health_check() -> dict[str, Any]:
    """
    Check Hermes AI service health status.

    Returns configuration status and connectivity information.
    """
    client = get_hermes_client()
    return await client.health_check()
