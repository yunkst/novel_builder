# Agent Chat 晨读书馆风重做 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `widgets/agent_chat/` 从 indigo 渐变 + emoji + 多色 status bar 的 1230 行巨石，重做为接入「晨读书馆」设计语言的多个聚焦组件（Header / StatusStrip / Messages / Composer），亮/暗同源。

**Architecture:** 只重写表达层。新建 4 个 widget + 1 个 icon 常量集；扩展 1 个通用空状态组件；改 3 个文件配色/emoji；瘦身 dialog 到 shell。**不动** `AgentLoop` / `ScenarioSession` / `AgentChatState` / `AgentChatSegment` sealed 类 / Riverpod providers / DB schema / 事件协议。状态合并：5 个手写 status bar -> 1 条 `AgentStatusStrip`（`selectStatus` 纯函数判定 `error > retry > supplement`，普通运行态不显示）。

**Tech Stack:** Flutter 3 / Dart / Riverpod 2.4 / flutter_markdown 0.6 / **Material Icons（`IconData`，非 SVG--项目无 `flutter_svg` 依赖，遵循零新增依赖）** / Noto Serif SC + Noto Sans SC（已打包）/ `AppColors` ThemeExtension（晨读亮 / 暗夜暗两套 const）

## Global Constraints

（每个 task 的需求隐含包含本节，逐条 verbatim 自 spec §2/§3/§7/§9）

- **不动层**：`AgentLoop` / `ScenarioSession` / `AgentChatState`（`core/providers/agent_chat_state.dart`）/ `AgentChatSegment` sealed 类 / 所有 Riverpod providers / DB schema / 事件协议 / `ScenarioIds` 常量。
- **不改切场景行为**：`currentAgentScenarioProvider` + `currentChatSessionIdProvider=null` + `scenarioSessionsProvider.get(id)` 逻辑（`agent_chat_dialog.dart:252-264`）保持原样；历史不丢。
- **组件只用 `AppColors` 语义 token**（`paper`/`ink`/`inkSoft`/`chatButtonPrimary`/`chatInputBackground`/`chatPrimaryText`/`chatHintText`/`chatDivider`/`divider`/`error`/`avatarShadow`/`agentOnBrand`/`agentAccent`），**禁止** `if(Theme.dark)`、**禁止**硬编码 `Colors.white`/`Colors.black54`/`Colors.orange`/`Colors.blue`。
- **不新增 `AppColors` 字段**；**不启用冷调遗留 token**（`chatRoleBubble`/`chatUserBubble`/`chatUserBubbleBorder`/`chatButtonDisabled`，Dify 时代冷蓝/绿黄）。
- **icon 用 Material `IconData`**（集中到 `agent_icons.dart`），**禁止** emoji `Text` 当图标。
- **测试**：`flutter analyze` 0 issue + 相关 `flutter test` 通过 + 亮/暗目视，每 task 末 `git commit`。
- **提交**：Conventional Commits 中文描述（`refactor(agent-chat): ...` / `feat(agent-chat): ...` / `test(agent-chat): ...` / `style(agent-chat): ...`）。

---

### Task 1: token 契约测试 + 冷调遗留标注

**Files:**
- Create: `novel_app/test/unit/core/theme/app_colors_test.dart`
- Modify: `novel_app/lib/core/theme/app_colors.dart`（`chatRoleBubble`/`chatUserBubble`/`chatUserBubbleBorder`/`chatButtonDisabled` 字段加 `@Deprecated` 文档注释；**不删字段**，避免破坏 const 引用与 copyWith）

**Interfaces:**
- Consumes: `AppColors.light` / `AppColors.dark`（`app_colors.dart:152`/`:198`）
- Produces: token 契约测试（后续 task 改 `app_colors.dart` 时回归保护）

- [ ] **Step 1: 写失败测试**

Create `novel_app/test/unit/core/theme/app_colors_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/theme/app_colors.dart';

void main() {
  /// 晨读书馆重做依赖的暖调 token：亮/暗都必须非 null 且不同值（防回归）。
  /// 冷调遗留 token（chatRoleBubble/chatUserBubble/...）不纳入断言，待清理。
  const warmTokens = <String, Function(AppColors)>{
    'paper': (c) => c.paper,
    'ink': (c) => c.ink,
    'inkSoft': (c) => c.inkSoft,
    'chatButtonPrimary': (c) => c.chatButtonPrimary,
    'chatInputBackground': (c) => c.chatInputBackground,
    'chatPrimaryText': (c) => c.chatPrimaryText,
    'chatHintText': (c) => c.chatHintText,
    'chatDivider': (c) => c.chatDivider,
    'error': (c) => c.error,
  };

  for (final entry in warmTokens.entries) {
    test('${entry.key} 亮/暗均非 null 且不同值', () {
      final light = entry.value(AppColors.light);
      final dark = entry.value(AppColors.dark);
      expect(light, isNotNull, reason: '${entry.key} light 为 null');
      expect(dark, isNotNull, reason: '${entry.key} dark 为 null');
      expect(light, isNot(equals(dark)),
          reason: '${entry.key} 亮/暗同值（应不同明度）');
    });
  }
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/core/theme/app_colors_test.dart`
Expected: PASS（token 已存在；此测试是回归保护网，先确认它绿）。若某 token 亮暗同值则 FAIL，按 spec §3 修正 `app_colors.dart` 对应字段。

- [ ] **Step 3: 给冷调遗留 token 加标注**

In `app_colors.dart`，找到 `dark` const（`:198`）上方字段定义区，给 4 个冷调遗留字段加文档注释。在 `light`（`:152`）和 `dark`（`:198`）两处对应字段行上方各加：

```dart
    // 容器色 · 米白纸感
    // chatRoleBubble/chatUserBubble/chatUserBubbleBorder/chatButtonDisabled:
    // Dify 时代冷调遗留（亮 chatRoleBubble #DCE6F0 冷蓝 / chatUserBubble #E0E8CF 绿黄），
    // 与晨读书馆琥珀暖纸主题冲突，agent_chat 重做不启用，待后续独立 commit 清理。
```

（注释加在 `// 容器色 · 米白纸感` 之上方一行，覆盖 light 与 dark 两块。不删字段。）

- [ ] **Step 3b: 删除 `errorAccent`（与 `error` 同值，spec §7.2）**

Run: `grep -rn "errorAccent" novel_app/lib/ novel_app/test/`

- 若有引用：逐处改为 `error`，再从 `app_colors.dart` light（`:192`）+ dark（`:238`）两 const 删 `errorAccent:` 字段，并从 `copyWith` 删对应参数。
- 若无引用：直接删两处字段 + `copyWith` 参数。

Run: `flutter analyze lib/core/theme/app_colors.dart`
Expected: 0 issue（无 dangling 引用）

- [ ] **Step 4: 跑 analyze + 测试**

Run: `flutter analyze lib/core/theme/app_colors.dart` && `flutter test test/unit/core/theme/app_colors_test.dart`
Expected: 0 issue + PASS

- [ ] **Step 5: Commit**

```bash
git add novel_app/test/unit/core/theme/app_colors_test.dart novel_app/lib/core/theme/app_colors.dart
git commit -m "test(agent-chat): 加 AppColors 暖调 token 契约测试 + 标注冷调遗留"
```

---

### Task 2: agent_icons.dart（Material IconData 集中）

**Files:**
- Create: `novel_app/lib/widgets/agent_chat/agent_icons.dart`

**Interfaces:**
- Consumes: `package:flutter/material.dart` 的 `IconData`
- Produces: `AgentIcons` 抽象类（静态 `IconData` 常量），供 Task 5/6/7/8 替换所有 emoji 与部分 `Icons.auto_awesome`

- [ ] **Step 1: 写失败测试**

Create `novel_app/test/unit/widgets/agent_chat/agent_icons_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/widgets/agent_chat/agent_icons.dart';

void main() {
  test('AgentIcons 所有常量非 null', () {
    expect(AgentIcons.quill, isNotNull);
    expect(AgentIcons.book, isNotNull);
    expect(AgentIcons.clock, isNotNull);
    expect(AgentIcons.dots, isNotNull);
    expect(AgentIcons.close, isNotNull);
    expect(AgentIcons.send, isNotNull);
    expect(AgentIcons.plus, isNotNull);
    expect(AgentIcons.layers, isNotNull);
    expect(AgentIcons.edit, isNotNull);
    expect(AgentIcons.arrow, isNotNull);
    expect(AgentIcons.link, isNotNull);
    expect(AgentIcons.wand, isNotNull);
    expect(AgentIcons.history, isNotNull);
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/widgets/agent_chat/agent_icons_test.dart`
Expected: FAIL（`AgentIcons` 未定义，import 报错）

- [ ] **Step 3: 实现**

Create `novel_app/lib/widgets/agent_chat/agent_icons.dart`:

```dart
/// Agent Chat 图标常量集
///
/// 集中所有 emoji 替换与场景图标，便于将来切换到 flutter_svg 时单点替换。
/// 当前用 Material IconData（项目无 flutter_svg 依赖，遵循零新增依赖）。
library;

import 'package:flutter/material.dart';

abstract final class AgentIcons {
  /// 写作场景徽标（替代 emoji ✍️）
  static const IconData quill = Icons.edit;

  /// 书 / 当前小说（替代 emoji 📖）
  static const IconData book = Icons.menu_book;

  /// 会话历史
  static const IconData history = Icons.history;

  /// 菜单（场景切换/配置/全屏）
  static const IconData dots = Icons.more_vert;

  /// 关闭
  static const IconData close = Icons.close;

  /// 发送
  static const IconData send = Icons.send_rounded;

  /// 附件 / 添加
  static const IconData plus = Icons.add_rounded;

  /// 上下文压缩（替代 emoji 🗂）
  static const IconData layers = Icons.layers_outlined;

  /// 工具调用
  static const IconData edit = Icons.edit_note;

  /// 前往 / 查看章节
  static const IconData arrow = Icons.arrow_forward;

  /// 链接 / WebView URL
  static const IconData link = Icons.link;

  /// 快捷提示 / 魔法
  static const IconData wand = Icons.auto_awesome;
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/widgets/agent_chat/agent_icons_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add novel_app/lib/widgets/agent_chat/agent_icons.dart novel_app/test/unit/widgets/agent_chat/agent_icons_test.dart
git commit -m "feat(agent-chat): 新建 AgentIcons 集中 IconData 常量（emoji 替换基础）"
```

---

### Task 3: EmptyStateView 扩展（iconWidget + titleStyle）

**Files:**
- Modify: `novel_app/lib/widgets/empty_states/empty_state_view.dart`
- Create: `novel_app/test/unit/widgets/empty_state_view_test.dart`

**Interfaces:**
- Consumes: 现有 `EmptyStateView`（`empty_state_view.dart:9`，收 `IconData icon` + `String title` + ...）
- Produces: `EmptyStateView` 新增两可选参 `Widget? iconWidget` / `TextStyle? titleStyle`，向后兼容（不传走原逻辑）。Task 6 agent 空状态传这两参实现印章式 SVG 风格图标 + serif 标题。

- [ ] **Step 1: 写失败测试**

Create `novel_app/test/unit/widgets/empty_state_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/widgets/empty_states/empty_state_view.dart';

void main() {
  testWidgets('不传 iconWidget/titleStyle 时走原逻辑（IconData 渲染）', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: EmptyStateView(icon: Icons.search, title: '空的')),
    ));
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('空的'), findsOneWidget);
  });

  testWidgets('传 iconWidget 时渲染该 widget 而非 IconData', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: EmptyStateView(
        icon: Icons.search, // 仍必填（向后兼容），但被 iconWidget 覆盖
        title: '空的',
        iconWidget: const Icon(Icons.edit, size: 48),
      )),
    ));
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.search), findsNothing);
  });

  testWidgets('传 titleStyle 时覆盖默认 headlineSmall', (tester) async {
    const custom = TextStyle(fontFamily: 'NotoSerifSC', fontSize: 17);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: EmptyStateView(icon: Icons.search, title: '空的', titleStyle: custom)),
    ));
    final text = tester.widget<Text>(find.text('空的'));
    expect(text.style?.fontFamily, 'NotoSerifSC');
    expect(text.style?.fontSize, 17);
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/widgets/empty_state_view_test.dart`
Expected: FAIL（`iconWidget`/`titleStyle` 参数不存在）

- [ ] **Step 3: 实现**

Modify `empty_state_view.dart`。在字段区（`:21` `final IconData icon;` 之后）加：

```dart
  /// 自定义图标 widget（如印章式 SVG 风格）。传则覆盖 [icon]；不传走原 [Icon(icon)]。
  final Widget? iconWidget;

  /// 自定义标题样式（如 serif）。传则覆盖默认 headlineSmall；不传走原逻辑。
  final TextStyle? titleStyle;
```

构造函数（`:10-18`）加两可选参：

```dart
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.iconWidget,
    this.titleStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 32),
  });
```

`build` 中图标段（`:44-49`）改为：

```dart
    final children = <Widget>[
      iconWidget ??
          Icon(
            icon,
            size: 80,
            color: onSurface.withValues(alpha: 0.25),
          ),
```

标题段（`:51-57`）改为：

```dart
      Text(
        title,
        style: titleStyle ??
            theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: onSurface.withValues(alpha: 0.7),
            ),
      ),
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/widgets/empty_state_view_test.dart`
Expected: PASS

- [ ] **Step 5: 跑全量回归（其他 EmptyStateView 调用点不受影响）**

Run: `flutter analyze lib/widgets/empty_states/` && `flutter test`
Expected: 0 issue + 全绿

- [ ] **Step 6: Commit**

```bash
git add novel_app/lib/widgets/empty_states/empty_state_view.dart novel_app/test/unit/widgets/empty_state_view_test.dart
git commit -m "feat(empty-state): EmptyStateView 加 iconWidget/titleStyle 可选参（向后兼容）"
```

---

### Task 4: selectStatus 纯函数 + AgentStatusStrip（含 retry 倒计时，自包含）

**Files:**
- Create: `novel_app/lib/widgets/agent_chat/agent_status_strip.dart`
- Create: `novel_app/test/unit/widgets/agent_chat/status_strip_test.dart`

**Interfaces:**
- Consumes:
  - `AgentChatState`（`core/providers/agent_chat_state.dart`）：`error: String?` / `isLoading: bool` / `supplementaryCount: int`
  - `RetryState`（`services/dsl_engine/retry_signals.dart`）：`level: RetryLevel{transport,round}` / `attempt: int` / `maxAttempts: int` / `delayMs: int` / `errorCategory: RetryErrorCategory` / `httpStatusCode: int?`；`RetryErrorCategory.label` extension 给中文文案
  - `RetrySignals.instance.notifier`（`ValueNotifier<RetryState?>`）
  - `currentChatStateProvider`（`core/providers/scenario_sessions_provider.dart:252`）
  - `AppColors`：`error`/`chatButtonPrimary`/`ink`/`inkSoft`/`chatHintText`
- Produces:
  - `enum AgentStatusKind { error, retry, supplement }`
  - `class AgentStatus { kind, message, detail?, countdownSeconds?, onAction?, actionLabel? }`
  - `AgentStatus? selectStatus(AgentChatState chatState, RetryState? retry)` 纯函数
  - `class AgentStatusStrip extends ConsumerStatefulWidget`（dialog 在 Task 8 接入，替换原 `RetryBanner` + `_buildErrorBar` + `_buildStopBar` + `_buildSupplementBar`）

- [ ] **Step 1: 写失败测试（selectStatus 优先级矩阵）**

Create `novel_app/test/unit/widgets/agent_chat/status_strip_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/providers/agent_chat_state.dart';
import 'package:novel_app/services/dsl_engine/retry_signals.dart';
import 'package:novel_app/widgets/agent_chat/agent_status_strip.dart';

const _retry = RetryState(
  level: RetryLevel.transport,
  attempt: 2,
  maxAttempts: 8,
  delayMs: 7000,
  errorCategory: RetryErrorCategory.rateLimited,
  httpStatusCode: 429,
);

void main() {
  test('idle（无 error/retry/supplement）-> null', () {
    expect(selectStatus(const AgentChatState(), null), isNull);
  });

  test('error 且 !isLoading -> error', () {
    final s = selectStatus(const AgentChatState(error: 'boom'), null);
    expect(s?.kind, AgentStatusKind.error);
    expect(s?.message, 'boom');
  });

  test('error 且 isLoading -> 不返 error（让位 retry/running）', () {
    final s = selectStatus(
        const AgentChatState(error: 'boom', isLoading: true), null);
    expect(s?.kind, isNot(AgentStatusKind.error));
  });

  test('retry 非 null -> retry，含 attempt/maxAttempts + 类别 + HTTP', () {
    final s = selectStatus(const AgentChatState(), _retry);
    expect(s?.kind, AgentStatusKind.retry);
    expect(s?.detail, contains('2/8'));
    expect(s?.detail, contains('限流'));
    expect(s?.detail, contains('HTTP 429'));
    expect(s?.countdownSeconds, 7);
  });

  test('isLoading + supplementaryCount>0 + 无 retry -> supplement', () {
    final s = selectStatus(
        const AgentChatState(isLoading: true, supplementaryCount: 3), null);
    expect(s?.kind, AgentStatusKind.supplement);
    expect(s?.message, contains('3'));
  });

  test('error 压 retry（同时存在 -> error）', () {
    final s = selectStatus(const AgentChatState(error: 'boom'), _retry);
    expect(s?.kind, AgentStatusKind.error);
  });

  test('retry 压 supplement', () {
    final s = selectStatus(
        const AgentChatState(isLoading: true, supplementaryCount: 3), _retry);
    expect(s?.kind, AgentStatusKind.retry);
  });

  test('retry round 层 -> detail 标「回合层」', () {
    final r = RetryState(
      level: RetryLevel.round, attempt: 1, maxAttempts: 3, delayMs: 2000,
      errorCategory: RetryErrorCategory.serverError, httpStatusCode: 502,
    );
    final s = selectStatus(const AgentChatState(), r);
    expect(s?.detail, contains('回合层'));
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/widgets/agent_chat/status_strip_test.dart`
Expected: FAIL（`selectStatus`/`AgentStatusKind` 未定义）

- [ ] **Step 3: 实现 selectStatus + AgentStatus + AgentStatusKind**

Create `novel_app/lib/widgets/agent_chat/agent_status_strip.dart`（先只写纯函数部分，widget 在 Step 4）:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/agent_chat_state.dart';
import '../../core/providers/scenario_sessions_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/dsl_engine/retry_signals.dart';

/// 状态条种类
enum AgentStatusKind { error, retry, supplement }

/// 单条状态（同一时刻最多 1 条）
@immutable
class AgentStatus {
  final AgentStatusKind kind;
  final String message;
  final String? detail;
  final int? countdownSeconds;
  final VoidCallback? onAction;
  final String? actionLabel;

  const AgentStatus(
    this.kind,
    this.message, {
    this.detail,
    this.countdownSeconds,
    this.onAction,
    this.actionLabel,
  });
}

/// 优先级：error > retry > supplement。isLoading 普通态返回 null（靠消息流流式光标）。
AgentStatus? selectStatus(AgentChatState chatState, RetryState? retry) {
  if (chatState.error != null && !chatState.isLoading) {
    return AgentStatus(AgentStatusKind.error, chatState.error!);
  }
  if (retry != null) {
    final levelLabel = retry.level == RetryLevel.transport ? '传输层' : '回合层';
    final cat = retry.errorCategory.label;
    final http =
        retry.httpStatusCode != null ? ' · HTTP ${retry.httpStatusCode}' : '';
    return AgentStatus(
      AgentStatusKind.retry,
      '网络重试 · $levelLabel',
      detail: '${retry.attempt}/${retry.maxAttempts} · $cat$http',
      countdownSeconds: (retry.delayMs / 1000).ceil(),
    );
  }
  if (chatState.isLoading && chatState.supplementaryCount > 0) {
    return AgentStatus(
      AgentStatusKind.supplement,
      '已补充 ${chatState.supplementaryCount} 条消息',
      detail: '将在下一轮处理',
    );
  }
  return null;
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/widgets/agent_chat/status_strip_test.dart`
Expected: PASS（8 用例全绿）

- [ ] **Step 5: 实现 AgentStatusStrip widget（含 retry 倒计时）**

在 `agent_status_strip.dart` 末尾追加（import 已含 flutter/material 需补）:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

/// 统一状态条：error/retry/supplement 3 选 1，消息流顶部。
///
/// 自包含 retry 倒计时（订阅 RetrySignals + Timer.periodic），
/// 取代原 RetryBanner + _buildErrorBar + _buildStopBar + _buildSupplementBar。
class AgentStatusStrip extends ConsumerStatefulWidget {
  const AgentStatusStrip({super.key});
  @override
  ConsumerState<AgentStatusStrip> createState() => _AgentStatusStripState();
}

class _AgentStatusStripState extends ConsumerState<AgentStatusStrip> {
  Timer? _timer;
  int _countdown = 0;
  // 记录上次 retry 的 attempt，用于检测新一轮重试（重启倒计时）
  int _lastAttempt = -1;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    _countdown = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(currentChatStateProvider);
    final retry = RetrySignals.instance.notifier.value;
    final status = selectStatus(chatState, retry);

    // retry 倒计时管理：检测新一轮 attempt 时重启
    if (status?.kind == AgentStatusKind.retry) {
      final attempt = retry!.attempt;
      if (attempt != _lastAttempt) {
        _lastAttempt = attempt;
        _startCountdown(status!.countdownSeconds ?? 0);
      }
    } else {
      _timer?.cancel();
      _countdown = 0;
      _lastAttempt = -1;
    }

    if (status == null) return const SizedBox.shrink();

    final colors = context.appColors;
    final isError = status.kind == AgentStatusKind.error;
    final accent = isError ? colors.error : colors.chatButtonPrimary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isError ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(width: 3, color: accent),
          top: BorderSide(color: accent.withValues(alpha: 0.2)),
          bottom: BorderSide(color: accent.withValues(alpha: 0.2)),
          right: BorderSide(color: accent.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          if (status.kind == AgentStatusKind.retry)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            )
          else
            Icon(isError ? Icons.error_outline : Icons.edit_note,
                size: 16, color: accent),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(status.message,
                    style: TextStyle(fontSize: 11.5, color: colors.ink)),
                if (status.detail != null) ...[
                  const SizedBox(height: 1),
                  Text(status.detail!,
                      style: TextStyle(
                          fontSize: 10.5,
                          color: colors.chatHintText,
                          fontFamily: 'JetBrainsMono')),
                ],
              ],
            ),
          ),
          if (status.kind == AgentStatusKind.retry && _countdown > 0)
            Text('${_countdown}s',
                style: TextStyle(
                    fontSize: 11,
                    color: accent,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'JetBrainsMono')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 跑 analyze**

Run: `flutter analyze lib/widgets/agent_chat/agent_status_strip.dart`
Expected: 0 issue

- [ ] **Step 7: Commit**

```bash
git add novel_app/lib/widgets/agent_chat/agent_status_strip.dart novel_app/test/unit/widgets/agent_chat/status_strip_test.dart
git commit -m "feat(agent-chat): 新建 AgentStatusStrip + selectStatus 纯函数（5 bar 合 1）"
```

---

### Task 5: AgentChatHeader（去渐变 + 上下文行 + 3 按钮 + 场景菜单）

**Files:**
- Create: `novel_app/lib/widgets/agent_chat/agent_chat_header.dart`
- Create: `novel_app/test/unit/widgets/agent_chat/agent_chat_header_test.dart`

**Interfaces:**
- Consumes:
  - `AgentChatState`：`scenarioId`/`scenarioDisplayName`/`currentNovel`
  - `CurrentNovel`（`core/providers/current_novel_provider.dart`，含 `title`）
  - `readingContextProvider`（`core/providers/reading_context_providers.dart`）：`ReadingContext.hasContext`/`displayLabel`
  - `webviewCurrentUrlProvider`（`core/providers/webview_providers.dart:80`）：`StateProvider<String>`
  - `currentAgentScenarioProvider` / `scenarioSessionsProvider`（切场景 + 配置入口）
  - `AgentScenarioFactory.availableScenarios`（`agent_scenario_factory.dart:71`）：`List<ScenarioInfo>{id,displayName,icon}`（icon 是 emoji string，**不再用**，改 `AgentIcons`）
  - `AgentNovelPickerDialog`（writing 场景选小说）
  - `ScenarioIds.webviewExtract` / `ScenarioIds.writing`（`agent_scenario.dart:328`）
- Produces: `class AgentChatHeader extends ConsumerWidget`（dialog 在 Task 8 用它替换 `_buildHeader`+`_buildWebViewInfoBar`+`_buildCurrentNovelBar`）

- [ ] **Step 1: 写失败测试**

Create `novel_app/test/unit/widgets/agent_chat/agent_chat_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/providers/agent_scenario_provider.dart';
import 'package:novel_app/core/providers/agent_chat_state.dart';
import 'package:novel_app/core/providers/current_novel_provider.dart';
import 'package:novel_app/core/providers/scenario_sessions_provider.dart';
import 'package:novel_app/services/novel_agent/agent_scenario.dart';
import 'package:novel_app/widgets/agent_chat/agent_chat_header.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: ProviderScope(overrides: [
        currentChatStateProvider.overrideWith((ref) => const AgentChatState(
              scenarioId: ScenarioIds.writing,
              scenarioDisplayName: '小说写作助手',
            )),
      ], child: child)),
    );

void main() {
  testWidgets('writing 场景渲染 serif 标题 + 上下文行占位（未选小说）', (tester) async {
    await tester.pumpWidget(_wrap(const AgentChatHeader()));
    await tester.pumpAndSettle();
    expect(find.text('小说写作助手'), findsOneWidget);
    expect(find.textContaining('尚未选择小说'), findsOneWidget);
  });

  testWidgets('Header 含 历史/菜单/关闭 三按钮', (tester) async {
    await tester.pumpWidget(_wrap(const AgentChatHeader()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('会话历史'), findsOneWidget);
    expect(find.byTooltip('场景与设置'), findsOneWidget);
    expect(find.byTooltip('关闭'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/widgets/agent_chat/agent_chat_header_test.dart`
Expected: FAIL（`AgentChatHeader` 未定义）

- [ ] **Step 3: 实现**

Create `novel_app/lib/widgets/agent_chat/agent_chat_header.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/agent_scenario_provider.dart';
import '../../core/providers/agent_chat_state.dart';
import '../../core/providers/current_novel_provider.dart';
import '../../core/providers/reading_context_providers.dart';
import '../../core/providers/scenario_sessions_provider.dart';
import '../../core/providers/webview_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/novel_agent/agent_scenario.dart';
import '../../services/novel_agent/agent_scenario_factory.dart';
import 'agent_icons.dart';
import 'agent_novel_picker_dialog.dart';

class AgentChatHeader extends ConsumerWidget {
  final VoidCallback? onHistory;
  final VoidCallback? onClose;

  const AgentChatHeader({super.key, this.onHistory, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(currentChatStateProvider);
    final colors = context.appColors;
    final isWebview = chatState.scenarioId == ScenarioIds.webviewExtract;

    return Container(
      decoration: BoxDecoration(
        color: colors.paper,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 行1：徽标 + serif 标题 + 3 按钮
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.chatButtonPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: colors.chatButtonPrimary.withValues(alpha: 0.20)),
                ),
                child: Icon(AgentIcons.quill,
                    size: 16, color: colors.chatButtonPrimary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  chatState.scenarioDisplayName,
                  style: AppTypography.novelTitle.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: '会话历史',
                icon: Icon(AgentIcons.history, size: 19),
                color: colors.inkSoft,
                onPressed: onHistory,
              ),
              _ScenarioMenu(),
              IconButton(
                tooltip: '关闭',
                icon: Icon(AgentIcons.close, size: 19),
                color: colors.inkSoft,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 行2：上下文行（整行可点）
          _ContextLine(isWebview: isWebview, chatState: chatState),
        ],
      ),
    );
  }
}

class _ScenarioMenu extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final currentId = ref.watch(currentAgentScenarioProvider);
    return PopupMenuButton<String>(
      tooltip: '场景与设置',
      icon: Icon(AgentIcons.dots, size: 19),
      color: colors.paper,
      onSelected: (value) {
        if (value == 'config') {
          // 配置入口沿用现有 dialog（Task 8 接线）
          return;
        }
        if (value == 'fullscreen') {
          return; // Task 8 dialog 层接线
        }
        // 否则为 scenarioId -> 切场景
        ref.read(currentAgentScenarioProvider.notifier).state = value;
        ref.read(currentChatSessionIdProvider.notifier).state = null;
        ref.read(scenarioSessionsProvider.notifier).get(value);
      },
      itemBuilder: (_) => [
        for (final s in AgentScenarioFactory.availableScenarios)
          PopupMenuItem(
            value: s.id,
            child: Row(children: [
              Icon(AgentIcons.quill, size: 16, color: colors.chatButtonPrimary),
              const SizedBox(width: 8),
              Expanded(child: Text(s.displayName)),
              if (s.id == currentId)
                Icon(Icons.check, size: 16, color: colors.chatButtonPrimary),
            ]),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'config', child: Text('场景配置')),
        const PopupMenuItem(value: 'fullscreen', child: Text('全屏切换')),
      ],
    );
  }
}

class _ContextLine extends ConsumerWidget {
  final bool isWebview;
  final AgentChatState chatState;
  const _ContextLine({required this.isWebview, required this.chatState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    if (isWebview) {
      final url = ref.watch(webviewCurrentUrlProvider);
      return InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Icon(AgentIcons.link, size: 12, color: colors.chatButtonPrimary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                url.isEmpty ? '当前无页面' : url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: colors.inkSoft, fontFamily: 'JetBrainsMono'),
              ),
            ),
          ]),
        ),
      );
    }
    // writing
    final novel = chatState.currentNovel;
    final readingCtx = ref.watch(readingContextProvider);
    final hasNovel = novel != null;
    final label = StringBuffer();
    if (hasNovel) {
      label.write('阅读《${novel.title}》');
      if (readingCtx.hasContext && readingCtx.chapterTitle != null) {
        label.write(' · ${readingCtx.chapterTitle}');
      }
    } else {
      label.write('尚未选择小说 · 点击选择');
    }
    return InkWell(
      onTap: hasNovel
          ? null
          : () => _showNovelPicker(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(AgentIcons.book, size: 13, color: colors.chatButtonPrimary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  color: hasNovel ? colors.inkSoft : colors.chatHintText),
            ),
          ),
        ]),
      ),
    );
  }

  void _showNovelPicker(BuildContext context, WidgetRef ref) {
    // 复用现有 picker；选择后调 session.selectNovel（Task 8 在 dialog 注入回调）
    showDialog(
      context: context,
      builder: (_) => const AgentNovelPickerDialog(),
    );
  }
}
```

> 注：`onHistory`/`onClose`/`config`/`fullscreen`/`selectNovel` 回调在 Task 8 由 dialog 注入；本 task 用空实现/占位，保证 widget 独立可渲染可测。

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/widgets/agent_chat/agent_chat_header_test.dart`
Expected: PASS

- [ ] **Step 5: 跑 analyze**

Run: `flutter analyze lib/widgets/agent_chat/agent_chat_header.dart`
Expected: 0 issue

- [ ] **Step 6: Commit**

```bash
git add novel_app/lib/widgets/agent_chat/agent_chat_header.dart novel_app/test/unit/widgets/agent_chat/agent_chat_header_test.dart
git commit -m "feat(agent-chat): 新建 AgentChatHeader（去渐变 + 上下文行 + 场景菜单）"
```

---

### Task 6: AgentChatMessages + 气泡改色 + compaction emoji

**Files:**
- Create: `novel_app/lib/widgets/agent_chat/agent_chat_messages.dart`
- Modify: `novel_app/lib/widgets/agent_chat/agent_message_bubble.dart`（`:100-106` `_getBubbleColor` / `:55-62` borderRadius / `:135-138`+`:164-167` 正文色 / assistant serif）
- Modify: `novel_app/lib/widgets/agent_chat/compaction_marker_card.dart`（`:65` `Text('🗂')` -> `Icon(AgentIcons.layers)`）
- Create: `novel_app/test/unit/widgets/agent_chat/agent_chat_messages_test.dart`

**Interfaces:**
- Consumes:
  - `AgentChatState`：`messages`/`streamingSegments`/`scenarioId`/`scenarioDisplayName`
  - `AgentMessageBubble`（改后）、`CompactionMarkerCard`（改 emoji）
  - `EmptyStateView`（Task 3 扩展后，传 `iconWidget`+`titleStyle`）
  - `ScenarioQuickPrompts.forScenario(scenarioId)`（`agent_scenario.dart:354`）-- 仅空状态 hint 用，快捷 chips 在 Composer
- Produces: `class AgentChatMessages extends ConsumerStatefulWidget`（含 ListView + 空状态 + jump-to-bottom `FloatingActionButton.small`）

- [ ] **Step 1: 写失败测试（空状态用扩展后的 EmptyStateView）**

Create `novel_app/test/unit/widgets/agent_chat/agent_chat_messages_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/providers/agent_chat_state.dart';
import 'package:novel_app/core/providers/scenario_sessions_provider.dart';
import 'package:novel_app/widgets/agent_chat/agent_chat_messages.dart';

void main() {
  testWidgets('空消息 -> 渲染 EmptyStateView（含印章 quill 图标）', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ProviderScope(overrides: [
        currentChatStateProvider
            .overrideWith((ref) => const AgentChatState()),
      ], child: const AgentChatMessages()),
    )));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit), findsOneWidget); // AgentIcons.quill = Icons.edit
    expect(find.textContaining('开始'), findsWidgets);
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/widgets/agent_chat/agent_chat_messages_test.dart`
Expected: FAIL（`AgentChatMessages` 未定义）

- [ ] **Step 3: 改气泡配色（先改依赖项）**

Modify `agent_message_bubble.dart`:

`_getBubbleColor`（`:100-106`）改为:

```dart
  Color _getBubbleColor(BuildContext context) {
    final c = context.appColors;
    if (message.role == AgentChatRole.user) {
      // 琥珀 wash（不用冷调 chatUserBubble）
      return c.chatButtonPrimary.withValues(alpha: 0.10);
    }
    // assistant：纸底（不用冷蓝 chatRoleBubble）
    return c.paper;
  }
```

Container `decoration`（`:55-70`）加描边 + 调 borderRadius（user 右上小、assistant 左上小）:

```dart
          decoration: BoxDecoration(
            color: _getBubbleColor(context),
            border: Border.all(
              color: isUser
                  ? context.appColors.chatButtonPrimary.withValues(alpha: 0.20)
                  : context.appColors.divider,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isUser ? 16 : 4),
              topRight: Radius.circular(isUser ? 4 : 16),
              bottomLeft: const Radius.circular(16),
              bottomRight: const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: context.appColors.avatarShadow.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
```

user 正文（`:135-138`）色改 `chatPrimaryText`（不再用白 `agentOnBrand`）:

```dart
      return Text(
        message.content,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: context.appColors.chatPrimaryText,
              height: 1.5,
            ),
      );
```

assistant `TextSegment`（`:164-167`）改 serif + `chatPrimaryText`:

```dart
            Text(
              seg.content,
              style: AppTypography.bodyProse.copyWith(
                fontSize: 13,
                height: 1.65,
                color: context.appColors.chatPrimaryText,
              ),
            ),
```

> 注：`_buildAssistantContent` 内 markdown stylesheet（审计 `:303-341`）的 `p` color 也由 `agentOnBrand` 改 `chatPrimaryText`；若该段引用 `agentOnBrand`，一并替换。执行时 grep `agentOnBrand` 全文替换为 `chatPrimaryText`（仅本文件）。

- [ ] **Step 4: 改 compaction emoji**

Modify `compaction_marker_card.dart:65`：`Text('🗂', ...)` -> `Icon(AgentIcons.layers, size: 14, color: context.appColors.chatButtonPrimary)`。补 import `agent_icons.dart` + `app_colors.dart`（若未引）。

- [ ] **Step 5: 实现 AgentChatMessages**

Create `novel_app/lib/widgets/agent_chat/agent_chat_messages.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/agent_chat_state.dart';
import '../../core/providers/scenario_sessions_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/agent_chat_message.dart';
import '../empty_states/empty_state_view.dart';
import 'agent_icons.dart';
import 'agent_message_bubble.dart';
import 'compaction_marker_card.dart';

class AgentChatMessages extends ConsumerStatefulWidget {
  final void Function(AgentChatMessage)? onRollback;
  const AgentChatMessages({super.key, this.onRollback});

  @override
  ConsumerState<AgentChatMessages> createState() => _AgentChatMessagesState();
}

class _AgentChatMessagesState extends ConsumerState<AgentChatMessages> {
  final _scrollController = ScrollController();
  bool _isAtBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final atBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 40;
      if (atBottom != _isAtBottom) setState(() => _isAtBottom = atBottom);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(currentChatStateProvider);
    final messages = chatState.messages;
    final colors = context.appColors;

    if (messages.isEmpty && chatState.streamingSegments.isEmpty) {
      return EmptyStateView(
        icon: AgentIcons.quill, // 必填，被 iconWidget 覆盖
        title: '开始今天的写作',
        subtitle: '告诉我你想写什么，或从下方提示开始一段新的章节。',
        iconWidget: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: colors.chatButtonPrimary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(
                color: colors.chatButtonPrimary.withValues(alpha: 0.20)),
          ),
          child: Icon(AgentIcons.quill,
              size: 30, color: colors.chatButtonPrimary),
        ),
        titleStyle:
            AppTypography.novelTitle.copyWith(fontSize: 17),
      );
    }

    return Stack(children: [
      ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: messages.length + (chatState.isLoading ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == messages.length) {
            // 流式尾气泡
            return AgentMessageBubble(
              message: AgentChatMessage(role: AgentChatRole.assistant),
              streamingSegments: chatState.streamingSegments,
            );
          }
          final m = messages[i];
          if (m.role == AgentChatRole.marker) return const CompactionMarkerCard();
          return AgentMessageBubble(
            message: m,
            showTimestamp: true,
            onRollback:
                m.role == AgentChatRole.user ? () => widget.onRollback?.(m) : null,
          );
        },
      ),
      if (!_isAtBottom)
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            onPressed: () => _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            ),
            backgroundColor: colors.agentAccent,
            foregroundColor: colors.agentOnBrand,
            child: const Icon(Icons.keyboard_arrow_down),
          ),
        ),
    ]);
  }
}
```

> 注：`AgentChatMessage`/`AgentChatRole.marker` 字段以 `models/agent_chat_message.dart` 实际为准；若 `CompactionMarkerCard` 构造需要参数（marker segment），按现有 `agent_chat_dialog.dart:354-371` 的 dispatch 方式传参。执行时对照现有 `_buildMessageList`（`:329-389`）保持消息构造一致。

- [ ] **Step 6: 跑测试验证通过**

Run: `flutter test test/unit/widgets/agent_chat/agent_chat_messages_test.dart`
Expected: PASS

- [ ] **Step 7: 跑 analyze**

Run: `flutter analyze lib/widgets/agent_chat/agent_message_bubble.dart lib/widgets/agent_chat/agent_chat_messages.dart lib/widgets/agent_chat/compaction_marker_card.dart`
Expected: 0 issue

- [ ] **Step 8: Commit**

```bash
git add novel_app/lib/widgets/agent_chat/agent_chat_messages.dart novel_app/lib/widgets/agent_chat/agent_message_bubble.dart novel_app/lib/widgets/agent_chat/compaction_marker_card.dart novel_app/test/unit/widgets/agent_chat/agent_chat_messages_test.dart
git commit -m "feat(agent-chat): 新建 AgentChatMessages + 气泡改暖调配色/serif + compaction 去 emoji"
```

---

### Task 7: AgentChatComposer（统一 chip + 双模发送按钮）

**Files:**
- Create: `novel_app/lib/widgets/agent_chat/agent_chat_composer.dart`
- Create: `novel_app/test/unit/widgets/agent_chat/agent_chat_composer_test.dart`

**Interfaces:**
- Consumes:
  - `AgentChatState`：`isLoading`/`supplementaryCount`/`scenarioId`
  - `ScenarioQuickPrompts.forScenario(scenarioId)`（`agent_scenario.dart:354`）：快捷提示
  - `AgentIcons`
- Produces: `class AgentChatComposer extends ConsumerStatefulWidget`（含 chips + TextField + attach/send 双模）。通过回调 `onSend(String text, int? mediaId)` / `onAttachMedia` 与 dialog 交互（Task 8 接线）。

- [ ] **Step 1: 写失败测试**

Create `novel_app/test/unit/widgets/agent_chat/agent_chat_composer_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/providers/agent_chat_state.dart';
import 'package:novel_app/core/providers/scenario_sessions_provider.dart';
import 'package:novel_app/services/novel_agent/agent_scenario.dart';
import 'package:novel_app/widgets/agent_chat/agent_chat_composer.dart';

void main() {
  testWidgets('渲染输入框 + 发送按钮（禁用态当无文本）', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: ProviderScope(overrides: [
        currentChatStateProvider.overrideWith((ref) => const AgentChatState(
              scenarioId: ScenarioIds.writing,
            )),
      ], child: const AgentChatComposer())),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('发送'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/widgets/agent_chat/agent_chat_composer_test.dart`
Expected: FAIL（`AgentChatComposer` 未定义）

- [ ] **Step 3: 实现**

Create `novel_app/lib/widgets/agent_chat/agent_chat_composer.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/agent_chat_state.dart';
import '../../core/providers/scenario_sessions_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/novel_agent/agent_scenario.dart';
import 'agent_icons.dart';

class AgentChatComposer extends ConsumerStatefulWidget {
  final void Function(String text, int? mediaId)? onSend;
  final VoidCallback? onAttachMedia;
  final int? attachedMediaId;
  final void Function(int? mediaId)? onClearAttachment;

  const AgentChatComposer({
    super.key,
    this.onSend,
    this.onAttachMedia,
    this.attachedMediaId,
    this.onClearAttachment,
  });

  @override
  ConsumerState<AgentChatComposer> createState() => _AgentChatComposerState();
}

class _AgentChatComposerState extends ConsumerState<AgentChatComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text, widget.attachedMediaId);
    _controller.clear();
    widget.onClearAttachment?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(currentChatStateProvider);
    final colors = context.appColors;
    final prompts = ScenarioQuickPrompts.forScenario(chatState.scenarioId);
    final isSupp = chatState.isLoading && chatState.supplementaryCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: colors.paper,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prompts.isNotEmpty && !chatState.isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final p in prompts)
                    ActionChip(
                      avatar: Icon(AgentIcons.wand, size: 14),
                      label: Text(p, style: const TextStyle(fontSize: 11)),
                      backgroundColor: colors.chatInputBackground,
                      side: BorderSide(color: colors.divider),
                      onPressed: () {
                        _controller.text = p;
                        _controller.selection = TextSelection(
                            baseOffset: p.length, extentOffset: p.length);
                      },
                    ),
                ],
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.chatInputBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: _controller,
                      maxLines: 5,
                      minLines: 1,
                      style: TextStyle(
                          fontSize: 13, color: colors.chatPrimaryText),
                      decoration: InputDecoration(
                        hintText: '和写作助手说点什么…',
                        hintStyle: TextStyle(color: colors.chatHintText),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '添加图片',
                  icon: Icon(AgentIcons.plus, size: 19),
                  color: colors.inkSoft,
                  onPressed: widget.onAttachMedia,
                ),
                const SizedBox(width: 2),
                _SendButton(
                  enabled: _hasText,
                  isSupplementary: isSupp,
                  onPressed: _send,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Enter 发送 · Shift+Enter 换行',
              style: TextStyle(
                  fontSize: 9.5,
                  color: colors.chatHintText,
                  fontFamily: 'JetBrainsMono')),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final bool isSupplementary;
  final VoidCallback onPressed;
  const _SendButton(
      {required this.enabled, required this.isSupplementary, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bg = enabled
        ? (isSupplementary
            ? colors.chatButtonPrimary.withValues(alpha: 0.5)
            : colors.chatButtonPrimary)
        : colors.chatDivider;
    return Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        boxShadow: enabled && !isSupplementary
            ? [
                BoxShadow(
                  color: colors.chatButtonPrimary.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: IconButton(
        tooltip: '发送',
        icon: Icon(AgentIcons.send, size: 17),
        color: colors.agentOnBrand,
        padding: EdgeInsets.zero,
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}
```

> 注：`ScenarioQuickPrompts.forScenario` 返回类型以 `agent_scenario.dart:354` 实际为准（`List<String>` 或 `List<QuickPrompt>`）；若为后者，取其 label 字段。执行时对照调整。

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/widgets/agent_chat/agent_chat_composer_test.dart`
Expected: PASS

- [ ] **Step 5: 跑 analyze**

Run: `flutter analyze lib/widgets/agent_chat/agent_chat_composer.dart`
Expected: 0 issue

- [ ] **Step 6: Commit**

```bash
git add novel_app/lib/widgets/agent_chat/agent_chat_composer.dart novel_app/test/unit/widgets/agent_chat/agent_chat_composer_test.dart
git commit -m "feat(agent-chat): 新建 AgentChatComposer（统一 chip + 双模发送按钮）"
```

---

### Task 8: dialog 瘦身 + 删 retry_banner + scenario_config emoji + 接线

**Files:**
- Modify: `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart`（瘦身到 shell，接入 Task 4-7 组件，删除 `_buildHeader`/`_buildWebViewInfoBar`/`_buildCurrentNovelBar`/`_buildErrorBar`/`_buildStopBar`/`_buildSupplementBar`/`_buildContextTag`/`_buildEmptyState`/`_buildJumpToBottomButton`/`_buildInputBar`/`_buildQuickPrompts`/`_AgentInputTrailingButton` + 移除 `const RetryBanner()`）
- Delete: `novel_app/lib/widgets/agent_chat/retry_banner.dart`（逻辑迁入 `AgentStatusStrip` Task 4）
- Modify: `novel_app/lib/widgets/agent_chat/agent_scenario_config_dialog.dart`（`:68` 标题 emoji `Text(scenarioInfo?.icon ?? '⚙️')` -> `Icon(AgentIcons.layers)` 或 `AgentIcons.quill`）

**Interfaces:**
- Consumes: Task 4 `AgentStatusStrip` / Task 5 `AgentChatHeader` / Task 6 `AgentChatMessages` / Task 7 `AgentChatComposer`
- Produces: `AgentChatDialog` 作为 < 300 行 shell（Dialog 容器 + fullscreen + 组装 + SnackBar 订阅）

- [ ] **Step 1: 改 scenario_config emoji**

Modify `agent_scenario_config_dialog.dart:68`：`Text(scenarioInfo?.icon ?? '⚙️', style: TextStyle(fontSize: 20))` -> `Icon(AgentIcons.quill, size: 22, color: context.appColors.chatButtonPrimary)`（补 import `agent_icons.dart`/`app_colors.dart`）。

- [ ] **Step 2: dialog shell 重写**

Rewrite `agent_chat_dialog.dart` 的 `build` 主体（`:152-189`）为:

```dart
    return Dialog(
      insetPadding: _isFullscreen
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _isFullscreen
                ? double.infinity
                : MediaQuery.of(context).size.width * 0.92,
            maxHeight: _isFullscreen
                ? double.infinity
                : MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AgentChatHeader(
                onHistory: () => _showHistorySheet(),
                onClose: () => Navigator.of(context).maybePop(),
              ),
              const AgentStatusStrip(),
              Expanded(child: AgentChatMessages(onRollback: _rollbackTo)),
              AgentChatComposer(
                onSend: (text, mediaId) => _sendMessage(text, mediaId),
                onAttachMedia: _pickImage,
                attachedMediaId: _attachedMediaId,
                onClearAttachment: (m) => setState(() => _attachedMediaId = null),
              ),
            ],
          ),
        ),
      ),
    );
```

删除被替换的 `_buildHeader`/`_buildWebViewInfoBar`/`_buildCurrentNovelBar`/`_buildErrorBar`/`_buildStopBar`/`_buildSupplementBar`/`_buildContextTag`/`_buildEmptyState`/`_buildJumpToBottomButton`/`_buildInputBar`/`_buildQuickPrompts`/`_AgentInputTrailingButton` 方法与 `const RetryBanner()` 调用（`:182`）。保留 `_showHistorySheet`/`_rollbackTo`/`_sendMessage`/`_pickImage`/`_isFullscreen`/`_attachedMediaId` 与 `agentEventsProvider` SnackBar 订阅（`:138-150`）。`_showScenarioConfigDialog` 通过 Header 的 `_ScenarioMenu` config 项触发，接线时在 Header 注入 `onConfig` 回调或保留 dialog 内方法引用。

> Header 的 `_ScenarioMenu` 中 `config`/`fullscreen` 占位在此步接线：将 `_ScenarioMenu` 改为接收 `VoidCallback? onConfig` / `VoidCallback? onToggleFullscreen`，dialog 传入 `_showScenarioConfigDialog` / `() => setState(() => _isFullscreen = !_isFullscreen)`。

- [ ] **Step 3: 删 retry_banner.dart**

Delete `novel_app/lib/widgets/agent_chat/retry_banner.dart`。Grep 确认无其他引用（`RetryBanner` 仅 dialog `:182` 用，已删）。

```bash
git rm novel_app/lib/widgets/agent_chat/retry_banner.dart
```

- [ ] **Step 4: 跑全量 analyze**

Run: `flutter analyze lib/widgets/agent_chat/`
Expected: 0 issue（重点看无 dangling import / 未定义引用）

- [ ] **Step 5: 跑全量测试**

Run: `flutter test`
Expected: 全绿（含 Task 1-7 测试 + 既有测试）

- [ ] **Step 6: Commit**

```bash
git add -A novel_app/lib/widgets/agent_chat/
git commit -m "refactor(agent-chat): dialog 瘦身为 shell + 删 retry_banner + scenario_config 去 emoji"
```

---

### Task 9: 集成验证（亮/暗 5 状态目视）

**Files:** 无新增/修改（仅验证；若目视发现问题，回对应 task 修）

- [ ] **Step 1: 启动 app（亮色）**

Run: `flutter run`（或项目既有的运行方式），打开 Agent Chat（FAB 或书架入口）。

逐项目视 5 状态：
1. **空状态**：印章 quill 图标 + serif「开始今天的写作」+ 提示
2. **正常对话**：user 琥珀 wash 气泡（墨字非白）/ assistant 纸色气泡 serif 正文 / 工具卡虚线描边 + 琥珀 CTA
3. **运行中**：消息流末尾流式光标，**无** status strip（普通运行态不显示）
4. **重试**：消息流顶部琥珀 status strip，倒计时在跑，输入区可点（非禁用--保留用户编辑权）
5. **压缩后**：消息流内嵌 compaction marker（layers 图标，非 emoji），可展开

核对：Header 无 indigo 渐变（纸底）/ 标题 serif / 上下文行显示「阅读《...》」或 URL / 3 按钮 / 场景菜单含切换+配置+全屏。

- [ ] **Step 2: 切暗色目视**

切换系统暗色（或 app 内主题切换）。重看 5 状态。核对：底色 `#241F16` 暖黑 / 字 `#E8DCC4` 羊皮 / 琥珀 `#D9A05B`（比亮色亮一档）/ status strip 琥珀仍可见 / 无冷蓝/绿黄气泡。

- [ ] **Step 3: 切场景目视**

点 Header ⋯ 菜单 -> 切到「网页提取」。核对：上下文行变 URL（monospace）/ 历史不丢（切回写作仍在）/ 菜单项带选中标记。

- [ ] **Step 4: 若有问题**

回对应 task 修复 + 增量 commit。若无问题，Step 5 收尾。

- [ ] **Step 5: 最终 analyze + 全量 test**

Run: `flutter analyze` && `flutter test`
Expected: 0 issue + 全绿

- [ ] **Step 6: 更新根 CLAUDE.md changelog**

在 `CLAUDE.md` 变更记录顶部加一行（格式参照现有条目）:

```
- **2026-07-27**: **Agent Chat 晨读书馆风重做**。`agent_chat_dialog.dart` 1230 行巨石拆为 Header/StatusStrip/Messages/Composer 4 组件 + `agent_icons.dart` 集中 IconData；5 个手写 status bar 合并为 `AgentStatusStrip`（`selectStatus` 纯函数 `error>retry>supplement` 优先级）；Header 去 indigo 渐变改纸底 + serif 标题；emoji 全换 Material IconData；气泡 user 琥珀 wash/assistant 纸底 serif，去冷调遗留 `chatRoleBubble`/`chatUserBubble`；`retry_banner.dart` 删除（逻辑入 StatusStrip）；`EmptyStateView` 加 `iconWidget`/`titleStyle` 可选参（向后兼容）。详见 `docs/superpowers/specs/2026-07-27-agent-chat-reading-style-redesign-design.md`。
```

- [ ] **Step 7: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(agent-chat): CLAUDE.md changelog 记录晨读书馆风重做"
```

---

## Self-Review

**1. Spec coverage**（逐节对照）：
- §1 背景痛点 1-9 -> Task 4（5 bar 合 1）/ Task 5（去渐变+emoji）/ Task 6（气泡冷调+正文色+emoji）/ Task 8（删 RetryBanner 冷色）全覆盖
- §2 非目标（不动层）-> Global Constraints + 各 task 仅改表达层 ✓
- §3 设计方向（色板/字体）-> Global Constraints token 约束 + Task 6 气泡用 `chatButtonPrimary`/`paper`/`chatPrimaryText` ✓
- §4 架构边界 -> Task 8 dialog shell + Task 4-7 组件 ✓
- §5 文件拆分 -> Task 2/4/5/6/7 新建 + Task 6/8 改 + Task 8 删 retry_banner ✓
- §6.1 Header -> Task 5（含上下文行交互、工具统计删除决策）✓
- §6.2 StatusStrip -> Task 4（含 retry 倒计时、优先级）✓
- §6.3 Messages -> Task 6（EmptyStateView 扩展在 Task 3、FAB.small、气泡配色）✓
- §6.4 Composer -> Task 7 ✓
- §7 token 清理 -> Task 1（冷调标注）+ Task 6（不启用冷调）✓；`errorAccent`/`agentAccent==agentBrandStart` 合并：spec §7.1/7.2 提到，但实际 `agentAccent`/`agentBrandStart` 在 FAB 仍用，删任一会破坏 FAB；`errorAccent` 需 grep 引用确认。**Gap**：Task 1 未显式处理 `errorAccent` 删除。已在下方 Type consistency 修正。
- §8 暗色 -> Global Constraints 禁 if(dark) + Task 9 Step 2 暗色目视 ✓
- §9 切场景 -> Global Constraints 不改行为 + Task 9 Step 3 目视 ✓
- §10 迁移 6 commit -> Task 1/2/3/4/5/6/7/8/9 对应 ✓
- §11 测试 -> Task 1（token 契约）/ Task 4（selectStatus 8 用例）/ Task 5/6/7（widget）/ Task 9（全量）✓
- §12 风险 -> Global Constraints + 各 task analyze/test gate ✓
- §13 token 映射 -> Task 6/7 代码用对应 token ✓

**2. Placeholder scan**：无 TBD/TODO。`_ScenarioMenu` 的 config/fullscreen 占位在 Task 8 Step 2 明确接线说明（非占位，是跨 task 接线点）。`ScenarioQuickPrompts.forScenario` 返回类型与 `AgentChatMessage` marker 构造标注「以实际为准 + 对照现有代码」，附了参照行号。

**3. Type consistency**：
- `selectStatus` 签名在 Task 4 定义、Task 4 测试调用、Task 4 widget 调用，一致 ✓
- `AgentStatus` 字段 `countdownSeconds` 在 Task 4 定义与 widget `status.countdownSeconds` 调用一致 ✓
- `AgentChatHeader` 的 `onHistory`/`onClose` 在 Task 5 定义、Task 8 接线一致 ✓
- `AgentChatComposer` 的 `onSend`/`onAttachMedia`/`attachedMediaId`/`onClearAttachment` 在 Task 7 定义、Task 8 接线一致 ✓
- **Gap 修正**：`errorAccent` 删除未覆盖。补 Task 1 Step 3b：

  在 Task 1 Step 3 之后补：`grep -rn "errorAccent" novel_app/lib/`，若无引用则从 `app_colors.dart` light/dark 两处删 `errorAccent` 字段（及 copyWith 参数）；若有引用则改为 `error` 并删除字段。run `flutter analyze` 确认 0 issue。

- `AgentIcons.layers` 在 Task 2 定义、Task 6 compaction + Task 8 scenario_config 使用一致 ✓

**4. Ambiguity**：`_buildAssistantContent` markdown stylesheet 改色（Task 6 Step 3 注）用 grep 全文替换 `agentOnBrand`->`chatPrimaryText`，明确。`AgentChatRole.marker` dispatch（Task 6 Step 5 注）对照现有 `:354-371`，明确。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-27-agent-chat-reading-style-redesign.md`. Two execution options:

**1. Subagent-Driven (recommended)** - 每个 task 派一个 fresh subagent 执行，task 间两阶段 review，快速迭代

**2. Inline Execution** - 在本会话用 executing-plans 批量执行，带 checkpoint review

Which approach?
