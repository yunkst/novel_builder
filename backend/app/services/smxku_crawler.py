#!/usr/bin/env python3
"""
SMXKU 小说网站爬虫
网站地址: https://www.smxku.com
功能: 搜索小说、获取目录、获取章节内容
"""

import re
from typing import Any
from urllib.parse import urljoin

from .base_crawler import BaseCrawler
from .http_client import RequestConfig, RequestStrategy


class SmxkuCrawler(BaseCrawler):
    """SMXKU小说网站爬虫"""

    def __init__(self):
        super().__init__("https://www.smxku.com", RequestStrategy.HYBRID)
        self.source_name = "smxku"
        self.source_display_name = "蜘蛛小说网"

    async def search_novels(self, keyword: str) -> list[dict[str, Any]]:
        """搜索小说"""
        try:
            # 构建搜索URL
            search_url = f"{self.base_url}/search.php"

            # 配置请求参数
            config = RequestConfig(
                timeout=15,
                max_retries=3,
                strategy=RequestStrategy.HYBRID
            )

            # 发送搜索请求
            response = await self.http_client.get(f"{search_url}?searchkey={keyword}", config)
            final_url = response.url  # 获取最终URL（可能被重定向）
            soup = response.soup()

            results = []

            # 检查是否直接跳转到了小说详情页
            # 小说详情页的URL格式通常是: https://www.smxku.com/novel_id/
            novel_detail_match = re.search(r'/(\d+)/?$', final_url)
            if novel_detail_match:
                # 如果跳转到小说详情页，直接提取这本小说的信息
                novel_id = novel_detail_match.group(1)
                novel_info = await self._extract_novel_from_detail_page(soup, final_url, novel_id)
                if novel_info:
                    return [novel_info]

            # 查找所有小说链接 - SMXKU搜索结果在 h4.bookname 中
            novel_containers = soup.find_all('h4', class_='bookname')
            processed_ids = set()

            for h4 in novel_containers:
                link = h4.find('a')
                if not link:
                    continue

                novel_url = link.get('href', '')
                # 如果是相对路径，转换为完整URL
                if novel_url.startswith('/'):
                    novel_url = urljoin(self.base_url, novel_url)

                novel_id_match = re.search(r'/(\d+)/?$', novel_url)
                novel_id = novel_id_match.group(1) if novel_id_match else ""

                # 跳过已处理过的ID
                if not novel_id or novel_id in processed_ids:
                    continue
                processed_ids.add(novel_id)

                # 获取小说标题
                title = link.get_text(strip=True)

                # 跳过导航链接
                if not title or title in ['首页', '分类', '榜单', '完结', '搜索', '阅读']:
                    continue

                # 尝试获取作者信息
                author = "未知作者"
                parent_element = h4.find_parent(['div', 'li', 'td'])
                if parent_element:
                    author_link = parent_element.find('a', href=re.compile(r'/kw/'))
                    if author_link:
                        author = author_link.get_text(strip=True)

                # 尝试获取简介
                description = ""
                if parent_element:
                    desc_elem = parent_element.find(['p', 'div'], class_=re.compile(r'intro|desc|content'))
                    if desc_elem:
                        description = desc_elem.get_text(strip=True)[:200]

                novel_info = {
                    'id': novel_id,
                    'title': title,
                    'author': author,
                    'description': description,
                    'url': novel_url,
                    'source': self.source_name
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
            novel_id_match = re.search(r'/(\d+)/?$', novel_url)
            if not novel_id_match:
                return []

            novel_id = novel_id_match.group(1)

            # 配置请求
            RequestConfig(
                timeout=15,
                max_retries=3,
                strategy=RequestStrategy.HYBRID
            )

            # 获取小说详情页
            response = await self.get_page(novel_url, timeout=15)
            soup = response.soup()

            chapters = []

            # 查找章节列表容器
            chapter_containers = [
                soup.find('dl', class_=re.compile(r'chapter')),
                soup.find('div', class_=re.compile(r'chapter')),
                soup.find('div', id=re.compile(r'chapter')),
                soup.find('div', id='listsss')
            ]

            chapter_list = None
            for container in chapter_containers:
                if container:
                    chapter_list = container
                    break

            if not chapter_list:
                # 如果没找到特定容器，查找所有章节链接
                chapter_links = soup.find_all('a', href=re.compile(f'^/{novel_id}/\\d+\\.html$'))
                for link in chapter_links:
                    chapter_title = link.get_text(strip=True)
                    chapter_url = urljoin(self.base_url, link['href'])

                    # 提取章节号
                    chapter_id_match = re.search(r'/(\d+)\.html$', link['href'])
                    chapter_id = chapter_id_match.group(1) if chapter_id_match else ""

                    if chapter_title and chapter_id:
                        chapters.append({
                            'id': chapter_id,
                            'title': chapter_title,
                            'url': chapter_url
                        })
            else:
                # 从容器中提取章节
                chapter_links = chapter_list.find_all('a', href=re.compile(f'^/{novel_id}/\\d+\\.html$'))

                for link in chapter_links:
                    chapter_title = link.get_text(strip=True)
                    chapter_url = urljoin(self.base_url, link['href'])

                    # 提取章节号
                    chapter_id_match = re.search(r'/(\d+)\.html$', link['href'])
                    chapter_id = chapter_id_match.group(1) if chapter_id_match else ""

                    if chapter_title and chapter_id:
                        chapters.append({
                            'id': chapter_id,
                            'title': chapter_title,
                            'url': chapter_url
                        })

            # 按章节号排序
            chapters.sort(key=lambda x: int(x['id']) if x['id'].isdigit() else 0)

            return chapters

        except Exception as e:
            print(f"SMXKU获取章节列表失败: {e!s}")
            return []

    async def get_chapter_content(self, chapter_url: str) -> dict[str, Any]:
        """获取章节内容"""
        try:
            # 配置请求
            RequestConfig(
                timeout=15,
                max_retries=3,
                strategy=RequestStrategy.HYBRID
            )

            # 获取章节页面
            response = await self.get_page(chapter_url, timeout=15)
            soup = response.soup()

            # 获取章节标题
            title_elem = soup.find('h1')
            title = title_elem.get_text(strip=True) if title_elem else "章节内容"

            # 优先使用SMXKU特定的内容提取方法，确保保留段落结构
            # 查找章节内容的容器
            content_containers = [
                soup.find('div', id=re.compile(r'content')),
                soup.find('div', class_=re.compile(r'content')),
                soup.find('div', class_=re.compile(r'read')),
                soup.find('div', class_=re.compile(r'text'))
            ]

            content_elem = None
            for container in content_containers:
                if container:
                    content_elem = container
                    break

            if not content_elem:
                # 如果没找到特定容器，尝试基类的通用方法
                content = self.extract_content(soup)
            else:
                # 移除广告和无关元素
                for ad in content_elem.find_all(['script', 'ins', 'iframe', 'style']):
                    ad.decompose()

                # 获取纯文本内容，优先保留段落结构
                paragraphs = content_elem.find_all('p')
                if paragraphs:
                    # 如果有p标签，按段落提取，保持段落分离
                    content_parts = []
                    for p in paragraphs:
                        text = p.get_text(strip=True)
                        if text and len(text) > 5:  # 过滤太短的段落
                            content_parts.append(text)
                    content = '\n\n'.join(content_parts)
                else:
                    # 如果没有p标签，则提取整个容器的文本
                    content = content_elem.get_text(strip=True)

                # 清理内容
                content = re.sub(r'^.*?已发布罪薪章劫.*?$', '', content, flags=re.MULTILINE)
                content = re.sub(r'www\.[^\s]+', '', content)
                content = re.sub(r'（使用快捷键.*?）', '', content)
                content = re.sub(r'\(本章完\)', '', content)
                content = self.clean_text(content)

            # 最终清理
            content = self.clean_text(content)

            return {
                'title': title,
                'content': content,
                'url': chapter_url,
                'word_count': len(content),
                'source': self.source_name
            }

        except Exception as e:
            print(f"SMXKU获取章节内容失败: {e!s}")
            return {
                'title': "章节内容",
                'content': f"获取失败: {e!s}",
                'url': chapter_url,
                'word_count': 0,
                'source': self.source_name
            }

    async def _extract_novel_from_detail_page(self, soup, novel_url: str, novel_id: str) -> dict[str, Any]:
        """从小说详情页提取小说信息"""
        try:
            # 查找小说标题 - 通常在 h1 或其他标题元素中
            title_elem = soup.find('h1')
            if not title_elem:
                # 尝试其他可能的标题选择器
                title_elem = soup.find('div', class_='title')
            if not title_elem:
                # 尝试查找包含小说信息的元素
                title_elem = soup.find('title')

            title = title_elem.get_text(strip=True) if title_elem else f"小说ID: {novel_id}"

            # 清理标题，移除网站名称等后缀
            title = re.sub(r'- 蜘蛛小说网.*$', '', title).strip()
            title = re.sub(r'_.*$', '', title).strip()

            # 查找作者信息
            author = "未知作者"
            # 尝试多种作者信息选择器
            author_patterns = [
                soup.find('a', href=re.compile(r'/kw/\d+')),
                soup.find('span', string=re.compile(r'作者')),
                soup.find('div', class_=re.compile(r'author')),
                soup.find('p', string=re.compile(r'作者')),
            ]

            for pattern in author_patterns:
                if pattern:
                    if pattern.name == 'a':
                        author = pattern.get_text(strip=True)
                    else:
                        # 如果是包含"作者"文本的元素，查找旁边的作者链接
                        author_link = pattern.find_next('a') if pattern.name != 'a' else pattern
                        if author_link:
                            author = author_link.get_text(strip=True)
                    if author and author != "未知作者":
                        break

            # 查找简介信息
            description = ""
            desc_patterns = [
                soup.find('div', class_=re.compile(r'intro|desc|content|summary')),
                soup.find('p', class_=re.compile(r'intro|desc|content|summary')),
                soup.find('div', id=re.compile(r'intro|desc|content|summary')),
            ]

            for pattern in desc_patterns:
                if pattern:
                    description = pattern.get_text(strip=True)[:200]
                    if description:
                        break

            # 如果没找到简介，尝试获取页面第一段文字作为描述
            if not description:
                first_p = soup.find('p')
                if first_p and len(first_p.get_text(strip=True)) > 20:
                    description = first_p.get_text(strip=True)[:200]

            return {
                'id': novel_id,
                'title': title,
                'author': author,
                'description': description,
                'url': novel_url,
                'source': self.source_name
            }

        except Exception as e:
            print(f"从详情页提取小说信息失败: {e!s}")
            # 返回基本信息
            return {
                'id': novel_id,
                'title': f"小说ID: {novel_id}",
                'author': "未知作者",
                'description': "",
                'url': novel_url,
                'source': self.source_name
            }
