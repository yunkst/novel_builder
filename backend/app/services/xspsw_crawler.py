#!/usr/bin/env python3

import asyncio
import re
import time
import urllib.parse

import requests
from bs4 import BeautifulSoup

from .base_crawler import BaseCrawler


class XspswCrawler(BaseCrawler):
    def __init__(self):
        self.base_url = "https://m.xspsw.com"
        self.session = requests.Session()
        self.session.headers.update(
            {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
                "Accept-Encoding": "gzip, deflate",
                "Connection": "keep-alive",
            }
        )

    async def search(self, keyword: str) -> list[dict]:
        """
        异步搜索方法，用于SearchService
        """
        # 在线程池中执行同步的search_novels方法
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self.search_novels, keyword)

    def search_novels(self, keyword: str) -> list[dict]:
        """
        搜索小说
        使用闲时书屋的真实搜索功能
        """
        try:
            # 使用真实的搜索功能
            search_url = f"{self.base_url}/search.html"

            # 准备搜索参数
            search_data = {
                "searchkey": keyword.strip()
            }

            # 发送 POST 请求进行搜索
            r = self.session.post(search_url, data=search_data, timeout=10)
            enc = getattr(r, "apparent_encoding", None) or r.encoding or "utf-8"
            if enc and enc.lower() in ["gb2312", "gbk"]:
                enc = "gbk"
            r.encoding = enc

            if r.status_code != 200:
                return []

            # 解析搜索结果
            novels = self._parse_search_results(r.text)
            return novels[:10]  # 限制返回数量

        except Exception as e:
            print(f"搜索失败: {e}")
            # 如果搜索失败，返回一些热门小说作为推荐
            return self._get_popular_novels()

    def _parse_search_results(self, html_content: str) -> list[dict]:
        """解析搜索结果页面"""
        try:
            soup = BeautifulSoup(html_content, "html.parser")
            novels = []

            # xspsw 搜索结果的特定结构：小说信息在 li 标签中
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

                    # 从图片 alt 属性获取标题（因为链接文本可能是空的）
                    img = item.find("img")
                    if img:
                        title = img.get("alt", "").strip()
                    else:
                        # 如果没有图片，尝试从链接文本获取
                        title = link.get_text(strip=True)

                    if not title or len(title) < 2:
                        continue

                    # 过滤掉明显不是小说标题的链接
                    if any(skip in title.lower() for skip in
                           ['首页', '下一页', '上一页', '更多', '登录', '注册']):
                        continue

                    novel_url = urllib.parse.urljoin(self.base_url, href)

                    # 从 li 标签的完整文本中提取作者和其他信息
                    full_text = item.get_text()
                    author = "未知作者"

                    # 查找作者信息模式 - xspsw 的格式通常是 "书名 作者 分类 状态"
                    author_match = re.search(r'作者[：:]\s*([^\s\n]+)', full_text)
                    if not author_match:
                        # 尝试另一种格式：在玄幻/都市等分类前的名称
                        author_match = re.search(r'([^\s]+)(?:玄幻|都市|仙侠|历史|科幻|游戏|体育)', full_text)

                    if author_match:
                        author = author_match.group(1)

                    # 查找状态信息
                    status = "unknown"
                    if "连载" in full_text:
                        status = "连载"
                    elif "完结" in full_text or "完本" in full_text:
                        status = "completed"

                    # 查找分类信息
                    category = "unknown"
                    categories = ["玄幻", "都市", "仙侠", "历史", "科幻", "游戏", "体育"]
                    for cat in categories:
                        if cat in full_text:
                            category = cat
                            break

                    novels.append({
                        "title": title,
                        "url": novel_url,
                        "author": author,
                        "source": "xspsw",
                        "category": category,
                        "status": status,
                    })
                except Exception as e:
                    print(f"处理搜索结果项时出错: {e}")
                    continue

            # 去重（基于URL）
            seen = set()
            unique_novels = []
            for novel in novels:
                if novel["url"] not in seen:
                    unique_novels.append(novel)
                    seen.add(novel["url"])

            return unique_novels
        except Exception as e:
            print(f"解析搜索结果失败: {e}")
            return []

    def _get_popular_novels(self) -> list[dict]:
        """获取热门小说作为搜索fallback"""
        try:
            # 访问首页获取热门小说
            r = self.session.get(self.base_url, timeout=10)
            if r.status_code != 200:
                return []

            soup = BeautifulSoup(r.text, "html.parser")
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

    def get_chapter_list(self, novel_url: str) -> list[dict]:
        """获取小说章节列表（支持分页获取完整列表）"""
        try:
            # 从小说URL提取novel_id
            novel_id_match = re.search(r"/xianshishuwu_(\d+)\.html", novel_url)
            if not novel_id_match:
                return []

            novel_id = novel_id_match.group(1)
            all_chapters = []

            # 首先访问第一页获取总页数信息
            first_page_url = f"{self.base_url}/xianshishuwu/{novel_id}/"
            r = self.session.get(first_page_url, timeout=10)
            if r.status_code != 200:
                return []

            soup = BeautifulSoup(r.text, "html.parser")

            # 尝试从页面中提取总章节数和分页信息
            total_chapters_text = soup.find(text=re.compile(r"共\s*\d+\s*章"))
            max_page = 1

            if total_chapters_text:
                # 提取总章节数
                total_match = re.search(r"共\s*(\d+)\s*章", total_chapters_text)
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

            # 获取所有页的章节
            for page_num in range(1, max_page + 1):
                if page_num == 1:
                    page_url = first_page_url
                else:
                    page_url = (
                        f"{self.base_url}/xianshishuwu/{novel_id}/0_{page_num}.html"
                    )

                try:
                    page_response = self.session.get(page_url, timeout=10)
                    if page_response.status_code != 200:
                        continue

                    page_soup = BeautifulSoup(page_response.text, "html.parser")

                    # 查找当前页的所有章节链接
                    chapter_links = page_soup.find_all(
                        "a", href=re.compile(r"/xianshishuwu/\d+/\d+\.html")
                    )

                    for link in chapter_links:
                        try:
                            chapter_title = link.get_text(strip=True)
                            chapter_href = link.get("href")

                            if (
                                chapter_title
                                and chapter_href
                                and len(chapter_title) > 1
                            ):
                                full_url = urllib.parse.urljoin(
                                    self.base_url, chapter_href
                                )
                                all_chapters.append(
                                    {"title": chapter_title, "url": full_url}
                                )
                        except Exception:
                            continue

                    # 添加延迟避免请求过快
                    time.sleep(0.5)

                except Exception as e:
                    # 如果某页获取失败，记录错误但继续获取其他页
                    print(f"获取第{page_num}页章节失败: {e}")
                    continue

            # 去重保持顺序
            seen = set()
            unique = []
            for ch in all_chapters:
                if ch["url"] not in seen:
                    unique.append(ch)
                    seen.add(ch["url"])

            return unique
        except Exception as e:
            print(f"获取章节列表异常: {e}")
            return []

    def get_chapter_content(self, chapter_url: str) -> dict:
        """
        获取章节内容，加入重试机制
        """
        max_retries = 3
        base_sleep = 0.6
        last_error = None

        for attempt in range(max_retries):
            try:
                time.sleep(base_sleep * (1 + attempt))
                r = self.session.get(chapter_url, timeout=10)
                if r.status_code != 200:
                    last_error = f"获取失败，状态码: {r.status_code}"
                    continue

                soup = BeautifulSoup(r.text, "html.parser")

                # 获取章节标题
                title_elem = soup.find("h1") or soup.find("title")
                title = title_elem.get_text().strip() if title_elem else "章节内容"

                # 查找章节内容容器
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
                        for ad in content_elem.find_all(
                            ["script", "style", "ins", "iframe"]
                        ):
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
                        for ad in longest_div.find_all(
                            ["script", "style", "ins", "iframe"]
                        ):
                            ad.decompose()
                        content = longest_div.get_text("\n", strip=True)

                # 清理内容
                if content:
                    content = re.sub(r"\n\s*\n", "\n\n", content)
                    content = re.sub(r"^\s+|\s+$", "", content)
                    content = re.sub(r" +", " ", content)

                if content and len(content) > 100:
                    return {"title": title, "content": content}

                # 内容不够有效，记录并继续重试
                last_error = "未能提取到有效章节内容"

            except Exception as e:
                last_error = str(e)
                continue

        # 多次重试失败，返回错误信息
        return {"title": "章节内容", "content": f"获取章节内容时出现错误: {last_error}"}
