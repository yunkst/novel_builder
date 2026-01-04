#!/usr/bin/env python3
"""
微风小说网爬虫
https://m.wfxs.tw

特点：
- 繁体中文内容
- 需要转换为简体中文
- 移动端优化
"""

import asyncio
import re
import urllib.parse
from typing import Any

import opencc
from bs4 import BeautifulSoup

from .base_crawler import BaseCrawler
from .http_client import RequestStrategy, Response


class WfxsCrawler(BaseCrawler):
    """微风小说网爬虫"""

    def __init__(self):
        super().__init__(
            base_url="https://m.wfxs.tw",
            strategy=RequestStrategy.BROWSER  # 使用浏览器模式以绕过反爬虫机制
        )
        # 初始化繁简转换器
        self.converter = opencc.OpenCC('t2s')  # 繁体转简体

    def convert_to_simplified(self, text: str) -> str:
        """转换繁体中文为简体中文"""
        if not text:
            return text
        try:
            return self.converter.convert(text)
        except Exception:
            # 如果转换失败，返回原文
            return text

    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """搜索小说

        Args:
            keyword: 搜索关键词

        Returns:
            小说列表
        """
        # 微风小说网的搜索接口（注意参数名是search不是keyword）
        search_url = f"{self.base_url}/s/"
        params = {
            'search': keyword,  # 正确的参数名
        }

        # 添加重试机制,应对微风小说网的反爬
        max_retries = 3
        retry_delay = 2  # 秒

        for attempt in range(max_retries):
            try:
                # 构建完整的URL
                full_url = f"{search_url}?{urllib.parse.urlencode(params)}"

                response = await self.get_page(full_url, timeout=15)

                if response.status_code != 200:
                    if attempt < max_retries - 1:
                        print(f"搜索失败 (状态码: {response.status_code}),重试 {attempt + 1}/{max_retries}...")
                        await asyncio.sleep(retry_delay)
                        continue
                    return []

                # 解析HTML
                soup = BeautifulSoup(response.content, 'lxml')
                novels = []

                # 解析搜索结果
                # 微风小说网搜索结果结构:
                # - 找所有 /xiaoshuo/ 的链接
                # - 标题在 h3 > a 中
                # - 作者在 h3 后的 p 标签中,格式为 "作者 | 連載"
                all_links = soup.find_all('a', href=True)
                novel_links = [link for link in all_links if '/xiaoshuo/' in link.get('href', '')]

                for link in novel_links:
                    try:
                        # 确保这是 h3 标签内的链接(标题链接)
                        h3_parent = link.find_parent('h3')
                        if not h3_parent:
                            continue

                        title = link.get_text(strip=True)
                        novel_url = link.get('href', '')

                        # 如果是相对路径，转换为绝对路径
                        if novel_url.startswith('/'):
                            novel_url = f"{self.base_url}{novel_url}"

                        # 提取作者 - 找 h3 之后的 p 标签
                        author = "未知"
                        next_sibling = h3_parent.find_next_sibling('p')
                        if next_sibling:
                            text = next_sibling.get_text(strip=True)
                            if '|' in text:
                                # 提取 " | " 之前的作者名
                                author = text.split('|')[0].strip()

                        novels.append({
                            'title': self.convert_to_simplified(title),
                            'author': self.convert_to_simplified(author),
                            'url': novel_url,
                            'source': 'wfxs',
                        })
                    except Exception:
                        continue

                return novels[:10]  # 返回前10个结果

            except Exception as e:
                # 如果是最后一次重试,记录错误并返回空
                if attempt == max_retries - 1:
                    print(f"搜索失败: {e}")
                    return []
                # 否则继续重试
                print(f"搜索失败: {e},重试 {attempt + 1}/{max_retries}...")
                await asyncio.sleep(retry_delay)
                continue

        return []  # 所有重试都失败

    async def get_chapter_list(self, novel_url: str, max_pages: int = 0) -> list[dict[str, Any]]:
        """获取章节列表

        Args:
            novel_url: 小说URL
            max_pages: 最大获取页数,默认为0(获取所有页),设置为1表示仅获取第一页

        Returns:
            章节列表
        """
        try:
            # 从novel_url提取novel_id
            # 格式: https://m.wfxs.tw/xiaoshuo/7840069/
            novel_id_match = re.search(r'/xiaoshuo/(\d+)/', novel_url)
            if not novel_id_match:
                return []

            novel_id = novel_id_match.group(1)
            chapter_list_url = f"{self.base_url}/booklist/{novel_id}.html"

            response = await self.get_page(chapter_list_url, timeout=15)

            if response.status_code != 200:
                return []

            soup = BeautifulSoup(response.content, 'lxml')
            chapters = []

            # 首先检查是否有分页链接
            # 查找包含分页链接的 ul (链接格式: 1~30章, 31~60章 等)
            all_uls = soup.find_all('ul')
            page_links = []

            for ul in all_uls:
                links = ul.find_all('a', href=True)
                for link in links:
                    href = link.get('href', '')
                    text = link.get_text(strip=True)
                    # 匹配分页链接格式: /booklist/7840069/1.html, /booklist/7840069/2.html 等
                    if re.search(rf'/booklist/{novel_id}/\d+\.html', href):
                        # 提取页码
                        page_match = re.search(rf'/booklist/{novel_id}/(\d+)\.html', href)
                        if page_match:
                            page_num = int(page_match.group(1))
                            page_links.append({
                                'page_num': page_num,
                                'url': f"{self.base_url}{href}"
                            })

            # 跳过第一页(第一页URL设计有问题,会重复返回1-30章)
            # 如果没有找到分页链接,说明只有一页,才使用第一页
            if not page_links:
                page_urls = [chapter_list_url]
            else:
                # 按页码排序
                page_links.sort(key=lambda x: x['page_num'])

                # 只使用分页链接,不使用第一页
                page_urls = [link['url'] for link in page_links]

                # 如果 max_pages 不为 0,限制页数
                if max_pages > 0:
                    page_urls = page_urls[:max_pages]

            # 遍历分页获取章节
            import asyncio

            # 关键发现:微风小说网会检测访问频率
            # 解决方案:分批次并行获取,每批之间有延迟

            # 分批处理,每批最多5个页面
            batch_size = 5
            all_results = []

            for batch_start in range(0, len(page_urls), batch_size):
                batch_end = min(batch_start + batch_size, len(page_urls))
                batch_urls = page_urls[batch_start:batch_end]

                print(f"准备获取第 {batch_start+1}-{batch_end}/{len(page_urls)} 页...")

                # 创建当前批次的任务
                tasks = [self._get_chapters_from_page(url) for url in batch_urls]

                # 并行执行当前批次
                print(f"并行获取 {len(batch_urls)} 页...")
                results = await asyncio.gather(*tasks, return_exceptions=True)

                # 处理当前批次结果
                for i, result in enumerate(results):
                    page_num = batch_start + i + 1
                    if isinstance(result, Exception):
                        print(f"  ⚠ 第 {page_num} 页获取失败: {result}")
                    elif result:
                        all_results.extend(result)
                        print(f"  ✓ 第 {page_num} 页: {len(result)} 个章节")

                # 批次之间延迟,避免触发反爬
                if batch_end < len(page_urls):
                    print(f"等待2秒后继续...")
                    await asyncio.sleep(2)

            # 合并所有结果
            chapters.extend(all_results)
            return chapters

        except Exception as e:
            print(f"获取章节列表失败: {e}")
            return []

    async def _get_chapters_from_page(self, page_url: str) -> list[dict[str, Any]]:
        """从单页获取章节列表"""
        try:
            # 为每个请求创建新的Playwright实例,避免被检测
            from playwright.async_api import async_playwright

            async with async_playwright() as p:
                browser = await p.chromium.launch(
                    headless=True,
                    args=["--no-sandbox", "--disable-dev-shm-usage"]
                )

                context = await browser.new_context(
                    user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                    viewport={"width": 1920, "height": 1080},
                    locale="zh-TW",
                )

                page = await context.new_page()
                response = await page.goto(page_url, timeout=15000)

                if response.ok:
                    content = await page.content()
                    await browser.close()
                else:
                    await browser.close()
                    return []

            soup = BeautifulSoup(content, 'lxml')
            chapters = []

            # 解析章节列表(使用现有逻辑)
            all_uls = soup.find_all('ul')

            best_ul = None
            max_chapter_count = 0

            for ul in all_uls:
                chapter_links = ul.find_all('a', href=True)
                chapter_count = 0

                for link in chapter_links:
                    text = link.get_text(strip=True)
                    # 只计算以"第"开头且包含"章"的链接
                    # 排除分页导航(如"1~30章"、"31~60章")
                    if text.startswith('第') and '章' in text and '~' not in text and '～' not in text:
                        chapter_count += 1

                if chapter_count > max_chapter_count:
                    max_chapter_count = chapter_count
                    best_ul = ul

            if best_ul:
                chapter_items = best_ul.find_all('li')
            else:
                chapter_items = []

            for item in chapter_items:
                try:
                    # 在 li 中查找链接
                    link = item.find('a')
                    if not link:
                        continue

                    title = link.get_text(strip=True)
                    chapter_url = link.get('href', '')

                    if not chapter_url:
                        continue

                    # 过滤掉分页导航链接
                    # 只保留以"第"开头且包含"章"的标题
                    if not (title.startswith('第') and '章' in title):
                        continue
                    # 排除范围导航(如"1~30章")
                    if '~' in title or '～' in title:
                        continue

                    # 转换为绝对路径
                    if chapter_url.startswith('/'):
                        chapter_url = f"{self.base_url}{chapter_url}"

                    chapters.append({
                        'title': self.convert_to_simplified(title),
                        'url': chapter_url,
                    })
                except Exception:
                    continue

            return chapters

        except Exception as e:
            print(f"获取章节列表失败: {e}")
            return []

    async def get_chapter_content(self, chapter_url: str) -> dict[str, Any]:
        """获取章节内容

        Args:
            chapter_url: 章节URL

        Returns:
            章节内容
        """
        # 为每个请求创建独立的Playwright实例,避免被检测
        from playwright.async_api import async_playwright

        try:
            async with async_playwright() as p:
                browser = await p.chromium.launch(
                    headless=True,
                    args=[
                        "--no-sandbox",
                        "--disable-dev-shm-usage",
                        "--disable-blink-features=AutomationControlled",  # 隐藏自动化特征
                    ]
                )

                context = await browser.new_context(
                    user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                    viewport={"width": 1920, "height": 1080},
                    locale="zh-TW",
                )

                page = await context.new_page()
                page.set_default_timeout(15000)

                response = await page.goto(chapter_url, timeout=15000)

                if response.ok:
                    content = await page.content()
                    await browser.close()

                    from bs4 import BeautifulSoup
                    soup = BeautifulSoup(content, 'lxml')

                    # 获取章节标题
                    title_elem = soup.select_one('article h1') or soup.select_one('h1')
                    title = title_elem.get_text(strip=True) if title_elem else ''

                    # 获取正文内容
                    article = soup.select_one('article')
                    if not article:
                        return {
                            'title': self.convert_to_simplified(title),
                            'content': '',
                            'success': True,
                        }

                    # 提取段落
                    paragraphs = article.select('p')
                    content_parts = []

                    for p in paragraphs:
                        text = p.get_text(strip=True)
                        if text and not self._should_skip_line(text):
                            content_parts.append(text)

                    content = '\n\n'.join(content_parts)

                    # 检查是否有分页
                    # 微风小说网的分页链接在list > listitem中,文本为"下一頁"
                    # 注意:listitem不是标准HTML标签,BeautifulSoup无法识别,需要用find方法
                    from urllib.parse import urljoin
                    next_page_link = soup.find('a', string=lambda text: text and '下一頁' in text)

                    if not next_page_link:
                        # 备选方案:查找包含 /2.html 的链接
                        all_links = soup.find_all('a', href=True)
                        for link in all_links:
                            href = link.get('href', '')
                            # 找到包含"2.html"的链接,并确保它是章节分页链接(以.html结尾)
                            if '/2.html' in href and href.endswith('.html'):
                                next_page_link = link
                                break

                    if next_page_link:
                        print(f"找到分页链接: {next_page_link.get('href', 'N/A')}")
                        # 如果有分页，获取下一页内容
                        next_page_url = next_page_link.get('href', '')
                        if next_page_url.startswith('/'):
                            next_page_url = urljoin(chapter_url, next_page_url)

                        print(f"准备获取第2页: {next_page_url}")
                        # 使用独立的Playwright实例获取下一页
                        next_page_content = await self._get_next_page_content_with_playwright(next_page_url)
                        print(f"第2页内容长度: {len(next_page_content) if next_page_content else 0}")

                        if next_page_content:
                            content = f"{content}\n\n{next_page_content}"
                            print(f"合并后总长度: {len(content)}")

                    return {
                        'title': self.convert_to_simplified(title),
                        'content': self.convert_to_simplified(content),
                        'success': True,
                    }
                else:
                    await browser.close()
                    return {
                        'title': '',
                        'content': '',
                        'success': False,
                    }

        except Exception as e:
            print(f"获取章节内容失败: {e}")
            return {
                'title': '',
                'content': '',
                'success': False,
            }

    async def _get_next_page_content_with_playwright(self, page_url: str) -> str:
        """使用独立Playwright实例获取下一页内容"""
        from playwright.async_api import async_playwright

        try:
            async with async_playwright() as p:
                browser = await p.chromium.launch(
                    headless=True,
                    args=[
                        "--no-sandbox",
                        "--disable-dev-shm-usage",
                        "--disable-blink-features=AutomationControlled",
                    ]
                )

                context = await browser.new_context(
                    user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                    viewport={"width": 1920, "height": 1080},
                    locale="zh-TW",
                )

                page = await context.new_page()
                page.set_default_timeout(15000)

                response = await page.goto(page_url, timeout=15000)

                if response.ok:
                    content = await page.content()
                    await browser.close()

                    from bs4 import BeautifulSoup
                    soup = BeautifulSoup(content, 'lxml')
                    article = soup.select_one('article')

                    if article:
                        paragraphs = article.select('p')
                        content_parts = []

                        for p in paragraphs:
                            text = p.get_text(strip=True)
                            if text and not self._should_skip_line(text):
                                content_parts.append(text)

                        return '\n\n'.join(content_parts)
                    else:
                        return ''
                else:
                    await browser.close()
                    return ''

        except Exception:
            return ''

    async def _get_next_page_content(self, page_url: str) -> str:
        """获取下一页的内容"""
        try:
            response = await self.get_page(page_url, timeout=15)

            if response.status_code != 200:
                return ''

            soup = BeautifulSoup(response.content, 'lxml')
            article = soup.select_one('article')

            if not article:
                return ''

            paragraphs = article.select('p')
            content_parts = []

            for p in paragraphs:
                text = p.get_text(strip=True)
                if text and not self._should_skip_line(text):
                    content_parts.append(text)

            return '\n\n'.join(content_parts)

        except Exception:
            return ''

    def _should_skip_line(self, text: str) -> bool:
        """判断是否应该跳过这一行"""
        skip_patterns = [
            r'本章完',
            r'^\s*--\s*$',
            r'^\s*===\s*$',
            r'喜欢.*.*.*还喜欢',
            r'^\s*[Ww]eb\s*[Nn]ovel',
        ]

        for pattern in skip_patterns:
            if re.search(pattern, text):
                return True

        return False
