#!/usr/bin/env python3
"""
重构版Shukuge爬虫

使用网络请求抽象层，专注于业务逻辑实现
"""

import logging
import re
import urllib.parse
from typing import Any

from .base_crawler import BaseCrawler, RequestStrategy
from .cache_decorator import cacheable
from .cache_types import CacheType

logger = logging.getLogger(__name__)


class ShukugeCrawlerRefactored(BaseCrawler):
    """重构版书库爬虫"""

    def __init__(self):
        # Shukuge使用HTTP，可以用简单策略
        super().__init__(
            base_url="http://www.shukuge.com", strategy=RequestStrategy.SIMPLE
        )

        # 自定义请求头
        self.custom_headers = {
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Accept-Encoding": "gzip, deflate",
            "Connection": "keep-alive",
        }

    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """搜索小说"""
        try:
            # 尝试多个搜索入口
            search_urls = [
                f"{self.base_url}/Search",
                f"{self.base_url}/modules/article/search.php",
                f"{self.base_url}/search.php",
            ]

            for i, search_url in enumerate(search_urls):
                try:
                    if "search.php" in search_url:
                        # POST方式搜索 - 确保所有参数值都是字符串类型
                        data = {"searchkey": str(keyword), "searchtype": "all"}
                        response = await self.post_form(
                            search_url, data, timeout=10, custom_headers=self.custom_headers
                        )
                    else:
                        # GET方式搜索 - 确保所有参数值都是字符串类型
                        params = {"wd": str(keyword)}
                        # 构建完整URL
                        full_url = f"{search_url}?{urllib.parse.urlencode(params)}"
                        response = await self.get_page(
                            full_url, timeout=10, custom_headers=self.custom_headers
                        )

                    # 提取搜索结果
                    novels = self._extract_shukuge_search_results(
                        response.soup(), keyword
                    )

                    if novels:
                        return novels[:20]

                except Exception as e:
                    logger.warning(f"搜索入口{i + 1}失败: {e!s}")
                    continue

            return []

        except Exception as e:
            logger.error(f"Shukuge搜索失败: {e!s}")
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
            # 1. 访问小说详情页
            response = await self.get_page(novel_url, timeout=10, custom_headers=self.custom_headers)

            # 2. 尝试专用章节列表页
            chapters = await self._try_special_chapter_page(novel_url, response.soup())

            # 3. 如果没找到，尝试从详情页的阅读链接获取
            if not chapters:
                chapters = await self._try_reading_links(novel_url, response.soup())

            # 4. 兜底：直接从详情页提取
            if not chapters:
                chapters = self.extract_chapters(response.soup(), novel_url)

            return chapters

        except Exception as e:
            logger.error(f"Shukuge获取章节列表失败: {e!s}")
            return []

    @cacheable(
        cache_type=CacheType.CHAPTER_CONTENT,
        key_params=["chapter_url", "novel_url"],
        min_valid_length=300,
    )
    async def get_chapter_content(
        self, chapter_url: str, novel_url: str = "", force_refresh: bool = False
    ) -> dict[str, Any]:
        """获取章节内容"""
        try:
            # 获取章节页面
            response = await self.get_page(
                chapter_url, timeout=10, custom_headers=self.custom_headers
            )

            # 提取内容
            soup = response.soup()

            # 获取标题
            title = self._extract_chapter_title(soup)

            # 获取内容
            content = self._extract_shukuge_content(soup)

            return {"title": title, "content": content}

        except Exception as e:
            logger.error(f"Shukuge获取章节内容失败: {e!s}")
            return {"title": "章节内容", "content": f"获取失败: {e!s}"}

    async def get_novel_info(self, novel_url: str) -> dict[str, Any]:
        """
        获取小说详细信息和章节列表

        Args:
            novel_url: 小说详情页URL

        Returns:
            包含小说信息和章节列表的字典
        """
        try:
            # 获取小说详情页
            response = await self.get_page(novel_url, timeout=15, custom_headers=self.custom_headers)
            soup = response.soup()

            # 提取小说基本信息
            title = self._extract_novel_title(soup)
            author = self._extract_novel_author(soup)
            cover_url = self._extract_novel_cover(soup, novel_url)
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

    # ==================== Shukuge专用提取方法 ====================

    def _extract_novel_title(self, soup) -> str:
        """提取小说标题"""
        title_selectors = ["h1", "h2", ".book-title", ".title", "title"]
        for selector in title_selectors:
            title_elem = soup.select_one(selector)
            if title_elem:
                title = title_elem.get_text().strip()
                if title and len(title) > 1:
                    # 清理标题中的网站名称等后缀
                    title = re.sub(r"_.*$", "", title).strip()
                    title = re.sub(r"-.*$", "", title).strip()
                    return title
        return "未知小说"

    def _extract_novel_author(self, soup) -> str:
        """提取小说作者"""
        # 尝试多种作者信息选择器
        author_patterns = [
            soup.find("span", class_=re.compile(r"author")),
            soup.find("div", class_=re.compile(r"author")),
            soup.find("p", class_=re.compile(r"author")),
        ]

        for pattern in author_patterns:
            if pattern:
                author = pattern.get_text().strip()
                # 清理作者信息中的标签
                author = re.sub(r"作者[：:]\s*", "", author)
                if author:
                    return author

        # 尝试从页面文本中提取作者信息
        text = soup.get_text()
        author_match = re.search(r"作者[：:]\s*([^\s\n\r<>/]+)", text)
        if author_match:
            return author_match.group(1).strip()

        return "未知作者"

    def _extract_novel_cover(self, soup, novel_url: str) -> str:
        """提取小说封面URL"""
        # 尝试查找封面图片
        cover_selectors = [
            "img.book-cover",
            "img.cover",
            "img[alt*='封面']",
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
                        return urllib.parse.urljoin(self.base_url, cover_src)
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
            "div.book-desc",
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
                    return desc[:500]  # 限制简介长度

        return ""

    def _extract_shukuge_search_results(
        self, soup, keyword: str
    ) -> list[dict[str, Any]]:
        """提取Shukuge搜索结果"""
        novels = []

        # 使用 CSS 选择器查找所有链接
        # soup 是 Scrapling Selector，使用 CSS 选择器语法
        all_links = soup.css('a[href]')

        for link in all_links:
            try:
                # 获取链接文本
                title = link.css('::text').get('').strip()
                # 获取 href 属性
                href = link.css('::attr(href)').get('')

                # 过滤条件
                if (
                    keyword.lower() not in title.lower()
                    or not any(
                        ind in href for ind in ["/book/", "/read/", "/modules/article"]
                    )
                    or len(title) < 2
                ):
                    continue

                # 提取作者信息
                author = self._extract_shukuge_author(link)

                # 构建完整URL
                novel_url = urllib.parse.urljoin(self.base_url, href)

                novels.append(
                    {
                        "title": title,
                        "author": author,
                        "url": novel_url,
                        "source": "shukuge",
                    }
                )

            except Exception:
                continue

        # 去重
        seen = set()
        unique = []
        for novel in novels:
            if novel["title"] not in seen and len(novel["title"]) > 1:
                unique.append(novel)
                seen.add(novel["title"])

        return unique

    def _extract_shukuge_author(self, link) -> str:
        """提取Shukuge作者信息"""
        author = "未知"

        try:
            # Scrapling Selector 获取父元素
            parent = link.parent
            if parent:
                # 获取父元素的文本内容
                text = parent.css('::text').getall()
                text = ''.join(text)
                # Shukuge特定的作者提取模式
                match = re.search(r"作者[：:]\s*([^\s\n\r<>/]+)", text)
                if match:
                    author = match.group(1).strip()
        except Exception:
            pass

        return author

    async def _try_special_chapter_page(
        self, novel_url: str, soup
    ) -> list[dict[str, Any]]:
        """尝试从专用章节页获取章节列表"""
        try:
            # 提取小说ID
            novel_id_match = re.search(r"/book/(\d+)/", novel_url)
            if not novel_id_match:
                return []

            novel_id = novel_id_match.group(1)

            # Shukuge的章节列表URL模式: /book/{novel_id}/index.html
            chapter_list_urls = [
                f"{self.base_url}/book/{novel_id}/index.html",
                f"{self.base_url}/other/chapters/id/{novel_id}.html",
            ]

            for chapter_list_url in chapter_list_urls:
                try:
                    # 访问专用章节页
                    response = await self.get_page(
                        chapter_list_url, timeout=10, custom_headers=self.custom_headers
                    )
                    chapters = self._extract_chapter_list_from_page(response.soup(), novel_url)

                    if chapters:
                        return chapters

                except Exception:
                    continue

            return []

        except Exception:
            return []

    async def _try_reading_links(self, novel_url: str, soup) -> list[dict[str, Any]]:
        """尝试从阅读链接获取章节列表"""
        try:
            # 查找阅读链接
            read_links = soup.find_all(
                "a",
                string=re.compile(
                    r"在线阅读|立即阅读|开始阅读|章节列表|全文阅读|阅读目录|目录|全部章节"
                ),
            )

            if read_links:
                read_url = urllib.parse.urljoin(
                    novel_url, read_links[0].get("href", "")
                )

                # 访问阅读页面
                response = await self.get_page(
                    read_url, timeout=10, custom_headers=self.custom_headers
                )
                chapters = self.extract_chapters(response.soup(), read_url)

                return chapters

            return []

        except Exception:
            return []

    def _extract_chapter_list_from_page(
        self, soup, novel_url: str
    ) -> list[dict[str, Any]]:
        """从页面提取章节列表 - Shukuge专用"""
        try:
            chapters = []

            # 查找所有链接
            links = soup.select('a[href]')

            # 提取小说ID用于过滤
            novel_id_match = re.search(r"/book/(\d+)/", novel_url)
            if not novel_id_match:
                return []

            novel_id = novel_id_match.group(1)

            # Shukuge的章节链接模式: /book/{novel_id}/{数字}.html
            chapter_pattern = re.compile(rf"/book/{novel_id}/\d+\.html")

            for link in links:
                try:
                    # 获取链接文本
                    title = link.get_text().strip()
                    # 获取 href 属性
                    href = link.get('href', '')

                    # 检查是否是章节链接
                    if (
                        not href
                        or not chapter_pattern.match(href)
                        or len(title) < 2
                    ):
                        continue

                    # 过滤导航链接
                    if any(nav in title for nav in ['首页', '小说', '排行', '分类', '作者', '登录', '注册', '目录']):
                        continue

                    # 构建完整URL
                    chapter_url = urllib.parse.urljoin(self.base_url, href)

                    chapters.append({
                        "title": title,
                        "url": chapter_url,
                    })

                except Exception:
                    continue

            return chapters

        except Exception as e:
            logger.error(f"Shukuge提取章节列表失败: {e!s}")
            return []

    def _extract_chapter_title(self, soup) -> str:
        """提取章节标题"""
        # Shukuge特定的标题选择器
        title_selectors = ["h1", "h2", ".chapter-title", ".title", "title"]

        for selector in title_selectors:
            title_elem = soup.select_one(selector)
            if title_elem:
                title_text = title_elem.get_text().strip()
                if title_text and len(title_text) > 1:
                    return title_text

        return "章节内容"

    def _extract_shukuge_content(self, soup) -> str:
        """提取Shukuge章节内容"""
        # Shukuge特定的内容选择器
        content_selectors = [
            "div#content",
            "div.content",
            "div.readcontent",
            "div#chaptercontent",
            "div.chapter-content",
            "div.book_con",
            "div.showtxt",
        ]

        content_elem = None
        for selector in content_selectors:
            # 使用 select_one 而不是 css
            content_elem = soup.select_one(selector)
            if content_elem:
                break

        # 如果没找到指定容器，尝试通用方法
        if not content_elem:
            # 使用基类的通用内容提取方法
            return self.extract_content(soup)

        if not content_elem:
            return ""

        # 获取文本内容 - 直接使用 get_text()
        content = content_elem.get_text(strip=True)

        # 清理内容
        content = self.clean_text(content)

        return content


# 为了向后兼容，创建别名
ShukugeCrawler = ShukugeCrawlerRefactored
