#!/usr/bin/env python3
"""
Scrapling 集成测试

验证重构后的爬虫系统是否正常工作
"""
import asyncio
import sys
from pathlib import Path

# 添加 app 目录到路径
sys.path.insert(0, str(Path(__file__).parent / "app"))

from services.page_response import PageResponse
from services.scrapling_fetcher import ScraplingFetcher, RequestStrategy, RequestConfig


async def test_fetcher():
    """测试 ScraplingFetcher"""
    print("\n=== 测试 ScraplingFetcher ===")

    # 测试不同的策略
    strategies = [
        RequestStrategy.SIMPLE,
        RequestStrategy.BROWSER,
        RequestStrategy.HYBRID,
    ]

    for strategy in strategies:
        try:
            fetcher = ScraplingFetcher(strategy=strategy)
            print(f"✓ {strategy.name} 策略创建成功")
        except Exception as e:
            print(f"✗ {strategy.name} 策略创建失败: {e}")

    # 测试 STEALTH 策略（需要 Playwright，可能失败）
    try:
        fetcher = ScraplingFetcher(strategy=RequestStrategy.STEALTH)
        print("✓ STEALTH 策略创建成功")
    except Exception as e:
        print(f"⚠ STEALTH 策略创建失败（预期，需要 Playwright 浏览器）: {e}")


async def test_page_response():
    """测试 PageResponse"""
    print("\n=== 测试 PageResponse ===")

    # 创建模拟响应
    mock_response = type('MockResponse', (), {
        'status': 200,
        'status_code': 200,
        'url': 'https://example.com',
        'headers': {},
        'content': '<div class="test"><p>Hello Scrapling</p></div>',  # 使用字符串而非字节
        'text': '<div class="test"><p>Hello Scrapling</p></div>',
        'elapsed': 0.5,
    })()

    fetcher = ScraplingFetcher(strategy=RequestStrategy.SIMPLE)
    page = PageResponse(mock_response, fetcher)

    # 测试属性访问
    assert page.status_code == 200, "状态码错误"
    assert page.url == 'https://example.com', "URL 错误"
    assert '<div' in page.content, "内容错误"
    print("✓ 属性访问正常")

    # 测试 Selector
    soup = page.soup()
    assert soup is not None, "Selector 创建失败"
    print("✓ Selector 创建成功")

    # 测试 CSS 选择器
    test_div = soup.css('.test').first
    assert test_div is not None, "CSS 选择器失败"
    print("✓ CSS 选择器正常")

    # 测试文本提取
    text = test_div.css('::text').get()
    assert 'Hello Scrapling' in text, f"文本提取错误: {text}"
    print("✓ 文本提取正常")


async def test_selector_performance():
    """测试 Selector 性能"""
    print("\n=== 测试 Selector 性能 ===")

    import time
    from scrapling.parser import Selector

    # 创建测试 HTML
    html = ''.join([f'<div class="item-{i}">Item {i}</div>' for i in range(1000)])

    # 测试解析速度
    start = time.time()
    selector = Selector(html)
    parse_time = time.time() - start
    print(f"✓ 解析 1000 个元素耗时: {parse_time * 1000:.2f}ms")

    # 测试查询速度
    start = time.time()
    items = selector.css('div[class^="item-"]')
    query_time = time.time() - start
    print(f"✓ 查询 1000 个元素耗时: {query_time * 1000:.2f}ms")

    assert len(items) == 1000, "查询结果数量错误"


async def test_base_crawler_import():
    """测试 BaseCrawler 导入"""
    print("\n=== 测试 BaseCrawler ===")

    try:
        from services.base_crawler import BaseCrawler
        print("✓ BaseCrawler 导入成功")

        # 测试是否可以创建子类
        class TestCrawler(BaseCrawler):
            async def search_novels(self, keyword: str):
                return []

            async def get_chapter_list(self, novel_url: str):
                return []

            async def get_chapter_content(self, chapter_url: str):
                return {"title": "测试", "content": "测试内容"}

            async def get_novel_info(self, novel_url: str):
                return {"title": "测试小说", "chapters": []}

        crawler = TestCrawler(base_url="https://example.com")
        print("✓ 可以创建 BaseCrawler 子类")
        print(f"✓ Base URL: {crawler.base_url}")
        print(f"✓ Strategy: {crawler.strategy.name}")

    except Exception as e:
        print(f"✗ BaseCrawler 测试失败: {e}")


async def main():
    """主测试函数"""
    print("=" * 60)
    print("Scrapling 集成测试")
    print("=" * 60)

    tests = [
        ("Fetcher 测试", test_fetcher),
        ("PageResponse 测试", test_page_response),
        ("Selector 性能测试", test_selector_performance),
        ("BaseCrawler 测试", test_base_crawler_import),
    ]

    passed = 0
    failed = 0

    for name, test_func in tests:
        try:
            await test_func()
            passed += 1
        except Exception as e:
            print(f"\n✗ {name} 失败: {e}")
            import traceback
            traceback.print_exc()
            failed += 1

    print("\n" + "=" * 60)
    print(f"测试结果: {passed} 通过, {failed} 失败")
    print("=" * 60)

    if failed == 0:
        print("\n✓ 所有测试通过！Scrapling 集成成功！")
        return 0
    else:
        print(f"\n✗ {failed} 个测试失败，请检查错误信息")
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
