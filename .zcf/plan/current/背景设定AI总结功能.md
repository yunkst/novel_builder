# 背景设定AI总结功能

## 任务概述
在章节背景设定页面新增总结按钮,点击后弹出弹框进行内容总结,逻辑上和章节总结一样。

## 执行时间
开始时间: 2026-01-26 00:09:14

## 技术上下文
- **目标页面**: `BackgroundSettingScreen` (已有自动保存、修改检测功能)
- **参考组件**: `ChapterSummaryDialog` (流式生成、确认对话框、复制功能)
- **AI服务**: DifyStreamingMixin
- **数据库**: DatabaseService.updateBackgroundSetting()

## 执行方案
采用**方案1**: 复用 ChapterSummaryDialog + 参数适配

## 实施步骤

### 步骤 1: 创建 BackgroundSummaryDialog 组件 ✅
**文件**: `novel_app/lib/widgets/reader/background_summary_dialog.dart`

**关键内容**:
- 继承 StatefulWidget,使用 DifyStreamingMixin
- 构造函数参数: `novel: Novel`, `backgroundText: String`
- UI结构:
  - 确认对话框(是否总结)
  - 流式生成状态显示
  - 总结结果显示
  - 重新总结和复制按钮
- 总结完成后自动更新数据库并关闭弹框

**状态**: 已完成

### 步骤 2: 修改 BackgroundSettingScreen 添加总结按钮 ✅
**文件**: `novel_app/lib/screens/background_setting_screen.dart`

**修改点**:
1. 导入新组件: `import '../widgets/reader/background_summary_dialog.dart';`
2. 在 AppBar 的 actions 中添加 IconButton (位于保存按钮之前)
3. 添加 `_showSummaryDialog()` 方法
4. 添加 `_reloadBackgroundSetting()` 方法,使用 `getBackgroundSetting()` 重新加载数据

**状态**: 已完成

### 步骤 3: 实现总结 Prompt 逻辑 ✅
**位置**: BackgroundSummaryDialog._buildSummaryPrompt()

**Prompt 设计**:
```
请对以下小说背景设定进行AI总结,提取关键信息:

背景设定:
[背景设定文本]

要求:
1. 保留核心世界观、设定要点
2. 精简冗余描述
3. 保持逻辑连贯
4. 字数控制在原文的30%-50%
5. 输出纯文本,不需要格式标记

请开始总结:
```

**状态**: 已完成

### 步骤 4: 处理总结结果更新 ✅
**位置**: BackgroundSummaryDialog._saveSummary()

**逻辑**:
1. 调用 `DatabaseService.updateBackgroundSetting()`
2. 显示成功提示
3. 延迟500ms关闭对话框(让用户看到提示)
4. 返回 true 给父组件

**状态**: 已完成

### 步骤 5: 添加必要的导入和依赖检查 ✅
**文件**: background_summary_dialog.dart

**导入列表**:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/novel.dart';
import '../../services/database_service.dart';
import '../../mixins/dify_streaming_mixin.dart';
```

**状态**: 已完成,所有依赖正确导入

## 代码变更总结

### 新增文件
- `novel_app/lib/widgets/reader/background_summary_dialog.dart` (313行)

### 修改文件
- `novel_app/lib/screens/background_setting_screen.dart`
  - 添加导入: `background_summary_dialog.dart`
  - 添加 `_showSummaryDialog()` 方法
  - 添加 `_reloadBackgroundSetting()` 方法
  - AppBar actions 添加总结按钮

## 编译验证
✅ flutter analyze 无错误
✅ 无警告

## 功能特性
1. **确认对话框**: 防止误操作
2. **流式生成**: 实时显示AI生成进度
3. **自动保存**: 生成完成后自动替换原有背景设定
4. **重新总结**: 支持不满意时重新生成
5. **复制功能**: 方便用户复制总结结果
6. **数据刷新**: 总结完成后自动刷新页面内容

## 测试要点
1. 背景设定为空时点击总结按钮
2. 背景设定有内容时点击总结按钮
3. 流式生成过程中的取消操作
4. 总结完成后自动刷新页面
5. 重新总结功能
6. 复制功能

## 待确认
- [ ] 用户确认功能符合预期
- [ ] 进入优化阶段检查代码质量
