#!/usr/bin/env python3
"""
测试 Biquge543 爬虫修复后的章节列表获取

测试 URL: https://m.biquge543.com/shu/163512/
"""

import asyncio
import sys
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.biquge543_crawler import Biquge543Crawler


async def test_chapter_list():
    """测试章节列表获取"""
    print("=" * 80)
    print("测试 Biquge543 爬虫修复后的章节列表获取")
    print("=" * 80)

    novel_url = "https://m.biquge543.com/shu/163512/"
    print(f"测试 URL: {novel_url}")
    print()

    # 创建爬虫实例
    crawler = Biquge543Crawler()

    # 获取章节列表
    print("开始获取章节列表...")
    chapters = await crawler.get_chapter_list(novel_url)

    print()
    print("=" * 80)
    print("测试结果")
    print("=" * 80)
    print(f"总章节数: {len(chapters)}")
    print()

    # 检查前 20 章
    print("前 20 章节:")
    print("-" * 80)
    for i, ch in enumerate(chapters[:20], 1):
        print(f"{i:3d}. {ch['title']}")
        print(f"     URL: {ch['url']}")

    # 检查章节号是否连续性
    print()
    print("检查章节连续性:")
    print("-" * 80)

    if len(chapters) > 0:
        # 提取所有章节号
        import re
        chapter_nums = []
        for ch in chapters:
            match = re.search(r'第(\d+)章', ch['title'])
            if match:
                chapter_nums.append(int(match.group(1)))

        if chapter_nums:
            print(f"最小章节号: {min(chapter_nums)}")
            print(f"最大章节号: {max(chapter_nums)}")

            # 检查是否连续
            expected = set(range(1, max(chapter_nums) + 1))
            actual = set(chapter_nums)
            missing = expected - actual

            if missing:
                print(f"缺失的章节号: {sorted(list(missing))[:20]}{'...' if len(missing) > 20 else ''}")
            else:
                print("章节号连续，没有缺失")

    # 检查是否有重复
    print()
    print("检查是否有重复:")
    print("-" * 80)
    urls = [ch['url'] for ch in chapters]
    if len(urls) == len(set(urls)):
        print("没有重复的章节URL")
    else:
        print(f"发现重复的章节URL！")
        from collections import Counter
        duplicates = Counter(urls)
        for url, count in duplicates.items():
            if count > 1:
                print(f"  {url} (出现 {count} 次)")

    print()
    print("=" * 80)
    print("测试完成")
    print("=" * 80)


if __name__ == "__main__":
    asyncio.run(test_chapter_list())
