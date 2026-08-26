#!/usr/bin/env python3
from app.services.crawler_factory import ShukugeCrawler
import asyncio


async def main():
    crawler = ShukugeCrawler()
    print(f"爬虫类型: {type(crawler).__name__}")
    print(f"爬虫站点: {crawler.base_url}")

    # 使用一个已知的有效测试URL
    test_url = "http://www.shukuge.com/book/47804/"
    print(f"\n测试URL: {test_url}")

    print("\n========== 测试get_novel_info ==========")
    info = await crawler.get_novel_info(test_url)

    print(f"标题: {info.get('title')}")
    print(f"作者: {info.get('author')}")
    print(f"封面URL: {info.get('cover_url')}")

    desc = info.get("description")
    if desc:
        print(f"简介: {desc[:200]}...")
    else:
        print("简介: 无")

    chapters = info.get("chapters", [])
    print(f"章节数: {len(chapters)}")
    if chapters:
        print("前3章:")
        for ch in chapters[:3]:
            title = ch.get('title', 'N/A')
            url = ch.get('url', 'N/A')
            print(f"  - {title}: {url}")
        if len(chapters) > 3:
            print(f"  ... 还有 {len(chapters) - 3} 章")
        if len(chapters) > 0:
            print(f"最后一章: {chapters[-1].get('title', 'N/A')}")

    print("\n========== 验证结果 ==========")
    print(f"✓ 标题提取: {'成功' if info.get('title') else '失败'}")
    print(f"✓ 作者提取: {'成功' if info.get('author') else '失败'}")
    print(f"✓ 封面URL提取: {'成功' if info.get('cover_url') else '失败'}")
    print(f"✓ 简介提取: {'成功' if desc else '失败'}")
    print(f"✓ 章节列表获取: {'成功' if len(chapters) > 0 else '失败'}")


if __name__ == "__main__":
    asyncio.run(main())
