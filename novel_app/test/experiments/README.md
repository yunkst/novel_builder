# 数据库锁定实验 - 使用指南

## 概述

这是一个系统性实验,用于测试和比较不同的数据库隔离方案,找出解决数据库锁定问题的真正有效方案。

## 实验目的

通过对照实验,验证以下4种方案的可靠性:
- **方案1**: DatabaseService单例模式
- **方案2**: DatabaseTestBase包装类
- **方案3**: 纯内存数据库
- **方案4**: 独立数据库实例

## 快速开始

### Windows用户

```cmd
# 运行实验
cd novel_app\test\experiments
run_experiment.bat

# 查看报告
type reports\experiment_report_YYYYMMDD_HHMMSS.txt
```

### Linux/macOS用户

```bash
# 给脚本添加执行权限
cd novel_app/test/experiments
chmod +x run_experiment.sh

# 运行实验
./run_experiment.sh

# 查看报告
cat reports/experiment_report_YYYYMMDD_HHMMSS.txt
```

## 实验文件说明

### 核心文件

```
test/experiments/
├── database_lock_experiment.dart      # 实验测试代码
├── run_experiment.sh                  # 运行脚本 (Linux/macOS)
├── run_experiment.bat                 # 运行脚本 (Windows)
├── analyze_experiment_results.py      # 结果分析脚本
├── EXPERIMENT_REPORT_TEMPLATE.md      # 报告模板
└── reports/                           # 实验报告输出目录
    ├── experiment_report_*.txt        # 原始测试输出
    └── experiment_report_*_analysis.txt # 分析后的报告
```

### 实验测试代码

`database_lock_experiment.dart` 包含4个测试组,每组3个连续测试:

- **方案1**: 测试单例模式是否会导致锁冲突
- **方案2**: 测试DatabaseTestBase的隔离效果
- **方案3**: 测试纯内存数据库的隔离效果
- **方案4**: 测试独立数据库实例的隔离效果

## 实验流程

### 1. 运行实验

选择适合你操作系统的脚本运行实验。

**Windows**:
```cmd
run_experiment.bat
```

**Linux/macOS**:
```bash
./run_experiment.sh
```

### 2. 查看原始输出

实验完成后,会生成一个包含原始测试输出的文件:

```
reports/experiment_report_20260202_143052.txt
```

这个文件包含:
- 实验时间
- 实验设计说明
- 完整的测试输出
- 错误堆栈(如果有)

### 3. 分析结果(可选)

如果你想自动分析结果,可以运行Python脚本:

```bash
python3 analyze_experiment_results.py reports/experiment_report_20260202_143052.txt
```

这会生成一个包含对比表格和分析结论的报告。

### 4. 填写实验报告

使用 `EXPERIMENT_REPORT_TEMPLATE.md` 作为模板,填写你的实验结果:

1. 复制模板
2. 根据实际测试结果填写表格
3. 分析失败原因(如果有)
4. 给出最佳实践建议

## 理解实验结果

### 测试输出解读

测试会输出类似以下内容:

```
✅ 方案1-测试1成功: 单例模式第1次运行通过
✅ 方案1-测试2成功: 单例模式第2次运行通过
❌ 方案1-测试3失败: Database is locked
```

这表示:
- 测试1和测试2成功
- 测试3遇到数据库锁定问题

### 判断方案是否有效

**有效方案**:
- ✅ 所有3个测试都通过
- ✅ 没有数据库锁定错误
- ✅ 每个测试都是独立的

**无效方案**:
- ❌ 任何一个测试失败
- ❌ 出现 "database is locked" 错误
- ❌ 测试之间相互干扰

### 推荐指数

- ⭐⭐⭐⭐⭐: 强烈推荐,完全可靠
- ⭐⭐⭐⭐: 推荐,基本可靠
- ⭐⭐⭐: 可以考虑,有局限性
- ⭐⭐: 不推荐,有问题
- ⭐: 完全不推荐,不可靠

## 实验结果示例

### 成功案例

假设所有测试都通过,对比表格如下:

| 方案 | 测试1 | 测试2 | 测试3 | 有锁冲突? | 推荐指数 |
|------|-------|-------|-------|-----------|----------|
| 方案1 | ✅ | ✅ | ❌ | 是 | ⭐⭐ |
| 方案2 | ✅ | ✅ | ✅ | 否 | ⭐⭐⭐⭐ |
| 方案3 | ✅ | ✅ | ✅ | 否 | ⭐⭐⭐⭐⭐ |
| 方案4 | ✅ | ✅ | ✅ | 否 | ⭐⭐⭐⭐⭐ |

**结论**: 方案3和方案4是最可靠的选择。

### 失败案例

假设方案1全部失败:

| 方案 | 测试1 | 测试2 | 测试3 | 有锁冲突? | 推荐指数 |
|------|-------|-------|-------|-----------|----------|
| 方案1 | ❌ | ❌ | ❌ | 是 | ⭐ |

**错误信息**:
```
DatabaseException: database is locked (errno 11)
```

**失败原因**: 单例模式导致所有测试共享同一个数据库连接,产生锁定冲突。

## 应用实验结果

### 选择推荐方案

根据实验结果,选择最优方案应用到现有测试:

**方案3 - 纯内存数据库** (推荐用于新测试):
```dart
test('新测试', () async {
  final db = await createInMemoryDatabase();
  // 使用db进行测试
  await db.close();
});
```

**方案2 - DatabaseTestBase** (推荐用于现有测试):
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

### 迁移计划

1. **阶段1**: 核心测试迁移(高优先级)
   - database_service_test.dart
   - chapter_repository_test.dart
   - character_repository_test.dart

2. **阶段2**: 扩展测试迁移(中优先级)
   - 其他服务测试
   - Repository测试

3. **阶段3**: 验证和优化
   - 运行全部测试
   - 性能对比
   - 文档更新

## 常见问题

### Q1: 实验测试运行很慢怎么办?

A: 这是正常的,因为实验创建了12个独立的数据库实例。你可以:
- 减少测试次数(修改代码中的测试数量)
- 使用更快的机器
- 只运行特定的测试组

### Q2: 实验结果不一致?

A: 确保每次实验前:
- 运行 `flutter clean`
- 关闭其他可能占用数据库的进程
- 删除旧的测试报告

### Q3: 如何修改实验?

A: 编辑 `database_lock_experiment.dart`:
- 添加新的测试方案
- 修改测试逻辑
- 调整测试数量

### Q4: 实验报告在哪里?

A: 报告保存在 `test/experiments/reports/` 目录下,文件名包含时间戳。

## 技术细节

### 方案对比

#### 方案1: DatabaseService单例
- **实现**: 直接使用 `DatabaseService()`
- **隔离**: 无隔离,共享全局单例
- **适用**: 生产环境,不适用于测试

#### 方案2: DatabaseTestBase
- **实现**: 继承 `DatabaseTestBase` 类
- **隔离**: 每个测试实例独立的内存数据库
- **适用**: 需要数据库功能的测试

#### 方案3: 纯内存数据库
- **实现**: 直接使用 `databaseFactoryFfi.openDatabase()`
- **隔离**: 完全独立,进程结束后自动释放
- **适用**: 简单的数据库操作测试

#### 方案4: 独立数据库实例
- **实现**: 创建独立的数据库和包装服务
- **隔离**: 完全独立,显式管理生命周期
- **适用**: 复杂的数据库操作测试

## 贡献指南

如果你想改进实验:

1. 修改 `database_lock_experiment.dart`
2. 添加新的测试方案
3. 更新文档
4. 运行实验验证

## 许可证

MIT License - 与主项目一致

## 联系方式

如有问题,请提交Issue或PR。

---

**最后更新**: 2026-02-02
**实验版本**: 1.0.0
