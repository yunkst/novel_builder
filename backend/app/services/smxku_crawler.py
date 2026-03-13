#!/usr/bin/env python3
"""
SMXKU 小说网站爬虫 - 基于 Scrapling 最佳实践重写
网站地址: https://www.smxku.com
功能: 搜索小说、获取目录、获取章节内容
"""

import re
from typing import Any
from urllib.parse import urljoin

from .base_crawler import BaseCrawler, RequestStrategy


class SmxkuCrawler(BaseCrawler):
    """SMXKU小说网站爬虫"""

    def __init__(self):
        super().__init__("https://www.smxku.com", RequestStrategy.SIMPLE)
        self.source_name = "smxku"
        self.source_display_name = "蜘蛛小说网"

    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """搜索小说"""
        try:
            # 构建搜索URL
            search_url = f"{self.base_url}/search.php"

            # 使用新的 get_page 接口
            page = await self.get_page(
                f"{search_url}?searchkey={keyword}",
            )

            results = []

            # 检查是否直接跳转到了小说详情页
            # 小说详情页的URL格式通常是: https://www.smxku.com/novel_id/
            novel_detail_match = re.search(r"/(\d+)/?$", page.url)
            if novel_detail_match:
                # 如果跳转到小说详情页，直接提取这本小说的信息
                novel_id = novel_detail_match.group(1)
                novel_info = await self._extract_novel_from_detail_page(
                    page, page.url, novel_id
                )
                if novel_info:
                    return [novel_info]

            # 使用 Scrapling Selector 查找所有小说链接
            # SMXKU搜索结果在 h4.bookname 中
            novel_containers = page.css('h4.bookname')
            processed_ids = set()

            for h4 in novel_containers:
                link = h4.css('a').first
                if not link:
                    continue

                novel_url = link.css('::attr(href)').get('')
                # 如果是相对路径，转换为完整URL
                if novel_url.startswith("/"):
                    novel_url = urljoin(self.base_url, novel_url)

                novel_id_match = re.search(r"/(\d+)/?$", novel_url)
                novel_id = novel_id_match.group(1) if novel_id_match else ""

                # 跳过已处理过的ID
                if not novel_id or novel_id in processed_ids:
                    continue
                processed_ids.add(novel_id)

                # 获取小说标题
                title = link.css('::text').get('').strip()

                # 跳过导航链接
                if not title or title in [
                    "首页",
                    "分类",
                    "榜单",
                    "完结",
                    "搜索",
                    "阅读",
                ]:
                    continue

                # 尝试获取作者信息
                author = "未知作者"
                # 使用 Scrapling Selector 查找父元素中的作者链接
                parent = h4.parent
                if parent:
                    author_link = parent.css('a[href*="/kw/"]').first
                    if author_link:
                        author = author_link.css('::text').get('').strip()

                # 尝试获取简介
                description = ""
                if parent:
                    desc_elem = parent.css('p[class*="intro"], p[class*="desc"], p[class*="content"]').first
                    if desc_elem:
                        description = desc_elem.css('::text').get('').strip()[:200]

                novel_info = {
                    "id": novel_id,
                    "title": title,
                    "author": author,
                    "description": description,
                    "url": novel_url,
                    "source": self.source_name,
                }

                results.append(novel_info)

            return results[:50]  # 限制返回数量

        except Exception as e:
            print(f"SMXKU搜索失败: {e!s}")
            return []

    async def get_chapter_list(self, novel_url: str) -> list[dict[str, Any]]:
        """获取章节列表"""
        try:
            # 从URL中提取小说ID
            novel_id_match = re.search(r"/(\d+)/?$", novel_url)
            if not novel_id_match:
                return []

            novel_id = novel_id_match.group(1)

            # 获取小说详情页
            page = await self.get_page(novel_url)

            chapters = []

            # 查找章节列表容器
            chapter_containers = [
                page.css('dl[class*="chapter"]').first,
                page.css('div[class*="chapter"]').first,
                page.css('div[id*="chapter"]').first,
                page.css('div#listsss').first,
            ]

            chapter_list = None
            for container in chapter_containers:
                if container:
                    chapter_list = container
                    break

            if not chapter_list:
                # 如果没找到特定容器，查找所有章节链接
                chapter_links = page.css(f'a[href^="/{novel_id}/"][href$=".html"]')
                for link in chapter_links:
                    chapter_title = link.css('::text').get('').strip()
                    href = link.css('::attr(href)').get('')
                    chapter_url = urljoin(self.base_url, href)

                    # 提取章节号
                    chapter_id_match = re.search(r"/(\d+)\.html$", href)
                    chapter_id = chapter_id_match.group(1) if chapter_id_match else ""

                    if chapter_title and chapter_id:
                        chapters.append(
                            {
                                "id": chapter_id,
                                "title": chapter_title,
                                "url": chapter_url,
                            }
                        )
            else:
                # 从容器中提取章节
                chapter_links = chapter_list.css(f'a[href^="/{novel_id}/"][href$=".html"]')

                for link in chapter_links:
                    chapter_title = link.css('::text').get('').strip()
                    href = link.css('::attr(href)').get('')
                    chapter_url = urljoin(self.base_url, href)

                    # 提取章节号
                    chapter_id_match = re.search(r"/(\d+)\.html$", href)
                    chapter_id = chapter_id_match.group(1) if chapter_id_match else ""

                    if chapter_title and chapter_id:
                        chapters.append(
                            {
                                "id": chapter_id,
                                "title": chapter_title,
                                "url": chapter_url,
                            }
                        )

            # 按章节号排序
            chapters.sort(key=lambda x: int(x["id"]) if x["id"].isdigit() else 0)

            return chapters

        except Exception as e:
            print(f"SMXKU获取章节列表失败: {e!s}")
            return []

    async def get_chapter_content(self, chapter_url: str) -> dict[str, Any]:
        """获取章节内容"""
        try:
            # 获取章节页面
            page = await self.get_page(chapter_url)

            # 获取章节标题
            title_elem = page.css('h1').first
            title = title_elem.css('::text').get('').strip() if title_elem else "章节内容"

            # 优先使用SMXKU特定的内容提取方法，确保保留段落结构
            # 查找章节内容的容器
            content_containers = [
                page.css('div[id*="content"]').first,
                page.css('div[class*="content"]').first,
                page.css('div[class*="read"]').first,
                page.css('div[class*="text"]').first,
            ]

            content_elem = None
            for container in content_containers:
                if container:
                    content_elem = container
                    break

            if not content_elem:
                # 如果没找到特定容器，尝试基类的通用方法
                content = self.extract_content(page)
            else:
                # 移除广告和无关元素
                # Scrapling Selector 的 remove 方法
                content_elem.css('script, ins, iframe, style').remove()

                # 获取纯文本内容，优先保留段落结构
                paragraphs = content_elem.css('p')
                if paragraphs:
                    # 如果有p标签，按段落提取，保持段落分离
                    content_parts = []
                    for p in paragraphs:
                        text = p.css('::text').get('').strip()
                        if text and len(text) > 5:  # 过滤太短的段落
                            content_parts.append(text)
                    content = "\n\n".join(content_parts)
                else:
                    # 如果没有p标签，则提取整个容器的文本
                    content = content_elem.css('::text').get('').strip()

                # 清理内容
                content = re.sub(
                    r"^.*?已发布罪薪章劫.*?$", "", content, flags=re.MULTILINE
                )
                content = re.sub(r"www\.[^\s]+", "", content)
                content = re.sub(r"（使用快捷键.*?）", "", content)
                content = re.sub(r"\(本章完\)", "", content)
                content = self.clean_text(content)

            # 最终清理
            content = self.clean_text(content)

            return {
                "title": title,
                "content": content,
                "url": chapter_url,
                "word_count": len(content),
                "source": self.source_name,
            }

        except Exception as e:
            print(f"SMXKU获取章节内容失败: {e!s}")
            return {
                "title": "章节内容",
                "content": f"获取失败: {e!s}",
                "url": chapter_url,
                "word_count": 0,
                "source": self.source_name,
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
            # 从URL中提取小说ID
            novel_id_match = re.search(r"/(\d+)/?$", novel_url)
            if not novel_id_match:
                return {
                    "title": "未知小说",
                    "author": "未知作者",
                    "url": novel_url,
                    "cover_url": "",
                    "description": "",
                    "chapters": [],
                }

            novel_id = novel_id_match.group(1)

            # 获取小说详情页
            page = await self.get_page(novel_url)

            # 提取小说基本信息（复用已有的方法）
            novel_info = await self._extract_novel_from_detail_page(page, novel_url, novel_id)

            # 如果提取失败，使用基本方法
            if not novel_info or not novel_info.get("title"):
                title = self._extract_novel_title(page)
                author = self._extract_novel_author(page)
                cover_url = self._extract_novel_cover(page)
                description = self._extract_novel_description(page)
            else:
                title = novel_info.get("title", "未知小说")
                author = novel_info.get("author", "未知作者")
                cover_url = self._extract_novel_cover(page)
                description = novel_info.get("description", "")

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
            print(f"{self.__class__.__name__}获取小说信息失败: {e!s}")
            return {
                "title": "未知小说",
                "author": "未知作者",
                "url": novel_url,
                "cover_url": "",
                "description": "",
                "chapters": [],
            }

    def _extract_novel_title(self, page) -> str:
        """提取小说标题"""
        title_elem = page.css('h1').first
        if title_elem:
            title = title_elem.css('::text').get('').strip()
            if title:
                # 清理标题中的网站名称等后缀
                title = re.sub(r"- 蜘蛛小说网.*$", "", title).strip()
                title = re.sub(r"_.*$", "", title).strip()
                return title
        return "未知小说"

    def _extract_novel_author(self, page) -> str:
        """提取小说作者"""
        # 尝试查找作者链接
        author_link = page.css('a[href*="/kw/"]').first
        if author_link:
            return author_link.css('::text').get('').strip()

        # 尝试从页面文本中提取作者信息
        text = page.css('::text').get('')
        author_match = re.search(r"作者[：:]\s*([^\s\n\r<>/]+)", text)
        if author_match:
            return author_match.group(1).strip()

        return "未知作者"

    def _extract_novel_cover(self, page) -> str:
        """提取小说封面URL"""
        # 尝试查找封面图片
        cover_selectors = [
            'img.book-cover',
            'img.cover',
            '.book-img img',
        ]

        for selector in cover_selectors:
            cover_elem = page.css(selector).first
            if cover_elem:
                cover_src = cover_elem.css('::attr(src)').get('') or cover_elem.css('::attr(data-src)').get('')
                if cover_src:
                    # 转换为绝对URL
                    if cover_src.startswith("/"):
                        return urljoin(self.base_url, cover_src)
                    elif cover_src.startswith("http"):
                        return cover_src

        return ""

    def _extract_novel_description(self, page) -> str:
        """提取小说简介"""
        # 尝试多种简介选择器
        desc_selectors = [
            'div.book-intro',
            'div.intro',
            'div.description',
            'div#bookintro',
            'p.intro',
        ]

        for selector in desc_selectors:
            desc_elem = page.css(selector).first
            if desc_elem:
                desc = desc_elem.css('::text').get('').strip()
                if desc and len(desc) > 10:
                    # 清理简介文本
                    desc = re.sub(r"\s+", " ", desc)
                    return desc[:500]

        return ""

    async def _extract_novel_from_detail_page(
        self, page, novel_url: str, novel_id: str
    ) -> dict[str, Any]:
        """从小说详情页提取小说信息"""
        try:
            # 查找小说标题 - 通常在 h1 或其他标题元素中
            title_elem = page.css('h1').first
            if not title_elem:
                # 尝试其他可能的标题选择器
                title_elem = page.css('div.title').first
            if not title_elem:
                # 尝试查找包含小说信息的元素
                title_elem = page.css('title').first

            title = (
                title_elem.css('::text').get('').strip() if title_elem else f"小说ID: {novel_id}"
            )

            # 清理标题，移除网站名称等后缀
            title = re.sub(r"- 蜘蛛小说网.*$", "", title).strip()
            title = re.sub(r"_.*$", "", title).strip()

            # 查找作者信息
            author = "未知作者"
            # 尝试多种作者信息选择器
            author_patterns = [
                page.css('a[href*="/kw/"]').first,
                page.css('span:contains("作者")').first,
                page.css('div[class*="author"]').first,
                page.css('p:contains("作者")').first,
            ]

            for pattern in author_patterns:
                if pattern:
                    # 获取作者链接的文本
                    author_link = pattern.css('a').first if pattern.css('a') else pattern
                    if author_link:
                        author = author_link.css('::text').get('').strip()
                    if author and author != "未知作者":
                        break

            # 查找简介信息
            description = ""
            desc_patterns = [
                'div[class*="intro"]',
                'div[class*="desc"]',
                'div[class*="content"]',
                'div[class*="summary"]',
                'p[class*="intro"]',
                'p[class*="desc"]',
            ]

            for selector in desc_patterns:
                desc_elem = page.css(selector).first
                if desc_elem:
                    description = desc_elem.css('::text').get('').strip()[:200]
                    if description:
                        break

            # 如果没找到简介，尝试获取页面第一段文字作为描述
            if not description:
                first_p = page.css('p').first
                if first_p:
                    first_text = first_p.css('::text').get('').strip()
                    if len(first_text) > 20:
                        description = first_text[:200]

            return {
                "id": novel_id,
                "title": title,
                "author": author,
                "description": description,
                "url": novel_url,
                "source": self.source_name,
            }

        except Exception as e:
            print(f"从详情页提取小说信息失败: {e!s}")
            # 返回基本信息
            return {
                "id": novel_id,
                "title": f"小说ID: {novel_id}",
                "author": "未知作者",
                "description": "",
                "url": novel_url,
                "source": self.source_name,
            }
