#!/bin/bash

echo "=== 覆盖率分析报告 ==="
echo ""

# 分析invalid_markup_cleaner.dart
echo "## invalid_markup_cleaner.dart"
echo "未覆盖的行："
awk '/^SF:lib\services\invalid_markup_cleaner\.dart/,/^end_of_record/' coverage/lcov.info | grep "^DA:" | awk -F, '$2==0 {print "  行 " $1}' | head -10

echo ""
echo "## media_markup_parser.dart"
echo "未覆盖的行："
awk '/^SF:lib\utils\media_markup_parser\.dart/,/^end_of_record/' coverage/lcov.info | grep "^DA:" | awk -F, '$2==0 {print "  行 " $1}' | head -10

echo ""
echo "## paragraph_rewrite_controller.dart"
echo "未覆盖的行："
awk '/^SF:lib\controllers\paragraph_rewrite_controller\.dart/,/^end_of_record/' coverage/lcov.info | grep "^DA:" | awk -F, '$2==0 {print "  行 " $1}' | head -10

