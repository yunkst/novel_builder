#!/usr/bin/env python3
"""
快速测试 BeautifulSoup 到 Scrapling 的适配层
"""

import asyncio
from scrapling.parser import Selector
from app.services.page_response import BeautifulSoupSelectorWrapper, PageResponse


def test_adapter():
    """测试适配层的关键功能"""
    # 测试 HTML
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

    print("测试 1: 基本功能")
    selector = Selector(html)
    wrapper = BeautifulSoupSelectorWrapper(selector)

    # 测试 find_all with href=True
    links = wrapper.find_all('a', href=True)
    print(f"  找到 {len(links)} 个链接")
    for link in links:
        print(f"    - '{link.get_text()}' -> {link.get('href')}")

    print("\n测试 2: 嵌套查找")
    items = wrapper.find_all('div', class_='book-item')
    print(f"  找到 {len(items)} 个书籍项目")
    for item in items:
        title_link = item.find('a', href=True)
        author = item.find('p', class_='author')
        if title_link and author:
            print(f"    - {title_link.get_text()} by {author.get_text()}")

    print("\n测试 3: PageResponse.soup()")
    class MockResponse:
        def __init__(self, html):
            self.html_content = html
            self.url = "http://test.com"
            self.status = 200

    page = PageResponse(MockResponse(html))
    soup = page.soup()

    # 测试 find
    title = soup.find('h3', class_='title')
    if title:
        print(f"  找到标题: {title.get_text()}")

    # 测试 find_all with href=True
    links = soup.find_all('a', href=True)
    print(f"  找到 {len(links)} 个链接")

    print("\n✅ 所有测试通过!")


if __name__ == "__main__":
    test_adapter()
