#!/bin/bash
# 批量修复测试文件中的databaseFactory重复设置

cd "$(dirname "$0")"

# 需要修复的文件列表
files=(
  "./diagnosis/background_setting_save_diagnosis_test.dart"
  "./diagnosis/real_user_scenario_test.dart"
  "./diagnosis/url_consistency_test.dart"
  "./integration/background_summary_persistence_test.dart"
  "./integration/character_extraction_integration_test.dart"
  "./integration/character_relationship_integration_test.dart"
  "./integration/character_update_integration_test.dart"
  "./integration/paragraph_rewrite_full_test.dart"
  "./integration/paragraph_rewrite_integration_test.dart"
  "./unit/preload_service_race_condition_test.dart"
  "./unit/screens/backend_settings_screen_test.dart"
  "./unit/screens/background_setting_load_test.dart"
  "./unit/screens/chapter_generation_screen_test.dart"
  "./unit/screens/chapter_search_screen_test.dart"
  "./unit/screens/character_chat_screen_test.dart"
  "./unit/screens/character_management_screen_test.dart"
  "./unit/screens/chat_scene_management_screen_test.dart"
  "./unit/screens/dify_settings_screen_test.dart"
  "./unit/screens/multi_role_chat_screen_test.dart"
  "./unit/screens/search_screen_test.dart"
  "./unit/screens/settings_screen_test.dart"
  "./unit/screens/unified_relationship_graph_test.dart"
  "./unit/services/batch_chapter_loading_test.dart"
  "./unit/services/character_auto_save_logic_test.dart"
  "./unit/services/character_extraction_service_test.dart"
  "./unit/services/database_service_test.dart"
  "./unit/services/outline_service_test.dart"
  "./unit/services/performance_optimization_test.dart"
  "./unit/services/reading_chapter_log_test.dart"
  "./unit/services/scene_illustration_bugfix_test.dart"
  "./unit/services/scene_illustration_service_test.dart"
  "./unit/widgets/bookshelf_selector_test.dart"
  "./unit/widgets/tts_widgets_test.dart"
)

fixed=0
skipped=0
failed=0

for file in "${files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "[MISSING] $file"
    ((failed++))
    continue
  fi

  # 检查文件是否包含需要替换的内容
  if grep -q "sqfliteFfiInit()" "$file" && grep -q "databaseFactory = databaseFactoryFfi" "$file"; then
    # 使用sed进行替换
    # 首先替换setUpAll块
    sed -i '/sqfliteFfiInit();/d' "$file"
    sed -i '/databaseFactory = databaseFactoryFfi;/d' "$file"
    sed -i 's|setUpAll(() {|setUpAll(() {\n    initTests();|' "$file"

    # 添加import语句(如果还没有)
    if ! grep -q "import.*test_bootstrap.dart" "$file"; then
      # 计算相对路径
      dir=$(dirname "$file")
      depth=$(echo "$dir" | tr -cd '/' | wc -c)
      prefix=""
      for ((i=0; i<depth; i++)); do
        prefix+="../"
      done
      prefix="${dir:+../}"  # 确保至少有一个../

      # 在最后一个import后添加
      sed -i "0,/import/s|import.*;|import '${prefix}test_bootstrap.dart';\n&|" "$file"
    fi

    echo "[FIXED] $file"
    ((fixed++))
  else
    echo "[SKIP] $file"
    ((skipped++))
  fi
done

echo ""
echo "Fix Summary:"
echo "   Fixed: $fixed files"
echo "   Skipped: $skipped files"
echo "   Failed: $failed files"
echo "   Total: ${#files[@]} files"
