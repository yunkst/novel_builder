#!/usr/bin/env python3
"""调试小说详情页"""

import asyncio
import sys
sys.path.insert(0, '/app')

from app.services.http_client import http_get, RequestConfig, RequestStrategy
from bs4 import BeautifulSoup

async def main():
    # 小说详情页
    novel_url = "https://www.twxs.com.tw/twxscomXiuXianGongLve250952223/"

    print(f"小说URL: {novel_url}")

    config = RequestConfig(
        timeout=30,
        strategy=RequestStrategy.BROWSER
    )

    response = await http_get(novel_url, config)
    print(f"状态码: {response.status_code}")
    print(f"内容长度: {len(response.content)}")

    # 保存HTML
    with open('/tmp/novel_debug.html', 'w', encoding='utf-8') as f:
        f.write(response.content)

    # 解析
    soup = BeautifulSoup(response.content, 'lxml')

    # 查找所有h2
    h2_tags = soup.find_all('h2')
    print(f"\n找到 {len(h2_tags)} 个h2标签:")
    for i, h2 in enumerate(h2_tags):
        text = h2.get_text(strip=True)
        print(f"  h2[{i}]: {text[:80]}")

    # 查找章节相关链接
    all_links = soup.find_all('a', href=True)
    chapter_links = [l for l in all_links if 'read_' in l.get('href', '')]

    print(f"\n找到 {len(chapter_links)} 个章节链接:")
    for i, link in enumerate(chapter_links[:10]):
        print(f"  [{i}] {link.get('href', '')}")
        print(f"      {link.get_text(strip=True)[:50]}")

if __name__ == "__main__":
    asyncio.run(main())
