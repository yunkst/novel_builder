#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
小说爬虫脚本
支持按名字搜索小说，展示小说列表，查看章节列表，阅读小说内容
"""

import requests
from bs4 import BeautifulSoup
import re
import time
import urllib.parse
import sys


class NovelCrawler:
    def __init__(self):
        # 从页面快照中可以看出，网站URL为365小说网，但实际域名可能变化
        self.base_url = "http://www.shukuge.com"
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })
        
    def search_novels(self, keyword):
        """
        搜索小说
        :param keyword: 搜索关键词
        :return: 小说列表 [{'title': str, 'author': str, 'url': str}, ...]
        """
        # 尝试不同的搜索URL格式
        search_urls = [
            f"{self.base_url}/modules/article/search.php",
            f"{self.base_url}/search.php",
            f"{self.base_url}/Search?wd={keyword}"
        ]
        
        # 首先尝试URL编码的参数搜索
        search_url = f"{self.base_url}/Search"
        params = {
            'wd': keyword
        }
        
        try:
            response = self.session.get(search_url, params=params)
            response.encoding = 'utf-8'
            
            if response.status_code == 200:
                soup = BeautifulSoup(response.text, 'html.parser')
                novels = []
                
                # 根据网站实际结构查找小说
                # 小说通常在包含标题和作者信息的div或list元素中
                all_links = soup.find_all('a', href=True, string=True)
                
                for link in all_links:
                    title = link.get_text().strip()
                    href = link.get('href', '')
                    
                    # 检查是否是小说相关链接
                    if keyword.lower() in title.lower() and any(indicator in href for indicator in ['/book/', '/read/', 'txt全集下载', '/modules/article']):
                        # 获取作者信息 - 通常在附近元素中
                        author = "未知"
                        parent = link.parent
                        if parent:
                            text = parent.get_text()
                            author_match = re.search(r'作者[：:]\s*([^\s\n\r<>/]+)', text)
                            if author_match:
                                author = author_match.group(1).strip()
                        
                        novels.append({
                            'title': title,
                            'author': author,
                            'url': urllib.parse.urljoin(self.base_url, href)
                        })
                
                # 去重并限制数量
                seen_titles = set()
                unique_novels = []
                for novel in novels:
                    if novel['title'] not in seen_titles and len(novel['title']) > 1:
                        seen_titles.add(novel['title'])
                        unique_novels.append(novel)
                
                if unique_novels:
                    return unique_novels[:20]  # 限制返回前20个结果

            # 如果第一个URL失败，尝试其他URL
            for search_url in search_urls:
                if search_url.endswith('.php'):
                    # 对于PHP搜索页面，尝试POST请求
                    data = {
                        'searchkey': keyword,
                        'searchtype': 'all'
                    }
                    
                    response = self.session.post(search_url, data=data)
                else:
                    # 对于其他搜索页面，尝试GET请求
                    params = {
                        'searchkey': keyword,
                        'searchtype': 'all'
                    }
                    response = self.session.get(search_url, params=params)
                
                response.encoding = 'utf-8'
                
                if response.status_code == 200:
                    soup = BeautifulSoup(response.text, 'html.parser')
                    novels = []
                    
                    # 根据网站实际结构查找小说
                    all_links = soup.find_all('a', href=True, string=True)
                    
                    for link in all_links:
                        title = link.get_text().strip()
                        href = link.get('href', '')
                        
                        # 检查是否是小说相关链接
                        if keyword.lower() in title.lower() and any(indicator in href for indicator in ['/book/', '/read/', 'txt全集下载', '/modules/article']):
                            # 获取作者信息
                            author = "未知"
                            parent = link.parent
                            if parent:
                                text = parent.get_text()
                                author_match = re.search(r'作者[：:]\s*([^\s\n\r<>/]+)', text)
                                if author_match:
                                    author = author_match.group(1).strip()
                            
                            novels.append({
                                'title': title,
                                'author': author,
                                'url': urllib.parse.urljoin(self.base_url, href)
                            })
                    
                    # 去重并限制数量
                    seen_titles = set()
                    unique_novels = []
                    for novel in novels:
                        if novel['title'] not in seen_titles and len(novel['title']) > 1:
                            seen_titles.add(novel['title'])
                            unique_novels.append(novel)
                    
                    if unique_novels:
                        return unique_novels[:20]  # 限制返回前20个结果
                else:
                    print(f"搜索URL {search_url} 返回状态码: {response.status_code}")
            
            return []  # 如果所有URL都失败，返回空列表
                
        except Exception as e:
            print(f"搜索过程中出现错误: {e}")
            return []

    def get_chapter_list(self, novel_url):
        """
        获取小说章节列表
        :param novel_url: 小说页面URL
        :return: 章节列表 [{'title': str, 'url': str}, ...]
        """
        try:
            response = self.session.get(novel_url)
            response.encoding = 'utf-8'
            
            if response.status_code == 200:
                soup = BeautifulSoup(response.text, 'html.parser')
                chapters = []
                
                # 首先尝试查找"在线阅读"链接，这通常会跳转到章节列表页
                online_read_link = soup.find('a', string=re.compile(r'在线阅读|立即阅读|章节列表'))
                
                if online_read_link:
                    chapter_list_url = urllib.parse.urljoin(novel_url, online_read_link.get('href', ''))
                    # 请求章节列表页
                    response = self.session.get(chapter_list_url)
                    response.encoding = 'utf-8'
                    
                    if response.status_code == 200:
                        soup = BeautifulSoup(response.text, 'html.parser')
                
                # 根据网站实际结构查找章节列表
                # 章节列表通常在特定的div或ul中
                chapter_list = (soup.find('div', id='list') or 
                               soup.find('div', class_='listmain') or 
                               soup.find('dl') or
                               soup.find('div', class_='book_list') or
                               soup.find('ul', class_='chapterlist') or
                               soup.find('div', id='readerlist') or
                               soup.find('div', class_=re.compile(r'list|chapter|content', re.I)))
                
                # 如果没有找到标准容器，尝试其他方法
                if not chapter_list:
                    # 查找包含章节链接的区域
                    # 从页面快照看，章节列表页面包含很多章节链接
                    for div in soup.find_all(['div', 'ul', 'ol'], recursive=True):
                        links = div.find_all('a', href=True)
                        # 如果一个容器包含多个章节链接，可能是章节列表
                        chapter_links = []
                        for link in links:
                            title = link.get_text().strip()
                            href = link.get('href', '')
                            # 章节标题通常包含"第"字或数字，或者与小说相关
                            if (re.search(r'第\d+|第[一二三四五六七八九十]+|引子|序章|终章|大结局|章节|章|节', title) or 
                                '第' in title or 
                                any(num in title for num in ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'])) and len(title) > 1:
                                chapter_links.append({
                                    'title': title,
                                    'url': urllib.parse.urljoin(novel_url, href)  # 使用原始novel_url来构建完整URL
                                })
                        
                        if len(chapter_links) > 5:  # 如果找到超过5个章节链接，认为是正确的章节列表
                            chapters = chapter_links
                            break
                
                # 如果找到了标准章节列表容器
                if chapter_list and not chapters:
                    links = chapter_list.find_all('a', href=True)
                    for link in links:
                        title = link.get_text().strip()
                        href = link.get('href', '')
                        
                        # 确保是章节链接
                        if title and href and ('.html' in href or '/book/' in href or '/read/' in href):
                            url = urllib.parse.urljoin(novel_url, href)  # 使用novel_url来构建完整URL
                            # 过滤掉可能不是章节的链接
                            if len(title) > 1 and not any(skip in title.lower() for skip in ['封面', '图片', '插图']):
                                chapters.append({
                                    'title': title,
                                    'url': url
                                })
                
                # 如果还是没有找到，尝试全局搜索所有可能是章节的链接
                if not chapters:
                    all_links = soup.find_all('a', href=True)
                    for link in all_links:
                        href = link.get('href', '')
                        title = link.get_text().strip()
                        
                        # 基于URL模式和标题内容判断是否为章节链接
                        if (re.search(r'/\d+\.html$|/book/\d+_|/chapters?/\d+|/read/\d+|/modules/article', href) and 
                            len(title) > 1 and 
                            (re.search(r'第\d+|第[一二三四五六七八九十]+|引子|序章|终章|大结局|章节|章|节', title) or '第' in title) and
                            not any(skip in title.lower() for skip in ['返回首页', '加入书架', '发表评论', 'txt下载', '在线阅读', '立即下载'])):
                            url = urllib.parse.urljoin(novel_url, href)
                            chapters.append({
                                'title': title,
                                'url': url
                            })
                
                # 如果还是没找到，尝试在小说详情页查找直接章节链接
                if not chapters and '/book/' in novel_url:  # 如果这已经是书籍详情页
                    # 在小说详情页中查找"在线阅读"或其他章节链接
                    read_links = soup.find_all('a', href=True, string=re.compile(r'在线阅读|开始阅读|立即阅读'))
                    if read_links:
                        read_link = read_links[0]
                        chapter_list_page_url = urllib.parse.urljoin(novel_url, read_link.get('href', ''))
                        # 访问章节列表页
                        response = self.session.get(chapter_list_page_url)
                        response.encoding = 'utf-8'
                        
                        if response.status_code == 200:
                            soup = BeautifulSoup(response.text, 'html.parser')
                            
                            # 在章节列表页面查找章节链接
                            for div in soup.find_all(['div', 'ul', 'ol'], recursive=True):
                                links = div.find_all('a', href=True)
                                chapter_links = []
                                for link in links:
                                    title = link.get_text().strip()
                                    href = link.get('href', '')
                                    # 章节标题通常包含"第"字或数字
                                    if (re.search(r'第\d+|第[一二三四五六七八九十]+|引子|序章|终章|大结局|章节|章|节', title) or 
                                        '第' in title) and len(title) > 1:
                                        chapter_links.append({
                                            'title': title,
                                            'url': urllib.parse.urljoin(chapter_list_page_url, href)
                                        })
                                
                                if len(chapter_links) > 5:
                                    chapters = chapter_links
                                    break
                
                return chapters
            else:
                print(f"获取章节列表失败，状态码: {response.status_code}")
                return []
                
        except Exception as e:
            print(f"获取章节列表时出现错误: {e}")
            return []

    def get_chapter_content(self, chapter_url):
        """
        获取章节内容
        :param chapter_url: 章节URL
        :return: 章节内容(str)
        """
        try:
            # 添加延迟避免请求过于频繁
            time.sleep(1)
            
            response = self.session.get(chapter_url, timeout=10)
            response.encoding = 'utf-8'
            
            if response.status_code == 200:
                soup = BeautifulSoup(response.text, 'html.parser')
                
                # 简化的内容提取逻辑
                # 首先尝试查找最常见的内容容器
                content_div = None
                
                # 按优先级尝试不同的选择器
                selectors = [
                    'div#content',
                    'div.content',
                    'div.readcontent',
                    'div#chaptercontent',
                    'div.chapter-content',
                    'div.book_con',
                    'div.showtxt'
                ]
                
                for selector in selectors:
                    content_div = soup.select_one(selector)
                    if content_div:
                        break
                
                # 如果没找到标准容器，查找文本最长的div
                if not content_div:
                    divs = soup.find_all('div')
                    longest_div = None
                    max_text_length = 0
                    
                    for div in divs:
                        text_length = len(div.get_text())
                        if text_length > max_text_length:
                            max_text_length = text_length
                            longest_div = div
                    
                    # 只有当文本足够长时才认为是内容区域
                    if max_text_length > 500:
                        content_div = longest_div
                
                if content_div:
                    # 提取标题
                    title_elem = soup.find('h1') or soup.find('title')
                    title = title_elem.get_text().strip() if title_elem else "章节内容"
                    
                    # 清理内容区域
                    # 移除脚本和样式标签
                    for script in content_div(["script", "style"]):
                        script.decompose()
                    
                    # 获取文本内容
                    content = content_div.get_text().strip()
                    
                    # 清理多余空白
                    content = re.sub(r'\n\s*\n', '\n', content)
                    content = re.sub(r' +', ' ', content)
                    
                    # 过滤掉明显不是正文的内容（仅排除特定关键词）
                    lines = content.split('\n')
                    filtered_lines = []
                    
                    for line in lines:
                        line = line.strip()
                        if not any(keyword in line.lower() for keyword in ['copyright', '站点地图', '热搜小说', '广告', '推荐', '返回', '目录', '加入书签']):
                            filtered_lines.append(line)
                    
                    content = '\n'.join(filtered_lines)
                    
                    # 如果内容仍然很短，可能是没找到正确的内容
                    if len(content) < 100:
                        # 尝试查找所有段落标签
                        paragraphs = soup.find_all('p')
                        if len(paragraphs) > 5:
                            para_texts = [p.get_text().strip() for p in paragraphs]
                            if para_texts:
                                content = '\n'.join(para_texts[:50])  # 取前50段
                
                else:
                    # 如果没找到明确的内容区域，尝试在整个页面中查找
                    title_elem = soup.find('h1') or soup.find('title')
                    title = title_elem.get_text().strip() if title_elem else "章节内容"
                    
                    # 查找所有段落
                    paragraphs = soup.find_all('p')
                    if len(paragraphs) > 5:
                        para_texts = []
                        for p in paragraphs:
                            text = p.get_text().strip()
                            # 过滤掉太短的段落和明显不是正文的内容
                            if (not any(keyword in text.lower() for keyword in ['copyright', '站点地图', '热搜小说', '广告', '推荐', '返回', '目录', '加入书签']) and
                                not p.find('a')):  # 通常链接不是正文
                                para_texts.append(text)
                        
                        if para_texts:
                            content = '\n'.join(para_texts[:50])  # 取前50段
                        else:
                            content = "未能提取到章节内容"
                    else:
                        content = "未能提取到章节内容"
                
                # 如果仍然没有内容，返回页面主体文本
                if not content or len(content) < 50:
                    body_text = soup.get_text()
                    # 移除多余空白
                    body_text = re.sub(r'\n\s*\n', '\n', body_text)
                    body_text = re.sub(r' +', ' ', body_text)
                    
                    # 查找正文开始位置
                    lines = body_text.split('\n')
                    content_lines = []
                    content_started = False
                    
                    for line in lines:
                        line = line.strip()
                        # 判断是否为正文（包含标点符号）
                        if not content_started and any(punct in line for punct in ['。', '！', '？', '，', '；', '：']):
                            content_started = True
                        
                        # 过滤掉明显不是正文的内容
                        if not any(exclude in line.lower() for exclude in ['copyright', '站点地图', '热搜小说', '广告', '推荐']):
                            if content_started:
                                content_lines.append(line)
                                if len(content_lines) >= 50:  # 取前50行
                                    break
                    
                    content = '\n'.join(content_lines) if content_lines else "未能提取到章节内容"
                
                return f"标题: {title}\n\n{content[:2000]}{'...' if len(content) > 2000 else ''}"
            
            else:
                return f"获取章节内容失败，状态码: {response.status_code}"
                
        except requests.exceptions.Timeout:
            return "获取章节内容超时"
        except requests.exceptions.RequestException as e:
            return f"获取章节内容时网络错误: {e}"
        except Exception as e:
            return f"获取章节内容时出现错误: {e}"


def main():
    crawler = NovelCrawler()
    
    print("欢迎使用小说爬虫工具！")
    print("=" * 50)
    
    while True:
        print("\n请选择功能:")
        print("1. 搜索小说")
        print("2. 退出程序")
        
        choice = input("\n请输入选项 (1-2): ").strip()
        
        if choice == '1':
            keyword = input("请输入小说名称或作者: ").strip()
            
            if keyword:
                print(f"\n正在搜索 '{keyword}'...")
                novels = crawler.search_novels(keyword)
                
                if novels:
                    print(f"\n找到 {len(novels)} 本相关小说:")
                    for i, novel in enumerate(novels, 1):
                        print(f"{i}. 《{novel['title']}》 - {novel['author']}")
                    
                    # 选择小说
                    while True:
                        try:
                            novel_choice = input(f"\n请选择小说 (1-{len(novels)}) 或输入 'b' 返回主菜单: ").strip()
                            
                            if novel_choice.lower() == 'b':
                                break
                                
                            novel_idx = int(novel_choice) - 1
                            if 0 <= novel_idx < len(novels):
                                selected_novel = novels[novel_idx]
                                print(f"\n您选择了: 《{selected_novel['title']}》")
                                
                                # 获取章节列表
                                print("\n正在获取章节列表...")
                                chapters = crawler.get_chapter_list(selected_novel['url'])
                                
                                if chapters:
                                    print(f"共找到 {len(chapters)} 个章节:")
                                    for i, chapter in enumerate(chapters[:20], 1):  # 只显示前20章
                                        print(f"{i}. {chapter['title']}")
                                    
                                    if len(chapters) > 20:
                                        print("...")
                                        print(f"还有 {len(chapters) - 20} 章未显示")
                                    
                                    # 选择章节
                                    while True:
                                        try:
                                            chapter_choice = input(f"\n请选择章节 (1-{len(chapters)}) 或输入 'b' 返回小说列表: ").strip()
                                            
                                            if chapter_choice.lower() == 'b':
                                                break
                                                
                                            chapter_idx = int(chapter_choice) - 1
                                            if 0 <= chapter_idx < len(chapters):
                                                selected_chapter = chapters[chapter_idx]
                                                print(f"\n您选择了: {selected_chapter['title']}")
                                                
                                                # 获取章节内容
                                                print("\n正在获取章节内容...")
                                                content = crawler.get_chapter_content(selected_chapter['url'])
                                                print("\n" + "="*50)
                                                print(content)
                                                print("="*50)
                                                
                                                # 询问是否继续阅读其他章节
                                                cont = input("\n是否继续阅读其他章节? (y/n): ").strip().lower()
                                                if cont != 'y':
                                                    break
                                            else:
                                                print("无效的章节选择，请重新输入。")
                                            
                                        except ValueError:
                                            print("请输入有效的数字或 'b'。")
                                        except KeyboardInterrupt:
                                            print("\n程序被用户中断。")
                                            sys.exit(0)
                                else:
                                    print("未能获取到章节列表。")
                                break
                            else:
                                print("无效的小说选择，请重新输入。")
                                
                        except ValueError:
                            print("请输入有效的数字或 'b'。")
                        except KeyboardInterrupt:
                            print("\n程序被用户中断。")
                            sys.exit(0)
                else:
                    print("未找到相关小说，请尝试其他关键词。")
            else:
                print("关键词不能为空。")
                
        elif choice == '2':
            print("感谢使用，再见！")
            break
        else:
            print("无效的选项，请重新输入。")
        
        time.sleep(1)  # 避免请求过于频繁


def test_mode():
    """测试模式，自动执行功能无需交互"""
    crawler = NovelCrawler()
    
    print("开始测试小说爬虫功能...")
    print("=" * 50)
    
    # 自动搜索一个热门小说
    keyword = "斗罗大陆"
    print(f"正在测试搜索: {keyword}")
    
    novels = crawler.search_novels(keyword)
    
    if novels:
        print(f"找到 {len(novels)} 本相关小说:")
        for i, novel in enumerate(novels[:3], 1):  # 只显示前3本
            print(f"{i}. 《{novel['title']}》 - {novel['author']}")
        
        # 自动选择第一本小说
        if novels:
            selected_novel = novels[0]
            print(f"\n自动选择: 《{selected_novel['title']}》")
            
            # 获取章节列表
            print("正在获取章节列表...")
            chapters = crawler.get_chapter_list(selected_novel['url'])
            
            if chapters:
                print(f"找到 {len(chapters)} 个章节:")
                # 显示前5个章节
                for i, chapter in enumerate(chapters[:5], 1):
                    print(f"{i}. {chapter['title']}")
                
                # 自动选择第一章
                if chapters:
                    first_chapter = chapters[0]
                    print(f"\n自动选择章节: {first_chapter['title']}")
                    
                    # 获取章节内容
                    print("正在获取章节内容...")
                    content = crawler.get_chapter_content(first_chapter['url'])
                    print("\n" + "="*50)
                    print(content[:1000])  # 只显示前1000个字符
                    if len(content) > 1000:
                        print("...\n[内容过长，已截断]")
                    print("="*50)
                    print("测试完成！")
            else:
                print("未能获取到章节列表。")
    else:
        print("未找到相关小说。")


if __name__ == "__main__":
    # 根据是否有命令行参数决定是否使用测试模式
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        test_mode()
    else:
        main()