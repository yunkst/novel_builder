#!/usr/bin/env python3
"""调试biquge543章节内容 - 详细检查"""

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
        print(f"\n找到id='neirong'的div: {neirong_div is not None}")

        if neirong_div:
            # 获取该div的文本
            text = neirong_div.get_text(strip=True)
            print(f"neirong div的文本长度: {len(text)}")
            print(f"neirong div的文本前500字符: {text[:500]}")

            # 查找p标签
            p_tags = neirong_div.find_all("p")
            print(f"neirong div中的p标签数量: {len(p_tags)}")
            if p_tags:
                print("前3个p标签内容:")
                for i, p in enumerate(p_tags[:3], 1):
                    print(f"{i}. {p.get_text(strip=True)[:100]}")

            # 查找所有子元素
            children = list(neirong_div.children)
            print(f"\nneirong div的直接子元素数量: {len(children)}")
            print("直接子元素类型:")
            for i, child in enumerate(children[:10], 1):
                if hasattr(child, 'name'):
                    print(f"{i}. <{child.name}>")
                else:
                    child_type = type(child).__name__
                    print(f"{i}. {child_type}: {str(child)[:50]}")


if __name__ == "__main__":
    asyncio.run(debug_chapter_content())
