#!/usr/bin/env python3
"""
Novel App 自动打包并上传脚本

此脚本自动化执行以下操作：
1. 从 pubspec.yaml 读取版本信息
2. 构建 Flutter APK (release)
3. 上传 APK 到后端服务器
4. 报告上传结果
"""

import os
import re
import subprocess
import sys
from pathlib import Path

import requests


def load_env_file(project_root: Path) -> dict[str, str]:
    """
    加载 .env 文件到环境变量

    Args:
        project_root: 项目根目录

    Returns:
        环境变量字典
    """
    env_vars = {}
    env_file = project_root / ".env"

    if env_file.exists():
        print(f"加载环境变量: {env_file}")
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                # 跳过注释和空行
                if not line or line.startswith("#"):
                    continue
                # 解析 KEY=VALUE 格式
                if "=" in line:
                    key, value = line.split("=", 1)
                    env_vars[key.strip()] = value.strip()
                    # 同时设置到 os.environ
                    os.environ[key.strip()] = value.strip()

    return env_vars


def get_project_root() -> Path:
    """获取项目根目录（包含此脚本的目录的上五级）"""
    # 脚本位置: .claude/skills/novel-app-release/scripts/build_and_upload.py
    # 需要向上5级到达项目根目录
    return Path(__file__).parent.parent.parent.parent.parent.resolve()


def get_flutter_version(project_root: Path) -> tuple[str, int]:
    """
    从 pubspec.yaml 读取版本信息

    Returns:
        (version_name, version_code) 例如: ("1.0.1", 2)
    """
    pubspec_path = project_root / "novel_app" / "pubspec.yaml"

    if not pubspec_path.exists():
        raise FileNotFoundError(f"找不到 pubspec.yaml: {pubspec_path}")

    content = pubspec_path.read_text(encoding="utf-8")

    # 解析版本行，格式: version: 1.0.1+2
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)', content, re.MULTILINE)
    if not match:
        raise ValueError("无法从 pubspec.yaml 解析版本号")

    version_name = match.group(1)
    version_code = int(match.group(2))

    return version_name, version_code


def build_flutter_apk(project_root: Path) -> Path:
    """
    构建 Flutter APK (release)

    Args:
        project_root: 项目根目录

    Returns:
        APK文件路径
    """
    novel_app_dir = project_root / "novel_app"

    print("正在构建 Flutter APK (release)...")
    print(f"工作目录: {novel_app_dir}")

    # Windows下需要shell=True来查找flutter命令
    result = subprocess.run(
        ["flutter", "build", "apk", "--release"],
        cwd=novel_app_dir,
        capture_output=True,
        text=True,
        shell=True if os.name == "nt" else False,
    )

    if result.returncode != 0:
        print("构建失败!")
        print("STDOUT:", result.stdout)
        print("STDERR:", result.stderr)
        raise RuntimeError("Flutter APK 构建失败")

    print("构建成功!")

    # APK 文件路径
    apk_path = (
        novel_app_dir
        / "build"
        / "app"
        / "outputs"
        / "flutter-apk"
        / "app-release.apk"
    )

    if not apk_path.exists():
        raise FileNotFoundError(f"找不到生成的APK文件: {apk_path}")

    print(f"APK 文件: {apk_path}")
    return apk_path


def upload_to_backend(
    apk_path: Path,
    version: str,
    version_code: int,
    api_url: str,
    api_token: str,
    changelog: str | None = None,
    force_update: bool = False,
) -> dict:
    """
    上传APK到后端服务器

    Args:
        apk_path: APK文件路径
        version: 版本号
        version_code: 版本递增码
        api_url: 后端API地址
        api_token: API认证令牌
        changelog: 更新日志（可选）
        force_update: 是否强制更新（默认false）

    Returns:
        服务器响应
    """
    upload_url = f"{api_url}/api/app-version/upload"

    print(f"正在上传到: {upload_url}")
    print(f"版本: {version} (code: {version_code})")

    # 准备文件和数据
    files = {
        "file": (
            f"novel_app_v{version}.apk",
            apk_path.read_bytes(),
            "application/vnd.android.package-archive",
        )
    }

    data = {
        "version": version,
        "version_code": str(version_code),
        "changelog": changelog or "",
        "force_update": "true" if force_update else "false",
    }

    headers = {
        "X-API-TOKEN": api_token,
    }

    # 发送请求
    response = requests.post(upload_url, files=files, data=data, headers=headers, timeout=300)

    if response.status_code != 200:
        print(f"上传失败! HTTP {response.status_code}")
        print(f"响应: {response.text}")
        raise RuntimeError(f"上传失败: {response.status_code}")

    result = response.json()
    print("上传成功!")
    print(f"下载URL: {result.get('download_url')}")
    print(f"文件大小: {result.get('file_size')} bytes")

    return result


def main():
    """主函数"""
    # 获取项目根目录
    project_root = get_project_root()
    print(f"项目根目录: {project_root}")
    print("-" * 50)

    # 加载 .env 文件
    load_env_file(project_root)

    # 1. 读取版本信息
    version, version_code = get_flutter_version(project_root)
    print(f"版本: {version} (version_code: {version_code})")
    print("-" * 50)

    # 2. 构建 APK
    apk_path = build_flutter_apk(project_root)
    print("-" * 50)

    # 3. 上传到后端
    # 从环境变量读取配置（已在load_env_file中加载.env文件）
    api_url = os.getenv("NOVEL_API_URL", "http://localhost:3800")
    api_token = os.getenv("NOVEL_API_TOKEN", "")

    if not api_token:
        print("错误: 未找到 NOVEL_API_TOKEN")
        print("请在项目根目录的 .env 文件中设置: NOVEL_API_TOKEN=your_token")
        sys.exit(1)

    changelog = os.getenv("CHANGELOG", None)
    force_update = os.getenv("FORCE_UPDATE", "false").lower() == "true"

    upload_to_backend(
        apk_path=apk_path,
        version=version,
        version_code=version_code,
        api_url=api_url,
        api_token=api_token,
        changelog=changelog,
        force_update=force_update,
    )

    print("-" * 50)
    print("完成! 🎉")


if __name__ == "__main__":
    main()
