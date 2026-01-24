#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
上传 Novel App APK 到后端服务器
"""
import requests
import os
import sys

# 配置
API_URL = "http://localhost:3800/api/app-version/upload"
API_TOKEN = "test_token_123"
APK_PATH = "novel_app/build/app/outputs/flutter-apk/app-release.apk"
VERSION = "1.3.1"
VERSION_CODE = 19
CHANGELOG = """沉浸体验交互优化：
- 优化角色选择方式，改用FilterChip点击切换
- 移除删除按钮，防止用户误删
- 改进视觉反馈，选中状态更清晰
- 显示所有可用角色，方便用户选择"""

def upload_apk():
    """上传APK到后端"""
    # 检查文件是否存在
    if not os.path.exists(APK_PATH):
        print(f"[ERROR] APK file not found: {APK_PATH}")
        sys.exit(1)

    # 获取文件大小
    file_size = os.path.getsize(APK_PATH)
    file_size_mb = file_size / (1024 * 1024)

    print(f"[INFO] Preparing to upload APK...")
    print(f"   Version: {VERSION} (code: {VERSION_CODE})")
    print(f"   File: {APK_PATH}")
    print(f"   Size: {file_size_mb:.1f} MB")
    print(f"   Target: {API_URL}")
    print()

    # 准备上传
    headers = {
        'X-API-TOKEN': API_TOKEN
    }

    files = {
        'file': open(APK_PATH, 'rb')
    }

    data = {
        'version': VERSION,
        'version_code': str(VERSION_CODE),
        'changelog': CHANGELOG,
        'force_update': 'false'
    }

    try:
        print("[INFO] Uploading...")
        response = requests.post(API_URL, headers=headers, files=files, data=data)

        # 关闭文件
        files['file'].close()

        # 检查响应
        if response.status_code == 200:
            result = response.json()
            print("[SUCCESS] Upload completed!")
            print()
            print("Version Info:")
            print(f"   ID: {result.get('id')}")
            print(f"   Version: {result.get('version')}")
            print(f"   Version Code: {result.get('version_code')}")
            print(f"   Download URL: {result.get('download_url')}")
            print(f"   File Size: {result.get('file_size_mb', 0)} MB")
            print()
            print("Changelog:")
            print(f"   {result.get('changelog', '')}")
            print()
            print("[SUCCESS] Novel App release completed!")
        else:
            print(f"[ERROR] Upload failed: HTTP {response.status_code}")
            print(f"   Response: {response.text}")
            sys.exit(1)

    except requests.exceptions.ConnectionError:
        print("[ERROR] Connection failed: Cannot connect to backend server")
        print(f"   Please ensure backend is running: {API_URL}")
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] Upload failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    upload_apk()
