#!/usr/bin/env python3
"""
测试Wodeshucheng站点小说详情页结构分析
"""

import asyncio
import sys
from pathlib import Path

# 添加项目路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.wodeshucheng_crawler import WodeshuchengCrawler
from bs4 import BeautifulSoup


async def analyze_wodeshucheng_site():
    """分析Wodeshucheng站点结构"""
    print("=" * 80)
    print("Wodeshucheng站点结构分析")
    print("=" * 80)
    print()

    crawler = WodeshuchengCrawler()

    # 测试URL - 先访问主页
    print("1. 访问主页: https://www.wodeshucheng.net")
    print("-" * 80)
    try:
        response = await crawler.get_page("https://www.wodeshucheng.net")
        if response.success:
            print("✓ 主页访问成功")
            soup = response.soup()

            # 查找小说链接
            print("\n查找小说链接...")
            novel_links = []
            for a in soup.find_all("a", href=True):
                href = a.get("href", "")
                text = a.get_text().strip()
                # 查找可能是小说详情页的链接
                if href and ("/xiaoshuo/" in href or "/book/" in href) and text:
                    if len(text) > 2 and len(text) < 50:
                        full_url = crawler._build_url(href)
                        novel_links.append({"title": text, "url": full_url})

            if novel_links:
                print(f"找到 {len(novel_links)} 个小说链接，选择第一个进行分析:")
                test_novel = novel_links[0]
                print(f"  标题: {test_novel['title']}")
                print(f"  URL: {test_novel['url']}")
                print()

                # 分析小说详情页
                await analyze_novel_detail_page(crawler, test_novel['url'])
            else:
                print("未找到小说链接，尝试分类页面...")
                await analyze_category_page(crawler)
        else:
            print(f"✗ 主页访问失败: {response.error}")
    except Exception as e:
        print(f"✗ 访问主页时发生错误: {e}")

    print("\n" + "=" * 80)
    print("分析完成")
    print("=" * 80)


async def analyze_category_page(crawler):
    """分析分类页面"""
    print("\n2. 访问分类页面: https://www.wodeshucheng.net/xuanhuanxiaoshuo/")
    print("-" * 80)
    try:
        response = await crawler.get_page("https://www.wodeshucheng.net/xuanhuanxiaoshuo/")
        if response.success:
            print("✓ 分类页面访问成功")
            soup = response.soup()

            # 查找小说列表
            print("\n查找小说列表...")
            novel_links = []

            # 尝试多种选择器
            selectors = [
                "div.item a",
                "div.book-item a",
                "li a[href*='/xiaoshuo/']",
                "a[href*='/book/']",
            ]

            for selector in selectors:
                links = soup.select(selector)
                print(f"  选择器 '{selector}' 找到 {len(links)} 个链接")

                for a in links[:10]:  # 只取前10个
                    href = a.get("href", "")
                    text = a.get_text().strip()
                    if href and text:
                        full_url = crawler._build_url(href)
                        if full_url not in [x['url'] for x in novel_links]:
                            novel_links.append({"title": text, "url": full_url})

            if novel_links:
                print(f"\n共找到 {len(novel_links)} 个小说链接")
                test_novel = novel_links[0]
                print(f"选择第一个小说进行分析:")
                print(f"  标题: {test_novel['title']}")
                print(f"  URL: {test_novel['url']}")
                print()

                await analyze_novel_detail_page(crawler, test_novel['url'])
            else:
                print("✗ 未找到小说链接")
        else:
            print(f"✗ 分类页面访问失败: {response.error}")
    except Exception as e:
        print(f"✗ 访问分类页面时发生错误: {e}")


async def analyze_novel_detail_page(crawler, novel_url):
    """分析小说详情页结构"""
    print(f"\n3. 分析小说详情页: {novel_url}")
    print("-" * 80)

    try:
        response = await crawler.get_page(novel_url)
        if not response.success:
            print(f"✗ 页面访问失败: {response.error}")
            return

        soup = response.soup()
        html_content = str(soup)

        # 保存HTML用于分析
        output_file = Path(__file__).parent / "debug_wodeshucheng_page.html"
        output_file.write_text(html_content, encoding='utf-8')
        print(f"✓ 页面HTML已保存到: {output_file}")

        # 分析页面结构
        print("\n页面结构分析:")
        print()

        # 1. 查找标题
        print("1. 小说标题:")
        title_found = False
        title_selectors = ["h1", "h2", "h3", ".book-title", ".title", "#bookname"]
        for selector in title_selectors:
            elem = soup.select_one(selector)
            if elem:
                text = elem.get_text().strip()
                if text:
                    print(f"  ✓ 选择器 '{selector}': {text[:100]}")
                    title_found = True
                    break
        if not title_found:
            print("  ✗ 未找到标题")

        # 2. 查找作者
        print("\n2. 作者信息:")
        author_found = False
        author_patterns = [
            ("div.author", "div.author"),
            ("p.author", "p.author"),
            (".book-author", ".book-author"),
            ("span.author", "span.author"),
        ]
        for selector, desc in author_patterns:
            elem = soup.select_one(selector)
            if elem:
                text = elem.get_text().strip()
                if text:
                    print(f"  ✓ 选择器 '{desc}': {text[:100]}")
                    author_found = True
                    break
        if not author_found:
            print("  ✗ 未找到作者信息")

        # 3. 查找封面
        print("\n3. 封面图片:")
        cover_found = False
        cover_selectors = ["img.book-cover", "img.cover", ".book-img img", "#bookimg img", "img[src*='cover']"]
        for selector in cover_selectors:
            elem = soup.select_one(selector)
            if elem:
                src = elem.get("src", "") or elem.get("data-src", "")
                if src:
                    print(f"  ✓ 选择器 '{selector}': {src[:100]}")
                    cover_found = True
                    break
        if not cover_found:
            print("  ✗ 未找到封面图片")

        # 4. 查找简介
        print("\n4. 小说简介:")
        desc_found = False
        desc_selectors = ["div.book-intro", "div.intro", "div.description", "#bookintro", "p.intro"]
        for selector in desc_selectors:
            elem = soup.select_one(selector)
            if elem:
                text = elem.get_text().strip()
                if text and len(text) > 10:
                    print(f"  ✓ 选择器 '{selector}': {text[:200]}...")
                    desc_found = True
                    break
        if not desc_found:
            print("  ✗ 未找到简介")

        # 5. 查找章节列表
        print("\n5. 章节列表:")
        chapter_found = False
        chapter_selectors = ["div.box_con", "#list", "div.chapter-list", ".catalog"]
        for selector in chapter_selectors:
            elem = soup.select_one(selector)
            if elem:
                links = elem.find_all("a", href=True)
                if links:
                    print(f"  ✓ 选择器 '{selector}' 找到 {len(links)} 个章节链接")
                    print(f"  前3个章节:")
                    for i, link in enumerate(links[:3], 1):
                        title = link.get_text().strip()
                        href = link.get("href", "")
                        print(f"    {i}. {title} ({href})")
                    chapter_found = True
                    break
        if not chapter_found:
            print("  ✗ 未找到章节列表")

        # 6. 测试get_novel_info方法
        print("\n6. 测试get_novel_info方法:")
        print("-" * 80)
        try:
            novel_info = await crawler.get_novel_info(novel_url)
            print("✓ get_novel_info执行成功")
            print(f"  标题: {novel_info.get('title', 'N/A')}")
            print(f"  作者: {novel_info.get('author', 'N/A')}")
            print(f"  封面: {novel_info.get('cover_url', 'N/A')[:80] if novel_info.get('cover_url') else 'N/A'}")
            print(f"  简介: {novel_info.get('description', 'N/A')[:100]}...")
            print(f"  章节数: {len(novel_info.get('chapters', []))}")

            # 验证提取结果
            issues = []
            if not novel_info.get('title') or novel_info['title'] == '未知小说':
                issues.append("标题提取失败")
            if not novel_info.get('author') or novel_info['author'] == '未知作者':
                issues.append("作者提取失败")
            if not novel_info.get('description'):
                issues.append("简介提取失败")
            if not novel_info.get('chapters'):
                issues.append("章节列表提取失败")

            if issues:
                print(f"\n⚠ 发现以下问题:")
                for issue in issues:
                    print(f"  - {issue}")
            else:
                print(f"\n✓ 所有信息提取成功!")

        except Exception as e:
            print(f"✗ get_novel_info执行失败: {e}")
            import traceback
            traceback.print_exc()

    except Exception as e:
        print(f"✗ 分析页面时发生错误: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(analyze_wodeshucheng_site())
