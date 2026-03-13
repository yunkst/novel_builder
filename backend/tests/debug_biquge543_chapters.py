#!/usr/bin/env python3
import asyncio
from app.services.biquge543_crawler import Biquge543Crawler

async def test():
    crawler = Biquge543Crawler()

    url = 'https://m.biquge543.com/shu/163512/'
    print(f'测试获取章节列表: {url}')

    chapters = await crawler.get_chapter_list(url)

    print(f'\n总共获取 {len(chapters)} 章')
    if chapters:
        print(f'第1章: {chapters[0]["title"]}')
        print(f'最后1章: {chapters[-1]["title"]}')
        print(f'\n前10章:')
        for ch in chapters[:10]:
            print(f'  {ch["index"]}. {ch["title"]}')

if __name__ == '__main__':
    asyncio.run(test())
