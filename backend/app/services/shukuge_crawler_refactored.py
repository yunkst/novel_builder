#!/usr/bin/env python3
"""
重构版Shukuge爬虫

使用网络请求抽象层，专注于业务逻辑实现
"""

import re
import urllib.parse
from typing import Any, Dict, List

from .enhanced_base_crawler import EnhancedBaseCrawler
from .http_client import RequestConfig, RequestStrategy


class ShukugeCrawlerRefactored(EnhancedBaseCrawler):
    """重构版书库爬虫"""

    def __init__(self):
        # Shukuge使用HTTP，可以用简单策略
        super().__init__(
            base_url="http://www.shukuge.com",
            strategy=RequestStrategy.SIMPLE
        )

        # 自定义请求头
        self.custom_headers = {
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Accept-Encoding": "gzip, deflate",
            "Connection": "keep-alive"
        }

    async def search_novels(self, keyword: str) -> List[Dict[str, Any]]:
        """搜索小说"""
        try:
            # 尝试多个搜索入口
            search_urls = [
                f"{self.base_url}/Search",
                f"{self.base_url}/modules/article/search.php",
                f"{self.base_url}/search.php"
            ]

            for i, search_url in enumerate(search_urls):
                try:
                    config = RequestConfig(
                        timeout=10,
                        max_retries=2,
                        strategy=RequestStrategy.SIMPLE,
                        custom_headers=self.custom_headers
                    )

                    if "search.php" in search_url:
                        # POST方式搜索
                        data = {"searchkey": keyword, "searchtype": "all"}
                        response = await self.post_form(search_url, data, timeout=10)
                    else:
                        # GET方式搜索
                        params = {"wd": keyword}
                        # 构建完整URL
                        full_url = f"{search_url}?{urllib.parse.urlencode(params)}"
                        response = await self.get_page(full_url, timeout=10)

                    # 提取搜索结果
                    novels = self._extract_shukuge_search_results(response.soup(), keyword)

                    if novels:
                        return novels[:20]

                except Exception as e:
                    print(f"搜索入口{i+1}失败: {str(e)}")
                    continue

            return []

        except Exception as e:
            print(f"Shukuge搜索失败: {str(e)}")
            return []

    async def get_chapter_list(self, novel_url: str) -> List[Dict[str, Any]]:
        """获取章节列表"""
        try:
            # 配置请求
            config = RequestConfig(
                timeout=10,
                max_retries=3,
                strategy=RequestStrategy.SIMPLE,
                custom_headers=self.custom_headers
            )

            # 1. 访问小说详情页
            response = await self.get_page(novel_url, timeout=10)

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
            print(f"Shukuge获取章节列表失败: {str(e)}")
            return []

    async def get_chapter_content(self, chapter_url: str) -> Dict[str, Any]:
        """获取章节内容"""
        try:
            # 配置请求
            config = RequestConfig(
                timeout=10,
                max_retries=3,
                retry_delay=0.8,  # Shukuge需要稍长的延迟
                strategy=RequestStrategy.SIMPLE,
                custom_headers=self.custom_headers
            )

            # 获取章节页面
            response = await self.get_page(chapter_url, timeout=10)

            # 提取内容
            soup = response.soup()

            # 获取标题
            title = self._extract_chapter_title(soup)

            # 获取内容
            content = self._extract_shukuge_content(soup)

            return {"title": title, "content": content}

        except Exception as e:
            print(f"Shukuge获取章节内容失败: {str(e)}")
            return {"title": "章节内容", "content": f"获取失败: {str(e)}"}

    # ==================== Shukuge专用提取方法 ====================

    def _extract_shukuge_search_results(self, soup, keyword: str) -> List[Dict[str, Any]]:
        """提取Shukuge搜索结果"""
        novels = []

        # 查找所有可能包含小说信息的链接
        all_links = soup.find_all("a", href=True, string=True)

        for link in all_links:
            try:
                title = link.get_text().strip()
                href = link.get("href", "")

                # 过滤条件
                if (keyword.lower() not in title.lower() or
                    not any(ind in href for ind in ["/book/", "/read/", "/modules/article"]) or
                    len(title) < 2):
                    continue

                # 提取作者信息
                author = self._extract_shukuge_author(link)

                # 构建完整URL
                novel_url = urllib.parse.urljoin(self.base_url, href)

                novels.append({
                    "title": title,
                    "author": author,
                    "url": novel_url,
                    "source": "shukuge"
                })

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
        parent = link.parent

        if parent:
            text = parent.get_text()
            # Shukuge特定的作者提取模式
            match = re.search(r"作者[：:]\s*([^\s\n\r<>/]+)", text)
            if match:
                author = match.group(1).strip()

        return author

    async def _try_special_chapter_page(self, novel_url: str, soup) -> List[Dict[str, Any]]:
        """尝试从专用章节页获取章节列表"""
        try:
            # 提取小说ID
            novel_id_match = re.search(r"/book/(\d+)/", novel_url)
            if not novel_id_match:
                return []

            novel_id = novel_id_match.group(1)
            chapter_list_url = f"{self.base_url}/other/chapters/id/{novel_id}.html"

            # 访问专用章节页
            response = await self.get_page(chapter_list_url, timeout=10)
            chapters = self.extract_chapters(response.soup(), chapter_list_url)

            return chapters

        except Exception:
            return []

    async def _try_reading_links(self, novel_url: str, soup) -> List[Dict[str, Any]]:
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
                read_url = urllib.parse.urljoin(novel_url, read_links[0].get("href", ""))

                # 访问阅读页面
                response = await self.get_page(read_url, timeout=10)
                chapters = self.extract_chapters(response.soup(), read_url)

                return chapters

            return []

        except Exception:
            return []

    def _extract_chapter_title(self, soup) -> str:
        """提取章节标题"""
        # Shukuge特定的标题选择器
        title_selectors = [
            "h1",
            "h2",
            ".chapter-title",
            ".title",
            "title"
        ]

        for selector in title_selectors:
            title_elem = soup.select_one(selector)
            if title_elem:
                title = title_elem.get_text().strip()
                if title and len(title) > 1:
                    return title

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
            "div.showtxt"
        ]

        content_elem = None
        for selector in content_selectors:
            content_elem = soup.select_one(selector)
            if content_elem:
                break

        # 如果没找到指定容器，尝试最长div方法
        if not content_elem:
            divs = soup.find_all("div")
            longest_div = None
            max_text_length = 0

            for div in divs:
                text_length = len(div.get_text())
                if text_length > max_text_length:
                    max_text_length = text_length
                    longest_div = div

            if longest_div and max_text_length > 500:
                content_elem = longest_div

        if not content_elem:
            return ""

        # 移除脚本和样式
        for elem in content_elem(["script", "style"]):
            elem.decompose()

        # 获取文本内容
        content = content_elem.get_text()

        # 清理内容
        content = self.clean_text(content)

        return content


# 为了向后兼容，创建别名
ShukugeCrawler = ShukugeCrawlerRefactored