#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
爱丽丝书屋小说爬虫脚本
支持按名字搜索小说，展示小说列表，查看章节列表，阅读小说内容
"""

import requests
from bs4 import BeautifulSoup
import re
import time
import urllib.parse
import sys


class AliceSWCrawler:
    def __init__(self):
        self.base_url = "https://www.alicesw.com"
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
        # 爱丽丝书屋的搜索URL格式
        search_url = f"{self.base_url}/search.html"
        
        try:
            # 使用正确的参数格式进行搜索
            params = {
                'q': keyword,  # 关键词
                'f': '_all',  # 搜索字段（全部）
                'sort': 'relevance'  # 排序方式
            }
            response = self.session.get(search_url, params=params)
            response.encoding = 'utf-8'
            
            if response.status_code == 200:
                soup = BeautifulSoup(response.text, 'html.parser')
                novels = []
                
                # 查找搜索结果容器
                result_items = soup.find_all(['div', 'li'], recursive=True)
                
                for item in result_items:
                    # 查找标题链接（通常是小说链接）
                    title_link = item.find('a', href=re.compile(r'/novel/\d+\.html'))
                    
                    if title_link:
                        title = title_link.get_text().strip()
                        href = title_link.get('href', '')
                        
                        # 获取作者信息
                        author = "未知"
                        # 在当前项目中查找作者信息
                        text = item.get_text()
                        author_match = re.search(r'作者[：:]\s*([^\n\r<>/,，、\[\]]+)', text)
                        if author_match:
                            author = author_match.group(1).strip()
                        
                        # 有些作者信息可能在链接中
                        if author == "未知":
                            # 查找作者链接
                            author_link = item.find('a', href=re.compile(r'search\?.*f=author'))
                            if author_link:
                                author = author_link.get_text().strip()
                        
                        novel_url = urllib.parse.urljoin(self.base_url, href)
                        novels.append({
                            'title': title,
                            'author': author,
                            'url': novel_url
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

            return novels  # 返回找到的结果，即使是空列表
                
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

                def extract_chapters_from_soup(any_soup, base):
                    results = []
                    for a in any_soup.find_all('a', href=True):
                        title = a.get_text().strip()
                        href = a.get('href', '')
                        # 仅抓取 /book/<id>/<slug>.html 形式的真实章节链接
                        if re.search(r'^/book/\d+/[^/]+\.html$', href):
                            # 过滤常见非章节导航标题
                            if (len(title) > 1 and
                                not any(x in title for x in ['爱丽丝书屋', '首页', '分类', '排行', '小说', '文章', '科幻', '武侠', '网游', '同人'])):
                                # 章节标题常见模式（含“第…章/节/卷”等或明显章节名）
                                if re.search(r'第\s*\d+|第[一二三四五六七八九十百千万]+|章|节|卷|楔子|序章|终章|大结局', title):
                                    results.append({
                                        'title': title,
                                        'url': urllib.parse.urljoin(base, href)
                                    })
                    return results

                # 1) 优先尝试专用章节列表页 /other/chapters/id/<novelId>.html
                novel_id_match = re.search(r'/novel/(\d+)\.html', novel_url)
                if novel_id_match:
                    novel_id = novel_id_match.group(1)
                    chapter_list_url = f"{self.base_url}/other/chapters/id/{novel_id}.html"
                    r2 = self.session.get(chapter_list_url)
                    r2.encoding = 'utf-8'
                    if r2.status_code == 200:
                        soup2 = BeautifulSoup(r2.text, 'html.parser')
                        chapters.extend(extract_chapters_from_soup(soup2, self.base_url))

                # 2) 若未找到，从详情页中寻找“在线阅读/章节列表”等入口页再抓取
                if not chapters:
                    read_links = soup.find_all('a', string=re.compile(r'在线阅读|立即阅读|开始阅读|章节列表|全文阅读'))
                    if read_links:
                        read_url = urllib.parse.urljoin(novel_url, read_links[0].get('href', ''))
                        r3 = self.session.get(read_url)
                        r3.encoding = 'utf-8'
                        if r3.status_code == 200:
                            soup3 = BeautifulSoup(r3.text, 'html.parser')
                            chapters.extend(extract_chapters_from_soup(soup3, read_url))

                # 3) 兜底：直接在详情页抓取 /book/<id>/... 链接
                if not chapters:
                    chapters.extend(extract_chapters_from_soup(soup, novel_url))

                # 去重保持顺序
                seen = set()
                unique = []
                for ch in chapters:
                    if ch['url'] not in seen:
                        unique.append(ch)
                        seen.add(ch['url'])

                return unique
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
                
                # 提取标题
                title_elem = soup.find('h1') or soup.find('title')
                title = title_elem.get_text().strip() if title_elem else "章节内容"
                
                # 使用段落提取逻辑获取正文内容
                paragraphs = soup.find_all('p')
                if len(paragraphs) > 5:
                    para_texts = [p.get_text().strip() for p in paragraphs]
                    if para_texts:
                        content = '\n'.join(para_texts)
                else:
                    content = "未能提取到章节内容"
                
                # 跟随“下一页/继续阅读/下页”分页，最多跟随5页，避免仅取到首段
                accum_content = content
                visited_urls = {chapter_url}
                max_pages = 5
                page_count = 0

                while page_count < max_pages:
                    # 1) 通过文字匹配寻找下一页
                    next_link = soup.find('a', string=re.compile(r'下一页|继续阅读|下页'))
                    if not next_link:
                        # 2) 备用：通过同章节的分页后缀 _2.html/_3.html 等识别下一页
                        base_prefix = re.sub(r'(?:_\d+)?\.html$', '', chapter_url)
                        candidates = []
                        for a in soup.find_all('a', href=True):
                            href = a.get('href') or ''
                            full = urllib.parse.urljoin(chapter_url, href)
                            m = re.search(r'_(\d+)\.html$', full)
                            if m and full.startswith(base_prefix):
                                try:
                                    candidates.append((int(m.group(1)), full))
                                except Exception:
                                    pass
                        if candidates:
                            candidates.sort(key=lambda x: x[0])
                            # 选择最小页码（通常是 2）
                            next_url = candidates[0][1]
                        else:
                            break
                    else:
                        next_href = next_link.get('href', '')
                        next_url = urllib.parse.urljoin(chapter_url, next_href)
                    if not next_url or next_url in visited_urls:
                        break
                    # 仅在同一章节的分页情况下继续（如 67559a60629b6.html -> 67559a60629b6_2.html）
                    base_curr = re.sub(r'(_\d+)?\.html$', '', chapter_url)
                    base_next = re.sub(r'(_\d+)?\.html$', '', next_url)
                    if base_curr != base_next:
                        break

                    try:
                        time.sleep(0.8)
                        r_next = self.session.get(next_url, timeout=10)
                        r_next.encoding = 'utf-8'
                        if r_next.status_code != 200:
                            break
                        soup_next = BeautifulSoup(r_next.text, 'html.parser')

                        # 使用段落提取下一页内容
                        paragraphs = soup_next.find_all('p')
                        if len(paragraphs) > 3:
                            content_next = '\n'.join([p.get_text().strip() for p in paragraphs])
                        else:
                            content_next = "未能提取到下一页内容"

                        # 清理多余空白
                        content_next = re.sub(r'\n\s*\n', '\n', content_next)
                        content_next = re.sub(r' +', ' ', content_next)

                        # 过滤噪点与导航
                        lines_next = []
                        for line in content_next.split('\n'):
                            line = line.strip()
                            if not any(keyword in line.lower() for keyword in [
                                'copyright', '站点地图', '热搜小说', '广告', '推荐', '返回', '目录', '加入书签',
                                '翻页', '上一章', '下一章', '返回书架', '继续阅读', '最新章节', '分类:', '爱丽丝书屋'
                            ]):
                                lines_next.append(line)

                        if lines_next:
                            accum_content += '\n' + '\n'.join(lines_next)

                        visited_urls.add(next_url)
                        page_count += 1
                        # 准备下一轮检测
                        soup = soup_next
                    except Exception:
                        break

                # 返回完整内容（不再进行2000字截断）
                return f"标题: {title}\n\n{accum_content}"
            
            else:
                return f"获取章节内容失败，状态码: {response.status_code}"
                
        except requests.exceptions.Timeout:
            return "获取章节内容超时"
        except requests.exceptions.RequestException as e:
            return f"获取章节内容时网络错误: {e}"
        except Exception as e:
            return f"获取章节内容时出现错误: {e}"


def main():
    crawler = AliceSWCrawler()
    
    print("欢迎使用爱丽丝书屋小说爬虫工具！")
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
                                print(f"\n您选择了: 《{selected_novel['title']}》 - {selected_novel['author']}")
                                
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
    crawler = AliceSWCrawler()
    
    print("开始测试爱丽丝书屋爬虫功能...")
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
            print(f"\n自动选择: 《{selected_novel['title']}》 - {selected_novel['author']}")
            
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
                    # 处理编码问题，只打印安全的字符
                    safe_content = content[:1000]
                    safe_content = safe_content.encode('utf-8', errors='ignore').decode('utf-8', errors='ignore')
                    print(safe_content)
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