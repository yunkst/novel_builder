#!/usr/bin/env python3
"""调试Ddxsmf小说站点结构"""

import asyncio
import sys
import re
sys.path.insert(0, 'D:/myspace/novel_builder/backend')

from app.services.http_client import http_get, RequestConfig, RequestStrategy
from bs4 import BeautifulSoup

async def main():
    base_url = "https://www.ddxsmf.com"

    print("=" * 80)
    print("第一步: 访问首页，寻找小说链接")
    print("=" * 80)

    config = RequestConfig(
        timeout=30,
        strategy=RequestStrategy.SIMPLE
    )

    try:
        response = await http_get(base_url, config)
        print(f"首页状态码: {response.status_code}")
        print(f"首页内容长度: {len(response.content)}")

        # 保存首页HTML用于分析
        with open('D:/myspace/novel_builder/backend/tests/ddxsmf_home.html', 'w', encoding='utf-8') as f:
            f.write(response.content)
        print("首页HTML已保存到: ddxsmf_home.html")

        soup = BeautifulSoup(response.content, 'lxml')

        # 查找小说链接 (格式: /数字ID/)
        all_links = soup.find_all('a', href=True)
        book_links = []

        for link in all_links:
            href = link.get('href', '')
            # 匹配 /数字/ 格式的链接
            if re.match(r'^/\d+/?$', href):
                title = link.get_text(strip=True)
                if title and len(title) > 1:  # 过滤掉单字符链接
                    book_links.append({
                        'href': href,
                        'title': title
                    })

        print(f"\n找到 {len(book_links)} 个可能的小说链接")
        print("前10个:")
        for i, link in enumerate(book_links[:10]):
            full_url = f"{base_url}{link['href']}"
            print(f"  [{i}] {full_url}")
            print(f"      标题: {link['title']}")

        if book_links:
            # 选择第一个小说链接进行详细分析
            test_novel_url = f"{base_url}{book_links[0]['href']}"
            print(f"\n{'=' * 80}")
            print(f"第二步: 分析小说详情页 - {test_novel_url}")
            print(f"{'=' * 80}")

            await analyze_novel_page(test_novel_url, config)
        else:
            print("\n未找到小说链接，尝试分析页面结构...")
            # 分析页面结构
            analyze_page_structure(soup)

    except Exception as e:
        print(f"访问首页失败: {e}")
        import traceback
        traceback.print_exc()

async def analyze_novel_page(novel_url, config):
    """分析小说详情页"""
    try:
        response = await http_get(novel_url, config)
        print(f"详情页状态码: {response.status_code}")
        print(f"详情页内容长度: {len(response.content)}")

        # 保存详情页HTML
        with open('D:/myspace/novel_builder/backend/tests/ddxsmf_novel.html', 'w', encoding='utf-8') as f:
            f.write(response.content)
        print("详情页HTML已保存到: ddxsmf_novel.html")

        soup = BeautifulSoup(response.content, 'lxml')

        print("\n--- 1. 标题分析 ---")
        # 查找标题
        h1_tags = soup.find_all('h1')
        print(f"找到 {len(h1_tags)} 个h1标签:")
        for i, h1 in enumerate(h1_tags):
            text = h1.get_text(strip=True)
            print(f"  h1[{i}]: {text}")

        print("\n--- 2. 作者信息分析 ---")
        # 查找作者信息
        text_content = soup.get_text()
        author_match = re.search(r"作者[：:]\s*([^\s\n\r<>/]+)", text_content)
        if author_match:
            print(f"  通过正则找到作者: {author_match.group(1).strip()}")

        author_links = soup.find_all('a', href=re.compile(r'author'))
        print(f"  找到 {len(author_links)} 个作者链接:")
        for i, link in enumerate(author_links[:3]):
            print(f"    [{i}] {link.get_text(strip=True)} - {link.get('href')}")

        print("\n--- 3. 封面图片分析 ---")
        # 查找图片
        all_images = soup.find_all('img')
        print(f"  找到 {len(all_images)} 个图片:")
        for i, img in enumerate(all_images[:5]):
            src = img.get('src', '') or img.get('data-src', '')
            alt = img.get('alt', '')
            print(f"    [{i}] src={src[:80]} alt={alt}")

        print("\n--- 4. 简介分析 ---")
        # 查找简介
        intro_selectors = [
            "div.book-intro",
            "div.intro",
            "div.description",
            "div#bookintro",
            "p.intro",
        ]
        for selector in intro_selectors:
            elem = soup.select_one(selector)
            if elem:
                text = elem.get_text(strip=True)
                if len(text) > 10:
                    print(f"  选择器 '{selector}' 找到简介:")
                    print(f"    {text[:200]}...")
                    break
        else:
            print("  未找到简介，尝试在页面文本中查找...")
            # 查找包含"简介"、"介绍"等关键词的段落
            p_tags = soup.find_all('p')
            for p in p_tags[:10]:
                text = p.get_text(strip=True)
                if any(keyword in text for keyword in ['简介', '介绍', '内容简介', '描述']):
                    print(f"  找到可能的简介段落: {text[:200]}")
                    break

        print("\n--- 5. 章节列表分析 ---")
        # 查找章节列表
        # 方法1: 查找包含"全部章节"或"最新章节"的标题
        chapter_heading = None
        for heading in soup.find_all(['h2', 'h3', 'h4']):
            if '全部章节' in heading.get_text() or '最新章节' in heading.get_text():
                chapter_heading = heading
                print(f"  找到章节标题: {heading.get_text(strip=True)}")
                break

        if chapter_heading:
            # 查找后续的ul
            next_ul = chapter_heading.find_next_sibling('ul')
            if next_ul:
                chapter_links = next_ul.find_all('a', href=True)
                print(f"  在后续ul中找到 {len(chapter_links)} 个章节链接")
                print(f"  前5个章节:")
                for i, link in enumerate(chapter_links[:5]):
                    print(f"    [{i}] {link.get('href')} - {link.get_text(strip=True)[:50]}")
            else:
                # 在父容器中查找
                parent = chapter_heading.find_parent(['div', 'generic'])
                if parent:
                    chapter_links = parent.find_all('a', href=True)
                    print(f"  在父容器中找到 {len(chapter_links)} 个链接")
                    # 过滤出章节链接
                    chapter_links = [
                        l for l in chapter_links
                        if re.match(r'/\d+/\d+\.html', l.get('href', ''))
                    ]
                    print(f"  过滤后找到 {len(chapter_links)} 个章节链接")
                    print(f"  前5个章节:")
                    for i, link in enumerate(chapter_links[:5]):
                        print(f"    [{i}] {link.get('href')} - {link.get_text(strip=True)[:50]}")
        else:
            print("  未找到章节标题，尝试直接查找章节链接...")
            # 直接查找匹配格式的链接
            all_links = soup.find_all('a', href=True)
            chapter_links = [
                l for l in all_links
                if re.match(r'/\d+/\d+\.html', l.get('href', ''))
            ]
            print(f"  找到 {len(chapter_links)} 个章节链接")
            if chapter_links:
                print(f"  前5个章节:")
                for i, link in enumerate(chapter_links[:5]):
                    print(f"    [{i}] {link.get('href')} - {link.get_text(strip=True)[:50]}")

        print("\n--- 6. 测试章节内容页 ---")
        if chapter_links:
            chapter_url = f"{base_url}{chapter_links[0].get('href')}"
            print(f"  测试章节: {chapter_url}")
            await analyze_chapter_page(chapter_url, config)

    except Exception as e:
        print(f"分析详情页失败: {e}")
        import traceback
        traceback.print_exc()

async def analyze_chapter_page(chapter_url, config):
    """分析章节内容页"""
    try:
        response = await http_get(chapter_url, config)
        print(f"  章节页状态码: {response.status_code}")
        print(f"  章节页内容长度: {len(response.content)}")

        # 保存章节页HTML
        with open('D:/myspace/novel_builder/backend/tests/ddxsmf_chapter.html', 'w', encoding='utf-8') as f:
            f.write(response.content)
        print("  章节页HTML已保存到: ddxsmf_chapter.html")

        soup = BeautifulSoup(response.content, 'lxml')

        print("  --- 章节标题 ---")
        h1_tags = soup.find_all('h1')
        if h1_tags:
            title = h1_tags[0].get_text(strip=True)
            print(f"    标题: {title}")

        print("  --- 章节内容 ---")
        # 查找内容容器
        generics = soup.find_all('generic')
        print(f"    找到 {len(generics)} 个generic标签")

        for i, generic in enumerate(generics):
            text = generic.get_text(strip=True)
            print(f"    generic[{i}] 长度: {len(text)}")
            if len(text) > 100:
                print(f"      内容预览: {text[:200]}")

    except Exception as e:
        print(f"  分析章节页失败: {e}")

def analyze_page_structure(soup):
    """分析页面基本结构"""
    print("\n页面结构分析:")

    # 查找所有主要容器
    print("  主要div容器:")
    divs = soup.find_all('div', limit=20)
    for div in divs[:10]:
        class_attr = div.get('class', [])
        id_attr = div.get('id', '')
        print(f"    div: class={class_attr} id={id_attr}")

    print("  所有链接:")
    links = soup.find_all('a', href=True, limit=30)
    for link in links[:20]:
        href = link.get('href', '')
        text = link.get_text(strip=True)[:30]
        print(f"    {href} -> {text}")

if __name__ == "__main__":
    asyncio.run(main())
