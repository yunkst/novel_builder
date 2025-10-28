#!/usr/bin/env python3
"""
测试新的API功能

1. 测试源站列表接口
2. 测试指定站点搜索功能
3. 验证向后兼容性
4. 测试错误处理
"""

import time
import requests
import json


def test_source_sites_api():
    """测试源站列表API"""
    print("🔍 测试源站列表API...")

    base_url = "http://backend:8000"
    headers = {
        "X-API-TOKEN": "test_token_123",
        "Content-Type": "application/json"
    }

    try:
        response = requests.get(f"{base_url}/source-sites", headers=headers, timeout=10)

        if response.status_code == 200:
            sites = response.json()
            print(f"✅ 源站列表API成功，返回 {len(sites)} 个站点")

            for site in sites:
                print(f"   - {site['id']}: {site['name']} ({'启用' if site['enabled'] else '禁用'})")
                print(f"     URL: {site['base_url']}")
                print(f"     描述: {site['description']}")

            return sites
        else:
            print(f"❌ 源站列表API失败: {response.status_code}")
            print(f"错误信息: {response.text}")
            return None

    except Exception as e:
        print(f"❌ 源站列表API异常: {e}")
        return None


def test_search_with_sites():
    """测试指定站点搜索功能"""
    print("\n🔍 测试指定站点搜索功能...")

    base_url = "http://backend:8000"
    headers = {
        "X-API-TOKEN": "test_token_123",
        "Content-Type": "application/json"
    }

    # 测试关键词
    keyword = "斗破苍穹"

    # 1. 测试指定alice_sw站点搜索
    print(f"\n📖 测试指定alice_sw站点搜索: {keyword}")
    try:
        response = requests.get(
            f"{base_url}/search",
            headers=headers,
            params={"keyword": keyword, "sites": "alice_sw"},
            timeout=30
        )

        if response.status_code == 200:
            results = response.json()
            print(f"✅ alice_sw站点搜索成功，找到 {len(results)} 个结果")
            if results:
                for i, novel in enumerate(results[:3]):  # 只显示前3个结果
                    print(f"   {i+1}. {novel['title']} - {novel['author']}")
        else:
            print(f"❌ alice_sw站点搜索失败: {response.status_code}")
            print(f"错误信息: {response.text}")

    except Exception as e:
        print(f"❌ alice_sw站点搜索异常: {e}")

    # 2. 测试多个站点搜索
    print(f"\n📖 测试多个站点搜索: {keyword}")
    try:
        response = requests.get(
            f"{base_url}/search",
            headers=headers,
            params={"keyword": keyword, "sites": "alice_sw,shukuge"},
            timeout=30
        )

        if response.status_code == 200:
            results = response.json()
            print(f"✅ 多站点搜索成功，找到 {len(results)} 个结果")
            if results:
                for i, novel in enumerate(results[:3]):  # 只显示前3个结果
                    print(f"   {i+1}. {novel['title']} - {novel['author']}")
        else:
            print(f"❌ 多站点搜索失败: {response.status_code}")
            print(f"错误信息: {response.text}")

    except Exception as e:
        print(f"❌ 多站点搜索异常: {e}")


def test_backward_compatibility():
    """测试向后兼容性"""
    print("\n🔍 测试向后兼容性（不传sites参数）...")

    base_url = "http://backend:8000"
    headers = {
        "X-API-TOKEN": "test_token_123",
        "Content-Type": "application/json"
    }

    keyword = "遮天"

    try:
        response = requests.get(
            f"{base_url}/search",
            headers=headers,
            params={"keyword": keyword},  # 不传sites参数
            timeout=30
        )

        if response.status_code == 200:
            results = response.json()
            print(f"✅ 向后兼容性测试成功，找到 {len(results)} 个结果")
            if results:
                for i, novel in enumerate(results[:3]):  # 只显示前3个结果
                    print(f"   {i+1}. {novel['title']} - {novel['author']}")
        else:
            print(f"❌ 向后兼容性测试失败: {response.status_code}")
            print(f"错误信息: {response.text}")

    except Exception as e:
        print(f"❌ 向后兼容性测试异常: {e}")


def test_error_handling():
    """测试错误处理"""
    print("\n🔍 测试错误处理...")

    base_url = "http://backend:8000"
    headers = {
        "X-API-TOKEN": "test_token_123",
        "Content-Type": "application/json"
    }

    # 测试无效站点
    print("\n📖 测试无效站点...")
    try:
        response = requests.get(
            f"{base_url}/search",
            headers=headers,
            params={"keyword": "测试", "sites": "invalid_site"},
            timeout=10
        )

        if response.status_code == 400:
            print("✅ 无效站点错误处理正常")
        else:
            print(f"❌ 无效站点错误处理异常: {response.status_code}")

    except Exception as e:
        print(f"❌ 无效站点测试异常: {e}")

    # 测试无效Token
    print("\n📖 测试无效Token...")
    try:
        response = requests.get(
            f"{base_url}/source-sites",
            headers={"X-API-TOKEN": "invalid_token"},
            timeout=10
        )

        if response.status_code == 401:
            print("✅ 无效Token错误处理正常")
        else:
            print(f"❌ 无效Token错误处理异常: {response.status_code}")

    except Exception as e:
        print(f"❌ 无效Token测试异常: {e}")


def main():
    """主测试函数"""
    print("🚀 开始测试新API功能")
    print("=" * 50)

    # 1. 测试源站列表API
    sites = test_source_sites_api()

    if sites:
        # 2. 测试指定站点搜索
        test_search_with_sites()

        # 3. 测试向后兼容性
        test_backward_compatibility()

        # 4. 测试错误处理
        test_error_handling()

        print("\n" + "=" * 50)
        print("🎉 所有测试完成！")
    else:
        print("\n❌ 源站列表API测试失败，跳过其他测试")


if __name__ == "__main__":
    main()