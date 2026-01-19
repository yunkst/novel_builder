#!/usr/bin/env python3
"""
Backend API变更检测工具

检查backend API相关文件的变更，判断是否需要重新生成Flutter API客户端代码。

使用方式：
  python scripts/check_api_changes.py

输出：
  - 如果检测到API变更，提示运行生成脚本
  - 显示变更的文件和类型
"""

import os
import subprocess
import sys
from pathlib import Path
from datetime import datetime, timedelta


def get_git_tracked_files(directory: Path, file_patterns: list[str]) -> list[Path]:
    """获取git跟踪的特定模式文件"""
    try:
        result = subprocess.run(
            ["git", "ls-files", *file_patterns],
            cwd=directory,
            capture_output=True,
            text=True,
            check=True,
        )
        if result.stdout:
            return [directory / line.strip() for line in result.stdout.split("\n") if line.strip()]
    except subprocess.CalledProcessError:
        pass
    return []


def get_file_modification_time(file_path: Path) -> float:
    """获取文件修改时间"""
    if file_path.exists():
        return file_path.stat().st_mtime
    return 0


def check_api_files(project_root: Path, since_hours: float = 1) -> dict[str, list[Path]]:
    """
    检查最近修改的API文件

    Args:
        project_root: 项目根目录
        since_hours: 检查最近几小时内修改的文件

    Returns:
        按类型分类的变更文件列表
    """
    backend_dir = project_root / "backend"
    changes = {
        "api_routes": [],
        "schemas": [],
        "models": [],
        "services": [],
    }

    if not backend_dir.exists():
        print(f"WARNING Backend directory does not exist: {backend_dir}")
        return changes

    # 检查的文件模式
    patterns = {
        "api_routes": "app/main.py",
        "schemas": "app/schemas.py",
        "models": "app/models/*.py",
        "services": "app/services/*.py",
    }

    cutoff_time = datetime.now() - timedelta(hours=since_hours)

    for category, pattern in patterns.items():
        # 使用glob查找文件
        if "*" in pattern:
            files = list((backend_dir / pattern).parent.glob(pattern.split("/")[-1]))
        else:
            file_path = backend_dir / pattern
            files = [file_path] if file_path.exists() else []

        for file_path in files:
            mtime = datetime.fromtimestamp(get_file_modification_time(file_path))
            if mtime > cutoff_time:
                changes[category].append(file_path)

    return changes


def check_backend_running() -> bool:
    """检查后端服务是否运行"""
    import socket

    try:
        sock = socket.create_connection(("localhost", 3800), timeout=2)
        sock.close()
        return True
    except (socket.timeout, ConnectionRefusedError, OSError):
        return False


def format_duration(hours: float) -> str:
    """格式化时间范围"""
    if hours < 1:
        return f"last {int(hours * 60)} minutes"
    return f"last {int(hours)} hours"


def main():
    """主函数"""
    # 脚本位置: .claude/skills/regenerate-flutter-api/scripts/check_api_changes.py
    # 需要向上5级到达项目根目录
    project_root = Path(__file__).parent.parent.parent.parent.parent.resolve()

    print("=" * 60)
    print("Backend API Change Detection")
    print("=" * 60)

    # 检查最近1小时内的变更
    changes = check_api_files(project_root, since_hours=1)

    total_changes = sum(len(files) for files in changes.values())

    if total_changes == 0:
        print(f"\nOK No API file changes detected in the {format_duration(1)}")
        print("   Backend API and Flutter client may be in sync")
        return

    print(f"\nWARNING Detected {total_changes} API files modified in the {format_duration(1)}:\n")

    if changes["api_routes"]:
        print("[API Routes] Changes:")
        for file_path in changes["api_routes"]:
            print(f"   - {file_path.relative_to(project_root)}")

    if changes["schemas"]:
        print("[Schemas] Data Model Changes:")
        for file_path in changes["schemas"]:
            print(f"   - {file_path.relative_to(project_root)}")

    if changes["models"]:
        print("[Models] Data Model Changes:")
        for file_path in changes["models"]:
            print(f"   - {file_path.relative_to(project_root)}")

    if changes["services"]:
        print("[Services] Business Service Changes:")
        for file_path in changes["services"]:
            print(f"   - {file_path.relative_to(project_root)}")

    print("\nSuggested Actions:")

    if check_backend_running():
        print("   OK Backend service is running")
        print("\n   Run the following command to regenerate Flutter API client:")
        print("   " + "-" * 56)
        print("   cd novel_app")
        print("   dart run tool/generate_api.dart")
        print("   " + "-" * 56)
    else:
        print("   WARNING Backend service not running (localhost:3800)")
        print("\n   Please start the backend service first, then run:")
        print("   " + "-" * 56)
        print("   # Terminal 1: Start backend")
        print("   cd backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 3800")
        print("\n   # Terminal 2: Generate API client")
        print("   cd novel_app && dart run tool/generate_api.dart")
        print("   " + "-" * 56)

    print("\nFor more info: .claude/skills/regenerate-flutter-api/")


if __name__ == "__main__":
    main()
