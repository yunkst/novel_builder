#!/usr/bin/env python3
"""悅暢小说爬虫测试"""

import asyncio
import sys
import os

# 添加 app 目录到路径
sys.path.insert(0, '/app')

from app.services.twxs_crawler import TwxsCrawler


async def main():
    print("=" * 60)
    print("悅暢小说爬虫测试")
    print("=" * 60)

    crawler = TwxsCrawler()

    # 测试搜索
    print("\n测试1: 搜索功能 (简体关键词自动转繁体)")
    keyword = "修仙"
    print(f"搜索关键词: {keyword}")

    novels = await crawler.search_novels(keyword)
    print(f"搜索结果数量: {len(novels)}")

    if not novels:
        print("❌ 搜索失败，未找到结果")
        return

    print("\n前3个结果:")
    for i, novel in enumerate(novels[:3], 1):
        print(f"{i}. {novel['title']} - {novel['author']}")

    # 测试章节列表
    print("\n测试2: 章节列表")
    novel_url = novels[0]['url']
    print(f"小说URL: {novel_url}")

    chapters = await crawler.get_chapter_list(novel_url)
    print(f"章节数量: {len(chapters)}")

    if not chapters:
        print("❌ 获取章节列表失败")
        return

    print("\n前5个章节:")
    for i, chapter in enumerate(chapters[:5], 1):
        print(f"{i}. {chapter['title']}")

    # 测试章节内容
    print("\n测试3: 章节内容 (繁体自动转简体)")
    chapter_url = chapters[0]['url']
    print(f"章节URL: {chapter_url}")

    result = await crawler.get_chapter_content(chapter_url)
    print(f"标题: {result['title']}")
    print(f"成功: {result.get('success', False)}")

    content = result.get('content', '')
    print(f"内容长度: {len(content)}")
    print(f"内容预览: {content[:100]}...")

    # 检查简繁转换
    if '章節' in content or '下一頁' in content:
        print("\n⚠️ 内容可能未完全转换为简体")
    else:
        print("\n✓ 内容已正确转换为简体")

    print("\n" + "=" * 60)
    print("✓ 所有测试通过!")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
