#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import asyncio
import re
import time
import urllib.parse
from typing import List, Dict

import requests
from bs4 import BeautifulSoup

from .base_crawler import BaseCrawler


class AliceSWCrawler(BaseCrawler):
    def __init__(self):
        self.base_url = "https://www.alicesw.com"
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })

    async def search(self, keyword: str) -> List[Dict]:
        """
        异步搜索方法，用于SearchService
        """
        # 在线程池中执行同步的search_novels方法
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self.search_novels, keyword)

    def search_novels(self, keyword: str) -> List[Dict]:
        search_url = f"{self.base_url}/search.html"
        try:
            params = { 'q': keyword, 'f': '_all', 'sort': 'relevance' }
            r = self.session.get(search_url, params=params, timeout=10)
            enc = getattr(r, 'apparent_encoding', None) or r.encoding or 'utf-8'
            if enc and enc.lower() in ['gb2312', 'gbk']:
                enc = 'gbk'
            r.encoding = enc
            if r.status_code != 200:
                return []
            soup = BeautifulSoup(r.text, 'html.parser')
            novels: List[Dict] = []
            result_items = soup.find_all(['div', 'li'], recursive=True)
            for item in result_items:
                title_link = item.find('a', href=re.compile(r'/novel/\d+\.html'))
                if not title_link:
                    continue
                title = title_link.get_text().strip()
                # 去掉搜索结果中的序号（如 "1. "��"2. " 等）
                title = re.sub(r'^\d+\.\s+', '', title)
                href = title_link.get('href', '')
                author = "未知"
                text = item.get_text()
                m = re.search(r'作者[：:]\s*([^\n\r<>/,，、\[\]]+)', text)
                if m:
                    author = m.group(1).strip()
                if author == "未知":
                    al = item.find('a', href=re.compile(r'search\?.*f=author'))
                    if al:
                        author = al.get_text().strip()
                novel_url = urllib.parse.urljoin(self.base_url, href)
                if title and novel_url:
                    novels.append({'title': title, 'author': author, 'url': novel_url})
            # 去重
            seen = set()
            unique = []
            for n in novels:
                if n['title'] not in seen:
                    unique.append(n)
                    seen.add(n['title'])
            return unique[:20]
        except Exception:
            return []

    def get_chapter_list(self, novel_url: str) -> List[Dict]:
        try:
            r = self.session.get(novel_url, timeout=10)
            enc = getattr(r, 'apparent_encoding', None) or r.encoding or 'utf-8'
            if enc and enc.lower() in ['gb2312', 'gbk']:
                enc = 'gbk'
            r.encoding = enc
            if r.status_code != 200:
                return []
            soup = BeautifulSoup(r.text, 'html.parser')

            def extract(any_soup, base):
                results = []
                for a in any_soup.find_all('a', href=True):
                    title = a.get_text().strip()
                    href = a.get('href', '')
                    if re.search(r'^/book/\d+/[^/]+\.html$', href):
                        if (len(title) > 1 and not any(x in title for x in ['首页','分类','排行','小说','文章'])):
                            if re.search(r'第\s*\d+|第[一二三四五六七八九十百千万]+|章|节|卷|楔子|序章|终章|大结局', title):
                                results.append({'title': title, 'url': urllib.parse.urljoin(base, href)})
                return results

            chapters: List[Dict] = []
            m = re.search(r'/novel/(\d+)\.html', novel_url)
            if m:
                novel_id = m.group(1)
                chapter_list_url = f"{self.base_url}/other/chapters/id/{novel_id}.html"
                r2 = self.session.get(chapter_list_url, timeout=10)
                enc2 = getattr(r2, 'apparent_encoding', None) or r2.encoding or 'utf-8'
                if enc2 and enc2.lower() in ['gb2312', 'gbk']:
                    enc2 = 'gbk'
                r2.encoding = enc2
                if r2.status_code == 200:
                    soup2 = BeautifulSoup(r2.text, 'html.parser')
                    chapters.extend(extract(soup2, self.base_url))

            if not chapters:
                read_links = soup.find_all('a', string=re.compile(r'在线阅读|立即阅读|开始阅读|章节列表|全文阅读'))
                if read_links:
                    read_url = urllib.parse.urljoin(novel_url, read_links[0].get('href', ''))
                    r3 = self.session.get(read_url, timeout=10)
                    enc3 = getattr(r3, 'apparent_encoding', None) or r3.encoding or 'utf-8'
                    if enc3 and enc3.lower() in ['gb2312', 'gbk']:
                        enc3 = 'gbk'
                    r3.encoding = enc3
                    if r3.status_code == 200:
                        soup3 = BeautifulSoup(r3.text, 'html.parser')
                        chapters.extend(extract(soup3, read_url))

            if not chapters:
                chapters.extend(extract(soup, novel_url))

            # 去重保持顺序
            seen = set()
            unique = []
            for ch in chapters:
                if ch['url'] not in seen:
                    unique.append(ch)
                    seen.add(ch['url'])
            return unique
        except Exception:
            return []

    def get_chapter_content(self, chapter_url: str) -> Dict:
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
                enc = getattr(r, 'apparent_encoding', None) or r.encoding or 'utf-8'
                if enc and enc.lower() in ['gb2312', 'gbk']:
                    enc = 'gbk'
                r.encoding = enc
                if r.status_code != 200:
                    last_error = f"获取失败，状态码: {r.status_code}"
                    continue

                soup = BeautifulSoup(r.text, 'html.parser')
                title_elem = soup.find('h1') or soup.find('title')
                title = title_elem.get_text().strip() if title_elem else "章节内容"

                # 首选段落解析
                paragraphs = soup.find_all('p')
                content = ''
                if len(paragraphs) > 5:
                    # 过滤掉非正文段落（如导航元素、页面信息等）
                    filter_keywords = ['分类:', '最新章节:', '继续阅读', '上一章', '下一章', '目录', '返回', '书签']
                    filtered_paragraphs = []
                    for p in paragraphs:
                        text = p.get_text().strip()
                        # 跳过太短的段落和包含过滤关键词的段落
                        if len(text) < 10:
                            continue
                        if any(keyword in text for keyword in filter_keywords):
                            continue
                        filtered_paragraphs.append(text)
                    content = '\n'.join(filtered_paragraphs)
                else:
                    # 兜底：尝试常见内容容器
                    selectors = ['div#content','div.content','div.readcontent','div#chaptercontent','div.chapter-content','div.book_con','div.showtxt']
                    content_div = None
                    for selector in selectors:
                        content_div = soup.select_one(selector)
                        if content_div:
                            break
                    if content_div:
                        for s in content_div(["script","style"]):
                            s.decompose()
                        content = content_div.get_text().strip()
                    else:
                        # 兜底：最长div文本
                        divs = soup.find_all('div')
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
                content = re.sub(r'\n\s*\n', '\n', content)
                content = re.sub(r' +', ' ', content)
                if content and len(content) > 100:
                    return {"title": title, "content": content}

                # 内容不够有效，记录并继续重试
                last_error = "未能提取到有效章节内容"
            except Exception as e:
                last_error = str(e)
                continue

        # 多次重试失败，返回错误信息
        return {"title": "章节内容", "content": f"获取章节内容时出现错误: {last_error}"}