#!/usr/bin/env python3
"""
Authentication and authorization utilities.

This module provides token-based authentication with support for both
simple token comparison and JWT tokens.
"""

import logging

from fastapi import Depends, Header, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from ..config import settings

logger = logging.getLogger(__name__)

# JWT security (for future enhancement)
security = HTTPBearer(auto_error=False)


def verify_token(
    x_api_token: str | None = Header(default=None, alias=settings.token_header),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
):
    """
    Verify API token for authentication.

    Supports both simple token comparison and JWT tokens.
    In development mode, allows requests without token if API_TOKEN is not set.

    Args:
        x_api_token: Simple API token from X-API-TOKEN header
        credentials: JWT token from Authorization header (future feature)

    Returns:
        bool: True if authenticated

    Raises:
        HTTPException: If authentication fails
    """
    # 检查JWT token (未来功能)
    if credentials and credentials.scheme.lower() == "bearer":
        try:
            # TODO: 实现JWT验证逻辑
            logger.info("JWT token detected, but not implemented yet")
            # 这里将添加JWT验证逻辑
        except Exception as e:
            logger.warning(f"JWT validation failed: {e}")
            raise HTTPException(
                status_code=401,
                detail="Invalid JWT token",
                headers={"WWW-Authenticate": "Bearer"},
            )

    # 简单token验证
    if not settings.api_token:
        # 开发环境：如果未设置API_TOKEN，记录警告但允许访问
        if settings.debug:
            logger.warning(
                "Development mode: No API_TOKEN configured, allowing all requests"
            )
            return True
        else:
            # 生产环境：必须设置API_TOKEN
            logger.error("Production environment requires API_TOKEN configuration")
            raise HTTPException(
                status_code=500, detail="Server configuration error: API_TOKEN not set"
            )

    # 验证token
    if not x_api_token:
        logger.warning("Missing API token in request")
        raise HTTPException(
            status_code=401,
            detail="API token required",
            headers={"WWW-Authenticate": f"Bearer scheme='{settings.token_header}'"},
        )

    if x_api_token != settings.api_token:
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

    if not x_api_token or x_api_token != settings.api_token:
        return {"authenticated": False, "reason": "invalid_token"}

    return {"authenticated": True, "user": "api_user"}
