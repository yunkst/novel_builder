#!/usr/bin/env python3
"""只测试章节内容提取"""

import asyncio
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.biquge543_crawler import Biquge543Crawler


async def test_content_extraction():
    """测试章节内容提取"""
    url = "https://m.biquge543.com/chapter/163512/743595401.html"
    crawler = Biquge543Crawler()

    print(f"获取章节: {url}")
    response = await crawler.get_page(url, custom_headers=crawler.custom_headers, timeout=30)
    print(f"状态码: {response.status_code}")

    if response.status_code == 200:
        soup = response.soup()

        # 直接调用提取方法
        content = crawler._extract_chapter_content(soup)
        print(f"\n提取的内容长度: {len(content)}")
        if content:
            print(f"内容前500字符:\n{content[:500]}")
        else:
            print("内容为空！")


if __name__ == "__main__":
    asyncio.run(test_content_extraction())
