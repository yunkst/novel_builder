#!/usr/bin/env python3
"""
重构版5dscw爬虫

使用网络请求抽象层，专注于业务逻辑实现
"""

import asyncio
import re
import urllib.parse
from typing import Any, Dict, List, Optional

from .enhanced_base_crawler import EnhancedBaseCrawler
from .http_client import RequestConfig, RequestStrategy


class WdscwCrawlerRefactored(EnhancedBaseCrawler):
    """重构版5dscw小说网站爬虫"""

    def __init__(self):
        super().__init__(
            base_url="https://www.5dscw.com",
            strategy=RequestStrategy.SIMPLE  # 使用简单HTTP请求
        )

        # 自定义请求头，模拟真实浏览器
        self.custom_headers = {
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
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

        # 搜索引擎配置
        self.search_base_url = "https://www.sososhu.com"

    async def search_novels(self, keyword: str) -> List[Dict[str, Any]]:
        """搜索小说"""
        try:
            # 使用外部搜索引擎API
            from urllib.parse import urlencode
            params = {
                'q': keyword,
                'site': '5dscw'
            }
            search_url = f"{self.search_base_url}/?{urlencode(params)}"

            response = await self.get_page(search_url, custom_headers=self.custom_headers, timeout=30)
            if response.status_code != 200:
                return []

            soup = response.soup()

            # 解析搜索结果
            novels = []
            novel_links = soup.find_all('a', href=re.compile(r'www\.5dscw\.com/book_\d+'))

            for link in novel_links:
                title = link.get_text(strip=True)
                href = link.get('href')
                if title and href and len(title) > 2:
                    novels.append({
                        'title': title,
                        'url': href,
                        'author': '',  # 5dscw的搜索结果中作者信息不明显
                        'cover': '',  # 暂时无法获取封面
                        'description': '',  # 暂时无法获取简介
                        'source': '5dscw'
                    })

            # 去重
            seen_urls = set()
            unique_novels = []
            for novel in novels:
                if novel['url'] not in seen_urls:
                    seen_urls.add(novel['url'])
                    unique_novels.append(novel)

            return unique_novels[:20]  # 限制返回数量

        except Exception as e:
            print(f"搜索小说失败: {e}")
            return []

    async def get_chapter_list(self, novel_url: str) -> List[Dict[str, Any]]:
        """获取章节列表"""
        try:
            response = await self.get_page(novel_url, custom_headers=self.custom_headers, timeout=30)
            if response.status_code != 200:
                return []

            soup = response.soup()

            # 提取小说标题
            title_elem = soup.find('h1')
            novel_title = title_elem.get_text(strip=True) if title_elem else "未知标题"

            # 查找章节列表
            chapters = []

            # 多种策略查找完整章节列表
            chapter_links = []

            # 策略1: 查找包含"完整章节列表"或"章节目录"的元素
            complete_section_patterns = [
                lambda x: x and '完整章节列表' in x,
                lambda x: x and '章节目录' in x,
                lambda x: x and '全部章节' in x,
                lambda x: x and '目录' in x and len(x) < 20  # 避免匹配过长的文本
            ]

            for pattern in complete_section_patterns:
                complete_section = soup.find('dt', string=pattern)
                if not complete_section:
                    complete_section = soup.find('div', string=pattern)
                if not complete_section:
                    complete_section = soup.find('h2', string=pattern)
                if not complete_section:
                    complete_section = soup.find('h3', string=pattern)

                if complete_section:
                    # 查找父级容器或后续兄弟元素中的章节链接
                    # 尝试多种容器类型
                    containers_to_check = [
                        complete_section.find_parent('dl'),
                        complete_section.find_parent('div'),
                        complete_section.find_parent('section')
                    ]

                    for container in containers_to_check:
                        if container:
                            links = container.find_all('a', href=re.compile(r'/book_\d+/\d+\.html'))
                            if len(links) > 20:  # 如果找到的链接数量较多，认为是完整章节列表
                                chapter_links = links
                                break

                    # 如果在容器中没找到足够多的链接，尝试查找后续兄弟元素
                    if len(chapter_links) <= 20:
                        chapter_links = complete_section.find_all_next_siblings('a', href=re.compile(r'/book_\d+/\d+\.html'))

                    # 如果找到了足够的章节链接，就使用这个策略
                    if len(chapter_links) > 20:
                        break

            # 策略2: 如果策略1没找到足够的链接，查找所有链接并去重
            if len(chapter_links) <= 20:
                all_chapter_links = soup.find_all('a', href=re.compile(r'/book_\d+/\d+\.html'))

                # 过滤掉明显不是章节的链接
                filtered_links = []
                for link in all_chapter_links:
                    title = link.get_text(strip=True)
                    href = link.get('href', '')

                    # 跳过明显不是章节的链接
                    if (len(title) > 2 and
                        not any(skip in title.lower() for skip in ['首页', '书库', '分类', '排行', '登录', '注册']) and
                        re.match(r'/book_\d+/\d+\.html', href)):
                        filtered_links.append(link)

                chapter_links = filtered_links

            for i, link in enumerate(chapter_links):
                chapter_title = link.get_text(strip=True)
                chapter_url = urllib.parse.urljoin(self.base_url, link.get('href'))

                if chapter_title and chapter_url:
                    chapters.append({
                        'title': chapter_title,
                        'url': chapter_url,
                        'index': i + 1
                    })

            # 按index排序
            chapters.sort(key=lambda x: x['index'])
            return chapters

        except Exception as e:
            print(f"获取章节列表失败: {e}")
            return []

    async def get_chapter_content(self, chapter_url: str) -> Dict[str, Any]:
        """获取章节内容"""
        try:
            response = await self.get_page(chapter_url, custom_headers=self.custom_headers, timeout=30)
            if response.status_code != 200:
                return {"title": "", "content": ""}

            soup = response.soup()

            # 提取章节标题
            title_elem = soup.find('h1')
            title = title_elem.get_text(strip=True) if title_elem else ""

            # 提取章节内容
            chapter_content = self._extract_chapter_content(soup)

            return {
                "title": title,
                "content": chapter_content
            }

        except Exception as e:
            print(f"获取章节内容失败: {e}")
            return {"title": "", "content": ""}

    def _extract_chapter_content(self, soup) -> str:
        """提取章节内容的辅助方法"""
        content = ""

        # 尝试多种可能的内容容器
        content_selectors = [
            'div.content',  # 标准内容div
            'div#content',  # ID为content的div
            'div[id*="content"]',  # ID包含content的div
            'div[class*="content"]',  # class包含content的div
            'div[id*="chapter"]',  # ID包含chapter的div
            'div[class*="chapter"]',  # class包含chapter的div
        ]

        content_div = None
        for selector in content_selectors:
            content_div = soup.select_one(selector)
            if content_div:
                break

        # 如果没找到，尝试查找包含多个段落的div
        if not content_div:
            divs = soup.find_all('div')
            for div in divs:
                # 跳过明显不是内容的div
                if div.get('class') and any(cls in ['nav', 'menu', 'header', 'footer', 'sidebar'] for cls in div.get('class', [])):
                    continue

                paragraphs = div.find_all(['p', 'div'])
                text_content = div.get_text(strip=True)

                # 如果包含足够多的文本内容，可能是正文区域
                if len(text_content) > 300 and len(paragraphs) >= 2:
                    content_div = div
                    break

        if content_div:
            # 移除广告和无关元素
            for ad in content_div.find_all(['script', 'style', 'ins', 'iframe', 'noscript', 'form']):
                ad.decompose()

            # 提取文本内容
            paragraphs = content_div.find_all(['p', 'div'])
            if paragraphs:
                content_parts = []
                for p in paragraphs:
                    text = p.get_text(strip=True)
                    if text and len(text) > 10:  # 过滤掉太短的段落
                        content_parts.append(text)

                content = '\n\n'.join(content_parts)
            else:
                content = content_div.get_text('\n', strip=True)

        # 清理内容
        if content:
            # 移除常见的广告词汇和无用文本
            content = re.sub(r'·[\d.]*\\?[\\\/]?[小小说说]?网[′\'`]?_?[无无]?错?内?容?\.?', '', content)
            content = re.sub(r'[\\\/]0\.[0-9]*\\?[\\\/]?[小小说说]?网[′\'`]?_?[无无]?错?内?容?\.?', '', content)
            content = re.sub(r'(?:温馨提示|热门推荐|本章未完|请点击下一页).*$', '', content, flags=re.MULTILINE)
            content = re.sub(r'搜索[:：][^\n]+$', '', content, flags=re.MULTILINE)
            content = re.sub(r'本章未完.*?请点击下一页.*$', '', content, flags=re.MULTILINE | re.DOTALL)
            content = re.sub(r'www\.[^\s]+\s*$', '', content, flags=re.MULTILINE)
            content = re.sub(r'网址:[^\s]+\s*$', '', content, flags=re.MULTILINE)
            content = re.sub(r'\n\s*\n', '\n\n', content)
            content = re.sub(r'^\s+|\s+$', '', content)
            content = re.sub(r' +', ' ', content)

        return content

    def _parse_html(self, html_content: str):
        """解析HTML内容的辅助方法"""
        try:
            from bs4 import BeautifulSoup
            return BeautifulSoup(html_content, 'html.parser')
        except ImportError:
            # 如果没有BeautifulSoup，使用简单的字符串处理
            return None


# 为了向后兼容，创建别名
WdscwCrawler = WdscwCrawlerRefactored