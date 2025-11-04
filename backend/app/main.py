#!/usr/bin/env python3
"""
FastAPI main application.

This module contains the main FastAPI application with all API endpoints
for novel searching, chapter management, and caching functionality.
"""

from datetime import datetime
from typing import Any

from fastapi import (
    Depends,
    FastAPI,
    HTTPException,
    Query,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from sqlalchemy.orm import Session

from .config import settings
from .database import get_db, init_db
from .deps.auth import verify_token
from .models.cache import ChapterCache as Cache
from .schemas import Chapter, ChapterContent, Novel, SourceSite
from .services.crawler_factory import (
    get_crawler_for_url,
    get_enabled_crawlers,
    get_source_sites_info,
)
from .services.novel_cache_service import novel_cache_service
from .services.search_service import SearchService

app = FastAPI(
    title="Novel Builder Backend",
    version="0.2.0",
    description="FastAPI backend for novel crawling and management",
)

# CORS（允许前端在局域网访问）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 如需更严格控制，可改为具体前端地址
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# 应用启动事件
@app.on_event("startup")
async def startup_event() -> None:
    # 初始化数据库
    init_db()
    print("✓ Novel Builder Backend 启动完成")
    print(f"✓ 启用的爬虫站点: {settings.enabled_sites}")
    if settings.debug:
        print("✓ 调试模式已开启")


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/source-sites", response_model=list[SourceSite], dependencies=[Depends(verify_token)])
async def get_source_sites() -> list[dict[str, Any]]:
    """获取所有源站列表"""
    return get_source_sites_info()


@app.get("/search", response_model=list[Novel], dependencies=[Depends(verify_token)])
async def search(
    keyword: str = Query(..., min_length=1, description="小说名称或作者"),
    sites: str = Query(None, description="指定搜索站点，逗号分隔，如 alice_sw,shukuge")
) -> list[dict[str, Any]]:
    """搜索小说，支持指定站点"""
    if sites:
        # 解析指定站点，只使用指定的爬虫
        site_list = [s.strip() for s in sites.split(",")]
        crawlers = {site: crawler for site, crawler in get_enabled_crawlers().items()
                   if site in site_list}
        if not crawlers:
            raise HTTPException(status_code=400, detail="指定的站点无效或未启用")
    else:
        # 使用所有启用的站点
        crawlers = get_enabled_crawlers()

    service = SearchService(list(crawlers.values()))
    results = await service.search(keyword, crawlers)
    return results


@app.get(
    "/chapters", response_model=list[Chapter], dependencies=[Depends(verify_token)]
)
async def chapters(url: str = Query(..., description="小说详情页或阅读页URL")) -> list[dict[str, Any]]:
    crawler = get_crawler_for_url(url)
    if not crawler:
        raise HTTPException(status_code=400, detail="不支持该URL的站点")
    chapters = await crawler.get_chapter_list(url)
    return chapters


@app.get(
    "/chapter-content",
    response_model=ChapterContent,
    dependencies=[Depends(verify_token)],
)
async def chapter_content(
    url: str = Query(..., description="章节URL"),
    force_refresh: bool = Query(False, description="强制刷新，从源站重新获取"),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    """
    获取章节内容

    - **url**: 章节URL
    - **force_refresh**: 是否强制刷新（默认 False）
      - False: 优先从缓存获取，缓存不存在时从源站抓取
      - True: 强制从源站重新获取（用于更新内容）
    """
    # 1. 如果不强制刷新，先检查缓存
    if not force_refresh:
        cached_chapter = (
            db.query(Cache)
            .filter(Cache.chapter_url == url)
            .first()
        )

        if cached_chapter:
            # 检查缓存内容的字数，如果小于300则认为缓存无效，需要重新获取
            if cached_chapter.word_count < 300:
                # 缓存字数不足，标记为需要重新获取
                pass  # 继续执行下面的源站获取逻辑
            else:
                return {
                    "title": cached_chapter.chapter_title,
                    "content": cached_chapter.chapter_content,
                    "from_cache": True,
                }

    # 2. 从源站获取内容
    crawler = get_crawler_for_url(url)
    if not crawler:
        raise HTTPException(status_code=400, detail="不支持该URL的站点")

    content_data = await crawler.get_chapter_content(url)

    # 3. 保存到缓存（不阻塞响应）
    if content_data and content_data.get("content"):
        try:
            # 在后台线程中保存缓存，不阻塞响应
            import threading
            thread = threading.Thread(
                target=_save_chapter_to_cache_sync,
                args=(url, content_data["title"], content_data["content"])
            )
            thread.daemon = True
            thread.start()
        except Exception:
            # 缓存保存失败不影响正常响应
            pass

    return {
        "title": content_data.get("title", "章节内容"),
        "content": content_data.get("content", ""),
        "from_cache": False,
    }


# ================= 缓存管理 API =================


@app.post("/api/cache/create", dependencies=[Depends(verify_token)])
async def create_cache_task(
    novel_url: str = Query(..., description="小说URL"), db: Session = Depends(get_db)
):
    """
    创建缓存任务

    - **novel_url**: 小说详情页URL
    """
    try:
        task = await novel_cache_service.create_cache_task(novel_url, db)
        return {
            "task_id": task.id,
            "status": task.status,
            "novel_title": task.novel_title,
            "novel_author": task.novel_author,
            "total_chapters": task.total_chapters,
            "message": "缓存任务创建成功",
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"创建缓存任务失败: {e!s}")


@app.get("/api/cache/status/{task_id}", dependencies=[Depends(verify_token)])
async def get_cache_status(task_id: int, db: Session = Depends(get_db)):
    """获取缓存任务状态"""
    task = await novel_cache_service.get_task_status(task_id, db)
    if not task:
        raise HTTPException(status_code=404, detail="缓存任务不存在")

    progress = (
        (task.cached_chapters / task.total_chapters * 100)
        if task.total_chapters > 0
        else 0
    )

    return {
        "task_id": task.id,
        "status": task.status,
        "novel_title": task.novel_title,
        "novel_author": task.novel_author,
        "novel_url": task.novel_url,
        "total_chapters": task.total_chapters,
        "cached_chapters": task.cached_chapters,
        "failed_chapters": task.failed_chapters,
        "progress": round(progress, 2),
        "created_at": task.created_at.isoformat(),
        "updated_at": task.updated_at.isoformat() if task.updated_at else None,
        "completed_at": task.completed_at.isoformat() if task.completed_at else None,
        "error_message": task.error_message,
    }


@app.get("/api/cache/tasks", dependencies=[Depends(verify_token)])
async def get_cache_tasks(
    status: str = Query(
        None, description="任务状态筛选: pending, running, completed, failed, cancelled"
    ),
    limit: int = Query(20, ge=1, le=100, description="返回数量限制"),
    offset: int = Query(0, ge=0, description="偏移量"),
    db: Session = Depends(get_db),
):
    """获取缓存任务列表"""
    tasks = await novel_cache_service.get_cache_tasks(status, limit, offset, db)

    return {
        "tasks": [
            {
                "task_id": task.id,
                "status": task.status,
                "novel_title": task.novel_title,
                "novel_author": task.novel_author,
                "total_chapters": task.total_chapters,
                "cached_chapters": task.cached_chapters,
                "failed_chapters": task.failed_chapters,
                "progress": round(
                    (task.cached_chapters / task.total_chapters * 100)
                    if task.total_chapters > 0
                    else 0,
                    2,
                ),
                "created_at": task.created_at.isoformat(),
                "completed_at": task.completed_at.isoformat()
                if task.completed_at
                else None,
            }
            for task in tasks
        ],
        "total": len(tasks),
    }


@app.post("/api/cache/cancel/{task_id}", dependencies=[Depends(verify_token)])
async def cancel_cache_task(task_id: int, db: Session = Depends(get_db)):
    """取消缓存任务"""
    success = await novel_cache_service.cancel_task(task_id, db)
    if success:
        return {"message": "任务已取消", "task_id": task_id}
    else:
        raise HTTPException(status_code=404, detail="任务不存在或无法取消")


@app.get("/api/cache/download/{task_id}", dependencies=[Depends(verify_token)])
async def download_cached_novel(
    task_id: int,
    format: str = Query("json", description="下载格式: json, txt"),
    db: Session = Depends(get_db),
):
    """
    下载已缓存的小说

    - **task_id**: 缓存任务ID
    - **format**: 下载格式 (json/txt)
    """
    # 检查任务是否存在且已完成
    task = await novel_cache_service.get_task_status(task_id, db)
    if not task or task.status != "completed":
        raise HTTPException(status_code=404, detail="缓存任务不存在或未完成")

    # 获取所有已缓存的章节
    chapters = await novel_cache_service.get_cached_chapters(task_id, db)

    if format == "json":
        return {
            "novel": {
                "title": task.novel_title,
                "author": task.novel_author,
                "url": task.novel_url,
                "total_chapters": len(chapters),
                "cached_at": task.completed_at.isoformat()
                if task.completed_at
                else None,
            },
            "chapters": [
                {
                    "title": ch.chapter_title,
                    "url": ch.chapter_url,
                    "content": ch.chapter_content,
                    "word_count": ch.word_count,
                    "index": ch.chapter_index,
                    "cached_at": ch.cached_at.isoformat() if ch.cached_at else None,
                }
                for ch in chapters
            ],
        }

    elif format == "txt":
        # 生成TXT格式
        content = (
            f"{task.novel_title}\n作者：{task.novel_author}\n来源：{task.novel_url}\n\n"
        )
        content += "=" * 50 + "\n\n"

        for ch in chapters:
            content += f"第{ch.chapter_index + 1}章 {ch.chapter_title}\n\n"
            content += str(ch.chapter_content) + "\n\n"
            content += "-" * 30 + "\n\n"

        return Response(
            content=content,
            media_type="text/plain; charset=utf-8",
            headers={
                "Content-Disposition": f"attachment; filename={task.novel_title}.txt"
            },
        )

    else:
        raise HTTPException(status_code=400, detail="不支持的格式，请使用 json 或 txt")


@app.websocket("/ws/cache/{task_id}")
async def cache_progress_websocket(websocket: WebSocket, task_id: int):
    """缓存进度WebSocket连接"""
    await websocket.accept()

    try:
        # 添加WebSocket连接
        await novel_cache_service.add_websocket_connection(task_id, websocket)

        # 立即发送当前状态
        db = next(get_db())
        try:
            task = await novel_cache_service.get_task_status(task_id, db)
            if task:
                progress = (
                    (task.cached_chapters / task.total_chapters * 100)
                    if task.total_chapters > 0
                    else 0
                )
                await websocket.send_json(
                    {
                        "task_id": task_id,
                        "status": task.status,
                        "total_chapters": task.total_chapters,
                        "cached_chapters": task.cached_chapters,
                        "failed_chapters": task.failed_chapters,
                        "progress": round(progress, 2),
                        "updated_at": task.updated_at.isoformat()
                        if task.updated_at
                        else None,
                        "error_message": task.error_message,
                    }
                )
        finally:
            db.close()

        # 保持连接活跃
        while True:
            try:
                await websocket.receive_text()
            except WebSocketDisconnect:
                break

    except WebSocketDisconnect:
        pass
    except Exception as e:
        print(f"WebSocket错误: {e}")
    finally:
        # 移除WebSocket连接
        await novel_cache_service.remove_websocket_connection(task_id, websocket)


# ================= 辅助函数 =================


def _save_chapter_to_cache_sync(chapter_url: str, title: str, content: str):
    """
    同步保存章节到缓存（在后台线程中运行）

    Args:
        chapter_url: 章节URL
        title: 章节标题
        content: 章节内容
    """
    if not content or len(content) < 300:  # 跳过过短的内容，字数小于300的缓存无效
        return

    try:
        from .models.cache import CacheTask

        with next(get_db()) as db:
            # 检查是否已存在
            existing = (
                db.query(Cache)
                .filter(Cache.chapter_url == chapter_url)
                .first()
            )

            if existing:
                # 更新现有缓存
                existing.chapter_title = title
                existing.chapter_content = content
                existing.word_count = len(content)
                existing.cached_at = datetime.now()
            else:
                # 创建或获取一个默认的缓存任务
                default_task = (
                    db.query(CacheTask)
                    .filter(CacheTask.novel_url == "individual_chapters")
                    .first()
                )

                if not default_task:
                    default_task = CacheTask(
                        novel_url="individual_chapters",
                        novel_title="独立缓存章节",
                        novel_author="系统",
                        status="completed",
                        total_chapters=1,
                        cached_chapters=1,
                        failed_chapters=0,
                        completed_at=datetime.now()
                    )
                    db.add(default_task)
                    db.flush()  # 确保获取ID

                # 创建新缓存记录
                cached_chapter = Cache(
                    task_id=default_task.id,
                    novel_url="individual_chapters",
                    chapter_title=title,
                    chapter_url=chapter_url,
                    chapter_content=content,
                    chapter_index=0,  # 独立章节索引设为0
                    word_count=len(content),
                    cached_at=datetime.now()
                )
                db.add(cached_chapter)

            db.commit()

    except Exception as e:
        # 缓存保存失败，记录日志但不影响主功能
        print(f"保存章节缓存失败: {e}")


async def _save_chapter_to_cache_async(chapter_url: str, title: str, content: str):
    """
    异步保存章节到缓存（已弃用，保留用于向后兼容）

    Args:
        chapter_url: 章节URL
        title: 章节标题
        content: 章节内容
    """
    # 为了向后兼容，调用同步版本
    _save_chapter_to_cache_sync(chapter_url, title, content)


# 便于 Docker 容器启动时的提示
@app.get("/")
def index():
    return {
        "message": "Novel Builder Backend",
        "version": "0.2.0",
        "docs": "/docs",
        "token_required": True,
        "token_header": settings.token_header,
        "features": [
            "多站点小说搜索",
            "指定站点搜索功能",
            "源站列表获取",
            "章节列表获取",
            "章节内容获取（支持缓存）",
            "智能缓存机制",
            "实时内容抓取",
            "后台缓存任务",
            "WebSocket进度推送",
        ],
        "endpoints": [
            "GET /source-sites - 获取源站列表",
            "GET /search?keyword=xxx&sites=alice_sw,shukuge - 搜索小说（可指定站点）",
            "GET /chapters?url=xxx - 获取章节列表",
            "GET /chapter-content?url=xxx&force_refresh=true - 获取章节内容",
        ],
        "supported_sites": [
            "alice_sw - 轻小说文库",
            "shukuge - 书库",
            "xspsw - 小说网"
        ]
    }
