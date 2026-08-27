#!/usr/bin/env python3
"""
测试适配层在实际爬虫中的应用
"""

import asyncio
import sys
import os

# 添加项目路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app.services.shukuge_crawler_refactored import ShukugeCrawlerRefactored


async def test_crawler_with_adapter():
    """测试爬虫使用适配层"""
    print("测试 ShukugeCrawlerRefactored 与适配层的兼容性")

    crawler = ShukugeCrawlerRefactored()

    print("\n1. 测试搜索功能...")
    try:
        results = await crawler.search_novels("斗破苍穹")
        print(f"   找到 {len(results)} 个结果")
        for i, novel in enumerate(results[:3], 1):
            print(f"   {i}. {novel['title']} - {novel['author']}")
    except Exception as e:
        print(f"   搜索失败: {e}")
        import traceback
        traceback.print_exc()

    if results:
        print("\n2. 测试获取章节列表...")
        try:
            novel_url = results[0]['url']
            chapters = await crawler.get_chapter_list(novel_url)
            print(f"   找到 {len(chapters)} 个章节")
            if chapters:
                print(f"   第一章: {chapters[0]['title']}")
        except Exception as e:
            print(f"   获取章节失败: {e}")
            import traceback
            traceback.print_exc()

    print("\n✅ 测试完成")


if __name__ == "__main__":
    asyncio.run(test_crawler_with_adapter())
