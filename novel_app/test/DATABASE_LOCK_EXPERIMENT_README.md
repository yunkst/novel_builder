# 数据库锁定实验

## 🎯 实验目标

通过探索性实验找到数据库锁定问题的**真正有效**解决方案。

## ⚡ 快速开始

```bash
# Windows
cd novel_app\test\experiments
run_experiment.bat

# Linux/macOS
cd novel_app/test/experiments
./run_experiment.sh
```

## 📊 实验结果

| 方案 | 结果 | 推荐 |
|------|------|------|
| 方案1-单例 | ✅ 通过 | ⚠️ 有风险 |
| 方案2-包装类 | ✅ 通过 | ✅ 推荐 |
| 方案3-内存DB | ✅ 通过 | ⭐ 最优 |
| 方案4-独立实例 | ✅ 通过 | ⭐ 最优 |

## 📚 完整文档

所有文档位于 `test/experiments/` 目录:

- **[INDEX.md](test/experiments/INDEX.md)** - 📖 文档导航索引
- **[QUICKSTART.md](test/experiments/QUICKSTART.md)** - ⚡ 快速开始指南
- **[QUICK_REFERENCE.md](test/experiments/QUICK_REFERENCE.md)** - 📝 快速参考卡片
- **[README.md](test/experiments/README.md)** - 📚 详细使用指南
- **[FINAL_ANALYSIS_REPORT.md](test/experiments/FINAL_ANALYSIS_REPORT.md)** - 📊 最终分析报告
- **[DELIVERY_CHECKLIST.md](test/experiments/DELIVERY_CHECKLIST.md)** - ✅ 交付清单

## 🎓 推荐方案

### 新测试: 方案3 (纯内存数据库) ⭐

```dart
test('新测试', () async {
  final db = await databaseFactoryFfi.openDatabase(
    ':memory:',
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE test (...)');
      },
    ),
  );

  try {
    // 测试代码
  } finally {
    await db.close();
  }
});
```

### 现有测试: 方案2 (DatabaseTestBase) ✅

```dart
late DatabaseTestBase testBase;

setUp(() async {
  testBase = DatabaseTestBase();
  await testBase.setUp();
});

tearDown(() async {
  await testBase.tearDown();
});

test('测试', () async {
  // 使用 testBase.databaseService
});
```

## 📖 更多信息

请查看 `test/experiments/README.md` 获取完整的实验文档。

---

**项目状态**: ✅ 已完成
**最后更新**: 2026-02-02
**推荐方案**: 方案3 (纯内存数据库)
