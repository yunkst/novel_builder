#!/usr/bin/env python3
"""查找包含大量文本的元素"""

import asyncio
import sys
sys.path.insert(0, '/app')

from app.services.http_client import http_get, RequestConfig, RequestStrategy
from bs4 import BeautifulSoup, NavigableString

async def main():
    chapter_url = "https://www.twxs.com.tw/twxscomXiuXianGongLve250952223/read_1.html"

    config = RequestConfig(timeout=30, strategy=RequestStrategy.BROWSER)
    response = await http_get(chapter_url, config)

    soup = BeautifulSoup(response.content, 'lxml')

    # 查找所有div
    divs = soup.find_all('div')
    print(f"找到 {len(divs)} 个div")

    # 找文本最多的div
    max_text = 0
    best_div = None

    for div in divs:
        # 获取所有文本节点
        text_nodes = []
        for child in div.descendants:
            if isinstance(child, NavigableString):
                text = str(child).strip()
                if text:
                    text_nodes.append(text)

        total_text = ''.join(text_nodes)

        # 跳过script和style
        if div.find('script') or div.find('style'):
            continue

        if len(total_text) > max_text and len(total_text) > 100:
            max_text = len(total_text)
            best_div = div

    if best_div:
        print(f"\n最长的div: {max_text} 字符")
        # 获取该div的class或id
        if best_div.get('class'):
            print(f"  class: {best_div.get('class')}")
        if best_div.get('id'):
            print(f"  id: {best_div.get('id')}")

        # 获取前几个文本节点
        texts = []
        for child in best_div.descendants:
            if isinstance(child, NavigableString):
                text = str(child).strip()
                if text and len(text) > 5:
                    texts.append(text)
                    if len(texts) >= 5:
                        break

        print(f"\n前5个文本节点:")
        for i, text in enumerate(texts):
            print(f"  [{i}] {text[:80]}")

if __name__ == "__main__":
    asyncio.run(main())
