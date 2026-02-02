#!/bin/bash

# 失败测试分析脚本
cd "D:\myspace\novel_builder\novel_app"

# 失败测试文件列表
failed_tests=(
  "test/unit/controllers/chapter_loader_test.dart"
  "test/unit/controllers/chapter_reorder_controller_test.dart"
  "test/unit/services/ai_accompaniment_background_test.dart"
  "test/unit/services/ai_accompaniment_database_test.dart"
  "test/unit/services/batch_chapter_loading_test.dart"
  "test/unit/services/chapter_service_test.dart"
  "test/unit/services/character_auto_save_logic_test.dart"
  "test/unit/services/character_drop_first_last_test.dart"
  "test/unit/services/character_extraction_bug_test.dart"
  "test/unit/services/character_extraction_service_test.dart"
  "test/unit/services/character_merge_test.dart"
  "test/unit/services/character_relationship_database_test.dart"
  "test/unit/services/database_lock_fix_verification_test.dart"
  "test/unit/services/database_service_test.dart"
  "test/unit/services/novels_view_test.dart"
  "test/unit/services/scene_illustration_service_test.dart"
  "test/unit/services/tts_player_service_test.dart"
  "test/unit/widgets/tts_widgets_test.dart"
)

echo "# 失败测试详细分析报告" > failure_analysis.md
echo "" >> failure_analysis.md
echo "生成时间: $(date)" >> failure_analysis.md
echo "" >> failure_analysis.md

for test in "${failed_tests[@]}"; do
  echo "## 分析: $test" >> failure_analysis.md
  echo '```' >> failure_analysis.md
  flutter test "$test" --reporter expanded 2>&1 | grep -A 3 "Error:" >> failure_analysis.md
  echo '```' >> failure_analysis.md
  echo "" >> failure_analysis.md
done

cat failure_analysis.md
