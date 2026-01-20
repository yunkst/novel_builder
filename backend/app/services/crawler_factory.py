#!/usr/bin/env python3

import os

from ..config import settings

# 导入爬虫
from .alice_sw_crawler_refactored import AliceSWCrawlerRefactored
from .base_crawler import BaseCrawler
from .shukuge_crawler_refactored import ShukugeCrawlerRefactored
from .smxku_crawler import SmxkuCrawler
from .wdscw_crawler_refactored import WdscwCrawlerRefactored
from .wfxs_crawler import WfxsCrawler
from .wodeshucheng_crawler import WodeshuchengCrawler
from .xspsw_crawler_refactored import XspswCrawlerRefactored

# 为了向后兼容，创建别名
AliceSWCrawler = AliceSWCrawlerRefactored
ShukugeCrawler = ShukugeCrawlerRefactored
XspswCrawler = XspswCrawlerRefactored
WdscwCrawler = WdscwCrawlerRefactored
WodeshuchengCrawler = WodeshuchengCrawler
SmxkuCrawler = SmxkuCrawler
WfxsCrawler = WfxsCrawler

# 源站元数据配置
SOURCE_SITES_METADATA = {
    "alice_sw": {
        "name": "轻小说文库",
        "base_url": "https://www.alicesw.com",
        "description": "专业的轻小说网站，包含大量日系轻小说",
        "search_enabled": True,
        "crawler_class": AliceSWCrawlerRefactored,  # 使用重构版
    },
    "shukuge": {
        "name": "书库",
        "base_url": "http://www.shukuge.com",
        "description": "综合性小说书库，资源丰富",
        "search_enabled": True,
        "crawler_class": ShukugeCrawlerRefactored,  # 使用重构版
    },
    "xspsw": {
        "name": "小说网",
        "base_url": "https://m.xspsw.com",
        "description": "移动端优化的小说网站",
        "search_enabled": True,
        "crawler_class": XspswCrawlerRefactored,  # 使用重构版
    },
    "wdscw": {
        "name": "我的书城",
        "base_url": "https://www.5dscw.com",
        "description": "精品小说免费阅读网站，包含玄幻、奇幻、武侠等多种类型小说",
        "search_enabled": True,
        "crawler_class": WdscwCrawlerRefactored,  # 使用重构版
    },
    "wodeshucheng": {
        "name": "我的书城(wodeshucheng)",
        "base_url": "https://www.wodeshucheng.net",
        "description": "综合性小说阅读网站，提供多种类型小说的在线阅读",
        "search_enabled": True,
        "crawler_class": WodeshuchengCrawler,
    },
    "smxku": {
        "name": "蜘蛛小说网",
        "base_url": "https://www.smxku.com",
        "description": "海量小说免费在线阅读，包含玄幻、都市、言情等多种类型",
        "search_enabled": True,
        "crawler_class": SmxkuCrawler,
    },
    "wfxs": {
        "name": "微风小说网",
        "base_url": "https://m.wfxs.tw",
        "description": "繁体中文小说网站，支持玄幻、都市、言情等多种类型，自动转换为简体",
        "search_enabled": True,
        "crawler_class": WfxsCrawler,
    },
}


def get_enabled_crawlers() -> dict[str, BaseCrawler]:
    """
    根据环境变量 NOVEL_ENABLED_SITES 启用站点；未设置时默认全部启用。
    示例：NOVEL_ENABLED_SITES="alice,shukuge,xspsw,wdscw"

    Returns:
        Dict mapping site names to crawler instances
    """
    enabled = settings.enabled_sites.lower()
    crawlers: dict[str, BaseCrawler] = {}
    if not enabled or "alice" in enabled or "alice_sw" in enabled:
        crawlers["alice_sw"] = AliceSWCrawler()
    if not enabled or "shukuge" in enabled:
        crawlers["shukuge"] = ShukugeCrawler()
    if not enabled or "xspsw" in enabled:
        crawlers["xspsw"] = XspswCrawler()
    if not enabled or "5dscw" in enabled or "wdscw" in enabled:
        crawlers["wdscw"] = WdscwCrawler()
    if not enabled or "wodeshucheng" in enabled:
        crawlers["wodeshucheng"] = WodeshuchengCrawler()
    if not enabled or "smxku" in enabled:
        crawlers["smxku"] = SmxkuCrawler()
    if not enabled or "wfxs" in enabled:
        crawlers["wfxs"] = WfxsCrawler()
    return crawlers


def get_crawler_for_url(url: str) -> BaseCrawler | None:
    """根据 URL 判断使用哪个爬虫。"""
    if "alicesw.com" in url:
        return AliceSWCrawlerRefactored()
    if "shukuge.com" in url:
        return ShukugeCrawlerRefactored()
    if "m.xspsw.com" in url:
        return XspswCrawlerRefactored()
    if "5dscw.com" in url:
        return WdscwCrawlerRefactored()
    if "wodeshucheng.net" in url:
        return WodeshuchengCrawler()
    if "smxku.com" in url:
        return SmxkuCrawler()
    if "wfxs.tw" in url:
        return WfxsCrawler()
    # 兜底：尝试匹配 base_url
    for crawler in get_enabled_crawlers().values():
        if hasattr(crawler, "base_url") and crawler.base_url in url:
            return crawler
    return None


def get_source_sites_info() -> list[dict]:
    """获取所有源站信息，包括启用的和未启用的"""
    enabled = settings.enabled_sites.lower()

    sites = []
    for site_id, metadata in SOURCE_SITES_METADATA.items():
        # 根据环境变量判断站点是否启用
        site_key = site_id.replace("_sw", "").replace("_", "")
        is_enabled = not enabled or site_key in enabled

        sites.append(
            {
                "id": site_id,
                "name": metadata["name"],
                "base_url": metadata["base_url"],
                "description": metadata["description"],
                "enabled": is_enabled,
                "search_enabled": metadata["search_enabled"],
            }
        )

    return sites
