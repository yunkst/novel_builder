#!/usr/bin/env python3
"""调试biquge543爬虫"""

import asyncio
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.biquge543_crawler import Biquge543Crawler


async def debug_page():
    """调试页面内容"""
    url = "https://m.biquge543.com/shu/163512/"
    crawler = Biquge543Crawler()

    # 不使用Accept-Encoding来获取未压缩的内容
    headers = crawler.custom_headers.copy()
    headers.pop("Accept-Encoding", None)

    print(f"获取页面: {url}")
    response = await crawler.get_page(url, custom_headers=headers, timeout=30)
    print(f"状态码: {response.status_code}")
    print(f"最终URL: {response.url}")
    print(f"响应头: {response.headers}")

    if response.status_code == 200:
        # 打印原始HTML的前1000个字符
        html_content = response.content
        print(f"\n原始HTML前1000字符:\n{html_content[:1000]}")

        soup = response.soup()

        # 打印页面标题
        title = soup.find("h1")
        if title:
            print(f"\n小说标题: {title.get_text(strip=True)}")

        # 查找所有a标签
        all_links = soup.find_all("a", href=True)
        print(f"\n找到的a标签数量: {len(all_links)}")

        if all_links:
            print("\n前10个a标签:")
            for i, link in enumerate(all_links[:10], 1):
                href = link.get("href") if link.has_attr("href") else ""
                text = link.get_text(strip=True)[:50]
                print(f"{i}. {text} -> {href}")


if __name__ == "__main__":
    asyncio.run(debug_page())
