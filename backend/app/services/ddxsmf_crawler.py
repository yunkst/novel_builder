#!/usr/bin/env python3
"""
顶点小说爬虫
https://www.ddxsmf.com

站点特点：
- 使用外部 Bing 搜索 (site:www.ddxsmf.com keyword)
- 小说详情页格式: /数字ID/
- 章节链接格式: /数字ID/数字.html
- 章节内容直接以文本节点形式呈现
"""

import logging
import re
import urllib.parse
from typing import Any

from .base_crawler import BaseCrawler, RequestStrategy
from .cache_decorator import cacheable
from .cache_types import CacheType

logger = logging.getLogger(__name__)


class DdxsmfCrawler(BaseCrawler):
    """顶点小说爬虫"""

    def __init__(self):
        super().__init__(
            base_url="https://www.ddxsmf.com",
            strategy=RequestStrategy.SIMPLE,  # 使用简单的 requests 请求
        )

    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """搜索小说 - 由于该网站使用外部搜索，这里返回空结果
        用户可以直接访问小说详情页URL来获取章节内容
        """
        try:
            # 尝试直接使用关键词构造可能的URL
            # 格式: https://www.ddxsmf.com/搜索/
            # 但该站点没有内部搜索功能，所以返回空结果
            return []

        except Exception as e:
            logger.error(f"搜索失败: {e}")
            return []

    @cacheable(
        cache_type=CacheType.CHAPTER_LIST,
        key_params=["novel_url"],
    )
    async def get_chapter_list(
        self, novel_url: str, force_refresh: bool = False
    ) -> list[dict[str, Any]]:
        """获取章节列表"""
        try:
            # 确保URL完整
            if not novel_url.startswith('http'):
                novel_url = f"{self.base_url}{novel_url}"

            # 移除尾部斜杠
            novel_url = novel_url.rstrip('/')

            response = await self.get_page(novel_url, timeout=15)
            if response.status_code != 200:
                return []

            soup = response.soup()
            chapters = []

            # 查找章节列表 - 章节链接格式: /数字ID/数字.html
            # 直接使用正则表达式过滤所有链接
            chapter_items = []
            all_links = soup.find_all('a', href=True)

            for link in all_links:
                href = link.get('href', '')
                # 匹配 /数字ID/数字.html 格式
                if href and re.match(r'^/\d+/\d+\.html$', href):
                    chapter_items.append(link)

            for item in chapter_items:
                try:
                    title = item.get_text(strip=True)
                    chapter_url = item.get('href', '')

                    if not chapter_url or not title:
                        continue

                    # 过滤导航链接
                    skip_words = ['首页', '书架', '收藏', '目录', '排行榜', '阅读记录', '返回']
                    if any(word in title for word in skip_words):
                        continue

                    # 转换为绝对路径
                    if chapter_url.startswith('/'):
                        chapter_url = f"{self.base_url}{chapter_url}"

                    chapters.append({
                        'title': title,
                        'url': chapter_url,
                    })
                except Exception:
                    continue

            return chapters

        except Exception as e:
            logger.error(f"获取章节列表失败: {e}")
            return []

    @cacheable(
        cache_type=CacheType.CHAPTER_CONTENT,
        key_params=["chapter_url"],
        min_valid_length=300,
    )
    async def get_chapter_content(
        self, chapter_url: str, novel_url: str = "", force_refresh: bool = False
    ) -> dict[str, Any]:
        """获取章节内容"""
        try:
            # 确保URL完整
            if not chapter_url.startswith('http'):
                chapter_url = f"{self.base_url}{chapter_url}"

            response = await self.get_page(chapter_url, timeout=15)
            if response.status_code != 200:
                return {
                    'title': '',
                    'content': '',
                    'success': False,
                }

            soup = response.soup()

            # 获取章节标题
            title_elem = soup.find('h1')
            title = title_elem.get_text(strip=True) if title_elem else ''

            # 清理标题
            title = re.sub(r'_顶点小说.*$', '', title)
            title = title.strip()

            # 查找章节内容容器
            # 内容通常在包含章节标题的generic容器中，以文本节点形式呈现
            content_container = None

            # 方法1：查找包含大量文本的generic容器
            generics = soup.find_all('generic')
            for generic in generics:
                text = generic.get_text()
                # 查找包含章节标题的容器
                if title and title in text:
                    # 检查是否有足够的内容
                    if len(text) > 200:  # 至少200个字符
                        content_container = generic
                        break

            # 方法2：如果没有找到，尝试查找特定class的容器
            if not content_container:
                for div in soup.find_all('div'):
                    text = div.get_text()
                    if title and title in text and len(text) > 200:
                        # 确保不是导航或其他容器
                        if not any(skip in text for skip in ['首页', '书架', '排行榜', '推荐']):
                            content_container = div
                            break

            if not content_container:
                return {
                    'title': title,
                    'content': '',
                    'success': True,
                }

            # 提取段落内容
            content_parts = []

            # 顶点小说的内容以文本节点形式存在
            # 使用 Scrapling 的方法获取文本内容
            text = content_container.get_text("\n", strip=True)
            for line in text.split("\n"):
                line = line.strip()
                if line and not self._should_skip_line(line):
                    content_parts.append(line)

            content = '\n\n'.join(content_parts)

            return {
                'title': title,
                'content': content,
                'success': True,
            }

        except Exception as e:
            logger.error(f"获取章节内容失败: {e}")
            return {
                'title': '',
                'content': '',
                'success': False,
            }

    async def get_novel_info(self, novel_url: str) -> dict[str, Any]:
        """
        获取小说详细信息和章节列表

        Args:
            novel_url: 小说详情页URL

        Returns:
            包含小说信息和章节列表的字典
        """
        try:
            # 确保URL完整
            if not novel_url.startswith('http'):
                novel_url = f"{self.base_url}{novel_url}"

            # 移除尾部斜杠
            novel_url = novel_url.rstrip('/')

            response = await self.get_page(novel_url, timeout=15)
            if response.status_code != 200:
                return {
                    "title": "未知小说",
                    "author": "未知作者",
                    "url": novel_url,
                    "cover_url": "",
                    "description": "",
                    "chapters": [],
                }

            soup = response.soup()

            # 提取小说基本信息
            title = self._extract_novel_title(soup)
            author = self._extract_novel_author(soup)
            cover_url = self._extract_novel_cover(soup)
            description = self._extract_novel_description(soup)

            # 获取章节列表（复用现有方法）
            chapters = await self.get_chapter_list(novel_url)

            return {
                "title": title,
                "author": author,
                "url": novel_url,
                "cover_url": cover_url,
                "description": description,
                "chapters": chapters,
            }

        except Exception as e:
            logger.error(f"{self.__class__.__name__}获取小说信息失败: {e!s}")
            return {
                "title": "未知小说",
                "author": "未知作者",
                "url": novel_url,
                "cover_url": "",
                "description": "",
                "chapters": [],
            }

    def _extract_novel_title(self, soup) -> str:
        """提取小说标题"""
        title_elem = soup.find('h1')
        if title_elem:
            title = title_elem.get_text(strip=True)
            if title:
                # 清理标题中的网站名称等后缀
                title = re.sub(r'_顶点小说.*$', '', title).strip()
                title = re.sub(r'-.*$', '', title).strip()
                return title
        return "未知小说"

    def _extract_novel_author(self, soup) -> str:
        """提取小说作者"""
        # 尝试从页面文本中提取作者信息
        text = soup.get_text()
        author_match = re.search(r"作者[：:]\s*([^\s\n\r<>/]+)", text)
        if author_match:
            return author_match.group(1).strip()

        # 尝试查找作者链接或元素
        author_elem = soup.find('a', href=re.compile(r'/author/'))
        if author_elem:
            return author_elem.get_text(strip=True)

        return "未知作者"

    def _extract_novel_cover(self, soup) -> str:
        """提取小说封面URL"""
        # 尝试查找封面图片
        cover_selectors = [
            ".bookimg2 img",  # 顶点小说使用的class
            "img.book-cover",
            "img.cover",
            ".book-img img",
            "#bookimg img",
        ]

        for selector in cover_selectors:
            cover_elem = soup.select_one(selector)
            if cover_elem:
                cover_src = cover_elem.get("src", "") or cover_elem.get("data-src", "")
                if cover_src:
                    # 转换为绝对URL
                    if cover_src.startswith("/"):
                        return f"{self.base_url}{cover_src}"
                    elif cover_src.startswith("http"):
                        return cover_src

        return ""

    def _extract_novel_description(self, soup) -> str:
        """提取小说简介"""
        # 尝试多种简介选择器
        desc_selectors = [
            "div.book-intro",
            "div.intro",
            "div.description",
            "div#bookintro",
            "p.intro",
        ]

        for selector in desc_selectors:
            desc_elem = soup.select_one(selector)
            if desc_elem:
                desc = desc_elem.get_text().strip()
                if desc and len(desc) > 10:
                    # 清理简介文本
                    desc = re.sub(r"\s+", " ", desc)
                    return desc[:500]

        return ""

    def _should_skip_line(self, text: str) -> bool:
        """判断是否应该跳过这一行"""
        skip_patterns = [
            r'本章完',
            r'^\s*--\s*$',
            r'^\s*===\s*$',
            r'^\s*\*\*\*\s*$',
            r'请收藏本站',
            r'本章结束',
            r'更多小说',
            r'PC站点如章节文字不全',
            r'得奇小说网',
            r'Copyright',
            r'All Rights Reserved',
        ]

        for pattern in skip_patterns:
            if re.search(pattern, text):
                return True

        return False


# 向后兼容的别名
DdxsmfCrawlerRefactored = DdxsmfCrawler
