#!/usr/bin/env python3
"""调试章节内容页"""

import asyncio
import sys
sys.path.insert(0, '/app')

from app.services.http_client import http_get, RequestConfig, RequestStrategy
from bs4 import BeautifulSoup

async def main():
    # 章节URL
    chapter_url = "https://www.twxs.com.tw/twxscomXiuXianGongLve250952223/read_1.html"

    print(f"章节URL: {chapter_url}")

    config = RequestConfig(
        timeout=30,
        strategy=RequestStrategy.BROWSER
    )

    response = await http_get(chapter_url, config)
    print(f"状态码: {response.status_code}")
    print(f"内容长度: {len(response.content)}")

    # 保存HTML
    with open('/tmp/chapter_debug.html', 'w', encoding='utf-8') as f:
        f.write(response.content)

    # 解析
    soup = BeautifulSoup(response.content, 'lxml')

    # 查找标题
    h1 = soup.find('h1')
    if h1:
        print(f"\n标题: {h1.get_text(strip=True)}")

    # 查找所有div及其文本长度
    print("\n查找内容容器:")
    for selector in ['#content', '.content', 'article', '#txt', '.txt']:
        elem = soup.select_one(selector)
        if elem:
            text = elem.get_text(strip=True)
            print(f"  {selector}: {len(text)} 字符")
            if len(text) > 50:
                print(f"    预览: {text[:100]}")

    # 查找所有段落
    paragraphs = soup.find_all('p')
    print(f"\n找到 {len(paragraphs)} 个p标签")

    # 打印前10个p标签内容
    for i, p in enumerate(paragraphs[:10]):
        text = p.get_text(strip=True)
        if text:
            print(f"  p[{i}]: {text[:80]}")

if __name__ == "__main__":
    asyncio.run(main())
