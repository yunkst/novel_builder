#!/usr/bin/env python3
"""
悅暢小说爬虫测试脚本
测试搜索、章节列表获取、章节内容获取功能
"""

import asyncio
import sys
from pathlib import Path

# 添加项目根目录到Python路径（支持本地和Docker环境）
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

# 根据运行环境选择导入路径
try:
    from app.services.twxs_crawler import TwxsCrawler
except ImportError:
    from backend.app.services.twxs_crawler import TwxsCrawler


async def test_search():
    """测试搜索功能"""
    print("=" * 60)
    print("测试1: 搜索功能")
    print("=" * 60)

    crawler = TwxsCrawler()

    # 测试简体关键词搜索（会自动转换为繁体）
    keyword = "修仙"
    print(f"\n搜索关键词: {keyword} (简体)")

    results = await crawler.search_novels(keyword)

    print(f"\n搜索结果数量: {len(results)}")
    print("\n前5个结果:")
    for i, novel in enumerate(results[:5], 1):
        print(f"\n{i}. {novel['title']}")
        print(f"   作者: {novel['author']}")
        print(f"   URL: {novel['url']}")

    if results:
        return results[0]['url']
    return None


async def test_chapter_list(novel_url: str):
    """测试章节列表获取"""
    print("\n" + "=" * 60)
    print("测试2: 章节列表获取")
    print("=" * 60)

    crawler = TwxsCrawler()

    print(f"\n小说URL: {novel_url}")
    chapters = await crawler.get_chapter_list(novel_url)

    print(f"\n章节数量: {len(chapters)}")
    print("\n前10个章节:")
    for i, chapter in enumerate(chapters[:10], 1):
        print(f"{i}. {chapter['title']}")
        print(f"   URL: {chapter['url']}")

    if chapters:
        return chapters[0]['url']
    return None


async def test_chapter_content(chapter_url: str):
    """测试章节内容获取"""
    print("\n" + "=" * 60)
    print("测试3: 章节内容获取")
    print("=" * 60)

    crawler = TwxsCrawler()

    print(f"\n章节URL: {chapter_url}")
    result = await crawler.get_chapter_content(chapter_url)

    print(f"\n标题: {result['title']}")
    print(f"成功: {result.get('success', False)}")
    print(f"\n内容预览 (前200字):")
    print(result['content'][:200] + "..." if len(result['content']) > 200 else result['content'])

    # 检查内容是否已转换为简体
    content = result['content']
    if content:
        # 简单检查：如果有"章節"说明还是繁体，应该转为"章节"
        if '章節' in content or '下一頁' in content or '目錄' in content:
            print("\n⚠️ 警告: 内容可能未完全转换为简体")
        else:
            print("\n✓ 内容已转换为简体")

    return result.get('success', False)


async def main():
    """主测试函数"""
    print("悅暢小说爬虫测试")
    print("=" * 60)

    try:
        # 测试搜索
        novel_url = await test_search()

        if not novel_url:
            print("\n❌ 搜索测试失败，未找到结果")
            return

        # 测试章节列表
        chapter_url = await test_chapter_list(novel_url)

        if not chapter_url:
            print("\n❌ 章节列表测试失败，未找到章节")
            return

        # 测试章节内容
        success = await test_chapter_content(chapter_url)

        print("\n" + "=" * 60)
        if success:
            print("✓ 所有测试通过!")
        else:
            print("❌ 章节内容获取失败")
        print("=" * 60)

    except Exception as e:
        print(f"\n❌ 测试过程中发生错误: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
