#!/usr/bin/env python3
"""测试微风小说网 booklist URL 获取章节列表和内容"""

import asyncio
import sys
from pathlib import Path

# 添加项目路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.services.wfxs_crawler import WfxsCrawler


async def main():
    crawler = WfxsCrawler()

    # 测试 booklist URL
    url = 'https://m.wfxs.tw/booklist/7822155.html'
    print(f'测试 URL: {url}')
    print('=' * 60)

    # 1. 获取章节列表
    print('\n【1. 获取章节列表】')
    chapters = await crawler.get_chapter_list(url)

    print(f'获取到 {len(chapters)} 个章节')
    if chapters:
        print('\n前 5 个章节:')
        for i, ch in enumerate(chapters[:5], 1):
            print(f'  {i}. {ch["title"]}')

        # 2. 测试获取章节内容
        print('\n【2. 获取章节内容】')
        first_chapter = chapters[0]
        print(f'测试章节：{first_chapter["title"]}')
        print(f'URL: {first_chapter["url"]}')
        print('-' * 60)

        content = await crawler.get_chapter_content(first_chapter["url"])

        if content.get("success"):
            print(f"\n标题：{content['title']}")
            print(f"内容长度：{len(content['content'])} 字符")
            print("\n内容前 500 字:")
            print("-" * 60)
            print(content['content'][:500])
            print("...")
        else:
            print("获取章节内容失败")


if __name__ == '__main__':
    asyncio.run(main())
