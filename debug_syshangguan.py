#!/usr/bin/env python3
"""
调试版本：查看实际获取到的网页内容
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

def debug_page_content(url, description):
    """调试页面内容"""
    print(f"\n{'='*60}")
    print(f"调试：{description}")
    print(f"URL: {url}")
    print('='*60)

    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
    })

    try:
        response = session.get(url, timeout=10)
        print(f"状态码: {response.status_code}")
        print(f"响应头: {dict(response.headers)}")
        print(f"编码: {response.encoding}")

        # 设置正确编码
        response.encoding = 'utf-8'

        # 保存原始内容到文件
        with open('debug_page.html', 'w', encoding='utf-8', errors='replace') as f:
            f.write(response.text)
        print("原始内容已保存到 debug_page.html")

        # 解析内容
        soup = BeautifulSoup(response.content, 'html.parser')

        # 查找标题
        title = soup.find('title')
        if title:
            print(f"页面标题: {title.get_text()}")

        # 查找所有链接
        all_links = soup.find_all('a')
        print(f"\n找到 {len(all_links)} 个链接:")

        for i, link in enumerate(all_links[:20]):  # 只显示前20个
            href = link.get('href', '')
            text = link.get_text().strip()
            if text and len(text) > 1:
                print(f"  {i+1}. {text[:50]} -> {href}")

        # 查找可能的小说信息
        print(f"\n查找小说信息:")

        # 查找作者
        author_patterns = [
            soup.find_all(string=re.compile(r'作者：')),
            soup.find_all('a', href=re.compile(r'author')),
        ]

        for pattern in author_patterns:
            if isinstance(pattern, list):
                for p in pattern:
                    print(f"  作者信息: {p}")
            else:
                print(f"  作者信息: {pattern}")

        # 查找描述
        desc_patterns = [
            soup.find_all(string=re.compile(r'简介|介绍|描述')),
        ]

        for pattern in desc_patterns:
            if isinstance(pattern, list):
                for p in pattern[:5]:  # 只显示前5个
                    print(f"  简介信息: {p}")
            else:
                print(f"  简介信息: {pattern}")

        return response.text

    except Exception as e:
        print(f"获取页面失败: {str(e)}")
        return None

def main():
    """主函数"""
    print("Syshangguan 网站调试工具")

    # 测试小说详情页
    novel_url = "https://m.syshangguan.com/198/"
    debug_page_content(novel_url, "小说详情页")

    # 测试目录页
    index_url = "https://m.syshangguan.com/198/index.html"
    debug_page_content(index_url, "小说目录页")

    # 测试章节页
    chapter_url = "https://m.syshangguan.com/198/49.html"
    debug_page_content(chapter_url, "章节内容页")

if __name__ == "__main__":
    main()