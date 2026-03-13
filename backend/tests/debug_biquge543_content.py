#!/usr/bin/env python3
"""调试biquge543章节内容"""

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

        # 查找标题
        title = soup.find("h1")
        if title:
            print(f"\n章节标题: {title.get_text(strip=True)}")

        # 打印页面结构
        print(f"\n=== 页面结构分析 ===")

        # 查找所有div
        all_divs = soup.find_all("div")
        print(f"找到的div数量: {len(all_divs)}")

        # 查找generic div
        generic_divs = soup.find_all("div", class_="generic")
        print(f"找到的generic div数量: {len(generic_divs)}")

        if generic_divs:
            print("\n第一个generic div的内容预览:")
            first_generic = generic_divs[0]
            text = first_generic.get_text(strip=True)[:500]
            print(f"文本内容: {text}")

        # 查找所有p标签
        all_p = soup.find_all("p")
        print(f"\n找到的p标签数量: {len(all_p)}")
        if all_p:
            print("前5个p标签:")
            for i, p in enumerate(all_p[:5], 1):
                text = p.get_text(strip=True)[:100]
                print(f"{i}. {text}")


if __name__ == "__main__":
    asyncio.run(debug_chapter_content())
