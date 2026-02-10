#!/bin/bash
# run_integration_tests.sh - 集成测试脚本
#
# 运行使用真实数据库的集成测试
# 用于验证数据持久化和数据层Bug发现

echo "🗄️  运行数据库集成测试（真实SQLite）..."
echo ""

# 切换到项目目录
cd "$(dirname "$0")/../novel_app"

# 定义集成测试文件列表（使用真实数据库）
REAL_DB_TESTS=(
  "test/real_db/controllers/bookshelf_manager_real_db_test.dart"
  "test/real_db/controllers/chapter_action_handler_real_db_test.dart"
)

INTEGRATION_TESTS=(
  "test/integration/"
)

# 运行真实数据库测试
echo "运行真实数据库测试..."
flutter test "${REAL_DB_TESTS[@]}"

REAL_DB_RESULT=$?

# 运行集成测试
echo ""
echo "运行端到端集成测试..."
flutter test "${INTEGRATION_TESTS[@]}"

INTEGRATION_RESULT=$?

# 检查结果
if [ $REAL_DB_RESULT -eq 0 ] && [ $INTEGRATION_RESULT -eq 0 ]; then
  echo ""
  echo "✅ 集成测试完成"
else
  echo ""
  echo "❌ 集成测试失败"
  exit 1
fi
