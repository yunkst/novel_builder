#!/bin/bash
# run_unit_tests.sh - 快速单元测试脚本
#
# 运行使用 Mock 的单元测试（快速反馈）
# 用于TDD开发和快速验证

echo "🚀 运行快速单元测试（Mock版本）..."
echo ""

# 切换到项目目录
cd "$(dirname "$0")/../novel_app"

# 定义测试文件列表（使用Mock的单元测试）
UNIT_TESTS=(
  "test/unit/controllers/chapter_loader_test.dart"
  "test/unit/services/ai_accompaniment_background_test.dart"
  "test/unit/services/dify_parsing_test.dart"
  "test/unit/models/chapter_ai_accompaniment_test.dart"
  "test/unit/models/character_relationship_test.dart"
  "test/unit/models/character_update_test.dart"
  "test/unit/models/reading_progress_test.dart"
)

# 运行测试
echo "运行 ${#UNIT_TESTS[@]} 个单元测试..."
flutter test "${UNIT_TESTS[@]}"

# 检查结果
if [ $? -eq 0 ]; then
  echo ""
  echo "✅ 快速单元测试完成"
else
  echo ""
  echo "❌ 单元测试失败"
  exit 1
fi
