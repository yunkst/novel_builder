#!/usr/bin/env python3
"""
批量修复测试文件中的databaseFactory重复设置问题

将:
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

替换为:
  setUpAll(() {
    initTests();
  });
"""

import os
import re
from pathlib import Path

# 需要修复的测试文件列表
TEST_FILES = [
    "./diagnosis/background_setting_save_diagnosis_test.dart",
    "./diagnosis/real_user_scenario_test.dart",
    "./diagnosis/url_consistency_test.dart",
    "./integration/background_summary_persistence_test.dart",
    "./integration/character_extraction_integration_test.dart",
    "./integration/character_relationship_integration_test.dart",
    "./integration/character_update_integration_test.dart",
    "./integration/paragraph_rewrite_full_test.dart",
    "./integration/paragraph_rewrite_integration_test.dart",
    "./unit/preload_service_race_condition_test.dart",
    "./unit/screens/backend_settings_screen_test.dart",
    "./unit/screens/background_setting_load_test.dart",
    "./unit/screens/chapter_generation_screen_test.dart",
    "./unit/screens/chapter_search_screen_test.dart",
    "./unit/screens/character_chat_screen_test.dart",
    "./unit/screens/character_management_screen_test.dart",
    "./unit/screens/chat_scene_management_screen_test.dart",
    "./unit/screens/dify_settings_screen_test.dart",
    "./unit/screens/multi_role_chat_screen_test.dart",
    "./unit/screens/search_screen_test.dart",
    "./unit/screens/settings_screen_test.dart",
    "./unit/screens/unified_relationship_graph_test.dart",
    "./unit/services/batch_chapter_loading_test.dart",
    "./unit/services/character_auto_save_logic_test.dart",
    "./unit/services/character_extraction_service_test.dart",
    "./unit/services/database_service_test.dart",
    "./unit/services/outline_service_test.dart",
    "./unit/services/performance_optimization_test.dart",
    "./unit/services/reading_chapter_log_test.dart",
    "./unit/services/scene_illustration_bugfix_test.dart",
    "./unit/services/scene_illustration_service_test.dart",
    "./unit/widgets/bookshelf_selector_test.dart",
    "./unit/widgets/tts_widgets_test.dart",
]

def fix_test_file(file_path: str) -> bool:
    """修复单个测试文件"""
    full_path = Path(file_path)

    if not full_path.exists():
        print(f"[MISSING] {file_path}")
        return False

    try:
        with open(full_path, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content

        # 模式1: 替换 setUpAll 中的 sqfliteFfiInit + databaseFactory 设置
        # 匹配:
        # setUpAll(() {
        #   sqfliteFfiInit();
        #   databaseFactory = databaseFactoryFfi;
        # });
        pattern1 = r'setUpAll\(\(\) \{\s*(?:ChapterManager\.setTestMode\(true\);\s*)?(?:TestWidgetsFlutterBinding\.ensureInitialized\(\);\s*)?sqfliteFfiInit\(\);\s+databaseFactory = databaseFactoryFfi;\s*\});'

        replacement1 = r'setUpAll(() {\n    initTests();\n  });'

        content = re.sub(pattern1, replacement1, content, flags=re.MULTILINE)

        # 模式2: 处理分多行的情况
        # setUpAll(() {
        #   // 注释
        #   sqfliteFfiInit();
        #   databaseFactory = databaseFactoryFfi;
        # });
        pattern2 = r'setUpAll\(\(\) \{\s*//[^\n]*\n(?:ChapterManager\.setTestMode\(true\);\s*)?(?:TestWidgetsFlutterBinding\.ensureInitialized\(\);\s*)?sqfliteFfiInit\(\);\s+databaseFactory = databaseFactoryFfi;\s*\});'

        replacement2 = r'setUpAll(() {\n    initTests();\n  });'

        content = re.sub(pattern2, replacement2, content, flags=re.MULTILINE)

        # 如果内容发生了变化,保存修改
        if content != original_content:
            # 检查是否需要添加 import
            if 'initTests' in content and "import '../test_bootstrap.dart'" not in content and 'import "../../test_bootstrap.dart"' not in content:
                # 找到最后一个 import 语句
                import_pattern = r"(import\s+['\"].*?['\"];\s*\n)"
                import_matches = list(re.finditer(import_pattern, content))

                if import_matches:
                    last_import = import_matches[-1]
                    insert_pos = last_import.end()

                    # 检查是否已经有 test_bootstrap 导入
                    if 'test_bootstrap' not in content[:insert_pos]:
                        # 确定相对导入路径
                        file_dir = full_path.parent
                        test_dir = Path.cwd()

                        # 计算相对路径
                        rel_parts = []
                        current = file_dir
                        while current != test_dir and current.parent != current:
                            rel_parts.append('..')
                            current = current.parent

                        rel_path = '/'.join(rel_parts) if rel_parts else '.'
                        import_statement = f"import '{rel_path}/test_bootstrap.dart';\n"

                        content = content[:insert_pos] + import_statement + content[insert_pos:]

            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(content)

            print(f"[FIXED] {file_path}")
            return True
        else:
            print(f"[SKIP] No changes needed: {file_path}")
            return False

    except Exception as e:
        print(f"[ERROR] {file_path}: {e}")
        return False

def main():
    print("Starting batch fix for databaseFactory duplicate settings\n")

    base_dir = Path.cwd()
    fixed_count = 0
    skipped_count = 0
    failed_count = 0

    for test_file in TEST_FILES:
        file_path = base_dir / test_file

        if fix_test_file(str(file_path)):
            fixed_count += 1
        else:
            # 检查是否是因为文件不存在
            if not file_path.exists():
                failed_count += 1
            else:
                skipped_count += 1

    print(f"\nFix Summary:")
    print(f"   Fixed: {fixed_count} files")
    print(f"   Skipped: {skipped_count} files")
    print(f"   Failed: {failed_count} files")
    print(f"   Total: {len(TEST_FILES)} files")

    if fixed_count > 0:
        print(f"\nNext steps: Run tests to verify the fix:")
        print(f"   cd D:/myspace/novel_builder/novel_app")
        print(f"   flutter test")

if __name__ == '__main__':
    main()
