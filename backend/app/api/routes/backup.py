#!/usr/bin/env python3
"""
Database backup upload API endpoints.

This module provides file upload functionality for user database backups.
"""

import shutil
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from ...deps.auth import verify_token
from ...schemas import BackupUploadResponse

router = APIRouter(prefix="/api/backup", tags=["backup"])

# 备份存储目录
BACKUP_DIR = Path("backups")


@router.post("/upload", response_model=BackupUploadResponse)
async def upload_backup(
    file: UploadFile = File(..., description="数据库备份文件(.db)"),
    authenticated: bool = Depends(verify_token),
):
    """
    上传数据库备份文件

    - **file**: 数据库备份文件(.db格式)
    - 返回: 文件上传结果，包含存储路径、文件大小、上传时间等信息

    **功能特性**:
    - 支持.db格式文件
    - 按日期组织存储目录 (YYYY-MM-DD/)
    - 保留所有历史文件（不覆盖）
    - 使用原文件名，同名文件时追加时间戳避免冲突

    **认证**: 需要X-API-TOKEN header

    **示例请求**:
    ```bash
    curl -X POST "http://localhost:3800/api/backup/upload" \
         -H "X-API-TOKEN: your-token" \
         -F "file=@novel_app_backup.db"
    ```

    **示例响应**:
    ```json
    {
      "filename": "novel_app_backup.db",
      "stored_path": "backups/2025-01-28/novel_app_backup.db",
      "file_size": 1048576,
      "uploaded_at": "2025-01-28T12:34:56",
      "stored_name": "novel_app_backup.db"
    }
    ```
    """
    # 1. 验证文件扩展名
    if not file.filename:
        raise HTTPException(status_code=400, detail="文件名不能为空")

    if not file.filename.lower().endswith(".db"):
        raise HTTPException(
            status_code=400, detail="仅支持.db格式的数据库备份文件"
        )

    # 2. 生成存储路径（按日期分目录）
    date_str = datetime.now().strftime("%Y-%m-%d")
    date_dir = BACKUP_DIR / date_str

    # 创建日期目录
    try:
        date_dir.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        raise HTTPException(
            status_code=500, detail=f"无法创建备份目录: {str(e)}"
        )

    # 3. 确定存储文件名（避免冲突）
    original_filename = file.filename
    stored_filename = original_filename
    file_path = date_dir / stored_filename

    # 如果文件已存在，追加时间戳
    if file_path.exists():
        timestamp = datetime.now().strftime("%H%M%S")
        name_without_ext = original_filename[:-3]  # 去掉.db
        stored_filename = f"{name_without_ext}_{timestamp}.db"
        file_path = date_dir / stored_filename

    # 4. 流式写入文件（避免大文件占用过多内存）
    try:
        with file_path.open("wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except OSError as e:
        raise HTTPException(status_code=500, detail=f"文件写入失败: {str(e)}")
    finally:
        # 确保文件对象被关闭
        file.file.close()

    # 5. 获取文件大小
    try:
        file_size = file_path.stat().st_size
    except OSError as e:
        file_size = 0

    # 6. 生成响应（返回相对路径，方便跨平台）
    stored_path = str(file_path)

    return BackupUploadResponse(
        filename=original_filename,
        stored_path=stored_path,
        file_size=file_size,
        uploaded_at=datetime.now().isoformat(),
        stored_name=stored_filename,
    )
