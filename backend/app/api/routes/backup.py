#!/usr/bin/env python3
"""
Database backup API endpoints.

This module provides upload, list, download, and delete functionality
for user database backups.
"""

import shutil
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import FileResponse

from ...deps.auth import verify_token
from ...schemas import BackupInfo, BackupListResponse, BackupUploadResponse

router = APIRouter(prefix="/api/backup", tags=["backup"])

# 备份存储目录
BACKUP_DIR = Path("backups")


def _safe_backup_path(backup_id: str) -> Path:
    """根据 backup_id 解析安全路径，防止路径穿越攻击.

    Args:
        backup_id: 客户端传入的相对路径，如 "2025-07-15/novel_app_backup.db"

    Returns:
        解析后的绝对 Path 对象

    Raises:
        HTTPException: 路径超出 BACKUP_DIR 时抛出 403
    """
    # 拒绝空值
    if not backup_id:
        raise HTTPException(status_code=400, detail="backup_id 不能为空")

    candidate = (BACKUP_DIR / backup_id).resolve()
    base_resolved = BACKUP_DIR.resolve()

    # 防止路径穿越：解析后必须位于 BACKUP_DIR 之内
    if base_resolved not in candidate.parents and candidate != base_resolved:
        raise HTTPException(status_code=403, detail="非法的备份路径")

    return candidate


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
    curl -X POST "http://localhost:3800/api/backup/upload" \\
         -H "X-API-TOKEN: your-token" \\
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


@router.get("/list", response_model=BackupListResponse)
async def list_backups(
    authenticated: bool = Depends(verify_token),
):
    """
    列出服务器上所有备份文件.

    按修改时间倒序排列。backup_id 是相对路径，可直接用于
    /download/{backup_id} 和 /delete/{backup_id}。

    **认证**: 需要 X-API-TOKEN header
    """
    # 若备份目录不存在则创建空目录，返回空列表
    if not BACKUP_DIR.exists():
        BACKUP_DIR.mkdir(parents=True, exist_ok=True)
        return BackupListResponse(backups=[])

    backups: list[BackupInfo] = []

    # 遍历 BACKUP_DIR 下所有 .db 文件
    for db_file in BACKUP_DIR.rglob("*.db"):
        if not db_file.is_file():
            continue

        try:
            stat = db_file.stat()
        except OSError:
            continue

        # 计算 backup_id（相对 BACKUP_DIR 的路径，使用 POSIX 分隔符）
        backup_id = db_file.relative_to(BACKUP_DIR).as_posix()

        # 文件名（不含日期目录）
        stored_name = db_file.name

        backups.append(
            BackupInfo(
                filename=stored_name,
                file_size=stat.st_size,
                stored_name=stored_name,
                backup_id=backup_id,
                uploaded_at=datetime.fromtimestamp(stat.st_mtime).isoformat(),
            )
        )

    # 按修改时间倒序
    backups.sort(key=lambda b: b.uploaded_at, reverse=True)

    return BackupListResponse(backups=backups)


@router.get("/download/{backup_id:path}")
async def download_backup(
    backup_id: str,
    authenticated: bool = Depends(verify_token),
):
    """
    下载备份文件.

    **认证**: 需要 X-API-TOKEN header
    """
    file_path = _safe_backup_path(backup_id)

    if not file_path.exists() or not file_path.is_file():
        raise HTTPException(status_code=404, detail=f"备份文件不存在: {backup_id}")

    # 提取纯文件名作为下载时的 filename
    download_name = file_path.name

    return FileResponse(
        path=file_path,
        media_type="application/octet-stream",
        filename=download_name,
    )


@router.delete("/delete/{backup_id:path}")
async def delete_backup(
    backup_id: str,
    authenticated: bool = Depends(verify_token),
):
    """
    删除指定备份文件.

    如果删除后日期目录为空，会自动清理空目录。

    **认证**: 需要 X-API-TOKEN header
    """
    file_path = _safe_backup_path(backup_id)

    if not file_path.exists() or not file_path.is_file():
        raise HTTPException(status_code=404, detail=f"备份文件不存在: {backup_id}")

    try:
        file_path.unlink()
    except OSError as e:
        raise HTTPException(status_code=500, detail=f"删除失败: {str(e)}")

    # 清理空的日期目录
    parent_dir = file_path.parent
    try:
        # 仅当 BACKUP_DIR 的直接子目录为空时清理
        if (
            parent_dir != BACKUP_DIR
            and parent_dir.is_dir()
            and not any(parent_dir.iterdir())
        ):
            parent_dir.rmdir()
    except OSError:
        # 清理失败不影响主流程
        pass

    return {
        "message": "备份已删除",
        "backup_id": backup_id,
    }
