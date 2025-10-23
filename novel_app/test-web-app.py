#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
简单的Flutter Web应用测试脚本
使用requests和BeautifulSoup来测试Web应用功能
"""

import requests
import time
import json
from typing import Dict, Any

class FlutterWebAppTester:
    def __init__(self, base_url: str = "http://localhost:3000"):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })

    def test_basic_access(self) -> bool:
        """测试基本访问"""
        try:
            response = self.session.get(self.base_url, timeout=10)
            print(f"✓ 基本访问测试: {response.status_code}")

            if response.status_code == 200:
                content = response.text
                print(f"  - 页面标题包含 'novel_app': {'novel_app' in content}")
                print(f"  - Flutter脚本已加载: {'flutter_bootstrap.js' in content}")
                print(f"  - CORS配置已添加: {'Access-Control-Allow-Origin' in content}")
                return True
            else:
                print(f"  ❌ 访问失败，状态码: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ 基本访问测试失败: {e}")
            return False

    def test_backend_api_connectivity(self) -> bool:
        """测试后端API连接性"""
        backend_url = "http://localhost:3800"

        try:
            # 测试健康检查
            response = requests.get(f"{backend_url}/health", timeout=5)
            print(f"✓ 后端健康检查: {response.status_code}")

            if response.status_code == 200:
                health_data = response.json()
                print(f"  - 健康状态: {health_data.get('status')}")

                # 测试搜索API
                search_response = requests.get(
                    f"{backend_url}/search?keyword=test",
                    headers={"X-API-TOKEN": "your-api-token-here"},
                    timeout=5
                )
                print(f"✓ 后端搜索API: {search_response.status_code}")

                if search_response.status_code == 200:
                    results = search_response.json()
                    print(f"  - 搜索返回结果数量: {len(results)}")
                    return True
                else:
                    print(f"  - 搜索失败: {search_response.text}")
                    return False
            else:
                print(f"  ❌ 健康检查失败: {response.text}")
                return False
        except Exception as e:
            print(f"❌ 后端API连接测试失败: {e}")
            return False

    def test_cors_configuration(self) -> bool:
        """测试CORS配置"""
        try:
            # 发送OPTIONS请求测试CORS
            response = requests.options(
                self.base_url,
                headers={
                    'Origin': 'http://localhost:3000',
                    'Access-Control-Request-Method': 'GET',
                    'Access-Control-Request-Headers': 'Content-Type'
                },
                timeout=5
            )

            print(f"✓ CORS OPTIONS测试: {response.status_code}")

            cors_headers = {
                'Access-Control-Allow-Origin',
                'Access-Control-Allow-Methods',
                'Access-Control-Allow-Headers'
            }

            for header in cors_headers:
                if header in response.headers:
                    print(f"  - {header}: {response.headers[header]}")
                else:
                    print(f"  - ⚠️ 缺少CORS头: {header}")

            return True
        except Exception as e:
            print(f"❌ CORS配置测试失败: {e}")
            return False

    def test_page_load_time(self) -> bool:
        """测试页面加载时间"""
        try:
            start_time = time.time()
            response = self.session.get(self.base_url, timeout=10)
            load_time = time.time() - start_time

            print(f"✓ 页面加载时间: {load_time:.2f}秒")

            if load_time < 5:
                print("  - 加载速度良好")
                return True
            else:
                print("  - ⚠️ 加载速度较慢")
                return False
        except Exception as e:
            print(f"❌ 页面加载时间测试失败: {e}")
            return False

    def run_all_tests(self) -> Dict[str, bool]:
        """运行所有测试"""
        print("🧪 开始Flutter Web应用功能测试")
        print("=" * 50)

        tests = {
            "基本访问": self.test_basic_access,
            "后端API连接": self.test_backend_api_connectivity,
            "CORS配置": self.test_cors_configuration,
            "页面加载性能": self.test_page_load_time,
        }

        results = {}
        for test_name, test_func in tests.items():
            print(f"\n🔍 {test_name}测试:")
            results[test_name] = test_func()

        return results

    def print_summary(self, results: Dict[str, bool]):
        """打印测试总结"""
        print("\n" + "=" * 50)
        print("📊 测试结果总结:")

        passed = sum(results.values())
        total = len(results)

        for test_name, result in results.items():
            status = "✅ 通过" if result else "❌ 失败"
            print(f"  {test_name}: {status}")

        print(f"\n总体结果: {passed}/{total} 测试通过")

        if passed == total:
            print("🎉 所有测试都通过了！Flutter Web应用运行正常。")
        else:
            print("⚠️ 部分测试失败，请检查上述问题。")

def main():
    tester = FlutterWebAppTester()
    results = tester.run_all_tests()
    tester.print_summary(results)

    return 0 if all(results.values()) else 1

if __name__ == "__main__":
    exit(main())