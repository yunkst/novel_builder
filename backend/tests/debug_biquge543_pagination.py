#!/usr/bin/env python3
"""
调试 Biquge543 分页问题
"""

import asyncio
import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.biquge543_crawler import Biquge543Crawler


async def debug_pagination():
    """调试分页问题"""
    print("=" * 80)
    print("调试 Biquge543 分页问题")
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

            # 查找所有包含"下一页"的链接
            print("查找所有包含'下一页'的链接:")
            print("-" * 80)
            all_links = soup.find_all("a")
            for link in all_links:
                text = link.get_text(strip=True)
                href = link.get('href', '')
                if '下一页' in text or 'next' in text.lower():
                    print(f"文本: {text}, href: {href}")

            # 查找所有链接
            print()
            print("所有链接文本（前50个）:")
            print("-" * 80)
            all_links = soup.find_all("a")
            for i, link in enumerate(all_links[:50]):
                text = link.get_text(strip=True)
                href = link.get('href', '')
                print(f"{i+1}. {text} -> {href}")

            # 查找分页相关的div
            print()
            print("查找分页相关的div:")
            print("-" * 80)
            all_divs = soup.find_all("div")
            for div in all_divs:
                div_class = div.get('class')
                div_id = div.get('id')
                text = div.get_text(strip=True)
                if any(keyword in text.lower() for keyword in ['上一页', '下一页', '首页', '末页', '1/52']):
                    print(f"div class={div_class}, id={div_id}")
                    print(f"  文本: {text[:100]}")

            # 直接搜索HTML内容中的分页信息
            print()
            print("原始HTML中的分页信息:")
            print("-" * 80)
            html_content = response.content
            import re
            # 查找分页相关的HTML
            pagination_patterns = [
                r'.{0,200}下一页.{0,200}',
                r'.{0,200}上一页.{0,200}',
                r'.{0,200}1/\d+.{0,200}',
            ]
            for pattern in pagination_patterns:
                matches = re.finditer(pattern, html_content)
                for match in matches:
                    text = match.group(0)
                    # 清理HTML标签，只显示文本
                    text = re.sub(r'<[^>]+>', ' ', text)
                    text = ' '.join(text.split())
                    if text.strip():
                        print(f"{text[:150]}")
                        print()


if __name__ == "__main__":
    asyncio.run(debug_pagination())
