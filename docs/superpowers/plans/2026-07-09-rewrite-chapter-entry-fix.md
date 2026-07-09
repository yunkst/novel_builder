# rewrite_chapter 跳转入口修复 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `rewrite_chapter` 工具执行成功后，agent 对话流里也显示可点击的「查看重写后的整章」入口卡片，跳转到 `ReaderScreen` 并定位到重写后的章节。

**Architecture:** 修改单一 widget 文件 `agent_message_bubble.dart` 的渲染条件与文案分支，在 `create_chapter` / `update_chapter_content` 现有基础上扩出 `rewrite_chapter`。复用既有 `ChapterRewriteEntryCard` 组件（已是通用的）。后端 handler 与工具定义无需改动——数据链路早已就绪。

**Tech Stack:** Flutter 3+ / Dart 3+（用 switch 表达式，需要 SDK ≥ 3.0）

## Global Constraints

- **Dart SDK**: `>=3.0.0 <4.0.0`（`novel_app/pubspec.yaml:22`）— switch 表达式可用
- **唯一改动文件**: `novel_app/lib/widgets/agent_chat/agent_message_bubble.dart`（3 处）
- **不动**: `chapter_rewrite_entry_card.dart` / `agent_tools.dart` / `tool_executor.dart`
- **不新增组件 / 不改数据库 / 不改 LLM 调用 / 不新增自动化测试**（spec 已明确：纯 UI 渲染层扩展，手动验证覆盖）
- **commit 前**: `flutter analyze` 必须通过

## File Structure

### 修改

- `novel_app/lib/widgets/agent_chat/agent_message_bubble.dart`
  - line 353：注释补 `rewrite_chapter`
  - line 354：渲染条件补 `rewrite_chapter`
  - line 361-363：三元文案改 switch 表达式，新增 `rewrite_chapter` → "查看重写后的整章" 分支

### 不修改（明确列出防止范围蔓延）

- `novel_app/lib/widgets/agent_chat/chapter_rewrite_entry_card.dart` — 组件已通用，`parseRewriteEntry` 与 `_openInReader` 不挑工具名
- `novel_app/lib/services/novel_agent/agent_tools.dart` — `rewrite_chapter` 的 description 第 301 行已正确承诺入口
- `novel_app/lib/services/novel_agent/tool_executor.dart` — `_rewriteChapterContent` handler 第 752-760 行已返回 `success/novelUrl/chapterUrl/chapterTitle/charCount`

---

## Task 1: 在 agent_message_bubble 中为 rewrite_chapter 补渲染入口

**Files:**
- Modify: `novel_app/lib/widgets/agent_chat/agent_message_bubble.dart`（注释 line 353、条件 line 354、文案 line 361-363）

**Interfaces:**
- Consumes: `widget.call.name`（AgentToolCall 的字符串工具名）+ `widget.call.status`（AgentToolStatus）+ `parseRewriteEntry(widget.call.result)`（ChapterRewriteEntryData?）
- Produces: 触发 `ChapterRewriteEntryCard` 的渲染与点击跳转（`chapter_rewrite_entry_card.dart:103-111` 已实现 `Navigator.push(MaterialPageRoute(... ReaderScreen(...)))`）

**为什么一个 Task 包含 3 处改动**：三处改动在同一 widget 内相邻几行、彼此强耦合（条件与文案必须同步修改才能避免误渲染），原子提交更合理。reviewer 无法批准条件分支但拒绝文案分支。

- [ ] **Step 1: 读取基线**

```bash
Read novel_app/lib/widgets/agent_chat/agent_message_bubble.dart (offset 350, limit 20)
```

期望看到：line 353 注释、line 354 条件、line 361-363 三元文案，**确认无 `rewrite_chapter`**。

- [ ] **Step 2: 修改注释（line 353）**

把：

```dart
// update_chapter_content / create_chapter 成功时，渲染跳转阅读器入口
```

改成：

```dart
// update_chapter_content / create_chapter / rewrite_chapter 成功时，渲染跳转阅读器入口
```

- [ ] **Step 3: 修改渲染条件（line 354）**

把：

```dart
if ((call.name == 'update_chapter_content' || call.name == 'create_chapter') &&
    call.status == AgentToolStatus.completed &&
    _rewriteEntry != null)
```

改成：

```dart
if ((call.name == 'update_chapter_content' ||
        call.name == 'create_chapter' ||
        call.name == 'rewrite_chapter') &&
    call.status == AgentToolStatus.completed &&
    _rewriteEntry != null)
```

注意：`&&` 操作符要在三个 `||` 整体之后（保持原优先级），用缩进表达分组。

- [ ] **Step 4: 修改文案分支（line 361-363）**

把：

```dart
titleText: call.name == 'create_chapter'
    ? '查看新创建的章节'
    : '查看重写后的章节',
```

改成：

```dart
titleText: switch (call.name) {
  'create_chapter' => '查看新创建的章节',
  'rewrite_chapter' => '查看重写后的整章',
  _ => '查看重写后的章节',
},
```

- [ ] **Step 5: 静态检查**

```bash
cd novel_app && flutter analyze lib/widgets/agent_chat/agent_message_bubble.dart
```

期望输出：`No issues found!`（或类似的 zero-issue 信息）

如果报错常见原因：
- switch 表达式语法：`=>` 后必须有值，不能用 statement body
- `widget.call.name` 类型若为 `dynamic`，需先 cast 或保留为字符串字面量比较

- [ ] **Step 6: 提交**

```bash
git add novel_app/lib/widgets/agent_chat/agent_message_bubble.dart
git commit -m "fix(agent_chat): rewrite_chapter 工具补 UI 跳转入口

工具定义(agent_tools.dart:301)与 handler(tool_executor.dart:752-760)
均已承诺/提供入口所需数据,但 agent_message_bubble.dart:354 的
渲染条件只匹配 create_chapter / update_chapter_content,漏掉了
rewrite_chapter,造成 UI 与文档承诺不一致。

本次在条件里补 rewrite_chapter,文案新增'查看重写后的整章'分支
(区分于 update_chapter_content 的'查看重写后的章节'),并同步注释。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage**（逐条核对）：

| Spec 改动点 | Plan Task/Step |
| --- | --- |
| 改动 1：渲染条件补 `rewrite_chapter` | Task 1 Step 3 ✓ |
| 改动 2：标题文案分支化 | Task 1 Step 4 ✓ |
| 改动 3：注释同步 | Task 1 Step 2 ✓ |
| 验证：flutter analyze 通过 | Task 1 Step 5 ✓ |
| 范围约束：不动其他文件 | Global Constraints + File Structure ✓ |
| 不新增自动化测试 | Global Constraints ✓ |

**Placeholder scan**：无 TBD / TODO / "implement later" / "similar to N" / "handle edge cases" 等占位符。每一步都是具体动作 + 具体代码块或命令。

**Type / consistency check**：
- `call.name` 类型在 Step 3 / Step 4 都用字符串字面量，与现有代码一致
- `_rewriteEntry` getter（agent_message_bubble.dart:381-382）未改动，与 Step 3 条件用法一致
- `titleText` 参数名未变，与 `ChapterRewriteEntryCard` 构造签名一致

**Other**：
- 计划提交信息明确点出文件路径、行号、原因，让 reviewer 能秒定位
- 三处改动按"注释→条件→文案"顺序改，避免漏改
- Step 5 静态检查是质量门槛