#!/usr/bin/env python3
"""
Pydantic schemas for client log upload API.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class LogEntrySchema(BaseModel):
    """单条日志条目"""

    timestamp: datetime = Field(..., description="客户端时间戳 (UTC ISO 8601)")
    level: str = Field(..., description="日志级别: debug/info/warning/error")
    message: str = Field(..., description="日志消息内容")
    stack_trace: Optional[str] = Field(None, description="堆栈信息")
    category: str = Field("general", description="日志分类")
    tags: list[str] = Field(default_factory=list, description="日志标签列表")


class LogUploadRequest(BaseModel):
    """日志上报请求"""

    logs: list[LogEntrySchema] = Field(
        ...,
        min_length=1,
        max_length=50,
        description="待上报的日志列表（1-50条）",
    )


class LogUploadResponse(BaseModel):
    """日志上报响应"""

    received: int = Field(..., description="成功接收的日志条数")
    message: str = Field(..., description="响应消息")
