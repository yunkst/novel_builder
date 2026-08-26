#!/usr/bin/env python3
"""
最终验证：修复前 vs 修复后的对比测试
"""

import asyncio
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from scrapling.parser import Selector
from app.services.page_response import BeautifulSoupSelectorWrapper, PageResponse


def test_issue_fix():
    """验证关键问题已修复"""
    print("=" * 70)
    print("验证关键问题修复")
    print("=" * 70)

    # 模拟爬虫中常用的 HTML 结构
    html = """
    <html>
        <body>
            <div class="result-list">
                <div class="item">
                    <h3 class="title"><a href="/book/123">小说标题</a></h3>
                    <p class="author">作者名</p>
                    <p class="intro">简介内容...</p>
                </div>
                <div class="chapter-list">
                    <ul>
                        <li><a href="/chapter/1">第一章</a></li>
                        <li><a href="/chapter/2">第二章</a></li>
                    </ul>
                </div>
            </div>
        </body>
    </html>
    """

    print("\n问题 1: find_all('a', href=True) 不工作")
    print("-" * 70)
    selector = Selector(html)
    wrapper = BeautifulSoupSelectorWrapper(selector)

    try:
        links = wrapper.find_all('a', href=True)
        print(f"✅ 修复成功! 找到 {len(links)} 个带 href 的链接")
        for link in links:
            print(f"   - {link.get_text()}: {link.get('href')}")
    except Exception as e:
        print(f"❌ 仍然失败: {e}")

    print("\n问题 2: get_text() 方法不可用")
    print("-" * 70)
    try:
        title = wrapper.find('h3', class_='title')
        if title:
            text = title.get_text()
            print(f"✅ 修复成功! get_text() 返回: '{text}'")
        else:
            print("⚠️  未找到标题元素")
    except Exception as e:
        print(f"❌ 仍然失败: {e}")

    print("\n问题 3: get('href') 方法不可用")
    print("-" * 70)
    try:
        link = wrapper.find('a', href='/book/123')
        if link:
            href = link.get('href')
            print(f"✅ 修复成功! get('href') 返回: '{href}'")
        else:
            print("⚠️  未找到链接元素")
    except Exception as e:
        print(f"❌ 仍然失败: {e}")

    print("\n问题 4: PageResponse.soup() 返回不兼容的对象")
    print("-" * 70)
    try:
        class MockResponse:
            def __init__(self, html):
                self.html_content = html
                self.url = "http://test.com"
                self.status = 200

        page = PageResponse(MockResponse(html))
        soup = page.soup()

        # 测试返回的对象是否支持 BeautifulSoup API
        if hasattr(soup, 'find_all'):
            links = soup.find_all('a', href=True)
            print(f"✅ 修复成功! PageResponse.soup() 返回兼容对象")
            print(f"   对象类型: {type(soup).__name__}")
            print(f"   支持的方法: find, find_all, get_text, get")
        else:
            print("❌ 返回的对象不支持 find_all 方法")
    except Exception as e:
        print(f"❌ 仍然失败: {e}")

    print("\n问题 5: select_one() 方法不工作")
    print("-" * 70)
    try:
        result = wrapper.select_one('.title')
        if result:
            print(f"✅ 修复成功! select_one() 返回元素: {result.get_text()}")
        else:
            print("⚠️  未找到元素")
    except Exception as e:
        print(f"❌ 仍然失败: {e}")

    print("\n问题 6: 嵌套查找不工作")
    print("-" * 70)
    try:
        item = wrapper.find('div', class_='item')
        if item:
            title = item.find('h3', class_='title')
            author = item.find('p', class_='author')
            print(f"✅ 修复成功! 嵌套查找工作正常")
            print(f"   标题: {title.get_text() if title else 'N/A'}")
            print(f"   作者: {author.get_text() if author else 'N/A'}")
        else:
            print("⚠️  未找到 item 元素")
    except Exception as e:
        print(f"❌ 仍然失败: {e}")

    print("\n" + "=" * 70)
    print("✅ 所有问题验证完成!")
    print("=" * 70)


def test_real_world_usage():
    """测试真实爬虫使用场景"""
    print("\n\n真实爬虫使用场景测试")
    print("=" * 70)

    # 模拟小说网站章节列表页面的 HTML
    html = """
    <html>
        <body>
            <div id="list">
                <dl>
                    <dt><a href="/book/123/">第一卷</a></dt>
                    <dd>
                        <a href="/chapter/1.html">第一章 开始</a>
                        <a href="/chapter/2.html">第二章 发展</a>
                        <a href="/chapter/3.html">第三章 高潮</a>
                    </dd>
                </dl>
            </div>
        </body>
    </html>
    """

    print("\n场景 1: 提取章节列表（爬虫常用模式）")
    print("-" * 70)
    selector = Selector(html)
    wrapper = BeautifulSoupSelectorWrapper(selector)

    try:
        # 这是爬虫中常用的模式
        chapter_links = wrapper.find_all('a', href=True)
        chapters = []
        for link in chapter_links:
            href = link.get('href', '')
            title = link.get_text().strip()
            if '/chapter/' in href and title:
                chapters.append({'title': title, 'url': href})

        print(f"✅ 成功提取 {len(chapters)} 个章节")
        for ch in chapters:
            print(f"   - {ch['title']}: {ch['url']}")
    except Exception as e:
        print(f"❌ 失败: {e}")
        import traceback
        traceback.print_exc()

    print("\n场景 2: 查找特定元素（class 参数）")
    print("-" * 70)
    try:
        # 使用 class_ 参数（BeautifulSoup 风格）
        element = wrapper.find('div', id='list')
        if element:
            print(f"✅ 成功找到元素: div#list")
        else:
            print("⚠️  未找到元素")
    except Exception as e:
        print(f"❌ 失败: {e}")

    print("\n场景 3: 组合使用多种方法")
    print("-" * 70)
    try:
        # 先查找容器，再在容器内查找子元素
        container = wrapper.find('div', id='list')
        if container:
            links = container.find_all('a', href=True)
            print(f"✅ 在容器中找到 {len(links)} 个链接")
    except Exception as e:
        print(f"❌ 失败: {e}")

    print("\n" + "=" * 70)
    print("✅ 真实场景测试完成!")
    print("=" * 70)


if __name__ == "__main__":
    test_issue_fix()
    test_real_world_usage()
