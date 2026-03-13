#!/usr/bin/env python3
"""
调试文本匹配逻辑
"""

import asyncio
import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.biquge543_crawler import Biquge543Crawler


async def debug_text_matching():
    """调试文本匹配逻辑"""
    print("=" * 80)
    print("调试文本匹配逻辑")
    print("=" * 80)

    novel_url = "https://m.biquge543.com/shu/163512/"
    print(f"测试 URL: {novel_url}")
    print()

    # 创建爬虫实例
    crawler = Biquge543Crawler()

    # 获取第一页
    import re
    novel_id_match = re.search(r"/shu/(\d+)/?", novel_url)
    if novel_id_match:
        novel_id = novel_id_match.group(1)
        list_url = f"{crawler.base_url}/shu/{novel_id}_1/"

        print(f"章节列表页面 URL: {list_url}")
        print()

        response = await crawler.get_page(
            list_url, custom_headers=crawler.custom_headers, timeout=30
        )

        if response.status_code == 200:
            soup = response.soup()

            # 获取所有a标签
            all_a = soup._selector.css('a')
            print(f"找到 {len(all_a)} 个<a>标签")
            print()

            # 查找包含"下一页"的链接
            target_text = "下一页"
            print(f"查找包含文本 '{target_text}' 的链接:")
            print("-" * 80)

            for i, elem in enumerate(all_a):
                # 获取文本
                text = elem.css('::text').get('')
                text_stripped = text.strip()

                if target_text in text_stripped:
                    print(f"  索引 {i}: text='{text}', stripped='{text_stripped}'")
                    print(f"    href: {elem.css('::attr(href)').get('')}")
                    print(f"    匹配: '{target_text}' in '{text_stripped}' = {target_text in text_stripped}")
                    print(f"    相等: '{target_text}' == '{text_stripped}' = {target_text == text_stripped}")


if __name__ == "__main__":
    asyncio.run(debug_text_matching())
