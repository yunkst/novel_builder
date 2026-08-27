#!/usr/bin/env python3
"""在容器中直接测试twxs爬虫"""
import sys
sys.path.insert(0, '/app')

from app.services.crawler_factory import get_enabled_crawlers
import asyncio

async def main():
    # 获取所有启用的爬虫
    crawlers = get_enabled_crawlers()
    print(f"启用的站点: {list(crawlers.keys())}")

    # 手动创建twxs爬虫
    from app.services.twxs_crawler import TwxsCrawler
    crawler = TwxsCrawler()

    # 测试搜索
    print("\n测试搜索...")
    results = await crawler.search_novels("修仙")
    print(f"搜索结果: {len(results)}个")
    for r in results[:3]:
        print(f"  - {r['title']} - {r['author']}")

if __name__ == "__main__":
    asyncio.run(main())
