#!/usr/bin/env python3

import os

from ..config import settings

# 导入爬虫
from .alice_sw_crawler_refactored import AliceSWCrawlerRefactored
from .base_crawler import BaseCrawler
from .biquge543_crawler import Biquge543Crawler
from .ddxsmf_crawler import DdxsmfCrawler
from .shukuge_crawler_refactored import ShukugeCrawlerRefactored
from .shuhaoxs_crawler import ShuhaoxsCrawler
from .smxku_crawler import SmxkuCrawler
from .wdscw_crawler_refactored import WdscwCrawlerRefactored
from .wfxs_crawler import WfxsCrawler
from .wodeshucheng_crawler import WodeshuchengCrawler
from .xspsw_crawler_refactored import XspswCrawlerRefactored
from .xqishen_crawler import XqishenCrawler

# 为了向后兼容，创建别名
AliceSWCrawler = AliceSWCrawlerRefactored
Biquge543Crawler = Biquge543Crawler
DdxsmfCrawler = DdxsmfCrawler
ShukugeCrawler = ShukugeCrawlerRefactored
ShuhaoxsCrawlerRefactored = ShuhaoxsCrawler
XspswCrawler = XspswCrawlerRefactored
WdscwCrawler = WdscwCrawlerRefactored
WodeshuchengCrawler = WodeshuchengCrawler
SmxkuCrawler = SmxkuCrawler
WfxsCrawler = WfxsCrawler
XqishenCrawler = XqishenCrawler

# 源站元数据配置
SOURCE_SITES_METADATA = {
    "alice_sw": {
        "name": "轻小说文库",
        "base_url": "https://www.alicesw.com",
        "description": "专业的轻小说网站，包含大量日系轻小说",
        "search_enabled": True,
        "search_reason": None,
        "search_hint": None,
        "crawler_class": AliceSWCrawlerRefactored,  # 使用重构版
    },
    "ddxsmf": {
        "name": "顶点小说",
        "base_url": "https://www.ddxsmf.com",
        "description": "中文免费小说阅读网，提供玄幻、修真、都市、穿越等多种类型小说",
        "search_enabled": False,
        "search_reason": "external_search",
        "search_hint": "请使用外部搜索引擎搜索 'site:ddxsmf.com 关键词' 来查找小说",
        "crawler_class": DdxsmfCrawler,
    },
    "shukuge": {
        "name": "书库",
        "base_url": "http://www.shukuge.com",
        "description": "综合性小说书库，资源丰富",
        "search_enabled": True,
        "search_reason": None,
        "search_hint": None,
        "crawler_class": ShukugeCrawlerRefactored,  # 使用重构版
    },
    "xspsw": {
        "name": "小说网",
        "base_url": "https://m.xspsw.com",
        "description": "移动端优化的小说网站",
        "search_enabled": False,  # 2026-03-12: 网站返回HTTP 520错误，源服务器不可用
        "search_reason": "service_unavailable",
        "search_hint": "该网站服务异常，暂时不可用",
        "crawler_class": XspswCrawlerRefactored,  # 使用重构版
    },
    "wdscw": {
        "name": "我的书城",
        "base_url": "https://www.5dscw.com",
        "description": "精品小说免费阅读网站，包含玄幻、奇幻、武侠等多种类型小说",
        "search_enabled": True,
        "search_reason": None,
        "search_hint": None,
        "crawler_class": WdscwCrawlerRefactored,  # 使用重构版
    },
    "wodeshucheng": {
        "name": "我的书城(wodeshucheng)",
        "base_url": "https://www.wodeshucheng.net",
        "description": "综合性小说阅读网站，提供多种类型小说的在线阅读",
        "search_enabled": True,
        "search_reason": None,
        "search_hint": None,
        "crawler_class": WodeshuchengCrawler,
    },
    "smxku": {
        "name": "蜘蛛小说网",
        "base_url": "https://www.smxku.com",
        "description": "海量小说免费在线阅读，包含玄幻、都市、言情等多种类型（注意：该网站已实施反爬虫措施，章节列表无法获取）",
        "search_enabled": False,  # 2025-03-12: 章节列表返回403，暂禁用
        "search_reason": "anti_crawler",
        "search_hint": "该网站已实施反爬虫措施，章节列表无法获取",
        "crawler_class": SmxkuCrawler,
    },
    "wfxs": {
        "name": "微风小说网",
        "base_url": "https://m.wfxs.tw",
        "description": "繁体中文小说网站，支持玄幻、都市、言情等多种类型，自动转换为简体",
        "search_enabled": True,
        "search_reason": None,
        "search_hint": None,
        "crawler_class": WfxsCrawler,
    },
    "shuhaoxs": {
        "name": "书豪小说网",
        "base_url": "https://www.shuhaoxs.com",
        "description": "综合小说阅读网站，包含玄幻、言情、都市等多种类型小说",
        "search_enabled": True,
        "search_reason": None,
        "search_hint": None,
        "crawler_class": ShuhaoxsCrawler,
    },
    "biquge543": {
        "name": "笔趣阁543",
        "base_url": "https://m.biquge543.com",
        "description": "移动端笔趣阁站点，提供多种类型小说的在线阅读",
        "search_enabled": False,  # 搜索功能有频率限制，暂不启用
        "search_reason": "rate_limit",
        "search_hint": "该站点搜索功能有频率限制，请使用直接URL添加",
        "crawler_class": Biquge543Crawler,
    },
    "xqishen": {
        "name": "齐盛小说网",
        "base_url": "https://www.xqishen.com",
        "description": "齐盛小说网，提供都市、玄幻、仙侠等多种类型小说",
        "search_enabled": False,
        "search_reason": "no_search",
        "search_hint": "该站点不支持站内搜索，请使用直接URL添加",
        "crawler_class": XqishenCrawler,
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
    if not enabled or "ddxsmf" in enabled:
        crawlers["ddxsmf"] = DdxsmfCrawler()
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
    if not enabled or "shuhaoxs" in enabled:
        crawlers["shuhaoxs"] = ShuhaoxsCrawler()
    if not enabled or "biquge543" in enabled:
        crawlers["biquge543"] = Biquge543Crawler()
    if not enabled or "xqishen" in enabled:
        crawlers["xqishen"] = XqishenCrawler()
    return crawlers


def get_crawler_for_url(url: str) -> BaseCrawler | None:
    """根据 URL 判断使用哪个爬虫。"""
    if "alicesw.com" in url:
        return AliceSWCrawlerRefactored()
    if "ddxsmf.com" in url:
        return DdxsmfCrawler()
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
    if "shuhaoxs.com" in url:
        return ShuhaoxsCrawler()
    if "biquge543.com" in url:
        return Biquge543Crawler()
    if "xqishen.com" in url:
        return XqishenCrawler()
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
                "search_reason": metadata.get("search_reason"),
                "search_hint": metadata.get("search_hint"),
            }
        )

    return sites
