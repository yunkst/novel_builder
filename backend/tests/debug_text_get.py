#!/usr/bin/env python3
"""
调试文本获取
"""

import asyncio
import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.biquge543_crawler import Biquge543Crawler


async def debug_text():
    """调试文本获取"""
    print("=" * 80)
    print("调试文本获取")
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

            # 获取所有链接
            all_links = soup.find_all("a")
            print(f"总共有 {len(all_links)} 个链接")
            print()

            # 找到"下一页"链接
            target_index = None
            for i, link in enumerate(all_links):
                text = link.get_text(strip=True)
                if '下一页' in text:
                    target_index = i
                    print(f"找到目标链接（索引 {i}）:")
                    print(f"  href: {link.get('href')}")
                    print(f"  get_text(strip=True): {text}")
                    print(f"  get_text(): {link.get_text()}")
                    print(f"  get_text(strip=False): {link.get_text(strip=False)}")

                    # 测试不同的文本获取方法
                    print()
                    print("  测试不同的文本获取方法:")
                    print(f"    css('::text').get(): {link._selector.css('::text').get()}")
                    print(f"    css('::text').getall(): {link._selector.css('::text').getall()}")
                    print(f"    css('::text').get(''): {link._selector.css('::text').get('')}")
                    break

            if target_index is None:
                print("未找到包含 '下一页' 的链接")
            else:
                # 测试查找
                print()
                print("测试查找:")
                print("-" * 80)
                target_link = all_links[target_index]

                # 直接获取文本
                text_direct = target_link.get_text(strip=True)
                print(f"直接获取文本: '{text_direct}'")
                print(f"'下一页' in '{text_direct}': {'下一页' in text_direct}")

                # 使用find方法
                found = soup.find("a", string="下一页")
                print(f"find('a', string='下一页'): {found is not None}")

                # 使用find_all方法
                found_all = soup.find_all("a", string="下一页")
                print(f"find_all('a', string='下一页'): {len(found_all)} 个")


if __name__ == "__main__":
    asyncio.run(debug_text())
