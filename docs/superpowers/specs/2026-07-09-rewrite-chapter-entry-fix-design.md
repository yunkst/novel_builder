# rewrite_chapter 跳转入口修复 — 设计

日期：2026-07-09
模块：`novel_app`
类型：Bug 修复（UI 缺失入口）

## 背景

`WritingScenario` 中的 `rewrite_chapter` 工具（整章 AI 重写）执行成功后，agent 对话流里没有出现可点击的「查看重写后的章节」入口卡片。

`agent_tools.dart:301` 的工具 description 明确承诺了：

> 生成完成后，聊天窗口会出现可点击的跳转入口。

后端 handler `tool_executor.dart:752-760` 也返回了与 `create_chapter` 完全一致的数据结构（`success` / `novelUrl` / `chapterUrl` / `chapterTitle` / `charCount`）。

跳转入口组件 `chapter_rewrite_entry_card.dart:18-35` 的 `parseRewriteEntry` 是通用的，不挑工具名——也完全能解析 `rewrite_chapter` 的输出。

**唯一缺失的是渲染条件**：`agent_message_bubble.dart:354` 的条件只匹配 `update_chapter_content` 和 `create_chapter`，漏掉了 `rewrite_chapter`。

## 目标

让 `rewrite_chapter` 执行成功后，对话流里也出现可点击的入口卡片，点击跳转到 `ReaderScreen` 并定位到重写后的章节。卡片标题文案与现有的 `update_chapter_content`（局部字符串替换）区分开，避免用户混淆。

## 范围

### 包含

- 修改 `lib/widgets/agent_chat/agent_message_bubble.dart`：
  1. 渲染条件补 `rewrite_chapter`
  2. 三元文案改 switch 表达式，区分三种工具
  3. 同步注释

### 不包含

- 不改 `tool_executor.dart`（handler 已返回正确数据）
- 不改 `chapter_rewrite_entry_card.dart`（组件已通用）
- 不改 `agent_tools.dart`（description 已正确）
- 不改数据库、LLM 调用、Prompt 拼接等下游逻辑
- 不新增组件、不改入口跳转的目标页

## 设计

### 改动 1：渲染条件补 `rewrite_chapter`

`lib/widgets/agent_chat/agent_message_bubble.dart:354`

```dart
// 改前
if ((call.name == 'update_chapter_content' || call.name == 'create_chapter') &&
    call.status == AgentToolStatus.completed &&
    _rewriteEntry != null)

// 改后
if ((call.name == 'update_chapter_content' ||
        call.name == 'create_chapter' ||
        call.name == 'rewrite_chapter') &&
    call.status == AgentToolStatus.completed &&
    _rewriteEntry != null)
```

### 改动 2：标题文案分支化

`lib/widgets/agent_chat/agent_message_bubble.dart:361-363`

```dart
// 改前
titleText: call.name == 'create_chapter'
    ? '查看新创建的章节'
    : '查看重写后的章节',

// 改后
titleText: switch (call.name) {
  'create_chapter' => '查看新创建的章节',
  'rewrite_chapter' => '查看重写后的整章',
  _ => '查看重写后的章节',
},
```

文案选择理由：

| 工具 | 语义 | 文案 |
| --- | --- | --- |
| `create_chapter` | 新建章节 | 查看新创建的章节 |
| `rewrite_chapter` | LLM 整章重写 | 查看重写后的整章 |
| `update_chapter_content` | 局部字符串替换（不调 LLM） | 查看重写后的章节 |

「整章」明确区分 LLM 整章重写与局部替换两种「重写」语义，避免用户对结果产生歧义。

### 改动 3：注释同步

`lib/widgets/agent_chat/agent_message_bubble.dart:353`

```dart
// 改前
// update_chapter_content / create_chapter 成功时，渲染跳转阅读器入口

// 改后
// update_chapter_content / create_chapter / rewrite_chapter 成功时，渲染跳转阅读器入口
```

## 风险与权衡

### 为什么不动组件而是改条件？

`ChapterRewriteEntryCard` 已经是「重写入口」的复用组件，加一个 `rewrite_chapter` 工具无需新增组件。强行新增组件会导致：
- 文案/图标重复维护
- 入口卡片样式不一致
- 后续工具合并时更难收敛

### 为什么用 switch 表达式而不是嵌套三元？

Dart 3 switch 表达式可读性更好，未来新增工具（比如 `rewrite_section`）时只加一行 case，避免三元嵌套膨胀。

### 兼容性

Dart 3 switch 表达式需要 SDK ≥ 3.0。项目根 `pubspec.yaml` 已声明 `sdk: '>=3.0.0 <4.0.0'`，可用。

## 验证

### 静态检查

```bash
flutter analyze lib/widgets/agent_chat/agent_message_bubble.dart
```

应无 warning / error。

### 手动验证

1. 在 agent 写作场景里触发一次 `rewrite_chapter`（提供 position + rewriteInstruction）
2. 对话流里应在工具调用完成态下方出现「查看重写后的整章」可点击卡片
3. 点击卡片应跳转到 `ReaderScreen`，章节为重写后的章节
4. 现有 `create_chapter` 仍显示「查看新创建的章节」
5. 现有 `update_chapter_content` 仍显示「查看重写后的章节」

### 回归点

- `create_chapter` 入口卡片渲染不受影响
- `update_chapter_content` 入口卡片渲染不受影响
- `create_images` / `create_image_to_video` 的 `MediaGalleryCard` 不受影响（条件独立，第 367-374 行）

## 测试策略

不新增单元测试。原因：本次改动是条件分支扩展 + 文案常量替换，无新逻辑、无新数据通路，纯 UI 渲染层。手动验证（见上）即可覆盖。如果未来该组件被多处复用或出现回归，再补 widget 测试。

## 关键文件

- `lib/widgets/agent_chat/agent_message_bubble.dart` —— 本次唯一改动文件
- `lib/widgets/agent_chat/chapter_rewrite_entry_card.dart` —— 复用，不改
- `lib/services/novel_agent/agent_tools.dart` —— 工具定义，不改
- `lib/services/novel_agent/tool_executor.dart` —— handler，不改