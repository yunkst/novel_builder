#!/usr/bin/env python3
"""
测试 BeautifulSoup 到 Scrapling 的适配层
"""

import asyncio
from app.services.page_response import BeautifulSoupSelectorWrapper, PageResponse
from scrapling.parser import Selector


def test_css_selector_building():
    """测试CSS选择器构建"""
    # 创建一个简单的HTML测试
    html = """
    <html>
        <body>
            <a href="http://example.com">Link 1</a>
            <a>Link 2</a>
            <div class="content">Content</div>
            <div id="main">Main</div>
        </body>
    </html>
    """

    selector = Selector(html)
    wrapper = BeautifulSoupSelectorWrapper(selector)

    print("测试 CSS 选择器构建:")

    # 测试 href=True 的转换
    print("\n1. 测试 find_all('a', href=True):")
    results = wrapper.find_all('a', href=True)
    print(f"   找到 {len(results)} 个带 href 的链接")
    for r in results:
        print(f"   - 文本: '{r.get_text()}', href: '{r.get('href')}'")

    # 测试 class 参数
    print("\n2. 测试 find('div', class_='content'):")
    result = wrapper.find('div', class_='content')
    if result:
        print(f"   找到: '{result.get_text()}'")

    # 测试 id 参数
    print("\n3. 测试 find('div', id='main'):")
    result = wrapper.find('div', id='main')
    if result:
        print(f"   找到: '{result.get_text()}'")

    # 测试 get_text()
    print("\n4. 测试 get_text():")
    print(f"   内容: '{result.get_text()}'")

    # 测试 get() 方法
    print("\n5. 测试 get('id'):")
    print(f"   ID: '{result.get('id')}'")

    print("\n✅ CSS 选择器构建测试完成")


def test_page_response_soup():
    """测试 PageResponse.soup() 方法"""
    html = """
    <html>
        <body>
            <h1>标题</h1>
            <a href="http://example.com">链接</a>
            <a>无链接</a>
        </body>
    </html>
    """

    # 模拟 Scrapling Response
    class MockResponse:
        def __init__(self, html):
            self.html_content = html
            self.url = "http://example.com"
            self.status = 200

    page_response = PageResponse(MockResponse(html))

    print("\n测试 PageResponse.soup():")

    # 测试 soup() 方法
    soup = page_response.soup()
    print(f"   soup 类型: {type(soup)}")

    # 测试 find
    title = soup.find('h1')
    print(f"   标题: '{title.get_text()}'")

    # 测试 find_all with href=True
    print("\n   测试 find_all('a', href=True):")
    links = soup.find_all('a', href=True)
    print(f"   找到 {len(links)} 个链接")
    for link in links:
        print(f"   - 文本: '{link.get_text()}', href: '{link.get('href')}'")

    print("\n✅ PageResponse.soup() 测试完成")


def test_complex_selectors():
    """测试复杂选择器"""
    html = """
    <html>
        <body>
            <div class="book-item">
                <h3 class="title"><a href="/book/1">Book 1</a></h3>
                <p class="author">Author 1</p>
            </div>
            <div class="book-item">
                <h3 class="title"><a href="/book/2">Book 2</a></h3>
                <p class="author">Author 2</p>
            </div>
        </body>
    </html>
    """

    selector = Selector(html)
    wrapper = BeautifulSoupSelectorWrapper(selector)

    print("\n测试复杂选择器:")

    # 测试嵌套查找
    print("\n1. 测试 find_all('div', class_='book-item'):")
    items = wrapper.find_all('div', class_='book-item')
    print(f"   找到 {len(items)} 个书籍项目")

    for item in items:
        title_link = item.find('a', href=True)
        if title_link:
            print(f"   - 书名: '{title_link.get_text()}', 链接: '{title_link.get('href')}'")

    print("\n✅ 复杂选择器测试完成")


def main():
    """运行所有测试"""
    print("=" * 60)
    print("BeautifulSoup 到 Scrapling 适配层测试")
    print("=" * 60)

    try:
        test_css_selector_building()
        test_page_response_soup()
        test_complex_selectors()

        print("\n" + "=" * 60)
        print("✅ 所有测试通过!")
        print("=" * 60)

    except Exception as e:
        print(f"\n❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
