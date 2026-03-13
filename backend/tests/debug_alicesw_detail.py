#!/usr/bin/env python3
"""
测试AliceSW小说站点详情页结构

使用Playwright访问站点，分析HTML结构，提取小说信息
"""

import asyncio
import re
from urllib.parse import urljoin

from playwright.async_api import async_playwright


async def test_alicesw_site():
    """测试AliceSW站点访问和分析"""

    print("=" * 60)
    print("AliceSW 小说站点详情页结构分析")
    print("=" * 60)

    async with async_playwright() as p:
        # 启动浏览器
        browser = await p.chromium.launch(
            headless=True,
            args=[
                "--no-sandbox",
                "--disable-dev-shm-usage",
            ]
        )

        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1920, "height": 1080},
        )

        page = await context.new_page()

        base_url = "https://www.alicesw.com"

        try:
            # 首先访问首页
            print(f"\n📖 访问首页: {base_url}")
            await page.goto(base_url, timeout=30000)
            await page.wait_for_load_state("networkidle", timeout=10000)

            # 获取首页HTML
            home_html = await page.content()

            print(f"✅ 首页访问成功，HTML长度: {len(home_html)} 字符")

            # 查找搜索框和搜索
            print(f"\n🔍 尝试搜索功能")

            # 查找搜索框
            search_input = await page.query_selector("input[name='q'], input[type='search'], #search, .search-box")

            if search_input:
                # 使用常见关键词搜索
                keyword = "青春"
                await search_input.fill(keyword)

                # 查找搜索按钮
                search_button = await page.query_selector("button[type='submit'], .search-btn, input[type='submit']")

                if search_button:
                    await search_button.click()
                    await page.wait_for_load_state("networkidle", timeout=15000)
                    print(f"✅ 搜索成功，关键词: {keyword}")
                else:
                    # 尝试直接访问搜索页面
                    search_url = f"{base_url}/search.html"
                    print(f"📝 尝试直接访问搜索页面: {search_url}")
                    await page.goto(search_url, timeout=30000)
                    await page.wait_for_load_state("networkidle", timeout=10000)
            else:
                # 尝试直接访问搜索页面
                search_url = f"{base_url}/search.html?q=青春"
                print(f"📝 直接访问搜索URL: {search_url}")
                await page.goto(search_url, timeout=30000)
                await page.wait_for_load_state("networkidle", timeout=10000)

            # 获取搜索结果页HTML
            search_html = await page.content()
            print(f"✅ 搜索结果页加载成功，HTML长度: {len(search_html)} 字符")

            # 从搜索结果中提取第一个小说链接
            print(f"\n📚 分析搜索结果页面，查找小说链接")

            # 查找所有小说链接
            novel_links = await page.query_selector_all("a[href*='/novel/']")

            if novel_links:
                print(f"✅ 找到 {len(novel_links)} 个小说链接")

                # 获取第一个小说的URL
                first_novel_url = await novel_links[0].get_attribute("href")
                first_novel_title = await novel_links[0].inner_text()

                if first_novel_url and not first_novel_url.startswith("http"):
                    first_novel_url = urljoin(base_url, first_novel_url)

                print(f"\n🎯 选择第一个小说进行分析:")
                print(f"   标题: {first_novel_title.strip()}")
                print(f"   URL: {first_novel_url}")

                # 访问小说详情页
                print(f"\n📖 访问小说详情页: {first_novel_url}")
                await page.goto(first_novel_url, timeout=30000)
                await page.wait_for_load_state("networkidle", timeout=10000)

                detail_html = await page.content()
                print(f"✅ 详情页加载成功，HTML长度: {len(detail_html)} 字符")

                # 分析详情页结构
                print(f"\n🔬 分析详情页HTML结构:")
                print("-" * 60)

                # 1. 分析标题
                print(f"\n📌 1. 小说标题:")
                title_selectors = [
                    "h1.book-title",
                    "h1.title",
                    "h1",
                    ".book-name",
                    "title",
                ]

                for selector in title_selectors:
                    try:
                        elem = await page.query_selector(selector)
                        if elem:
                            text = await elem.inner_text()
                            if text and len(text.strip()) > 1:
                                print(f"   ✅ 选择器 '{selector}': {text.strip()}")
                                break
                    except Exception:
                        continue

                # 2. 分析作者信息
                print(f"\n👤 2. 作者信息:")

                # 查找作者链接
                author_links = await page.query_selector_all("a[href*='author'], a[href*='search']")
                if author_links:
                    for i, link in enumerate(author_links[:3]):  # 只显示前3个
                        try:
                            text = await link.inner_text()
                            href = await link.get_attribute("href")
                            if text and len(text.strip()) > 0 and len(text.strip()) < 20:
                                print(f"   可能作者 [{i+1}]: {text.strip()} (href: {href})")
                        except Exception:
                            continue

                # 获取页面文本，查找作者模式
                page_text = await page.inner_text("body")
                author_patterns = [
                    r"作者[：:]\s*([^\n\r<>/,，、\[\]]+)",
                    r"文\s*/\s*([^\n\r]+)",
                ]

                for pattern in author_patterns:
                    match = re.search(pattern, page_text)
                    if match:
                        author = match.group(1).strip()
                        if len(author) < 50:
                            print(f"   ✅ 模式匹配 '{pattern}': {author}")
                            break

                # 3. 分析封面图片
                print(f"\n🖼️ 3. 封面图片:")

                cover_selectors = [
                    ".book-cover img",
                    ".cover img",
                    "img.book-cover",
                    "img[alt*='封面']",
                    "img[alt*='cover']",
                ]

                for selector in cover_selectors:
                    try:
                        elem = await page.query_selector(selector)
                        if elem:
                            src = await elem.get_attribute("src")
                            data_src = await elem.get_attribute("data-src")
                            img_url = src or data_src
                            if img_url:
                                print(f"   ✅ 选择器 '{selector}': {img_url}")
                                break
                    except Exception:
                        continue

                # 查找第一张图片
                if not any([await page.query_selector(s) for s in cover_selectors]):
                    first_img = await page.query_selector("img")
                    if first_img:
                        src = await first_img.get_attribute("src")
                        data_src = await first_img.get_attribute("data-src")
                        img_url = src or data_src
                        if img_url:
                            print(f"   ℹ️  第一张图片: {img_url}")

                # 4. 分析小说简介
                print(f"\n📝 4. 小说简介:")

                desc_selectors = [
                    ".book-description",
                    ".description",
                    ".book-intro",
                    ".intro",
                    ".summary",
                    "div[class*='desc']",
                ]

                for selector in desc_selectors:
                    try:
                        elem = await page.query_selector(selector)
                        if elem:
                            text = await elem.inner_text()
                            if text and len(text.strip()) > 10:
                                print(f"   ✅ 选择器 '{selector}':")
                                print(f"      {text.strip()[:100]}...")
                                break
                    except Exception:
                        continue

                # 5. 分析章节列表获取方式
                print(f"\n📑 5. 章节列表获取方式:")

                # 查找章节列表链接
                chapter_list_links = await page.query_selector_all("a")

                chapter_patterns = [
                    r"查看所有章节|更多章节|更多|目录|查看全部|所有章节",
                    r"/other/chapters/id/\d+\.html",
                    r"chapter|list|index|directory",
                ]

                found_chapter_link = False
                for link in chapter_list_links[:20]:  # 只检查前20个链接
                    try:
                        href = await link.get_attribute("href")
                        text = await link.inner_text()

                        if href and any(re.search(p, text, re.I) for p in chapter_patterns[:1]):
                            full_url = urljoin(base_url, href)
                            print(f"   ✅ 找到章节列表链接:")
                            print(f"      文本: {text.strip()}")
                            print(f"      URL: {full_url}")
                            found_chapter_link = True

                            # 尝试访问章节列表页
                            print(f"\n   📖 访问章节列表页...")
                            await page.goto(full_url, timeout=30000)
                            await page.wait_for_load_state("networkidle", timeout=10000)

                            chapter_html = await page.content()
                            print(f"   ✅ 章节列表页加载成功，HTML长度: {len(chapter_html)} 字符")

                            # 分析章节列表页结构
                            chapter_containers = await page.query_selector_all("div.book_newchap, div[class*='chapter'], div[class*='list']")
                            print(f"   ℹ️  找到 {len(chapter_containers)} 个可能的章节容器")

                            # 查找章节链接
                            chapter_links_on_page = await page.query_selector_all("a[href*='/book/']")
                            print(f"   ℹ️  找到 {len(chapter_links_on_page)} 个章节链接")

                            if chapter_links_on_page:
                                first_chapter_title = await chapter_links_on_page[0].inner_text()
                                first_chapter_href = await chapter_links_on_page[0].get_attribute("href")
                                print(f"   📌 第一个章节:")
                                print(f"      标题: {first_chapter_title.strip()}")
                                print(f"      URL: {urljoin(base_url, first_chapter_href)}")

                            break
                    except Exception:
                        continue

                if not found_chapter_link:
                    # 尝试从URL构造章节列表URL
                    novel_id_match = re.search(r"/novel/(\d+)\.html", first_novel_url)
                    if novel_id_match:
                        novel_id = novel_id_match.group(1)
                        constructed_url = f"{base_url}/other/chapters/id/{novel_id}.html"
                        print(f"   📝 构造章节列表URL: {constructed_url}")

                        try:
                            await page.goto(constructed_url, timeout=30000)
                            await page.wait_for_load_state("networkidle", timeout=10000)

                            if page.url == constructed_url or page.url.endswith(f"/id/{novel_id}.html"):
                                print(f"   ✅ 构造的URL有效")
                            else:
                                print(f"   ❌ 构造的URL无效，重定向到: {page.url}")
                        except Exception as e:
                            print(f"   ❌ 访问构造的URL失败: {e}")

                # 6. 保存HTML样本用于分析
                print(f"\n💾 保存HTML样本用于进一步分析:")
                print("-" * 60)

                # 保存详情页HTML（截取前2000个字符）
                sample_length = 2000
                detail_sample = detail_html[:sample_length]

                print(f"   📄 详情页HTML样本 (前{sample_length}字符):")
                print("   " + "=" * 56)
                for line in detail_sample.split("\n")[:30]:  # 只显示前30行
                    print("   " + line)
                print("   " + "=" * 56)

            else:
                print(f"❌ 未找到小说链接，尝试直接访问一个已知小说URL")

                # 尝试一个常见的小说URL模式
                test_urls = [
                    f"{base_url}/novel/1.html",
                    f"{base_url}/novel/100.html",
                    f"{base_url}/novel/1000.html",
                ]

                for test_url in test_urls:
                    print(f"\n📝 尝试访问: {test_url}")
                    try:
                        response = await page.goto(test_url, timeout=15000)
                        if response and response.status == 200:
                            print(f"✅ 成功访问: {test_url}")
                            await page.wait_for_load_state("networkidle", timeout=10000)
                            break
                    except Exception:
                        print(f"❌ 访问失败")
                        continue

        except Exception as e:
            print(f"\n❌ 测试过程中出现错误: {e}")
            import traceback
            traceback.print_exc()

        finally:
            await browser.close()

    print(f"\n" + "=" * 60)
    print("测试完成")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(test_alicesw_site())
