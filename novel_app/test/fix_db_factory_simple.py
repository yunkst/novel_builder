#!/usr/bin/env python3
"""
简单直接的方法修复测试文件
"""
import os
import re
from pathlib import Path

def fix_file(file_path):
    """修复单个文件"""
    if not os.path.exists(file_path):
        print(f"[SKIP] File not found: {file_path}")
        return False

    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # 检查是否需要修复
    needs_fix = False
    has_sqflite_import = False
    has_init_tests_import = False
    init_tests_line_idx = -1

    for i, line in enumerate(lines):
        if "sqfliteFfiInit()" in line:
            needs_fix = True
            break
        if "databaseFactory = databaseFactoryFfi" in line:
            needs_fix = True
            break
        if "import 'package:sqflite_common_ffi" in line or 'import "package:sqflite_common_ffi' in line:
            has_sqflite_import = True
        if "import '../test_bootstrap.dart'" in line or 'import "../test_bootstrap.dart"' in line or "import '../../test_bootstrap.dart'" in line or 'import "../../test_bootstrap.dart"' in line:
            has_init_tests_import = True
            init_tests_line_idx = i

    if not needs_fix:
        print(f"[SKIP] No fix needed: {file_path}")
        return False

    # 开始修复
    new_lines = []
    skip_next = False
    in_setup_all = False
    added_init_tests = False

    i = 0
    while i < len(lines):
        line = lines[i]

        # 跳过不需要的行
        if "sqfliteFfiInit()" in line and "setUpAll" in "".join(lines[max(0,i-5):i]):
            i += 1
            continue

        if "databaseFactory = databaseFactoryFfi" in line:
            i += 1
            continue

        # 检测setUpAll开始
        if "setUpAll(() {" in line:
            in_setup_all = True
            new_lines.append(line)
            i += 1

            # 检查下一行是否需要添加initTests
            if i < len(lines) and not added_init_tests:
                # 跳过注释行
                while i < len(lines) and ("//" in lines[i] or lines[i].strip() == ""):
                    new_lines.append(lines[i])
                    i += 1

                # 如果下一行不是initTests，添加它
                if i < len(lines) and "initTests()" not in lines[i]:
                    indent = "    "
                    new_lines.append(f"{indent}initTests();\n")
                    added_init_tests = True
            continue

        # 移除sqflite_common_ffi import
        if "import 'package:sqflite_common_ffi" in line or 'import "package:sqflite_common_ffi' in line:
            i += 1
            continue

        new_lines.append(line)
        i += 1

    # 添加test_bootstrap import (如果需要)
    if not has_init_tests_import:
        # 找到最后的import行
        last_import_idx = -1
        for idx, line in enumerate(new_lines):
            if line.strip().startswith("import ") and idx > last_import_idx:
                last_import_idx = idx

        if last_import_idx >= 0:
            # 计算相对路径
            file_dir = Path(file_path).parent
            test_dir = Path.cwd()

            # 简单计算相对路径层级
            depth = len(file_dir.relative_to(test_dir).parts)
            rel_path = "../" * (depth if depth > 0 else 0)
            if rel_path:
                rel_path = rel_path.rstrip("/")  # 移除末尾多余的斜杠
                import_line = f"import '{rel_path}/test_bootstrap.dart';\n"
            else:
                import_line = "import 'test_bootstrap.dart';\n"

            new_lines.insert(last_import_idx + 1, import_line)

    # 写回文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    print(f"[FIXED] {file_path}")
    return True

def main():
    base = Path.cwd()

    files = [
        "diagnosis/background_setting_save_diagnosis_test.dart",
        "diagnosis/real_user_scenario_test.dart",
        "diagnosis/url_consistency_test.dart",
        "integration/background_summary_persistence_test.dart",
        "integration/character_extraction_integration_test.dart",
        "integration/character_relationship_integration_test.dart",
        "integration/character_update_integration_test.dart",
        "integration/paragraph_rewrite_full_test.dart",
        "integration/paragraph_rewrite_integration_test.dart",
        "unit/preload_service_race_condition_test.dart",
        "unit/screens/backend_settings_screen_test.dart",
        "unit/screens/background_setting_load_test.dart",
        "unit/screens/chapter_generation_screen_test.dart",
        "unit/screens/chapter_search_screen_test.dart",
        "unit/screens/character_chat_screen_test.dart",
        "unit/screens/character_management_screen_test.dart",
        "unit/screens/chat_scene_management_screen_test.dart",
        "unit/screens/dify_settings_screen_test.dart",
        "unit/screens/multi_role_chat_screen_test.dart",
        "unit/screens/search_screen_test.dart",
        "unit/screens/settings_screen_test.dart",
        "unit/screens/unified_relationship_graph_test.dart",
        "unit/services/batch_chapter_loading_test.dart",
        "unit/services/character_auto_save_logic_test.dart",
        "unit/services/character_extraction_service_test.dart",
        "unit/services/outline_service_test.dart",
        "unit/services/performance_optimization_test.dart",
        "unit/services/reading_chapter_log_test.dart",
        "unit/services/scene_illustration_bugfix_test.dart",
        "unit/services/scene_illustration_service_test.dart",
        "unit/widgets/bookshelf_selector_test.dart",
        "unit/widgets/tts_widgets_test.dart",
    ]

    fixed = 0
    skipped = 0

    for f in files:
        full_path = base / f
        if fix_file(str(full_path)):
            fixed += 1
        else:
            skipped += 1

    print(f"\nSummary: Fixed={fixed}, Skipped={skipped}, Total={len(files)}")

if __name__ == '__main__':
    main()
