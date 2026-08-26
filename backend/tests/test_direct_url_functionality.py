#!/usr/bin/env python3
"""
测试 DDXSMF 和 Biquge543 站点的直接URL添加功能

测试日期: 2026-03-12
测试目的: 验证这些站点虽然不支持搜索，但仍然可以通过直接URL添加小说
"""

import asyncio
import json
from pathlib import Path
import httpx

# 添加项目路径
sys_path = str(Path(__file__).parent.parent)
import sys
if sys_path not in sys.path:
    sys.path.insert(0, sys_path)

from app.services.ddxsmf_crawler import DdxsmfCrawler
from app.services.biquge543_crawler import Biquge543Crawler


def print_section(title):
    """打印分节标题"""
    print("\n" + "=" * 80)
    print(f"  {title}")
    print("=" * 80)


async def test_ddxsmf_direct_url():
    """测试 DDXSMF 直接URL功能"""
    print_section("测试 DDXSMF 直接URL功能")

    crawler = DdxsmfCrawler()

    # 测试URL
    test_novel_url = "https://www.ddxsmf.com/15/"

    print(f"\n测试小说URL: {test_novel_url}")

    # 1. 测试 get_novel_info
    print("\n--- 1. 测试 get_novel_info ---")
    novel_info = await crawler.get_novel_info(test_novel_url)

    print(f"小说标题: {novel_info.get('title', 'N/A')}")
    print(f"作者: {novel_info.get('author', 'N/A')}")
    print(f"URL: {novel_info.get('url', 'N/A')}")
    print(f"封面: {novel_info.get('cover_url', 'N/A')[:60]}..." if novel_info.get('cover_url') else "封面: N/A")
    print(f"简介: {novel_info.get('description', 'N/A')[:100]}..." if novel_info.get('description') else "简介: N/A")

    chapters = novel_info.get('chapters', [])
    print(f"\n找到 {len(chapters)} 个章节")

    if chapters:
        print(f"第1章: {chapters[0].get('title', 'N/A')}")
        print(f"最后1章: {chapters[-1].get('title', 'N/A')}")

    # 2. 测试 get_chapter_list（单独测试）
    print("\n--- 2. 测试 get_chapter_list（单独测试）---")
    chapters_list = await crawler.get_chapter_list(test_novel_url)
    print(f"找到 {len(chapters_list)} 个章节")
    if chapters_list:
        print(f"第1章: {chapters_list[0].get('title', 'N/A')}")
        print(f"最后1章: {chapters_list[-1].get('title', 'N/A')}")

    # 3. 测试 get_chapter_content
    if chapters_list:
        print("\n--- 3. 测试 get_chapter_content ---")
        first_chapter_url = chapters_list[0].get('url', '')
        print(f"测试章节URL: {first_chapter_url}")

        content = await crawler.get_chapter_content(first_chapter_url)
        print(f"章节标题: {content.get('title', 'N/A')}")
        print(f"内容长度: {len(content.get('content', ''))}")
        print(f"内容预览: {content.get('content', '')[:200]}...")

    return {
        'novel_info': novel_info,
        'success': len(chapters) > 0
    }


async def test_biquge543_direct_url():
    """测试 Biquge543 直接URL功能"""
    print_section("测试 Biquge543 直接URL功能")

    crawler = Biquge543Crawler()

    # 测试URL
    test_novel_url = "https://m.biquge543.com/shu/163512/"

    print(f"\n测试小说URL: {test_novel_url}")

    # 1. 测试 get_novel_info
    print("\n--- 1. 测试 get_novel_info ---")
    novel_info = await crawler.get_novel_info(test_novel_url)

    print(f"小说标题: {novel_info.get('title', 'N/A')}")
    print(f"作者: {novel_info.get('author', 'N/A')}")
    print(f"URL: {novel_info.get('url', 'N/A')}")
    print(f"封面: {novel_info.get('cover_url', 'N/A')[:60]}..." if novel_info.get('cover_url') else "封面: N/A")
    print(f"简介: {novel_info.get('description', 'N/A')[:100]}..." if novel_info.get('description') else "简介: N/A")

    chapters = novel_info.get('chapters', [])
    print(f"\n找到 {len(chapters)} 个章节")

    if chapters:
        print(f"第1章: {chapters[0].get('title', 'N/A')}")
        print(f"最后1章: {chapters[-1].get('title', 'N/A')}")

    # 2. 测试 get_chapter_list（单独测试）
    print("\n--- 2. 测试 get_chapter_list（单独测试）---")
    chapters_list = await crawler.get_chapter_list(test_novel_url)
    print(f"找到 {len(chapters_list)} 个章节")
    if chapters_list:
        print(f"第1章: {chapters_list[0].get('title', 'N/A')}")
        print(f"最后1章: {chapters_list[-1].get('title', 'N/A')}")

    # 3. 测试 get_chapter_content
    if chapters_list:
        print("\n--- 3. 测试 get_chapter_content ---")
        first_chapter_url = chapters_list[0].get('url', '')
        print(f"测试章节URL: {first_chapter_url}")

        content = await crawler.get_chapter_content(first_chapter_url)
        print(f"章节标题: {content.get('title', 'N/A')}")
        print(f"内容长度: {len(content.get('content', ''))}")
        print(f"内容预览: {content.get('content', '')[:200]}...")

    return {
        'novel_info': novel_info,
        'success': len(chapters) > 0
    }


async def test_novel_by_url_api():
    """测试 /novel-by-url API 端点"""
    print_section("测试 /novel-by-url API 端点")

    api_base_url = "http://localhost:8000"
    api_token = "test_token_123"

    headers = {
        "X-API-TOKEN": api_token,
        "Content-Type": "application/json"
    }

    # 测试 DDXSMF
    print("\n--- 测试 DDXSMF ---")
    ddxsmf_url = "https://www.ddxsmf.com/15/"
    print(f"请求URL: {api_base_url}/novel-by-url?url={ddxsmf_url}")

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.get(
                f"{api_base_url}/novel-by-url",
                params={"url": ddxsmf_url},
                headers=headers
            )
            print(f"状态码: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                novel = data.get('novel', {})
                chapters = data.get('chapters', [])
                print(f"小说标题: {novel.get('title', 'N/A')}")
                print(f"作者: {novel.get('author', 'N/A')}")
                print(f"章节数量: {len(chapters)}")
                if chapters:
                    print(f"第1章: {chapters[0].get('title', 'N/A')}")
                    print(f"最后1章: {chapters[-1].get('title', 'N/A')}")
            else:
                print(f"错误: {response.text}")
    except Exception as e:
        print(f"请求失败: {e}")

    # 测试 Biquge543
    print("\n--- 测试 Biquge543 ---")
    biquge543_url = "https://m.biquge543.com/shu/163512/"
    print(f"请求URL: {api_base_url}/novel-by-url?url={biquge543_url}")

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.get(
                f"{api_base_url}/novel-by-url",
                params={"url": biquge543_url},
                headers=headers
            )
            print(f"状态码: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                novel = data.get('novel', {})
                chapters = data.get('chapters', [])
                print(f"小说标题: {novel.get('title', 'N/A')}")
                print(f"作者: {novel.get('author', 'N/A')}")
                print(f"章节数量: {len(chapters)}")
                if chapters:
                    print(f"第1章: {chapters[0].get('title', 'N/A')}")
                    print(f"最后1章: {chapters[-1].get('title', 'N/A')}")
            else:
                print(f"错误: {response.text}")
    except Exception as e:
        print(f"请求失败: {e}")


async def main():
    """主测试函数"""
    print_section("直接URL功能测试")
    print("\n测试目标: DDXSMF 和 Biquge543 站点")
    print("测试内容: get_novel_info, get_chapter_list, get_chapter_content, API端点")

    # 测试结果
    results = {}

    # 1. 测试 DDXSMF
    try:
        results['ddxsmf'] = await test_ddxsmf_direct_url()
    except Exception as e:
        print(f"\nDDXSMF 测试失败: {e}")
        import traceback
        traceback.print_exc()
        results['ddxsmf'] = {'success': False, 'error': str(e)}

    # 2. 测试 Biquge543
    try:
        results['biquge543'] = await test_biquge543_direct_url()
    except Exception as e:
        print(f"\nBiquge543 测试失败: {e}")
        import traceback
        traceback.print_exc()
        results['biquge543'] = {'success': False, 'error': str(e)}

    # 3. 测试 API 端点
    try:
        await test_novel_by_url_api()
    except Exception as e:
        print(f"\nAPI 端点测试失败: {e}")
        import traceback
        traceback.print_exc()

    # 4. 打印总结
    print_section("测试总结")
    print("\n1. DDXSMF 直接URL功能:")
    ddxsmf_result = results.get('ddxsmf', {})
    ddxsmf_success = ddxsmf_result.get('success', False)
    print(f"   状态: {'✅ 通过' if ddxsmf_success else '❌ 失败'}")
    if ddxsmf_success:
        novel_info = ddxsmf_result.get('novel_info', {})
        print(f"   小说: {novel_info.get('title', 'N/A')}")
        print(f"   章节数: {len(novel_info.get('chapters', []))}")
    if 'error' in ddxsmf_result:
        print(f"   错误: {ddxsmf_result['error']}")

    print("\n2. Biquge543 直接URL功能:")
    biquge543_result = results.get('biquge543', {})
    biquge543_success = biquge543_result.get('success', False)
    print(f"   状态: {'✅ 通过' if biquge543_success else '❌ 失败'}")
    if biquge543_success:
        novel_info = biquge543_result.get('novel_info', {})
        print(f"   小说: {novel_info.get('title', 'N/A')}")
        print(f"   章节数: {len(novel_info.get('chapters', []))}")
    if 'error' in biquge543_result:
        print(f"   错误: {biquge543_result['error']}")

    print("\n3. API /novel-by-url 端点:")
    print("   状态: 上述测试中已包含API调用结果")

    print("\n" + "=" * 80)
    print("结论:")
    print("=" * 80)

    if ddxsmf_success and biquge543_success:
        print("\n✅ 两个站点都可以通过直接URL添加小说！")
        print("\n这些站点虽然不支持搜索功能，但用户可以通过直接URL添加小说，")
        print("然后正常获取章节列表和章节内容。")
        print("\n支持的功能:")
        print("  • get_novel_info: 获取小说详细信息（标题、作者、封面、简介、章节列表）")
        print("  • get_chapter_list: 单独获取章节列表")
        print("  • get_chapter_content: 获取章节内容")
        print("  • API /novel-by-url: 通过URL直接获取小说信息和章节列表")
    else:
        print("\n⚠️ 部分站点功能存在问题，需要进一步调试。")
        if not ddxsmf_success:
            print("   - DDXSMF: 需要检查")
        if not biquge543_success:
            print("   - Biquge543: 需要检查")


if __name__ == "__main__":
    asyncio.run(main())
