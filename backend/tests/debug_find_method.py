#!/usr/bin/env python3
"""
调试 find 方法
"""

import asyncio
import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.biquge543_crawler import Biquge543Crawler


async def debug_find():
    """调试 find 方法"""
    print("=" * 80)
    print("调试 find 方法")
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

            # 测试 find 方法
            print("测试 find('a', string='下一页'):")
            print("-" * 80)
            next_link = soup.find("a", string="下一页")
            if next_link:
                print(f"找到下一页链接: {next_link.get('href')}")
            else:
                print("未找到下一页链接")

            print()
            print("测试 find_all('a', string='下一页'):")
            print("-" * 80)
            next_links = soup.find_all("a", string="下一页")
            if next_links:
                for i, link in enumerate(next_links):
                    print(f"  {i+1}. {link.get('href')} - {link.get_text(strip=True)}")
            else:
                print("未找到下一页链接")

            print()
            print("测试 find_all('a'):")
            print("-" * 80)
            all_links = soup.find_all("a")
            for i, link in enumerate(all_links):
                text = link.get_text(strip=True)
                href = link.get('href', '')
                if '下一页' in text:
                    print(f"  {i+1}. {href} - {text}")


if __name__ == "__main__":
    asyncio.run(debug_find())
