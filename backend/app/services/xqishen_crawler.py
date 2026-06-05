#!/usr/bin/env python3
"""
齐盛小说网 (xqishen.com) 爬虫

站点特点：
- 小说详情页：/xiaoshuo/{id}/
- 章节内容页：/xiaoshuo/{id}/{chapter_id}.html
- 章节列表直接在小说详情页中
"""

import re
from typing import Any

from .base_crawler import BaseCrawler
from .http_client import RequestStrategy


class XqishenCrawler(BaseCrawler):
    """齐盛小说网爬虫"""

    def __init__(self):
        super().__init__(
            base_url="https://www.xqishen.com",
            strategy=RequestStrategy.SIMPLE,
        )

        self.custom_headers = {
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Referer": "https://www.xqishen.com/",
        }

    def _extract_novel_id(self, url: str) -> str:
        """从 URL 中提取小说ID"""
        # URL 格式: /xiaoshuo/123456/ 或 /xiaoshuo/123456/1234567890.html
        match = re.search(r"/xiaoshuo/(\d+)/?", url)
        if match:
            return match.group(1)
        return ""

    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """
        搜索小说 - 齐盛小说网暂不提供站内搜索功能
        """
        # 该站点不支持站内搜索，可以通过外部搜索引擎搜索
        return []

    async def get_chapter_list(self, novel_url: str, force_refresh: bool = False) -> list[dict[str, Any]]:
        """获取章节列表"""
        try:
            novel_id = self._extract_novel_id(novel_url)
            if not novel_id:
                return []

            response = await self.get_page(
                novel_url,
                custom_headers=self.custom_headers,
                timeout=30,
            )
            soup = response.soup()

            chapters = []
            seen_urls: set[str] = set()

            # 章节列表在章节目录部分，查找所有匹配的链接
            # 格式: /xiaoshuo/{id}/{chapter_id}.html
            links = soup.find_all(
                "a",
                href=re.compile(rf"/xiaoshuo/{novel_id}/\d+\.html"),
            )

            for link in links:
                href = link.get("href", "")
                if not href or href in seen_urls:
                    continue
                if not href.startswith("http"):
                    href = self.base_url + href

                title = link.get_text(strip=True)
                if not title or len(title) < 2:
                    continue

                seen_urls.add(href)

                # 提取章节序号
                chapter_match = re.search(rf"/xiaoshuo/{novel_id}/(\d+)\.html", href)
                chapter_index = int(chapter_match.group(1)) if chapter_match else 0

                chapters.append({
                    "title": title,
                    "url": href,
                    "chapter_index": chapter_index,
                })

            # 按章节序号排序
            chapters.sort(key=lambda x: x["chapter_index"])
            return chapters

        except Exception as e:
            print(f"获取章节列表失败: {e}")
            return []

    async def get_chapter_content(self, chapter_url: str, novel_url: str = "", force_refresh: bool = False) -> dict[str, Any]:
        """获取章节内容"""
        try:
            response = await self.get_page(
                chapter_url,
                custom_headers=self.custom_headers,
                timeout=30,
            )

            soup = response.soup()

            # 提取标题
            title = ""
            # 优先从 title 标签提取
            title_elem = soup.find("title")
            if title_elem:
                title_text = title_elem.get_text(strip=True)
                # 清理标题格式: "章节名_小说名_齐盛小说网"
                title = re.sub(r".*_", "", title_text)
                title = re.sub(r"_(第\d+章.*)", r"\1", title)
                if title == title_text:
                    # 如果清理后和原标题相同，使用整个标题
                    title = re.sub(r"_[^_]*$", "", title_text)
                title = title.strip()

            # 提取内容
            content = ""

            # 尝试多种内容容器
            content_elem = soup.find("div", id="content")
            if not content_elem:
                content_elem = soup.find("div", class_="content")
            if not content_elem:
                content_elem = soup.find("div", id="chaptercontent")
            if not content_elem:
                content_elem = soup.find("div", class_="read-content")

            if content_elem:
                # 清理广告和脚本
                for tag in content_elem.find_all(["script", "style", "iframe", "ins"]):
                    tag.decompose()

                # 提取纯文本并分段
                text = content_elem.get_text(separator="\n", strip=True)
                content = self.clean_text(text)

            if not content:
                # 使用通用提取方法
                content = self.extract_content(response).get("content", "")

            # 清理章节末尾的广告
            ad_patterns = [
                r"齐盛小说网.*$",
                r"看小说.*网站.*$",
                r"记住.*?\.com",
                r"www.*?\.com",
                r"本章.*?来自.*$",
                r"请安装.*?APP.*$",
            ]
            for pattern in ad_patterns:
                content = re.sub(pattern, "", content, flags=re.DOTALL)

            # 移除重复内容（网站有时会重复输出章节内容）
            lines = content.split("\n")
            content = "\n".join(lines[:len(lines)//2] if len(lines) > 100 else lines)

            content = content.strip()

            return {
                "title": title if title else "章节内容",
                "content": content,
            }

        except Exception as e:
            print(f"获取章节内容失败: {e}")
            return {"title": "", "content": ""}

    async def get_novel_info(self, novel_url: str) -> dict[str, Any]:
        """获取小说详细信息"""
        try:
            novel_id = self._extract_novel_id(novel_url)
            if not novel_id:
                return {
                    "title": "未知小说",
                    "author": "未知作者",
                    "url": novel_url,
                    "cover_url": "",
                    "description": "",
                    "chapters": [],
                }

            response = await self.get_page(
                novel_url,
                custom_headers=self.custom_headers,
                timeout=30,
            )
            soup = response.soup()

            # 提取小说标题
            title = ""
            title_elem = soup.find("h1")
            if title_elem:
                title = title_elem.get_text(strip=True)
            if not title:
                title_elem = soup.find("title")
                if title_elem:
                    title = title_elem.get_text(strip=True)
                    title = re.sub(r"_[^_]*$", "", title)

            # 提取作者
            author = "未知作者"
            author_texts = soup.find_all(text=re.compile(r"作\s*[者：:]"))
            for text in author_texts:
                parent = text.parent
                if parent:
                    author = parent.get_text(strip=True)
                    author = re.sub(r"作\s*[者：:]\s*", "", author)
                    break

            # 提取封面
            cover_url = ""
            cover_img = soup.find("img", src=re.compile(r"/\d+/\d+/s\.jpg"))
            if cover_img:
                cover_url = cover_img.get("src", "")
                if cover_url and not cover_url.startswith("http"):
                    cover_url = self.base_url + cover_url

            # 提取简介
            description = ""
            desc_elem = soup.find("div", class_=re.compile(r"desc|intro|description"))
            if desc_elem:
                description = desc_elem.get_text(strip=True)

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