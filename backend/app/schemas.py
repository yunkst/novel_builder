#!/usr/bin/env python3
"""
Pydantic schemas for API request/response models.

This module contains data models used throughout the application
for request validation and response serialization.
"""

from pydantic import BaseModel


class Novel(BaseModel):
    """Novel metadata schema."""

    title: str
    author: str
    url: str


class Chapter(BaseModel):
    """Chapter metadata schema."""

    title: str
    url: str


class ChapterContent(BaseModel):
    """Chapter content schema."""

    title: str
    content: str
    from_cache: bool = False


class SourceSite(BaseModel):
    """Source site information schema."""

    id: str              # 站点标识 (alice_sw, shukuge, xspsw)
    name: str            # 站点名称
    base_url: str        # 站点基础URL
    description: str     # 站点描述
    enabled: bool        # 是否启用
    search_enabled: bool # 是否支持搜索功能
