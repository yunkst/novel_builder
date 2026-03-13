#!/usr/bin/env python3
"""调试脚本 - 捕获实际的错误位置"""
import asyncio
import traceback


async def debug_with_patched_crawler():
    """使用打补丁的爬虫来调试"""
    from app.services.shukuge_crawler_refactored import ShukugeCrawlerRefactored
    from app.services.scrapling_fetcher import RequestConfig, RequestStrategy

    # 保存原始的 fetch 方法
    original_fetch = None

    # 创建一个包装的 fetch 方法来捕获错误
    def patched_fetch(self, url, config):
        print(f'\n[DEBUG] fetch 被调用:')
        print(f'  URL: {url}')
        print(f'  Config: timeout={config.timeout}, strategy={config.strategy}')
        print(f'  post_data: {getattr(config, "post_data", "None")}')
        print(f'  custom_headers: {getattr(config, "custom_headers", "None")}')

        # 检查是否有非字符串值
        if hasattr(config, 'custom_headers') and config.custom_headers:
            for k, v in config.custom_headers.items():
                if not isinstance(v, str):
                    print(f'  [ERROR] Header "{k}" 值不是字符串: {type(v)} = {v}')

        if hasattr(config, 'post_data') and config.post_data:
            for k, v in config.post_data.items():
                if not isinstance(v, str):
                    print(f'  [ERROR] Data "{k}" 值不是字符串: {type(v)} = {v}')

        # 调用原始方法
        return original_fetch(url, config)

    # 爬虫的 fetcher 可能是 ScraplingFetcher 类型
    # 让我们先获取实例
    crawler = ShukugeCrawlerRefactored()

    # 获取原始的 fetch 方法
    if hasattr(crawler.fetcher, 'fetch'):
        original_fetch = crawler.fetcher.fetch
        # 暂时不打补丁，因为 scrapling 内部可能有其他调用方式

    # 测试搜索
    print('=' * 80)
    print('测试 search_novels:')
    print('=' * 80)

    try:
        results = await crawler.search_novels('仙侠')
        print(f'\n返回结果: {len(results)}个')

        if results:
            for i, r in enumerate(results[:3]):
                print(f'{i+1}. {r["title"]}')
    except Exception as e:
        print(f'\n异常: {e}')
        print('=' * 80)
        traceback.print_exc()


if __name__ == '__main__':
    asyncio.run(debug_with_patched_crawler())
