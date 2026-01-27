# 段落替换测试快速参考

## 快速验证命令
```bash
# 运行所有段落替换测试
flutter test test/unit/paragraph_replace_logic_test.dart \
              test/unit/dify_response_to_replace_test.dart \
              test/integration/paragraph_rewrite_integration_test.dart \
              --no-pub

# 或使用验证脚本
./test/verify_paragraph_replace_tests.sh  # Linux/Mac
./test/verify_paragraph_replace_tests.bat # Windows
```

## 测试统计
- **总测试数**: 40个
- **单元测试**: 29个
- **集成测试**: 11个
- **通过率**: 100%
- **执行时间**: <5秒

## 核心文件
```
lib/utils/paragraph_replace_helper.dart
lib/widgets/reader/paragraph_rewrite_dialog.dart
test/unit/paragraph_replace_logic_test.dart
test/unit/dify_response_to_replace_test.dart
test/integration/paragraph_rewrite_integration_test.dart
```

## 修复历史
- **2026-01-26**: 修复 ChapterManager API调用，所有测试通过

## 性能基准
- 小章节: <1ms
- 大章节 (100段): <10ms
- 流式生成: 正常

## 状态: ✅ 全部通过
