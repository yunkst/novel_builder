---
name: flutter-unit-test
description: Use this skill when creating or reviewing unit tests for Flutter applications. This skill provides testing standards, best practices, and automated report generation. Trigger this skill when user asks to "create unit tests", "write tests for [service/widget]", "test coverage", or "generate test report".
---

# Flutter 单元测试技能

## Overview

此技能用于为 Flutter 应用创建符合标准的单元测试，并自动生成测试报告。提供测试模板、Mock 数据工厂、测试覆盖率分析，以及自动化测试报告生成功能。

## 何时使用

- 用户请求为 Flutter 服务、控制器、Widget 创建单元测试
- 用户询问测试覆盖率或测试质量
- 用户需要生成测试报告
- 代码审查时需要验证测试完整性

## 测试标准

### 命名规范

测试文件必须放在 `test/unit/` 目录下，与源码结构对应：

```
test/unit/services/          # 服务层测试
test/unit/controllers/       # 控制器测试
test/unit/widgets/           # Widget测试
test/unit/repositories/      # 仓库测试
test/test_helpers/           # 测试辅助工具
```

文件命名格式：`[filename]_test.dart`

### 测试结构

每个测试文件应包含：

```dart
import 'package:flutter_test/flutter_test.dart';
// 其他导入

/// [Service/Class Name] 单元测试
///
/// 测试[Service/Class Name]的核心功能：
/// - 功能1描述
/// - 功能2描述
/// - 功能3描述
void main() {
  // setUpAll - 全局初始化（如数据库FFI）
  setUpAll(() {
    // 一次性设置
  });

  group('[功能模块名] - [测试类别]', () {
    late [ServiceType] service;

    setUp(() {
      // 每个测试前的设置
    });

    test('[应该做什么] - [测试场景描述]', () async {
      // Arrange（准备）
      final input = ...;

      // Act（执行）
      final result = await service.method(input);

      // Assert（断言）
      expect(result, expectedValue);
    });

    tearDown(() {
      // 每个测试后的清理
    });
  });

  tearDownAll(() {
    // 全局清理
  });
}
```

### 测试用例命名规范

使用中文描述，格式：`[应该做什么] - [测试场景描述]`

示例：
- `searchChaptersByName 应该找到包含正式名称的章节`
- `extractContextAroundMatches 上下文模式应该提取正确范围`
- `estimateContentLength 空内容应该返回0`

### 必需的测试覆盖

对于每个方法，至少测试：

| 场景 | 测试用例 |
|------|---------|
| **正常情况** | 基本功能正常工作 |
| **边界情况** | 空值、null、0、空列表 |
| **异常情况** | 错误输入、网络失败 |
| **特殊场景** | 多个结果、排序、分页 |

### Mock 数据使用

优先使用 `test_helpers/mock_data.dart` 中的 MockData 工厂：

```dart
import '../../test_helpers/mock_data.dart';

final testChapter = MockData.createTestChapter(
  title: '测试章节',
  content: '测试内容',
);
```

## 测试报告生成

测试执行完成后，自动生成包含以下内容的报告：

1. **测试概览**
   - 总测试数量
   - 通过/失败数量
   - 执行时间

2. **测试详情**
   - 测试组分类
   - 每个测试用例的名称
   - 测试场景描述
   - 预期行为

3. **覆盖率分析**
   - 方法覆盖率
   - 场景覆盖率
   - 缺失的测试场景

4. **建议**
   - 未覆盖的边界情况
   - 需要补充的测试用例

## 常见测试模式

### 服务层测试（Service）

```dart
group('[ServiceName] - [功能]测试', () {
  late DatabaseService dbService;
  late ServiceName service;

  setUp(() async {
    dbService = DatabaseService();
    service = ServiceName();
    final db = await dbService.database;
    await db.delete('table_name'); // 清理测试数据
  });

  test('method 应该返回预期结果', () async {
    // 准备测试数据
    await dbService.insert(...);

    // 执行测试
    final result = await service.method();

    // 验证结果
    expect(result.length, 1);
    expect(result.first.field, expectedValue);
  });
});
```

### 数据库相关测试

```dart
setUpAll(() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
});

setUp(() async {
  // 清理数据
  final db = await dbService.database;
  await db.delete('table_name');
});
```

### 异步测试

所有异步操作使用 `async`/`await`，并设置合理的超时：

```dart
test('异步方法测试', () async {
  final result = await service.asyncMethod();
  expect(result, isNotNull);
}, timeout: const Timeout(Duration(seconds: 5)));
```

## 执行测试命令

```bash
# 运行所有测试
flutter test

# 运行特定测试文件
flutter test test/unit/services/service_name_test.dart

# 运行特定测试组
flutter test --name "搜索章节测试"

# 生成覆盖率报告
flutter test --coverage

# 查看详细输出
flutter test --verbose
```

## 工作流程

1. **分析待测试代码**
   - 识别服务/控制器的方法
   - 确定输入输出类型
   - 识别依赖和副作用

2. **创建测试文件**
   - 在对应目录创建 `*_test.dart`
   - 导入必要的依赖
   - 添加测试描述注释

3. **编写测试用例**
   - 按功能模块分组（group）
   - 使用 MockData 创建测试数据
   - 覆盖正常、边界、异常情况

4. **执行测试**
   - 运行测试验证通过
   - 检查测试覆盖率

5. **生成测试报告**
   - 汇总测试结果
   - 分析覆盖率
   - 提供改进建议

## 测试报告模板

```markdown
# [服务/组件名称] 单元测试报告

## 测试概览
- 测试文件：[文件路径]
- 总测试数：[X] 个
- 通过：[X] 个
- 失败：[X] 个
- 执行时间：[X] ms

## 测试详情

### [测试组1名称]
| 测试用例 | 场景描述 | 预期结果 | 状态 |
|---------|---------|---------|------|
| test_name | 场景说明 | 期望行为 | ✅/❌ |

### [测试组2名称]
...

## 覆盖率分析
- 方法覆盖率：[X]%
- 场景覆盖率：[X]%

## 缺失测试
- [ ] 待测试场景1
- [ ] 待测试场景2

## 建议
- 补充边界情况测试
- 添加异常处理测试
```
