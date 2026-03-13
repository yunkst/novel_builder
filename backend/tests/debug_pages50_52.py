#!/usr/bin/env python3
import asyncio
import re
from app.services.biquge543_crawler import Biquge543Crawler

async def test():
    crawler = Biquge543Crawler()
    novel_id = "163512"

    # 检查多页内容
    for page_num in [50, 51, 52]:
        url = f"https://m.biquge543.com/shu/{novel_id}_{page_num}/"
        print(f'=== 第{page_num}页 ===')
        response = await crawler.get_page(url, custom_headers=crawler.custom_headers, timeout=30)
        soup = response.soup()

        all_links = soup.find_all("a", href=re.compile(rf"/chapter/{novel_id}/\d+\.html"))

        chapter_nums = []
        for link in all_links:
            title = link.get_text(strip=True)
            chapter_num_match = re.search(r'第(\d+)章', title)
            if chapter_num_match:
                chapter_nums.append(int(chapter_num_match.group(1)))

        if chapter_nums:
            print(f'找到章节: {sorted(chapter_nums)}')
        else:
            print('没有找到章节')
        print()

if __name__ == '__main__':
    asyncio.run(test())
