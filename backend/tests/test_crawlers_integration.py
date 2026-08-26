#!/usr/bin/env python3
"""
爬虫集成测试脚本 - 验证重构后的爬虫系统

测试所有爬虫的核心功能：
1. 搜索功能
2. 章节列表获取
3. 章节内容获取
"""

import asyncio
import sys
import time
from pathlib import Path

# 添加项目根目录到 Python 路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.crawler_factory import get_enabled_crawlers


class CrawlerTester:
    """爬虫测试器"""

    def __init__(self):
        self.results = {}
        self.test_keyword = "仙侠"  # 测试关键词

    async def test_all_crawlers(self):
        """测试所有启用的爬虫"""
        print("=" * 60)
        print("开始测试爬虫系统...")
        print("=" * 60)

        crawlers = get_enabled_crawlers()
        print(f"\n已启用 {len(crawlers)} 个爬虫:")
        for site_id in crawlers:
            print(f"  - {site_id}")

        print(f"\n使用测试关键词: '{self.test_keyword}'")
        print("-" * 60)

        # 测试每个爬虫
        for site_id, crawler in crawlers.items():
            await self._test_crawler(site_id, crawler)

        # 打印测试结果摘要
        self._print_summary()

    async def _test_crawler(self, site_id: str, crawler):
        """测试单个爬虫"""
        print(f"\n[{'=' * 50}]")
        print(f"测试 {site_id.upper()}")
        print(f"{'=' * 50}")

        result = {
            "site_id": site_id,
            "search": {"success": False, "count": 0, "error": None},
            "chapter_list": {"success": False, "count": 0, "error": None},
            "chapter_content": {"success": False, "length": 0, "error": None},
        }

        # 1. 测试搜索功能
        print(f"1. 测试搜索功能...")
        try:
            start_time = time.time()
            novels = await crawler.search_novels(self.test_keyword)
            elapsed = time.time() - start_time

            result["search"]["success"] = True
            result["search"]["count"] = len(novels)
            print(f"   ✓ 找到 {len(novels)} 个结果 (耗时 {elapsed:.2f}秒)")

            if novels:
                # 打印第一个结果
                first_novel = novels[0]
                print(f"   示例: {first_novel.get('title', 'N/A')} - {first_novel.get('author', 'N/A')}")

                # 2. 测试章节列表获取
                print(f"\n2. 测试章节列表获取...")
                try:
                    novel_url = first_novel.get("url", "")
                    if novel_url:
                        start_time = time.time()
                        chapters = await crawler.get_chapter_list(novel_url)
                        elapsed = time.time() - start_time

                        result["chapter_list"]["success"] = True
                        result["chapter_list"]["count"] = len(chapters)
                        print(f"   ✓ 获取到 {len(chapters)} 个章节 (耗时 {elapsed:.2f}秒)")

                        if chapters:
                            # 打印第一个和最后一个章节
                            print(f"   首章: {chapters[0].get('title', 'N/A')}")
                            if len(chapters) > 1:
                                print(f"   末章: {chapters[-1].get('title', 'N/A')}")

                            # 3. 测试章节内容获取
                            print(f"\n3. 测试章节内容获取...")
                            try:
                                chapter_url = chapters[0].get("url", "")
                                if chapter_url:
                                    start_time = time.time()
                                    content = await crawler.get_chapter_content(chapter_url)
                                    elapsed = time.time() - start_time

                                    content_text = content.get("content", "")
                                    content_length = len(content_text)

                                    result["chapter_content"]["success"] = True
                                    result["chapter_content"]["length"] = content_length
                                    print(f"   ✓ 获取到章节内容 (耗时 {elapsed:.2f}秒)")
                                    print(f"   标题: {content.get('title', 'N/A')}")
                                    print(f"   内容长度: {content_length} 字符")

                                    # 显示内容预览
                                    if content_text:
                                        preview = content_text[:100].replace("\n", " ")
                                        print(f"   预览: {preview}...")

                                    # 验证内容质量
                                    if content_length < 50:
                                        print(f"   ⚠ 警告: 内容过短，可能提取失败")
                                    elif content_length > 100:
                                        print(f"   ✓ 内容质量良好")
                                else:
                                    print(f"   ✗ 章节URL为空")
                                    result["chapter_content"]["error"] = "章节URL为空"

                            except Exception as e:
                                error_msg = str(e)[:100]
                                print(f"   ✗ 获取章节内容失败: {error_msg}")
                                result["chapter_content"]["error"] = error_msg

                        else:
                            print(f"   ⚠ 没有找到章节，跳过内容测试")
                    else:
                        print(f"   ✗ 小说URL为空，跳过章节测试")
                        result["chapter_list"]["error"] = "小说URL为空"

                except Exception as e:
                    error_msg = str(e)[:100]
                    print(f"   ✗ 获取章节列表失败: {error_msg}")
                    result["chapter_list"]["error"] = error_msg

            else:
                print(f"   ⚠ 没有找到搜索结果，跳过后续测试")

        except Exception as e:
            error_msg = str(e)[:100]
            print(f"   ✗ 搜索失败: {error_msg}")
            result["search"]["error"] = error_msg

        self.results[site_id] = result

        # 关闭爬虫资源
        if hasattr(crawler, "close"):
            await crawler.close()

    def _print_summary(self):
        """打印测试结果摘要"""
        print("\n" + "=" * 60)
        print("测试结果摘要")
        print("=" * 60)

        # 统计结果
        total_crawlers = len(self.results)
        search_success = sum(1 for r in self.results.values() if r["search"]["success"])
        chapter_success = sum(1 for r in self.results.values() if r["chapter_list"]["success"])
        content_success = sum(1 for r in self.results.values() if r["chapter_content"]["success"])

        print(f"\n总体统计:")
        print(f"  总爬虫数: {total_crawlers}")
        print(f"  搜索成功: {search_success}/{total_crawlers}")
        print(f"  章节列表成功: {chapter_success}/{total_crawlers}")
        print(f"  章节内容成功: {content_success}/{total_crawlers}")

        # 详细结果
        print(f"\n详细结果:")
        print(f"{'站点':<15} {'搜索':<8} {'章节':<8} {'内容':<8} {'状态'}")
        print("-" * 60)

        for site_id, result in self.results.items():
            search_status = "✓" if result["search"]["success"] else "✗"
            chapter_status = "✓" if result["chapter_list"]["success"] else "✗"
            content_status = "✓" if result["chapter_content"]["success"] else "✗"

            # 计算总体状态
            if result["search"]["success"]:
                if result["chapter_list"]["success"]:
                    if result["chapter_content"]["success"]:
                        status = "完全正常"
                    else:
                        status = "内容异常"
                else:
                    status = "章节异常"
            else:
                status = "搜索异常"

            print(f"{site_id:<15} {search_status:<8} {chapter_status:<8} {content_status:<8} {status}")

        # 错误详情
        errors = []
        for site_id, result in self.results.items():
            if result["search"]["error"]:
                errors.append(f"{site_id} 搜索: {result['search']['error']}")
            if result["chapter_list"]["error"]:
                errors.append(f"{site_id} 章节: {result['chapter_list']['error']}")
            if result["chapter_content"]["error"]:
                errors.append(f"{site_id} 内容: {result['chapter_content']['error']}")

        if errors:
            print(f"\n错误详情:")
            for error in errors:
                print(f"  - {error}")

        print("\n" + "=" * 60)


async def main():
    """主函数"""
    tester = CrawlerTester()
    await tester.test_all_crawlers()


if __name__ == "__main__":
    asyncio.run(main())
