# Agent 聊天窗口停止按钮重定位实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 agent 聊天窗口输入栏上方新增独立停止条，agent 运行时始终可见；补充条移除停止按钮；清理 `_TrailingMode.stop` 死代码。

**架构：** 在 `_AgentChatDialogState` 中新增 `_buildStopBar` 方法，在 Column children 中 `_buildErrorBar` 之后、`RetryBanner` 之前插入条件渲染。停止操作复用现有 `session.cancel()` 路径，不引入新状态。补充条改为纯信息展示，移除 `session` 参数和停止按钮。

**技术栈：** Flutter/Dart，Riverpod，Material 3

**规格文档：** `docs/superpowers/specs/2026-07-18-agent-chat-stop-button-relocation-design.md`

---

## 文件结构

| 文件 | 职责 | 改动类型 |
|---|---|---|
| `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart` | 聊天窗口 UI 组件 | 修改 |
| `novel_app/test/unit/widgets/agent_chat_dialog_attach_test.dart` | 输入栏按钮 + 停止条渲染测试 | 修改 |

---

### 任务 1：新增 `_buildStopBar` 方法 + Column 插入

**文件：**
- 修改：`novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart`

- [ ] **步骤 1：在 `_buildSupplementBar` 方法上方添加 `_buildStopBar` 方法**

在 `_buildSupplementBar` 方法定义之前（第 631 行之前）插入以下代码：

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

- [ ] **步骤 2：在 Column children 中插入停止条条件渲染**

在第 178 行（`if (chatState.isLoading && chatState.supplementaryCount > 0)` 之前）插入一行：

```dart
              if (chatState.isLoading)
                _buildStopBar(session),
```

插入后 Column children 变为：

```dart
              if (chatState.error != null && !chatState.isLoading)
                _buildErrorBar(chatState.error!, session),
              if (chatState.isLoading)
                _buildStopBar(session),
              if (chatState.isLoading && chatState.supplementaryCount > 0)
                _buildSupplementBar(chatState.supplementaryCount, session),
              const RetryBanner(),
```

- [ ] **步骤 3：验证编译通过**

```bash
cd novel_app && flutter analyze lib/widgets/agent_chat/agent_chat_dialog.dart
```

预期：无错误。

- [ ] **步骤 4：Commit**

```bash
git add novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart
git commit -m "feat(agent-chat): 新增独立停止条 _buildStopBar，agent 运行时始终可见"
```

---

### 任务 2：修改 `_buildSupplementBar` 为纯信息展示

**文件：**
- 修改：`novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart`

- [ ] **步骤 1：更新 `_buildSupplementBar` 文档注释**

将第 631-633 行：

```dart
  /// A 方案：运行中补充消息状态条。
  /// 显示"已补充 N 条，将在下一轮处理"+ 停止按钮（主动取消走 cancel 路径，
  /// 队列内的补充消息也会被 cancelFor 一并清空）。
```

替换为：

```dart
  /// A 方案：运行中补充消息状态条。
  /// 仅显示"已补充 N 条，将在下一轮处理"信息，不提供停止入口
  /// （停止操作已迁移至独立的 [_buildStopBar]）。
```

- [ ] **步骤 2：修改方法签名，移除 `session` 参数**

将第 634 行：

```dart
  Widget _buildSupplementBar(int count, ScenarioSession? session) {
```

改为：

```dart
  Widget _buildSupplementBar(int count) {
```

- [ ] **步骤 3：移除停止按钮 Row child**

删除 `TextButton.icon(...)` 整个 widget（当前代码中该 `TextButton.icon` 前没有 `SizedBox`，直接删除即可）。最终方法体为：

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

- [ ] **步骤 4：更新 Column 中调用点，移除 `session` 参数**

将第 179 行：

```dart
                _buildSupplementBar(chatState.supplementaryCount, session),
```

改为：

```dart
                _buildSupplementBar(chatState.supplementaryCount),
```

- [ ] **步骤 5：验证编译通过**

```bash
cd novel_app && flutter analyze lib/widgets/agent_chat/agent_chat_dialog.dart
```

预期：无错误（补充条方法签名变更后，唯一调用点已同步更新）。

- [ ] **步骤 6：Commit**

```bash
git add novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart
git commit -m "refactor(agent-chat): 补充条改为纯信息展示，移除停止按钮和 session 参数"
```

---

### 任务 3：清理 `_TrailingMode.stop` 死代码

**文件：**
- 修改：`novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart`

- [ ] **步骤 1：删除 `_TrailingMode.stop` 枚举值**

将第 1084 行：

```dart
enum _TrailingMode { attach, send, stop }
```

改为：

```dart
enum _TrailingMode { attach, send }
```

- [ ] **步骤 2：删除 `_resolveConfig` 中 `case _TrailingMode.stop:` 分支**

删除第 1188-1196 行：

```dart
      case _TrailingMode.stop:
        return _TrailingButtonConfig(
          icon: Icons.stop_rounded,
          bg: appColors.error,
          fg: appColors.agentOnBrand,
          onPressed: onStop,
          tooltip: '停止',
        );
```

- [ ] **步骤 3：删除 `_AgentInputTrailingButton.onStop` 字段**

删除第 1099 行：

```dart
  final VoidCallback? onStop;
```

- [ ] **步骤 4：删除构造函数中 `this.onStop` 参数**

将第 1103-1110 行的构造函数：

```dart
  const _AgentInputTrailingButton({
    required this.mode,
    this.isPickingImage = false,
    this.isSupplementary = false,
    this.onAttach,
    this.onSend,
    this.onStop,
  });
```

改为：

```dart
  const _AgentInputTrailingButton({
    required this.mode,
    this.isPickingImage = false,
    this.isSupplementary = false,
    this.onAttach,
    this.onSend,
  });
```

- [ ] **步骤 5：删除 `_buildInputBar` 中 `onStop:` 传参**

将 `_AgentInputTrailingButton` 调用中的 `onStop: () => session?.cancel(),`（约第 907 行）删除。

```dart
                onStop: () => session?.cancel(),
```

删除（连同该行末尾的逗号如影响格式）。

`_AgentInputTrailingButton` 调用变为：

```dart
              _AgentInputTrailingButton(
                mode: _trailingMode(chatState),
                isPickingImage: _isPickingImage,
                isSupplementary: chatState.isLoading,
                onAttach: _onAttachTap,
                onSend: () => _sendMessage(session),
              ),
```

- [ ] **步骤 6：更新 `_trailingMode` 方法注释**

将第 997 行：

```dart
  /// 主动取消按钮改由 [_buildSupplementBar] 顶部条提供（仅 isLoading 时显示）。
```

改为：

```dart
  /// 主动取消按钮改由 [_buildStopBar] 顶部条提供（仅 isLoading 时显示）。
```

- [ ] **步骤 7：验证编译通过**

```bash
cd novel_app && flutter analyze lib/widgets/agent_chat/agent_chat_dialog.dart
```

预期：无错误，且无 `_TrailingMode.stop` 或 `onStop` 的"未使用"或"未定义"警告。

- [ ] **步骤 8：Commit**

```bash
git add novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart
git commit -m "refactor(agent-chat): 清理 _TrailingMode.stop 死代码，移除 onStop 回调链"
```

---

### 任务 4：更新测试文件

**文件：**
- 修改：`novel_app/test/unit/widgets/agent_chat_dialog_attach_test.dart`

- [ ] **步骤 1：更新测试文件头部注释**

将第 36-39 行：

```dart
  // 输入栏重构（2026-07-16）后右侧三态按钮的状态机：
  //   isLoading (运行中)  -> 停止
  //   有文本 OR 有图     -> 发送
  //   完全空 (无文无图)  -> 添加图片
```

替换为：

```dart
  // 输入栏右侧二态按钮（A 方案，2026-07-18）：
  //   有文本 OR 有图     -> 发送（运行中为"补充到下一轮"）
  //   完全空 (无文无图)  -> 添加图片
  // 停止操作已迁移至输入栏上方的独立停止条 _buildStopBar。
```

- [ ] **步骤 2：重写"LLM 运行时显示停止按钮"测试**

将第 67-85 行的测试：

```dart
    testWidgets('LLM 运行时显示「停止」按钮，运行态覆盖文本/图片态',
        (tester) async {
      await tester.pumpWidget(
        _wrap(state: const AgentChatState(isLoading: true)),
      );
      await tester.pump();
      final stopBtn = _findIconButtonByTooltip(tester, '停止');
      expect(stopBtn, isNotNull, reason: '运行中右侧应显示停止按钮');
      expect(stopBtn!.onPressed, isNotNull, reason: '停止按钮应可点击');
      expect(_findIconButtonByTooltip(tester, '发送'), isNull);
      expect(_findIconButtonByTooltip(tester, '添加图片'), isNull);

      // 运行中输入文字也不应让按钮切到发送态（运行态最高优先级）
      await tester.enterText(find.byType(TextField), '排队等待的消息');
      await tester.pump();
      expect(_findIconButtonByTooltip(tester, '停止'), isNotNull,
          reason: '运行态期间即便有文本仍应是停止按钮');
      expect(_findIconButtonByTooltip(tester, '发送'), isNull);
    });
```

替换为：

```dart
    testWidgets('LLM 运行时显示停止条（_buildStopBar），不在右下角', (tester) async {
      await tester.pumpWidget(
        _wrap(state: const AgentChatState(isLoading: true)),
      );
      await tester.pump();

      // 停止条存在：查找 TextButton.icon 中 label 为 '停止' 的按钮
      final stopButtons = find.widgetWithText(TextButton, '停止');
      expect(stopButtons, findsOneWidget,
          reason: '运行中应显示停止条，包含一个 TextButton「停止」');

      // 右下角不再有停止按钮（_TrailingMode.stop 已移除）
      expect(_findIconButtonByTooltip(tester, '停止'), isNull,
          reason: '右下角不应再有停止 IconButton');

      // 右下角空状态应显示添加图片按钮（A 方案二态）
      expect(_findIconButtonByTooltip(tester, '添加图片'), findsOneWidget);

      // 运行中输入文字后：右下角切为发送（补充到下一轮），停止条仍在
      await tester.enterText(find.byType(TextField), '排队等待的消息');
      await tester.pump();
      expect(find.widgetWithText(TextButton, '停止'), findsOneWidget,
          reason: '停止条在输入文字后仍应存在');
      expect(_findIconButtonByTooltip(tester, '发送'), findsOneWidget,
          reason: '运行中有文本时右下角应显示发送（补充到下一轮）');
    });
```

- [ ] **步骤 2b：新增 `session == null` 时停止按钮禁用测试**

在步骤 2 的测试用例之后追加：

```dart
    testWidgets('session 为 null 时停止条仍渲染但停止按钮禁用', (tester) async {
      // 通过 override currentSessionProvider 返回 null 模拟无 session
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSessionProvider.overrideWith((ref) => null),
          ],
          child: _wrap(state: const AgentChatState(isLoading: true)),
        ),
      );
      await tester.pump();

      // 停止条存在
      final stopBtn = find.widgetWithText(TextButton, '停止');
      expect(stopBtn, findsOneWidget);
      // onPressed 为 null → 按钮禁用
      final btn = tester.widget<TextButton>(stopBtn);
      expect(btn.onPressed, isNull,
          reason: 'session 为 null 时停止按钮应被禁用');
    });
```

- [ ] **步骤 2c：新增"补充条不含停止按钮"和"两条同时显示"测试**

在步骤 2b 之后追加：

```dart
    testWidgets('运行中 + 补充计数 > 0 时，停止条和补充条同时显示且补充条无停止按钮',
        (tester) async {
      await tester.pumpWidget(
        _wrap(state: const AgentChatState(
          isLoading: true,
          supplementaryCount: 3,
        )),
      );
      await tester.pump();

      // 停止条存在（findsOneWidget = 仅停止条中的那一个）
      expect(find.widgetWithText(TextButton, '停止'), findsOneWidget,
          reason: '仅停止条中有停止按钮，补充条已移除停止按钮');

      // 补充条约文字可见
      expect(find.text('已补充 3 条消息，将在下一轮处理'), findsOneWidget);
    });
```

- [ ] **步骤 3：运行测试验证**

```bash
cd novel_app && flutter test test/unit/widgets/agent_chat_dialog_attach_test.dart
```

预期：全部测试通过，包括重写后的停止条测试。

- [ ] **步骤 4：运行全部 agent_chat 相关测试确保无回归**

```bash
cd novel_app && flutter test test/unit/widgets/agent_chat/
```

预期：全部通过。

- [ ] **步骤 5：Commit**

```bash
git add novel_app/test/unit/widgets/agent_chat_dialog_attach_test.dart
git commit -m "test(agent-chat): 更新测试适配停止条方案，移除 _TrailingMode.stop 查找"
```

---

### 任务 5：端到端验证

**无需修改文件，仅验证。**

- [ ] **步骤 1：运行完整测试套件**

```bash
cd novel_app && flutter test
```

预期：全部通过，无回归。

- [ ] **步骤 2：手动验证清单**

以下场景需要在真机/模拟器上手动验证：

| 场景 | 预期 |
|---|---|
| 点击"添加到书架"→ agent 开始运行 | 输入栏上方出现红色停止条"● 正在生成回复... [停止]" |
| 点击停止条 [停止] | agent 停止，停止条消失 |
| 运行中输入文字并发送 | 右下角按钮为半透明"补充到下一轮"，停止条仍在 |
| 补充消息发送后 | 补充条出现"已补充 N 条..."（无停止按钮），停止条仍在 |
| agent 空闲时 | 停止条和补充条都不显示，右下角正常显示添加图片/发送 |
| 全屏模式 | 停止条随宽度自适应 |

- [ ] **步骤 3：验证完成后 Commit（如有微调）**

```bash
git add -A && git commit -m "chore: 端到端验证通过，停止条重定位完成"
```