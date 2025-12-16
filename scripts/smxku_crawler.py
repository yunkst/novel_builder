#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SMXKU 小说网站爬虫
网站地址: https://www.smxku.com
功能: 搜索小说、获取目录、获取章节内容
"""

import requests
import re
import json
import time
import logging
from typing import List, Dict, Optional, Tuple
from urllib.parse import urljoin, quote
from bs4 import BeautifulSoup

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class SMXKUCrawler:
    def __init__(self):
        self.base_url = "https://www.smxku.com"
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'zh-CN,zh;q=0.8,zh-TW;q=0.7,zh-HK;q=0.5,en-US;q=0.3,en;q=0.2',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        })

    def search_novels(self, keyword: str, page: int = 1) -> List[Dict]:
        """
        搜索小说

        Args:
            keyword: 搜索关键词
            page: 页码

        Returns:
            搜索结果列表
        """
        try:
            logger.info(f"开始搜索小说: {keyword}, 页码: {page}")

            search_url = f"{self.base_url}/search.php"
            params = {
                'searchkey': keyword,
                'page': page
            }

            response = self.session.get(search_url, params=params, timeout=10)
            response.raise_for_status()
            response.encoding = 'utf-8'

            soup = BeautifulSoup(response.text, 'html.parser')

            # 查找搜索结果
            results = []

            # 分析搜索结果页面的结构
            # 查找所有小说链接
            novel_links = soup.find_all('a', href=re.compile(r'^/\d+/$'))

            for link in novel_links:
                novel_url = urljoin(self.base_url, link['href'])
                novel_id = link['href'].strip('/')

                # 获取小说标题（通常在链接文本或父元素中）
                title = link.get_text(strip=True)
                if not title:
                    # 尝试从附近的元素获取标题
                    parent = link.find_parent(['div', 'span', 'td', 'li'])
                    if parent:
                        title = parent.get_text(strip=True)

                # 跳过导航链接
                if not title or title in ['首页', '分类', '榜单', '完结', '搜索']:
                    continue

                # 尝试获取作者信息
                author = "未知作者"
                author_link = parent.find('a', href=re.compile(r'/kw/')) if parent else None
                if author_link:
                    author = author_link.get_text(strip=True)

                # 尝试获取简介
                description = ""
                desc_elem = parent.find(['p', 'div'], class_=re.compile(r'intro|desc|content')) if parent else None
                if desc_elem:
                    description = desc_elem.get_text(strip=True)[:200]  # 限制长度

                novel_info = {
                    'id': novel_id,
                    'title': title,
                    'author': author,
                    'description': description,
                    'url': novel_url,
                    'source': 'smxku'
                }

                results.append(novel_info)
                logger.info(f"找到小说: {title} (ID: {novel_id})")

            # 去重
            unique_results = []
            seen_ids = set()
            for novel in results:
                if novel['id'] not in seen_ids:
                    unique_results.append(novel)
                    seen_ids.add(novel['id'])

            logger.info(f"搜索完成，共找到 {len(unique_results)} 本小说")
            return unique_results

        except Exception as e:
            logger.error(f"搜索小说时发生错误: {str(e)}")
            return []

    def get_novel_info(self, novel_id: str) -> Optional[Dict]:
        """
        获取小说详情信息

        Args:
            novel_id: 小说ID

        Returns:
            小说详情信息
        """
        try:
            logger.info(f"获取小说详情: {novel_id}")

            novel_url = f"{self.base_url}/{novel_id}/"
            response = self.session.get(novel_url, timeout=10)
            response.raise_for_status()
            response.encoding = 'utf-8'

            soup = BeautifulSoup(response.text, 'html.parser')

            # 获取小说标题
            title_elem = soup.find('h1')
            title = title_elem.get_text(strip=True) if title_elem else ""

            # 获取作者信息
            author = "未知作者"
            author_link = soup.find('a', href=re.compile(r'/kw/'))
            if author_link:
                author = author_link.get_text(strip=True)

            # 获取小说简介
            description = ""
            desc_elem = soup.find(['div', 'p'], class_=re.compile(r'intro|desc|content'))
            if desc_elem:
                description = desc_elem.get_text(strip=True)

            # 获取状态信息
            status = "连载中"
            status_elem = soup.find(text=re.compile(r'连载|完结|连载中'))
            if status_elem and '完结' in status_elem:
                status = "已完结"

            # 获取最后更新时间
            last_update = ""
            update_elem = soup.find(text=re.compile(r'更新时间|最后更新'))
            if update_elem:
                # 尝试提取日期
                date_match = re.search(r'\d{4}-\d{2}-\d{2}', update_elem)
                if date_match:
                    last_update = date_match.group()

            novel_info = {
                'id': novel_id,
                'title': title,
                'author': author,
                'description': description,
                'status': status,
                'last_update': last_update,
                'url': novel_url,
                'source': 'smxku'
            }

            logger.info(f"获取小说详情成功: {title}")
            return novel_info

        except Exception as e:
            logger.error(f"获取小说详情时发生错误: {str(e)}")
            return None

    def get_chapter_list(self, novel_id: str) -> List[Dict]:
        """
        获取章节列表

        Args:
            novel_id: 小说ID

        Returns:
            章节列表
        """
        try:
            logger.info(f"获取章节列表: {novel_id}")

            novel_url = f"{self.base_url}/{novel_id}/"
            response = self.session.get(novel_url, timeout=10)
            response.raise_for_status()
            response.encoding = 'utf-8'

            soup = BeautifulSoup(response.text, 'html.parser')

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

            logger.info(f"获取章节列表成功，共 {len(chapters)} 章")
            return chapters

        except Exception as e:
            logger.error(f"获取章节列表时发生错误: {str(e)}")
            return []

    def get_chapter_content(self, novel_id: str, chapter_id: str) -> Optional[Dict]:
        """
        获取章节内容

        Args:
            novel_id: 小说ID
            chapter_id: 章节ID

        Returns:
            章节内容
        """
        try:
            logger.info(f"获取章节内容: {novel_id}/{chapter_id}")

            chapter_url = f"{self.base_url}/{novel_id}/{chapter_id}.html"
            response = self.session.get(chapter_url, timeout=10)
            response.raise_for_status()
            response.encoding = 'utf-8'

            soup = BeautifulSoup(response.text, 'html.parser')

            # 获取章节标题
            title_elem = soup.find('h1')
            title = title_elem.get_text(strip=True) if title_elem else ""

            # 查找章节内容的容器
            content_containers = [
                soup.find('div', id=re.compile(r'content')),
                soup.find('div', class_=re.compile(r'content')),
                soup.find('div', class_=re.compile(r'read')),
                soup.find('div', class_=re.compile(r'text'))
            ]

            content = ""
            content_elem = None

            for container in content_containers:
                if container:
                    content_elem = container
                    break

            if content_elem:
                # 移除广告和无关元素
                for ad in content_elem.find_all(['script', 'ins', 'iframe']):
                    ad.decompose()

                # 获取纯文本内容
                paragraphs = content_elem.find_all('p')
                if paragraphs:
                    content = '\n\n'.join([p.get_text(strip=True) for p in paragraphs])
                else:
                    content = content_elem.get_text(strip=True)

            # 清理内容
            content = re.sub(r'^.*?已发布罪薪章劫.*?$', '', content, flags=re.MULTILINE)  # 移可能的干扰文本
            content = re.sub(r'www\.[^\s]+', '', content)  # 移除网址
            content = re.sub(r'（使用快捷键.*?）', '', content)  # 移除提示文本
            content = re.sub(r'\(本章完\)', '', content)  # 移除结束标记
            content = re.sub(r'\n\s*\n', '\n\n', content)  # 清理多余空行
            content = content.strip()

            if not content:
                # 备用方法：查找所有段落
                all_paragraphs = soup.find_all('p')
                content = '\n\n'.join([p.get_text(strip=True) for p in all_paragraphs if p.get_text(strip=True)])
                content = content.strip()

            chapter_info = {
                'id': chapter_id,
                'title': title,
                'content': content,
                'url': chapter_url,
                'word_count': len(content),
                'source': 'smxku'
            }

            logger.info(f"获取章节内容成功: {title}, 字数: {len(content)}")
            return chapter_info if content else None

        except Exception as e:
            logger.error(f"获取章节内容时发生错误: {str(e)}")
            return None


def test_crawler():
    """测试爬虫功能"""
    logger.info("开始测试 SMXKU 爬虫")

    crawler = SMXKUCrawler()

    # 测试搜索功能
    logger.info("=== 测试搜索功能 ===")
    search_results = crawler.search_novels("斗罗")
    logger.info(f"搜索结果: {json.dumps(search_results[:2], ensure_ascii=False, indent=2)}")

    if search_results:
        novel_id = search_results[0]['id']
        logger.info(f"选择小说进行测试: {search_results[0]['title']} (ID: {novel_id})")

        # 测试获取小说详情
        logger.info("=== 测试获取小说详情 ===")
        novel_info = crawler.get_novel_info(novel_id)
        logger.info(f"小说详情: {json.dumps(novel_info, ensure_ascii=False, indent=2)}")

        # 测试获取章节列表
        logger.info("=== 测试获取章节列表 ===")
        chapter_list = crawler.get_chapter_list(novel_id)
        logger.info(f"章节列表数量: {len(chapter_list)}")
        if chapter_list:
            logger.info(f"前5章: {json.dumps(chapter_list[:5], ensure_ascii=False, indent=2)}")

            # 测试获取章节内容
            logger.info("=== 测试获取章节内容 ===")
            chapter_id = chapter_list[0]['id']
            chapter_content = crawler.get_chapter_content(novel_id, chapter_id)
            if chapter_content:
                logger.info(f"章节内容: {json.dumps(chapter_content, ensure_ascii=False, indent=2)}")
                logger.info(f"章节内容预览: {chapter_content['content'][:200]}...")
            else:
                logger.error("获取章节内容失败")
        else:
            logger.error("获取章节列表失败")
    else:
        logger.error("搜索失败，无法进行后续测试")

    logger.info("爬虫测试完成")


if __name__ == "__main__":
    test_crawler()