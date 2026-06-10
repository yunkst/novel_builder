#!/usr/bin/env python3
"""
Client log upload API routes.

POST /api/logs/upload - Upload batch of client logs
"""

import json
import logging

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...database import get_db
from ...deps.auth import verify_token
from ...models.client_log import ClientLog
from ...schemas.log import LogUploadRequest, LogUploadResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/logs", tags=["logs"])


@router.post(
    "/upload",
    response_model=LogUploadResponse,
    dependencies=[Depends(verify_token)],
)
async def upload_logs(
    request: LogUploadRequest,
    db: Session = Depends(get_db),
) -> LogUploadResponse:
    """
    上传客户端日志

    接收客户端批量上报的日志并存入数据库。
    单次最多接收 50 条日志。
    """
    count = 0
    try:
        for entry in request.logs:
            db.add(
                ClientLog(
                    level=entry.level,
                    message=entry.message,
                    stack_trace=entry.stack_trace,
                    category=entry.category,
                    tags=json.dumps(entry.tags) if entry.tags else None,
                    timestamp=entry.timestamp,
                )
            )
            count += 1

        db.commit()
        logger.info(f"成功接收 {count} 条客户端日志")
        return LogUploadResponse(
            received=count, message=f"成功接收 {count} 条日志"
        )

    except Exception as e:
        db.rollback()
        logger.error(f"日志上报处理失败: {e}")
        return LogUploadResponse(
            received=0, message=f"处理失败: {e!s}"
        )