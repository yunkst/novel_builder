#!/usr/bin/env python3
"""
移除不需要的sqflite_common_ffi import
"""
import os
from pathlib import Path

def remove_sqflite_import(base_dir):
    """移除sqflite_common_ffi import"""
    fixed = 0

    # 需要处理的文件
    files_to_fix = [
        "integration/database_rebuild_test.dart",
        "unit/ai_companion_auto_trigger_test.dart",
        "unit/screens/chat_scene_management_screen_test.dart",
        "unit/services/character_avatar_service_test.dart",
        "unit/services/insert_user_chapter_fix_test.dart",
        "unit/services/novels_view_test.dart",
    ]

    for file_rel in files_to_fix:
        file_path = os.path.join(base_dir, file_rel)

        if not os.path.exists(file_path):
            print(f"[SKIP] Not found: {file_rel}")
            continue

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()

            new_lines = []
            for line in lines:
                # 移除sqflite_common_ffi import
                if "import 'package:sqflite_common_ffi" in line or 'import "package:sqflite_common_ffi' in line:
                    print(f"[REMOVED] {file_rel}: {line.strip()}")
                    fixed += 1
                    continue
                new_lines.append(line)

            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)

            print(f"[FIXED] {file_rel}")

        except Exception as e:
            print(f"[ERROR] {file_rel}: {e}")

    return fixed

if __name__ == '__main__':
    base = Path.cwd()
    count = remove_sqflite_import(str(base))
    print(f"\nRemoved {count} import lines")
