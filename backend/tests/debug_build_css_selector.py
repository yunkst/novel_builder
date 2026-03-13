#!/usr/bin/env python3
"""
调试 build_css_selector
"""

import asyncio
import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.biquge543_crawler import Biquge543Crawler


async def debug_build_css_selector():
    """调试 build_css_selector"""
    print("=" * 80)
    print("调试 build_css_selector")
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

            # 测试 _build_css_selector
            print("测试 _build_css_selector:")
            print("-" * 80)
            css_selector = soup._build_css_selector("a", None, None)
            print(f"_build_css_selector('a', None, None): '{css_selector}'")
            print(f"类型: {type(css_selector)}")

            # 测试 CSS 选择器
            print()
            print("测试 CSS 选择器:")
            print("-" * 80)
            if css_selector:
                results = soup._selector.css(css_selector)
                print(f"soup._selector.css('{css_selector}'): 找到 {len(results)} 个元素")
            else:
                print("CSS选择器为空")

            # 直接使用 soup._selector.css('a')
            print()
            print("直接使用 soup._selector.css('a'):")
            print("-" * 80)
            all_a = soup._selector.css('a')
            print(f"找到 {len(all_a)} 个元素")

            # 测试 find 方法
            print()
            print("测试 soup.find('a'):")
            print("-" * 80)
            result = soup.find("a")
            if result:
                print(f"找到第一个<a>元素: {result.get('href')} - {result.get_text(strip=True)}")
            else:
                print("未找到<a>元素")

            # 测试 find 方法 with string
            print()
            print("测试 soup.find('a', string='下一页'):")
            print("-" * 80)
            result = soup.find("a", string="下一页")
            if result:
                print(f"找到元素: {result.get('href')} - {result.get_text(strip=True)}")
            else:
                print("未找到元素")


if __name__ == "__main__":
    asyncio.run(debug_build_css_selector())
