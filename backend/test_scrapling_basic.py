#!/usr/bin/env python3
"""
简单 Scrapling 功能测试

验证核心功能是否正常工作
"""

import asyncio
from scrapling import Fetcher, Selector


async def test_fetcher():
    """测试 Fetcher 功能"""
    print("=== 测试 Fetcher ===\n")

    try:
        # 创建 Fetcher
        fetcher = Fetcher()
        print("✓ Fetcher 创建成功")

        # 测试基本请求
        response = await asyncio.to_thread(
            lambda: fetcher.get('https://httpbin.org/html', timeout=10)
        )
        print(f"✓ 请求成功")
        print(f"  状态码: {response.status}")
        print(f"  URL: {response.url}")
        print(f"  HTML 长度: {len(response.html)}")

        # 测试 Selector
        selector = Selector(response.html)
        print(f"✓ Selector 创建成功")

        # 测试 CSS 选择器
        title = selector.css('title::text').get()
        print(f"✓ CSS 选择器成功: {title}")

        return True

    except Exception as e:
        print(f"✗ 测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False


async def test_selector_performance():
    """测试 Selector 性能"""
    print("\n=== 测试 Selector 性能 ===\n")

    import time

    # 创建测试 HTML
    html = ''.join([f'<div class="item-{i}">Item {i}</div>' for i in range(1000)])

    # 测试解析速度
    start = time.time()
    selector = Selector(html)
    parse_time = time.time() - start_time
    print(f"✓ 解析 1000 个元素耗时: {parse_time * 1000:.2f}ms")

    # 测试查询速度
    start = time.time()
    items = selector.css('div[class^="item-"]')
    query_time = time.time() - start_time
    print(f"✓ 查询 1000 个元素耗时: {query_time * 1000:.2f}ms")
    print(f"✓ 找到 {len(items)} 个元素")


async def main():
    """主测试函数"""
    print("="*60)
    print("Scrapling 核心功能测试")
    print("="*60)

    # 测试 Fetcher
    await test_fetcher()

    # 测试 Selector 性能
    await test_selector_performance()

    print("\n" + "="*60)
    print("测试完成！")
    print("="*60)


if __name__ == "__main__":
    asyncio.run(main())
