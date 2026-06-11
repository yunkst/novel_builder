#!/usr/bin/env python3
"""
Novel App 自动打包并上传脚本

此脚本自动化执行以下操作：
1. 从 pubspec.yaml 读取版本信息
2. 分析 git diff 生成更新日志
3. 构建 Flutter APK (release)
4. 上传 APK 到后端服务器
5. 自动提交代码到 git
"""

import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional

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


def run_git_command(args: list[str], cwd: Path) -> tuple[int, str]:
    """
    执行 git 命令并处理 Windows 编码问题

    Args:
        args: git 命令参数列表
        cwd: 工作目录

    Returns:
        (return_code, output) 元组
    """
    result = subprocess.run(
        args,
        cwd=cwd,
        capture_output=True,
        shell=True if os.name == "nt" else False,
    )

    # 尝试 UTF-8 解码，失败则使用 GBK（Windows 中文环境）
    try:
        stdout = result.stdout.decode("utf-8")
    except UnicodeDecodeError:
        try:
            stdout = result.stdout.decode("gbk", errors="ignore")
        except:
            stdout = ""

    try:
        stderr = result.stderr.decode("utf-8")
    except UnicodeDecodeError:
        try:
            stderr = result.stderr.decode("gbk", errors="ignore")
        except:
            stderr = ""

    return result.returncode, stdout, stderr


def analyze_git_changes(project_root: Path) -> str:
    """
    分析 git 变更生成更新日志

    Args:
        project_root: 项目根目录

    Returns:
        生成的更新日志
    """
    print("正在分析代码变更...")

    # 获取 novel_app 目录的变更文件列表
    returncode, stdout, stderr = run_git_command(
        ["git", "diff", "--name-only", "novel_app/lib"],
        project_root,
    )

    if returncode != 0:
        print("无法获取 git 变更，使用默认更新日志")
        return "Bug修复和性能优化"

    changed_files = stdout.strip().split("\n") if stdout.strip() else []
    changed_files = [f for f in changed_files if f]  # 过滤空字符串

    if not changed_files:
        return "Bug修复和性能优化"

    # 按模块分类变更
    changes_by_category = {
        "screens": [],
        "widgets": [],
        "services": [],
        "providers": [],
        "repositories": [],
        "models": [],
        "其他": [],
    }

    for file_path in changed_files:
        if "screens/" in file_path:
            changes_by_category["screens"].append(file_path)
        elif "widgets/" in file_path:
            changes_by_category["widgets"].append(file_path)
        elif "services/" in file_path:
            changes_by_category["services"].append(file_path)
        elif "providers/" in file_path:
            changes_by_category["providers"].append(file_path)
        elif "repositories/" in file_path:
            changes_by_category["repositories"].append(file_path)
        elif "models/" in file_path:
            changes_by_category["models"].append(file_path)
        else:
            changes_by_category["其他"].append(file_path)

    # 分析具体文件变更获取更详细的信息
    change_descriptions = []

    # 检查关键文件的变更
    for file_path in changed_files:
        # 获取该文件的 diff
        returncode, diff_content, _ = run_git_command(
            ["git", "diff", file_path],
            project_root,
        )

        if returncode == 0 and diff_content:
            # 分析 diff 内容提取关键变更
            # 检查是否添加了新功能
            if " Future<void> _edit" in diff_content or "Future<void> _show" in diff_content:
                if "编辑书名" in diff_content:
                    change_descriptions.append("新增编辑书名功能")
                elif "刷新确认" in diff_content:
                    change_descriptions.append("优化刷新确认对话框")
                elif "下载" in diff_content and "Token" in diff_content:
                    change_descriptions.append("修复应用更新下载认证问题")

            # 检查 API Token 相关修复
            if "X-API-TOKEN" in diff_content or "api_token" in diff_content.lower():
                if "app_update_service" in file_path and "下载" in diff_content:
                    if "修复" not in change_descriptions:
                        change_descriptions.append("修复应用更新下载认证问题")

            # 检查章节列表相关
            if "chapter_list" in file_path.lower():
                if "refresh" in diff_content.lower() and "context" in diff_content:
                    if "优化刷新" not in change_descriptions:
                        change_descriptions.append("优化章节列表刷新交互")

    # 如果没有从 diff 分析出具体变更，使用基于文件分类的通用描述
    if not change_descriptions:
        if changes_by_category["services"]:
            change_descriptions.append("服务层优化")
        if changes_by_category["screens"]:
            change_descriptions.append("界面功能增强")
        if changes_by_category["providers"]:
            change_descriptions.append("状态管理优化")

    # 组合最终的更新日志
    if change_descriptions:
        # 去重并限制数量
        unique_descriptions = list(dict.fromkeys(change_descriptions))[:4]
        changelog = "、".join(unique_descriptions)
    else:
        changelog = "Bug修复和性能优化"

    print(f"生成的更新日志: {changelog}")
    return changelog


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
        shell=True if os.name == "nt" else False,
    )

    # 处理输出编码
    try:
        stdout = result.stdout.decode("utf-8")
    except UnicodeDecodeError:
        stdout = result.stdout.decode("gbk", errors="ignore")

    try:
        stderr = result.stderr.decode("utf-8")
    except UnicodeDecodeError:
        stderr = result.stderr.decode("gbk", errors="ignore")

    if result.returncode != 0:
        print("构建失败!")
        print("STDOUT:", stdout)
        print("STDERR:", stderr)
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

    # 检查文件是否存在
    if not apk_path.exists():
        raise FileNotFoundError(f"APK文件不存在: {apk_path}")

    # 检查文件大小
    file_size = apk_path.stat().st_size
    print(f"文件大小: {file_size / 1024 / 1024:.2f} MB")

    # 准备文件和数据（使用文件对象，而非直接读取bytes）
    with open(apk_path, "rb") as f:
        files = {
            "file": (
                f"novel_app_v{version}.apk",
                f.read(),
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


def commit_changes(project_root: Path, version: str, changelog: str) -> bool:
    """
    提交代码变更到 git 并创建 tag

    Args:
        project_root: 项目根目录
        version: 版本号
        changelog: 更新日志

    Returns:
        是否成功提交
    """
    print("-" * 50)
    print("正在提交代码变更...")

    tag_name = f"v{version}"

    try:
        # 添加所有变更文件
        print("添加变更文件...")
        subprocess.run(
            ["git", "add", "."],
            cwd=project_root,
            capture_output=True,
            shell=True if os.name == "nt" else False,
            check=True,
        )

        # 生成 commit 消息
        commit_msg = f"chore: 发布版本 {version}\n\n{changelog}"
        print(f"提交消息: {commit_msg}")

        # 执行提交
        result = subprocess.run(
            ["git", "commit", "-m", commit_msg],
            cwd=project_root,
            capture_output=True,
            shell=True if os.name == "nt" else False,
        )

        # 处理输出编码
        try:
            stdout = result.stdout.decode("utf-8")
        except UnicodeDecodeError:
            stdout = result.stdout.decode("gbk", errors="ignore")

        if result.returncode == 0:
            print("代码提交成功!")
            print(f"提交信息:\n{stdout}")
        elif "nothing to commit" in stdout.lower():
            print("没有需要提交的代码变更")
        else:
            print("代码提交失败:")
            print(stdout)
            return False

        # 创建 git tag
        print(f"\n创建版本标签: {tag_name}")
        tag_result = subprocess.run(
            ["git", "tag", "-a", tag_name, "-m", f"Release {version}\n\n{changelog}"],
            cwd=project_root,
            capture_output=True,
            shell=True if os.name == "nt" else False,
        )

        if tag_result.returncode == 0:
            print(f"标签 {tag_name} 创建成功!")
        else:
            # tag 可能已存在
            try:
                tag_stderr = tag_result.stderr.decode("utf-8")
            except UnicodeDecodeError:
                tag_stderr = tag_result.stderr.decode("gbk", errors="ignore")
            if "already exists" in tag_stderr.lower():
                print(f"标签 {tag_name} 已存在，跳过")
            else:
                print(f"创建标签失败: {tag_stderr}")
                # tag 创建失败不阻塞整体流程
        return True

    except subprocess.CalledProcessError as e:
        print(f"Git 命令执行失败: {e}")
        return False
    except Exception as e:
        print(f"提交代码时出错: {e}")
        return False


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

    # 2. 分析代码变更生成更新日志
    changelog_env = os.getenv("CHANGELOG", None)
    if changelog_env:
        changelog = changelog_env
        print(f"使用环境变量中的更新日志: {changelog}")
    else:
        changelog = analyze_git_changes(project_root)
    print(f"更新日志: {changelog}")
    print("-" * 50)

    # 3. 构建 APK
    apk_path = build_flutter_apk(project_root)
    print("-" * 50)

    # 4. 上传到后端
    # 从环境变量读取配置（已在load_env_file中加载.env文件）
    api_url = os.getenv("NOVEL_API_URL", "http://localhost:3800")
    api_token = os.getenv("NOVEL_API_TOKEN", "")

    if not api_token:
        print("错误: 未找到 NOVEL_API_TOKEN")
        print("请在项目根目录的 .env 文件中设置: NOVEL_API_TOKEN=your_token")
        sys.exit(1)

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

    # 5. 提交代码变更
    commit_success = commit_changes(project_root, version, changelog)

    print("-" * 50)
    print("Complete! Release successful!")
    print(f"Version {version} (code: {version_code}) has been uploaded.")
    print(f"Download URL: {api_url}/api/app-version/download/{version}")

    if commit_success:
        print("\n提示: 代码已提交到本地仓库，如需推送到远程请执行:")
        print(f"  git push")
        print(f"  git push origin {tag_name}")


if __name__ == "__main__":
    main()
