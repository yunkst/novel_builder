#!/usr/bin/env python3
"""调试脚本 - 捕获 Scrapling 错误的完整堆栈跟踪"""
import asyncio
import sys
import traceback


async def debug_shukuge():
    """调试 shukuge 爬虫"""
    from app.services.shukuge_crawler_refactored import ShukugeCrawlerRefactored

    # 启用完整的错误跟踪
    sys.excepthook = lambda exc_type, exc_value, exc_tb: traceback.print_exception(exc_type, exc_value, exc_tb)

    crawler = ShukugeCrawlerRefactored()

    print('=' * 80)
    print('Shukuge 爬虫调试')
    print('=' * 80)

    # 测试 POST 请求
    print('\n测试 POST 请求：')
    print('-' * 40)
    try:
        search_url = f'{crawler.base_url}/modules/article/search.php'
        data = {'searchkey': str('仙侠'), 'searchtype': 'all'}

        print(f'URL: {search_url}')
        print(f'Data: {data}')
        print(f'Custom headers: {crawler.custom_headers}')

        # 直接调用 fetcher
        from app.services.scrapling_fetcher import RequestConfig, RequestStrategy
        from app.services.shukuge_crawler_refactored import ShukugeCrawlerRefactored

        config = RequestConfig(
            timeout=10,
            max_retries=3,
            strategy=RequestStrategy.SIMPLE,
            post_data=data,
            custom_headers=crawler.custom_headers
        )

        print(f'Config: timeout={config.timeout}, strategy={config.strategy}')
        print(f'post_data type: {type(config.post_data)}')
        print(f'post_data: {config.post_data}')

        # 执行请求
        response = await crawler.fetcher.fetch(search_url, config)
        print(f'请求成功! 状态码: {response.status_code}')

    except Exception as e:
        print(f'\n请求失败: {e}')
        print('=' * 80)
        print('完整错误堆栈:')
        print('=' * 80)
        traceback.print_exc()

    # 测试搜索方法
    print('\n\n测试 search_novels 方法：')
    print('-' * 40)
    try:
        results = await crawler.search_novels('仙侠')
        print(f'返回结果: {len(results)}个')

        if results:
            for i, r in enumerate(results[:3]):
                print(f'{i+1}. {r["title"]}')
    except Exception as e:
        print(f'搜索失败: {e}')
        print('=' * 80)
        print('完整错误堆栈:')
        print('=' * 80)
        traceback.print_exc()


if __name__ == '__main__':
    asyncio.run(debug_shukuge())
