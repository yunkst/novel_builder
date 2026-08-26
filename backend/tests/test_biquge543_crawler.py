#!/usr/bin/env python3
"""Biquge543 爬虫测试脚本"""

import asyncio
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.biquge543_crawler import Biquge543Crawler


# 使用已知的测试URL
TEST_NOVEL_URL = "https://m.biquge543.com/shu/163512/"


async def test_chapter_list():
    """测试章节列表"""
    print("\n=== 测试章节列表 ===")
    crawler = Biquge543Crawler()
    chapters = await crawler.get_chapter_list(TEST_NOVEL_URL)
    print(f"章节列表: {len(chapters)} 章")
    if chapters:
        print(f"第一章: {chapters[0]['title']}")
        print(f"最后一章: {chapters[-1]['title']}")
    return chapters[0]['url'] if chapters else None


async def test_chapter_content(chapter_url):
    """测试章节内容"""
    print("\n=== 测试章节内容 ===")
    crawler = Biquge543Crawler()
    content = await crawler.get_chapter_content(chapter_url)
    print(f"章节标题: {content['title']}")
    print(f"内容长度: {len(content['content'])} 字符")
    print(f"内容预览: {content['content'][:200]}...")
    return len(content['content']) > 300


async def main():
    print("=" * 60)
    print("笔趣阁543 爬虫功能测试")
    print("=" * 60)

    try:
        chapter_url = await test_chapter_list()
        if not chapter_url:
            print("\n❌ 章节列表测试失败，无法继续测试")
            return False

        success = await test_chapter_content(chapter_url)
        if success:
            print("\n" + "=" * 60)
            print("✅ 所有测试通过!")
            print("=" * 60)
        else:
            print("\n" + "=" * 60)
            print("❌ 测试失败: 章节内容长度不足")
            print("=" * 60)

        return success

    except Exception as e:
        print(f"\n❌ 测试过程中发生错误: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)
