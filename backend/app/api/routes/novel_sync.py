#!/usr/bin/env python3
"""
小说同步API端点.
"""

import logging

from fastapi import APIRouter, Depends, HTTPException

from ...deps.auth import verify_token
from ...schemas import (
    NovelSyncData,
    NovelSyncDeleteResponse,
    NovelSyncDownloadRequest,
    NovelSyncDownloadResponse,
    NovelSyncListResponse,
    NovelSyncUploadRequest,
    NovelSyncUploadResponse,
)
from ...services.novel_sync_service import (
    NovelSyncServiceError,
    get_novel_sync_service,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/novel/sync", tags=["novel-sync"])


@router.post(
    "/upload",
    response_model=NovelSyncUploadResponse,
    dependencies=[Depends(verify_token)],
)
async def upload_novel(request: NovelSyncUploadRequest):
    """上传小说数据到服务器."""
    try:
        service = get_novel_sync_service()
        result = service.save_novel(request.novel_data, force_overwrite=request.force_overwrite)

        return NovelSyncUploadResponse(
            success=True,
            message="小说数据上传成功",
            title=result["title"],
            sync_version=result["sync_version"],
            synced_at=result["synced_at"],
        )

    except NovelSyncServiceError as e:
        logger.warning(f"小说上传失败: {e.message}")
        raise HTTPException(status_code=400, detail=e.to_dict())
    except Exception as e:
        logger.error(f"小说上传异常: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {e!s}")


@router.post(
    "/download",
    response_model=NovelSyncDownloadResponse,
    dependencies=[Depends(verify_token)],
)
async def download_novel(request: NovelSyncDownloadRequest):
    """从服务器下载小说数据."""
    try:
        service = get_novel_sync_service()

        novel_data = service.load_novel(request.title)

        if not novel_data:
            return NovelSyncDownloadResponse(
                success=False,
                message="小说数据不存在",
                novel_data=None,
                sync_version=0,
                synced_at="",
            )

        if not request.include_chapters:
            novel_data.chapters = []
        if not request.include_characters:
            novel_data.characters = []
            novel_data.character_relations = []
        if not request.include_outlines:
            novel_data.outlines = []

        sync_status = service.get_sync_status(request.title)

        return NovelSyncDownloadResponse(
            success=True,
            message="小说数据下载成功",
            novel_data=novel_data,
            sync_version=sync_status.get("sync_version", 1) if sync_status else 1,
            synced_at=sync_status.get("synced_at", "") if sync_status else "",
        )

    except NovelSyncServiceError as e:
        logger.warning(f"小说下载失败: {e.message}")
        raise HTTPException(status_code=400, detail=e.to_dict())
    except Exception as e:
        logger.error(f"小说下载异常: {e}")
        raise HTTPException(status_code=500, detail=f"下载失败: {e!s}")


@router.get(
    "/list",
    response_model=NovelSyncListResponse,
    dependencies=[Depends(verify_token)],
)
async def list_synced_novels(
    page: int = 1,
    page_size: int = 20,
):
    """获取已同步小说列表."""
    try:
        service = get_novel_sync_service()

        page_size = min(page_size, 100)

        result = service.list_synced_novels(page=page, page_size=page_size)

        novels = []
        for novel_meta in result["novels"]:
            novels.append(
                NovelSyncData(
                    title=novel_meta["title"],
                    author=novel_meta.get("author"),
                )
            )

        return NovelSyncListResponse(
            success=True,
            message="获取同步列表成功",
            novels=novels,
            total_count=result["total_count"],
            page=result["page"],
            page_size=result["page_size"],
        )

    except Exception as e:
        logger.error(f"获取同步列表异常: {e}")
        raise HTTPException(status_code=500, detail=f"获取列表失败: {e!s}")


@router.delete(
    "/delete",
    response_model=NovelSyncDeleteResponse,
    dependencies=[Depends(verify_token)],
)
async def delete_synced_novel(title: str):
    """删除已同步的小说数据."""
    try:
        service = get_novel_sync_service()

        success = service.delete_novel(title)

        if not success:
            raise HTTPException(status_code=404, detail="小说数据不存在")

        return NovelSyncDeleteResponse(
            success=True,
            message="小说数据删除成功",
        )

    except NovelSyncServiceError as e:
        logger.warning(f"小说删除失败: {e.message}")
        raise HTTPException(status_code=400, detail=e.to_dict())
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"小说删除异常: {e}")
        raise HTTPException(status_code=500, detail=f"删除失败: {e!s}")