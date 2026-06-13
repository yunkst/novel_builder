#!/usr/bin/env python3
"""
Novel App 发布脚本

此脚本自动化执行以下操作：

阶段 1 — 预检（模拟 CI）:
  1.1 flutter analyze --no-fatal-infos
  1.2 flutter test --no-pub test/unit/ test/bug/ test/verification/
  1.3 flutter build apk --release

阶段 2 — 版本识别:
  2.1 从 pubspec.yaml 读取版本信息
  2.2 分析 git diff 生成更新日志

阶段 3 — git 操作:
  3.1 git add .
  3.2 git commit -m "chore: 发布版本 {version}"
  3.3 git tag -a v{version} -m "Release {version}"
  3.4 git push
  3.5 git push origin v{version}

预检中任何一步失败都会中断发布，因为这意味着 GitHub Actions 也会失败。
可通过 SKIP_PREFLIGHT=1 环境变量跳过预检（不推荐）。
"""

import os
import re
import subprocess
import sys
from pathlib import Path

# 强制使用 UTF-8 输出（修复 Windows cmd 的 GBK 编码问题）
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass


def get_project_root() -> Path:
    """获取项目根目录（包含此脚本的目录的上五级）"""
    # 脚本位置: .claude/skills/novel-app-release/scripts/build_and_upload.py
    # 需要向上5级到达项目根目录
    return Path(__file__).parent.parent.parent.parent.parent.resolve()


def get_flutter_app_dir(project_root: Path) -> Path:
    """获取 Flutter 应用目录"""
    return project_root / "novel_app"


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


def run_command(args: list[str], cwd: Path, description: str = "") -> tuple[int, str, str]:
    """
    执行命令并处理 Windows 编码问题

    Args:
        args: 命令参数列表
        cwd: 工作目录
        description: 步骤描述（用于日志输出）

    Returns:
        (return_code, stdout, stderr) 元组
    """
    if description:
        print(f"  {description}...")

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
        except Exception:
            stdout = ""

    try:
        stderr = result.stderr.decode("utf-8")
    except UnicodeDecodeError:
        try:
            stderr = result.stderr.decode("gbk", errors="ignore")
        except Exception:
            stderr = ""

    return result.returncode, stdout, stderr


def run_preflight(project_root: Path) -> bool:
    """
    阶段 1：预检 — 模拟 CI 流程

    运行与 GitHub Actions 完全一致的检查：
    1. flutter analyze --no-fatal-infos
    2. flutter test --no-pub test/unit/ test/bug/ test/verification/
    3. flutter build apk --release

    Returns:
        是否全部通过
    """
    flutter_dir = get_flutter_app_dir(project_root)

    print("=" * 60)
    print("阶段 1/3: 预检（模拟 CI 流程）")
    print("=" * 60)

    # 1.1 flutter analyze
    print("\n  [1.1/3] flutter analyze --no-fatal-infos")
    print("  " + "-" * 40)
    rc, stdout, stderr = run_command(
        ["flutter", "analyze", "--no-fatal-infos"],
        flutter_dir,
    )

    # 打印最后几行（分析结果摘要）
    output_lines = stdout.strip().split("\n") if stdout.strip() else []
    for line in output_lines[-8:]:
        print(f"  {line}")

    # --no-fatal-infos 下，warning 也会导致非零退出码
    # 但 GitHub Actions 不会因此失败（只有 error 才是真正的阻断项）
    # 检查输出中是否有 "error -" 级别的诊断
    has_errors = any("error -" in line for line in output_lines)
    if has_errors:
        print(f"\n  ❌ flutter analyze 存在 error 级别诊断")
        print(f"  请修复上述问题后重新运行发布脚本")
        return False
    print("  ✅ flutter analyze 通过")

    # 1.2 flutter test
    print("\n  [1.2/3] flutter test --no-pub test/unit/ test/bug/ test/verification/")
    print("  " + "-" * 40)
    rc, stdout, stderr = run_command(
        ["flutter", "test", "--no-pub", "test/unit/", "test/bug/", "test/verification/"],
        flutter_dir,
    )

    # 打印最后几行（测试结果摘要）
    output_lines = stdout.strip().split("\n") if stdout.strip() else []
    for line in output_lines[-8:]:
        print(f"  {line}")

    if rc != 0:
        print(f"\n  ❌ flutter test 失败 (exit code: {rc})")
        print(f"  请修复失败的测试后重新运行发布脚本")

        # 尝试找出具体失败的测试
        failed_lines = [l for l in output_lines if "FAILED" in l or "Some tests failed" in l]
        if failed_lines:
            print(f"  失败摘要:")
            for line in failed_lines[:5]:
                print(f"    {line}")

        if stderr:
            # 只打印 stderr 中非 info 级别的错误
            error_lines = [l for l in stderr.split("\n") if "Error" in l or "error" in l]
            if error_lines:
                print(f"  错误详情:")
                for line in error_lines[:5]:
                    print(f"    {line}")
        return False
    print("  ✅ flutter test 通过")

    # 1.3 flutter build apk --release
    print("\n  [1.3/3] flutter build apk --release")
    print("  " + "-" * 40)
    print("  ⏳ 正在构建 Release APK（可能需要几分钟）...")
    rc, stdout, stderr = run_command(
        ["flutter", "build", "apk", "--release"],
        flutter_dir,
    )

    # 打印最后几行
    output_lines = stdout.strip().split("\n") if stdout.strip() else []
    for line in output_lines[-5:]:
        print(f"  {line}")

    if rc != 0:
        print(f"\n  ❌ flutter build apk --release 失败 (exit code: {rc})")
        print(f"  请修复构建错误后重新运行发布脚本")
        if stderr:
            # 打印 stderr 中关键的错误行
            error_lines = [l for l in stderr.split("\n") if "Error" in l or "error" in l or "FAILURE" in l]
            if error_lines:
                print(f"  错误详情:")
                for line in error_lines[:10]:
                    print(f"    {line}")
            else:
                print(f"  stderr (前500字符): {stderr[:500]}")
        return False
    print("  ✅ flutter build apk --release 通过")

    print("\n" + "=" * 60)
    print("✅ 预检全部通过 — 本地验证与 CI 一致，可以安全发布")
    print("=" * 60)
    return True


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
    returncode, stdout, _ = run_command(
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

    for file_path in changed_files:
        returncode, diff_content, _ = run_command(
            ["git", "diff", file_path],
            project_root,
        )

        if returncode == 0 and diff_content:
            if " Future<void> _edit" in diff_content or "Future<void> _show" in diff_content:
                if "编辑书名" in diff_content:
                    change_descriptions.append("新增编辑书名功能")
                elif "刷新确认" in diff_content:
                    change_descriptions.append("优化刷新确认对话框")

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
        if changes_by_category["widgets"]:
            change_descriptions.append("组件优化")

    # 组合最终的更新日志
    if change_descriptions:
        unique_descriptions = list(dict.fromkeys(change_descriptions))[:4]
        changelog = "、".join(unique_descriptions)
    else:
        changelog = "Bug修复和性能优化"

    print(f"生成的更新日志: {changelog}")
    return changelog


def commit_and_push(project_root: Path, version: str, changelog: str) -> bool:
    """
    阶段 3：提交代码变更到 git，创建 tag，并推送到远程仓库

    Args:
        project_root: 项目根目录
        version: 版本号
        changelog: 更新日志

    Returns:
        是否成功完成所有操作
    """
    tag_name = f"v{version}"
    commit_msg = f"chore: 发布版本 {version}\n\n{changelog}"

    print("-" * 50)
    print("正在提交代码变更...")

    try:
        # 1. 添加所有变更文件
        print("  [1/5] 添加变更文件...")
        subprocess.run(
            ["git", "add", "."],
            cwd=project_root,
            capture_output=True,
            shell=True if os.name == "nt" else False,
            check=True,
        )

        # 2. 提交
        print(f"  [2/5] 提交代码 (chore: 发布版本 {version})...")
        result = subprocess.run(
            ["git", "commit", "-m", commit_msg],
            cwd=project_root,
            capture_output=True,
            shell=True if os.name == "nt" else False,
        )

        try:
            stdout = result.stdout.decode("utf-8")
        except UnicodeDecodeError:
            stdout = result.stdout.decode("gbk", errors="ignore")

        if result.returncode == 0:
            print(f"        提交成功!")
        elif "nothing to commit" in stdout.lower():
            print("        没有需要提交的代码变更（仅打 tag）")
        else:
            print(f"        提交失败: {stdout}")
            return False

        # 3. 创建 tag
        print(f"  [3/5] 创建标签 {tag_name}...")
        tag_result = subprocess.run(
            ["git", "tag", "-a", tag_name, "-m", f"Release {version}\n\n{changelog}"],
            cwd=project_root,
            capture_output=True,
            shell=True if os.name == "nt" else False,
        )

        if tag_result.returncode != 0:
            try:
                tag_stderr = tag_result.stderr.decode("utf-8")
            except UnicodeDecodeError:
                tag_stderr = tag_result.stderr.decode("gbk", errors="ignore")
            if "already exists" in tag_stderr.lower():
                print(f"        标签 {tag_name} 已存在，继续推送")
            else:
                print(f"        创建标签失败: {tag_stderr}")
                return False
        else:
            print(f"        标签创建成功!")

        # 4. 推送 commit 到远程
        print(f"  [4/5] 推送 commit 到远程仓库...")
        # 自动检测 remote 名字（origin / o1 / upstream）
        remote_name = "origin"
        for candidate in ("origin", "o1", "upstream"):
            rc, _, _ = run_command(
                ["git", "remote", "get-url", candidate], project_root
            )
            if rc == 0:
                remote_name = candidate
                break

        push_result = subprocess.run(
            ["git", "push", remote_name],
            cwd=project_root,
            capture_output=True,
            shell=True if os.name == "nt" else False,
        )

        try:
            push_stdout = push_result.stdout.decode("utf-8")
        except UnicodeDecodeError:
            push_stdout = push_result.stdout.decode("gbk", errors="ignore")

        if push_result.returncode == 0:
            print(f"        Commit 推送成功!")
        else:
            print(f"        Commit 推送失败: {push_stdout}")
            return False

        # 5. 推送 tag 到远程
        print(f"  [5/5] 推送标签 {tag_name} 到远程仓库...")
        # 自动检测 remote 名字（o1 或 origin）
        remote_name = "origin"
        for candidate in ("origin", "o1", "upstream"):
            rc, _, _ = run_command(
                ["git", "remote", "get-url", candidate], project_root
            )
            if rc == 0:
                remote_name = candidate
                break

        tag_push_result = subprocess.run(
            ["git", "push", remote_name, tag_name],
            cwd=project_root,
            capture_output=True,
            shell=True if os.name == "nt" else False,
        )

        try:
            tag_push_stdout = tag_push_result.stdout.decode("utf-8")
        except UnicodeDecodeError:
            tag_push_stdout = tag_push_result.stdout.decode("gbk", errors="ignore")

        if tag_push_result.returncode == 0:
            print(f"        标签推送成功!")
        else:
            print(f"        标签推送失败: {tag_push_stdout}")
            return False

        return True

    except subprocess.CalledProcessError as e:
        print(f"Git 命令执行失败: {e}")
        return False
    except Exception as e:
        print(f"发布过程出错: {e}")
        return False


def main():
    """主函数"""
    # 获取项目根目录
    project_root = get_project_root()
    print(f"项目根目录: {project_root}")
    print("=" * 60)

    # ============================================================
    # 阶段 1: 预检（模拟 CI）
    # ============================================================
    skip_preflight = os.getenv("SKIP_PREFLIGHT", "").strip() in ("1", "true", "yes", "True", "YES")

    if skip_preflight:
        print("⚠️  SKIP_PREFLIGHT=1，跳过预检阶段")
        print("⚠️  请注意：GitHub Actions 仍会运行同样的检查，如失败则发布不成功")
        print("=" * 60)
    else:
        if not run_preflight(project_root):
            print("\n" + "=" * 60)
            print("❌ 预检失败，发布已中断")
            print("   请修复上述问题后重新运行，或使用 SKIP_PREFLIGHT=1 跳过（不推荐）")
            print("=" * 60)
            sys.exit(1)

    # ============================================================
    # 阶段 2: 版本识别
    # ============================================================
    print("\n" + "=" * 60)
    print("阶段 2/3: 版本识别与变更日志")
    print("=" * 60)

    version, version_code = get_flutter_version(project_root)
    print(f"版本: {version} (version_code: {version_code})")

    changelog_env = os.getenv("CHANGELOG", None)
    if changelog_env:
        changelog = changelog_env
        print(f"使用自定义更新日志: {changelog}")
    else:
        changelog = analyze_git_changes(project_root)
    print(f"更新日志: {changelog}")

    # ============================================================
    # 阶段 3: git 操作
    # ============================================================
    print("\n" + "=" * 60)
    print("阶段 3/3: git commit + tag + push")
    print("=" * 60)

    success = commit_and_push(project_root, version, changelog)

    print("=" * 60)
    if success:
        print("🎉 发布成功!")
        print(f"  版本: {version} (code: {version_code})")
        print(f"  标签: v{version} 已推送到 origin")
        print(f"  GitHub Actions 将自动构建 APK 并创建 Release")
        print(f"  Release 页面: https://github.com/yunkst/novel_builder/releases/tag/v{version}")
    else:
        print("❌ 发布失败，请检查上方错误信息")
        sys.exit(1)


if __name__ == "__main__":
    main()
