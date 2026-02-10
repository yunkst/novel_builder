#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试App与后端API交互的脚本
验证Token、搜索、章节获取等核心功能
"""
import requests
import json
from typing import Optional
import sys
import io

# 修复Windows编码问题
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# 配置
BACKEND_HOST = "http://localhost:3800"
API_TOKEN = "test_token_123"  # 使用实际的API Token

def print_section(title: str):
    """打印分节标题"""
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def test_connection():
    """测试后端连接"""
    print_section("1. 测试后端连接")

    try:
        response = requests.get(f"{BACKEND_HOST}/docs", timeout=5)
        if response.status_code == 200:
            print(f"[OK] 后端服务运行正常: {BACKEND_HOST}")
            return True
        else:
            print(f"[FAIL] 后端响应异常: {response.status_code}")
            return False
    except Exception as e:
        print(f"[FAIL] 无法连接到后端: {e}")
        return False

def test_source_sites():
    """测试获取源站列表"""
    print_section("2. 测试获取源站列表")

    headers = {"X-API-TOKEN": API_TOKEN}
    url = f"{BACKEND_HOST}/source-sites"

    print(f"请求: GET {url}")
    print(f"Headers: {headers}")

    try:
        response = requests.get(url, headers=headers, timeout=10)
        print(f"响应状态码: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            print(f"[OK] 成功获取源站列表")
            print(f"源站数量: {len(data)}")
            for site in data[:3]:  # 只显示前3个
                print(f"  - {site.get('name', 'N/A')}: {site.get('base_url', 'N/A')}")
            return True, data
        else:
            print(f"[FAIL] 请求失败")
            print(f"响应内容: {response.text[:200]}")
            return False, None
    except Exception as e:
        print(f"[FAIL] 请求异常: {e}")
        return False, None

def test_search():
    """测试搜索功能"""
    print_section("3. 测试小说搜索")

    headers = {"X-API-TOKEN": API_TOKEN}
    keyword = "斗破"
    url = f"{BACKEND_HOST}/search"
    params = {"keyword": keyword}

    print(f"请求: GET {url}")
    print(f"参数: keyword={keyword}")
    print(f"Headers: {headers}")

    try:
        response = requests.get(url, headers=headers, params=params, timeout=30)
        print(f"响应状态码: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            print(f"[OK] 搜索成功")
            print(f"结果数量: {len(data)}")
            if data:
                novel = data[0]
                print(f"\n示例小说:")
                print(f"  标题: {novel.get('title', 'N/A')}")
                print(f"  作者: {novel.get('author', 'N/A')}")
                print(f"  URL: {novel.get('url', 'N/A')}")
                return True, novel
            else:
                print("[WARN] 搜索结果为空")
                return True, None
        else:
            print(f"[FAIL] 搜索失败")
            print(f"响应内容: {response.text[:200]}")
            return False, None
    except Exception as e:
        print(f"[FAIL] 请求异常: {e}")
        return False, None

def test_chapters(novel_url: Optional[str]):
    """测试获取章节列表"""
    if not novel_url:
        print("\n[WARN]  跳过章节测试（没有小说URL）")
        return False, None

    print_section("4. 测试获取章节列表")

    headers = {"X-API-TOKEN": API_TOKEN}
    url = f"{BACKEND_HOST}/chapters"
    params = {"url": novel_url}

    print(f"请求: GET {url}")
    print(f"参数: url={novel_url[:50]}...")
    print(f"Headers: {headers}")

    try:
        response = requests.get(url, headers=headers, params=params, timeout=30)
        print(f"响应状态码: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            print(f"[OK] 成功获取章节列表")
            print(f"章节数量: {len(data)}")
            if data:
                chapter = data[0]
                print(f"\n第一章:")
                print(f"  标题: {chapter.get('title', 'N/A')}")
                print(f"  URL: {chapter.get('url', 'N/A')}")
                return True, chapter.get('url')
            return True, None
        else:
            print(f"[FAIL] 获取章节失败")
            print(f"响应内容: {response.text[:200]}")
            return False, None
    except Exception as e:
        print(f"[FAIL] 请求异常: {e}")
        return False, None

def test_chapter_content(chapter_url: Optional[str]):
    """测试获取章节内容"""
    if not chapter_url:
        print("\n[WARN]  跳过章节内容测试（没有章节URL）")
        return False

    print_section("5. 测试获取章节内容")

    headers = {"X-API-TOKEN": API_TOKEN}
    url = f"{BACKEND_HOST}/chapter-content"
    params = {"url": chapter_url}

    print(f"请求: GET {url}")
    print(f"参数: url={chapter_url[:50]}...")
    print(f"Headers: {headers}")

    try:
        response = requests.get(url, headers=headers, params=params, timeout=30)
        print(f"响应状态码: {response.status_code}")

        if response.status_code == 200:
            data = response.json()
            content = data.get('content', '')
            print(f"[OK] 成功获取章节内容")
            print(f"内容长度: {len(content)} 字符")
            print(f"内容预览: {content[:100]}...")
            return True
        else:
            print(f"[FAIL] 获取章节内容失败")
            print(f"响应内容: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"[FAIL] 请求异常: {e}")
        return False

def main():
    """主测试流程"""
    print_section("App与后端API交互测试")
    print(f"后端地址: {BACKEND_HOST}")
    print(f"API Token: {API_TOKEN}")

    results = []

    # 1. 测试连接
    results.append(("连接测试", test_connection()))

    # 2. 测试源站列表
    success, sites = test_source_sites()
    results.append(("源站列表", success))

    # 3. 测试搜索
    success, novel = test_search()
    results.append(("小说搜索", success))
    novel_url = novel.get('url') if novel else None

    # 4. 测试章节列表
    success, chapter_url = test_chapters(novel_url)
    results.append(("章节列表", success))

    # 5. 测试章节内容
    success = test_chapter_content(chapter_url)
    results.append(("章节内容", success))

    # 总结
    print_section("测试结果总结")
    passed = sum(1 for _, result in results if result)
    total = len(results)

    for name, result in results:
        status = "[OK] 通过" if result else "[FAIL] 失败"
        print(f"{status}  {name}")

    print(f"\n总计: {passed}/{total} 测试通过")

    if passed == total:
        print("\n[SUCCESS] 所有测试通过！App与后端交互正常。")
    else:
        print(f"\n[WARN]  有 {total - passed} 个测试失败，请检查配置。")
        print("\n[INFO] 建议:")
        print("1. 确认后端服务正在运行")
        print("2. 检查API Token是否正确")
        print("3. 查看后端日志: docker-compose logs -f backend")

if __name__ == "__main__":
    main()
