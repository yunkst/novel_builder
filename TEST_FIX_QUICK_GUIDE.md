# 测试修复快速指南

本指南提供快速修复测试超时、编译缓存和数据库锁定问题的步骤。

---

## 🚀 快速修复 (3步)

### 步骤1: 清理缓存
```bash
cd novel_app
flutter clean
flutter pub get
```

### 步骤2: 运行测试
```bash
# 基础测试（并行）
flutter test test/unit/ --concurrency=4

# 数据库测试（串行）
flutter test --tags="database" --concurrency=1

# 特定测试
flutter test test/unit/core/providers/theme_provider_test.dart
```

### 步骤3: 查看结果
```bash
# 生成覆盖率报告
flutter test --coverage
```

---

## 📋 问题诊断

### 问题1: 测试超时
**症状**: `TimeoutException after 0:10:00.000000`

**原因**: 使用 `testWidgets` 测试非 Widget 代码

**解决**:
```dart
// ❌ 错误
testWidgets('should load theme', (tester) async {
  final container = ProviderContainer();
  // ...
});

// ✅ 正确
test('should load theme', () async {
  final container = ProviderContainer();
  // ...
});
```

### 问题2: 编译缓存冲突
**症状**: `PathExistsException: Cannot copy file to 'build\test_cache\...'`

**原因**: 多个测试文件同时编译

**解决**:
```bash
flutter clean
rm -rf build/.test_cache  # Linux/macOS
flutter pub get
```

### 问题3: 数据库锁定
**症状**: `database is locked (code 5)`

**原因**: 多个测试同时访问数据库

**解决**:
```dart
@Tags(['database'])
@TestOn('vm')
void main() {
  // 测试代码
}
```

运行时串行执行:
```bash
flutter test --tags="database" --concurrency=1
```

---

## 🔧 常用修复模式

### 模式1: Flutter 绑定初始化
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('example', () {
    // 测试代码
  });
}
```

### 模式2: SharedPreferences Mock
```dart
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'key': 'value',
    });
  });

  test('example', () {
    // 测试代码
  });
}
```

### 模式3: 测试隔离
```dart
@Tags(['database'])
@TestOn('vm')
void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService();
    // 初始化
  });

  tearDown(() async {
    // 清理
  });

  test('example', () {
    // 测试代码
  });
}
```

---

## 📊 性能基准

| 场景 | 修复前 | 修复后 | 提升 |
|------|--------|--------|------|
| ThemeProvider测试 | 10分钟超时 | 1秒完成 | 600x |
| 数据库测试 | 并发锁定 | 串行执行 | 稳定 |
| 编译缓存 | 冲突失败 | 正常编译 | 100% |

---

## 🎯 修复检查清单

### ✅ 代码修改
- [ ] 将 `testWidgets` 改为 `test`（如果不涉及Widget）
- [ ] 添加 `TestWidgetsFlutterBinding.ensureInitialized()`
- [ ] 为数据库测试添加 `@Tags(['database'])`
- [ ] 添加 `@Timeout` 注解（如需要）

### ✅ 环境配置
- [ ] 运行 `flutter clean`
- [ ] 运行 `flutter pub get`
- [ ] 删除 `.test_cache` 目录（如存在）

### ✅ 测试执行
- [ ] 基础测试: `flutter test test/unit/`
- [ ] 数据库测试: `flutter test --tags="database" --concurrency=1`
- [ ] 覆盖率报告: `flutter test --coverage`

---

## 🚨 常见错误

### 错误1: MissingPluginException
```
MissingPluginException: No implementation found for method getAll
on channel plugins.flutter.io/shared_preferences
```

**解决**: 初始化 Mock SharedPreferences
```dart
SharedPreferences.setMockInitialValues({});
```

### 错误2: Binding not initialized
```
Binding has not yet been initialized
```

**解决**: 初始化 Flutter 绑定
```dart
TestWidgetsFlutterBinding.ensureInitialized();
```

### 错误3: Database locked
```
database is locked (code 5)
```

**解决**: 串行执行数据库测试
```bash
flutter test --tags="database" --concurrency=1
```

---

## 📖 详细文档

- 完整修复报告: `TEST_TIMEOUT_AND_CACHE_FIX_REPORT.md`
- 最终修复报告: `FINAL_TEST_FIX_REPORT.md`
- 测试最佳实践: `test/reports/TEST_BEST_PRACTICES.md`

---

## 💡 提示

1. **定期清理**: 每次运行测试前执行 `flutter clean`
2. **并行测试**: 使用 `--concurrency=N` 加速
3. **串行数据库**: 数据库测试必须串行执行
4. **超时设置**: 为慢速测试添加 `@Timeout` 注解

---

最后更新: 2026-02-01
