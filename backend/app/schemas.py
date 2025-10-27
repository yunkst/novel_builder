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
