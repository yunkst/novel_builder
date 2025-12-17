#!/usr/bin/env python3
"""
FastAPI main application.

This module contains the main FastAPI application with all API endpoints
for novel searching, chapter management, and caching functionality.
"""

import logging
import os
from datetime import datetime
from typing import Any

from fastapi import (
    Depends,
    FastAPI,
    HTTPException,
    Query,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from sqlalchemy.orm import Session

from .config import settings
from .database import get_db, init_db
from .deps.auth import verify_token
from .models.cache import ChapterCache as Cache
from .schemas import (
    Chapter,
    ChapterContent,
    EnhancedSceneIllustrationRequest,
    ImageToVideoRequest,
    ImageToVideoResponse,
    ImageToVideoTaskStatusResponse,
    Novel,
    RoleCardGenerateRequest,
    RoleCardTaskStatusResponse,
    RoleGalleryResponse,
    RoleImageDeleteRequest,
    RoleRegenerateRequest,
    SceneGalleryResponse,
    SceneImageDeleteRequest,
    SceneRegenerateRequest,
    SourceSite,
    VideoStatusResponse,
)
from .services.crawler_factory import (
    get_crawler_for_url,
    get_enabled_crawlers,
    get_source_sites_info,
)
from .services.dify_client import create_dify_client
from .services.image_to_video_service import create_image_to_video_service
from .services.role_card_async_service import role_card_async_service
from .services.role_card_service import role_card_service
from .services.scene_illustration_service import create_scene_illustration_service
from .services.search_service import SearchService

logger = logging.getLogger(__name__)

# 创建场面绘制服务实例
dify_client = create_dify_client()
scene_illustration_service = create_scene_illustration_service(dify_client)

# 创建图生视频服务实例
image_to_video_service = create_image_to_video_service()

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






@app.get("/text2img/image/{filename}", response_class=Response,
         responses={
             200: {
                 "content": {
                     "image/png": {
                         "schema": {
                             "type": "string",
                             "format": "binary"
                         }
                     }
                 },
                 "description": "成功返回图片二进制数据 (PNG格式)"
             },
             404: {
                 "description": "图片文件不存在"
             }
         })
async def get_image_proxy(filename: str):
    """
    图片代理接口 - 从ComfyUI获取图片并转发给用户

    返回图片二进制数据 (PNG格式)

    - **filename**: 图片文件名
    - **返回**: 图片二进制数据 (Content-Type: image/png)
    """
    import requests

    try:
        # 直接从ComfyUI获取图片
        comfyui_url = os.getenv("COMFYUI_API_URL", "http://host.docker.internal:8000")
        image_url = f"{comfyui_url}/view?filename={filename}"

        response = requests.get(image_url, timeout=None)
        if response.status_code == 200:
            return Response(
                content=response.content,
                media_type="image/png",
                headers={
                    "Cache-Control": "public, max-age=86400",  # 缓存1天
                    "X-Content-Type-Options": "nosniff"
                }
            )
        else:
            raise HTTPException(status_code=404, detail="图片不存在")
    except requests.RequestException:
        raise HTTPException(status_code=503, detail="无法连接到ComfyUI服务")


@app.get("/text2img/health", dependencies=[Depends(verify_token)])
async def text2img_health_check():
    """检查ComfyUI服务健康状态"""
    import requests

    try:
        comfyui_url = os.getenv("COMFYUI_API_URL", "http://host.docker.internal:8000")
        response = requests.get(f"{comfyui_url}/system_stats", timeout=5)

        if response.status_code == 200:
            return {
                "status": "healthy",
                "message": "ComfyUI服务正常",
                "services": {
                    "comfyui": True,
                    "api_accessible": True
                }
            }
        else:
            return {
                "status": "unhealthy",
                "message": f"ComfyUI服务响应异常: {response.status_code}",
                "services": {
                    "comfyui": False,
                    "api_accessible": False
                }
            }
    except requests.RequestException as e:
        return {
            "status": "unhealthy",
            "message": f"无法连接ComfyUI服务: {e!s}",
            "services": {
                "comfyui": False,
                "api_accessible": False
            }
        }


# ================= 人物卡图片生成 API =================


@app.post("/api/role-card/generate", dependencies=[Depends(verify_token)])
async def generate_role_card_images(
    request: RoleCardGenerateRequest,
    db: Session = Depends(get_db)
):
    """
    异步生成人物卡图片

    - **role_id**: 人物卡ID
    - **roles**: 人物卡设定信息
    - **model**: 使用的模型名称（可选）

    返回任务ID，可通过 /api/role-card/status/{task_id} 查询进度

    注意：用户要求已固定为"生成人物卡"，无需手动输入
    """
    try:
        result = await role_card_async_service.create_task(request, db)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"创建人物卡生成任务失败: {e}")
        raise HTTPException(status_code=500, detail="创建任务失败")


@app.get("/api/role-card/status/{task_id}", response_model=RoleCardTaskStatusResponse, dependencies=[Depends(verify_token)])
async def get_role_card_task_status(
    task_id: int,
    db: Session = Depends(get_db)
):
    """
    查询人物卡生成任务状态

    - **task_id**: 任务ID
    """
    try:
        result = await role_card_async_service.get_task_status(task_id, db)
        if not result:
            raise HTTPException(status_code=404, detail="任务不存在")
        return result
    except Exception as e:
        logger.error(f"查询任务状态失败: {e}")
        raise HTTPException(status_code=500, detail="查询任务状态失败")


@app.get("/api/role-card/gallery/{role_id}", response_model=RoleGalleryResponse, dependencies=[Depends(verify_token)])
async def get_role_card_gallery(
    role_id: str,
    db: Session = Depends(get_db)
):
    """
    查看角色图集

    - **role_id**: 人物卡ID
    """
    try:
        result = await role_card_service.get_role_gallery(role_id, db)
        return result
    except Exception as e:
        logger.error(f"获取角色图集失败: {e}")
        raise HTTPException(status_code=500, detail="获取图集失败")


@app.delete("/api/role-card/image", dependencies=[Depends(verify_token)])
async def delete_role_card_image(
    request: RoleImageDeleteRequest,
    db: Session = Depends(get_db)
):
    """
    从角色图集中删除图片

    - **role_id**: 人物卡ID
    - **img_url**: 要删除的图片URL
    """
    try:
        success = await role_card_service.delete_role_image(request, db)
        if success:
            return {"message": "图片删除成功"}
        else:
            raise HTTPException(status_code=404, detail="图片不存在")
    except Exception as e:
        logger.error(f"删除角色图片失败: {e}")
        raise HTTPException(status_code=500, detail="删除图片失败")


@app.post("/api/role-card/regenerate", dependencies=[Depends(verify_token)])
async def regenerate_similar_images(
    request: RoleRegenerateRequest,
    db: Session = Depends(get_db)
):
    """
    重新生成相似图片

    - **img_url**: 参考图片URL
    - **count**: 生成图片数量
    - **model**: 指定使用的模型名称（可选）
    """
    try:
        result = await role_card_service.regenerate_similar_images(request, db, model=request.model)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"重新生成相似图片失败: {e}")
        raise HTTPException(status_code=500, detail="重新生成图片失败")


@app.get("/api/role-card/models", dependencies=[Depends(verify_token)])
async def get_available_models():
    """获取可用的工作流模型列表"""
    try:
        from app.workflow_config.workflow_config import workflow_config_manager
        workflows = workflow_config_manager.list_t2i_workflows()

        return {
            "models": workflows,
            "total_count": len(workflows)
        }
    except Exception as e:
        logger.error(f"获取可用模型失败: {e}")
        raise HTTPException(status_code=500, detail="获取模型列表失败")


@app.get("/api/role-card/health", dependencies=[Depends(verify_token)])
async def role_card_health_check():
    """检查人物卡服务健康状态"""
    try:
        health_status = await role_card_service.health_check()
        overall_healthy = all(health_status.values())

        return {
            "status": "healthy" if overall_healthy else "unhealthy",
            "services": health_status
        }
    except Exception as e:
        logger.error(f"人物卡健康检查失败: {e}")
        return {
            "status": "error",
            "message": str(e),
            "services": {}
        }


# ================= 场面绘制 API =================


@app.post("/api/scene-illustration/generate", dependencies=[Depends(verify_token)])
async def generate_scene_images(
    request: EnhancedSceneIllustrationRequest,
    db: Session = Depends(get_db)
):
    """
    生成场面绘制图片

    - **chapters_content**: 章节内容
    - **task_id**: 任务标识符
    - **roles**: 角色信息
    - **num**: 生成图片数量
    - **model_name**: 指定使用的模型名称（可选）

    返回任务ID，可通过后续接口查询和获取图片
    """
    try:
        result = await scene_illustration_service.generate_scene_images(request, db)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"创建场面绘制任务失败: {e}")
        raise HTTPException(status_code=500, detail="创建任务失败")


@app.get("/api/scene-illustration/gallery/{task_id}", response_model=SceneGalleryResponse, dependencies=[Depends(verify_token)])
async def get_scene_gallery(
    task_id: str,
    db: Session = Depends(get_db)
):
    """
    查看场面绘制图片列表

    - **task_id**: 场面绘制任务ID
    """
    try:
        result = await scene_illustration_service.get_scene_gallery(task_id, db)
        return result
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"获取场面图集失败: {e}")
        raise HTTPException(status_code=500, detail="获取图集失败")


@app.delete("/api/scene-illustration/image", dependencies=[Depends(verify_token)])
async def delete_scene_image(
    request: SceneImageDeleteRequest,
    db: Session = Depends(get_db)
):
    """
    从场面绘制结果中删除图片

    - **task_id**: 场面绘制任务ID
    - **filename**: 要删除的图片文件名
    """
    try:
        success = await scene_illustration_service.delete_scene_image(request, db)
        if success:
            return {"message": "图片删除成功"}
        else:
            raise HTTPException(status_code=404, detail="图片不存在")
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"删除场面图片失败: {e}")
        raise HTTPException(status_code=500, detail="删除图片失败")


@app.post("/api/scene-illustration/regenerate", dependencies=[Depends(verify_token)])
async def regenerate_scene_images(
    request: SceneRegenerateRequest,
    db: Session = Depends(get_db)
):
    """
    基于现有任务重新生成场面图片

    - **task_id**: 原始任务ID
    - **count**: 生成图片数量
    - **model**: 指定使用的模型名称（可选，会使用原始任务的模型）
    """
    try:
        result = await scene_illustration_service.regenerate_scene_images(request, db)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"重新生成场面图片失败: {e}")
        raise HTTPException(status_code=500, detail="重新生成图片失败")




# ================= 图生视频 API =================


@app.post("/api/image-to-video/generate", response_model=ImageToVideoResponse, dependencies=[Depends(verify_token)])
async def generate_video_from_image(
    request: ImageToVideoRequest,
    db: Session = Depends(get_db)
):
    """
    生成图生视频

    创建一个图生视频任务，将指定的图片转换为动态视频。

    **请求参数:**
    - **img_name**: 要处理的图片文件名称
    - **user_input**: 用户对视频生成的要求描述
    - **model_name**: 图生视频模型名称

    **返回值:**
    - **task_id**: 视频生成任务的唯一标识符，用于后续状态查询
    - **img_name**: 处理的图片名称
    - **status**: 任务初始状态（通常为 "pending"）
    - **message**: 任务创建的状态消息

    **使用示例:**
    ```json
    {
        "task_id": 123,
        "img_name": "example.jpg",
        "status": "pending",
        "message": "图生视频任务创建成功"
    }
    ```

    **后续操作:**
    使用返回的 task_id 调用 `/api/image-to-video/status/{task_id}` 查询生成进度
    """
    try:
        result = await image_to_video_service.create_video_generation_task(request, db)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"创建图生视频任务失败: {e}")
        raise HTTPException(status_code=500, detail="创建任务失败")


@app.get("/api/image-to-video/has-video/{img_name}", response_model=VideoStatusResponse, dependencies=[Depends(verify_token)])
async def check_video_status(
    img_name: str,
    db: Session = Depends(get_db)
):
    """
    检查图片是否有已生成的视频

    根据图片名称快速查询是否已有对应的视频文件存在。

    **路径参数:**
    - **img_name**: 要查询的图片文件名称

    **返回值:**
    - **img_name**: 图片名称
    - **has_video**: 是否有对应的视频文件（true/false）
    - **video_url**: 视频文件URL（如果有）
    - **created_at**: 视频创建时间（如果有）

    **使用场景:**
    - 在显示图片时快速判断是否显示视频播放按钮
    - 避免重复创建已有视频的任务
    """
    try:
        result = await image_to_video_service.get_video_status(img_name, db)
        return result
    except Exception as e:
        logger.error(f"检查视频状态失败: {e}")
        raise HTTPException(status_code=500, detail="检查视频状态失败")


@app.get("/api/image-to-video/status/{task_id}", response_model=ImageToVideoTaskStatusResponse, dependencies=[Depends(verify_token)])
async def get_video_task_status(
    task_id: int,
    db: Session = Depends(get_db)
):
    """
    查询图生视频任务状态

    获取指定任务的详细状态信息，包括生成进度和结果。

    **路径参数:**
    - **task_id**: 图生视频任务的唯一标识符

    **返回值:**
    - **task_id**: 任务ID
    - **img_name**: 处理的图片名称
    - **status**: 任务状态（pending/running/completed/failed）
    - **model_name**: 使用的模型名称
    - **user_input**: 用户输入要求
    - **video_prompt**: 生成的视频提示词（如果有）
    - **video_filename**: 生成的视频文件名（完成时）
    - **result_message**: 结果描述信息
    - **error_message**: 错误信息（失败时）
    - **created_at**: 任务创建时间
    - **updated_at**: 任务更新时间
    """
    try:
        result = await image_to_video_service.get_task_status(task_id, db)
        if not result:
            raise HTTPException(status_code=404, detail="任务不存在")
        return result
    except Exception as e:
        logger.error(f"查询任务状态失败: {e}")
        raise HTTPException(status_code=500, detail="查询任务状态失败")


@app.get("/api/image-to-video/video/{img_name}", response_class=Response,
         responses={
             200: {
                 "content": {
                     "video/mp4": {
                         "schema": {
                             "type": "string",
                             "format": "binary"
                         }
                     }
                 },
                 "description": "成功返回视频二进制数据 (MP4格式)"
             },
             404: {
                 "description": "视频文件不存在"
             }
         })
async def get_video_file(img_name: str):
    """
    获取视频文件

    返回视频二进制数据 (MP4格式)

    - **img_name**: 图片名称
    - **返回**: 视频二进制数据 (Content-Type: video/mp4)
    """
    try:
        db = next(get_db())
        try:
            video_data = await image_to_video_service.get_video_file(img_name, db)
            if video_data:
                return Response(
                    content=video_data,
                    media_type="video/mp4",
                    headers={
                        "Cache-Control": "public, max-age=3600",  # 缓存1小时
                        "X-Content-Type-Options": "nosniff"
                    }
                )
            else:
                raise HTTPException(status_code=404, detail="视频文件不存在")
        finally:
            db.close()

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取视频文件失败: {e}")
        raise HTTPException(status_code=500, detail="获取视频文件失败")


@app.get("/api/image-to-video/health", dependencies=[Depends(verify_token)])
async def image_to_video_health_check():
    """检查图生视频服务健康状态"""
    try:
        health_status = await image_to_video_service.health_check()
        return health_status
    except Exception as e:
        logger.error(f"图生视频健康检查失败: {e}")
        return {
            "status": "error",
            "message": str(e),
            "services": {}
        }


# ================= 缓存管理 API =================














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
                # 创建新缓存记录（不依赖CacheTask）
                cached_chapter = Cache(
                    task_id=None,  # 独立章节不需要任务ID
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
            "角色卡AI图片生成",
            "ComfyUI图片生成",
            "图生视频功能",
            "Dify工作流集成",
        ],
        "endpoints": [
            "GET /source-sites - 获取源站列表",
            "GET /search?keyword=xxx&sites=alice_sw,shukuge - 搜索小说（可指定站点）",
            "GET /chapters?url=xxx - 获取章节列表",
            "GET /chapter-content?url=xxx&force_refresh=true - 获取章节内容",
            "GET /text2img/image/{filename} - 获取生成的图片",
            "GET /text2img/health - 文生图服务健康检查",
            "POST /api/image-to-video/generate - 图生视频生成",
            "GET /api/image-to-video/has-video/{img_name} - 检查图片是否有视频",
            "GET /api/image-to-video/video/{img_name} - 获取视频文件",
            "GET /api/image-to-video/status/{task_id} - 查询视频生成任务状态",
        ],
        "supported_sites": [
            "alice_sw - 轻小说文库",
            "shukuge - 书库",
            "xspsw - 小说网",
            "wdscw - 我的书城",
            "wodeshucheng - 我的书城(wodeshucheng)"
        ]
    }
