#!/usr/bin/env python3
"""书豪小说网 (shuhaoxs.com) 爬虫测试脚本"""

import asyncio
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.shuhaoxs_crawler import ShuhaoxsCrawler


async def test_search():
    """测试搜索功能"""
    crawler = ShuhaoxsCrawler()
    results = await crawler.search_novels("天道")
    print(f"搜索结果: {len(results)} 本小说")
    for r in results[:5]:
        print(f"  - {r['title']} ({r.get('author', '未知')}) -> {r['url']}")
    return results[0]["url"] if results else None


async def test_chapter_list(novel_url):
    """测试章节列表"""
    crawler = ShuhaoxsCrawler()
    chapters = await crawler.get_chapter_list(novel_url)
    print(f"章节列表: {len(chapters)} 章")
    if chapters:
        print(f"  第一章: {chapters[0]['title']} -> {chapters[0]['url']}")
        print(f"  最后一章: {chapters[-1]['title']} -> {chapters[-1]['url']}")
    return chapters[0]["url"] if chapters else None


async def test_chapter_content(chapter_url):
    """测试章节内容"""
    crawler = ShuhaoxsCrawler()
    content = await crawler.get_chapter_content(chapter_url)
    print(f"章节标题: {content['title']}")
    print(f"内容长度: {len(content['content'])} 字符")
    print(f"内容预览: {content['content'][:200]}...")
    return len(content["content"]) > 100


async def test_direct_chapter_list():
    """直接测试已知小说的章节列表"""
    crawler = ShuhaoxsCrawler()
    novel_url = "https://www.shuhaoxs.com/book/tftt00.html"
    chapters = await crawler.get_chapter_list(novel_url)
    print(f"直接访问章节列表: {len(chapters)} 章")
    if chapters:
        print(f"  第一章: {chapters[0]['title']}")
        print(f"  最后一章: {chapters[-1]['title']}")
    return chapters[0]["url"] if chapters else None


async def main():
    print("=" * 60)
    print("书豪小说网 爬虫测试")
    print("=" * 60)

    print("\n--- 测试 1: 搜索 ---")
    novel_url = await test_search()
    if not novel_url:
        print("搜索未返回结果，使用已知小说 URL")
        novel_url = "https://www.shuhaoxs.com/book/tftt00.html"

    print("\n--- 测试 2: 章节列表 ---")
    chapter_url = await test_chapter_list(novel_url)
    if not chapter_url:
        print("章节列表失败，使用已知章节 URL")
        chapter_url = "https://www.shuhaoxs.com/book/tftt00-1.html"

    print("\n--- 测试 3: 章节内容 ---")
    success = await test_chapter_content(chapter_url)

    print("\n" + "=" * 60)
    print("测试通过!" if success else "测试失败!")
    return success


if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)
