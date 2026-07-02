#!/usr/bin/env python3
"""
FastAPI main application.

This module contains the main FastAPI application with all API endpoints
for novel searching, chapter management, and caching functionality.
"""

import logging
import secrets
from typing import Any

from fastapi import (
    Depends,
    FastAPI,
    File,
    Form,
    HTTPException,
    Query,
    Request,
    UploadFile,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, Response
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from .config import settings
from .constants import CACHE_ONE_DAY, CACHE_ONE_HOUR, TIMEOUT_FAST
from .database import get_db, init_db
from .deps.auth import verify_token
from .exceptions import (
    NovelBuilderException,
    handle_exception,
)
from .logging_config import setup_logging
from .schemas import (
    Chapter,
    ChapterContent,
    EnhancedSceneIllustrationRequest,
    ImageToVideoRequest,
    ImageToVideoResponse,
    ModelsResponse,
    Novel,
    NovelWithChapters,
    RoleCardGenerateRequest,
    RoleCardTaskStatusResponse,
    RoleGalleryResponse,
    RoleImageDeleteRequest,
    RoleRegenerateRequest,
    SceneIllustrationResponse,
    SceneGalleryResponse,
    SceneImageDeleteRequest,
    SceneRegenerateRequest,
    SceneRegenerateResponse,
    SourceSite,
    VideoStatusResponse,
    WorkflowInfo,
)
from .services.crawler_factory import (
    SOURCE_SITES_METADATA,
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
from .api.routes.backup import router as backup_router
from .api.routes.logs import router as logs_router

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

# CORS配置 - 使用环境变量控制允许的源
allowed_origins = settings.cors_origins.split(",") if settings.cors_origins else []
if settings.debug and not allowed_origins:
    # 开发环境默认允许本地访问
    allowed_origins = ["http://localhost:3154", "http://127.0.0.1:3154"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],  # 限制HTTP方法
    allow_headers=["*"],
)

# 注册API路由
app.include_router(backup_router)
app.include_router(logs_router)


# 应用启动事件
@app.on_event("startup")
async def startup_event() -> None:
    # 初始化日志系统
    logger = setup_logging()

    # 初始化数据库
    init_db()

    logger.info("Novel Builder Backend 启动完成")
    logger.info(f"启用的爬虫站点: {settings.enabled_sites}")

    if settings.debug:
        logger.warning("调试模式已开启")

    if not settings.is_secure():
        logger.warning("当前配置不安全，请检查环境变量设置")


# 全局异常处理器
@app.exception_handler(NovelBuilderException)
async def novel_builder_exception_handler(request: Request, exc: NovelBuilderException):
    """处理自定义应用异常"""
    logger.error(f"应用异常: {exc.error_code} - {exc.message}")
    return JSONResponse(status_code=500, content=exc.to_dict())


@app.exception_handler(Exception)
async def general_exception_handler(
    request: Request, exc: Exception
) -> JSONResponse:
    """处理未预期的异常"""
    novel_exc = handle_exception(exc, logger)
    logger.error(f"未处理异常: {novel_exc.message}")
    return JSONResponse(status_code=500, content=novel_exc.to_dict())


def handle_service_exception(
    exc: Exception, logger: logging.Logger, operation_name: str
) -> HTTPException:
    """
    统一的服务层异常处理函数

    Args:
        exc: 捕获的异常
        logger: 日志记录器
        operation_name: 操作名称（用于日志）

    Returns:
        HTTPException: 格式化的HTTP异常
    """
    expected_types = (ValueError, SQLAlchemyError)
    if isinstance(exc, expected_types):
        logger.warning(f"{operation_name}参数错误: {exc}")
        return HTTPException(status_code=400, detail=str(exc))

    logger.error(f"{operation_name}失败: {exc}")
    return HTTPException(status_code=500, detail=f"{operation_name}失败")


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/security-check")
def security_check() -> dict[str, Any]:
    """安全配置检查端点，仅在开发环境可用"""
    if not settings.debug:
        raise HTTPException(status_code=404, detail="Not found")

    return {
        "is_secure": settings.is_secure(),
        "has_api_token": bool(settings.api_token),
        "has_custom_secret_key": settings.secret_key != secrets.token_urlsafe(32),
        "is_debug_mode": settings.debug,
        "cors_origins": settings.cors_origins.split(",")
        if settings.cors_origins
        else [],
        "warnings": [
            "DEBUG模式已启用" if settings.debug else None,
            "未设置API_TOKEN" if not settings.api_token else None,
            "使用默认SECRET_KEY"
            if settings.secret_key == "your-secret-key-here"
            else None,
            "CORS设置为允许所有源" if "*" in (settings.cors_origins or "") else None,
        ],
    }


@app.get(
    "/source-sites",
    response_model=list[SourceSite],
    dependencies=[Depends(verify_token)],
)
async def get_source_sites() -> list[dict[str, Any]]:
    """获取所有源站列表"""
    return get_source_sites_info()


@app.get("/search", response_model=list[Novel], dependencies=[Depends(verify_token)])
async def search(
    keyword: str = Query(..., min_length=1, description="小说名称或作者"),
    sites: str = Query(None, description="指定搜索站点，逗号分隔，如 alice_sw,shukuge"),
) -> list[dict[str, Any]]:
    """搜索小说，支持指定站点"""
    # 获取所有启用的站点
    all_crawlers = get_enabled_crawlers()

    # 过滤出搜索功能启用的站点
    searchable_crawlers = {
        site_id: crawler
        for site_id, crawler in all_crawlers.items()
        if SOURCE_SITES_METADATA.get(site_id, {}).get("search_enabled", False)
    }

    if sites:
        # 解析指定站点，只使用指定的爬虫
        site_list = [s.strip() for s in sites.split(",")]
        crawlers = {
            site: crawler
            for site, crawler in searchable_crawlers.items()
            if site in site_list
        }
        if not crawlers:
            raise HTTPException(status_code=400, detail="指定的站点无效或未启用搜索功能")
    else:
        # 使用所有搜索功能启用的站点
        crawlers = searchable_crawlers

    service = SearchService(list(crawlers.values()))
    results = await service.search(keyword, crawlers)
    return results


@app.get(
    "/chapters", response_model=list[Chapter], dependencies=[Depends(verify_token)]
)
async def chapters(
    url: str = Query(..., description="小说详情页或阅读页URL"),
    force_refresh: bool = Query(False, description="强制刷新，从源站重新获取"),
) -> list[dict[str, Any]]:
    """
    获取章节列表

    - **url**: 小说详情页或阅读页URL
    - **force_refresh**: 是否强制刷新（默认 False）
      - False: 优先从缓存获取，缓存不存在时从源站抓取
      - True: 强制从源站重新获取
    """
    # 获取爬虫并调用（缓存由装饰器自动处理）
    crawler = get_crawler_for_url(url)
    if not crawler:
        raise HTTPException(status_code=400, detail="不支持该URL的站点")

    # 调用爬虫方法，缓存装饰器会自动处理缓存逻辑
    chapters = await crawler.get_chapter_list(url, force_refresh=force_refresh)
    return chapters


@app.get(
    "/novel-by-url", response_model=NovelWithChapters, dependencies=[Depends(verify_token)]
)
async def novel_by_url(
    url: str = Query(..., description="小说详情页URL"),
) -> dict[str, Any]:
    """
    通过URL获取小说信息和章节列表

    - **url**: 小说详情页URL

    返回小说的完整信息，包括：
    - novel: 小说基本信息（标题、作者、封面、简介）
    - chapters: 章节列表（缓存由装饰器自动处理）
    """
    crawler = get_crawler_for_url(url)
    if not crawler:
        raise HTTPException(status_code=400, detail="不支持该URL的站点")

    # 调用爬虫的 get_novel_info 方法（内部会调用 get_chapter_list，缓存由装饰器自动处理）
    novel_info = await crawler.get_novel_info(url)
    chapters = novel_info.get("chapters", [])

    # 清理标题中的冗余信息
    title = novel_info.get("title", "")
    if " - " in title:
        title = title.split(" - ")[0]

    # 构建 Novel 对象
    novel_data = {
        "title": title,
        "author": novel_info.get("author", "未知作者"),
        "url": url,
    }

    # 返回结果
    return {
        "novel": novel_data,
        "chapters": chapters,
    }


@app.get(
    "/chapter-content",
    response_model=ChapterContent,
    dependencies=[Depends(verify_token)],
)
async def chapter_content(
    url: str = Query(..., description="章节URL"),
    force_refresh: bool = Query(False, description="强制刷新，从源站重新获取"),
) -> dict[str, Any]:
    """
    获取章节内容

    - **url**: 章节URL
    - **force_refresh**: 是否强制刷新（默认 False）
      - False: 优先从缓存获取，缓存不存在时从源站抓取
      - True: 强制从源站重新获取（用于更新内容）
    """
    # 获取爬虫并调用（缓存由装饰器自动处理）
    crawler = get_crawler_for_url(url)
    if not crawler:
        raise HTTPException(status_code=400, detail="不支持该URL的站点")

    # 调用爬虫方法，缓存装饰器会自动处理缓存逻辑
    content_data = await crawler.get_chapter_content(url, force_refresh=force_refresh)

    return {
        "title": content_data.get("title", "章节内容"),
        "content": content_data.get("content", ""),
        "from_cache": content_data.get("from_cache", False),
    }


@app.get(
    "/text2img/image/{filename}",
    response_class=Response,
    responses={
        200: {
            "content": {
                "image/png": {"schema": {"type": "string", "format": "binary"}}
            },
            "description": "成功返回图片二进制数据 (PNG格式)",
        },
        404: {"description": "图片文件不存在"},
    },
)
async def get_image_proxy(filename: str):
    """
    图片代理接口 - 从ComfyUI获取图片并转发给用户

    返回图片二进制数据 (PNG格式)

    - **filename**: 图片文件名
    - **返回**: 图片二进制数据 (Content-Type: image/png)
    """
    import re

    import requests

    try:
        # 安全验证：防止路径遍历攻击
        # 只允许字母、数字、下划线、连字符、点和扩展名分隔符
        if not re.match(r"^[a-zA-Z0-9_\-\.]+\.(png|jpg|jpeg|gif|webp)$", filename):
            raise HTTPException(status_code=400, detail="无效的文件名格式")

        # 额外检查：防止路径遍历
        if ".." in filename or "/" in filename or "\\" in filename:
            raise HTTPException(status_code=400, detail="文件名包含非法字符")

        # 直接从ComfyUI获取图片
        comfyui_url = settings.comfyui_api_url
        image_url = f"{comfyui_url}/view?filename={filename}"

        response = requests.get(image_url, timeout=None)
        if response.status_code == 200:
            return Response(
                content=response.content,
                media_type="image/png",
                headers={
                    "Cache-Control": f"public, max-age={CACHE_ONE_DAY}",  # 缓存1天
                    "X-Content-Type-Options": "nosniff",
                },
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
        comfyui_url = settings.comfyui_api_url
        response = requests.get(f"{comfyui_url}/system_stats", timeout=TIMEOUT_FAST)

        if response.status_code == 200:
            return {
                "status": "healthy",
                "message": "ComfyUI服务正常",
                "services": {"comfyui": True, "api_accessible": True},
            }
        else:
            return {
                "status": "unhealthy",
                "message": f"ComfyUI服务响应异常: {response.status_code}",
                "services": {"comfyui": False, "api_accessible": False},
            }
    except requests.RequestException as e:
        return {
            "status": "unhealthy",
            "message": f"无法连接ComfyUI服务: {e!s}",
            "services": {"comfyui": False, "api_accessible": False},
        }


# ================= 人物卡图片生成 API =================


@app.post("/api/role-card/generate", dependencies=[Depends(verify_token)])
async def generate_role_card_images(
    request: RoleCardGenerateRequest, db: Session = Depends(get_db)
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
        return await role_card_async_service.create_task(request, db)
    except Exception as e:
        raise handle_service_exception(e, logger, "创建人物卡生成任务")


@app.get(
    "/api/role-card/status/{task_id}",
    response_model=RoleCardTaskStatusResponse,
    dependencies=[Depends(verify_token)],
)
async def get_role_card_task_status(
    task_id: int, db: Session = Depends(get_db)
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
    except HTTPException:
        raise
    except Exception as e:
        raise handle_service_exception(e, logger, "查询任务状态")


@app.get(
    "/api/role-card/gallery/{role_id}",
    response_model=RoleGalleryResponse,
    dependencies=[Depends(verify_token)],
)
async def get_role_card_gallery(
    role_id: str, db: Session = Depends(get_db)
):
    """
    查看角色图集

    - **role_id**: 人物卡ID
    """
    try:
        return await role_card_service.get_role_gallery(role_id, db)
    except Exception as e:
        raise handle_service_exception(e, logger, "获取角色图集")


@app.delete("/api/role-card/image", dependencies=[Depends(verify_token)])
async def delete_role_card_image(
    request: RoleImageDeleteRequest, db: Session = Depends(get_db)
):
    """
    从角色图集中删除图片

    - **role_id**: 人物卡ID
    - **img_url**: 要删除的图片URL
    """
    try:
        success = await role_card_service.delete_role_image(request, db)
        if not success:
            raise HTTPException(status_code=404, detail="图片不存在")
        return {"message": "图片删除成功"}
    except HTTPException:
        raise
    except Exception as e:
        raise handle_service_exception(e, logger, "删除角色图片")


@app.post("/api/role-card/regenerate", dependencies=[Depends(verify_token)])
async def regenerate_similar_images(
    request: RoleRegenerateRequest, db: Session = Depends(get_db)
):
    """
    重新生成相似图片

    - **img_url**: 参考图片URL
    - **count**: 生成图片数量
    - **model_name**: 指定使用的模型名称（可选，不填则使用默认模型，向后兼容model参数）
    """
    try:
        return await role_card_service.regenerate_similar_images(
            request, db, model=request.model
        )
    except Exception as e:
        raise handle_service_exception(e, logger, "重新生成相似图片")


@app.get("/api/models", dependencies=[Depends(verify_token)])
async def get_models() -> ModelsResponse:
    """获取所有可用模型，按文生图和图生视频分类"""
    try:
        from app.workflow_config import WorkflowType, workflow_config_manager

        default_t2i_workflow = workflow_config_manager.get_default_workflow(
            WorkflowType.T2I
        )
        default_t2i_title = default_t2i_workflow.title

        t2i_response = workflow_config_manager.list_workflows(WorkflowType.T2I)
        text2img_models = [
            WorkflowInfo(
                title=workflow.title,
                description=workflow.description,
                path=workflow.path,
                width=workflow.width,
                height=workflow.height,
                is_default=(workflow.title == default_t2i_title),
            )
            for workflow in t2i_response.workflows
        ]

        i2v_response = workflow_config_manager.list_workflows(WorkflowType.I2V)
        img2video_models = [
            WorkflowInfo(
                title=workflow.title,
                description=workflow.description,
                path=workflow.path,
            )
            for workflow in i2v_response.workflows
        ]

        return ModelsResponse(text2img=text2img_models, img2video=img2video_models)
    except Exception as e:
        raise handle_service_exception(e, logger, "获取模型列表")


@app.get("/api/role-card/health", dependencies=[Depends(verify_token)])
async def role_card_health_check():
    """检查人物卡服务健康状态"""
    try:
        health_status = await role_card_service.health_check()
        overall_healthy = all(health_status.values())

        return {
            "status": "healthy" if overall_healthy else "unhealthy",
            "services": health_status,
        }
    except Exception as e:
        logger.error(f"人物卡健康检查失败: {e}")
        return {"status": "error", "message": str(e), "services": {}}


# ================= 场面绘制 API =================


@app.post(
    "/api/scene-illustration/generate",
    response_model=SceneIllustrationResponse,
    dependencies=[Depends(verify_token)],
)
async def generate_scene_images(
    request: EnhancedSceneIllustrationRequest, db: Session = Depends(get_db)
):
    """
    生成场面绘制图片

    - **chapters_content**: 章节内容
    - **task_id**: 任务标识符
    - **roles**: 角色信息
    - **num**: 生成图片数量
    - **model_name**: 指定使用的模型名称（可选，不填则使用默认模型）

    返回任务ID，可通过后续接口查询和获取图片
    """
    try:
        return await scene_illustration_service.generate_scene_images(request, db)
    except Exception as e:
        raise handle_service_exception(e, logger, "创建场面绘制任务")


@app.get(
    "/api/scene-illustration/gallery/{task_id}",
    response_model=SceneGalleryResponse,
    dependencies=[Depends(verify_token)],
)
async def get_scene_gallery(
    task_id: str, db: Session = Depends(get_db)
):
    """
    查看场面绘制图片列表

    - **task_id**: 场面绘制任务ID
    """
    try:
        return await scene_illustration_service.get_scene_gallery(task_id, db)
    except HTTPException:
        raise
    except Exception as e:
        raise handle_service_exception(e, logger, "获取场面图集")


@app.delete("/api/scene-illustration/image", dependencies=[Depends(verify_token)])
async def delete_scene_image(
    request: SceneImageDeleteRequest, db: Session = Depends(get_db)
):
    """
    从场面绘制结果中删除图片

    - **task_id**: 场面绘制任务ID
    - **filename**: 要删除的图片文件名
    """
    try:
        success = await scene_illustration_service.delete_scene_image(request, db)
        if not success:
            raise HTTPException(status_code=404, detail="图片不存在")
        return {"message": "图片删除成功"}
    except HTTPException:
        raise
    except Exception as e:
        raise handle_service_exception(e, logger, "删除场面图片")


@app.post(
    "/api/scene-illustration/regenerate",
    response_model=SceneRegenerateResponse,
    dependencies=[Depends(verify_token)],
)
async def regenerate_scene_images(
    request: SceneRegenerateRequest, db: Session = Depends(get_db)
):
    """
    基于现有任务重新生成场面图片

    - **task_id**: 原始任务ID
    - **count**: 生成图片数量
    - **model_name**: 指定使用的模型名称（可选，不填则使用默认模型，向后兼容model参数）
    """
    try:
        return await scene_illustration_service.regenerate_scene_images(request, db)
    except Exception as e:
        raise handle_service_exception(e, logger, "重新生成场面图片")


# ================= 图生视频 API =================


@app.post(
    "/api/image-to-video/generate",
    response_model=ImageToVideoResponse,
    dependencies=[Depends(verify_token)],
)
async def generate_video_from_image(
    request: ImageToVideoRequest, db: Session = Depends(get_db)
):
    """
    生成图生视频

    创建一个图生视频任务，将指定的图片转换为动态视频。

    **请求参数:**
    - **img_name**: 要处理的图片文件名称
    - **user_input**: 用户对视频生成的要求描述
    - **model_name**: 图生视频模型名称（可选，不填则使用默认模型）

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
    使用返回的 task_id 轮询 `/api/image-to-video/has-video/{img_name}` 查询视频是否生成完成
    """
    try:
        return await image_to_video_service.create_video_generation_task(request, db)
    except Exception as e:
        raise handle_service_exception(e, logger, "创建图生视频任务")


@app.get(
    "/api/image-to-video/has-video/{img_name}",
    response_model=VideoStatusResponse,
    dependencies=[Depends(verify_token)],
)
async def check_video_status(
    img_name: str, db: Session = Depends(get_db)
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
        return await image_to_video_service.get_video_status(img_name, db)
    except Exception as e:
        raise handle_service_exception(e, logger, "检查视频状态")


@app.get(
    "/api/image-to-video/video/{img_name}",
    response_class=Response,
    responses={
        200: {
            "content": {
                "video/mp4": {"schema": {"type": "string", "format": "binary"}}
            },
            "description": "成功返回视频二进制数据 (MP4格式)",
        },
        404: {"description": "视频文件不存在"},
    },
)
async def get_video_file(
    img_name: str, db: Session = Depends(get_db)
):
    """
    获取视频文件

    返回视频二进制数据 (MP4格式)

    - **img_name**: 图片名称
    - **返回**: 视频二进制数据 (Content-Type: video/mp4)
    """
    try:
        video_data = await image_to_video_service.get_video_file(img_name, db)
        if not video_data:
            raise HTTPException(status_code=404, detail="视频文件不存在")

        return Response(
            content=video_data,
            media_type="video/mp4",
            headers={
                "Cache-Control": f"public, max-age={CACHE_ONE_HOUR}",
                "X-Content-Type-Options": "nosniff",
            },
        )
    except HTTPException:
        raise
    except Exception as e:
        raise handle_service_exception(e, logger, "获取视频文件")


# ================= 缓存管理 API =================


# ================= APP版本管理 API 已废弃 =================
# 版本更新已迁移到 GitHub Releases：
# https://github.com/yunkst/novel_builder/releases
# 应用内通过 GitHub Releases API 检测更新（lib/services/github_release_service.dart）


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
            "APP版本管理和升级",
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
            "POST /api/app-version/upload - 上传APP新版本",
            "GET /api/app-version/latest - 查询最新版本",
            "GET /api/app-version/download/{version} - 下载APK文件",
        ],
        "supported_sites": [
            "alice_sw - 轻小说文库",
            "shukuge - 书库",
            "xspsw - 小说网",
            "wdscw - 我的书城",
            "wodeshucheng - 我的书城(wodeshucheng)",
        ],
    }
