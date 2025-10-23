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


class ShukugeCrawler(BaseCrawler):
    def __init__(self):
        self.base_url = "http://www.shukuge.com"
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
        # 尝试不同的搜索入口
        try:
            search_url = f"{self.base_url}/Search"
            params = {'wd': keyword}
            r = self.session.get(search_url, params=params, timeout=10)
            enc = getattr(r, 'apparent_encoding', None) or r.encoding or 'utf-8'
            if enc and enc.lower() in ['gb2312', 'gbk']:
                enc = 'gbk'
            r.encoding = enc
            if r.status_code == 200:
                soup = BeautifulSoup(r.text, 'html.parser')
                novels = self._extract_novels(soup, keyword)
                if novels:
                    return novels[:20]

            # 备用入口
            for url in [f"{self.base_url}/modules/article/search.php", f"{self.base_url}/search.php"]:
                if url.endswith('.php'):
                    data = {'searchkey': keyword, 'searchtype': 'all'}
                    r = self.session.post(url, data=data, timeout=10)
                else:
                    params = {'searchkey': keyword, 'searchtype': 'all'}
                    r = self.session.get(url, params=params, timeout=10)
                enc = getattr(r, 'apparent_encoding', None) or r.encoding or 'utf-8'
                if enc and enc.lower() in ['gb2312', 'gbk']:
                    enc = 'gbk'
                r.encoding = enc
                if r.status_code == 200:
                    soup = BeautifulSoup(r.text, 'html.parser')
                    novels = self._extract_novels(soup, keyword)
                    if novels:
                        return novels[:20]
            return []
        except Exception:
            return []

    def _extract_novels(self, soup: BeautifulSoup, keyword: str) -> List[Dict]:
        novels: List[Dict] = []
        all_links = soup.find_all('a', href=True, string=True)
        for link in all_links:
            title = link.get_text().strip()
            href = link.get('href', '')
            if keyword.lower() in title.lower() and any(ind in href for ind in ['/book/', '/read/', '/modules/article']):
                author = "未知"
                parent = link.parent
                if parent:
                    text = parent.get_text()
                    m = re.search(r'作者[：:]\s*([^\s\n\r<>/]+)', text)
                    if m:
                        author = m.group(1).strip()
                novels.append({'title': title, 'author': author, 'url': urllib.parse.urljoin(self.base_url, href)})
        # 去重
        seen = set()
        unique = []
        for n in novels:
            if n['title'] not in seen and len(n['title']) > 1:
                unique.append(n)
                seen.add(n['title'])
        return unique

    def get_chapter_list(self, novel_url: str) -> List[Dict]:
        try:
            def _extract_chapters_from_soup(any_soup: BeautifulSoup, base: str) -> List[Dict]:
                results: List[Dict] = []
                # 优先在常见容器中提取
                container = (any_soup.find('div', id='list') or
                             any_soup.find('div', class_='listmain') or
                             any_soup.find('dl') or
                             any_soup.find('div', class_='book_list') or
                             any_soup.find('ul', class_='chapterlist') or
                             any_soup.find('div', id='readerlist') or
                             any_soup.find('div', class_=re.compile(r'list|chapter|content', re.I)))
                skip_words = ['封面', '图片', '插图', '返回首页', '加入书架', '发表评论', 'txt下载', '在线阅读', '立即下载']
                if container:
                    links = container.find_all('a', href=True)
                    for a in links:
                        title = a.get_text().strip()
                        href = a.get('href', '')
                        if title and href and ('.html' in href or '/book/' in href or '/read/' in href):
                            if len(title) > 1 and not any(sw in title for sw in skip_words):
                                results.append({'title': title, 'url': urllib.parse.urljoin(base, href)})
                    # 若容器内提取足够，直接返回
                    if len(results) >= 5:
                        # 去重保持顺序
                        seen = set()
                        uniq = []
                        for ch in results:
                            if ch['url'] not in seen:
                                uniq.append(ch)
                                seen.add(ch['url'])
                        return uniq

                # 兜底：全局链接扫描 + 章节标题模式
                for a in any_soup.find_all('a', href=True):
                    href = a.get('href', '')
                    title = a.get_text().strip()
                    is_candidate_href = bool(re.search(r'/\d+\.html$|/book/\d+/?|/read/\d+|/chapters?/\d+', href))
                    looks_like_chapter = bool(re.search(r'第\s*\d+|第[一二三四五六七八九十百千万]+|章|节|卷|楔子|序章|终章|大结局', title)) or ('第' in title)
                    if (is_candidate_href and len(title) > 1 and looks_like_chapter and
                        not any(sw in title for sw in skip_words)):
                        results.append({'title': title, 'url': urllib.parse.urljoin(base, href)})

                # 去重保持顺序
                seen = set()
                uniq = []
                for ch in results:
                    if ch['url'] not in seen:
                        uniq.append(ch)
                        seen.add(ch['url'])
                return uniq

            # 1) 访问小说详情页
            r = self.session.get(novel_url, timeout=10)
            enc = getattr(r, 'apparent_encoding', None) or r.encoding or 'utf-8'
            if enc and enc.lower() in ['gb2312', 'gbk']:
                enc = 'gbk'
            r.encoding = enc
            if r.status_code != 200:
                return []
            soup = BeautifulSoup(r.text, 'html.parser')

            # 2) 尝试专用章节列表页：/other/chapters/id/{id}.html（若存在）
            chapters: List[Dict] = []
            novel_id_match = re.search(r'/book/(\d+)/', novel_url)
            if novel_id_match:
                novel_id = novel_id_match.group(1)
                chapter_list_url = f"{self.base_url}/other/chapters/id/{novel_id}.html"
                r2 = self.session.get(chapter_list_url, timeout=10)
                enc2 = getattr(r2, 'apparent_encoding', None) or r2.encoding or 'utf-8'
                if enc2 and enc2.lower() in ['gb2312', 'gbk']:
                    enc2 = 'gbk'
                r2.encoding = enc2
                if r2.status_code == 200:
                    soup2 = BeautifulSoup(r2.text, 'html.parser')
                    chapters = _extract_chapters_from_soup(soup2, chapter_list_url)
                    if chapters:
                        return chapters

            # 3) 若未找到，尝试从详情页中寻找“在线阅读/章节列表”等入口页
            if not chapters:
                read_links = soup.find_all('a', string=re.compile(r'在线阅读|立即阅读|开始阅读|章节列表|全文阅读|阅读目录|目录|全部章节'))
                if read_links:
                    read_url = urllib.parse.urljoin(novel_url, read_links[0].get('href', ''))
                    r3 = self.session.get(read_url, timeout=10)
                    enc3 = getattr(r3, 'apparent_encoding', None) or r3.encoding or 'utf-8'
                    if enc3 and enc3.lower() in ['gb2312', 'gbk']:
                        enc3 = 'gbk'
                    r3.encoding = enc3
                    if r3.status_code == 200:
                        soup3 = BeautifulSoup(r3.text, 'html.parser')
                        chapters = _extract_chapters_from_soup(soup3, read_url)
                        if chapters:
                            return chapters

            # 4) 兜底：直接在详情页提取
            chapters = _extract_chapters_from_soup(soup, novel_url)
            return chapters
        except Exception:
            return []

    def get_chapter_content(self, chapter_url: str) -> Dict:
        """
        抓取章节内容，加入有限重试与指数退避；并在内容为空/过短时重试不同解析策略。
        """
        max_retries = 3
        base_sleep = 0.8
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
                selectors = [
                    'div#content','div.content','div.readcontent','div#chaptercontent','div.chapter-content','div.book_con','div.showtxt'
                ]
                content_div = None
                for selector in selectors:
                    content_div = soup.select_one(selector)
                    if content_div:
                        break
                if not content_div:
                    # 兜底：最长div
                    divs = soup.find_all('div')
                    longest_div = None
                    max_text_length = 0
                    for div in divs:
                        text_length = len(div.get_text())
                        if text_length > max_text_length:
                            max_text_length = text_length
                            longest_div = div
                    if longest_div and max_text_length > 500:
                        content_div = longest_div

                title_elem = soup.find('h1') or soup.find('title')
                title = title_elem.get_text().strip() if title_elem else "章节内容"
                content = ''
                if content_div:
                    for s in content_div(["script","style"]):
                        s.decompose()
                    content = content_div.get_text().strip()

                # 清理与有效性校验
                content = re.sub(r'\n\s*\n', '\n', content)
                content = re.sub(r' +', ' ', content)
                if content and len(content) > 100:
                    return {"title": title, "content": content}

                last_error = "未能提取到有效章节内容"
            except Exception as e:
                last_error = str(e)
                continue

        return {"title": "章节内容", "content": f"获取章节内容时出现错误: {last_error}"}