#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from typing import List, Dict

from .base_crawler import BaseCrawler


class SearchService:
    def __init__(self, crawlers: List[BaseCrawler]):
        self.crawlers = crawlers

    def search(self, keyword: str) -> List[Dict]:
        results: List[Dict] = []
        for crawler in self.crawlers:
            try:
                items = crawler.search_novels(keyword)
                if items:
                    results.extend(items)
            except Exception:
                # 某个站点异常不影响整体搜索
                continue

        # 去重并标准化输出
        seen = set()
        unique: List[Dict] = []
        for n in results:
            title = n.get("title")
            url = n.get("url")
            author = n.get("author") or "未知"
            key = (title, url)
            if title and url and key not in seen:
                unique.append({"title": title, "author": author, "url": url})
                seen.add(key)
        return unique