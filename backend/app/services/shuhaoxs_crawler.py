#!/usr/bin/env python3
"""
书豪小说网 (shuhaoxs.com) 爬虫

站点特点：
- 小说详情页：/book/{code}.html
- 章节列表页：/chapter/{code}.html
- 章节内容页：/book/{code}-{num}.html
- 搜索需要使用 sososhu.com 外部搜索
"""

import re
from typing import Any

from .base_crawler import BaseCrawler
from .http_client import RequestStrategy


class ShuhaoxsCrawler(BaseCrawler):
    """书豪小说网爬虫"""

    def __init__(self):
        super().__init__(
            base_url="https://www.shuhaoxs.com",
            strategy=RequestStrategy.SIMPLE,
        )

        self.custom_headers = {
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Referer": "https://www.shuhaoxs.com/",
        }

    def _extract_code_from_url(self, url: str) -> str:
        """从 URL 中提取小说代码"""
        # URL 格式: /book/xxxxx.html 或 /book/xxxxx-1.html
        match = re.search(r"/book/([a-z0-9]+)", url)
        if match:
            return match.group(1)
        return ""

    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """搜索小说"""
        import urllib.parse

        encoded_keyword = urllib.parse.quote(keyword)
        search_url = f"https://www.sososhu.com/?q={encoded_keyword}&site=shuhaoxs"

        try:
            response = await self.get_page(
                search_url,
                custom_headers=self.custom_headers,
                timeout=30,
            )
            soup = response.soup()

            results = []
            seen_urls: set[str] = set()

            # 查找所有匹配 shuhaoxs.com/book/ 的链接
            links = soup.find_all(
                "a",
                href=re.compile(r"www\.shuhaoxs\.com/book/\w+\.html"),
            )

            for link in links:
                url = link.get("href", "")
                if not url or url in seen_urls:
                    continue

                # 过滤非小说详情页
                if not re.search(r"www\.shuhaoxs\.com/book/[a-z0-9]+\.html$", url):
                    continue

                title = link.get_text(strip=True)
                if len(title) < 2 or title.startswith("http"):
                    continue

                seen_urls.add(url)

                # 尝试获取作者信息
                author = ""
                parent = link.find_parent()
                if parent:
                    # 查找作者标签
                    author_match = re.search(r"作者[：:]\s*(\S+)", parent.get_text())
                    if author_match:
                        author = author_match.group(1)

                results.append({
                    "title": title,
                    "url": url,
                    "author": author,
                })

                if len(results) >= 20:
                    break

            return results

        except Exception as e:
            print(f"搜索失败: {e}")
            return []

    async def get_chapter_list(self, novel_url: str) -> list[dict[str, Any]]:
        """获取章节列表"""
        try:
            # 从小说详情页 URL 提取代码
            code = self._extract_code_from_url(novel_url)
            if not code:
                return []

            # 章节列表页 URL
            chapter_list_url = f"{self.base_url}/chapter/{code}.html"

            response = await self.get_page(
                chapter_list_url,
                custom_headers=self.custom_headers,
                timeout=30,
            )
            soup = response.soup()

            chapters = []
            seen_urls: set[str] = set()

            # 查找章节链接
            links = soup.find_all(
                "a",
                href=re.compile(rf"/book/{code}-\d+\.html"),
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
                chapter_match = re.search(rf"/book/{code}-(\d+)\.html", href)
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

    async def get_chapter_content(self, chapter_url: str) -> dict[str, Any]:
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
            title_elem = soup.find("h1") or soup.find("title")
            if title_elem:
                title = title_elem.get_text(strip=True)
                # 清理标题中的站点信息
                title = re.sub(r"[|_\-].*$", "", title).strip()

            # 提取内容
            content = ""
            content_elem = soup.find("div", class_="content")
            if not content_elem:
                content_elem = soup.find("div", id="content")

            if content_elem:
                # 清理广告和脚本
                for tag in content_elem.find_all(["script", "style", "iframe"]):
                    tag.decompose()

                # 提取纯文本并分段
                text = content_elem.get_text(separator="\n", strip=True)
                content = self.clean_text(text)

            if not content:
                # 使用通用提取方法
                content = self.extract_content(response).get("content", "")

            # 清理章节末尾的广告
            ad_patterns = [
                r"最新章引爆剧情.*$",
                r"登录.*追更.*$",
                r"记住.*?\.com",
            ]
            for pattern in ad_patterns:
                content = re.sub(pattern, "", content, flags=re.DOTALL).strip()

            return {
                "title": title,
                "content": content,
            }

        except Exception as e:
            print(f"获取章节内容失败: {e}")
            return {"title": "", "content": ""}


# 向后兼容别名
ShuhaoxsCrawlerRefactored = ShuhaoxsCrawler
