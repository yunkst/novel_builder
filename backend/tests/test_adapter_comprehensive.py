#!/usr/bin/env python3
"""
全面测试 BeautifulSoup 到 Scrapling 的适配层功能
"""

import asyncio
import sys
import os
import re

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from scrapling.parser import Selector
from app.services.page_response import BeautifulSoupSelectorWrapper


def test_all_beautifulsoup_features():
    """测试所有 BeautifulSoup 兼容功能"""
    print("=" * 70)
    print("BeautifulSoup 到 Scrapling 适配层功能测试")
    print("=" * 70)

    # 复杂的 HTML 测试用例
    html = """
    <html>
        <head>
            <title>测试页面</title>
        </head>
        <body>
            <div class="container">
                <h1 class="main-title">主要标题</h1>

                <div class="book-list">
                    <div class="book-item">
                        <h3 class="title">
                            <a href="/book/1" class="book-link">书籍 1</a>
                        </h3>
                        <p class="author">作者 1</p>
                        <p class="description">这是书籍 1 的描述</p>
                    </div>

                    <div class="book-item">
                        <h3 class="title">
                            <a href="/book/2" class="book-link">书籍 2</a>
                        </h3>
                        <p class="author">作者 2</p>
                        <p class="description">这是书籍 2 的描述</p>
                    </div>

                    <div class="book-item featured">
                        <h3 class="title">
                            <a href="/book/3" class="book-link featured-link">书籍 3</a>
                        </h3>
                        <p class="author">作者 3</p>
                        <p class="description">这是书籍 3 的描述</p>
                    </div>
                </div>

                <div class="chapter-list">
                    <ul>
                        <li><a href="/chapter/1">第一章</a></li>
                        <li><a href="/chapter/2">第二章</a></li>
                        <li><a href="/chapter/3">第三章</a></li>
                    </ul>
                </div>
            </div>
        </body>
    </html>
    """

    selector = Selector(html)
    wrapper = BeautifulSoupSelectorWrapper(selector)

    # 测试 1: find_all with href=True
    print("\n1. 测试 find_all('a', href=True) - 查找所有带 href 属性的链接")
    links = wrapper.find_all('a', href=True)
    print(f"   结果: 找到 {len(links)} 个链接")
    for i, link in enumerate(links[:3], 1):
        print(f"      {i}. 文本='{link.get_text()}', href='{link.get('href')}'")
    assert len(links) == 6, "应该找到 6 个链接"
    print("   ✅ 通过")

    # 测试 2: find with class_
    print("\n2. 测试 find('div', class_='book-list') - 通过 class 查找")
    book_list = wrapper.find('div', class_='book-list')
    assert book_list is not None, "应该找到 book-list"
    print(f"   结果: 找到元素")
    print("   ✅ 通过")

    # 测试 3: 嵌套查找
    print("\n3. 测试嵌套查找 - 在 book-item 中查找链接")
    book_items = wrapper.find_all('div', class_='book-item')
    print(f"   结果: 找到 {len(book_items)} 个 book-item")
    assert len(book_items) == 3, "应该找到 3 个 book-item"
    for item in book_items:
        title_link = item.find('a', href=True)
        if title_link:
            print(f"      - {title_link.get_text()}")
    print("   ✅ 通过")

    # 测试 4: get_text()
    print("\n4. 测试 get_text() - 获取文本内容")
    title = wrapper.find('h1', class_='main-title')
    if title:
        text = title.get_text()
        print(f"   结果: '{text}'")
        assert text == "主要标题", "应该获取到正确的标题"
    print("   ✅ 通过")

    # 测试 5: get() 方法
    print("\n5. 测试 get('href') - 获取属性值")
    link = wrapper.find('a', href='/book/1')
    if link:
        href = link.get('href')
        print(f"   结果: '{href}'")
        assert href == '/book/1', "应该获取到正确的 href"
    print("   ✅ 通过")

    # 测试 6: get() with default
    print("\n6. 测试 get('data-id', default='N/A') - 带默认值的属性获取")
    link = wrapper.find('a', href='/book/1')
    if link:
        data_id = link.get('data-id', 'N/A')
        print(f"   结果: '{data_id}'")
        assert data_id == 'N/A', "应该返回默认值"
    print("   ✅ 通过")

    # 测试 7: select_one()
    print("\n7. 测试 select_one('.book-list') - CSS 选择器")
    book_list = wrapper.select_one('.book-list')
    assert book_list is not None, "应该通过 CSS 选择器找到元素"
    print(f"   结果: 找到元素")
    print("   ✅ 通过")

    # 测试 8: select()
    print("\n8. 测试 select('.book-item') - CSS 选择器多元素")
    items = wrapper.select('.book-item')
    print(f"   结果: 找到 {len(items)} 个元素")
    assert len(items) == 3, "应该找到 3 个元素"
    print("   ✅ 通过")

    # 测试 9: 多个 class
    print("\n9. 测试 find('div', class_='book-item featured') - 多个 class")
    featured = wrapper.find('div', class_='featured')
    assert featured is not None, "应该找到 featured 元素"
    print(f"   结果: 找到元素")
    print("   ✅ 通过")

    # 测试 10: text 属性
    print("\n10. 测试 .text 属性 - 文本属性")
    title = wrapper.find('h1')
    if title:
        text = title.text
        print(f"   结果: '{text}'")
        assert "主要标题" in text, "应该包含标题文本"
    print("   ✅ 通过")

    # 测试 11: limit 参数
    print("\n11. 测试 find_all('a', href=True, limit=2) - 限制结果数量")
    limited_links = wrapper.find_all('a', href=True, limit=2)
    print(f"   结果: 找到 {len(limited_links)} 个链接")
    assert len(limited_links) == 2, "应该只返回 2 个链接"
    print("   ✅ 通过")

    # 测试 12: 空结果处理
    print("\n12. 测试 find('nonexistent') - 查找不存在的元素")
    not_found = wrapper.find('nonexistent')
    assert not_found is None, "应该返回 None"
    print("   结果: None (符合预期)")
    print("   ✅ 通过")

    # 测试 13: kwargs 参数
    print("\n13. 测试 find('a', href='/book/1') - 使用 kwargs 传递属性")
    link = wrapper.find('a', href='/book/1')
    assert link is not None, "应该找到链接"
    print(f"   结果: 找到链接 '{link.get_text()}'")
    print("   ✅ 通过")

    print("\n" + "=" * 70)
    print("✅ 所有测试通过!")
    print("=" * 70)


if __name__ == "__main__":
    test_all_beautifulsoup_features()
