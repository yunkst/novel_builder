#!/usr/bin/env python3
import asyncio
from app.services.biquge543_crawler import Biquge543Crawler

async def test():
    crawler = Biquge543Crawler()

    url = 'https://m.biquge543.com/shu/163512/'
    print(f'测试获取章节列表: {url}')

    chapters = await crawler.get_chapter_list(url)

    print(f'\n总共获取 {len(chapters)} 章')

    # 提取章节号
    import re
    chapter_nums = []
    for ch in chapters:
        match = re.search(r'第(\d+)章', ch['title'])
        if match:
            chapter_nums.append(int(match.group(1)))

    print(f'\n提取到的章节号数量: {len(chapter_nums)}')
    if chapter_nums:
        print(f'最小章节号: {min(chapter_nums)}')
        print(f'最大章节号: {max(chapter_nums)}')

        # 检查是否有重复
        seen = set()
        duplicates = []
        for num in chapter_nums:
            if num in seen:
                duplicates.append(num)
            seen.add(num)

        if duplicates:
            print(f'发现重复的章节号: {sorted(set(duplicates))[:20]}... (共{len(set(duplicates))}个重复章节号)')
        else:
            print('没有重复的章节号')

        # 检查是否连续
        expected_nums = list(range(min(chapter_nums), max(chapter_nums) + 1))
        missing_nums = set(expected_nums) - set(chapter_nums)

        if missing_nums:
            print(f'缺失的章节号: {sorted(missing_nums)[:20]}... (共{len(missing_nums)}个缺失章节)')
        else:
            print('章节号连续')

    print(f'\n前5章:')
    for ch in chapters[:5]:
        print(f'  {ch["index"]}. {ch["title"]}')

    print(f'\n最后5章:')
    for ch in chapters[-5:]:
        print(f'  {ch["index"]}. {ch["title"]}')

if __name__ == '__main__':
    asyncio.run(test())
