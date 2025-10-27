#!/usr/bin/env python3

from fastapi import Header, HTTPException

from ..config import settings


def verify_token(
    x_api_token: str | None = Header(default=None, alias=settings.token_header),
):
    # 如果未设置环境变量，则不进行校验（便于本地开发）；生产请务必设置
    if not settings.api_token:
        return True
    if not x_api_token or x_api_token != settings.api_token:
        raise HTTPException(status_code=401, detail="TOKEN 无效或缺失")
    return True
