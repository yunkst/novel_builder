# 数据库锁定实验 - 快速开始

## 一键运行

### Windows

```cmd
cd novel_app\test\experiments
run_experiment.bat
```

### Linux/macOS

```bash
cd novel_app/test/experiments
chmod +x run_experiment.sh
./run_experiment.sh
```

## 查看结果

测试完成后,查看报告:

```bash
# Windows
type reports\experiment_report_*.txt

# Linux/macOS
cat reports/experiment_report_*.txt
```

## 快速判断

在报告中查找:

### ✅ 所有测试通过
```
All tests passed!
✅ 方案1-测试1成功
✅ 方案1-测试2成功
✅ 方案1-测试3成功
...
```

**结论**: 该方案有效,可以使用。

### ❌ 部分测试失败
```
Some tests failed
❌ 方案1-测试3失败: Database is locked
```

**结论**: 该方案无效,需要使用其他方案。

## 实验结果模板

复制这个表格填写你的结果:

| 方案 | 测试1 | 测试2 | 测试3 | 有锁冲突? | 推荐指数 |
|------|-------|-------|-------|-----------|----------|
| 方案1-单例 | [✅/❌] | [✅/❌] | [✅/❌] | [是/否] | ⭐~⭐⭐⭐⭐⭐ |
| 方案2-包装类 | [✅/❌] | [✅/❌] | [✅/❌] | [是/否] | ⭐~⭐⭐⭐⭐⭐ |
| 方案3-内存DB | [✅/❌] | [✅/❌] | [✅/❌] | [是/否] | ⭐~⭐⭐⭐⭐⭐ |
| 方案4-独立实例 | [✅/❌] | [✅/❌] | [✅/❌] | [是/否] | ⭐~⭐⭐⭐⭐⭐ |

## 下一步

1. **找到最优方案**: 选择所有测试都通过且有4-5星推荐的方案
2. **应用到测试**: 使用推荐方案重写失败的测试
3. **验证修复**: 运行测试确保问题解决

## 示例: 应用方案2

```dart
import 'package:novel_app/test/base/database_test_base.dart';

void main() {
  late DatabaseTestBase testBase;

  setUp(() async {
    testBase = DatabaseTestBase();
    await testBase.setUp();
  });

  tearDown(() async {
    await testBase.tearDown();
  });

  test('我的测试', () async {
    // 使用 testBase.databaseService 进行测试
    await testBase.databaseService.addToBookshelf(novel);

    final novels = await testBase.databaseService.getBookshelf();
    expect(novels.length, 1);
  });
}
```

## 需要帮助?

查看详细文档: [README.md](./README.md)
