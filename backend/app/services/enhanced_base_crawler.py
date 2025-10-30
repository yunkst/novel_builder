#!/usr/bin/env python3
"""
增强版基础爬虫

使用抽象网络请求层的爬虫基类，爬虫开发者只需要关注业务逻辑
"""

import asyncio
import re
import urllib.parse
from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional

from .http_client import (
    RequestConfig,
    RequestStrategy,
    Response,
    get_http_client,
    http_get,
    http_post
)


class EnhancedBaseCrawler(ABC):
    """增强版基础爬虫类"""

    def __init__(self, base_url: str, strategy: RequestStrategy = RequestStrategy.HYBRID):
        self.base_url = base_url
        self.strategy = strategy
        self.http_client = get_http_client(strategy)

    @abstractmethod
    async def search_novels(self, keyword: str) -> List[Dict[str, Any]]:
        """搜索小说 - 必须实现"""
        pass

    @abstractmethod
    async def get_chapter_list(self, novel_url: str) -> List[Dict[str, Any]]:
        """获取章节列表 - 必须实现"""
        pass

    @abstractmethod
    async def get_chapter_content(self, chapter_url: str) -> Dict[str, Any]:
        """获取章节内容 - 必须实现"""
        pass

    # ==================== 通用工具方法 ====================

    async def get_page(self, url: str, timeout: int = 10,
                      max_retries: int = 3) -> Response:
        """获取页面内容的通用方法"""
        config = RequestConfig(
            timeout=timeout,
            max_retries=max_retries,
            strategy=self.strategy
        )
        return await http_get(url, config)

    async def post_form(self, url: str, data: Dict[str, str],
                       timeout: int = 10, max_retries: int = 3) -> Response:
        """提交表单的通用方法"""
        config = RequestConfig(
            timeout=timeout,
            max_retries=max_retries,
            strategy=self.strategy
        )
        return await http_post(url, data, config)

    def clean_text(self, text: str) -> str:
        """清理文本内容"""
        if not text:
            return ""

        # 移除多余空白
        text = re.sub(r'\n\s*\n', '\n', text)
        text = re.sub(r' +', ' ', text)
        text = text.strip()

        return text

    def extract_novel_info(self, soup, keyword: str = "") -> List[Dict[str, Any]]:
        """通用的小说信息提取方法"""
        novels = []

        # 查找所有可能包含小说信息的链接
        links = soup.find_all('a', href=True)

        for link in links:
            try:
                title = link.get_text().strip()
                href = link.get('href', '')

                # 过滤条件
                if (len(title) < 2 or
                    not href or
                    self._should_skip_link(title, href)):
                    continue

                # 构建完整URL
                full_url = urllib.parse.urljoin(self.base_url, href)

                # 提取作者信息
                author = self._extract_author_from_context(link)

                # 提取其他信息
                novel_info = {
                    'title': title,
                    'author': author,
                    'url': full_url,
                    'cover_url': self._extract_cover_url(link),
                    'description': self._extract_description(link),
                    'status': self._extract_status(link),
                    'category': self._extract_category(link),
                    'last_updated': self._extract_last_updated(link)
                }

                novels.append(novel_info)

            except Exception:
                continue

        # 去重
        seen = set()
        unique_novels = []
        for novel in novels:
            key = (novel['title'], novel['url'])
            if key not in seen:
                unique_novels.append(novel)
                seen.add(key)

        return unique_novels

    def extract_chapters(self, soup, base_url: str) -> List[Dict[str, Any]]:
        """通用的章节列表提取方法"""
        chapters = []

        # 常见的章节容器选择器
        container_selectors = [
            '#list', '.listmain', 'dl',
            '.book_list', '.chapterlist', '#readerlist',
            'div[class*="list"]', 'div[class*="chapter"]'
        ]

        container = None
        for selector in container_selectors:
            container = soup.select_one(selector)
            if container:
                break

        # 在容器内查找章节链接
        if container:
            links = container.find_all('a', href=True)
        else:
            links = soup.find_all('a', href=True)

        # 需要跳过的关键词
        skip_words = [
            '封面', '图片', '插图', '返回首页', '加入书架',
            '发表评论', 'txt下载', '在线阅读', '立即下载',
            '目录', '书架', '推荐', '排行'
        ]

        for link in links:
            try:
                title = link.get_text().strip()
                href = link.get('href', '')

                # 过滤条件
                if (len(title) < 2 or
                    not href or
                    any(word in title for word in skip_words)):
                    continue

                # 检查是否像章节标题
                if not self._looks_like_chapter_title(title):
                    continue

                full_url = urllib.parse.urljoin(base_url, href)

                chapters.append({
                    'title': title,
                    'url': full_url
                })

            except Exception:
                continue

        # 去重保持顺序
        seen = set()
        unique_chapters = []
        for chapter in chapters:
            if chapter['url'] not in seen:
                unique_chapters.append(chapter)
                seen.add(chapter['url'])

        return unique_chapters

    def extract_content(self, soup) -> str:
        """通用的章节内容提取方法"""
        # 常见的内容容器选择器
        content_selectors = [
            '#content', '.content', '.readcontent',
            '#chaptercontent', '.chapter-content', '.book_con',
            '.showtxt', '.txt', 'div[class*="content"]',
            'div[class*="txt"]'
        ]

        content_elem = None
        for selector in content_selectors:
            content_elem = soup.select_one(selector)
            if content_elem:
                break

        # 如果没找到指定容器，尝试找最长的div
        if not content_elem:
            divs = soup.find_all('div')
            longest_div = None
            max_length = 0

            for div in divs:
                text_length = len(div.get_text())
                if text_length > max_length:
                    max_length = text_length
                    longest_div = div

            if longest_div and max_length > 500:
                content_elem = longest_div

        if not content_elem:
            return ""

        # 移除脚本和样式
        for elem in content_elem(['script', 'style', 'ins', 'iframe']):
            elem.decompose()

        # 获取文本内容
        content = content_elem.get_text()

        # 清理内容
        content = self.clean_text(content)

        return content

    # ==================== 私有辅助方法 ====================

    def _should_skip_link(self, title: str, href: str) -> bool:
        """判断是否应该跳过这个链接"""
        skip_patterns = [
            r'javascript:', r'#', r'mailto:',
            r'登录|注册|首页|书签|收藏',
            r'上一页|下一页|更多|继续',
            r'.css$', r'.js$', r'.jpg$', r'.png$'
        ]

        text = (title + ' ' + href).lower()
        return any(re.search(pattern, text) for pattern in skip_patterns)

    def _extract_author_from_context(self, link) -> str:
        """从链接上下文中提取作者信息"""
        # 尝试从父元素中提取作者信息
        parent = link.parent
        if parent:
            text = parent.get_text()

            # 常见的作者模式
            author_patterns = [
                r'作者[：:]\s*([^\s\n<>/]+)',
                r'文\s*/\s*([^\s\n]+)',
                r'([^\s]+)\s*著'
            ]

            for pattern in author_patterns:
                match = re.search(pattern, text)
                if match:
                    return match.group(1).strip()

        return "未知作者"

    def _extract_cover_url(self, link) -> str:
        """提取封面URL"""
        img = link.find('img')
        if img:
            src = img.get('src') or img.get('data-src')
            if src:
                return urllib.parse.urljoin(self.base_url, src)
        return ""

    def _extract_description(self, link) -> str:
        """提取简介信息"""
        # 尝试从相邻元素中提取简介
        next_sibling = link.next_sibling
        if next_sibling and hasattr(next_sibling, 'get_text'):
            desc = next_sibling.get_text().strip()
            if len(desc) > 10 and len(desc) < 200:
                return desc

        return ""

    def _extract_status(self, link) -> str:
        """提取连载状态"""
        text = (link.get_text() + ' ' + str(link.parent)).lower()

        if '连载' in text:
            return "连载"
        elif any(word in text for word in ['完结', '完本', '结局']):
            return "完结"

        return "unknown"

    def _extract_category(self, link) -> str:
        """提取分类信息"""
        text = (link.get_text() + ' ' + str(link.parent)).lower()

        categories = ['玄幻', '都市', '仙侠', '历史', '科幻', '游戏', '体育', '军事', '悬疑']
        for category in categories:
            if category in text:
                return category

        return "unknown"

    def _extract_last_updated(self, link) -> str:
        """提取更新时间"""
        text = str(link.parent)

        # 常见的时间模式
        time_patterns = [
            r'(\d{4}-\d{2}-\d{2})',
            r'(\d{2}-\d{2})',
            r'(\d{4}/\d{2}/\d{2})',
            r'(\d{2}月\d{2}日)'
        ]

        for pattern in time_patterns:
            match = re.search(pattern, text)
            if match:
                return match.group(1)

        return ""

    def _looks_like_chapter_title(self, title: str) -> bool:
        """判断标题是否像章节"""
        # 章节标题的关键词模式
        chapter_patterns = [
            r'第\s*\d+.*章',
            r'第[一二三四五六七八九十百千万]+.*章',
            r'.*章\s*\d+',
            r'卷\s*\d+',
            r'楔子|序章|终章|大结局',
            r'\d+\.+.*'  # 数字开头的标题
        ]

        title_lower = title.lower()

        # 检查是否包含章节关键词
        if any(re.search(pattern, title) for pattern in chapter_patterns):
            return True

        # 检查是否包含章节相关词汇
        chapter_words = ['章', '节', '卷', '回', '楔子', '序', '结局']
        if any(word in title for word in chapter_words):
            return True

        # 检查是否以"第"开头
        if title.startswith('第'):
            return True

        return False


# ==================== 使用示例 ====================

class ExampleCrawler(EnhancedBaseCrawler):
    """使用抽象网络层的爬虫示例"""

    def __init__(self):
        super().__init__("https://www.example.com", RequestStrategy.HYBRID)

    async def search_novels(self, keyword: str) -> List[Dict[str, Any]]:
        """搜索小说 - 只需要关注业务逻辑"""
        try:
            # 发送搜索请求 - 不需要关心底层实现
            search_url = f"{self.base_url}/search"
            response = await self.post_form(search_url, {"keyword": keyword})

            # 提取搜索结果 - 使用基类提供的通用方法
            novels = self.extract_novel_info(response.soup(), keyword)

            return novels[:20]  # 限制返回数量

        except Exception as e:
            print(f"搜索失败: {e}")
            return []

    async def get_chapter_list(self, novel_url: str) -> List[Dict[str, Any]]:
        """获取章节列表 - 只需要关注业务逻辑"""
        try:
            # 获取页面 - 不需要关心底层实现
            response = await self.get_page(novel_url)

            # 提取章节列表 - 使用基类提供的通用方法
            chapters = self.extract_chapters(response.soup(), novel_url)

            return chapters

        except Exception as e:
            print(f"获取章节列表失败: {e}")
            return []

    async def get_chapter_content(self, chapter_url: str) -> Dict[str, Any]:
        """获取章节内容 - 只需要关注业务逻辑"""
        try:
            # 获取页面 - 不需要关心底层实现
            response = await self.get_page(chapter_url)

            # 提取内容 - 使用基类提供的通用方法
            soup = response.soup()

            # 获取标题
            title_elem = soup.find('h1') or soup.find('title')
            title = title_elem.get_text().strip() if title_elem else "章节内容"

            # 获取内容
            content = self.extract_content(soup)

            return {"title": title, "content": content}

        except Exception as e:
            print(f"获取章节内容失败: {e}")
            return {"title": "章节内容", "content": f"获取失败: {str(e)}"}