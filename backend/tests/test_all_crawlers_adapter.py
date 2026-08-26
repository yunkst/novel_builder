#!/usr/bin/env python3
"""
快速验证：修复后的爬虫适配层测试
"""

import asyncio
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app.services.shukuge_crawler_refactored import ShukugeCrawlerRefactored
from app.services.wodeshucheng_crawler import WodeshuchengCrawler
from app.services.alice_sw_crawler_refactored import AliceSWCrawlerRefactored


async def test_crawler_compatibility():
    """测试爬虫与适配层的兼容性"""
    print("=" * 70)
    print("爬虫适配层兼容性测试")
    print("=" * 70)

    crawlers = [
        ("ShukugeCrawlerRefactored", ShukugeCrawlerRefactored()),
        ("WodeshuchengCrawler", WodeshuchengCrawler()),
        ("AliceSWCrawlerRefactored", AliceSWCrawlerRefactored()),
    ]

    keyword = "斗破"

    for crawler_name, crawler in crawlers:
        print(f"\n测试 {crawler_name}:")
        print("-" * 70)

        try:
            results = await crawler.search_novels(keyword)
            if results:
                print(f"✅ 搜索成功! 找到 {len(results)} 个结果")
                print(f"   示例: {results[0]['title']} - {results[0]['author']}")

                # 测试获取章节列表
                if results and 'url' in results[0]:
                    chapters = await crawler.get_chapter_list(results[0]['url'])
                    if chapters:
                        print(f"✅ 章节列表获取成功! 共 {len(chapters)} 章")
                    else:
                        print("⚠️  章节列表为空或获取失败")
            else:
                print("⚠️  搜索结果为空")
        except Exception as e:
            print(f"❌ 测试失败: {e}")
            # 继续测试下一个爬虫
            continue

    print("\n" + "=" * 70)
    print("✅ 兼容性测试完成!")
    print("=" * 70)


if __name__ == "__main__":
    asyncio.run(test_crawler_compatibility())
