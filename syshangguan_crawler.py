#!/usr/bin/env python3
"""
Syshangguan Novel Website Crawler
爬虫脚本：爱尚小说网 (https://m.syshangguan.com/)

功能：
1. 搜索小说功能
2. 查看小说目录功能
3. 查看目录中特定章节的功能

"""

import requests
import re
import json
import time
import logging
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse, quote
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
        logging.FileHandler('syshangguan_crawler.log', encoding='utf-8', errors='replace'),
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

    def search_novel(self, keyword):
        """
        搜索小说功能
        :param keyword: 搜索关键词
        :return: 搜索结果列表
        """
        self.log_info(f"开始搜索小说：{keyword}")

        # 尝试多种搜索方式
        encoded_keyword = quote(keyword)
        search_urls = [
            f"{self.base_url}/search.php?searchword={encoded_keyword}",
            f"{self.base_url}/modules/article/search.php?searchkey={encoded_keyword}",
            f"{self.base_url}/e/search/index.php?keyboard={encoded_keyword}",
        ]

        for search_url in search_urls:
            try:
                self.log_info(f"尝试搜索URL：{search_url}")
                response = self.session.get(search_url, timeout=10)
                self.log_info(f"响应状态码：{response.status_code}")

                if response.status_code == 200:
                    # 解析搜索结果页面
                    soup = BeautifulSoup(response.content, 'html.parser')

                    # 检查是否是搜索结果页面
                    if self._is_search_results_page(soup):
                        results = self._parse_search_results(soup)
                        if results:
                            self.log_info(f"找到 {len(results)} 个搜索结果")
                            return results
                        else:
                            self.log_warning("搜索结果页面为空")
                    else:
                        self.log_warning("不是搜索结果页面，可能是其他页面")

                elif response.status_code == 403:
                    self.log_warning("访问被拒绝，可能有反爬虫保护")

                time.sleep(1)  # 避免请求过快

            except Exception as e:
                self.log_error(f"搜索请求失败：{str(e)}")
                continue

        # 如果直接搜索失败，尝试通过推荐链接寻找
        self.log_info("直接搜索失败，尝试通过页面推荐寻找相关小说")
        return self._search_via_recommendation(keyword)

    def _is_search_results_page(self, soup):
        """判断是否是搜索结果页面"""
        # 检查页面标题
        title = soup.find('title')
        if title and '搜索' in title.get_text():
            return True

        # 检查是否有搜索结果相关的元素
        search_indicators = [
            soup.find('div', class_='result'),
            soup.find('div', class_='search-result'),
            soup.find('div', class_='book-list'),
            soup.find_all('a', href=re.compile(r'/\d+/$'))
        ]

        return any(search_indicators)

    def _parse_search_results(self, soup):
        """解析搜索结果"""
        results = []

        # 方法1：查找小说链接模式
        novel_links = soup.find_all('a', href=re.compile(r'/\d+/$'))

        for link in novel_links:
            href = link.get('href')
            title = link.get_text().strip()

            if title and href and len(title) > 1:
                # 获取完整的URL
                full_url = urljoin(self.base_url, href)

                # 查找作者信息
                author = "未知"
                author_element = link.find_next('a', href=re.compile(r'author'))
                if author_element:
                    author = author_element.get_text().strip()

                results.append({
                    'title': title,
                    'author': author,
                    'url': full_url,
                    'novel_id': href.strip('/').split('/')[-1]
                })

        # 方法2：查找class为result的div
        if not results:
            result_divs = soup.find_all('div', class_='result')
            for div in result_divs:
                title_link = div.find('a')
                if title_link:
                    title = title_link.get_text().strip()
                    href = title_link.get('href')
                    if href:
                        full_url = urljoin(self.base_url, href)
                        results.append({
                            'title': title,
                            'author': '未知',
                            'url': full_url,
                            'novel_id': href.strip('/').split('/')[-1] if href.endswith('/') else href.split('/')[-1]
                        })

        return results[:10]  # 限制返回前10个结果

    def _search_via_recommendation(self, keyword):
        """通过推荐页面搜索小说"""
        self.log_info(f"通过推荐页面搜索：{keyword}")

        try:
            # 访问首页
            response = self.session.get(self.base_url, timeout=10)
            if response.status_code != 200:
                return []

            soup = BeautifulSoup(response.content, 'html.parser')

            # 查找所有小说链接
            novel_links = soup.find_all('a', href=re.compile(r'/\d+/$'))
            results = []

            for link in novel_links:
                title = link.get_text().strip()
                href = link.get('href')

                # 模糊匹配标题
                if keyword.lower() in title.lower() or any(char in title for char in keyword):
                    if href and title:
                        full_url = urljoin(self.base_url, href)

                        # 查找作者信息
                        author = "未知"
                        author_element = link.find_next(string=re.compile(r'作者：'))
                        if author_element:
                            author = author_element.replace('作者：', '').strip()

                        results.append({
                            'title': title,
                            'author': author,
                            'url': full_url,
                            'novel_id': href.strip('/').split('/')[-1]
                        })

            self.log_info(f"通过推荐页面找到 {len(results)} 个相关结果")
            return results[:5]  # 限制返回前5个结果

        except Exception as e:
            self.log_error(f"推荐页面搜索失败：{str(e)}")
            return []

    def get_novel_chapters(self, novel_url, novel_id):
        """
        获取小说章节列表
        :param novel_url: 小说详情页URL
        :param novel_id: 小说ID
        :return: 章节列表
        """
        self.log_info(f"获取小说章节列表：{novel_url}")

        try:
            # 访问小说详情页
            response = self.session.get(novel_url, timeout=10)
            if response.status_code != 200:
                self.log_error(f"访问小说详情页失败，状态码：{response.status_code}")
                return []

            soup = BeautifulSoup(response.content, 'html.parser')

            # 查找目录链接
            index_links = [
                soup.find('a', href=f'/{novel_id}/index.html'),
                soup.find('a', href=re.compile(r'/index\.html$')),
                soup.find('a', text='目录'),
                soup.find('a', text='目录页')
            ]

            index_url = None
            for link in index_links:
                if link:
                    index_url = urljoin(self.base_url, link.get('href'))
                    break

            if not index_url:
                self.log_error("未找到目录页面链接")
                return []

            self.log_info(f"找到目录页面：{index_url}")

            # 访问目录页面
            time.sleep(1)
            index_response = self.session.get(index_url, timeout=10)
            if index_response.status_code != 200:
                self.log_error(f"访问目录页面失败，状态码：{index_response.status_code}")
                return []

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

        # 方法1：查找章节链接
        chapter_links = soup.find_all('a', href=re.compile(rf'/{novel_id}/\d+\.html'))

        for link in chapter_links:
            title = link.get_text().strip()
            href = link.get('href')

            if title and href:
                chapter_url = urljoin(self.base_url, href)
                chapter_id = href.split('/')[-1].replace('.html', '')

                chapters.append({
                    'title': title,
                    'url': chapter_url,
                    'chapter_id': chapter_id
                })

        # 方法2：如果方法1失败，尝试其他选择器
        if not chapters:
            # 查找所有可能包含章节的链接
            all_links = soup.find_all('a')
            for link in all_links:
                href = link.get('href', '')
                title = link.get_text().strip()

                # 匹配章节URL模式
                if re.match(rf'/{novel_id}/\d+\.html', href) and title:
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
        :param chapter_url: 章节URL
        :param chapter_id: 章节ID
        :return: 章节内容
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
        # 方法1：查找包含章节内容的div
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

        # 方法2：查找所有p标签
        all_paragraphs = soup.find_all('p')
        content_parts = []

        for p in all_paragraphs:
            text = p.get_text().strip()
            # 过滤掉太短的段落（可能是导航或其他内容）
            if len(text) > 10 and not any(skip_word in text for skip_word in
                                         ['首页', '目录', '下一页', '上一页', '加入书签', '推荐', '投票']):
                content_parts.append(text)

        if content_parts:
            return '\n\n'.join(content_parts)

        # 方法3：查找包含大量文本的div
        all_divs = soup.find_all('div')
        for div in all_divs:
            text = div.get_text().strip()
            if len(text) > 200:  # 假设章节内容至少200字符
                # 检查是否包含导航元素
                if not any(skip_word in text for skip_word in
                          ['请输入搜索关键词', '首页', '我的书架', '阅读记录', '同类最热']):
                    return text

        return ""

    def test_search(self, keyword="遮天"):
        """测试搜索功能"""
        self.log_info("=" * 50)
        self.log_info(f"测试搜索功能：{keyword}")
        self.log_info("=" * 50)

        results = self.search_novel(keyword)

        if results:
            self.log_info(f"搜索成功，找到 {len(results)} 个结果：")
            for i, result in enumerate(results, 1):
                self.log_info(f"{i}. 标题：{result['title']}")
                self.log_info(f"   作者：{result['author']}")
                self.log_info(f"   URL：{result['url']}")
                self.log_info(f"   小说ID：{result['novel_id']}")
                self.log_info("-" * 30)
        else:
            self.log_warning("搜索失败，未找到相关结果")

        return results

    def test_chapter_list(self, novel_url, novel_id):
        """测试获取章节列表"""
        self.log_info("=" * 50)
        self.log_info(f"测试获取章节列表：{novel_url}")
        self.log_info("=" * 50)

        chapters = self.get_novel_chapters(novel_url, novel_id)

        if chapters:
            self.log_info(f"成功获取章节列表，共 {len(chapters)} 章：")
            for i, chapter in enumerate(chapters[:10], 1):  # 只显示前10章
                self.log_info(f"{i}. {chapter['title']}")
                self.log_info(f"   URL：{chapter['url']}")
                self.log_info(f"   章节ID：{chapter['chapter_id']}")
                self.log_info("-" * 30)

            if len(chapters) > 10:
                self.log_info(f"... 还有 {len(chapters) - 10} 章")
        else:
            self.log_warning("获取章节列表失败")

        return chapters

    def test_chapter_content(self, chapter_url, chapter_id):
        """测试获取章节内容"""
        self.log_info("=" * 50)
        self.log_info(f"测试获取章节内容：{chapter_url}")
        self.log_info("=" * 50)

        content = self.get_chapter_content(chapter_url, chapter_id)

        if content:
            self.log_info("成功获取章节内容：")
            self.log_info("-" * 30)
            self.log_info(content[:500] + "..." if len(content) > 500 else content)
            self.log_info("-" * 30)
            self.log_info(f"内容总长度：{len(content)} 字符")
        else:
            self.log_warning("获取章节内容失败")

        return content

    def run_complete_test(self, keyword="遮天"):
        """运行完整测试"""
        self.log_info("开始完整测试流程")
        self.log_info("=" * 60)

        # 步骤1：搜索小说
        search_results = self.test_search(keyword)

        if not search_results:
            self.log_error("搜索失败，测试终止")
            return False

        # 使用第一个搜索结果进行后续测试
        novel = search_results[0]
        self.log_info(f"选择第一个结果进行测试：{novel['title']}")

        # 步骤2：获取章节列表
        chapters = self.test_chapter_list(novel['url'], novel['novel_id'])

        if not chapters:
            self.log_error("获取章节列表失败，测试终止")
            return False

        # 步骤3：获取章节内容
        # 选择第一章进行测试
        first_chapter = chapters[0]
        content = self.test_chapter_content(first_chapter['url'], first_chapter['chapter_id'])

        if not content:
            self.log_error("获取章节内容失败，测试终止")
            return False

        self.log_info("=" * 60)
        self.log_info("完整测试流程成功完成！")
        self.log_info("=" * 60)

        return True


def main():
    """主函数"""
    crawler = SyshangguanCrawler()

    if len(sys.argv) > 1:
        keyword = sys.argv[1]
    else:
        keyword = "遮天"

    print(f"Syshangguan 小说爬虫测试")
    print(f"测试关键词：{keyword}")
    print("=" * 60)

    try:
        success = crawler.run_complete_test(keyword)
        if success:
            print("测试成功完成！")
        else:
            print("测试失败！")

    except KeyboardInterrupt:
        print("\n测试被用户中断")
    except Exception as e:
        print(f"测试过程中发生错误：{str(e)}")


if __name__ == "__main__":
    main()