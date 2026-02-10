# 测试失败修复快速参考

**更新时间**: 2025-02-02
**适用场景**: 数据库相关测试修复

---

## 🚨 快速诊断流程

### 第1步: 查看实际错误信息
```bash
# 从测试输出中提取错误
grep "\[E\]" test_final_results.txt | grep "你的测试文件名"
```

### 第2步: 判断错误类型

| 错误信息 | 错误类型 | 根本原因 |
|---------|---------|---------|
| `database is locked (code 5)` | 🔴 数据库锁定 | 测试隔离问题 |
| `Expected: X, Actual: Y` | ⚠️ 断言失败 | 数据污染 |
| `SqfliteFfiException` | 🔴 运行时异常 | 数据库配置问题 |
| `NoSuchMethodError` | 🟡 代码错误 | 依赖注入问题 |

### 第3步: 选择修复方案

---

## 🔧 标准修复模式

### 模式A: DatabaseTestBase（推荐）

```dart
import '../../base/database_test_base.dart';

void main() {
  setUpAll(() {
    initTests();
  });

  group('测试组', () {
    late DatabaseTestBase testBase;

    setUp(() async {
      testBase = DatabaseTestBase();
      await testBase.setUp();
    });

    tearDown(() async {
      await testBase.tearDown();
    });

    test('测试用例', () async {
      // ✅ 使用 testBase.databaseService
      final service = YourService(testBase.databaseService);

      // ✅ 测试代码
      await service.someMethod();
      expect(result, expectedValue);
    });
  });
}
```

### 模式B: 避免使用（❌ 错误示例）

```dart
// ❌ 错误: 使用单例
final dbService = DatabaseService();

setUp(() async {
  await dbService.database;  // 所有测试共享!
});

// ❌ 错误: 没有清理
tearDown(() async {
  // 缺少清理代码
});
```

---

## 📋 快速修复清单

### 当前需要修复的文件

- [ ] `test/unit/services/scene_illustration_bugfix_test.dart`
- [ ] `test/unit/services/scene_illustration_service_test.dart`
- [ ] `test/unit/services/outline_service_test.dart`
- [ ] `test/unit/services/novels_view_test.dart`
- [ ] `test/unit/services/performance_optimization_test.dart`

### 修复步骤（每个文件）

1. **添加导入**:
   ```dart
   import '../../base/database_test_base.dart';
   ```

2. **替换setUp**:
   ```dart
   // 从这样:
   late DatabaseService dbService;
   setUp(() async {
     dbService = DatabaseService();
     await dbService.database;
   });

   // 改成这样:
   late DatabaseTestBase testBase;
   setUp(() async {
     testBase = DatabaseTestBase();
     await testBase.setUp();
   });
   ```

3. **添加tearDown**:
   ```dart
   tearDown(() async {
     await testBase.tearDown();
   });
   ```

4. **替换所有dbService引用**:
   ```dart
   // 从这样:
   dbService.addToBookshelf(novel);

   // 改成这样:
   testBase.databaseService.addToBookshelf(novel);
   ```

---

## 🎯 特定测试的修复要点

### scene_illustration_bugfix_test.dart

**问题**: 153次失败，全部是 `database is locked`

**修复**:
```dart
// setUp中创建testBase
setUp(() async {
  testBase = DatabaseTestBase();
  await testBase.setUp();

  // 初始化测试数据
  final chapter = MockData.createTestChapter(
    content: '测试内容',
  );
  await testBase.databaseService.cacheChapter(testNovelUrl, chapter, '');
});

// tearDown中清理
tearDown(() async {
  await testBase.tearDown();
});
```

### outline_service_test.dart

**问题**: 偶发性 `database is locked` + 数据污染

**修复**:
```dart
setUp(() async {
  testBase = DatabaseTestBase();
  await testBase.setUp();

  // ✅ 清空所有相关表
  final db = await testBase.databaseService.database;
  await db.delete('outlines');
  await db.delete('bookshelf');
});

tearDown(() async {
  await testBase.tearDown();
});
```

### flutter_force_directed_graph_test.dart

**问题**: 无问题（测试全过）

**修复**: 无需修复

---

## 📊 验证修复效果

### 修复前
```bash
$ flutter test test/unit/services/
00:32 +1394 ~3 -110: scene_illustration_bugfix_test ... [E]
00:31 +1273 ~3 -93: outline_service_test ... [E]
# 大量 database is locked 错误
```

### 修复后（预期）
```bash
$ flutter test test/unit/services/
00:15 +1500 ~3 -0: All tests passed!
✅ 无数据库锁定错误
✅ 所有测试稳定通过
```

---

## ⚡ 一键修复脚本

```bash
#!/bin/bash
# fix_database_tests.sh

FILES=(
  "test/unit/services/scene_illustration_bugfix_test.dart"
  "test/unit/services/scene_illustration_service_test.dart"
  "test/unit/services/outline_service_test.dart"
  "test/unit/services/novels_view_test.dart"
  "test/unit/services/performance_optimization_test.dart"
)

for file in "${FILES[@]}"; do
  echo "修复 $file ..."
  # TODO: 实际修复逻辑
done

echo "完成! 运行测试验证..."
flutter test test/unit/services/
```

---

## 🔍 常见问题

### Q1: 为什么必须使用DatabaseTestBase？

**A**: 因为 `DatabaseService()` 是单例模式，所有测试共享同一个数据库文件，导致锁冲突。

### Q2: 可以不使用DatabaseTestBase吗？

**A**: 理论上可以，但需要：
1. 每个测试使用不同的数据库文件
2. 确保tearDown完全关闭连接
3. 自己管理所有清理逻辑

**不推荐**，重复造轮子且容易出错。

### Q3: 修复后测试仍然失败？

**检查清单**:
- [ ] 是否所有 `DatabaseService()` 都替换成了 `testBase.databaseService`?
- [ ] 是否在tearDown中调用了 `testBase.tearDown()`?
- [ ] 是否导入了 `../../base/database_test_base.dart`?
- [ ] 是否在setUp中调用了 `testBase.setUp()`?

### Q4: 需要修改业务代码吗？

**A**: 不需要！业务代码是正确的，问题只在测试代码。

---

## 📈 预期改进

### 测试通过率
- 修复前: 91.6% (1451/1583)
- 修复后: 99.8%+ (1580/1583)

### 错误数量
- 修复前: 190个 "database is locked" 错误
- 修复后: 0个数据库锁定错误

### 测试稳定性
- 修复前: 偶发性失败，难以调试
- 修复后: 稳定通过，结果可预测

---

## 📚 相关文档

- [深度分析报告](../REPEATED_TEST_FAILURES_DEEP_ANALYSIS.md)
- [DatabaseTestBase文档](./test/base/README.md)
- [数据库锁定修复总结](./novel_app/test/DATABASE_LOCK_FIX_SUMMARY.md)

---

**维护者**: Claude AI Assistant
**最后更新**: 2025-02-02
**版本**: 1.0
