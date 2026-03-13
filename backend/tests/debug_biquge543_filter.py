#!/usr/bin/env python3
"""测试提取逻辑"""

import asyncio
import sys
from pathlib import Path
import re

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.biquge543_crawler import Biquge543Crawler


async def test_extraction_logic():
    """测试提取逻辑"""
    url = "https://m.biquge543.com/chapter/163512/743595401.html"
    crawler = Biquge543Crawler()

    response = await crawler.get_page(url, custom_headers=crawler.custom_headers, timeout=30)

    if response.status_code == 200:
        soup = response.soup()

        # 查找id="neirong"的div
        content_div = soup.find("div", id="neirong")

        if content_div:
            # 获取文本
            text = content_div.get_text(strip=True)
            print(f"原始文本长度: {len(text)}")
            print(f"原始文本前500字符: {text[:500]}")

            # 模拟过滤逻辑
            lines = text.split("\n")
            print(f"\n原始行数: {len(lines)}")
            print("前10行:")
            for i, line in enumerate(lines[:10], 1):
                print(f"{i}. [{len(line)}] {line[:100]}")
            print()

            cleaned_lines = []
            for line in lines:
                line = line.strip()
                # 跳过广告和无关文本
                if line and not any(
                    ad_word in line
                    for ad_word in [
                        "一秒记住",
                        "biquge",
                        "笔趣阁",
                        "更新快",
                        "无弹窗",
                        "本章完",
                        "下载APP",
                        "免登陆",
                        "章节报错",
                        "本站所有小说",
                        "转载而来",
                        "宣传本书",
                        "请选择错误类型",
                        "更新太慢",
                        "缺少章节",
                        "章节内容错误",
                        "验证码",
                        "提交关闭",
                        "关灯",
                        "护眼",
                        "字号",
                    ]
                ):
                    cleaned_lines.append(line)

            content = "\n".join(cleaned_lines)
            print(f"\n过滤后行数: {len(cleaned_lines)}")
            print(f"过滤后内容长度: {len(content)}")
            if content:
                print(f"过滤后内容前500字符: {content[:500]}")


if __name__ == "__main__":
    asyncio.run(test_extraction_logic())
