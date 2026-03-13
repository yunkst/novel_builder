#!/usr/bin/env python3
"""
调试 Biquge543 章节列表页面的 HTML 结构
"""

import asyncio
import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.biquge543_crawler import Biquge543Crawler


async def debug_html_structure():
    """调试 HTML 结构"""
    print("=" * 80)
    print("调试 Biquge543 章节列表页面 HTML 结构")
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

            # 查找所有 h2 标题
            print("所有 h2 标题:")
            print("-" * 80)
            for i, h2 in enumerate(soup.find_all("h2")):
                print(f"{i+1}. {h2.get_text(strip=True)}")
                # 打印 h2 后面的兄弟元素
                print("   后面的元素:")
                next_elements = soup.select(f"h2:nth-of-type({i+1}) ~ *")
                for j, elem in enumerate(next_elements[:5]):
                    tag_name = elem.get('tag') if hasattr(elem, 'get') else str(type(elem))
                    text = elem.get_text(strip=True)[:50] if hasattr(elem, 'get_text') else ''
                    print(f"     - {tag_name}: {text}")
                print()

            # 查找所有包含"文章目录"的区域
            print("查找包含'文章目录'的区域:")
            print("-" * 80)
            all_h2 = soup.find_all("h2")
            for i, h2 in enumerate(all_h2):
                text = h2.get_text(strip=True)
                if "目录" in text:
                    print(f"找到: {text}")
                    # 尝试使用不同的选择器
                    print("  尝试 CSS 选择器:")
                    selectors = [
                        f"h2:nth-of-type({i+1}) + div",
                        f"h2:nth-of-type({i+1}) ~ div",
                        f"h2:nth-of-type({i+1}) + div div",
                        f"h2:nth-of-type({i+1}) ~ div div",
                    ]
                    for sel in selectors:
                        results = soup.select(sel)
                        print(f"    {sel}: 找到 {len(results)} 个元素")
                        if results:
                            for j, r in enumerate(results[:2]):
                                print(f"      元素 {j+1}: {r.get_text(strip=True)[:50]}")

            # 查找所有包含章节链接的区域
            print()
            print("查找所有包含章节链接的 div:")
            print("-" * 80)
            all_divs = soup.find_all("div")
            for div in all_divs:
                links = div.find_all("a", href=True)
                chapter_links = [link for link in links if re.match(rf'^/chapter/{re.escape(novel_id)}/\d+\.html$', link.get('href', ''))]
                if len(chapter_links) > 5:  # 至少有5个章节链接才认为是章节列表区域
                    # 获取div的class或id
                    div_class = div.get('class')
                    div_id = div.get('id')
                    print(f"找到包含 {len(chapter_links)} 个章节链接的 div: class={div_class}, id={div_id}")
                    print(f"  前几个章节: {chapter_links[0].get_text(strip=True)}, {chapter_links[1].get_text(strip=True)}, {chapter_links[2].get_text(strip=True)}")

            # 打印原始 HTML 的一部分
            print()
            print("原始 HTML 片段 (包含 '文章目录' 的部分):")
            print("-" * 80)
            html_content = response.content
            # 找到包含"文章目录"的部分
            import re
            catalog_match = re.search(r'.{0,500}文章目录.{0,1000}', html_content)
            if catalog_match:
                print(catalog_match.group(0))
            else:
                print("未找到'文章目录'相关内容")


if __name__ == "__main__":
    asyncio.run(debug_html_structure())
