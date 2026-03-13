#!/usr/bin/env python3
"""测试Wfxs小说站点的爬虫功能"""

import asyncio
import sys
import os

# 添加项目路径到sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.wfxs_crawler import WfxsCrawler


async def test_search():
    """测试搜索功能"""
    print("=" * 50)
    print("测试1: 搜索小说")
    print("=" * 50)

    crawler = WfxsCrawler()

    # 测试搜索
    keyword = "斗罗"
    print(f"\n搜索关键词: {keyword}")
    print(f"搜索URL: {crawler.base_url}/s/?search={keyword}")

    results = await crawler.search_novels(keyword)

    print(f"\n搜索结果数量: {len(results)}")
    if results:
        print("\n前3个结果:")
        for i, novel in enumerate(results[:3], 1):
            print(f"\n{i}. {novel.get('title', 'N/A')}")
            print(f"   作者: {novel.get('author', 'N/A')}")
            print(f"   URL: {novel.get('url', 'N/A')}")
    else:
        print("未找到搜索结果")

    return results


async def test_novel_info(novel_url: str):
    """测试获取小说详情"""
    print("\n" + "=" * 50)
    print("测试2: 获取小说详情")
    print("=" * 50)

    crawler = WfxsCrawler()

    print(f"\n小说URL: {novel_url}")

    # 使用get_novel_info方法
    novel_info = await crawler.get_novel_info(novel_url)

    print(f"\n小说标题: {novel_info.get('title', 'N/A')}")
    print(f"作者: {novel_info.get('author', 'N/A')}")
    print(f"封面URL: {novel_info.get('cover_url', 'N/A')}")
    print(f"简介: {novel_info.get('description', 'N/A')[:100] if novel_info.get('description') else 'N/A'}...")
    print(f"章节数量: {len(novel_info.get('chapters', []))}")

    if novel_info.get('chapters'):
        print("\n前5个章节:")
        for i, chapter in enumerate(novel_info['chapters'][:5], 1):
            print(f"{i}. {chapter.get('title', 'N/A')}")
            print(f"   URL: {chapter.get('url', 'N/A')}")

    return novel_info


async def test_direct_page_access():
    """直接访问页面分析HTML结构"""
    print("\n" + "=" * 50)
    print("测试3: 直接访问页面分析HTML")
    print("=" * 50)

    crawler = WfxsCrawler()

    # 直接访问一个已知的有效URL
    test_url = "https://m.wfxs.tw/xiaoshuo/7840069/"
    print(f"\n访问URL: {test_url}")

    response = await crawler.get_page(test_url)

    if response.status_code == 200:
        print(f"状态码: {response.status_code}")
        print(f"内容长度: {len(response.content)}")

        # 保存HTML到文件供分析
        html_file = os.path.join(os.path.dirname(__file__), "wfxs_novel_page.html")
        with open(html_file, "w", encoding="utf-8") as f:
            f.write(response.content)
        print(f"\nHTML已保存到: {html_file}")

        # 使用BeautifulSoup分析
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(response.content, 'lxml')

        # 尝试提取各种元素
        print("\n分析页面结构:")

        # 1. 查找h1标题
        h1_tags = soup.find_all('h1')
        print(f"\n找到 {len(h1_tags)} 个h1标签:")
        for h1 in h1_tags[:3]:
            print(f"  - {h1.get_text(strip=True)[:100]}")

        # 2. 查找图片
        img_tags = soup.find_all('img')
        print(f"\n找到 {len(img_tags)} 个img标签:")
        for img in img_tags[:5]:
            src = img.get('src', '') or img.get('data-src', '')
            alt = img.get('alt', '')
            if src:
                print(f"  - src: {src[:80]}")
                print(f"    alt: {alt[:50]}")

        # 3. 查找所有链接
        links = soup.find_all('a', href=True)
        xiaoshuo_links = [l for l in links if '/xiaoshuo/' in l.get('href', '')]
        booklist_links = [l for l in links if '/booklist/' in l.get('href', '')]

        print(f"\n找到 {len(xiaoshuo_links)} 个/xiaoshuo/链接")
        print(f"找到 {len(booklist_links)} 个/booklist/链接")

        # 4. 查找包含"作者"的文本
        author_patterns = soup.find_all(string=lambda text: text and '作者' in str(text))
        print(f"\n找到 {len(author_patterns)} 个包含'作者'的文本:")
        for pattern in author_patterns[:5]:
            print(f"  - {pattern.strip()[:100]}")

        # 5. 查找可能的简介区域
        intro_divs = soup.find_all('div', class_=lambda x: x and 'intro' in str(x).lower())
        print(f"\n找到 {len(intro_divs)} 个包含'intro'的div:")
        for div in intro_divs[:3]:
            print(f"  - {div.get('class')}: {div.get_text(strip=True)[:100]}")

    else:
        print(f"访问失败，状态码: {response.status_code}")


async def main():
    """主函数"""
    try:
        # 先测试搜索
        search_results = await test_search()

        # 如果有搜索结果，测试获取详情
        if search_results:
            first_novel_url = search_results[0].get('url')
            if first_novel_url:
                await test_novel_info(first_novel_url)

        # 测试直接页面访问
        await test_direct_page_access()

    except Exception as e:
        print(f"\n测试出错: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
