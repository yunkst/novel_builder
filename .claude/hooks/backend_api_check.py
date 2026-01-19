#!/usr/bin/env python3
"""
Backend API变更检测Hook

当backend API相关文件被修改时，检查是否需要重新生成Flutter API客户端代码。

触发生成条件：
1. main.py 中的API路由定义变更
2. schemas.py 中的数据模型变更
3. models/ 或 services/ 中的业务逻辑变更

使用方式：
- 作为 Claude Code user-prompt-submit-hook 运行
- 检测到API变更时提示用户是否生成客户端代码
"""

import os
import re
import sys
from pathlib import Path

# 添加项目根目录到Python路径
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))


def detect_api_changes(file_path: str, new_content: str, old_content: str | None) -> dict[str, bool]:
    """
    检测文件中的API变更

    Args:
        file_path: 修改的文件路径
        new_content: 新文件内容
        old_content: 旧文件内容（如果存在）

    Returns:
        变更检测结果
    """
    changes = {
        "has_api_route": False,
        "has_schema": False,
        "has_model": False,
        "should_regenerate": False
    }

    file_path_lower = file_path.lower()

    # 检测main.py中的API路由变更
    if "main.py" in file_path_lower:
        # 检查是否有新的@app.xxx装饰器
        new_routes = len(re.findall(r'@app\.(get|post|put|delete|patch)', new_content))
        changes["has_api_route"] = new_routes > 0

        if old_content:
            old_routes = len(re.findall(r'@app\.(get|post|put|delete|patch)', old_content))
            changes["should_regenerate"] = new_routes != old_routes
        else:
            changes["should_regenerate"] = new_routes > 0

    # 检测schemas.py中的数据模型变更
    elif "schemas.py" in file_path_lower:
        # 检查Pydantic模型定义
        new_models = len(re.findall(r'class\s+\w+\s*\([^)]*BaseModel', new_content))
        changes["has_schema"] = new_models > 0

        if old_content:
            old_models = len(re.findall(r'class\s+\w+\s*\([^)]*BaseModel', old_content))
            changes["should_regenerate"] = new_models != old_models
        else:
            changes["should_regenerate"] = new_models > 0

    # 检测models/和services/中的变更
    elif "models" in file_path_lower or "services" in file_path_lower:
        # 检查是否有类定义或函数定义
        new_definitions = len(re.findall(r'^(class|def|async\s+def)\s+', new_content, re.MULTILINE))
        changes["has_model"] = new_definitions > 0

        if old_content:
            old_definitions = len(re.findall(r'^(class|def|async\s+def)\s+', old_content, re.MULTILINE))
            # 定义数量变化或新增/修改了关键类
            changes["should_regenerate"] = new_definitions != old_definitions
        else:
            changes["should_regenerate"] = new_definitions > 0

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


def generate_flutter_client() -> bool:
    """
    执行Flutter API客户端代码生成

    Returns:
        是否成功生成
    """
    import subprocess

    novel_app_dir = project_root / "novel_app"

    if not novel_app_dir.exists():
        print(f"❌ 找不到novel_app目录: {novel_app_dir}")
        return False

    print("\n🚀 开始生成Flutter API客户端代码...")

    try:
        # 运行生成脚本
        result = subprocess.run(
            ["dart", "run", "tool/generate_api.dart"],
            cwd=novel_app_dir,
            capture_output=True,
            text=True,
            timeout=120,
        )

        if result.returncode == 0:
            print(result.stdout)
            print("\n✅ Flutter API客户端代码生成成功！")
            return True
        else:
            print(f"\n❌ 生成失败:")
            print(result.stderr)
            return False

    except subprocess.TimeoutExpired:
        print("\n❌ 生成超时（>120秒）")
        return False
    except FileNotFoundError:
        print("\n❌ 找不到dart命令，请确保Flutter/Dart环境已安装")
        return False
    except Exception as e:
        print(f"\n❌ 生成出错: {e}")
        return False


def main():
    """主函数"""
    # 从环境变量获取文件信息（Claude Code hook会设置这些）
    file_path = os.getenv("CLAUDE_HOOK_FILE_PATH", "")
    file_content = os.getenv("CLAUDE_HOOK_FILE_CONTENT", "")

    if not file_path or not file_content:
        # 如果不是通过hook调用，直接退出
        return

    print("\n" + "=" * 60)
    print("🔍 Backend API变更检测")
    print("=" * 60)
    print(f"文件: {file_path}")

    # 检测变更
    changes = detect_api_changes(file_path, file_content, None)

    if not changes["should_regenerate"]:
        print("✅ 未检测到需要重新生成的API变更")
        return

    # 显示变更详情
    print("\n检测到以下变更:")
    if changes["has_api_route"]:
        print("  • API路由定义")
    if changes["has_schema"]:
        print("  • 数据模型(Schema)")
    if changes["has_model"]:
        print("  • 业务模型/服务")

    # 检查后端是否运行
    if not check_backend_running():
        print("\n⚠️  警告: 后端服务未运行（localhost:3800）")
        print("请先启动后端服务，然后手动运行生成命令:")
        print("  cd novel_app && dart run tool/generate_api.dart")
        return

    print("\n💡 建议: 重新生成Flutter API客户端代码")
    print("\n📋 变更的文件可能影响Flutter端的API调用")

    # 在真实场景中，这里会询问用户是否要生成
    # 但由于hook限制，我们只输出提示信息
    print("\n📝 请在保存后手动运行:")
    print("  cd novel_app && dart run tool/generate_api.dart")


if __name__ == "__main__":
    main()
