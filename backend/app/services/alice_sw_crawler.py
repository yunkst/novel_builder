#!/usr/bin/env python3

import asyncio
import re
import time
import urllib.parse
import urllib3

import requests
from bs4 import BeautifulSoup

# Disable SSL verification warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

from .base_crawler import BaseCrawler

# Try to import Playwright, but make it optional
try:
    from playwright.async_api import async_playwright
    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    PLAYWRIGHT_AVAILABLE = False


class AliceSWCrawler(BaseCrawler):
    def __init__(self):
        self.base_url = "https://www.alicesw.com"
        self.session = requests.Session()
        # Use more realistic headers to avoid anti-bot detection
        self.session.headers.update(
            {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
                "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
                "Accept-Encoding": "gzip, deflate, br",
                "DNT": "1",
                "Connection": "keep-alive",
                "Upgrade-Insecure-Requests": "1",
                "Sec-Fetch-Dest": "document",
                "Sec-Fetch-Mode": "navigate",
                "Sec-Fetch-Site": "none",
                "Sec-Fetch-User": "?1",
                "Cache-Control": "max-age=0"
            }
        )
        # Disable SSL verification to fix connection issues in Docker container
        self.session.verify = False
        # Set up custom adapter with more permissive SSL settings
        from requests.adapters import HTTPAdapter
        from urllib3.util.retry import Retry
        import ssl

        # Create a custom SSL context that doesn't verify certificates
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE

        # Mount with custom SSL context and more retries
        adapter = HTTPAdapter(
            max_retries=Retry(
                total=5,
                backoff_factor=0.5,
                status_forcelist=[500, 502, 503, 504],
                allowed_methods=["GET", "POST"]
            )
        )
        self.session.mount('https://', adapter)
        self.session.mount('http://', adapter)

    async def search(self, keyword: str) -> list[dict]:
        """
        异步搜索方法，用于SearchService
        优先使用 Playwright，如果不可用则回退到 requests
        """
        if PLAYWRIGHT_AVAILABLE:
            try:
                # Try Playwright first
                return await self.search_novels_playwright(keyword)
            except Exception as e:
                # Fall back to requests if Playwright fails
                import logging
                logging.warning(f"Playwright search failed, falling back to requests: {str(e)}")

        # 在线程池中执行同步的search_novels方法
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self.search_novels, keyword)

    async def search_novels_playwright(self, keyword: str) -> list[dict]:
        """
        使用 Playwright 进行搜索，绕过 SSL 和反爬虫检测
        """
        if not PLAYWRIGHT_AVAILABLE:
            raise ImportError("Playwright is not available")

        async with async_playwright() as p:
            # Launch browser with settings to avoid detection
            browser = await p.chromium.launch(
                headless=True,
                args=[
                    '--no-sandbox',
                    '--disable-dev-shm-usage',
                    '--disable-gpu',
                    '--disable-web-security',
                    '--disable-features=VizDisplayCompositor',
                    '--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                ]
            )

            try:
                page = await browser.new_page()

                # Set additional headers to look like a real browser
                await page.set_extra_http_headers({
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
                    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
                    "Accept-Encoding": "gzip, deflate, br",
                    "DNT": "1",
                    "Connection": "keep-alive",
                    "Upgrade-Insecure-Requests": "1",
                    "Sec-Fetch-Dest": "document",
                    "Sec-Fetch-Mode": "navigate",
                    "Sec-Fetch-Site": "none",
                    "Sec-Fetch-User": "?1",
                    "Cache-Control": "max-age=0"
                })

                # Navigate to search page
                search_url = f"{self.base_url}/search.html"
                await page.goto(search_url, timeout=30000)

                # Fill in search form
                await page.fill('input[name="q"]', keyword)

                # Submit search form
                await page.press('input[name="q"]', 'Enter')

                # Wait for results to load
                await page.wait_for_timeout(3000)

                # Extract search results
                novels = []

                # Look for search result items
                result_items = await page.query_selector_all('.list-group-item')

                if not result_items:
                    # Try alternative selectors
                    result_items = await page.query_selector_all('div[class*="result"], li[class*="result"]')

                for item in result_items:
                    try:
                        # Extract title and link
                        title_link = await item.query_selector('a[href*="/novel/"]')
                        if not title_link:
                            continue

                        title = await title_link.inner_text()
                        title = title.strip()
                        # 去掉搜索结果中的序号
                        title = re.sub(r"^\d+\.\s+", "", title)

                        if len(title) < 2:
                            continue

                        href = await title_link.get_attribute('href')
                        novel_url = urllib.parse.urljoin(self.base_url, href)

                        # Extract author
                        author = "未知"
                        item_text = await item.inner_text()

                        # Try to find author using patterns
                        author_patterns = [
                            r"作者[：:]\s*([^\n\r<>/,，、\[\]]+)",
                            r"<a[^>]*>([^<]+)</a>\s*作者[：:]\s*([^\n\r<>/,，、\[\]]+)",
                        ]

                        for pattern in author_patterns:
                            m = re.search(pattern, item_text)
                            if m:
                                author = m.group(1).strip() if len(m.groups()) == 1 else m.group(2).strip()
                                break

                        # Skip if author looks like navigation
                        if any(nav in author for nav in ["首页", "分类", "排行", "小说", "文章"]):
                            continue

                        if title and novel_url:
                            novels.append({"title": title, "author": author, "url": novel_url})

                    except Exception:
                        continue

                # 去重保持顺序
                seen_titles = set()
                unique = []
                for n in novels:
                    if n["title"] not in seen_titles:
                        unique.append(n)
                        seen_titles.add(n["title"])

                return unique[:20]

            finally:
                await browser.close()

    def search_novels(self, keyword: str) -> list[dict]:
        search_url = f"{self.base_url}/search.html"
        try:
            # Ensure proper URL encoding for the keyword
            from urllib.parse import quote
            encoded_keyword = quote(keyword, safe='')
            params = {"q": keyword, "f": "_all", "sort": "relevance"}
            r = self.session.get(search_url, params=params, timeout=10)
            enc = getattr(r, "apparent_encoding", None) or r.encoding or "utf-8"
            if enc and enc.lower() in ["gb2312", "gbk"]:
                enc = "gbk"
            r.encoding = enc
            if r.status_code != 200:
                return []
            soup = BeautifulSoup(r.text, "html.parser")
            novels: list[dict] = []

            # Look for search result items specifically in the list-group div
            result_items = soup.find_all("div", class_="list-group-item")
            if not result_items:
                # Fallback: try to find any div or li containing novel links
                result_items = soup.find_all(["div", "li"], recursive=True)

            for item in result_items:
                title_link = item.find("a", href=re.compile(r"/novel/\d+\.html"))
                if not title_link:
                    continue
                title = title_link.get_text().strip()
                # 去掉搜索结果中的序号（如 "1. " 或 "2. " 等）
                title = re.sub(r"^\d+\.\s+", "", title)

                # Skip if title is too short or contains only navigation elements
                if len(title) < 2 or any(nav in title for nav in ["首页", "分类", "排行", "小说", "文章"]):
                    continue

                href = title_link.get("href", "")
                author = "未知"
                text = item.get_text()

                # Try to find author using multiple patterns
                author_patterns = [
                    r"作者[：:]\s*([^\n\r<>/,，、\[\]]+)",
                    r"<a[^>]*>([^<]+)</a>\s*作者[：:]\s*([^\n\r<>/,，、\[\]]+)",
                ]

                for pattern in author_patterns:
                    m = re.search(pattern, text)
                    if m:
                        author = m.group(1).strip() if len(m.groups()) == 1 else m.group(2).strip()
                        break

                # If still unknown, try to find author link
                if author == "未知":
                    al = item.find("a", href=re.compile(r"search\?.*f=author"))
                    if al:
                        author = al.get_text().strip()

                # Skip if author is still unknown or looks like navigation
                if author == "未知" or any(nav in author for nav in ["首页", "分类", "排行", "小说", "文章"]):
                    continue

                novel_url = urllib.parse.urljoin(self.base_url, href)
                if title and novel_url:
                    novels.append({"title": title, "author": author, "url": novel_url})

            # 去重保持顺序
            seen_titles = set()
            unique = []
            for n in novels:
                if n["title"] not in seen_titles:
                    unique.append(n)
                    seen_titles.add(n["title"])
            return unique[:20]
        except Exception as e:
            # Log the error for debugging
            import logging
            logging.error(f"AliceSW search error for keyword '{keyword}': {str(e)}")
            return []

    def get_chapter_list(self, novel_url: str) -> list[dict]:
        try:
            r = self.session.get(novel_url, timeout=10)
            enc = getattr(r, "apparent_encoding", None) or r.encoding or "utf-8"
            if enc and enc.lower() in ["gb2312", "gbk"]:
                enc = "gbk"
            r.encoding = enc
            if r.status_code != 200:
                return []
            soup = BeautifulSoup(r.text, "html.parser")

            def extract(any_soup, base):
                results = []
                for a in any_soup.find_all("a", href=True):
                    title = a.get_text().strip()
                    href = a.get("href", "")
                    if (re.search(r"^/book/\d+/[^/]+\.html$", href) and
                        len(title) > 1 and not any(
                            x in title for x in ["首页", "分类", "排行", "小说", "文章"]
                        ) and re.search(
                            r"第\s*\d+|第[一二三四五六七八九十百千万]+|章|节|卷|楔子|序章|终章|大结局",
                            title,
                        )):
                        results.append(
                            {
                                "title": title,
                                "url": urllib.parse.urljoin(base, href),
                            }
                        )
                return results

            chapters: list[dict] = []
            m = re.search(r"/novel/(\d+)\.html", novel_url)
            if m:
                novel_id = m.group(1)
                chapter_list_url = f"{self.base_url}/other/chapters/id/{novel_id}.html"
                r2 = self.session.get(chapter_list_url, timeout=10)
                enc2 = getattr(r2, "apparent_encoding", None) or r2.encoding or "utf-8"
                if enc2 and enc2.lower() in ["gb2312", "gbk"]:
                    enc2 = "gbk"
                r2.encoding = enc2
                if r2.status_code == 200:
                    soup2 = BeautifulSoup(r2.text, "html.parser")
                    chapters.extend(extract(soup2, self.base_url))

            if not chapters:
                read_links = soup.find_all(
                    "a",
                    string=re.compile(r"在线阅读|立即阅读|开始阅读|章节列表|全文阅读"),
                )
                if read_links:
                    read_url = urllib.parse.urljoin(
                        novel_url, read_links[0].get("href", "")
                    )
                    r3 = self.session.get(read_url, timeout=10)
                    enc3 = (
                        getattr(r3, "apparent_encoding", None) or r3.encoding or "utf-8"
                    )
                    if enc3 and enc3.lower() in ["gb2312", "gbk"]:
                        enc3 = "gbk"
                    r3.encoding = enc3
                    if r3.status_code == 200:
                        soup3 = BeautifulSoup(r3.text, "html.parser")
                        chapters.extend(extract(soup3, read_url))

            if not chapters:
                chapters.extend(extract(soup, novel_url))

            # 去重保持顺序
            seen = set()
            unique = []
            for ch in chapters:
                if ch["url"] not in seen:
                    unique.append(ch)
                    seen.add(ch["url"])
            return unique
        except Exception:
            return []

    def get_chapter_content(self, chapter_url: str) -> dict:
        """
        抓取章节内容，加入有限重试与指数退避；并在内容为空/过短时重试不同解析策略。
        """
        max_retries = 3
        base_sleep = 0.6
        last_error = None
        for attempt in range(max_retries):
            try:
                time.sleep(base_sleep * (1 + attempt))
                r = self.session.get(chapter_url, timeout=10)
                enc = getattr(r, "apparent_encoding", None) or r.encoding or "utf-8"
                if enc and enc.lower() in ["gb2312", "gbk"]:
                    enc = "gbk"
                r.encoding = enc
                if r.status_code != 200:
                    last_error = f"获取失败，状态码: {r.status_code}"
                    continue

                soup = BeautifulSoup(r.text, "html.parser")
                title_elem = soup.find("h1") or soup.find("title")
                title = title_elem.get_text().strip() if title_elem else "章节内容"

                # 首选段落解析
                paragraphs = soup.find_all("p")
                content = ""
                if len(paragraphs) > 5:
                    # 过滤掉非正文段落（如导航元素、页面信息等）
                    filter_keywords = [
                        "分类:",
                        "最新章节:",
                        "继续阅读",
                        "上一章",
                        "下一章",
                        "目录",
                        "返回",
                        "书签",
                    ]
                    filtered_paragraphs = []
                    for p in paragraphs:
                        text = p.get_text().strip()
                        # 跳过太短的段落和包含过滤关键词的段落
                        if len(text) < 10:
                            continue
                        if any(keyword in text for keyword in filter_keywords):
                            continue
                        filtered_paragraphs.append(text)
                    content = "\n".join(filtered_paragraphs)
                else:
                    # 兜底：尝试常见内容容器
                    selectors = [
                        "div#content",
                        "div.content",
                        "div.readcontent",
                        "div#chaptercontent",
                        "div.chapter-content",
                        "div.book_con",
                        "div.showtxt",
                    ]
                    content_div = None
                    for selector in selectors:
                        content_div = soup.select_one(selector)
                        if content_div:
                            break
                    if content_div:
                        for s in content_div(["script", "style"]):
                            s.decompose()
                        content = content_div.get_text().strip()
                    else:
                        # 兜底：最长div文本
                        divs = soup.find_all("div")
                        longest_div = None
                        max_text_length = 0
                        for div in divs:
                            text_length = len(div.get_text())
                            if text_length > max_text_length:
                                max_text_length = text_length
                                longest_div = div
                        if longest_div and max_text_length > 500:
                            content = longest_div.get_text().strip()

                # 清理与有效性校验
                content = re.sub(r"\n\s*\n", "\n", content)
                content = re.sub(r" +", " ", content)
                if content and len(content) > 100:
                    return {"title": title, "content": content}

                # 内容不够有效，记录并继续重试
                last_error = "未能提取到有效章节内容"
            except Exception as e:
                last_error = str(e)
                continue

        # 多次重试失败，返回错误信息
        return {"title": "章节内容", "content": f"获取章节内容时出现错误: {last_error}"}
