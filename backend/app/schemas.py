#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pydantic import BaseModel, HttpUrl


class Novel(BaseModel):
    title: str
    author: str
    url: str


class Chapter(BaseModel):
    title: str
    url: str


class ChapterContent(BaseModel):
    title: str
    content: str
    from_cache: bool = False