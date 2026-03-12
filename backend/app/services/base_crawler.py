#!/usr/bin/env python3
"""
基础爬虫类 - 基于 Scrapling 重写

使用 Scrapling 库作为底层网络请求和 HTML 解析层。
所有爬虫继承此类，自动获得高性能、强反爬虫能力。
"""

import re
import urllib.parse
from abc import ABC, abstractmethod
from typing import Any

from .scrapling_fetcher import ScraplingFetcher
from .page_response import PageResponse
from .http_client import RequestStrategy


class BaseCrawler(ABC):
    """
    基础爬虫类 - 基于 Scrapling 重写

    通过集成 Scrapling 库，提供：
    - 高性能 HTML 解析（比 BeautifulSoup4 快 784 倍）
    - 强反爬虫能力（StealthyFetcher 自动绕过 Cloudflare）
    - 统一的网络请求接口
    - 会话复用和代理轮换

    所有爬虫类继承此类，只需关注业务逻辑，
    底层性能和可靠性自动升级。
    """

    def __init__(
        self,
        base_url: str,
        strategy: RequestStrategy = RequestStrategy.HYBRID,
    ):
        """
        初始化爬虫

        Args:
            base_url: 站点基础 URL
            strategy: 请求策略
                - SIMPLE: 使用 FetcherSession，简单高效的 HTTP 请求
                - BROWSER: 使用 DynamicSession，支持 JS 渲染
                - HYBRID: 自动选择最佳策略（默认）
                - STEALTH: 使用 StealthySession，最强的反爬能力
        """
        self.base_url = base_url
        self.strategy = strategy

        # 使用 Scrapling 作为底层网络层
        self.fetcher = ScraplingFetcher(strategy)

    # ==================== 核心接口（保持完全兼容）===================

    @abstractmethod
    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """
        搜索小说 - 必须实现

        Args:
            keyword: 搜索关键词

        Returns:
            list[dict]: 小说信息列表，每个字典包含：
                - title: 小说标题
                - author: 作者
                - url: 小说 URL
                - cover_url: 封面 URL
                - description: 简介
                - status: 连载状态
                - category: 分类
        """
        pass

    @abstractmethod
    async def get_chapter_list(self, novel_url: str) -> list[dict[str, Any]]:
        """
        获取章节列表 - 必须实现

        Args:
            novel_url: 小说详情页 URL

        Returns:
            list[dict]: 章节列表，每个字典包含：
                - title: 章节标题
                - url: 章节内容 URL
        """
        pass

    @abstractmethod
    async def get_chapter_content(self, chapter_url: str) -> dict[str, Any]:
        """
        获取章节内容 - 必须实现

        Args:
            chapter_url: 章节内容 URL

        Returns:
            dict: 章节内容字典，包含：
                - title: 章节标题
                - content: 章节文本内容
        """
        pass

    @abstractmethod
    async def get_novel_info(self, novel_url: str) -> dict[str, Any]:
        """
        获取小说详细信息 - 必须实现

        Args:
            novel_url: 小说详情页 URL

        Returns:
            dict: 包含小说信息和章节列表的字典：
                - title: 小说标题
                - author: 作者
                - url: 小说 URL
                - cover_url: 封面 URL
                - description: 简介
                - chapters: 章节列表
        """
        pass

    # ==================== 网络请求方法 ====================

    async def get_page(
        self, url: str, timeout: int = 10, max_retries: int = 3, **kwargs
    ) -> PageResponse:
        """
        获取页面内容

        Args:
            url: 目标 URL
            timeout: 超时时间（秒）
            max_retries: 最大重试次数
            **kwargs: 其他请求参数

        Returns:
            PageResponse: 包含 Scrapling Selector 的响应对象

        使用示例：
            >>> page = await crawler.get_page(url)
            >>> title = page.css('h1::text').get()
            >>> content = page.css('#content').css('p::text').getall()
        """
        from .http_client import RequestConfig

        config = RequestConfig(
            timeout=timeout,
            max_retries=max_retries,
            strategy=self.strategy,
            **kwargs
        )
        response = await self.fetcher.fetch(url, config)
        return PageResponse(response, self.fetcher)

    async def post_form(
        self,
        url: str,
        data: dict[str, str],
        timeout: int = 10,
        max_retries: int = 3,
        **kwargs,
    ) -> PageResponse:
        """
        提交表单

        Args:
            url: 目标 URL
            data: 表单数据
            timeout: 超时时间（秒）
            max_retries: 最大重试次数
            **kwargs: 其他请求参数

        Returns:
            PageResponse: 包含 Scrapling Selector 的响应对象
        """
        from .http_client import RequestConfig

        config = RequestConfig(
            timeout=timeout,
            max_retries=max_retries,
            strategy=self.strategy,
            **kwargs
        )
        response = await self.fetcher.fetch(url, config)
        return PageResponse(response, self.fetcher)

    # ==================== 通用工具方法 ====================

    def clean_text(self, text: str) -> str:
        """
        清理文本内容

        Args:
            text: 原始文本

        Returns:
            str: 清理后的文本
        """
        if not text:
            return ""

        # 移除多余空白
        text = re.sub(r"\n\s*\n", "\n", text)
        text = re.sub(r" +", " ", text)
        text = text.strip()

        return text

    def extract_novel_info(self, page: PageResponse, keyword: str = "") -> list[dict[str, Any]]:
        """
        通用的小说信息提取方法

        Args:
            page: PageResponse 对象
            keyword: 搜索关键词（可选）

        Returns:
            list[dict]: 小说信息列表
        """
        novels = []

        # 使用 Scrapling Selector 查找所有可能包含小说信息的链接
        links = page.css('a[href]')

        for link in links:
            try:
                title = link.css('::text').get('').strip()
                href = link.css('::attr(href)').get('')

                # 过滤条件
                if len(title) < 2 or not href or self._should_skip_link(title, href):
                    continue

                # 构建完整URL
                full_url = urllib.parse.urljoin(self.base_url, href)

                # 提取作者信息
                author = self._extract_author_from_context(link)

                # 提取其他信息
                novel_info = {
                    "title": title,
                    "author": author,
                    "url": full_url,
                    "cover_url": self._extract_cover_url(link),
                    "description": self._extract_description(link),
                    "status": self._extract_status(link),
                    "category": self._extract_category(link),
                    "last_updated": self._extract_last_updated(link),
                }

                novels.append(novel_info)

            except Exception:
                continue

        # 去重
        seen = set()
        unique_novels = []
        for novel in novels:
            key = (novel["title"], novel["url"])
            if key not in seen:
                unique_novels.append(novel)
                seen.add(key)

        return unique_novels

    def extract_chapters(self, page: PageResponse, base_url: str) -> list[dict[str, Any]]:
        """
        通用的章节列表提取方法

        Args:
            page: PageResponse 对象
            base_url: 基础URL（用于解析相对路径）

        Returns:
            list[dict]: 章节列表
        """
        chapters = []

        # 常见的章节容器选择器
        container_selectors = [
            "#list",
            ".listmain",
            "dl",
            ".book_list",
            ".chapterlist",
            "#readerlist",
            'div[class*="list"]',
            'div[class*="chapter"]',
        ]

        container = None
        for selector in container_selectors:
            container = page.css(selector).first
            if container:
                break

        # 在容器内查找章节链接
        if container:
            links = container.css('a[href]')
        else:
            links = page.css('a[href]')

        # 需要跳过的关键词
        skip_words = [
            "封面", "图片", "插图", "返回首页", "加入书架",
            "发表评论", "txt下载", "在线阅读", "立即下载",
            "目录", "书架", "推荐", "排行",
        ]

        for link in links:
            try:
                title = link.css('::text').get('').strip()
                href = link.css('::attr(href)').get('')

                # 过滤条件
                if (
                    len(title) < 2
                    or not href
                    or any(word in title for word in skip_words)
                ):
                    continue

                # 检查是否像章节标题
                if not self._looks_like_chapter_title(title):
                    continue

                full_url = urllib.parse.urljoin(base_url, href)
                chapters.append({"title": title, "url": full_url})

            except Exception:
                continue

        # 去重保持顺序
        seen = set()
        unique_chapters = []
        for chapter in chapters:
            if chapter["url"] not in seen:
                unique_chapters.append(chapter)
                seen.add(chapter["url"])

        return unique_chapters

    def extract_content(self, page: PageResponse) -> str:
        """
        通用的章节内容提取方法

        Args:
            page: PageResponse 对象

        Returns:
            str: 章节文本内容
        """
        # 常见的内容容器选择器
        content_selectors = [
            "#content",
            ".content",
            ".readcontent",
            "#chaptercontent",
            ".chapter-content",
            ".book_con",
            ".showtxt",
            ".txt",
            'div[class*="content"]',
            'div[class*="txt"]',
        ]

        content_elem = None
        for selector in content_selectors:
            content_elem = page.css(selector).first
            if content_elem:
                break

        # 如果没找到指定容器，尝试找最长的div
        if not content_elem:
            divs = page.css('div')
            longest_div = None
            max_length = 0

            for div in divs:
                text_length = len(div.css('::text').get())
                if text_length > max_length:
                    max_length = text_length
                    longest_div = div

            if longest_div and max_length > 500:
                content_elem = longest_div

        if not content_elem:
            return ""

        # 移除脚本和样式
        content_elem.css('script, style, ins, iframe').remove()

        # 获取文本内容
        content = content_elem.css('::text').getall()
        text = '\n'.join([t.strip() for t in content if t.strip()])

        # 清理内容
        content = self.clean_text(content)

        return content

    # ==================== 私有辅助方法 ====================

    def _should_skip_link(self, title: str, href: str) -> bool:
        """
        判断是否应该跳过这个链接

        Args:
            title: 链接标题
            href: 链接地址

        Returns:
            bool: 是否跳过
        """
        skip_patterns = [
            r"javascript:",
            r"#",
            r"mailto:",
            r"登录|注册|首页|书签|收藏",
            r"上一页|下一页|更多|继续",
            r".css$",
            r".js$",
            r".jpg$",
            r".png$",
        ]

        text = (title + " " + href).lower()
        return any(re.search(pattern, text) for pattern in skip_patterns)

    def _extract_author_from_context(self, link) -> str:
        """
        从链接上下文中提取作者信息

        Args:
            link: 链接元素

        Returns:
            str: 作者名称
        """
        # 获取父元素
        parent = link.parent
        if parent:
            text = parent.css('::text').get('')

            # 常见的作者模式
            author_patterns = [
                r"作者[：:]\s*([^\s\n<>/]+)",
                r"文\s*/\s*([^\s\n]+)",
                r"([^\s]+)\s*著",
            ]

            for pattern in author_patterns:
                match = re.search(pattern, text)
                if match:
                    return match.group(1).strip()

        return "未知作者"

    def _extract_cover_url(self, link) -> str:
        """
        提取封面URL

        Args:
            link: 链接元素

        Returns:
            str: 封面图片URL
        """
        # 查找图片元素
        img = link.css('img').first
        if img:
            src = img.css('::attr(src)').get('') or img.css('::attr(data-src)').get('')
            if src:
                return urllib.parse.urljoin(self.base_url, src)
        return ""

    def _extract_description(self, link) -> str:
        """
        提取简介信息

        Args:
            link: 链接元素

        Returns:
            str: 简介文本
        """
        # 尝试从相邻元素中提取简介
        next_sibling = link.next
        if next_sibling:
            desc = next_sibling.css('::text').get('').strip()
            if len(desc) > 10 and len(desc) < 200:
                return desc
        return ""

    def _extract_status(self, link) -> str:
        """
        提取连载状态

        Args:
            link: 链接元素

        Returns:
            str: 连载状态（连载/完结/unknown）
        """
        text = link.css('::text').get('').lower()

        if "连载" in text:
            return "连载"
        elif any(word in text for word in ["完结", "完本", "结局"]):
            return "完结"

        return "unknown"

    def _extract_category(self, link) -> str:
        """
        提取分类信息

        Args:
            link: 链接元素

        Returns:
            str: 分类名称
        """
        text = link.css('::text').get('').lower()

        categories = [
            "玄幻", "都市", "仙侠", "历史", "科幻",
            "游戏", "体育", "军事", "悬疑",
        ]

        for category in categories:
            if category in text:
                return category

        return "unknown"

    def _extract_last_updated(self, link) -> str:
        """
        提取更新时间

        Args:
            link: 链接元素

        Returns:
            str: 更新时间字符串
        """
        text = str(link.parent)

        # 常见的时间模式
        time_patterns = [
            r"(\d{4}-\d{2}-\d{2})",
            r"(\d{2}-\d{2})",
            r"(\d{4}/\d{2}/\d{2})",
            r"(\d{2}月\d{2}日)",
        ]

        for pattern in time_patterns:
            match = re.search(pattern, text)
            if match:
                return match.group(1)

        return ""

    def _looks_like_chapter_title(self, title: str) -> bool:
        """
        判断标题是否像章节

        Args:
            title: 章节标题

        Returns:
            bool: 是否像章节标题
        """
        # 章节标题的关键词模式
        chapter_patterns = [
            r"第\s*\d+.*章",
            r"第[一二三四五六七八九十百千万]+.*章",
            r".*章\s*\d+",
            r"卷\s*\d+",
            r"楔子|序章|终章|大结局",
            r"\d+\.+.*",  # 数字开头的标题
        ]

        title_lower = title.lower()

        # 检查是否包含章节关键词
        if any(re.search(pattern, title) for pattern in chapter_patterns):
            return True

        # 检查是否包含章节相关词汇
        chapter_words = ["章", "节", "卷", "回", "楔子", "序", "结局"]
        if any(word in title for word in chapter_words):
            return True

        # 检查是否以"第"开头
        return title.startswith("第")

    async def close(self):
        """
        关闭资源

        清理爬虫使用的资源，关闭所有网络连接
        """
        await self.fetcher.close()


# ==================== 使用示例 ====================

class ExampleCrawler(BaseCrawler):
    """
    使用抽象网络层的爬虫示例

    继承 BaseCrawler 后，只需关注业务逻辑：
    - search_novels() 如何搜索
    - get_chapter_list() 如何提取章节列表
    - get_chapter_content() 如何提取章节内容
    - get_novel_info() 如何获取小说详细信息
    """

    def __init__(self):
        super().__init__(
            base_url="https://www.example.com",
            strategy=RequestStrategy.HYBRID,  # 混合模式，优先简单请求
        )

    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """
        搜索小说 - 只需要关注业务逻辑

        不需要关心底层实现（requests vs Scrapling），
        只需关注如何搜索和提取数据。
        """
        try:
            # 发送搜索请求 - 不需要关心底层实现
            search_url = f"{self.base_url}/search"
            response = await self.post_form(search_url, {"keyword": keyword})

            # 提取搜索结果 - 使用基类提供的通用方法
            # 注意：现在使用的是 Scrapling Selector，性能提升 784 倍
            novels = self.extract_novel_info(response, keyword)

            return novels[:20]  # 限制返回数量

        except Exception as e:
            print(f"搜索失败: {e}")
            return []

    async def get_chapter_list(self, novel_url: str) -> list[dict[str, Any]]:
        """
        获取章节列表 - 只需要关注业务逻辑

        不需要关心底层实现，只需关注如何提取章节。
        """
        try:
            # 获取页面 - 不需要关心底层实现
            response = await self.get_page(novel_url)

            # 提取章节列表 - 使用基类提供的通用方法
            # 注意：现在使用的是 Scrapling Selector，性能提升 784 倍
            chapters = self.extract_chapters(response, novel_url)

            return chapters

        except Exception as e:
            print(f"获取章节列表失败: {e}")
            return []

    async def get_chapter_content(self, chapter_url: str) -> dict[str, Any]:
        """
        获取章节内容 - 只需要关注业务逻辑

        不需要关心底层实现，只需关注如何提取内容。
        """
        try:
            # 获取页面 - 不需要关心底层实现
            response = await self.get_page(chapter_url)

            # 提取内容 - 使用基类提供的通用方法
            # 注意：现在使用的是 Scrapling Selector，性能提升 784 倍
            soup = response  # PageResponse 支持直接作为 Selector 使用

            # 获取标题
            title_elem = soup.css('h1').first or soup.css('title').first
            title = title_elem.css('::text').get('').strip() if title_elem else "章节内容"

            # 获取内容
            content = self.extract_content(soup)

            return {"title": title, "content": content}

        except Exception as e:
            print(f"获取章节内容失败: {e}")
            return {"title": "章节内容", "content": f"获取失败: {e!s}"}

    async def get_novel_info(self, novel_url: str) -> dict[str, Any]:
        """
        获取小说详细信息 - 只需要关注业务逻辑
        """
        try:
            # 获取小说详情页
            response = await self.get_page(novel_url)
            soup = response

            # 提取小说基本信息
            title = soup.css('h1.book-title::text').get('').strip()
            author = soup.css('p:contains("作者")::text').re_first(
                r'作者[：:]\s*(.+)', default='未知作者'
            )
            cover_url = soup.css('.book-cover img::attr(src)').get('')
            description = soup.css('.book-description::text').get('')

            # 获取章节列表
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
            print(f"获取小说信息失败: {e}")
            return {
                "title": "未知小说",
                "author": "未知作者",
                "url": novel_url,
                "cover_url": "",
                "description": "",
                "chapters": [],
            }
