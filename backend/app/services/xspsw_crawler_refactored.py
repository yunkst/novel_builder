#!/usr/bin/env python3
"""
重构版Xspsw爬虫

使用网络请求抽象层，专注于业务逻辑实现
"""

import asyncio
import re
import urllib.parse
from typing import Any

from .base_crawler import BaseCrawler
from .http_client import RequestConfig, RequestStrategy


class XspswCrawlerRefactored(BaseCrawler):
    """重构版小说网爬虫"""

    def __init__(self):
        # Xspsw是移动端网站，使用简单策略
        super().__init__(
            base_url="https://m.xspsw.com", strategy=RequestStrategy.SIMPLE
        )

        # 移动端请求头
        self.custom_headers = {
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Accept-Encoding": "gzip, deflate",
            "Connection": "keep-alive",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1",
        }

    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """搜索小说"""
        try:
            # 使用真实的搜索功能
            search_url = f"{self.base_url}/search.html"

            # 配置请求
            RequestConfig(
                timeout=10,
                max_retries=3,
                strategy=RequestStrategy.SIMPLE,
                custom_headers=self.custom_headers,
            )

            # 准备搜索参数
            search_data = {"searchkey": keyword.strip()}

            # 发送POST请求进行搜索
            response = await self.post_form(
                search_url, search_data, timeout=10, custom_headers=self.custom_headers
            )

            # 解析搜索结果
            novels = self._parse_xspsw_search_results(response.soup())

            return novels[:10]  # 限制返回数量

        except Exception as e:
            print(f"Xspsw搜索失败: {e!s}")
            # 如果搜索失败，返回一些热门小说作为推荐
            return await self._get_popular_novels()

    async def get_chapter_list(self, novel_url: str) -> list[dict[str, Any]]:
        """获取小说章节列表（支持分页获取完整列表）"""
        try:
            # 从小说URL提取novel_id
            novel_id_match = re.search(r"/xianshishuwu_(\d+)\.html", novel_url)
            if not novel_id_match:
                return []

            novel_id = novel_id_match.group(1)
            all_chapters = []

            # 配置请求
            RequestConfig(
                timeout=10,
                max_retries=3,
                strategy=RequestStrategy.SIMPLE,
                custom_headers=self.custom_headers,
            )

            # 首先访问第一页获取总页数信息
            first_page_url = f"{self.base_url}/xianshishuwu/{novel_id}/"
            response = await self.get_page(
                first_page_url, timeout=10, custom_headers=self.custom_headers
            )

            soup = response.soup()

            # 计算最大页数
            max_page = self._calculate_max_page(soup)

            # 获取所有页的章节
            for page_num in range(1, max_page + 1):
                try:
                    if page_num == 1:
                        page_url = first_page_url
                    else:
                        page_url = (
                            f"{self.base_url}/xianshishuwu/{novel_id}/0_{page_num}.html"
                        )

                    # 访问分页
                    page_response = await self.get_page(
                        page_url, timeout=10, custom_headers=self.custom_headers
                    )
                    page_soup = page_response.soup()

                    # 提取当前页的章节链接
                    page_chapters = self._extract_chapters_from_page(
                        page_soup, self.base_url
                    )
                    all_chapters.extend(page_chapters)

                    # 添加延迟避免请求过快
                    if page_num < max_page:
                        await asyncio.sleep(0.5)

                except Exception as e:
                    print(f"获取第{page_num}页章节失败: {e!s}")
                    continue

            # 去重保持顺序
            return self._deduplicate_chapters(all_chapters)

        except Exception as e:
            print(f"Xspsw获取章节列表异常: {e!s}")
            return []

    async def get_chapter_content(self, chapter_url: str) -> dict[str, Any]:
        """获取章节内容"""
        try:
            # 配置请求
            RequestConfig(
                timeout=10,
                max_retries=3,
                retry_delay=0.6,
                strategy=RequestStrategy.SIMPLE,
                custom_headers=self.custom_headers,
            )

            # 获取章节页面
            response = await self.get_page(
                chapter_url, timeout=10, custom_headers=self.custom_headers
            )

            # 提取内容
            soup = response.soup()

            # 获取标题
            title = self._extract_chapter_title(soup)

            # 获取内容
            content = self._extract_xspsw_content(soup)

            return {"title": title, "content": content}

        except Exception as e:
            print(f"Xspsw获取章节内容失败: {e!s}")
            return {"title": "章节内容", "content": f"获取失败: {e!s}"}

    # ==================== Xspsw专用提取方法 ====================

    def _parse_xspsw_search_results(self, soup) -> list[dict[str, Any]]:
        """解析Xspsw搜索结果页面"""
        novels = []

        # Xspsw搜索结果的特定结构：小说信息在li标签中
        list_items = soup.find_all("li")

        for item in list_items:
            try:
                # 查找链接
                link = item.find("a")
                if not link:
                    continue

                href = link.get("href")
                if not href or not href.startswith("/xianshishuwu_"):
                    continue

                # 从图片alt属性获取标题
                img = item.find("img")
                title = img.get("alt", "").strip() if img else link.get_text(strip=True)

                if not title or len(title) < 2:
                    continue

                # 过滤掉明显不是小说标题的链接
                if any(
                    skip in title.lower()
                    for skip in ["首页", "下一页", "上一页", "更多", "登录", "注册"]
                ):
                    continue

                # 构建完整URL
                novel_url = urllib.parse.urljoin(self.base_url, href)

                # 从li标签的完整文本中提取信息
                full_text = item.get_text()
                author = self._extract_xspsw_author(full_text)
                status = self._extract_xspsw_status(full_text)
                category = self._extract_xspsw_category(full_text)

                novels.append(
                    {
                        "title": title,
                        "url": novel_url,
                        "author": author,
                        "source": "xspsw",
                        "category": category,
                        "status": status,
                    }
                )

            except Exception as e:
                print(f"处理搜索结果项时出错: {e}")
                continue

        # 去重（基于URL）
        return self._deduplicate_novels(novels)

    def _extract_xspsw_author(self, full_text: str) -> str:
        """提取Xspsw作者信息"""
        # 新格式："书名\n作者名N次元连载\n简介"
        # 尝试匹配 "作者名N次元" 格式
        author_match = re.search(r"\n([^\n]+?)N次元", full_text)
        if author_match:
            author = author_match.group(1).strip()
            if author and len(author) > 1:
                return author

        # 旧格式："书名 作者 分类 状态"
        author_match = re.search(r"作者[：:]\s*([^\s\n]+)", full_text)
        if not author_match:
            # 尝试另一种格式：在分类前的名称
            author_match = re.search(
                r"([^\s]+)(?:玄幻|都市|仙侠|历史|科幻|游戏|体育)", full_text
            )

        if author_match:
            return author_match.group(1)

        return "未知作者"

    def _extract_xspsw_status(self, full_text: str) -> str:
        """提取连载状态"""
        if "连载" in full_text:
            return "连载"
        elif "完结" in full_text or "完本" in full_text:
            return "completed"
        return "unknown"

    def _extract_xspsw_category(self, full_text: str) -> str:
        """提取分类信息"""
        categories = ["玄幻", "都市", "仙侠", "历史", "科幻", "游戏", "体育"]
        for category in categories:
            if category in full_text:
                return category
        return "unknown"

    async def _get_popular_novels(self) -> list[dict[str, Any]]:
        """获取热门小说作为搜索fallback"""
        try:
            # 访问首页获取热门小说
            response = await self.get_page(
                self.base_url, timeout=10, custom_headers=self.custom_headers
            )
            soup = response.soup()

            novels = []

            # 查找热门小说链接
            links = soup.find_all("a", href=re.compile(r"/xianshishuwu_\d+\.html"))
            for link in links[:10]:  # 只取前10个
                try:
                    title = link.get_text(strip=True)
                    href = link.get("href")
                    if title and href and len(title) > 2:
                        novel_url = urllib.parse.urljoin(self.base_url, href)
                        novels.append(
                            {
                                "title": title,
                                "url": novel_url,
                                "author": "未知作者",
                                "source": "xspsw",
                            }
                        )
                except Exception:
                    continue

            return novels

        except Exception:
            return []

    def _calculate_max_page(self, soup) -> int:
        """计算最大页数"""
        max_page = 1

        # 尝试从页面中提取总章节数
        total_chapters_text = soup.find(text=re.compile(r"共\s*\d+\s*章"))
        if total_chapters_text:
            total_match = re.search(r"共\s*(\d+)\s*章", str(total_chapters_text))
            if total_match:
                total_chapters = int(total_match.group(1))
                # 每页大约100章，计算最大页数
                max_page = (total_chapters + 99) // 100

        # 查找分页链接，确定最大页数
        pagination_links = soup.find_all(
            "a", href=re.compile(r"/xianshishuwu/\d+/0_\d+\.html")
        )
        for link in pagination_links:
            href = link.get("href", "")
            page_match = re.search(r"/0_(\d+)\.html", href)
            if page_match:
                page_num = int(page_match.group(1))
                max_page = max(max_page, page_num)

        return max_page

    def _extract_chapters_from_page(self, soup, base_url: str) -> list[dict[str, Any]]:
        """从分页中提取章节链接"""
        chapters = []

        # 查找当前页的所有章节链接
        chapter_links = soup.find_all(
            "a", href=re.compile(r"/xianshishuwu/\d+/\d+\.html")
        )

        for link in chapter_links:
            try:
                chapter_title = link.get_text(strip=True)
                chapter_href = link.get("href")

                if chapter_title and chapter_href and len(chapter_title) > 1:
                    full_url = urllib.parse.urljoin(base_url, chapter_href)
                    chapters.append({"title": chapter_title, "url": full_url})

            except Exception:
                continue

        return chapters

    def _deduplicate_chapters(
        self, chapters: list[dict[str, Any]]
    ) -> list[dict[str, Any]]:
        """章节去重保持顺序"""
        seen = set()
        unique = []
        for chapter in chapters:
            if chapter["url"] not in seen:
                unique.append(chapter)
                seen.add(chapter["url"])
        return unique

    def _deduplicate_novels(self, novels: list[dict[str, Any]]) -> list[dict[str, Any]]:
        """小说去重"""
        seen = set()
        unique_novels = []
        for novel in novels:
            if novel["url"] not in seen:
                unique_novels.append(novel)
                seen.add(novel["url"])
        return unique_novels

    def _extract_chapter_title(self, soup) -> str:
        """提取章节标题"""
        # Xspsw特定的标题选择器
        title_selectors = ["h1", "h2", ".chapter-title", ".title", "title"]

        for selector in title_selectors:
            title_elem = soup.select_one(selector)
            if title_elem:
                title = title_elem.get_text().strip()
                if title and len(title) > 1:
                    return title

        return "章节内容"

    def _extract_xspsw_content(self, soup) -> str:
        """提取Xspsw章节内容"""
        # Xspsw特定的内容选择器
        content_selectors = [
            "div#content",
            "div.content",
            "div.txt",
            "div#chapter_content",
            'div[class*="content"]',
            'div[class*="txt"]',
        ]

        content = ""
        content_elem = None

        for selector in content_selectors:
            content_elem = soup.select_one(selector)
            if content_elem:
                # 移除广告和无关元素
                for ad in content_elem.find_all(["script", "style", "ins", "iframe"]):
                    ad.decompose()

                content = content_elem.get_text("\n", strip=True)
                if len(content) > 100:  # 内容长度合理
                    break

        # 如果没有找到内容，尝试其他方法
        if not content or len(content) < 100:
            # 尝试找到最长的div
            divs = soup.find_all("div")
            longest_div = None
            max_text_length = 0

            for div in divs:
                text_length = len(div.get_text())
                if text_length > max_text_length:
                    max_text_length = text_length
                    longest_div = div

            if longest_div and max_text_length > 500:
                # 移除广告和无关元素
                for ad in longest_div.find_all(["script", "style", "ins", "iframe"]):
                    ad.decompose()
                content = longest_div.get_text("\n", strip=True)

        # 清理内容
        if content:
            content = re.sub(r"\n\s*\n", "\n\n", content)
            content = re.sub(r"^\s+|\s+$", "", content)
            content = re.sub(r" +", " ", content)

        return content


# 为了向后兼容，创建别名
XspswCrawler = XspswCrawlerRefactored
