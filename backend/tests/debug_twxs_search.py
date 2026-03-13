#!/usr/bin/env python3
"""调试悅暢小说搜索"""

import asyncio
import sys
sys.path.insert(0, '/app')

from app.services.http_client import http_get, RequestConfig, RequestStrategy
from bs4 import BeautifulSoup

async def main():
    # 测试搜索URL
    search_url = "https://www.twxs.com.tw/search/result.html?searchkey=%E4%BF%AE%E4%BB%99"

    print(f"搜索URL: {search_url}")

    config = RequestConfig(
        timeout=15,
        strategy=RequestStrategy.HYBRID
    )

    response = await http_get(search_url, config)
    print(f"状态码: {response.status_code}")
    print(f"内容长度: {len(response.content)}")

    # 保存原始HTML用于调试
    with open('/tmp/search_debug.html', 'w', encoding='utf-8') as f:
        f.write(response.content)

    # 解析HTML
    soup = BeautifulSoup(response.content, 'lxml')

    # 查找h2标签
    h2_tags = soup.find_all('h2')
    print(f"\n找到 {len(h2_tags)} 个h2标签")

    for i, h2 in enumerate(h2_tags[:5]):
        print(f"\nh2[{i}]: {h2.get_text(strip=True)[:100]}")

    # 查找所有链接
    links = soup.find_all('a', href=True)
    twxs_links = [l for l in links if '/twxscom' in l.get('href', '')]
    print(f"\n找到 {len(twxs_links)} 个twxscom链接")

    for i, link in enumerate(twxs_links[:5]):
        print(f"链接[{i}]: {link.get('href', '')[:80]}")
        print(f"  文本: {link.get_text(strip=True)[:50]}")

if __name__ == "__main__":
    asyncio.run(main())
