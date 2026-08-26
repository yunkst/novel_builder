#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Upload APK to backend server."""
import requests
import os
import sys

# Set stdout encoding to UTF-8 for Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Configuration
APK_PATH = r"D:\myspace\novel_builder\novel_app\build\app\outputs\flutter-apk\app-release.apk"
API_URL = "http://localhost:3800/api/app-version/upload"
API_TOKEN = "test_token_123"
VERSION = "1.0.9"
VERSION_CODE = 10
CHANGELOG = """修复APP更新下载功能：
- 使用 background_downloader 标准API重写下载逻辑
- 修复下载卡在 enqueued 状态的问题
- 添加完整的进度和状态回调
- 优化权限请求流程"""

def upload_apk():
    """Upload APK file to backend server."""
    if not os.path.exists(APK_PATH):
        print(f"❌ APK文件不存在: {APK_PATH}")
        return False

    print(f"📦 开始上传 APK...")
    print(f"   文件: {APK_PATH}")
    print(f"   版本: {VERSION} (build {VERSION_CODE})")
    print(f"   大小: {os.path.getsize(APK_PATH) / 1024 / 1024:.1f} MB")
    print(f"   URL: {API_URL}")

    headers = {
        'X-API-TOKEN': API_TOKEN
    }

    with open(APK_PATH, 'rb') as f:
        files = {'file': f}
        data = {
            'version': VERSION,
            'version_code': str(VERSION_CODE),
            'changelog': CHANGELOG,
            'force_update': 'false'
        }

        try:
            response = requests.post(API_URL, headers=headers, files=files, data=data)
            response.raise_for_status()

            result = response.json()
            print(f"\n✅ 上传成功!")
            print(f"   版本: {result.get('version')}")
            print(f"   版本码: {result.get('version_code')}")
            print(f"   下载URL: {result.get('download_url')}")
            print(f"\n📝 更新日志:")
            print(f"   {CHANGELOG}")
            return True

        except requests.exceptions.RequestException as e:
            print(f"\n❌ 上传失败: {e}")
            if hasattr(e.response, 'text'):
                print(f"   响应: {e.response.text}")
            return False

if __name__ == '__main__':
    upload_apk()
