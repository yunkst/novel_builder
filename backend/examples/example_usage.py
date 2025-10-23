#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Novel Builder Backend - 使用示例

这个脚本演示了如何使用Novel Builder API进行小说搜索和内容获取。
"""

import asyncio
import httpx
import json
from typing import List, Dict, Any


class NovelClient:
    """小说API客户端示例"""

    def __init__(self, base_url: str = "http://localhost:8000", api_token: str = ""):
        self.base_url = base_url.rstrip("/")
        self.api_token = api_token
        self.headers = {
            "X-API-TOKEN": api_token,
            "Content-Type": "application/json"
        }

    async def health_check(self) -> bool:
        """检查API健康状态"""
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{self.base_url}/health")
                return response.status_code == 200
        except Exception as e:
            print(f"健康检查失败: {e}")
            return False

    async def search_novels(self, keyword: str) -> List[Dict[str, Any]]:
        """搜索小说"""
        try:
            async with httpx.AsyncClient(headers=self.headers) as client:
                response = await client.get(
                    f"{self.base_url}/search",
                    params={"keyword": keyword}
                )
                response.raise_for_status()
                return response.json()
        except httpx.HTTPStatusError as e:
            print(f"搜索失败 (HTTP {e.response.status_code}): {e.response.text}")
            return []
        except Exception as e:
            print(f"搜索失败: {e}")
            return []

    async def get_chapters(self, novel_url: str) -> List[Dict[str, Any]]:
        """获取章节列表"""
        try:
            async with httpx.AsyncClient(headers=self.headers) as client:
                response = await client.get(
                    f"{self.base_url}/chapters",
                    params={"novel_url": novel_url}
                )
                response.raise_for_status()
                return response.json()
        except httpx.HTTPStatusError as e:
            print(f"获取章节列表失败 (HTTP {e.response.status_code}): {e.response.text}")
            return []
        except Exception as e:
            print(f"获取章节列表失败: {e}")
            return []

    async def get_chapter_content(self, chapter_url: str) -> Dict[str, Any]:
        """获取章节内容"""
        try:
            async with httpx.AsyncClient(headers=self.headers) as client:
                response = await client.get(
                    f"{self.base_url}/chapter-content",
                    params={"chapter_url": chapter_url}
                )
                response.raise_for_status()
                return response.json()
        except httpx.HTTPStatusError as e:
            print(f"获取章节内容失败 (HTTP {e.response.status_code}): {e.response.text}")
            return {}
        except Exception as e:
            print(f"获取章节内容失败: {e}")
            return {}

    def print_novel(self, novel: Dict[str, Any]) -> None:
        """打印小说信息"""
        print(f"📚 {novel.get('title', '未知标题')}")
        print(f"✍️  作者: {novel.get('author', '未知')}")
        print(f"🔗 链接: {novel.get('url', '未知')}")
        if novel.get('description'):
            print(f"📖 简介: {novel['description']}")
        if novel.get('cover_url'):
            print(f"🖼️  封面: {novel['cover_url']}")
        print("-" * 50)

    def print_chapter(self, chapter: Dict[str, Any]) -> None:
        """打印章节信息"""
        print(f"📄 {chapter.get('title', '未知标题')}")
        print(f"🔗 链接: {chapter.get('url', '未知')}")
        if chapter.get('index'):
            print(f"📍 索引: {chapter['index']}")
        print("-" * 30)


async def demo_basic_usage():
    """基础使用演示"""
    print("🚀 Novel Builder Backend 使用演示")
    print("=" * 50)

    # 从环境变量获取配置
    import os
    api_token = os.getenv("NOVEL_API_TOKEN", "your-api-token-here")
    base_url = os.getenv("API_BASE_URL", "http://localhost:8000")

    client = NovelClient(base_url=base_url, api_token=api_token)

    # 1. 健康检查
    print("1️⃣ 检查API状态...")
    if not await client.health_check():
        print("❌ API服务不可用，请确保服务正在运行")
        return
    print("✅ API服务正常")
    print()

    # 2. 搜索小说
    print("2️⃣ 搜索小说...")
    keyword = "斗罗"  # 可以修改这个关键词
    print(f"🔍 搜索关键词: {keyword}")

    novels = await client.search_novels(keyword)

    if not novels:
        print("❌ 没有找到相关小说")
        return

    print(f"✅ 找到 {len(novels)} 本小说:")
    for i, novel in enumerate(novels[:3], 1):  # 只显示前3本
        print(f"\n{i}.")
        client.print_novel(novel)

    # 3. 获取章节列表
    if novels:
        print("\n3️⃣ 获取第一本小说的章节列表...")
        first_novel = novels[0]
        novel_url = first_novel['url']

        chapters = await client.get_chapters(novel_url)

        if not chapters:
            print("❌ 没有找到章节")
            return

        print(f"✅ 找到 {len(chapters)} 个章节:")
        for i, chapter in enumerate(chapters[:10], 1):  # 只显示前10章
            print(f"  {i}.")
            client.print_chapter(chapter)

        # 4. 获取章节内容
        if chapters:
            print("\n4️⃣ 获取第一章内容...")
            first_chapter = chapters[0]
            chapter_url = first_chapter['url']

            content = await client.get_chapter_content(chapter_url)

            if not content:
                print("❌ 没有找到章节内容")
                return

            print(f"✅ 章节标题: {content.get('title', '未知')}")
            chapter_text = content.get('content', '')

            # 只显示前500个字符
            preview = chapter_text[:500]
            if len(chapter_text) > 500:
                preview += "..."

            print(f"📖 内容预览:\n{preview}")
            print(f"\n📊 章节统计:")
            print(f"   - 总字数: {len(chapter_text)}")
            print(f"   - 段落数: {len([p for p in chapter_text.split('\n') if p.strip()])}")

            if content.get('next_chapter_url'):
                print(f"   - 下一章: {content['next_chapter_url']}")
            if content.get('prev_chapter_url'):
                print(f"   - 上一章: {content['prev_chapter_url']}")


async def demo_error_handling():
    """错误处理演示"""
    print("\n🛠️ 错误处理演示")
    print("=" * 30)

    client = NovelClient(api_token="invalid-token")

    print("1. 测试无效token...")
    novels = await client.search_novels("test")
    if not novels:
        print("✅ 正确处理了无效token")

    print("\n2. 测试无效请求...")
    chapters = await client.get_chapters("invalid-url")
    if not chapters:
        print("✅ 正确处理了无效URL")


async def interactive_mode():
    """交互模式"""
    print("\n🎮 交互模式")
    print("=" * 20)

    import os
    api_token = os.getenv("NOVEL_API_TOKEN", "your-api-token-here")
    base_url = os.getenv("API_BASE_URL", "http://localhost:8000")

    client = NovelClient(base_url=base_url, api_token=api_token)

    while True:
        print("\n请选择操作:")
        print("1. 搜索小说")
        print("2. 查看章节列表")
        print("3. 阅读章节内容")
        print("4. 退出")

        choice = input("\n请输入选择 (1-4): ").strip()

        if choice == "1":
            keyword = input("请输入搜索关键词: ").strip()
            if keyword:
                novels = await client.search_novels(keyword)
                if novels:
                    print(f"\n找到 {len(novels)} 本小说:")
                    for i, novel in enumerate(novels, 1):
                        print(f"{i}. {novel.get('title', '未知')} - {novel.get('author', '未知')}")
                else:
                    print("没有找到相关小说")

        elif choice == "2":
            novel_url = input("请输入小说URL: ").strip()
            if novel_url:
                chapters = await client.get_chapters(novel_url)
                if chapters:
                    print(f"\n找到 {len(chapters)} 个章节:")
                    for i, chapter in enumerate(chapters, 1):
                        print(f"{i}. {chapter.get('title', '未知')}")
                else:
                    print("没有找到章节")

        elif choice == "3":
            chapter_url = input("请输入章节URL: ").strip()
            if chapter_url:
                content = await client.get_chapter_content(chapter_url)
                if content:
                    print(f"\n标题: {content.get('title', '未知')}")
                    print(f"内容:\n{content.get('content', '无内容')}")
                else:
                    print("没有找到章节内容")

        elif choice == "4":
            print("👋 再见!")
            break

        else:
            print("❌ 无效选择，请重新输入")


async def main():
    """主函数"""
    try:
        # 基础使用演示
        await demo_basic_usage()

        # 错误处理演示
        await demo_error_handling()

        # 询问是否进入交互模式
        choice = input("\n是否进入交互模式? (y/n): ").strip().lower()
        if choice in ['y', 'yes', '是']:
            await interactive_mode()

    except KeyboardInterrupt:
        print("\n\n👋 用户中断，程序退出")
    except Exception as e:
        print(f"\n❌ 程序出错: {e}")


if __name__ == "__main__":
    # 运行演示
    asyncio.run(main())