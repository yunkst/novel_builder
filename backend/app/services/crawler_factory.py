#!/usr/bin/env python3

import os

from .alice_sw_crawler import AliceSWCrawler
from .base_crawler import BaseCrawler
from .shukuge_crawler import ShukugeCrawler
from .xspsw_crawler import XspswCrawler


def get_enabled_crawlers() -> dict[str, BaseCrawler]:
    """
    根据环境变量 NOVEL_ENABLED_SITES 启用站点；未设置时默认全部启用。
    示例：NOVEL_ENABLED_SITES="alice,shukuge,xspsw"

    Returns:
        Dict mapping site names to crawler instances
    """
    enabled = os.getenv("NOVEL_ENABLED_SITES", "").lower()
    crawlers: dict[str, BaseCrawler] = {}
    if not enabled or "alice" in enabled:
        crawlers["alice_sw"] = AliceSWCrawler()
    if not enabled or "shukuge" in enabled:
        crawlers["shukuge"] = ShukugeCrawler()
    if not enabled or "xspsw" in enabled:
        crawlers["xspsw"] = XspswCrawler()
    return crawlers


def get_crawler_for_url(url: str) -> BaseCrawler | None:
    """根据 URL 判断使用哪个爬虫。"""
    if "alicesw.com" in url:
        return AliceSWCrawler()
    if "shukuge.com" in url:
        return ShukugeCrawler()
    if "m.xspsw.com" in url:
        return XspswCrawler()
    # 兜底：尝试匹配 base_url
    for crawler in get_enabled_crawlers().values():
        if hasattr(crawler, "base_url") and crawler.base_url in url:
            return crawler
    return None
