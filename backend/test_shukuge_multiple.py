#!/usr/bin/env python3
from app.services.crawler_factory import ShukugeCrawler
import asyncio
import httpx
from bs4 import BeautifulSoup


async def test_multiple_novels():
    crawler = ShukugeCrawler()

    async with httpx.AsyncClient(timeout=30.0, follow_redirects=True) as client:
        response = await client.get("http://www.shukuge.com")
        soup = BeautifulSoup(response.text, "lxml")

        novel_links = soup.find_all("a", href=lambda x: x and "/book/" in x)
        print(f"找到 {len(novel_links)} 个小说链接\n")

        # 测试前3个小说
        for i, link in enumerate(novel_links[:3]):
            test_url = "http://www.shukuge.com" + link["href"]
            print(f"========== 测试小说 {i+1} ==========")
            print(f"URL: {test_url}")

            info = await crawler.get_novel_info(test_url)

            print(f"标题: {info.get('title')}")
            print(f"作者: {info.get('author')}")
            print(f"封面URL: {info.get('cover_url')}")

            desc = info.get("description")
            if desc:
                print(f"简介: {desc[:150]}...")
            else:
                print("简介: 无")

            chapters = info.get("chapters", [])
            print(f"章节数: {len(chapters)}")

            # 验证结果
            print("验证结果:")
            print(f"  标题: {'OK' if info.get('title') else 'FAIL'}")
            print(f"  作者: {'OK' if info.get('author') else 'FAIL'}")
            print(f"  封面: {'OK' if info.get('cover_url') else 'FAIL'}")
            print(f"  简介: {'OK' if desc else 'FAIL'}")
            print(f"  章节: {'OK' if len(chapters) > 0 else 'FAIL'}")
            print()


if __name__ == "__main__":
    asyncio.run(test_multiple_novels())
