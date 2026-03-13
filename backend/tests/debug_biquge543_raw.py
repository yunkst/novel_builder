#!/usr/bin/env python3
"""调试biquge543章节内容 - 打印原始HTML"""

import asyncio
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.biquge543_crawler import Biquge543Crawler


async def debug_chapter_content():
    """调试章节内容"""
    url = "https://m.biquge543.com/chapter/163512/743595401.html"
    crawler = Biquge543Crawler()

    print(f"获取章节: {url}")
    response = await crawler.get_page(url, custom_headers=crawler.custom_headers, timeout=30)
    print(f"状态码: {response.status_code}")
    print(f"响应长度: {len(response.content)}")

    if response.status_code == 200:
        # 打印原始HTML的前2000字符
        html = response.content
        print(f"\n=== 原始HTML前2000字符 ===")
        print(html[:2000])

        # 查找特定关键词
        print(f"\n=== 查找关键词 ===")
        print(f"包含'generic': {'generic' in html}")
        print(f"包含'class=generic': {'class=generic' in html}")
        print(f"包含'<p>': {'<p>' in html or '<p ' in html}")


if __name__ == "__main__":
    asyncio.run(debug_chapter_content())
