#!/usr/bin/env python3
"""
修复错误的import路径
"""
import os
from pathlib import Path

def fix_imports(base_dir):
    """修复所有错误的import语句"""
    fixed = 0

    for root, dirs, files in os.walk(base_dir):
        # 跳过某些目录
        dirs[:] = [d for d in dirs if d not in ['.dart_tool', 'build', 'reports', 'real_db']]

        for file in files:
            if not file.endswith('_test.dart'):
                continue

            file_path = os.path.join(root, file)

            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                if r"import '$rel_path/test_bootstrap.dart'" not in content:
                    continue

                # 计算相对路径
                rel_path = os.path.relpath(root, base_dir)
                depth = len(Path(rel_path).parts)

                if depth == 0:
                    # test/xxx_test.dart
                    import_path = "test_bootstrap.dart"
                elif depth == 1:
                    # test/unit/xxx_test.dart 或 test/integration/xxx_test.dart
                    import_path = "../test_bootstrap.dart"
                elif depth == 2:
                    # test/unit/screens/xxx_test.dart
                    import_path = "../../test_bootstrap.dart"
                else:
                    import_path = "../" * depth + "test_bootstrap.dart"

                # 替换
                new_content = content.replace(
                    r"import '$rel_path/test_bootstrap.dart'",
                    f"import '{import_path}'"
                )

                if new_content != content:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"[FIXED] {os.path.relpath(file_path, base_dir)}")
                    fixed += 1

            except Exception as e:
                print(f"[ERROR] {file_path}: {e}")

    return fixed

if __name__ == '__main__':
    base = Path.cwd()
    count = fix_imports(str(base))
    print(f"\nFixed {count} files")
