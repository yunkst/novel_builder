#!/usr/bin/env python3
"""
重构版AliceSW爬虫

使用网络请求抽象层，专注于业务逻辑实现
"""

import json
import logging
import re
import urllib.parse
from typing import Any

import requests

from .base_crawler import BaseCrawler, RequestStrategy
from .cache_decorator import cacheable
from .cache_types import CacheType

logger = logging.getLogger(__name__)


class AliceSWCrawlerRefactored(BaseCrawler):
    """重构版轻小说文库爬虫"""

    def __init__(self):
        # AliceSW需要特殊的SSL配置和浏览器参数
        super().__init__(
            base_url="https://www.alicesw.com",
            strategy=RequestStrategy.SIMPLE,  # 使用简单策略
        )

        # 自定义请求头，模拟真实浏览器 - 确保所有值都是字符串
        self.custom_headers = {
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Accept-Encoding": "gzip, deflate, br",
            "DNT": "1",  # 字符串 "1" 而不是整数
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",  # 字符串 "1" 而不是整数
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-User": "?1",  # 字符串 "?1" 而不是布尔值
            "Cache-Control": "max-age=0",
        }

        # 自定义浏览器参数（用于Playwright）
        self.browser_args = [
            "--disable-web-security",
            "--disable-features=VizDisplayCompositor",
            "--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ]

    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """搜索小说"""
        try:
            # 构建搜索URL和参数
            search_url = f"{self.base_url}/search.html"
            # 确保所有参数值都是字符串类型
            search_params = {
                "q": str(keyword),
                "f": "_all",
                "sort": "relevance"
            }

            # 使用POST请求发送搜索
            response = await self.post_form(search_url, search_params, timeout=30)

            # 提取搜索结果
            novels = self._extract_alice_sw_search_results(response.soup(), keyword)

            return novels[:20]  # 限制返回数量

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError, AttributeError) as e:
            logger.error(f"AliceSW搜索失败: {e!s}")
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
            # 首先获取小说详情页，查找章节列表页面链接
            response = await self.get_page(novel_url, timeout=15)
            soup = response.soup()

            # 查找指向章节列表页面的链接
            chapter_list_url = self._find_chapter_list_url(soup, novel_url)

            if chapter_list_url:
                # 如果找到章节列表页面，访问该页面
                list_response = await self.get_page(chapter_list_url, timeout=15)
                chapters = self._extract_alice_sw_chapters_from_list_page(
                    list_response.soup(), chapter_list_url
                )
            else:
                # 如果没有找到专门的章节列表页面，尝试在详情页中提取章节
                chapters = self._extract_alice_sw_chapters(soup, novel_url)

            return chapters

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError, AttributeError) as e:
            logger.error(f"AliceSW获取章节列表失败: {e!s}")
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
            response = await self.get_page(chapter_url, timeout=15)

            # 提取内容
            soup = response.soup()

            # 获取标题
            title = self._extract_chapter_title(soup)

            # 获取内容
            content = self._extract_alice_sw_content(soup)

            return {"title": title, "content": content}

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError, AttributeError) as e:
            logger.error(f"AliceSW获取章节内容失败: {e!s}")
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
            response = await self.get_page(novel_url, timeout=15)
            soup = response.soup()

            # 提取小说基本信息
            title = self._extract_novel_title(soup)
            author = self._extract_novel_author(soup)
            cover_url = self._extract_novel_cover(soup, novel_url)
            description = self._extract_novel_description(soup)

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

        except (OSError, requests.RequestException, ValueError, json.JSONDecodeError, AttributeError) as e:
            logger.error(f"AliceSW获取小说信息失败: {e!s}")
            return {
                "title": "未知小说",
                "author": "未知作者",
                "url": novel_url,
                "cover_url": "",
                "description": "",
                "chapters": [],
            }

    # ==================== AliceSW专用提取方法 ====================

    def _extract_alice_sw_search_results(
        self, soup, keyword: str
    ) -> list[dict[str, Any]]:
        """提取AliceSW搜索结果"""
        novels = []

        # AliceSW特定的搜索结果选择器
        result_items = soup.find_all("div", class_="list-group-item")
        if not result_items:
            # 备用选择器
            result_items = soup.find_all(["div", "li"], recursive=True)

        for item in result_items:
            try:
                # 查找小说链接
                title_link = item.find("a", href=re.compile(r"/novel/\d+\.html"))
                if not title_link:
                    continue

                title = title_link.get_text().strip()
                # 去掉搜索结果中的序号（如 "1. " 或 "2. " 等）
                title = re.sub(r"^\d+\.\s+", "", title)

                # 过滤无效标题
                if len(title) < 2 or any(
                    nav in title for nav in ["首页", "分类", "排行", "小说", "文章"]
                ):
                    continue

                href = title_link.get("href", "")

                # 提取作者信息
                author = self._extract_alice_sw_author(item)

                # 过滤无效作者
                if author == "未知" or any(
                    nav in author for nav in ["首页", "分类", "排行", "小说", "文章"]
                ):
                    continue

                # 构建完整URL
                novel_url = urllib.parse.urljoin(self.base_url, href)

                if title and novel_url:
                    novels.append(
                        {
                            "title": title,
                            "author": author,
                            "url": novel_url,
                            "source": "alice_sw",
                        }
                    )

            except Exception:
                continue

        # 去重保持顺序
        seen_titles = set()
        unique = []
        for novel in novels:
            if novel["title"] not in seen_titles:
                unique.append(novel)
                seen_titles.add(novel["title"])

        return unique

    def _extract_alice_sw_author(self, item) -> str:
        """提取AliceSW作者信息"""
        text = item.get_text()

        # AliceSW特定的作者提取模式
        author_patterns = [
            r"作者[：:]\s*([^\n\r<>/,，、\[\]]+)",
            r"<a[^>]*>([^<]+)</a>\s*作者[：:]\s*([^\n\r<>/,，、\[\]]+)",
        ]

        for pattern in author_patterns:
            match = re.search(pattern, text)
            if match:
                author = (
                    match.group(1).strip()
                    if len(match.groups()) == 1
                    else match.group(2).strip()
                )
                return author

        # 尝试查找作者链接
        author_link = item.find("a", href=re.compile(r"search\?.*f=author"))
        if author_link:
            return author_link.get_text().strip()

        return "未知"

    def _find_chapter_list_url(self, soup, novel_url: str) -> str:
        """查找章节列表页面的URL

        AliceSW的章节列表链接格式：
        - 文本包含"查看所有章节"
        - href格式: /other/chapters/id/{novel_id}.html
        """
        # 1. 首先尝试查找"查看所有章节"链接
        all_links = soup.find_all("a", href=True)
        for link in all_links:
            href = link.get("href", "")
            text = link.get_text().strip()

            # 匹配"查看所有章节"文本和章节列表URL格式
            if "查看所有章节" in text and re.match(
                r"^/other/chapters/id/\d+\.html$", href
            ):
                return urllib.parse.urljoin(self.base_url, href)

        # 2. 如果没找到，尝试构造章节列表URL
        # AliceSW的章节列表URL模式: /other/chapters/id/{novel_id}.html
        novel_id_match = re.search(r"/novel/(\d+)\.html", novel_url)
        if novel_id_match:
            novel_id = novel_id_match.group(1)
            # 构造AliceSW标准的章节列表URL
            chapter_list_url = f"{self.base_url}/other/chapters/id/{novel_id}.html"
            return chapter_list_url

        return None

    def _extract_alice_sw_chapters_from_list_page(
        self, soup, chapter_list_url: str
    ) -> list[dict[str, Any]]:
        """从章节列表页面提取章节

        基于实际页面结构分析：
        - 章节列表页面URL格式: /other/chapters/id/{novel_id}.html
        - 页面中有多个ul，一个是章节列表，其他是导航和推荐
        - 策略：通过评分系统选择正确的ul
        """
        chapters = []

        # 策略：找到包含章节链接的ul
        # 使用评分系统选择最可能是章节列表的ul
        uls = soup.find_all("ul")

        # 计算每个ul的"章节分数"
        best_ul = None
        best_score = -1

        for ul in uls:
            chapter_links = ul.find_all("a", href=lambda x: x and "/book/" in x)
            if not chapter_links:
                continue

            score = 0
            count = len(chapter_links)

            # 因素1: 章节数量适中（1-100章最有可能）
            if 1 <= count <= 100:
                score += 30
            elif count > 100:
                score += 10  # 太多链接可能是推荐

            # 因素2: 章节标题特征（严格的章节格式）
            chapter_title_count = 0
            for link in chapter_links:
                text = link.get_text().strip()
                # 更严格的章节标题检测
                if re.search(r"第\s*\d+\s*章|第\s*\d+\s*节", text):
                    chapter_title_count += 1

            if count > 0:
                # 章节标题占比高则加分
                score += (chapter_title_count / count) * 70

            # 因素3: 避免导航和推荐内容
            ul_text = ul.get_text()
            nav_keywords = ["推荐", "排行", "分类", "导航", "首页", "书架"]
            for keyword in nav_keywords:
                if keyword in ul_text:
                    score -= 20
                    break

            # 因素4: 如果链接都是/book/格式，加分
            all_book = all(
                re.search(r"/book/\d+/", a.get("href", ""))
                for a in chapter_links
            )
            if all_book and count > 0:
                score += 30

            if score > best_score:
                best_score = score
                best_ul = ul

        if not best_ul:
            # 备用：直接取第一个有/book/链接且数量合理的ul
            for ul in uls:
                chapter_links = ul.find_all("a", href=lambda x: x and "/book/" in x)
                count = len(chapter_links)
                if 1 <= count <= 100:  # 合理的章节数量
                    best_ul = ul
                    break

        if not best_ul:
            return []

        # 从找到的 ul 中提取所有章节
        for a_tag in best_ul.find_all("a", href=True):
            href = a_tag.get("href", "")
            title = a_tag.get_text().strip()

            # 验证是否为有效的章节链接
            if re.match(r"^/book/\d+/[a-f0-9\-]+\.html$", href):
                # 构建完整URL
                if href.startswith("/"):
                    full_url = urllib.parse.urljoin(self.base_url, href)
                else:
                    full_url = urllib.parse.urljoin(chapter_list_url, href)

                if self._is_valid_alice_sw_chapter(title, href):
                    chapters.append({"title": title, "url": full_url})

        return chapters

    def _extract_alice_sw_chapters(self, soup, novel_url: str) -> list[dict[str, Any]]:
        """提取AliceSW章节列表 - 基于实际HTML结构"""
        chapters = []

        # 1. 查找章节列表容器 - 基于网站分析结果
        chapter_containers = soup.find_all("div", class_="book_newchap")

        if not chapter_containers:
            # 备用选择器
            chapter_containers = soup.find_all(
                "div", class_=re.compile(r"book.*chap|chapter.*list", re.I)
            )

        for container in chapter_containers:
            # 在容器内查找章节链接
            # 章节链接通常在 <p class="ti"> 或类似的结构中
            chapter_links = container.find_all("p", class_="ti")
            if not chapter_links:
                # 备用查找方式
                chapter_links = container.find_all(
                    ["p", "li", "div"], class_=re.compile(r"ti|chapter|item", re.I)
                )

            for link_elem in chapter_links:
                # 查找链接
                a_tag = link_elem.find("a", href=True)
                if not a_tag:
                    continue

                href = a_tag.get("href", "")
                title = a_tag.get_text().strip()

                # 构建完整URL
                full_url = urllib.parse.urljoin(novel_url, href)

                # 验证是否为有效的章节链接
                if self._is_valid_alice_sw_chapter(title, href):
                    chapters.append({"title": title, "url": full_url})

        # 2. 如果没有找到专门的章节容器，尝试全局搜索章节链接
        if not chapters:
            # 查找所有符合AliceSW章节URL模式的链接
            for a_tag in soup.find_all("a", href=True):
                href = a_tag.get("href", "")
                title = a_tag.get_text().strip()

                # AliceSW章节URL模式: /book/数字/字符串.html
                if re.match(r"^/book/\d+/[a-f0-9]+\.html$", href):
                    full_url = urllib.parse.urljoin(novel_url, href)
                    chapters.append({"title": title, "url": full_url})

        # 3. 去重并保持顺序
        seen = set()
        unique_chapters = []
        for chapter in chapters:
            if chapter["url"] not in seen and chapter["title"].strip():
                unique_chapters.append(chapter)
                seen.add(chapter["url"])

        return unique_chapters

    def _is_valid_alice_sw_chapter(self, title: str, href: str) -> bool:
        """判断是否为有效的AliceSW章节链接 - 基于实际网站结构"""
        # 1. 基本标题检查
        if not title or len(title.strip()) <= 1:
            return False

        # 2. 检查URL模式 - AliceSW特定的章节URL格式
        # 主要格式: /book/数字/字符串.html 或 /book/数字/字符串.html（带连字符）
        if not re.match(r"^/book/\d+/[a-f0-9\-]+\.html$", href):
            return False

        # 3. 基本标题验证 - 排除明显不是章节的标题
        # 但AliceSW的章节标题通常格式比较规范，所以检查可以宽松一些
        skip_patterns = [
            r"^(登录|注册|首页|分类|排行)$",
            r"^(书架|收藏|推荐|设置)$",
            r"^(javascript:void\(0\)|#)$",
            r"^(more|more chapters|read more)$",
        ]

        for pattern in skip_patterns:
            if re.match(pattern, title.strip(), re.IGNORECASE):
                return False

        # 4. URL符合AliceSW章节格式，标题也不是明显的导航链接，就认为是有效章节
        return True

    def _should_skip_chapter_link(self, title: str, href: str) -> bool:
        """判断是否应该跳过章节链接"""
        skip_patterns = [
            r"javascript:",
            r"#",
            r"目录",
            r"书签",
            r"收藏",
            r"推荐",
            r"排行",
            r"首页",
            r"分类",
        ]

        text = (title + " " + href).lower()
        return any(re.search(pattern, text) for pattern in skip_patterns)

    def _extract_chapter_title(self, soup) -> str:
        """提取章节标题"""
        # 尝试多种标题选择器
        title_selectors = ["h1", "h2", ".chapter-title", ".title", "title"]

        for selector in title_selectors:
            title_elem = soup.select_one(selector)
            if title_elem:
                title = title_elem.get_text().strip()
                if title and len(title) > 1:
                    return title

        return "章节内容"

    def _extract_alice_sw_content(self, soup) -> str:
        """提取AliceSW章节内容"""
        # AliceSW特定的内容选择器
        content_selectors = [
            "#content",
            ".content",
            ".chapter-content",
            ".read-content",
            "div[class*='content']",
            "div[class*='chapter']",
        ]

        content_elem = None
        for selector in content_selectors:
            content_elem = soup.select_one(selector)
            if content_elem:
                break

        # 如果没找到指定容器，尝试通用方法
        if not content_elem:
            content = self.extract_content(soup)
            return content

        # 移除无关元素
        for elem in content_elem.find_all(["script", "style", "ins", "iframe", "div"], class_=re.compile(r"ad")):
            elem.decompose()

        # 智能提取内容，保留段落结构
        content = self._extract_content_with_paragraphs(content_elem)

        # 清理内容
        content = self.clean_text_with_paragraphs(content)

        return content

    def _extract_content_with_paragraphs(self, element) -> str:
        """智能提取内容，保留段落结构"""
        content_parts = []

        # 递归处理元素内容
        for child in element.children:
            # 检查是否是 BeautifulSoup 标签对象
            if hasattr(child, "name") and child.name:  # 是标签元素
                if child.name in ["p", "div", "section", "article"]:
                    # 段落标签，提取其文本内容并添加段落标记
                    paragraph_text = child.get_text().strip()
                    if paragraph_text:
                        content_parts.append(paragraph_text)
                elif child.name == "br":
                    # 换行标签
                    content_parts.append("")
                elif child.name not in ["script", "style", "ins", "iframe"]:
                    # 其他标签，递归处理
                    nested_content = self._extract_content_with_paragraphs(child)
                    if nested_content.strip():
                        content_parts.append(nested_content.strip())
            else:  # 是文本节点（NavigableString 或其他）
                text = str(child).strip()
                if text:
                    content_parts.append(text)

        # 将内容用双换行符连接，保持段落结构
        return "\n\n".join(filter(None, content_parts))

    def clean_text_with_paragraphs(self, text: str) -> str:
        """清理文本内容，保持段落结构"""
        if not text:
            return ""

        # 移除多余的空行（超过2个连续换行符）
        text = re.sub(r"\n{3,}", "\n\n", text)

        # 移除每行开头和结尾的多余空格
        lines = text.split("\n")
        cleaned_lines = [line.strip() for line in lines]

        # 重新组合，保持双换行符作为段落分隔
        text = "\n".join(cleaned_lines)

        # 确保段落之间有适当的分隔
        text = re.sub(r"([.!?。！？])\n([A-Z\u4e00-\u9fa5])", r"\1\n\n\2", text)

        # 移除段落内部的多余空格
        paragraphs = text.split("\n\n")
        cleaned_paragraphs = []
        for paragraph in paragraphs:
            # 保留段落内的正常空格，但移除多余的连续空格
            cleaned_paragraph = re.sub(r" +", " ", paragraph.strip())
            if cleaned_paragraph:
                cleaned_paragraphs.append(cleaned_paragraph)

        return "\n\n".join(cleaned_paragraphs)

    # ==================== 小说信息提取方法 ====================

    def _extract_novel_title(self, soup) -> str:
        """提取小说标题"""
        title_selectors = [
            "h1.book-title",
            "h1.title",
            "h1",
            ".book-name",
            "title",
        ]

        for selector in title_selectors:
            title_elem = soup.select_one(selector)
            if title_elem:
                title = title_elem.get_text().strip()
                if title and len(title) > 1:
                    return title

        return "未知小说"

    def _extract_novel_author(self, soup) -> str:
        """提取小说作者"""
        # 查找包含"作者"信息的元素
        author_patterns = [
            r"作者[：:]\s*([^\n\r<>/,，、\[\]]+)",
            r"文\s*/\s*([^\n\r]+)",
        ]

        # 先尝试查找带有明确作者标签的元素
        for pattern in author_patterns:
            author_elem = soup.find(string=re.compile(pattern))
            if author_elem:
                match = re.search(pattern, author_elem)
                if match:
                    return match.group(1).strip()

        # 尝试查找作者链接
        author_link = soup.find("a", href=re.compile(r"search\?.*author"))
        if author_link:
            return author_link.get_text().strip()

        # 从页面文本中提取
        page_text = soup.get_text()
        for pattern in author_patterns:
            match = re.search(pattern, page_text)
            if match:
                author = match.group(1).strip()
                if len(author) < 50:  # 防止匹配到过长的文本
                    return author

        return "未知作者"

    def _extract_novel_cover(self, soup, base_url: str) -> str:
        """提取小说封面URL"""
        # 查找封面图片
        cover_selectors = [
            ".book-cover img",
            ".cover img",
            "img.book-cover",
            "img[alt*='封面']",
            "img[alt*='cover']",
        ]

        for selector in cover_selectors:
            img = soup.select_one(selector)
            if img:
                src = img.get("src") or img.get("data-src")
                if src:
                    return urllib.parse.urljoin(base_url, src)

        # 查找页面中的第一张图片
        img = soup.find("img")
        if img:
            src = img.get("src") or img.get("data-src")
            if src:
                return urllib.parse.urljoin(base_url, src)

        return ""

    def _extract_novel_description(self, soup) -> str:
        """提取小说简介"""
        desc_selectors = [
            ".book-description",
            ".description",
            ".book-intro",
            ".intro",
            ".summary",
            "div[class*='desc']",
        ]

        for selector in desc_selectors:
            desc_elem = soup.select_one(selector)
            if desc_elem:
                desc = desc_elem.get_text().strip()
                if len(desc) > 10:
                    return self.clean_text(desc)

        return ""


# 为了向后兼容，创建别名
AliceSWCrawler = AliceSWCrawlerRefactored
