#!/usr/bin/env python3
"""
我的书城爬虫

https://www.wodeshucheng.net/
支持小说搜索、章节列表获取、章节内容抓取
"""

import re
import urllib.parse
from typing import Any, Dict, List, Optional

from bs4 import BeautifulSoup

from .base_crawler import BaseCrawler
from .http_client import RequestStrategy


class WodeshuchengCrawler(BaseCrawler):
    """我的书城爬虫"""

    def __init__(self):
        super().__init__("https://www.wodeshucheng.net", RequestStrategy.HYBRID)
        self.name = "我的书城"
        self.site_id = "wodeshucheng"

    async def search_novels(self, keyword: str) -> List[Dict[str, Any]]:
        """
        搜索小说
        由于原网站搜索功能跳转到外部，使用分类页面作为替代方案
        """
        try:
            # 构建搜索URL - 使用分类页面
            category_url = f"{self.base_url}/xuanhuanxiaoshuo/"

            # 获取分类页面
            response = await self.get_page(category_url)
            if not response.success:
                return []

            soup = response.soup()
            novels = []

            # 查找小说列表项
            book_items = soup.find_all('div', class_='item')
            for item in book_items:
                try:
                    # 提取标题和链接
                    title_link = item.find('h3', class_='title').find('a') if item.find('h3', class_='title') else None
                    if not title_link:
                        continue

                    title = title_link.get_text().strip()
                    href = title_link.get('href', '')

                    # 过滤包含关键词的小说
                    if keyword.lower() not in title.lower():
                        continue

                    # 构建完整URL
                    full_url = urllib.parse.urljoin(self.base_url, href)

                    # 提取其他信息
                    author_elem = item.find('div', class_='author')
                    author = author_elem.get_text().strip().replace('作者：', '') if author_elem else "未知作者"

                    # 提取简介
                    desc_elem = item.find('div', class_='intro')
                    description = desc_elem.get_text().strip() if desc_elem else ""

                    # 提取分类
                    category_elem = item.find('div', class_='cat')
                    category = category_elem.get_text().strip() if category_elem else "小说"

                    # 提取状态
                    status_elem = item.find('div', class_='status')
                    status = "连载" if status_elem and "连载" in status_elem.get_text() else "完结"

                    novel_info = {
                        'title': title,
                        'author': author,
                        'url': full_url,
                        'description': description,
                        'category': category,
                        'status': status,
                        'source': self.name
                    }

                    novels.append(novel_info)

                except Exception:
                    continue

            # 如果没有找到，尝试在其他页面搜索
            if not novels:
                # 可以扩展到其他分类页面
                categories = ['都市', '仙侠', '历史', '科幻', '游戏']
                for cat in categories:
                    if len(novels) >= 10:  # 限制结果数量
                        break
                    cat_url = f"{self.base_url}/{cat.lower()}xiaoshuo/"
                    try:
                        cat_response = await self.get_page(cat_url)
                        if cat_response.success:
                            cat_novels = self._extract_novels_from_category(cat_response.soup(), keyword)
                            novels.extend(cat_novels)
                    except Exception:
                        continue

            return novels[:20]  # 限制返回数量

        except Exception as e:
            print(f"搜索小说失败: {e}")
            return []

    async def get_chapter_list(self, novel_url: str) -> List[Dict[str, Any]]:
        """获取章节列表"""
        try:
            # 获取小说详情页
            response = await self.get_page(novel_url)
            if not response.success:
                return []

            soup = response.soup()
            chapters = []

            # 查找章节目录容器
            chapter_container = soup.find('div', class_='box_con')
            if not chapter_container:
                chapter_container = soup.find('div', id='list')

            if chapter_container:
                # 提取章节链接
                chapter_links = chapter_container.find_all('a', href=True)

                for link in chapter_links:
                    try:
                        title = link.get_text().strip()
                        href = link.get('href', '')

                        # 过滤非章节链接
                        if (len(title) < 2 or
                            not href or
                            href.startswith('javascript:') or
                            any(word in title for word in ['目录', '书架', '推荐', '排行'])):
                            continue

                        # 构建完整URL
                        full_url = urllib.parse.urljoin(self.base_url, href)

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

        except Exception as e:
            print(f"获取章节列表失败: {e}")
            return []

    async def get_chapter_content(self, chapter_url: str) -> Dict[str, Any]:
        """获取章节内容"""
        try:
            # 获取章节页面
            response = await self.get_page(chapter_url)
            if not response.success:
                return {"title": "章节内容", "content": f"获取失败: 无法访问页面"}

            soup = response.soup()

            # 提取章节标题
            title_elem = soup.find('div', class_='bookname')
            if title_elem:
                title_h1 = title_elem.find('h1')
                title = title_h1.get_text().strip() if title_h1 else "章节内容"
            else:
                # 备用标题提取
                title_h1 = soup.find('h1')
                title = title_h1.get_text().strip() if title_h1 else "章节内容"

            # 提取章节内容
            content_elem = soup.find('div', id='content')
            if not content_elem:
                # 备用内容提取
                content_elem = soup.find('div', class_='showtxt')

            if not content_elem:
                # 再次尝试其他可能的选择器
                content_selectors = [
                    'div.chapter-content',
                    'div.readcontent',
                    'div.book_con',
                    'div.content'
                ]
                for selector in content_selectors:
                    content_elem = soup.select_one(selector)
                    if content_elem:
                        break

            if content_elem:
                # 移除不需要的元素
                for elem in content_elem(['script', 'style', 'ins', 'iframe', 'div']):
                    if elem.name == 'div' and 'ad' in elem.get('class', []):
                        elem.decompose()

                # 获取文本内容
                content = content_elem.get_text()

                # 清理内容
                content = self._clean_chapter_content(content)

                return {
                    "title": title,
                    "content": content
                }
            else:
                return {
                    "title": title,
                    "content": "无法提取章节内容，可能页面结构已变化"
                }

        except Exception as e:
            print(f"获取章节内容失败: {e}")
            return {"title": "章节内容", "content": f"获取失败: {str(e)}"}

    # ==================== 私有辅助方法 ====================

    def _extract_novels_from_category(self, soup: BeautifulSoup, keyword: str) -> List[Dict[str, Any]]:
        """从分类页面提取小说信息"""
        novels = []

        # 查找所有可能的小说容器
        containers = soup.find_all(['div', 'li'], class_=lambda x: x and ('item' in str(x) or 'book' in str(x)))

        for container in containers:
            try:
                # 查找标题链接
                title_link = container.find('a', href=True)
                if not title_link:
                    continue

                title = title_link.get_text().strip()

                # 过滤关键词
                if keyword.lower() not in title.lower():
                    continue

                href = title_link.get('href', '')
                full_url = urllib.parse.urljoin(self.base_url, href)

                # 提取作者信息
                author = "未知作者"
                author_text = container.get_text()
                author_match = re.search(r'作者[：:]\s*([^\s\n<>/]+)', author_text)
                if author_match:
                    author = author_match.group(1).strip()

                novels.append({
                    'title': title,
                    'author': author,
                    'url': full_url,
                    'description': "",
                    'category': "小说",
                    'status': "unknown",
                    'source': self.name
                })

            except Exception:
                continue

        return novels

    def _clean_chapter_content(self, content: str) -> str:
        """清理章节内容"""
        if not content:
            return ""

        # 移除常见的广告和无用文本
        patterns_to_remove = [
            r'【.*?】',
            r'<!--.*?-->',
            r'广告.*?推广',
            r'天才一秒记住.*?',
            r'更新最快.*?',
            r'手机用户请浏览.*?',
            r'请记住本站域名.*?',
            r'本章未完.*?点击下一页.*?',
            r'\s*-->>\s*',
            r'\s*<<--\s*',
            r'收藏.*?书架',
            r'推荐.*?朋友'
        ]

        for pattern in patterns_to_remove:
            content = re.sub(pattern, '', content, flags=re.IGNORECASE)

        # 清理多余的空白字符
        content = re.sub(r'\n\s*\n', '\n\n', content)
        content = re.sub(r' +', ' ', content)
        content = content.strip()

        return content