#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from fastapi import FastAPI, Depends, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from .config import settings
from .deps.auth import verify_token
from .schemas import Novel, Chapter, ChapterContent
from .services.search_service import SearchService
from .services.crawler_factory import get_enabled_crawlers, get_crawler_for_url

app = FastAPI(
    title="Novel Builder Backend",
    version="0.2.0",
    description="FastAPI backend for novel crawling and management"
)

# CORS（允许前端在局域网访问）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 如需更严格控制，可改为具体前端地址
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)


# 应用启动事件
@app.on_event("startup")
async def startup_event():
    print("✓ Novel Builder Backend 启动完成")
    print(f"✓ 启用的爬虫站点: {settings.enabled_sites}")
    if settings.debug:
        print("✓ 调试模式已开启")


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.get("/search", response_model=list[Novel], dependencies=[Depends(verify_token)])
async def search(keyword: str = Query(..., min_length=1, description="小说名称或作者")):
    service = SearchService(get_enabled_crawlers())
    results = await service.search(keyword, get_enabled_crawlers())
    return results


@app.get("/chapters", response_model=list[Chapter], dependencies=[Depends(verify_token)])
def chapters(url: str = Query(..., description="小说详情页或阅读页URL")):
    crawler = get_crawler_for_url(url)
    if not crawler:
        raise HTTPException(status_code=400, detail="不支持该URL的站点")
    chapters = crawler.get_chapter_list(url)
    return chapters


@app.get("/chapter-content", response_model=ChapterContent, dependencies=[Depends(verify_token)])
def chapter_content(
    url: str = Query(..., description="章节URL"),
    force_refresh: bool = Query(False, description="强制刷新，从源站重新获取"),
):
    """
    获取章节内容

    - **url**: 章节URL
    - **force_refresh**: 是否强制刷新（默认 False）
      - False: 直接从源站获取
      - True: 从源站重新获取（用于更新内容）
    """
    # 从源站获取内容
    crawler = get_crawler_for_url(url)
    if not crawler:
        raise HTTPException(status_code=400, detail="不支持该URL的站点")

    content = crawler.get_chapter_content(url)
    return content


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
            "章节列表获取",
            "章节内容获取",
            "实时内容抓取"
        ]
    }