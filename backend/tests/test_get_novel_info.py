#!/usr/bin/env python3
"""
测试所有爬虫的 get_novel_info 方法
在容器内运行: docker exec novel_builder-backend-1 python tests/test_get_novel_info.py
"""

import asyncio
from app.services.crawler_factory import get_enabled_crawlers

# 测试URL - 需要手动更新为有效的小说URL
TEST_URLS = {
    "alice_sw": "https://www.alicesw.com/novel/12345.html",
    "shukuge": "http://www.shukuge.com/23_23333/",
    "xspsw": "https://m.xspsw.com/xianshishuwu_5/",
    "wdscw": "https://www.5dscw.com/book_66899/",
    "wodeshucheng": "https://www.wodeshucheng.net/book/8230/",
    "smxku": "https://www.smxku.com/book/29786/",
    "wfxs": "https://m.wfxs.tw/book/112345/",
    "ddxsmf": "https://www.ddxsmf.com/book_12345/",
}


async def test_crawler(site_name: str, crawler, url: str):
    """测试单个爬虫"""
    print(f"\n{'='*60}")
    print(f"测试 {site_name} 爬虫")
    print(f"URL: {url}")
    print(f"{'='*60}")

    try:
        result = await crawler.get_novel_info(url)

        print(f"✅ 标题: {result.get('title', 'N/A')}")
        print(f"✅ 作者: {result.get('author', 'N/A')}")
        print(f"✅ 封面: {'有' if result.get('cover_url') else '无'}")
        print(f"✅ 简介: {result.get('description', 'N/A')[:50]}..." if result.get('description') else "✅ 简介: 无")
        print(f"✅ 章节数: {len(result.get('chapters', []))}")

        if result.get('chapters'):
            print(f"   前3章:")
            for i, ch in enumerate(result['chapters'][:3]):
                print(f"   {i+1}. {ch.get('title', 'N/A')}")

        return True

    except Exception as e:
        print(f"❌ 失败: {e}")
        import traceback
        traceback.print_exc()
        return False


async def main():
    """主测试函数"""
    crawlers = get_enabled_crawlers()

    print(f"找到 {len(crawlers)} 个启用的爬虫")

    results = {}

    for site_name, crawler in crawlers.items():
        if site_name in TEST_URLS:
            url = TEST_URLS[site_name]
            success = await test_crawler(site_name, crawler, url)
            results[site_name] = success
        else:
            print(f"\n⚠️  {site_name} 没有配置测试URL")

    print(f"\n{'='*60}")
    print("测试结果汇总:")
    print(f"{'='*60}")
    for site, success in results.items():
        status = "✅ 通过" if success else "❌ 失败"
        print(f"{site}: {status}")


if __name__ == "__main__":
    asyncio.run(main())
