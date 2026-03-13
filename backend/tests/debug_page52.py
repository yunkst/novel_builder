#!/usr/bin/env python3
import asyncio
import re
from app.services.biquge543_crawler import Biquge543Crawler

async def test():
    crawler = Biquge543Crawler()
    novel_id = "163512"
    url = f"https://m.biquge543.com/shu/{novel_id}_52/"

    print(f'获取第52页: {url}')
    response = await crawler.get_page(url, custom_headers=crawler.custom_headers, timeout=30)
    soup = response.soup()

    # 查找所有章节链接
    all_links = soup.find_all("a", href=re.compile(rf"/chapter/{novel_id}/\d+\.html"))

    print(f'\n找到 {len(all_links)} 个章节链接\n')

    for i, link in enumerate(all_links, 1):
        title = link.get_text(strip=True)
        href = link.get("href")

        # 尝试提取章节号
        chapter_num_match = re.search(r'第(\d+)章', title)
        if chapter_num_match:
            chapter_num = chapter_num_match.group(1)
        else:
            chapter_num = "N/A"

        print(f'{i}. [{chapter_num}] {title}')
        print(f'   URL: {href}')

if __name__ == '__main__':
    asyncio.run(test())
