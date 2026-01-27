# 特写替换功能失效诊断指南

## 快速诊断流程

### 步骤1: 检查基础替换逻辑 ✅

**测试命令**:
```bash
cd novel_app
flutter test test/unit/paragraph_replace_logic_test.dart
```

**预期结果**: 所有12个测试应该通过

**如果测试失败** → 核心代码有问题，需要修复
**如果测试通过** → 继续下一步诊断

---

### 步骤2: 检查日志输出

在运行应用时，查找以下关键日志：

```dart
📝 准备替换: 删除 X 段，插入 Y 段
🗑️ 删除段落 N: "内容"
✅ 在位置 X 插入 Y 段内容
```

**如果看到这些日志** → 替换逻辑已执行，问题可能在回调
**如果没有看到这些日志** → `_executeDeleteAndInsert` 未被调用

---

### 步骤3: 验证UI交互

#### 3.1 检查按钮状态

**位置**: `paragraph_rewrite_dialog.dart` 第574-582行

```dart
ElevatedButton.icon(
  onPressed: (_rewriteResult.isEmpty || isStreaming)
      ? null
      : () {
          _replaceSelectedParagraphs();
        },
  icon: const Icon(Icons.check),
  label: const Text('替换'),
)
```

**检查点**:
- [ ] "替换"按钮是否可点击（不是灰色）
- [ ] `_rewriteResult` 是否有内容
- [ ] `isStreaming` 是否为 `false`

#### 3.2 验证用户操作流程

1. 选择段落 → 应该弹出"输入改写要求"对话框
2. 输入要求并确认 → 应该显示"AI正在改写内容..."
3. AI生成完成 → 应该显示改写结果
4. 点击"替换"按钮 → 应该执行替换逻辑

---

### 步骤4: 检查回调函数

**位置**: 调用 `ParagraphRewriteDialog` 的地方

```dart
ParagraphRewriteDialog(
  onReplace: (newContent) {
    // ⚠️ 关键：这里是否正确实现了？
    // 1. 是否更新了章节内容？
    // 2. 是否保存到了数据库？
    // 3. 是否刷新了UI？
  },
)
```

**常见问题**:

#### 问题1: 回调未实现
```dart
// ❌ 错误示例
onReplace: (newContent) {
  print('新内容: $newContent');
  // 没有实际更新内容！
}

// ✅ 正确示例
onReplace: (newContent) {
  setState(() {
    widget.chapter.content = newContent; // 更新内容
  });
  _saveChapter(); // 保存到数据库
}
```

#### 问题2: 状态未更新
```dart
// ❌ 错误示例
onReplace: (newContent) {
  widget.chapter.content = newContent;
  // 忘记调用 setState！
}

// ✅ 正确示例
onReplace: (newContent) {
  setState(() {
    widget.chapter.content = newContent;
  });
}
```

---

### 步骤5: 添加调试日志

在 `paragraph_rewrite_dialog.dart` 的关键位置添加日志：

```dart
void _replaceSelectedParagraphs() {
  debugPrint('🔍 === 开始替换流程 ===');
  debugPrint('选中索引: ${widget.selectedParagraphIndices}');
  debugPrint('改写结果长度: ${_rewriteResult.length}');

  final paragraphs = widget.content.split('\n');
  debugPrint('原文段落数: ${paragraphs.length}');

  final rewrittenParagraphs = _rewriteResult.split('\n');
  debugPrint('AI生成段落数: ${rewrittenParagraphs.length}');

  // ... 原有代码
}

void _executeDeleteAndInsert(...) {
  debugPrint('🔍 === 执行删除和插入 ===');
  debugPrint('删除索引: $indicesToDelete');
  debugPrint('插入内容: ${contentToInsert.join(", ")}');

  // ... 原有代码

  debugPrint('✅ === 替换完成 ===');
  debugPrint('新内容长度: ${newContent.length}');

  widget.onReplace(newContent);
  debugPrint('📞 已调用 onReplace 回调');
}
```

---

## 常见问题排查

### 问题1: 点击"替换"按钮无反应

**可能原因**:
1. 按钮被禁用（`isStreaming` 为 `true`）
2. `_rewriteResult` 为空

**排查方法**:
```dart
// 在按钮 onPressed 中添加日志
onPressed: () {
  debugPrint('替换按钮点击');
  debugPrint('_rewriteResult是否为空: ${_rewriteResult.isEmpty}');
  debugPrint('isStreaming: $isStreaming');
  _replaceSelectedParagraphs();
}
```

---

### 问题2: 替换后内容未更新

**可能原因**:
1. `onReplace` 回调未正确实现
2. 回调中未调用 `setState`
3. 未保存到数据库

**排查方法**:
```dart
// 在回调中添加日志
onReplace: (newContent) {
  debugPrint('📞 onReplace 被调用');
  debugPrint('新内容: ${newContent.substring(0, 100)}...');

  setState(() {
    widget.chapter.content = newContent;
    debugPrint('✅ setState 已调用');
  });

  _saveToDatabase().then((_) {
    debugPrint('✅ 已保存到数据库');
  });
}
```

---

### 问题3: 对话框关闭但内容未变化

**可能原因**:
1. `onReplace` 回调的参数未正确传递
2. UI未刷新

**排查方法**:
```dart
// 在 _executeDeleteAndInsert 中验证
final newContent = updatedParagraphs.join('\n');
debugPrint('新内容第一行: ${newContent.split('\n').first}');

widget.onReplace(newContent);
Navigator.pop(context);

// 在父组件中验证
onReplace: (newContent) {
  debugPrint('收到内容第一行: ${newContent.split('\n').first}');

  setState(() {
    final oldContent = widget.chapter.content;
    widget.chapter.content = newContent;

    debugPrint('内容是否变化: ${oldContent != newContent}');
  });
}
```

---

### 问题4: AI生成内容为空

**可能原因**:
1. Dify服务返回空内容
2. 网络请求失败
3. 特殊标记处理错误

**排查方法**:
```dart
// 在 _generateRewrite 中添加日志
await callDifyStreaming(
  inputs: inputs,
  onChunk: (chunk) {
    debugPrint('收到文本块: "$chunk"');
    setState(() {
      _rewriteResult += chunk;
    });
  },
  // ...
);

// 在生成完成后检查
debugPrint('AI生成完成，内容长度: ${_rewriteResult.length}');
debugPrint('内容预览: ${_rewriteResult.substring(0, 100)}...');
```

---

## 完整诊断示例

### 场景：用户点击替换后无反应

**1. 添加日志到按钮**:
```dart
ElevatedButton.icon(
  onPressed: (_rewriteResult.isEmpty || isStreaming)
      ? null
      : () {
          debugPrint('🔵 替换按钮被点击');
          debugPrint('🔵 改写结果长度: ${_rewriteResult.length}');
          debugPrint('🔵 是否正在生成: $isStreaming');
          _replaceSelectedParagraphs();
        },
  // ...
)
```

**2. 运行应用并点击按钮**

**3. 查看日志输出**

**如果看到**:
```
🔵 替换按钮被点击
🔵 改写结果长度: 150
🔵 是否正在生成: false
🔍 === 开始替换流程 ===
🗑️ 删除段落 1: "第二段"
✅ 在位置 1 插入 3 段内容
✅ === 替换完成 ===
📞 已调用 onReplace 回调
```

**结论**: 替换逻辑正常执行，问题在 `onReplace` 回调

**如果没有看到**:
```
🔵 替换按钮被点击
🔵 改写结果长度: 0  // ← 问题在这里！
```

**结论**: AI生成内容为空，需要检查 Dify 服务

---

## 下一步行动

根据诊断结果：

### 如果核心逻辑有问题
→ 回归到步骤1，修复单元测试

### 如果回调有问题
→ 检查调用 `ParagraphRewriteDialog` 的父组件
→ 确保 `onReplace` 正确实现

### 如果UI有问题
→ 检查状态管理
→ 确保 `setState` 被正确调用

### 如果数据保存有问题
→ 检查数据库服务
→ 验证保存逻辑

---

## 联系开发者

如果以上步骤都无法解决问题，请提供：

1. 完整的日志输出
2. 单元测试结果
3. 具体的问题描述和重现步骤
4. Flutter版本和设备信息

---

**文档版本**: 1.0
**最后更新**: 2026-01-26
