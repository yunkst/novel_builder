#!/usr/bin/env python3
"""
Authentication and authorization utilities.

This module provides token-based authentication via the X-API-TOKEN header.
"""

import logging
import secrets

from fastapi import Header, HTTPException

from ..config import settings

logger = logging.getLogger(__name__)


def verify_token(
    x_api_token: str | None = Header(default=None, alias=settings.token_header),
):
    """
    Verify API token for authentication.

    Behavior:
    - Production: API_TOKEN must be set; missing/invalid token returns 401.
      If API_TOKEN is unset at startup the request is rejected with 500
      (server misconfiguration) and a startup warning is logged once.
    - Development (DEBUG=True) with API_TOKEN unset: all requests are allowed,
      a warning is logged per request (rate-limited via DEBUG flag).

    Args:
        x_api_token: Simple API token from X-API-TOKEN header

    Returns:
        bool: True if authenticated

    Raises:
        HTTPException: If authentication fails
    """
    # 未设置 API_TOKEN:开发环境放行,生产环境拒绝(配置错误)
    if not settings.api_token:
        if settings.debug:
            # 开发环境:无 token 配置时放行,记录警告(每次请求,但 DEBUG 才进)
            logger.warning(
                "Development mode: No API_TOKEN configured, allowing all requests"
            )
            return True
        # 生产环境:未配置 API_TOKEN 视为服务端配置错误,拒绝请求
        logger.error("Production environment requires API_TOKEN configuration")
        raise HTTPException(
            status_code=500,
            detail="Server configuration error: API_TOKEN not set",
        )

    # 验证 token
    if not x_api_token:
        logger.warning("Missing API token in request")
        raise HTTPException(
            status_code=401,
            detail="API token required",
            headers={"WWW-Authenticate": f"Bearer scheme='{settings.token_header}'"},
        )

    # 恒定时间比较,防时序侧信道
    if not secrets.compare_digest(str(x_api_token), str(settings.api_token)):
        logger.warning(f"Invalid API token provided: {x_api_token[:8]}...")
        raise HTTPException(status_code=401, detail="Invalid API token")

    logger.debug("API token validation successful")
    return True


def get_current_user_optional(
    x_api_token: str | None = Header(default=None, alias=settings.token_header),
):
    """
    Optional authentication - doesn't raise exception if token is missing.

    Returns:
        dict: User info or None if not authenticated
    """
    if not settings.api_token:
        return {"authenticated": False, "reason": "no_token_required"}

    if not x_api_token:
        return {"authenticated": False, "reason": "missing_token"}

    if not secrets.compare_digest(str(x_api_token), str(settings.api_token)):
        return {"authenticated": False, "reason": "invalid_token"}

    return {"authenticated": True, "user": "api_user"}
