#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
上传APK到后端服务器
"""
import os
import sys
import requests

# 配置
API_URL = os.getenv('NOVEL_API_URL', 'http://localhost:3800')
API_TOKEN = os.getenv('NOVEL_API_TOKEN', 'test_token_123')
APK_PATH = 'novel_app/build/app/outputs/flutter-apk/app-release.apk'

# 版本信息（从pubspec.yaml读取）
VERSION = '1.3.7'
VERSION_CODE = 25

# 更新日志（可以从命令行参数传入）
CHANGELOG = os.getenv('CHANGELOG', '''
- 优化AI伴读功能，改进关系信息格式化
- 新增特写替换功能的完整测试覆盖（39个测试）
- 提取段落替换工具类，提升代码可维护性
- 修复已知问题并优化性能
''').strip()

FORCE_UPDATE = os.getenv('FORCE_UPDATE', 'false')

def upload_apk():
    """上传APK到后端"""

    # 检查文件是否存在
    if not os.path.exists(APK_PATH):
        print(f"[ERROR] APK file not found: {APK_PATH}")
        sys.exit(1)

    # 检查文件大小
    file_size = os.path.getsize(APK_PATH)
    print(f"[INFO] APK file: {APK_PATH}")
    print(f"[INFO] File size: {file_size / 1024 / 1024:.2f} MB")
    print(f"[INFO] Version: {VERSION}")
    print(f"[INFO] Version code: {VERSION_CODE}")

    # 准备上传
    url = f"{API_URL}/api/app-version/upload"
    headers = {
        'X-API-TOKEN': API_TOKEN
    }

    # 准备数据和文件
    files = {
        'file': open(APK_PATH, 'rb')
    }

    data = {
        'version': VERSION,
        'version_code': str(VERSION_CODE),
        'changelog': CHANGELOG,
        'force_update': FORCE_UPDATE
    }

    print(f"\n[INFO] Uploading to: {url}")
    print(f"[INFO] Changelog:\n{CHANGELOG}\n")

    try:
        # 发送请求
        response = requests.post(url, headers=headers, files=files, data=data, timeout=300)

        # 检查响应
        if response.status_code == 200:
            result = response.json()
            print("[SUCCESS] Upload successful!")
            print(f"[INFO] Version: {result.get('version')}")
            print(f"[INFO] Version code: {result.get('version_code')}")
            print(f"[INFO] Download URL: {result.get('download_url')}")
            print(f"[INFO] Force update: {result.get('force_update')}")
            print(f"[INFO] Created at: {result.get('created_at')}")
        else:
            print(f"[ERROR] Upload failed: HTTP {response.status_code}")
            print(f"[INFO] Response: {response.text}")
            sys.exit(1)

    except requests.exceptions.RequestException as e:
        print(f"[ERROR] Network error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] Unknown error: {e}")
        sys.exit(1)
    finally:
        files['file'].close()

if __name__ == '__main__':
    upload_apk()
