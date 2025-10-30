#!/usr/bin/env python3

import os

from .alice_sw_crawler import AliceSWCrawler
from .base_crawler import BaseCrawler
from .shukuge_crawler import ShukugeCrawler
from .xspsw_crawler import XspswCrawler

# 源站元数据配置
SOURCE_SITES_METADATA = {
    "alice_sw": {
        "name": "轻小说文库",
        "base_url": "https://www.alicesw.com",
        "description": "专业的轻小说网站，包含大量日系轻小说",
        "search_enabled": True,
        "crawler_class": AliceSWCrawler
    },
    "shukuge": {
        "name": "书库",
        "base_url": "http://www.shukuge.com",
        "description": "综合性小说书库，资源丰富",
        "search_enabled": True,
        "crawler_class": ShukugeCrawler
    },
    "xspsw": {
        "name": "小说网",
        "base_url": "https://m.xspsw.com",
        "description": "移动端优化的小说网站",
        "search_enabled": True,
        "crawler_class": XspswCrawler
    }
}


def get_enabled_crawlers() -> dict[str, BaseCrawler]:
    """
    根据环境变量 NOVEL_ENABLED_SITES 启用站点；未设置时默认全部启用。
    示例：NOVEL_ENABLED_SITES="alice,shukuge,xspsw"

    Returns:
        Dict mapping site names to crawler instances
    """
    enabled = os.getenv("NOVEL_ENABLED_SITES", "").lower()
    crawlers: dict[str, BaseCrawler] = {}
    if not enabled or "alice" in enabled or "alice_sw" in enabled:
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


def get_source_sites_info() -> list[dict]:
    """获取所有源站信息，包括启用的和未启用的"""
    enabled = os.getenv("NOVEL_ENABLED_SITES", "").lower()

    sites = []
    for site_id, metadata in SOURCE_SITES_METADATA.items():
        # 根据环境变量判断站点是否启用
        site_key = site_id.replace("_sw", "").replace("_", "")
        is_enabled = not enabled or site_key in enabled

        sites.append({
            "id": site_id,
            "name": metadata["name"],
            "base_url": metadata["base_url"],
            "description": metadata["description"],
            "enabled": is_enabled,
            "search_enabled": metadata["search_enabled"]
        })

    return sites
