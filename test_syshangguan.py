#!/usr/bin/env python3
"""
Syshangguan Novel Website Crawler - Simple Test
测试版本：爱尚小说网 (https://m.syshangguan.com/)

直接测试已知URL的功能
"""

import requests
import re
import time
import logging
from bs4 import BeautifulSoup
from urllib.parse import urljoin, quote
import sys

# 设置控制台输出编码
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.detach())
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.detach())

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('test_syshangguan.log', encoding='utf-8', errors='replace'),
        logging.StreamHandler(sys.stdout)
    ]
)

class SyshangguanCrawler:
    def __init__(self):
        self.base_url = "https://m.syshangguan.com"
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        })

    def log_info(self, message):
        """记录信息日志"""
        logging.info(message)

    def log_error(self, message):
        """记录错误日志"""
        logging.error(message)

    def log_warning(self, message):
        """记录警告日志"""
        logging.warning(message)

    def get_novel_info(self, novel_url):
        """
        获取小说基本信息
        """
        self.log_info(f"获取小说信息：{novel_url}")

        try:
            response = self.session.get(novel_url, timeout=10)
            if response.status_code != 200:
                self.log_error(f"访问小说页面失败，状态码：{response.status_code}")
                return None

            # 设置正确的编码
            response.encoding = 'utf-8'
            soup = BeautifulSoup(response.content, 'html.parser')

            # 提取小说标题 - 从页面标题中提取
            title = "未知标题"
            title_element = soup.find('title')
            if title_element:
                title_text = title_element.get_text()
                # 去掉网站名和其他信息
                if '最新章节' in title_text:
                    title = title_text.split('最新章节')[0].strip()
                elif '_' in title_text:
                    title = title_text.split('_')[0].strip()
                else:
                    title = title_text.strip()

            # 提取作者 - 从页面中查找作者信息
            author = "未知作者"

            # 方法1：查找包含"作者"的文本
            author_patterns = [
                soup.find('a', href=re.compile(r'author')),
                soup.find('p', string=re.compile(r'作者：')),
                soup.find(string=re.compile(r'作者：([^]]+)'))
            ]

            for pattern in author_patterns:
                if pattern:
                    if hasattr(pattern, 'get_text'):
                        author_text = pattern.get_text().strip()
                        if '作者：' in author_text:
                            author = author_text.replace('作者：', '').strip()
                        else:
                            author = author_text
                        break
                    elif isinstance(pattern, str):
                        if '作者：' in pattern:
                            author = pattern.replace('作者：', '').strip()
                            break

            # 提取小说ID
            novel_id = None
            if novel_url.endswith('/'):
                novel_id = novel_url.rstrip('/').split('/')[-1]
            else:
                novel_id = novel_url.split('/')[-1]

            novel_info = {
                'title': title,
                'author': author,
                'novel_id': novel_id,
                'url': novel_url
            }

            self.log_info(f"小说信息获取成功：{title} - {author}")
            return novel_info

        except Exception as e:
            self.log_error(f"获取小说信息失败：{str(e)}")
            return None

    def get_novel_chapters(self, novel_url, novel_id):
        """
        获取小说章节列表
        """
        self.log_info(f"获取小说章节列表：{novel_url}")

        try:
            # 先从小说详情页查找目录链接
            response = self.session.get(novel_url, timeout=10)
            if response.status_code != 200:
                self.log_error(f"访问小说详情页失败，状态码：{response.status_code}")
                return []

            soup = BeautifulSoup(response.content, 'html.parser')

            # 查找目录链接
            index_url = None
            index_links = soup.find_all('a', href=re.compile(r'index\.html$'))
            for link in index_links:
                index_url = urljoin(self.base_url, link.get('href'))
                break

            if not index_url:
                # 尝试构造目录URL
                index_url = f"{self.base_url}/{novel_id}/index.html"
                self.log_info(f"未找到目录链接，尝试构造：{index_url}")
            else:
                self.log_info(f"找到目录链接：{index_url}")

            # 访问目录页面
            time.sleep(1)
            index_response = self.session.get(index_url, timeout=10)
            if index_response.status_code != 200:
                self.log_error(f"访问目录页面失败，状态码：{index_response.status_code}")
                return []

            # 设置正确的编码
            index_response.encoding = 'utf-8'
            index_soup = BeautifulSoup(index_response.content, 'html.parser')

            # 解析章节列表
            chapters = self._parse_chapter_list(index_soup, novel_id)

            self.log_info(f"成功获取 {len(chapters)} 个章节")
            return chapters

        except Exception as e:
            self.log_error(f"获取章节列表失败：{str(e)}")
            return []

    def _parse_chapter_list(self, soup, novel_id):
        """解析章节列表"""
        chapters = []

        # 查找章节链接
        chapter_links = soup.find_all('a', href=re.compile(rf'/{novel_id}/\d+\.html'))

        self.log_info(f"找到 {len(chapter_links)} 个可能的章节链接")

        for link in chapter_links:
            title = link.get_text().strip()
            href = link.get('href')

            if title and href and len(title) > 1:
                chapter_url = urljoin(self.base_url, href)
                chapter_id = href.split('/')[-1].replace('.html', '')

                chapters.append({
                    'title': title,
                    'url': chapter_url,
                    'chapter_id': chapter_id
                })

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

    def get_chapter_content(self, chapter_url, chapter_id):
        """
        获取章节内容
        """
        self.log_info(f"获取章节内容：{chapter_url}")

        try:
            response = self.session.get(chapter_url, timeout=10)
            if response.status_code != 200:
                self.log_error(f"访问章节页面失败，状态码：{response.status_code}")
                return ""

            soup = BeautifulSoup(response.content, 'html.parser')

            # 解析章节内容
            content = self._parse_chapter_content(soup)

            if content:
                self.log_info(f"成功获取章节内容，长度：{len(content)} 字符")
                return content
            else:
                self.log_error("未能解析到章节内容")
                return ""

        except Exception as e:
            self.log_error(f"获取章节内容失败：{str(e)}")
            return ""

    def _parse_chapter_content(self, soup):
        """解析章节内容"""
        # 查找包含章节内容的div
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
                        return content
                else:
                    # 如果没有p标签，直接获取文本
                    content = content_div.get_text().strip()
                    if content:
                        return content

        # 查找所有p标签
        all_paragraphs = soup.find_all('p')
        content_parts = []

        for p in all_paragraphs:
            text = p.get_text().strip()
            # 过滤掉太短的段落（可能是导航或其他内容）
            if len(text) > 10 and not any(skip_word in text for skip_word in
                                         ['首页', '目录', '下一页', '上一页', '加入书签', '推荐', '投票', '搜']):
                content_parts.append(text)

        if content_parts:
            return '\n\n'.join(content_parts)

        # 查找包含大量文本的div
        all_divs = soup.find_all('div')
        for div in all_divs:
            text = div.get_text().strip()
            if len(text) > 200:  # 假设章节内容至少200字符
                # 检查是否包含导航元素
                if not any(skip_word in text for skip_word in
                          ['请输入搜索关键词', '首页', '我的书架', '阅读记录', '同类最热', '底部广告']):
                    return text

        return ""

    def test_known_novel(self):
        """测试已知小说的完整功能"""
        self.log_info("=" * 60)
        self.log_info("开始测试已知小说的完整功能")
        self.log_info("=" * 60)

        # 使用已知的遮天小说URL
        novel_url = "https://m.syshangguan.com/198/"

        # 步骤1：获取小说信息
        novel_info = self.get_novel_info(novel_url)
        if not novel_info:
            self.log_error("获取小说信息失败，测试终止")
            return False

        self.log_info("小说信息：")
        self.log_info(f"  标题：{novel_info['title']}")
        self.log_info(f"  作者：{novel_info['author']}")
        self.log_info(f"  小说ID：{novel_info['novel_id']}")

        # 步骤2：获取章节列表
        chapters = self.get_novel_chapters(novel_info['url'], novel_info['novel_id'])
        if not chapters:
            self.log_error("获取章节列表失败，测试终止")
            return False

        self.log_info(f"章节列表：共 {len(chapters)} 章")
        for i, chapter in enumerate(chapters[:5], 1):
            self.log_info(f"  {i}. {chapter['title']} (ID: {chapter['chapter_id']})")

        # 步骤3：获取第一章内容
        if chapters:
            first_chapter = chapters[0]
            content = self.get_chapter_content(first_chapter['url'], first_chapter['chapter_id'])

            if content:
                self.log_info("第一章内容预览：")
                preview = content[:200] + "..." if len(content) > 200 else content
                self.log_info(f"  {preview}")
                self.log_info(f"  内容总长度：{len(content)} 字符")
            else:
                self.log_error("获取第一章内容失败")
                return False

        self.log_info("=" * 60)
        self.log_info("测试成功完成！所有功能正常")
        self.log_info("=" * 60)
        return True


def main():
    """主函数"""
    crawler = SyshangguanCrawler()

    print("Syshangguan 小说爬虫测试")
    print("测试已知小说：遮天")
    print("=" * 60)

    try:
        success = crawler.test_known_novel()
        if success:
            print("测试成功！网站爬虫功能正常")
        else:
            print("测试失败！")

    except KeyboardInterrupt:
        print("\n测试被用户中断")
    except Exception as e:
        print(f"测试过程中发生错误：{str(e)}")


if __name__ == "__main__":
    main()