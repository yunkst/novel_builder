# Agent 聊天窗口停止按钮重定位设计

**日期：** 2026-07-18  
**状态：** 已批准  
**关联提交：** `bafe709`（A 方案：运行中允许用户补充消息注入下一轮 LLM 上下文）

## 问题

提交 `bafe709` 将 agent 聊天窗口右下角按钮从三态（停止/发送/添加图片）改为二态（发送/添加图片），停止按钮被移入补充状态条 `_buildSupplementBar`，但该条仅在 `supplementaryCount > 0` 时才显示。结果：agent 运行时若用户尚未发送补充消息，整个聊天窗口找不到停止按钮，右下角显示"添加图片"。

## 设计决策

- **保留补充消息功能**（A 方案核心能力）：运行中用户可以继续输入文字/图片，排队到下一轮 LLM
- **停止按钮独立安置**：在输入栏上方新增独立停止条，agent 运行时始终可见
- **右下角行为不变**：保持 A 方案二态（发送/添加图片），不恢复三态

## 方案：独立停止条 `_buildStopBar`

### 组件结构

在 `_AgentChatDialogState` 中新增 `_buildStopBar(ScenarioSession? session)` 方法：

```
┌──────────────────────────────────┐
│  ● 正在生成回复...         [停止] │  ← 停止条（仅 isLoading 时显示）
└──────────────────────────────────┘
┌──────────────────────────────────┐
│  📝 已补充 N 条...          [停止] │  ← 补充条（supplementaryCount > 0 时显示，不变）
└──────────────────────────────────┘
┌──────────────────────────────────┐
│  输入框...                  [✚]  │  ← 输入栏（A 方案行为不变）
└──────────────────────────────────┘
```

停止条和补充条是两个独立组件，互不依赖。

### Column 插入位置

在 `build` 方法的 `Column` children 中，停止条放在补充条**上方**：

```dart
if (chatState.isLoading)
  _buildStopBar(session),
if (chatState.isLoading && chatState.supplementaryCount > 0)
  _buildSupplementBar(chatState.supplementaryCount, session),
```

### 停止条实现

```dart
Widget _buildStopBar(ScenarioSession? session) {
  final appColors = context.appColors;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    color: appColors.error.withValues(alpha: 0.06),
    child: Row(
      children: [
        Icon(Icons.circle, size: 8, color: appColors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '正在生成回复...',
            style: TextStyle(fontSize: 12, color: appColors.error),
          ),
        ),
        TextButton.icon(
          onPressed: session == null ? null : () => session.cancel(),
          icon: const Icon(Icons.stop_rounded, size: 16),
          label: const Text('停止', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: appColors.error,
          ),
        ),
      ],
    ),
  );
}
```

### 数据流（无新增状态）

```
ScenarioSession._state.isLoading == true   → 显示停止条
ScenarioSession._state.isLoading == false  → 隐藏停止条
```

停止操作复用现有 `session.cancel()` 路径，无需新增 provider 或状态字段。

### 错误处理 & 边界情况

| 场景 | 行为 |
|---|---|
| `session == null` | 停止按钮 `onPressed` 为 null，自动禁用 |
| 快速连续点击停止 | `cancel()` 内部有幂等保护（`_isRunning == false` 时 return） |
| 停止条 + 错误条共存 | 不会。`isLoading` 时错误条不渲染，`isLoading` 变 false 后停止条已隐藏 |
| 补充消息队列清空 | `cancel()` 调用 `cancelFor()` 清空，行为不变 |
| 全屏模式 | 停止条随 Column 自适应宽度，无需特殊处理 |

### 改动范围

| 文件 | 改动 |
|---|---|
| `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart` | 新增 `_buildStopBar` 方法 + Column 中加一行条件渲染 + 更新 `_trailingMode` 注释 |
| `novel_app/test/unit/widgets/agent_chat_dialog_attach_test.dart` | 更新第 36-39 行注释（三态 → 停止条方案） |

### 测试要点

- `isLoading == true` 时停止条渲染，点击停止触发 `session.cancel()`
- `isLoading == false` 时停止条不渲染
- 补充条行为不变（仅在 `supplementaryCount > 0` 时出现）
- 停止条 + 补充条可同时显示且互不冲突