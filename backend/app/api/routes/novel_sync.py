#!/usr/bin/env python3
"""
小说同步API端点.

This module provides API endpoints for syncing novel data between APP and server,
including upload, download, list, and delete operations.
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
    """
    上传小说数据到服务器.

    接收APP端上传的完整小说数据，包括章节、角色、关系和大纲等信息。
    服务器会根据source_url作为唯一标识存储数据，支持版本控制。

    **请求参数:**
    - **device_id**: 设备标识（用于追踪同步来源）
    - **novel_data**: 完整的小说数据，包括：
        - 基本信息（标题、作者、简介等）
        - 章节列表（包括用户插入章节）
        - 角色列表
        - 角色关系列表
        - 大纲列表
    - **force_overwrite**: 是否强制覆盖服务器数据（默认false）

    **返回值:**
    - **success**: 是否成功
    - **message**: 响应消息
    - **novel_id**: 小说ID
    - **sync_version**: 同步版本号（每次更新递增）
    - **synced_at**: 同步时间

    **认证**: 需要X-API-TOKEN header
    """
    try:
        service = get_novel_sync_service()
        result = service.save_novel(request.novel_data, force_overwrite=request.force_overwrite)

        return NovelSyncUploadResponse(
            success=True,
            message="小说数据上传成功",
            novel_id=result["novel_id"],
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
    """
    从服务器下载小说数据.

    根据小说来源URL（source_url）获取服务器上存储的完整小说数据。
    支持选择性下载章节、角色和大纲数据。

    **请求参数:**
    - **device_id**: 设备标识
    - **source_url**: 小说来源URL（作为唯一标识，与上传时一致）
    - **include_chapters**: 是否包含章节内容（默认true）
    - **include_characters**: 是否包含角色数据（默认true）
    - **include_outlines**: 是否包含大纲数据（默认true）

    **返回值:**
    - **success**: 是否成功
    - **message**: 响应消息
    - **novel_data**: 完整的小说数据（如果找到）
    - **sync_version**: 同步版本号
    - **synced_at**: 最后同步时间

    **认证**: 需要X-API-TOKEN header

    **注意:** 如果小说不存在，返回success=false，novel_data=null
    """
    try:
        service = get_novel_sync_service()

        # 使用source_url作为唯一标识加载小说数据
        novel_data = service.load_novel(request.source_url)

        if not novel_data:
            return NovelSyncDownloadResponse(
                success=False,
                message="小说数据不存在",
                novel_data=None,
                sync_version=0,
                synced_at="",
            )

        # 根据请求参数过滤数据
        if not request.include_chapters:
            novel_data.chapters = []
        if not request.include_characters:
            novel_data.characters = []
            novel_data.character_relations = []
        if not request.include_outlines:
            novel_data.outlines = []

        # 获取同步状态
        sync_status = service.get_sync_status(request.source_url)

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
    """
    获取已同步小说列表.

    返回服务器上所有已同步小说的基本信息列表，支持分页。
    返回的数据仅包含元数据，不包含章节内容。

    **查询参数:**
    - **page**: 页码（从1开始，默认1）
    - **page_size**: 每页数量（默认20，最大100）

    **返回值:**
    - **success**: 是否成功
    - **message**: 响应消息
    - **novels**: 小说元数据列表
    - **total_count**: 总数
    - **page**: 当前页码
    - **page_size**: 每页数量

    **认证**: 需要X-API-TOKEN header
    """
    try:
        service = get_novel_sync_service()

        # 限制page_size最大值
        page_size = min(page_size, 100)

        result = service.list_synced_novels(page=page, page_size=page_size)

        # 转换为NovelSyncData格式（仅包含基本信息）
        novels = []
        for novel_meta in result["novels"]:
            novels.append(
                NovelSyncData(
                    novel_id=novel_meta["novel_id"],
                    title=novel_meta["title"],
                    author=novel_meta.get("author"),
                    source_url=novel_meta.get("source_url"),
                    total_chapters=novel_meta.get("total_chapters", 0),
                    chapters=[],  # 列表不返回章节内容
                    characters=[],  # 列表不返回角色数据
                    character_relations=[],  # 列表不返回角色关系
                    outlines=[],  # 列表不返回大纲数据
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
async def delete_synced_novel(novel_url: str):
    """
    删除已同步的小说数据.

    从服务器删除指定小说的所有同步数据，包括章节、角色、关系和大纲。

    **查询参数:**
    - **novel_url**: 小说URL（作为唯一标识）

    **返回值:**
    - **success**: 是否成功
    - **message**: 响应消息

    **认证**: 需要X-API-TOKEN header

    **注意:** 此操作不可逆，删除后数据无法恢复
    """
    try:
        service = get_novel_sync_service()

        success = service.delete_novel(novel_url)

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