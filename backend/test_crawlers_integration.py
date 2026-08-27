#!/usr/bin/env python3
"""
爬虫功能集成测试

测试所有启用的爬虫站点是否能正常爬取网站内容
"""

import asyncio
import sys
from pathlib import Path
import time

# 添加 app 目录到路径
sys.path.insert(0, str(Path(__file__).parent / "app"))

from app.services.crawler_factory import get_enabled_crawlers, SOURCE_SITES_METADATA


class CrawlerTester:
    """爬虫测试器"""

    def __init__(self):
        self.results = []

    async def test_search(self, crawler, keyword: str = "凡人"):
        """测试搜索功能"""
        crawler_name = crawler.__class__.__name__
        print(f"\n{'='*60}")
        print(f"测试 {crawler_name} - 搜索功能")
        print(f"{'='*60}")

        try:
            start_time = time.time()
            results = await crawler.search_novels(keyword)
            elapsed = time.time() - start_time

            print(f"✓ 搜索成功！")
            print(f"  - 耗时: {elapsed:.2f}秒")
            print(f"  - 结果数量: {len(results)}")

            if results:
                print(f"  - 示例结果:")
                for i, novel in enumerate(results[:3], 1):
                    print(f"    {i}. {novel.get('title', 'N/A')} - {novel.get('url', 'N/A')[:50]}")

            self.results.append({
                'crawler': crawler_name,
                'test': 'search',
                'success': True,
                'elapsed': elapsed,
                'results_count': len(results),
            })
            return True

        except Exception as e:
            print(f"✗ 搜索失败: {e}")
            import traceback
            traceback.print_exc()

            self.results.append({
                'crawler': crawler_name,
                'test': 'search',
                'success': False,
                'error': str(e),
            })
            return False

    async def test_chapter_list(self, crawler, novel_url: str = None):
        """测试章节列表功能"""
        crawler_name = crawler.__class__.__name__
        print(f"\n{'='*60}")
        print(f"测试 {crawler_name} - 章节列表功能")
        print(f"{'='*6060}")

        try:
            # 如果没有提供 URL，先搜索获取一个
            if novel_url is None:
                print("  先搜索获取小说 URL...")
                search_results = await crawler.search_novels("凡人")
                if not search_results:
                    print("  ✗ 无法获取搜索结果，跳过章节列表测试")
                    return False
                novel_url = search_results[0]['url']
                print(f"  使用小说: {search_results[0]['title']}")
                print(f"  URL: {novel_url}")

            start_time = time.time()
            chapters = await crawler.get_chapter_list(novel_url)
            elapsed = time.time() - start_time

            print(f"✓ 获取章节列表成功！")
            print(f"  - 耗时: {elapsed:.2f}秒")
            print(f"  - 章节数量: {len(chapters)}")

            if chapters:
                print(f"  - 章节示例:")
                for i, chapter in enumerate(chapters[:3], 1):
                    print(f"    {i}. {chapter.get('title', 'N/A')}")

            self.results.append({
                'crawler': crawler_name,
                'test': 'chapter_list',
                'success': True,
                'elapsed': elapsed,
                'chapter_count': len(chapters),
            })
            return True

        except Exception as e:
            print(f"✗ 获取章节列表失败: {e}")
            import traceback
            traceback.print_exc()

            self.results.append({
                'crawler': crawler_name,
                'test': 'chapter_list',
                'success': False,
                'error': str(e),
            })
            return False

    async def test_chapter_content(self, crawler, novel_url: str = None):
        """测试章节内容功能"""
        crawler_name = crawler.__class__.__name__
        print(f"\n{'='*60}")
        print(f"测试 {crawler_name} - 章节内容功能")
        print(f"{'='*60}")

        try:
            # 如果没有提供 URL，先搜索并获取章节 URL
            if novel_url is None:
                print("  先搜索获取章节 URL...")
                search_results = await crawler.search_novels("凡人")
                if not search_results:
                    print("  ✗ 无法获取搜索结果")
                    return False

                novel_url = search_results[0]['url']
                print(f"  使用小说: {search_results[0]['title']}")

                # 获取章节列表
                chapters = await crawler.get_chapter_list(novel_url)
                if not chapters:
                    print("  ✗ 无法获取章节列表")
                    return False

                chapter_url = chapters[0]['url']
                print(f"  使用章节: {chapters[0]['title']}")
            else:
                # 假设 novel_url 实际上是章节 URL
                chapter_url = novel_url

            start_time = time.time()
            content = await crawler.get.get_chapter_content(chapter_url)
            elapsed = time.time() - start_time

            print(f"✓ 获取章节内容成功！")
            print(f"  - 耗时: {elapsed:.2f}秒")
            print(f"  - 标题: {content.get('title', 'N/A')}")
            print(f"  - 内容长度: {len(content.get('content', ''))}")

            self.results.append({
                'crawler': crawler_name,
                'test': 'chapter_content',
                'success': True,
                'elapsed': elapsed,
                'content_length': len(content.get('content', '')),
            })
            return True

        except Exception as e:
            print(f"✗ 获取章节内容失败: {e}")
            import traceback
            traceback.print_exc()

            self.results.append({
                'crawler': crawler_name,
                'test': 'chapter_content',
                'success': False,
                'error': str(e),
            })
            return False

    def print_summary(self):
        """打印测试结果汇总"""
        print(f"\n\n{'='*80}")
        print("测试结果汇总")
        print(f"{'='*80}")

        # 按爬虫分组
        crawler_results = {}
        for result in self.results:
            crawler = result['crawler']
            if crawler not in crawler_results:
                crawler_results[crawler] = []
            crawler_results[crawler].append(result)

        for crawler, tests in crawler_results.items():
            print(f"\n{crawler}:")
            for test in tests:
                test_name = test['test']
                success = test['success']

                status = "✓ 通过" if success else "✗ 失败"
                print(f"  - {test_name:12} {status}")

                if success:
                    if 'elapsed' in test:
                        print(f"    耗时: {test['elapsed']:.2f}秒")
                    if 'results_count' in test:
                        print(f"    结果数: {test['results_count']}")
                    if 'chapter_count' in test:
                        print(f"    章节数: {test['chapter_count']}")
                    if 'content_length' in test:
                        print(f"    内容长度: {test['content_length']}")
                else:
                    if 'error' in test:
                        print(f"    错误: {test['error'][:100]}")

        # 统计
        total = len(self.results)
        passed = sum(1 for r in self.results if r['success'])
        success_rate = (passed / total * 100) if total > 0 else 0

        print(f"\n\n总计: {passed}/{total} 通过 ({success_rate:.1f}%)")


async def main():
    """主测试函数"""
    print("="*80)
    print("爬虫功能集成测试")
    print("="*80)

    # 获取所有可用的爬虫
    crawlers = get_enabled_crawlers()

    if not crawlers:
        print("✗ 没有找到可用的爬虫")
        return

    print(f"\n找到 {len(crawlers)} 个可用爬虫:")
    for site_id, crawler in crawlers.items():
        print(f"  - {site_id}: {crawler.__class__.__name__}")

    tester = CrawlerTester()

    # 测试每个爬虫
    for site_id, crawler in crawlers.items():
        print(f"\n\n{'#'*80}")
        print(f"# 爬虫站点: {site_id}")
        print(f"{'#'*80}")

        try:
            # 测试搜索
            await tester.test_search(crawler)

            # 暂停避免测试过多
            # await asyncio.sleep(1)

            # 测试章节列表（如果有搜索结果）
            # await tester.test_chapter_list(crawler)

            # 测试章节内容（如果有章节）
            # await tester.test_chapter_content(crawler)

        except KeyboardInterrupt:
            print("\n\n测试被用户中断")
            break
        except Exception as e:
            print(f"\n✗ 爬虫 {site_id} 测试异常: {e}")
            continue

    # 打印汇总
    tester.print_summary()

    # 清理
    for site_id, crawler in crawlers.items():
        try:
            if hasattr(crawler, 'close'):
                await crawler.close()
        except Exception as e:
            print(f"关闭 {site_id} 爬虫时出错: {e}")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\n测试被用户中断")
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ 测试异常: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
