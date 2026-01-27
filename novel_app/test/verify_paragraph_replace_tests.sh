#!/bin/bash
# 段落替换功能测试验证脚本
# 用于快速验证所有段落替换相关的测试

echo "========================================"
echo "段落替换功能测试验证"
echo "========================================"
echo ""

echo "[1/3] 运行段落替换逻辑单元测试..."
flutter test test/unit/paragraph_replace_logic_test.dart --no-pub
if [ $? -ne 0 ]; then
    echo "❌ 段落替换逻辑测试失败"
    exit 1
fi
echo "✅ 段落替换逻辑测试通过"
echo ""

echo "[2/3] 运行Dify响应到替换测试..."
flutter test test/unit/dify_response_to_replace_test.dart --no-pub
if [ $? -ne 0 ]; then
    echo "❌ Dify响应到替换测试失败"
    exit 1
fi
echo "✅ Dify响应到替换测试通过"
echo ""

echo "[3/3] 运行段落替换集成测试..."
flutter test test/integration/paragraph_rewrite_integration_test.dart --no-pub
if [ $? -ne 0 ]; then
    echo "❌ 段落替换集成测试失败"
    exit 1
fi
echo "✅ 段落替换集成测试通过"
echo ""

echo "========================================"
echo "✅ 所有段落替换测试通过 (40个测试)"
echo "========================================"
echo ""
echo "测试文件:"
echo "  - test/unit/paragraph_replace_logic_test.dart (17个测试)"
echo "  - test/unit/dify_response_to_replace_test.dart (12个测试)"
echo "  - test/integration/paragraph_rewrite_integration_test.dart (11个测试)"
echo ""

exit 0
