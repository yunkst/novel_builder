# 数据库锁定实验 - 快速参考

## 一键运行

```bash
# Windows
cd novel_app\test\experiments
run_experiment.bat

# Linux/macOS
cd novel_app/test/experiments
./run_experiment.sh
```

## 实验结果

| 方案 | 结果 | 推荐 | 适用场景 |
|------|------|------|----------|
| 方案1-单例 | ✅ 通过 | ⚠️ 不推荐 | 生产环境 |
| 方案2-包装类 | ✅ 通过 | ✅ 推荐 | 现有测试 |
| 方案3-内存DB | ✅ 通过 | ⭐ 强烈推荐 | 新测试 |
| 方案4-独立实例 | ✅ 通过 | ⭐ 强烈推荐 | 复杂测试 |

## 快速应用

### 新测试 (推荐方案3)

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

### 现有测试 (推荐方案2)

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

## 关键要点

✅ **DO**:
- 在测试中使用独立数据库
- 显式关闭数据库连接
- 使用内存数据库

❌ **DON'T**:
- 在测试中使用DatabaseService单例
- 共享数据库连接
- 忘记关闭连接

## 文档索引

- **快速开始**: [QUICKSTART.md](./QUICKSTART.md)
- **详细指南**: [README.md](./README.md)
- **实验报告**: [FINAL_ANALYSIS_REPORT.md](./FINAL_ANALYSIS_REPORT.md)
- **项目总结**: [PROJECT_SUMMARY.md](./PROJECT_SUMMARY.md)

## 常见问题

**Q: 方案1为什么通过了?**
A: 测试串行执行,没有并发冲突,但仍不推荐使用。

**Q: 应该选择哪个方案?**
A: 新测试用方案3,现有测试用方案2。

**Q: 如何迁移现有测试?**
A: 参考FINAL_ANALYSIS_REPORT.md的迁移计划。

---

**最后更新**: 2026-02-02
**实验状态**: ✅ 已完成
**推荐方案**: 方案3(纯内存数据库)
