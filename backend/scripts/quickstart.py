#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
快速启动脚本 - 一键设置开发环境
"""

import os
import sys
import subprocess
import json
from pathlib import Path


def run_command(command: str, check: bool = True) -> subprocess.CompletedProcess:
    """运行shell命令"""
    print(f"🔧 执行命令: {command}")
    result = subprocess.run(
        command,
        shell=True,
        capture_output=True,
        text=True,
        check=check
    )
    if result.stdout:
        print(result.stdout)
    if result.stderr and result.returncode != 0:
        print(f"❌ 错误: {result.stderr}")
    return result


def check_python_version():
    """检查Python版本"""
    print("🐍 检查Python版本...")
    version = sys.version_info
    if version.major != 3 or version.minor < 11:
        print(f"❌ 需要Python 3.11+，当前版本: {version.major}.{version.minor}")
        sys.exit(1)
    print(f"✅ Python版本: {version.major}.{version.minor}.{version.micro}")


def setup_virtual_environment():
    """设置虚拟环境"""
    print("📦 设置虚拟环境...")

    if not Path("venv").exists():
        print("创建虚拟环境...")
        run_command(f"{sys.executable} -m venv venv")

    # 激活虚拟环境
    if os.name == 'nt':  # Windows
        pip_path = "venv/Scripts/pip"
        python_path = "venv/Scripts/python"
    else:  # Unix-like
        pip_path = "venv/bin/pip"
        python_path = "venv/bin/python"

    # 升级pip
    print("升级pip...")
    run_command(f"{pip_path} install --upgrade pip")

    return pip_path, python_path


def install_dependencies(pip_path: str):
    """安装依赖"""
    print("📚 安装依赖...")

    # 检查pyproject.toml是否存在
    if not Path("pyproject.toml").exists():
        print("❌ 找不到pyproject.toml文件")
        return False

    # 安装依赖
    try:
        run_command(f"{pip_path} install -e .")
        run_command(f"{pip_path} install -e '.[dev]'")
        print("✅ 依赖安装完成")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ 依赖安装失败: {e}")
        return False


def setup_environment():
    """设置环境变量"""
    print("⚙️ 设置环境变量...")

    env_file = Path(".env")
    env_example = Path(".env.example")

    if not env_file.exists() and env_example.exists():
        print("复制环境变量模板...")
        env_file.write_text(env_example.read_text())
        print("✅ 已创建.env文件，请根据需要修改")
    elif env_file.exists():
        print("✅ .env文件已存在")
    else:
        print("⚠️ 没有找到.env.example文件")
        # 创建基本的环境变量文件
        basic_env = """# Novel Builder Backend - Environment Configuration

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
API_RELOAD=false

# Security
SECRET_KEY=your-secret-key-here-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Novel API Settings
NOVEL_API_TOKEN=your-novel-api-token-here
NOVEL_ENABLED_SITES=alice_sw,shukuge

# Development Settings
DEBUG=false
LOG_LEVEL=INFO

# CORS Settings
ALLOWED_ORIGINS=*
"""
        env_file.write_text(basic_env)
        print("✅ 已创建基本.env文件")


def setup_pre_commit(python_path: str):
    """设置pre-commit钩子"""
    print("🪝 设置pre-commit钩子...")

    if not Path(".pre-commit-config.yaml").exists():
        print("⚠️ 没有找到.pre-commit-config.yaml文件")
        return False

    try:
        run_command(f"{python_path} -m pre_commit install")
        print("✅ pre-commit钩子设置完成")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ pre-commit设置失败: {e}")
        return False


def run_code_checks(python_path: str):
    """运行代码检查"""
    print("🔍 运行代码检查...")

    checks = [
        ("代码格式检查", f"{python_path} -m ruff format --check ."),
        ("代码质量检查", f"{python_path} -m ruff check ."),
        ("类型检查", f"{python_path} -m mypy app/"),
    ]

    all_passed = True
    for name, command in checks:
        print(f"\n📋 {name}...")
        try:
            result = run_command(command, check=False)
            if result.returncode == 0:
                print(f"✅ {name}通过")
            else:
                print(f"❌ {name}失败")
                all_passed = False
        except Exception as e:
            print(f"❌ {name}执行出错: {e}")
            all_passed = False

    return all_passed


def run_tests(python_path: str):
    """运行测试"""
    print("🧪 运行测试...")

    if not Path("tests").exists():
        print("⚠️ 没有找到tests目录")
        return True

    try:
        result = run_command(f"{python_path} -m pytest tests/ -v", check=False)
        if result.returncode == 0:
            print("✅ 所有测试通过")
            return True
        else:
            print("❌ 部分测试失败")
            return False
    except Exception as e:
        print(f"❌ 测试执行出错: {e}")
        return False


def start_server(python_path: str):
    """启动开发服务器"""
    print("🚀 启动开发服务器...")

    # 检查端口是否被占用
    import socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result = sock.connect_ex(('localhost', 8000))
    sock.close()

    if result == 0:
        print("⚠️ 端口8000已被占用，请检查是否已有服务在运行")
        return

    print("启动服务器...")
    print("📍 API地址: http://localhost:8000")
    print("📖 API文档: http://localhost:8000/docs")
    print("🔄 按Ctrl+C停止服务器")
    print()

    try:
        # 使用uvicorn启动服务器
        os.system(f"{python_path} -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000")
    except KeyboardInterrupt:
        print("\n👋 服务器已停止")


def check_requirements():
    """检查系统要求"""
    print("🔍 检查系统要求...")

    # 检查Python
    check_python_version()

    # 检查pip
    try:
        import pip
        print("✅ pip可用")
    except ImportError:
        print("❌ pip不可用")
        sys.exit(1)

    # 检查Git
    try:
        result = run_command("git --version", check=False)
        if result.returncode == 0:
            print("✅ Git可用")
        else:
            print("⚠️ Git不可用，但不影响基本功能")
    except:
        print("⚠️ Git不可用，但不影响基本功能")


def main():
    """主函数"""
    print("🚀 Novel Builder Backend 快速启动")
    print("=" * 50)

    # 检查系统要求
    check_requirements()
    print()

    # 设置虚拟环境
    pip_path, python_path = setup_virtual_environment()
    print()

    # 安装依赖
    if not install_dependencies(pip_path):
        print("❌ 依赖安装失败，无法继续")
        sys.exit(1)
    print()

    # 设置环境变量
    setup_environment()
    print()

    # 设置pre-commit
    setup_pre_commit(python_path)
    print()

    # 询问是否运行代码检查
    choice = input("是否运行代码检查? (y/n): ").strip().lower()
    if choice in ['y', 'yes', '是']:
        if not run_code_checks(python_path):
            print("⚠️ 代码检查未完全通过，但可以继续开发")
        print()

    # 询问是否运行测试
    choice = input("是否运行测试? (y/n): ").strip().lower()
    if choice in ['y', 'yes', '是']:
        if not run_tests(python_path):
            print("⚠️ 部分测试失败，但可以继续开发")
        print()

    # 询问是否启动服务器
    choice = input("是否启动开发服务器? (y/n): ").strip().lower()
    if choice in ['y', 'yes', '是']:
        start_server(python_path)
    else:
        print("\n✅ 开发环境设置完成!")
        print("💡 手动启动服务器: make run")
        print("💡 运行测试: make test")
        print("💡 代码检查: make check-all")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n👋 用户中断，程序退出")
    except Exception as e:
        print(f"\n❌ 程序出错: {e}")
        sys.exit(1)