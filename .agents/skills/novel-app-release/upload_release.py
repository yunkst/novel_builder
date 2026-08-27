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
VERSION = "1.1.0"
VERSION_CODE = 11
CHANGELOG = """修复APP更新下载功能（重要更新）：
- 使用 Dio 替代 background_downloader 进行文件下载
- 添加原生 MethodChannel 实现 APK 安装功能
- 修复下载卡在 enqueued 状态的问题
- 完善角色管理和编辑功能
- 优化 UI 显示效果和搜索高亮

角色管理功能：
- 新增角色编辑和管理界面
- 添加角色提取服务
- 完善角色匹配逻辑

UI/UX 优化：
- 修复 withOpacity deprecated 警告
- 优化搜索结果高亮显示
- 改进章节列表标题样式"""

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
            return True

        except requests.exceptions.RequestException as e:
            print(f"\n❌ 上传失败: {e}")
            if hasattr(e.response, 'text'):
                print(f"   响应: {e.response.text}")
            return False

if __name__ == '__main__':
    upload_apk()
