#!/usr/bin/env python3
"""调试biquge543章节内容 - 检查子div内容"""

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
        soup = response.soup()

        # 查找id="neirong"的div
        neirong_div = soup.find("div", id="neirong")

        if neirong_div:
            # 获取所有div子元素
            child_divs = neirong_div.find_all("div", recursive=False)
            print(f"\nneirong div的直接子div数量: {len(child_divs)}")

            # 检查每个子div
            for i, div in enumerate(child_divs[:10], 1):
                print(f"\n子div {i}:")
                print(f"  class: {div.get('class', '无')}")
                print(f"  id: {div.get('id', '无')}")
                print(f"  文本长度: {len(div.get_text(strip=True))}")
                print(f"  文本预览: {div.get_text(strip=True)[:200]}")

            # 查找generic class的div
            generic_divs = neirong_div.find_all("div", class_="generic")
            print(f"\n\nneirong div中的generic子div数量: {len(generic_divs)}")
            if generic_divs:
                print("第一个generic div:")
                print(f"  文本长度: {len(generic_divs[0].get_text(strip=True))}")
                print(f"  文本预览: {generic_divs[0].get_text(strip=True)[:500]}")


if __name__ == "__main__":
    asyncio.run(debug_chapter_content())
