#!/usr/bin/env python3
"""
调试 Biquge543 站点第一页章节混乱问题

目标 URL: https://m.biquge543.com/shu/163512/
"""

import re
import urllib.parse
from scrapling import Fetcher
from bs4 import BeautifulSoup


def debug_first_page():
    """调试第一页章节提取"""
    base_url = "https://m.biquge543.com"
    novel_url = "https://m.biquge543.com/shu/163512/"

    print("=" * 80)
    print("调试 Biquge543 第一页章节提取")
    print("=" * 80)
    print(f"目标 URL: {novel_url}")
    print()

    # 提取小说ID
    novel_id_match = re.search(r"/shu/(\d+)/?", novel_url)
    if not novel_id_match:
        print("错误: 无法提取小说ID")
        return

    novel_id = novel_id_match.group(1)
    print(f"小说ID: {novel_id}")
    print()

    # 第一页 URL
    list_url = f"{base_url}/shu/{novel_id}/"
    print(f"第一页 URL: {list_url}")
    print()

    # 使用 Fetcher 获取页面
    print("正在获取第一页...")
    try:
        fetcher = Fetcher(auto_config=True)
        response = fetcher.get(
            list_url,
            headers={
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "zh-CN,zh;q=0.9",
                "Accept-Encoding": "",
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
            },
        )

        if response.status != 200:
            print(f"错误: HTTP状态码 {response.status}")
            return

        # 使用 BeautifulSoup 解析
        # Scrapling Fetcher 返回的 Response 对象有不同的属性
        # 根据日志可以看到成功获取了页面，使用不同的属性访问内容
        html_content = ""
        if hasattr(response, 'html_content'):
            html_content = response.html_content
        elif hasattr(response, 'content'):
            html_content = response.content
        elif hasattr(response, 'text'):
            html_content = response.text
        else:
            html_content = str(response)

        soup = BeautifulSoup(html_content, 'lxml')

        # 方法1: 直接查找所有匹配格式的链接（当前代码使用的方法）
        print("-" * 80)
        print("方法1: 当前代码使用的提取方法")
        print("-" * 80)

        chapter_links = []
        all_links = soup.find_all("a", href=True)
        print(f"总共找到 {len(all_links)} 个链接")

        for link in all_links:
            href = link.get('href', '')
            # 匹配 /chapter/数字ID/数字.html 格式
            if re.match(rf'^/chapter/{re.escape(novel_id)}/\d+\.html$', href):
                chapter_links.append(link)

        print(f"匹配到 {len(chapter_links)} 个章节链接")
        print()

        print("前20个章节链接:")
        print("-" * 80)
        for i, link in enumerate(chapter_links[:20], 1):
            title = link.get_text(strip=True)
            href = link.get("href")
            chapter_url = urllib.parse.urljoin(base_url, href)

            # 提取章节号
            chapter_num_match = re.search(r'第(\d+)章', title)
            chapter_num = chapter_num_match.group(1) if chapter_num_match else "N/A"

            print(f"{i:3d}. 章节{chapter_num}: {title}")
            print(f"     URL: {href}")

        print()

        # 方法2: 查找章节列表容器（检查是否有容器）
        print("-" * 80)
        print("方法2: 查找章节列表容器")
        print("-" * 80)

        # 常见的选择器
        selectors = [
            "#list",
            ".listmain",
            "dl",
            ".book_list",
            ".chapterlist",
            "#readerlist",
            'div[class*="list"]',
            'div[class*="chapter"]',
        ]

        for selector in selectors:
            container = soup.select_one(selector)
            if container:
                print(f"找到容器: {selector}")
                links_in_container = container.find_all("a", href=True)
                print(f"  容器内链接数: {len(links_in_container)}")

                # 统计匹配的章节链接
                matched_in_container = 0
                for link in links_in_container:
                    href = link.get('href', '')
                    if re.match(rf'^/chapter/{re.escape(novel_id)}/\d+\.html$', href):
                        matched_in_container += 1
                print(f"  匹配的章节链接: {matched_in_container}")
                print()

        # 方法3: 分析页面上所有匹配格式的链接分布
        print("-" * 80)
        print("方法3: 分析链接分布（检查是否有重复或混乱）")
        print("-" * 80)

        chapter_dict = {}  # 按章节号分组
        duplicates = []

        for link in chapter_links:
            href = link.get('href', '')
            title = link.get_text(strip=True)
            chapter_url = urllib.parse.urljoin(base_url, href)

            # 提取章节号
            chapter_num_match = re.search(r'第(\d+)章', title)
            chapter_num = chapter_num_match.group(1) if chapter_num_match else "0"

            if chapter_num in chapter_dict:
                duplicates.append((chapter_num, title, href, chapter_dict[chapter_num]))
            else:
                chapter_dict[chapter_num] = (title, href)

        print(f"唯一章节号数量: {len(chapter_dict)}")
        print(f"重复的章节数量: {len(duplicates)}")

        if duplicates:
            print("\n重复的章节:")
            for chapter_num, title, href, original_href in duplicates[:10]:
                print(f"  章节{chapter_num}: {title}")
                print(f"    新URL: {href}")
                print(f"    旧URL: {original_href}")

        print()

        # 按章节号号顺序检查
        print("-" * 80)
        print("方法4: 按章节号顺序检查")
        print("-" * 80)

        sorted_chapters = sorted(chapter_dict.items(), key=lambda x: int(x[0]) if x[0].isdigit() else 0)

        print("前20个章节（按章节号排序）:")
        for i, (chapter_num, href) in enumerate(sorted_chapters[:20], 1):
            print(f"{i:3d}. 章节{chapter_num}: {href}")

        print()

        # 检查是否有跳跃
        print("-" * 80)
        print("方法5: 检查章节号连续性")
        print("-" * 80)

        chapter_nums = [int(num) for num in chapter_dict.keys() if num.isdigit()]
        if chapter_nums:
            chapter_nums.sort()
            print(f"最小章节号: {min(chapter_nums)}")
            print(f"最大章节号: {max(chapter_nums)}")
            print(f"总章节数: {len(chapter_nums)}")

            # 检查缺失的章节
            expected = set(range(min(chapter_nums), max(chapter_nums) + 1))
            actual = set(chapter_nums)
            missing = expected - actual

            if missing:
                print(f"\n缺失的章节（共 {len(missing)} 章）:")
                print(f"缺失范围: {sorted(list(missing))[:20]}{'...' if len(missing) > 20 else ''}")
            else:
                print("章节号连续，没有缺失")

        # 打印原始HTML部分（用于调试）
        print()
        print("-" * 80)
        print("原始HTML片段（前2000字符）:")
        print("-" * 80)
        print(html_content[:2000])

    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    debug_first_page()