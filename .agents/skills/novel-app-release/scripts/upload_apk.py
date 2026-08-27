#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
上传APK到后端服务器
使用Python requests库避免Windows下curl的UTF-8编码问题
"""

import requests
import os
import sys
import re
import yaml
from pathlib import Path

# 设置标准输出编码为UTF-8
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

# 配置
API_URL = "http://localhost:3800/api/app-version/upload"
API_TOKEN = "test_token_123"

# APK文件路径
APK_PATH = "../../../../novel_app/build/app/outputs/flutter-apk/app-release.apk"

# 从 pubspec.yaml 读取版本信息
def read_version_from_pubspec():
    """从 pubspec.yaml 读取版本信息"""
    # 使用当前工作目录定位项目
    import os
    cwd = Path(os.getcwd())
    pubspec_path = cwd / "novel_app" / "pubspec.yaml"

    # 如果当前不在项目根目录，尝试向上查找
    if not pubspec_path.exists():
        # 假设在 novel_app 目录下运行
        pubspec_path = cwd / "pubspec.yaml"

    if not pubspec_path.exists():
        print(f"[错误] pubspec.yaml 不存在: {pubspec_path}")
        print(f"[提示] 当前工作目录: {cwd}")
        sys.exit(1)

    with open(pubspec_path, 'r', encoding='utf-8') as f:
        content = f.read()
        # 查找 version: 行
        match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)', content, re.MULTILINE)
        if match:
            version = match.group(1)
            version_code = int(match.group(2))
            return version, version_code
        else:
            print("[错误] 无法从 pubspec.yaml 解析版本号")
            sys.exit(1)

VERSION, VERSION_CODE = read_version_from_pubspec()

# 更新日志
CHANGELOG = """✨ UI优化:
- 优化章节列表页面布局
- 将大纲管理、背景设定、AI伴读设置移入更多菜单
- 移除右下角浮动按钮，增加内容显示区域

📱 用户体验改进:
- AppBar 按钮从6个减少到4个，界面更简洁
- 所有设置类功能统一在更多菜单中"""

FORCE_UPDATE = "false"


def upload_apk():
    """上传APK到后端"""

    # 检查APK文件是否存在
    apk_path = Path(__file__).parent / APK_PATH
    apk_path = apk_path.resolve()

    if not apk_path.exists():
        print(f"[错误] APK文件不存在: {apk_path}")
        sys.exit(1)

    print(f"[准备上传APK]")
    print(f"  版本: {VERSION} (版本码: {VERSION_CODE})")
    print(f"  文件: {apk_path}")
    print(f"  大小: {apk_path.stat().st_size / 1024 / 1024:.2f} MB")
    print()

    # 准备上传
    url = API_URL
    headers = {
        'X-API-TOKEN': API_TOKEN
    }

    # 准备数据和文件
    data = {
        'version': VERSION,
        'version_code': str(VERSION_CODE),
        'changelog': CHANGELOG,
        'force_update': FORCE_UPDATE
    }

    files = {
        'file': open(apk_path, 'rb')
    }

    print("[开始上传]")

    try:
        # 发送请求
        response = requests.post(url, headers=headers, files=files, data=data)

        # 关闭文件
        files['file'].close()

        # 检查响应
        if response.status_code == 200:
            result = response.json()
            print("[上传成功]")
            print()
            print("[返回信息]")
            print(f"  ID: {result.get('id')}")
            print(f"  版本: {result.get('version')}")
            print(f"  版本码: {result.get('version_code')}")
            print(f"  文件大小: {result.get('file_size')} bytes")
            print(f"  强制更新: {result.get('force_update')}")
            print(f"  创建时间: {result.get('created_at')}")
            print()
            print("[发布完成]")
            return True
        else:
            print(f"[上传失败] HTTP {response.status_code}")
            print(f"  响应: {response.text}")
            return False

    except Exception as e:
        print(f"[上传异常] {e}")
        return False


if __name__ == "__main__":
    success = upload_apk()
    sys.exit(0 if success else 1)
