#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量替换 SnackBar 为 Toast 的脚本
"""
import re
from pathlib import Path

def get_relative_import_depth(file_path):
    """计算相对路径深度"""
    path_str = str(file_path)
    lib_index = path_str.find('\\lib\\') if '\\' in path_str else path_str.find('/lib/')
    if lib_index == -1:
        return 1

    separator = '\\' if '\\' in path_str else '/'
    after_lib = path_str[lib_index + 5:]
    depth = after_lib.count(separator)
    return max(1, depth)

def replace_snackbar_in_file(file_path):
    """替换单个文件中的 SnackBar 为 Toast"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # 匹配模式，支持多行和可选的分号
    # 模式1: 简单的 const SnackBar
    pattern1 = r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*const\s+SnackBar\(\s*content:\s*Text\(([^)]+)\)\s*\)\s*\);?"
    matches1 = list(re.finditer(pattern1, content))
    for match in reversed(matches1):  # 从后向前替换，避免位置偏移
        message = match.group(1)
        old_text = match.group(0)
        new_text = f'ToastUtils.show({message});'
        content = content[:match.start()] + new_text + content[match.end():]

    # 模式2: 简单的 SnackBar（没有 const）
    pattern2 = r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\(([^)]+)\)\s*\)\s*\);?"
    matches2 = list(re.finditer(pattern2, content))
    for match in reversed(matches2):
        message = match.group(1)
        old_text = match.group(0)
        new_text = f'ToastUtils.show({message});'
        content = content[:match.start()] + new_text + content[match.end():]

    # 模式3-5: 带颜色的 SnackBar（green, red, orange）
    for color, method in [('green', 'showSuccess'), ('red', 'showError'), ('orange', 'showWarning')]:
        # 有 const
        pattern_const = f"ScaffoldMessenger\\.of\\(context\\)\\.showSnackBar\\(\\s*const\\s+SnackBar\\(\\s*content:\\s*Text\\(([^)]+)\\),\\s*backgroundColor:\\s*Colors\\.{color}\\s*\\)\\s*\\);?"
        matches = list(re.finditer(pattern_const, content))
        for match in reversed(matches):
            message = match.group(1)
            content = content[:match.start()] + f'ToastUtils.{method}({message});' + content[match.end():]

        # 没有 const
        pattern_noconst = f"ScaffoldMessenger\\.of\\(context\\)\\.showSnackBar\\(\\s*SnackBar\\(\\s*content:\\s*Text\\(([^)]+)\\),\\s*backgroundColor:\\s*Colors\\.{color}\\s*\\)\\s*\\);?"
        matches = list(re.finditer(pattern_noconst, content))
        for match in reversed(matches):
            message = match.group(1)
            content = content[:match.start()] + f'ToastUtils.{method}({message});' + content[match.end():]

    # 如果有替换，检查是否需要添加 import
    if content != original_content:
        # 检查是否已经有 import
        if 'toast_utils.dart' not in content:
            # 计算相对路径
            depth = get_relative_import_depth(file_path)
            prefix = '../' * depth
            import_line = f"import '{prefix}utils/toast_utils.dart';"

            # 找到最后一个 import
            import_matches = list(re.finditer(r"^import\s+'[^']+';", content, re.MULTILINE))
            if import_matches:
                last_import = import_matches[-1]
                insert_pos = content.find('\n', last_import.end()) + 1
                content = content[:insert_pos] + import_line + '\n' + content[insert_pos:]

        # 写回文件
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

def main():
    """主函数"""
    lib_dir = Path('./novel_app/lib')

    # 找到所有包含 showSnackBar 的 dart 文件
    files_with_snackbar = []
    for file_path in lib_dir.rglob('*.dart'):
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                if 'showSnackBar' in f.read():
                    files_with_snackbar.append(file_path)
        except Exception as e:
            print(f"读取文件错误 {file_path}: {e}")

    print(f"找到 {len(files_with_snackbar)} 个包含 SnackBar 的文件\n")

    # 替换每个文件
    replaced_count = 0
    for file_path in files_with_snackbar:
        try:
            replaced = replace_snackbar_in_file(file_path)
            if replaced:
                print(f"✓ 已处理: {file_path}")
                replaced_count += 1
            else:
                print(f"- 跳过: {file_path}")
        except Exception as e:
            print(f"✗ 错误 {file_path}: {e}")
            import traceback
            traceback.print_exc()

    print(f"\n完成！共处理 {replaced_count} 个文件")

if __name__ == '__main__':
    main()
