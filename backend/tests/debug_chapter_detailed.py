#!/usr/bin/env python3
"""详细调试章节内容"""

import asyncio
import sys
import re
sys.path.insert(0, '/app')

from app.services.http_client import http_get, RequestConfig, RequestStrategy
from bs4 import BeautifulSoup, NavigableString

async def main():
    chapter_url = "https://www.twxs.com.tw/twxscomXiuXianGongLve250952223/read_1.html"

    config = RequestConfig(timeout=30, strategy=RequestStrategy.BROWSER)
    response = await http_get(chapter_url, config)

    soup = BeautifulSoup(response.content, 'lxml')

    # 查找所有generic容器
    generics = soup.find_all('div', class_=lambda x: x and 'generic' in str(x).lower())
    print(f"找到 {len(generics)} 个generic容器")

    for i, generic in enumerate(generics):
        # 获取该容器内的所有文本
        texts = []
        for elem in generic.descendants:
            if isinstance(elem, NavigableString):
                text = str(elem).strip()
                if text and len(text) > 10:
                    texts.append(text)

        if len(texts) > 5:
            print(f"\ngeneric[{i}]: {len(texts)} 个文本节点")
            print(f"  预览: {texts[0] if texts else 'N/A'}")
            print(f"  第2个: {texts[1] if len(texts) > 1 else 'N/A'}")
            print(f"  第3个: {texts[2] if len(texts) > 2 else 'N/A'}")

            # 检查是否包含小说内容特征
            combined = ' '.join(texts)
            if '姚氏' in combined or '清冷' in combined or '眸色' in combined:
                print(f"  ✓ 找到小说内容！")
                break

if __name__ == "__main__":
    asyncio.run(main())
