#!/usr/bin/env python3
import asyncio
import sys

async def test_crawler(site_id, crawler):
    print('\n' + '=' * 50)
    print(f'{site_id.upper()} ({crawler.__class__.__name__})')
    print('=' * 50)

    features = {
        'search': False,
        'search_results': 0,
        'search_error': None,
        'chapter_list': False,
        'chapter_list_count': 0,
        'chapter_list_error': None,
        'chapter_content': False,
        'chapter_content_error': None
    }

    # 测试搜索
    try:
        results = await crawler.search_novels('仙侠')
        features['search'] = True
        features['search_results'] = len(results)
        if results:
            print(f'✓ 搜索功能: 返回 {len(results)} 个结果')
            print(f'  示例结果: "{results[0]["title"]}" ({results[0]["url"][:60]}...)')
        else:
            print(f'✗ 搜索功能: 返回 0 个结果（可能被禁用或站点问题）')
    except Exception as e:
        features['search_error'] = str(e)[:100]
        print(f'✗ 搜索功能: {str(e)[:80]}...')

    # 如果搜索返回了结果，测试章节列表
    if features['search_results'] > 0:
        try:
            test_url = results[0]['url']
            chapters = await crawler.get_chapter_list(test_url)
            features['chapter_list'] = True
            features['chapter_list_count'] = len(chapters)
            if chapters:
                print(f'✓ 章节列表: 返回 {len(chapters)} 个章节')
                print(f'  首章节: "{chapters[0]["title"]}"')

                # 测试章节内容
                try:
                    content = await crawler.get_chapter_content(chapters[0]['url'])
                    features['chapter_content'] = True
                    content_length = len(content.get('content', ''))
                    if content_length > 100:
                        print(f'✓ 章节内容: 返回 {content_length} 字符')
                        print(f'  内容预览: {content.get("content", "")[:60]}...')
                    else:
                        print(f'✗ 章节内容: 内容太短 ({content_length} 字符)或为空')
                except Exception as e:
                    features['chapter_content_error'] = str(e)[:100]
                    print(f'✗ 章节内容: {str(e)[:80]}...')
            else:
                print(f'✗ 章节列表: 未找到章节')
        except Exception as e:
            features['chapter_list_error'] = str(e)[:100]
            print(f'✗ 章节列表: {str(e)[:80]}...')
    else:
        print(f'⚠ 跳过章节测试（搜索无结果）')

    return features

async def main():
    from app.services.crawler_factory import get_enabled_crawlers

    crawlers = get_enabled_crawlers()
    all_features = {}

    for site_id, crawler in crawlers.items():
        try:
            features = await test_crawler(site_id, crawler)
            all_features[site_id] = features
        except Exception as e:
            print(f'✗ {site_id} 测试异常: {str(e)[:100]}')
            all_features[site_id] = {'error': str(e)[:100]}

    # 总结
    print('\n\n' + '=' * 70)
    print('功能总结')
    print('=' * 70)

    for site_id, features in sorted(all_features.items()):
        if 'error' in features:
            print(f'{site_id:15} ✗ 导入失败')
        else:
            status_parts = []
            if features['search']:
                status_parts.append(f'搜索({features["search_results"]}个)')
            if features['chapter_list']:
                status_parts.append(f'章节列表({features["chapter_list_count"]}个)')
            if features['chapter_content']:
                status_parts.append('章节内容')

            if status_parts:
                print(f'{site_id:15} ✓ {" ".join(status_parts)}')
            else:
                parts = []
                if features['search_error']:
                    parts.append('搜索错误')
                if features['chapter_list_error']:
                    parts.append('章节列表错误')
                if features['chapter_content_error']:
                    parts.append('章节内容错误')
                print(f'{site_id:15} ✗ {" ".join(parts)}')

asyncio.run(main())
