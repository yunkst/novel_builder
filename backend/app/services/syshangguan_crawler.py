#!/usr/bin/env python3
"""
爱尚小说网爬虫

使用网络请求抽象层，专注于业务逻辑实现
网站: https://m.syshangguan.com/
"""

import asyncio
import re
import urllib.parse
from typing import Any, Dict, List

from .base_crawler import BaseCrawler
from .http_client import RequestConfig, RequestStrategy


class SyshangguanCrawler(BaseCrawler):
    """爱尚小说网爬虫"""

    def __init__(self):
        # 爱尚小说网使用标准请求策略
        super().__init__(
            base_url="https://m.syshangguan.com",
            strategy=RequestStrategy.HYBRID  # 混合模式，根据需要选择最佳策略
        )

        # 自定义请求头，模拟移动端浏览器
        self.custom_headers = {
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Accept-Encoding": "gzip, deflate",  # 避免brotli压缩
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"
        }

    async def search_novels(self, keyword: str) -> List[Dict[str, Any]]:
        """搜索小说"""
        try:
            # 爱尚小说网的搜索功能可能被Cloudflare保护
            # 这里采用通过推荐页面查找的方式
            self._log_info(f"开始搜索小说：{keyword}")

            # 访问首页，通过推荐页面查找相关小说
            response = await self.get_page(
                self.base_url,
                headers=self.custom_headers
            )

            if response.status_code != 200:
                self._log_error(f"访问首页失败，状态码：{response.status_code}")
                return []

            soup = response.soup()

            # 查找所有小说链接
            novel_links = soup.find_all('a', href=re.compile(r'/\d+/$'))
            results = []

            for link in novel_links:
                try:
                    title = link.get_text().strip()
                    href = link.get('href')

                    # 模糊匹配标题
                    if (title and href and len(title) > 1 and
                        keyword.lower() in title.lower() or
                        any(char in title for char in keyword)):

                        # 构建完整URL
                        full_url = urllib.parse.urljoin(self.base_url, href)

                        # 查找作者信息
                        author = self._extract_author_from_context(link)

                        # 提取其他信息
                        novel_info = {
                            'title': title,
                            'author': author,
                            'url': full_url,
                            'cover_url': self._extract_cover_url(link),
                            'description': self._extract_description(link),
                            'status': self._extract_status(link),
                            'category': self._extract_category(link),
                            'last_updated': self._extract_last_updated(link)
                        }

                        results.append(novel_info)

                except Exception as e:
                    self._log_error(f"处理搜索结果时出错：{str(e)}")
                    continue

            self._log_info(f"搜索完成，找到 {len(results)} 个结果")
            return results[:10]  # 限制返回数量

        except Exception as e:
            self._log_error(f"搜索失败：{str(e)}")
            return []

    async def get_chapter_list(self, novel_url: str) -> List[Dict[str, Any]]:
        """获取章节列表"""
        try:
            self._log_info(f"获取章节列表：{novel_url}")

            # 获取小说详情页
            response = await self.get_page(
                novel_url,
                headers=self.custom_headers
            )

            if response.status_code != 200:
                self._log_error(f"访问小说详情页失败，状态码：{response.status_code}")
                return []

            soup = response.soup()

            # 查找目录链接
            index_url = None
            index_links = soup.find_all('a', href=re.compile(r'index\.html$'))
            for link in index_links:
                index_url = urllib.parse.urljoin(self.base_url, link.get('href'))
                break

            if not index_url:
                # 尝试构造目录URL
                # 从novel_url中提取novel_id
                novel_id = self._extract_novel_id_from_url(novel_url)
                if novel_id:
                    index_url = f"{self.base_url}/{novel_id}/index.html"
                    self._log_info(f"未找到目录链接，尝试构造：{index_url}")
                else:
                    self._log_error("无法提取novel_id，无法构造目录URL")
                    return []
            else:
                self._log_info(f"找到目录链接：{index_url}")

            # 访问目录页面
            await asyncio.sleep(1)  # 避免请求过快
            index_response = await self.get_page(
                index_url,
                headers=self.custom_headers
            )

            if index_response.status_code != 200:
                self._log_error(f"访问目录页面失败，状态码：{index_response.status_code}")
                return []

            index_soup = index_response.soup()

            # 提取小说ID用于章节链接匹配
            novel_id = self._extract_novel_id_from_url(novel_url)
            chapters = self._extract_syshangguan_chapters(index_soup, novel_id)

            self._log_info(f"成功获取 {len(chapters)} 个章节")
            return chapters

        except Exception as e:
            self._log_error(f"获取章节列表失败：{str(e)}")
            return []

    async def get_chapter_content(self, chapter_url: str) -> Dict[str, Any]:
        """获取章节内容"""
        try:
            self._log_info(f"获取章节内容：{chapter_url}")

            response = await self.get_page(
                chapter_url,
                headers=self.custom_headers
            )

            if response.status_code != 200:
                self._log_error(f"访问章节页面失败，状态码：{response.status_code}")
                return {"title": "章节内容", "content": f"获取失败，状态码：{response.status_code}"}

            soup = response.soup()

            # 获取章节标题
            title_elem = soup.find('title')
            title = "章节内容"
            if title_elem:
                title_text = title_elem.get_text()
                # 提取章节标题
                if '正文' in title_text:
                    title = title_text.split('正文')[0].strip()
                elif '_' in title_text:
                    title = title_text.split('_')[0].strip()
                else:
                    title = title_text.strip()

            # 提取章节内容
            content = self._extract_syshangguan_content(soup)

            return {"title": title, "content": content}

        except Exception as e:
            self._log_error(f"获取章节内容失败：{str(e)}")
            return {"title": "章节内容", "content": f"获取失败：{str(e)}"}

    # ==================== 爱尚小说网专用方法 ====================

    def _extract_novel_id_from_url(self, url: str) -> str:
        """从URL中提取novel_id"""
        # 爱尚小说网的URL格式：https://m.syshangguan.com/198/
        match = re.search(r'/(\d+)/?$', url)
        return match.group(1) if match else ""

    def _extract_syshangguan_chapters(self, soup, novel_id: str) -> List[Dict[str, Any]]:
        """提取爱尚小说网的章节列表"""
        chapters = []

        # 查找章节链接 - 爱尚小说网的章节链接格式：/198/40.html
        chapter_links = soup.find_all('a', href=re.compile(rf'/{novel_id}/\d+\.html'))

        self._log_info(f"找到 {len(chapter_links)} 个可能的章节链接")

        for link in chapter_links:
            try:
                title = link.get_text().strip()
                href = link.get('href')

                if title and href and len(title) > 1:
                    # 构建完整URL
                    chapter_url = urllib.parse.urljoin(self.base_url, href)

                    # 提取章节ID
                    chapter_id = href.split('/')[-1].replace('.html', '')

                    chapters.append({
                        'title': title,
                        'url': chapter_url,
                        'chapter_id': chapter_id
                    })

            except Exception as e:
                self._log_error(f"处理章节链接时出错：{str(e)}")
                continue

        # 如果没找到，尝试查找所有链接
        if not chapters:
            self._log_info("方法1未找到章节，尝试查找所有链接")
            all_links = soup.find_all('a')
            for link in all_links:
                try:
                    href = link.get('href', '')
                    title = link.get_text().strip()

                    # 匹配章节URL模式
                    if (re.match(rf'/{novel_id}/\d+\.html', href) and
                        title and len(title) > 1):

                        chapter_url = urllib.parse.urljoin(self.base_url, href)
                        chapter_id = href.split('/')[-1].replace('.html', '')

                        chapters.append({
                            'title': title,
                            'url': chapter_url,
                            'chapter_id': chapter_id
                        })

                except Exception as e:
                    continue

        # 去重并排序
        unique_chapters = []
        seen_ids = set()

        for chapter in chapters:
            if chapter['chapter_id'] not in seen_ids:
                seen_ids.add(chapter['chapter_id'])
                unique_chapters.append(chapter)

        # 按章节ID排序
        unique_chapters.sort(key=lambda x: int(x['chapter_id']) if x['chapter_id'].isdigit() else 0)

        return unique_chapters

    def _extract_syshangguan_content(self, soup) -> str:
        """提取爱尚小说网的章节内容"""
        # 爱尚小说网特定的内容选择器
        content_selectors = [
            'div#content',
            'div.content',
            'div.readcontent',
            'div.chapter-content',
            'div.text-content',
            'div#BookText',
            'div.BookText'
        ]

        for selector in content_selectors:
            content_div = soup.select_one(selector)
            if content_div:
                # 提取段落文本
                paragraphs = content_div.find_all('p')
                if paragraphs:
                    content = '\n\n'.join([p.get_text().strip() for p in paragraphs if p.get_text().strip()])
                    if content:
                        return self.clean_text(content)
                else:
                    # 如果没有p标签，直接获取文本
                    content = content_div.get_text().strip()
                    if content:
                        return self.clean_text(content)

        # 查找所有p标签
        all_paragraphs = soup.find_all('p')
        content_parts = []

        for p in all_paragraphs:
            text = p.get_text().strip()
            # 过滤掉太短的段落（可能是导航或其他内容）
            if (len(text) > 10 and
                not any(skip_word in text for skip_word in
                       ['首页', '目录', '下一页', '上一页', '加入书签', '推荐', '投票', '搜'])):
                content_parts.append(text)

        if content_parts:
            return self.clean_text('\n\n'.join(content_parts))

        # 查找包含大量文本的div
        all_divs = soup.find_all('div')
        for div in all_divs:
            text = div.get_text().strip()
            if len(text) > 200:  # 假设章节内容至少200字符
                # 检查是否包含导航元素
                if not any(skip_word in text for skip_word in
                          ['请输入搜索关键词', '首页', '我的书架', '阅读记录', '同类最热', '底部广告']):
                    return self.clean_text(text)

        return ""

    def _log_info(self, message: str):
        """记录信息日志"""
        # 这里可以集成项目的日志系统
        print(f"[SyshangguanCrawler] {message}")

    def _log_error(self, message: str):
        """记录错误日志"""
        # 这里可以集成项目的日志系统
        print(f"[SyshangguanCrawler ERROR] {message}")