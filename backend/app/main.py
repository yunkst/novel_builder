#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from fastapi import FastAPI, Depends, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from .config import settings
from .deps.auth import verify_token
from .schemas import Novel, Chapter, ChapterContent
from .services.search_service import SearchService
from .services.crawler_factory import get_enabled_crawlers, get_crawler_for_url

app = FastAPI(title="Novel Builder Backend", version="0.1.0")

# CORS（允许前端在局域网访问）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 如需更严格控制，可改为具体前端地址
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.get("/search", response_model=list[Novel], dependencies=[Depends(verify_token)])
def search(keyword: str = Query(..., min_length=1, description="小说名称或作者")):
    service = SearchService(get_enabled_crawlers())
    results = service.search(keyword)
    return results


@app.get("/chapters", response_model=list[Chapter], dependencies=[Depends(verify_token)])
def chapters(url: str = Query(..., description="小说详情页或阅读页URL")):
    crawler = get_crawler_for_url(url)
    if not crawler:
        raise HTTPException(status_code=400, detail="不支持该URL的站点")
    chapters = crawler.get_chapter_list(url)
    return chapters


@app.get("/chapter-content", response_model=ChapterContent, dependencies=[Depends(verify_token)])
def chapter_content(url: str = Query(..., description="章节URL")):
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
        "docs": "/docs",
        "token_required": True,
        "token_header": settings.token_header,
    }