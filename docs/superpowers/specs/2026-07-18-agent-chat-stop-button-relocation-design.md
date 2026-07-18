# Agent 聊天窗口停止按钮重定位设计

**日期：** 2026-07-18
**状态：** 已批准
**关联提交：** `bafe709`（A 方案：运行中允许用户补充消息注入下一轮 LLM 上下文）

## 问题

提交 `bafe709` 将 agent 聊天窗口右下角按钮从三态（停止/发送/添加图片）改为二态（发送/添加图片），停止按钮被移入补充状态条 `_buildSupplementBar`，但该条仅在 `supplementaryCount > 0` 时才显示。结果：agent 运行时若用户尚未发送补充消息，整个聊天窗口找不到停止按钮，右下角显示"添加图片"。

## 设计决策

- **保留补充消息功能**（A 方案核心能力）：运行中用户可以继续输入文字/图片，排队到下一轮 LLM
- **停止按钮独立安置在输入栏上方**：用户视线在输入时自然聚焦于底部区域，停止按钮紧邻操作区减少视线跳转，比放在 header 更直觉
- **补充条移除停止按钮**：独立停止条已提供停止入口，补充条只保留"已补充 N 条..."信息，避免两个停止按钮共存造成困惑
- **右下角行为不变**：保持 A 方案二态（发送/添加图片），不恢复三态
- **清理 `_TrailingMode.stop` 死代码**：既然不再由 `_trailingMode` 返回该值，相关枚举值、`_resolveConfig` 分支、`onStop` 参数一并移除

## 方案：独立停止条 `_buildStopBar`

### 组件结构

在 `_AgentChatDialogState` 中新增 `_buildStopBar(ScenarioSession? session)` 方法：

```
┌──────────────────────────────────┐
│  ● 正在生成回复...         [停止] │  ← 停止条（仅 isLoading 时显示）
└──────────────────────────────────┘
┌──────────────────────────────────┐
│  📝 已补充 N 条，将在下一轮处理    │  ← 补充条（supplementaryCount > 0 时显示，移除停止按钮）
└──────────────────────────────────┘
┌──────────────────────────────────┐
│  输入框...                  [✚]  │  ← 输入栏（A 方案行为不变）
└──────────────────────────────────┘
```

### Column 插入位置

在 `build` 方法的 `Column` children 中，在 `_buildErrorBar` 条件渲染之后、`RetryBanner` 之前插入停止条（补充条保持原位置）：

```dart
if (chatState.isLoading)
  _buildStopBar(session),
if (chatState.isLoading && chatState.supplementaryCount > 0)
  _buildSupplementBar(chatState.supplementaryCount, session),
```

补充条条件中的 `chatState.isLoading &&` 前缀是防御性守卫：虽然 `supplementaryCount` 仅在运行中递增，但保留双重条件确保极端边界下不会出现"非运行中却显示补充条"的 UI 异常。

### 停止条实现

```dart
/// 停止条：agent 运行时在输入栏上方始终显示，提供停止入口。
/// 与 [_buildSupplementBar] 独立，不依赖 supplementaryCount。
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

### 补充条修改

`_buildSupplementBar` 移除停止按钮，只保留信息展示：

```dart
Widget _buildSupplementBar(int count) {
  final appColors = context.appColors;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    color: appColors.agentAccent.withValues(alpha: 0.08),
    child: Row(
      children: [
        Icon(Icons.edit_note, size: 16, color: appColors.agentAccent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '已补充 $count 条消息，将在下一轮处理',
            style: TextStyle(fontSize: 12, color: appColors.agentAccent),
          ),
        ),
      ],
    ),
  );
}
```

注意：`_buildSupplementBar` 不再需要 `session` 参数。

### 死代码清理

| 位置 | 操作 |
|---|---|
| `enum _TrailingMode { attach, send, stop }`（第 1050 行） | 移除 `stop`，改为 `enum _TrailingMode { attach, send }` |
| `_resolveConfig` 中 `case _TrailingMode.stop:` 分支（约第 1168-1176 行） | 删除整个 case 分支 |
| `_AgentInputTrailingButton.onStop` 参数（第 1065 行） | 删除 |
| `_AgentInputTrailingButton` 构造函数 `this.onStop`（第 1075 行） | 删除 |
| `_buildInputBar` 中 `onStop: () => session?.cancel()`（第 873 行） | 删除 |
| `_trailingMode` 方法注释（第 997 行） | 将 `[_buildSupplementBar]` 改为 `[_buildStopBar]` |
| `_buildSupplementBar` 文档注释（第 631-633 行） | 更新为描述纯信息展示行为，注明停止已迁移至 `_buildStopBar` |

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
| `isLoading == false && error != null` | 停止条隐藏，错误条显示 |
| 补充消息队列清空 | `cancelFor()` 清空 service 层队列；`supplementaryCount` 不清零但由 `isLoading == false` 条件守卫隐藏补充条 |
| 全屏模式 | 停止条随 Column 自适应宽度，无需特殊处理 |
| 停止条颜色语义 | 使用 `error` 红色系：停止操作具有破坏性语义，红色在 UI 中强抓取注意力，符合"紧急操作"定位 |

### 改动范围

| 文件 | 改动 |
|---|---|
| `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart` | 新增 `_buildStopBar`；修改 `_buildSupplementBar` 移除停止按钮和 `session` 参数；Column 加停止条条件渲染；删除 `_TrailingMode.stop` 及相关死代码；更新 `_trailingMode` 注释 |
| `novel_app/test/unit/widgets/agent_chat_dialog_attach_test.dart` | 更新注释；修改/删除"LLM 运行时显示停止按钮"测试（从右下角查找改为停止条查找） |

### 测试要点

- `isLoading == true` 时停止条渲染，点击停止触发 `session.cancel()`
- `isLoading == false` 时停止条不渲染
- `session == null` 时停止条仍渲染，停止按钮 `onPressed` 为 null（禁用态）
- 补充条仅显示信息文字，不含停止按钮
- 停止条 + 补充条可同时显示且互不冲突（无冗余停止按钮）
- 快速连续点击停止按钮，第二次 `cancel()` 安全返回（不抛异常）
- `isSupplementary` 参数保持不变（发送按钮在运行中仍需展示"补充到下一轮"语义）
- 测试文件迁移策略：
  - `tooltip '停止'` 查找在空状态断言中保持 `isNull`（空状态不渲染停止条）
  - `tooltip '停止'` 查找在运行态测试中改为查找停止条内的 `TextButton.icon`（label '停止'），而非右下角 `IconButton`
  - 确认 `_TrailingMode.stop` 枚举值被移除后无编译错误