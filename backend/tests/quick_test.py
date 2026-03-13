#!/usr/bin/env python3
"""
快速测试脚本 - 验证爬虫系统基本功能

在 Docker 环境中运行此脚本来验证重构后的爬虫系统。
"""

import asyncio
import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.crawler_factory import get_enabled_crawlers


async def quick_test():
    """快速测试所有爬虫的导入和初始化"""
    print("=" * 50)
    print("爬虫系统快速测试")
    print("=" * 50)

    try:
        # 获取所有启用的爬虫
        crawlers = get_enabled_crawlers()
        print(f"\n✓ 成功加载 {len(crawlers)} 个爬虫:")

        for site_id, crawler in crawlers.items():
            # 检查爬虫是否有必要的方法
            has_search = hasattr(crawler, "search_novels")
            has_chapters = hasattr(crawler, "get_chapter_list")
            has_content = hasattr(crawler, "get_chapter_content")

            status = "✓" if (has_search and has_chapters and has_content) else "✗"
            print(f"  {status} {site_id}: {crawler.__class__.__name__}")

        print("\n✓ 所有爬虫导入成功!")

        # 测试 SmxkuCrawler 的搜索功能（作为参考）
        if "smxku" in crawlers:
            print("\n测试 SmxkuCrawler 搜索功能...")
            crawler = crawlers["smxku"]
            try:
                results = await crawler.search_novels("仙侠")
                print(f"✓ 搜索返回 {len(results)} 个结果")
                if results:
                    print(f"  示例: {results[0].get('title', 'N/A')}")
            except Exception as e:
                print(f"✗ 搜索失败: {str(e)[:100]}")

        print("\n" + "=" * 50)
        print("测试完成!")
        print("=" * 50)

    except Exception as e:
        print(f"\n✗ 测试失败: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(quick_test())
