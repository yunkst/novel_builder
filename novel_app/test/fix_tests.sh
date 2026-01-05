#!/bin/bash

# 批量修复数据库测试文件
files=(
  "chapter_url_fix_test.dart"
  "database_column_fix_test.dart"
  "search_navigation_test.dart"
  "search_navigation_unit_test.dart"
  "search_test.dart"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    # 检查是否已经导入了test_bootstrap
    if ! grep -q "import 'test_bootstrap.dart" "$file"; then
      echo "修复 $file"
      # 在第一个import后添加test_bootstrap导入
      sed -i "1 a import 'test_bootstrap.dart';" "$file"
      
      # 在main()后添加initDatabaseTests()
      sed -i '/^void main()/a \  initDatabaseTests();' "$file"
      
      echo "✅ $file 已修复"
    else
      echo "⏭️  $file 已包含test_bootstrap，跳过"
    fi
  else
    echo "❌ 文件不存在: $file"
  fi
done

echo ""
echo "批量修复完成"
