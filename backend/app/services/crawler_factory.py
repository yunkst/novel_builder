#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from typing import List, Optional

from .base_crawler import BaseCrawler
from .alice_sw_crawler import AliceSWCrawler
from .shukuge_crawler import ShukugeCrawler


def get_enabled_crawlers() -> dict:
    """
    根据环境变量 NOVEL_ENABLED_SITES 启用站点；未设置时默认全部启用。
    示例：NOVEL_ENABLED_SITES="alice,shukuge"

    Returns:
        Dict mapping site names to crawler instances
    """
    enabled = os.getenv("NOVEL_ENABLED_SITES", "").lower()
    crawlers = {}
    if not enabled or "alice" in enabled:
        crawlers["alice_sw"] = AliceSWCrawler()
    if not enabled or "shukuge" in enabled or "shukuge" in enabled:
        crawlers["shukuge"] = ShukugeCrawler()
    return crawlers


def get_crawler_for_url(url: str) -> Optional[BaseCrawler]:
    """根据 URL 判断使用哪个爬虫。"""
    if "alicesw.com" in url:
        return AliceSWCrawler()
    if "shukuge.com" in url:
        return ShukugeCrawler()
    # 兜底：尝试匹配 base_url
    for c in get_enabled_crawlers():
        if getattr(c, "base_url", "") and c.base_url in url:
            return c
    return None