# 上下文式 Agent 启动器 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现通用 `ContextualAgentLauncher`（按钮点击 -> 注入上下文 -> 新建 agent 对话 -> 预填草稿 -> autoSend/draftOnly），并完成"添加到书架"失败降级触发提取 agent 的接入。

**Architecture:** 启动器是一层薄编排，复用现有 `ScenarioSession`（`switchSession(id,null)` 触发新会话）、`AgentChatDialog`（加 `initialDraft` 参数）、`currentAgentScenarioProvider`（切场景）。FAB 改造为三分支：有脚本快速路径（现状）/ 失败降级 / 无脚本降级。agent 内部分流（目录页判断）靠 autoSend 的 `draftMessage` 承载指令，不改 `buildSystemPrompt`/`AgentScenarioContext`。

**Tech Stack:** Flutter / Dart / Riverpod / flutter_inappwebview / sqflite_common_ffi（测试）

## Global Constraints

- 纯前端 `novel_app`，不涉及后端爬虫链路。
- 测试用 **mockito**（非 mocktail）；依赖 DB 的测试用真实内存 SQLite（`TestDatabaseSetup.createInMemoryDatabase()` + `DatabaseConnection.forTesting(db)`）。
- 测试运行命令：`flutter test --no-pub -j 1 test/unit/...`（必须 `-j 1` 串行，避免全局 DB 竞态）；单文件 `flutter test --no-pub test/unit/path/xxx_test.dart`。
- 提交规范：Conventional Commits 中文（`type(中文scope): 中文描述`），用 `chinese-commit-conventions` 技能。
- 代码生成：若新增 `@riverpod` 注解或 `@GenerateMocks`，运行 `dart run build_runner build --delete-conflicting-outputs`。
- 字段范围：保持 `title` + `chapters`，不补 author/简介/封面（`author` 维持硬编码 `''`）。
- 提取范围：agent 一次会话生成 `chapter_list_js` + `chapter_content_js` 两段（headless 跳转验证，不打扰用户当前页）。

## File Structure

**新建：**
- `novel_app/lib/services/agent_launcher/agent_launch_request.dart` — `AgentLaunchRequest` + `LaunchMode` 数据类
- `novel_app/lib/services/agent_launcher/contextual_agent_launcher.dart` — 启动器核心（`launch()` 编排）
- `novel_app/lib/core/providers/agent_launcher_providers.dart` — 启动器 Provider
- `novel_app/lib/widgets/agent_chat/agent_chat_launcher_entry.dart` — 编程式展开对话框的静态函数（从 `AgentFloatingButton._showChatDialog` 抽出）
- `novel_app/test/unit/services/agent_launcher/agent_launch_request_test.dart` — request 构造测试
- `novel_app/test/unit/services/agent_launcher/contextual_agent_launcher_test.dart` — launch 行为测试
- `novel_app/test/unit/widgets/webview_add_novel_fab_orchestration_test.dart` — FAB 三分支编排测试
- `novel_app/test/unit/services/agent_launcher/fab_launch_request_builder_test.dart` — 降级 request 构造测试

**修改：**
- `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart` — 加 `initialDraft` 参数，initState 预填 `_inputController`
- `novel_app/lib/widgets/agent_chat/agent_floating_button.dart` — `_showChatDialog` 改为调用抽取出的公共函数
- `novel_app/lib/widgets/webview_add_novel_button.dart` — `_handleAddNovel` 改造为三分支编排 + 失败降级触发启动器
- `novel_app/lib/core/providers/webview_add_novel_providers.dart` — `webviewHasAddNovelButtonProvider` 改为"http(s) 页面即显示"
- `novel_app/test/unit/providers/webview_add_novel_providers_test.dart` — 同步更新可见性断言

**契约 only（不在本计划实现，记录在 spec §7）：** 添加章节接入（`WritingScenario` 工具 + 目录页按钮）。

---

### Task 1: `AgentLaunchRequest` 数据类

**Files:**
- Create: `novel_app/lib/services/agent_launcher/agent_launch_request.dart`
- Test: `novel_app/test/unit/services/agent_launcher/agent_launch_request_test.dart`

**Interfaces:**
- Produces: `enum LaunchMode { autoSend, draftOnly }`、`class AgentLaunchRequest`（字段 `scenarioId`/`context`/`draftMessage`/`mode`/`title`）。后续 Task 全部依赖此类型。

- [ ] **Step 1: 写失败测试**

创建 `novel_app/test/unit/services/agent_launcher/agent_launch_request_test.dart`：

```dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/agent_launcher/agent_launch_request.dart';

void main() {
  group('AgentLaunchRequest', () {
    test('autoSend 模式构造', () {
      final req = AgentLaunchRequest(
        scenarioId: 'webview_extract',
        context: {'currentUrl': 'https://a.com/book/1', 'domain': 'a.com'},
        draftMessage: '请生成提取脚本',
        mode: LaunchMode.autoSend,
      );
      expect(req.scenarioId, 'webview_extract');
      expect(req.mode, LaunchMode.autoSend);
      expect(req.context['domain'], 'a.com');
      expect(req.title, isNull);
    });

    test('draftOnly 模式构造带标题', () {
      final req = AgentLaunchRequest(
        scenarioId: 'writing',
        context: {'novelId': 5},
        draftMessage: '请添加章节',
        mode: LaunchMode.draftOnly,
        title: '添加章节',
      );
      expect(req.mode, LaunchMode.draftOnly);
      expect(req.title, '添加章节');
    });

    test('draftMessage 不应为空断言', () {
      expect(
        () => AgentLaunchRequest(
          scenarioId: 'webview_extract',
          context: {},
          draftMessage: '',
          mode: LaunchMode.autoSend,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('scenarioId 不应为空断言', () {
      expect(
        () => AgentLaunchRequest(
          scenarioId: '',
          context: {},
          draftMessage: 'x',
          mode: LaunchMode.autoSend,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test --no-pub test/unit/services/agent_launcher/agent_launch_request_test.dart`
Expected: FAIL（文件不存在 / `AgentLaunchRequest` 未定义）

- [ ] **Step 3: 写实现**

创建 `novel_app/lib/services/agent_launcher/agent_launch_request.dart`：

```dart
/// 上下文式 Agent 启动器请求
library;

/// 启动模式
///
/// - [autoSend]：触发后自动发送草稿，agent 立即开跑（草稿作为可见首条 user message）
/// - [draftOnly]：草稿预填到输入框，等用户编辑后手动发送
enum LaunchMode { autoSend, draftOnly }

/// 通用 Agent 启动请求
///
/// 任意按钮点击 -> 注入上下文 -> 新建 agent 对话 -> 预填草稿 -> autoSend/draftOnly。
/// 字段 [context] 由调用方按场景自由填充，启动器本身不解读其内容；
/// 对 webview_extract 场景，currentUrl 等由 ScenarioSession._buildScenarioContext
/// 自动从 providers 读取，context 仅作为 draftMessage 生成的来源。
class AgentLaunchRequest {
  /// 目标场景 ID（'webview_extract' / 'writing'）
  final String scenarioId;

  /// 场景上下文（URL/domain/novel/失败原因/旧脚本…），由调用方填充
  final Map<String, dynamic> context;

  /// 预填草稿（autoSend 下作为首条 user message；draftOnly 下填入输入框）
  final String draftMessage;

  /// 启动模式
  final LaunchMode mode;

  /// 会话标题（可选）
  final String? title;

  const AgentLaunchRequest({
    required this.scenarioId,
    required this.context,
    required this.draftMessage,
    required this.mode,
    this.title,
  })  : assert(scenarioId.isNotEmpty, 'scenarioId 不应为空'),
        assert(draftMessage.isNotEmpty, 'draftMessage 不应为空');
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test --no-pub test/unit/services/agent_launcher/agent_launch_request_test.dart`
Expected: PASS（4 个测试通过）

- [ ] **Step 5: 提交**

```bash
cd D:/my_space/novel_builder
git add novel_app/lib/services/agent_launcher/agent_launch_request.dart novel_app/test/unit/services/agent_launcher/agent_launch_request_test.dart
git commit -m "feat(AI Agent): 添加 AgentLaunchRequest 数据类

通用启动器请求模型，支持 autoSend/draftOnly 两种模式。"
```

---

### Task 2: `AgentChatDialog` 支持 `initialDraft` 预填

**Files:**
- Modify: `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart`（`AgentChatDialog` 类 `:22-28`，`_inputController` `:31`，initState 位置）
- Test: 复用既有 `agent_chat_dialog` 测试若无则新增 widget 测试

**Interfaces:**
- Consumes: 无
- Produces: `AgentChatDialog({super.key, this.initialDraft})`，`initialDraft` 为 `String?`；非 null 时 initState 后 `_inputController.text = initialDraft`。Task 3/5 依赖此参数。

- [ ] **Step 1: 读现状确认 initState**

读 `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart` 的 `AgentChatDialog` 类定义（`:22-28`）和 `_AgentChatDialogState` 的 `initState`（用 Grep 定位 `void initState`）。确认 `_inputController` 在 `:31` 声明。

- [ ] **Step 2: 写失败测试**

创建 `novel_app/test/unit/widgets/agent_chat_dialog_draft_test.dart`：

```dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/widgets/agent_chat/agent_chat_dialog.dart';

void main() {
  group('AgentChatDialog initialDraft', () {
    testWidgets('initialDraft 非空时预填输入框', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AgentChatDialog(initialDraft: '请生成提取脚本'),
          ),
        ),
      );
      await tester.pump();
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      expect(
        tester.widget<TextField>(textField).controller!.text,
        '请生成提取脚本',
      );
    });

    testWidgets('initialDraft 为 null 时输入框为空', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AgentChatDialog()),
        ),
      );
      await tester.pump();
      final textField = find.byType(TextField);
      expect(
        tester.widget<TextField>(textField).controller!.text,
        '',
      );
    });
  });
}
```

- [ ] **Step 3: 运行测试验证失败**

Run: `flutter test --no-pub test/unit/widgets/agent_chat_dialog_draft_test.dart`
Expected: FAIL（`initialDraft` 参数不存在，编译错误）

- [ ] **Step 4: 修改实现**

在 `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart` 把 `AgentChatDialog` 改为：

```dart
class AgentChatDialog extends ConsumerStatefulWidget {
  /// 预填草稿（draftOnly 模式下由启动器注入；autoSend 模式不传）
  final String? initialDraft;

  const AgentChatDialog({super.key, this.initialDraft});

  @override
  ConsumerState<AgentChatDialog> createState() => _AgentChatDialogState();
}
```

在 `_AgentChatDialogState` 的 `initState` 末尾追加预填逻辑（用 Grep 找到 `void initState` 后，在其 `super.initState();` 之后、现有初始化之后追加）：

```dart
@override
void initState() {
  super.initState();
  // ... 现有初始化保持不变 ...
  if (widget.initialDraft != null) {
    _inputController.text = widget.initialDraft;
  }
}
```

- [ ] **Step 5: 运行测试验证通过**

Run: `flutter test --no-pub test/unit/widgets/agent_chat_dialog_draft_test.dart`
Expected: PASS

- [ ] **Step 6: 运行全量 agent_chat 相关测试确保无回归**

Run: `flutter test --no-pub -j 1 test/unit/widgets/ test/unit/services/novel_agent/`
Expected: 全部 PASS

- [ ] **Step 7: 提交**

```bash
cd D:/my_space/novel_builder
git add novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart novel_app/test/unit/widgets/agent_chat_dialog_draft_test.dart
git commit -m "feat(AI Agent): AgentChatDialog 支持 initialDraft 预填草稿"
```

---

### Task 3: 抽取公共展开函数 `AgentChatLauncherEntry`

**Files:**
- Create: `novel_app/lib/widgets/agent_chat/agent_chat_launcher_entry.dart`
- Modify: `novel_app/lib/widgets/agent_chat/agent_floating_button.dart`（`_showChatDialog` `:107-112`）

**Interfaces:**
- Consumes: Task 2 的 `AgentChatDialog.initialDraft`
- Produces: `AgentChatLauncherEntry.open(BuildContext, {String? initialDraft})` 静态方法，供 Task 5 启动器调用。

- [ ] **Step 1: 写失败测试**

创建 `novel_app/test/unit/widgets/agent_chat_launcher_entry_test.dart`：

```dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/widgets/agent_chat/agent_chat_launcher_entry.dart';

void main() {
  group('AgentChatLauncherEntry.open', () {
    testWidgets('调用后弹出 AgentChatDialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    AgentChatLauncherEntry.open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // AgentChatDialog 打开后会渲染输入框
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('带 initialDraft 打开后输入框已预填', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => AgentChatLauncherEntry.open(
                  context,
                  initialDraft: '预填内容',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final textField = find.byType(TextField).first;
      expect(
        tester.widget<TextField>(textField).controller!.text,
        '预填内容',
      );
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test --no-pub test/unit/widgets/agent_chat_launcher_entry_test.dart`
Expected: FAIL（`AgentChatLauncherEntry` 未定义）

- [ ] **Step 3: 写实现**

创建 `novel_app/lib/widgets/agent_chat/agent_chat_launcher_entry.dart`：

```dart
/// Agent 对话框编程式展开入口
///
/// 从 [AgentFloatingButton._showChatDialog] 抽出的公共函数，
/// 供 ContextualAgentLauncher 等非悬浮按钮入口复用。
library;

import 'package:flutter/material.dart';
import 'package:novel_app/widgets/agent_chat/agent_chat_dialog.dart';

class AgentChatLauncherEntry {
  AgentChatLauncherEntry._();

  /// 打开 AgentChatDialog
  ///
  /// [initialDraft] 非空时预填输入框（draftOnly 模式用）。
  static void open(BuildContext context, {String? initialDraft}) {
    showDialog(
      context: context,
      builder: (context) => AgentChatDialog(initialDraft: initialDraft),
    );
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test --no-pub test/unit/widgets/agent_chat_launcher_entry_test.dart`
Expected: PASS

- [ ] **Step 5: 改造 `AgentFloatingButton` 复用该函数**

读 `novel_app/lib/widgets/agent_chat/agent_floating_button.dart:1-15` 确认 import 区。把 `:107-112` 的 `_showChatDialog` 改为：

```dart
void _showChatDialog() {
  AgentChatLauncherEntry.open(context);
}
```

并在文件顶部 import 区追加：

```dart
import 'package:novel_app/widgets/agent_chat/agent_chat_launcher_entry.dart';
```

- [ ] **Step 6: 运行回归测试**

Run: `flutter test --no-pub -j 1 test/unit/widgets/`
Expected: 全部 PASS

- [ ] **Step 7: 提交**

```bash
cd D:/my_space/novel_builder
git add novel_app/lib/widgets/agent_chat/agent_chat_launcher_entry.dart novel_app/lib/widgets/agent_chat/agent_floating_button.dart novel_app/test/unit/widgets/agent_chat_launcher_entry_test.dart
git commit -m "refactor(AI Agent): 抽取 AgentChatLauncherEntry 公共展开入口"
```

---

### Task 4: `ContextualAgentLauncher` 核心编排

**Files:**
- Create: `novel_app/lib/services/agent_launcher/contextual_agent_launcher.dart`
- Create: `novel_app/lib/core/providers/agent_launcher_providers.dart`
- Test: `novel_app/test/unit/services/agent_launcher/contextual_agent_launcher_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `AgentLaunchRequest`；现有 `scenarioSessionsProvider.notifier`（`switchSession`）、`currentAgentScenarioProvider`、`currentSessionProvider`、`novelAgentServiceProvider.isRunningFor`。
- Produces: `class ContextualAgentLauncher`（`launch(BuildContext, AgentLaunchRequest)`）、`contextualAgentLauncherProvider`。Task 5/6 依赖。

- [ ] **Step 1: 确认 ScenarioSession 暴露的方法**

用 Grep 在 `novel_app/lib/core/providers/scenario_session.dart` 确认：
- `bool get isRunning` 是否存在（搜 `isRunning`）；若不存在，改用 `ref.read(novelAgentServiceProvider).isRunningFor(scenarioId)` 判断防重入。
- `Future<void> sendMessage(String content)` 的方法签名（搜 `Future<void> sendMessage` 或 `Future<void> _sendMessage`）。

把确认到的签名记下来，用于 Step 3 实现。

- [ ] **Step 2: 写失败测试**

创建 `novel_app/test/unit/services/agent_launcher/contextual_agent_launcher_test.dart`：

```dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/core/providers/agent_launcher_providers.dart';
import 'package:novel_app/core/providers/scenario_sessions_provider.dart';
import 'package:novel_app/core/providers/agent_scenario_provider.dart';
import 'package:novel_app/services/agent_launcher/agent_launch_request.dart';
import 'package:novel_app/services/agent_launcher/contextual_agent_launcher.dart';
import 'package:novel_app/services/novel_agent/agent_scenario.dart';

/// 占位 mock：记录 switchSession / 当前场景切换
class _FakeScenarioSessionsNotifier extends Fake
    implements ScenarioSessionsNotifier {
  int switchCallCount = 0;
  String? lastScenarioId;
  int? lastSessionId;

  @override
  Future<void> switchSession(String scenarioId, int? newSessionId) async {
    switchCallCount++;
    lastScenarioId = scenarioId;
    lastSessionId = newSessionId;
  }
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('ContextualAgentLauncher.launch', () {
    testWidgets('autoSend 模式：切场景 + switchSession(id, null) 触发新会话',
        (tester) async {
      final fakeNotifier = _FakeScenarioSessionsNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scenarioSessionsProvider
                .overrideWith((ref) => fakeNotifier),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    final launcher =
                        container.read(contextualAgentLauncherProvider);
                    await launcher.launch(
                      context,
                      AgentLaunchRequest(
                        scenarioId: ScenarioIds.webviewExtract,
                        context: {'currentUrl': 'https://a.com/book/1'},
                        draftMessage: '请生成提取脚本',
                        mode: LaunchMode.autoSend,
                      ),
                    );
                  },
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // 场景已切到 webview_extract
      expect(
        container.read(currentAgentScenarioProvider),
        ScenarioIds.webviewExtract,
      );
      // switchSession 被调用，传入 null 触发新建
      expect(fakeNotifier.switchCallCount, greaterThanOrEqualTo(1));
      expect(fakeNotifier.lastScenarioId, ScenarioIds.webviewExtract);
      expect(fakeNotifier.lastSessionId, isNull);
    });
  });
}
```

> 说明：此测试验证启动器对 `scenarioSessionsProvider.notifier.switchSession` 与 `currentAgentScenarioProvider` 的副作用。`autoSend` 的实际 `sendMessage` 依赖完整 ScenarioSession 与 LLM，在单测里不验证（留集成测试）。

- [ ] **Step 3: 运行测试验证失败**

Run: `flutter test --no-pub test/unit/services/agent_launcher/contextual_agent_launcher_test.dart`
Expected: FAIL（`ContextualAgentLauncher` / `contextualAgentLauncherProvider` 未定义）

- [ ] **Step 4: 写实现**

创建 `novel_app/lib/services/agent_launcher/contextual_agent_launcher.dart`：

```dart
/// 上下文式 Agent 启动器
///
/// 把"按钮点击"转化为"一次准备好上下文的 agent 对话"：
/// 1. 切换当前场景到 [AgentLaunchRequest.scenarioId]
/// 2. 防重入：若该场景已有 agent 在跑，聚焦现有对话框并提示
/// 3. switchSession(scenarioId, null) 触发全新会话（_ensureSessionId 自动新建）
/// 4. 打开 AgentChatDialog（draftOnly 模式预填草稿）
/// 5. autoSend 模式：调 ScenarioSession.sendMessage(draftMessage) 立即发送
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/core/providers/agent_scenario_provider.dart';
import 'package:novel_app/core/providers/scenario_sessions_provider.dart';
import 'package:novel_app/services/agent_launcher/agent_launch_request.dart';
import 'package:novel_app/services/novel_agent/novel_agent_service.dart';
import 'package:novel_app/widgets/agent_chat/agent_chat_launcher_entry.dart';

class ContextualAgentLauncher {
  final Ref _ref;

  ContextualAgentLauncher(this._ref);

  /// 启动一次上下文式 agent 对话
  Future<void> launch(BuildContext context, AgentLaunchRequest request) async {
    final notifier = _ref.read(scenarioSessionsProvider.notifier);

    // 1. 切换场景
    _ref.read(currentAgentScenarioProvider.notifier).state = request.scenarioId;

    // 2. 防重入：该场景已有 agent 运行中 -> 聚焦现有对话框并提示
    final agentService = _ref.read(novelAgentServiceProvider);
    if (agentService.isRunningFor(request.scenarioId)) {
      AgentChatLauncherEntry.open(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('上一次提取仍在进行中')),
      );
      return;
    }

    // 3. 触发全新会话：adoptSession(null) 清空 sessionId/状态，
    //    下次 sendMessage 时 _ensureSessionId 自动新建 ChatSession。
    await notifier.switchSession(request.scenarioId, null);

    // 4. 打开对话框；draftOnly 模式预填草稿
    AgentChatLauncherEntry.open(
      context,
      initialDraft:
          request.mode == LaunchMode.draftOnly ? request.draftMessage : null,
    );

    // 5. autoSend 模式：立即发送（草稿作为首条可见 user message）
    if (request.mode == LaunchMode.autoSend) {
      final session = notifier.get(request.scenarioId);
      await session.sendMessage(request.draftMessage);
    }
  }
}
```

创建 `novel_app/lib/core/providers/agent_launcher_providers.dart`：

```dart
/// Agent 启动器 Provider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/services/agent_launcher/contextual_agent_launcher.dart';

final contextualAgentLauncherProvider =
    Provider<ContextualAgentLauncher>((ref) {
  return ContextualAgentLauncher(ref);
});
```

- [ ] **Step 5: 运行测试验证通过**

Run: `flutter test --no-pub test/unit/services/agent_launcher/contextual_agent_launcher_test.dart`
Expected: PASS

> 若 `ScenarioSessionsNotifier` 的 `Fake` 因 sealed/final 不可实现，改用 `mockito` 的 `@GenerateMocks([ScenarioSessionsNotifier])`（需 `dart run build_runner build --delete-conflicting-outputs`），或改测更底层的 `switchSession` 调用断言（用 `verify`）。

- [ ] **Step 6: 提交**

```bash
cd D:/my_space/novel_builder
git add novel_app/lib/services/agent_launcher/contextual_agent_launcher.dart novel_app/lib/core/providers/agent_launcher_providers.dart novel_app/test/unit/services/agent_launcher/contextual_agent_launcher_test.dart
git commit -m "feat(AI Agent): 实现 ContextualAgentLauncher 核心编排

按钮点击->切场景->switchSession(id,null)新建会话->打开对话框->autoSend/draftOnly。"
```

---

### Task 5: FAB 可见性改为 http(s) 页面即显示

**Files:**
- Modify: `novel_app/lib/core/providers/webview_add_novel_providers.dart`（`webviewHasAddNovelButtonProvider` `:57-63`）
- Modify: `novel_app/test/unit/providers/webview_add_novel_providers_test.dart`（已有，更新断言）

**Interfaces:**
- Produces: `webviewHasAddNovelButtonProvider` 返回"当前页是否 http(s) 页面"，无脚本也显示。

- [ ] **Step 1: 读现有测试**

读 `novel_app/test/unit/providers/webview_add_novel_providers_test.dart` 全文，找到现有对 `webviewHasAddNovelButtonProvider` 的断言用例（之前已知 `:22-63` 有 setUp，断言在文件后段）。

- [ ] **Step 2: 更新测试断言**

把 `webviewHasAddNovelButtonProvider` 相关用例改为：

```dart
group('webviewHasAddNovelButtonProvider', () {
  test('http(s) 页面 -> 显示 FAB（无论有无脚本）', () {
    container.read(webviewCurrentUrlProvider.notifier).state =
        'https://unknown-site.com/book/123';
    // 即使无脚本也显示（降级到 agent 生成）
    expect(container.read(webviewHasAddNovelButtonProvider), isTrue);
  });

  test('非 http(s) 页面 -> 不显示 FAB', () {
    container.read(webviewCurrentUrlProvider.notifier).state =
        'about:blank';
    expect(container.read(webviewHasAddNovelButtonProvider), isFalse);
  });

  test('空 URL -> 不显示 FAB', () {
    container.read(webviewCurrentUrlProvider.notifier).state = '';
    expect(container.read(webviewHasAddNovelButtonProvider), isFalse);
  });
});
```

- [ ] **Step 3: 运行测试验证失败**

Run: `flutter test --no-pub test/unit/providers/webview_add_novel_providers_test.dart`
Expected: FAIL（现有实现"有脚本才显示"，新断言要求"无脚本也显示"）

- [ ] **Step 4: 修改 provider 实现**

把 `novel_app/lib/core/providers/webview_add_novel_providers.dart:57-63` 的 `webviewHasAddNovelButtonProvider` 改为：

```dart
/// 是否显示"添加到书架"FAB
///
/// 改为：当前页是 http(s) 页面即显示（无脚本时点击走 agent 降级生成）。
final webviewHasAddNovelButtonProvider = Provider<bool>((ref) {
  final domain = ref.watch(webviewCurrentDomainProvider);
  return domain != null;
});
```

> `webviewCurrentDomainProvider` 已在 `:22-32` 实现"非 http(s) 返回 null"，复用它判断。

- [ ] **Step 5: 运行测试验证通过**

Run: `flutter test --no-pub test/unit/providers/webview_add_novel_providers_test.dart`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
cd D:/my_space/novel_builder
git add novel_app/lib/core/providers/webview_add_novel_providers.dart novel_app/test/unit/providers/webview_add_novel_providers_test.dart
git commit -m "feat(添加书架): FAB 可见性改为 http(s) 页面即显示

无脚本时也显示 FAB，点击走 agent 降级生成提取脚本。"
```

---

### Task 6: 降级 request 构造器 `FabLaunchRequestBuilder`

**Files:**
- Create: `novel_app/lib/widgets/agent_chat/fab_launch_request_builder.dart`
- Test: `novel_app/test/unit/services/agent_launcher/fab_launch_request_builder_test.dart`

**Interfaces:**
- Consumes: Task 1 `AgentLaunchRequest`
- Produces: `FabLaunchRequestBuilder.build({required String currentUrl, String? domain, String? oldScript, required FabFailureReason reason})` -> `AgentLaunchRequest`。Task 7 依赖。

- [ ] **Step 1: 写失败测试**

创建 `novel_app/test/unit/services/agent_launcher/fab_launch_request_builder_test.dart`：

```dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/agent_launcher/agent_launch_request.dart';
import 'package:novel_app/widgets/agent_chat/fab_launch_request_builder.dart';

void main() {
  group('FabLaunchRequestBuilder.build', () {
    test('无脚本 -> draftMessage 含域名与 URL，autoSend', () {
      final req = FabLaunchRequestBuilder.build(
        currentUrl: 'https://a.com/book/123',
        domain: 'a.com',
        oldScript: null,
        reason: FabFailureReason.noScript,
      );
      expect(req.scenarioId, 'webview_extract');
      expect(req.mode, LaunchMode.autoSend);
      expect(req.draftMessage, contains('a.com'));
      expect(req.draftMessage, contains('https://a.com/book/123'));
      expect(req.context['currentUrl'], 'https://a.com/book/123');
      expect(req.context['domain'], 'a.com');
      expect(req.context['oldScript'], isNull);
      expect(req.context['failureReason'], 'noScript');
    });

    test('脚本报错 -> draftMessage 含错误信息', () {
      final req = FabLaunchRequestBuilder.build(
        currentUrl: 'https://a.com/book/123',
        domain: 'a.com',
        oldScript: '(async function(){...})()',
        reason: FabFailureReason.scriptError,
        errorMessage: 'JS_REFERENCE_ERROR: a is not defined',
      );
      expect(req.draftMessage, contains('JS_REFERENCE_ERROR'));
      expect(req.context['oldScript'], '(async function(){...})()');
      expect(req.context['failureReason'], 'scriptError');
    });

    test('脚本空结果 -> draftMessage 引导先判断目录页', () {
      final req = FabLaunchRequestBuilder.build(
        currentUrl: 'https://a.com/book/123',
        domain: 'a.com',
        oldScript: '(async function(){...})()',
        reason: FabFailureReason.emptyResult,
      );
      expect(req.draftMessage, contains('get_page_info'));
      expect(req.draftMessage, contains('目录页'));
      expect(req.context['failureReason'], 'emptyResult');
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test --no-pub test/unit/services/agent_launcher/fab_launch_request_builder_test.dart`
Expected: FAIL（`FabLaunchRequestBuilder` 未定义）

- [ ] **Step 3: 写实现**

创建 `novel_app/lib/widgets/agent_chat/fab_launch_request_builder.dart`：

```dart
/// FAB 降级触发 agent 的请求构造器
///
/// 把 FAB 三分支中的"失败/无脚本"情况转化为 AgentLaunchRequest，
/// 分流指令靠 draftMessage 承载（agent 读首条 user message 自行判断目录页）。
library;

import 'package:novel_app/services/agent_launcher/agent_launch_request.dart';
import 'package:novel_app/services/novel_agent/agent_scenario.dart';

/// FAB 降级原因
enum FabFailureReason {
  /// 当前域名无提取脚本
  noScript,

  /// 脚本执行报错（JS 异常 / 超时）
  scriptError,

  /// 脚本返回空结果（可能不在目录页，或脚本失效）
  emptyResult,
}

class FabLaunchRequestBuilder {
  FabLaunchRequestBuilder._();

  /// 构造降级请求
  ///
  /// [errorMessage] 仅 reason==scriptError 时提供（JS 错误信息）。
  static AgentLaunchRequest build({
    required String currentUrl,
    required String domain,
    required String? oldScript,
    required FabFailureReason reason,
    String? errorMessage,
  }) {
    final draftMessage = _buildDraftMessage(
      currentUrl: currentUrl,
      domain: domain,
      reason: reason,
      errorMessage: errorMessage,
    );

    return AgentLaunchRequest(
      scenarioId: ScenarioIds.webviewExtract,
      context: {
        'currentUrl': currentUrl,
        'domain': domain,
        'oldScript': oldScript,
        'failureReason': reason.name,
        if (errorMessage != null) 'errorMessage': errorMessage,
      },
      draftMessage: draftMessage,
      mode: LaunchMode.autoSend,
    );
  }

  static String _buildDraftMessage({
    required String currentUrl,
    required String domain,
    required FabFailureReason reason,
    String? errorMessage,
  }) {
    switch (reason) {
      case FabFailureReason.noScript:
        return '当前站点($domain)还没有提取脚本。'
            '请为目录页 $currentUrl 编写目录提取脚本和正文提取脚本：'
            '先用 get_page_info 确认是否为目录页，'
            '若是目录页则生成 chapter_list_js 并验证，'
            '再 navigate_to 第一章生成验证 chapter_content_js，'
            '最后 save_script 保存。';
      case FabFailureReason.scriptError:
        return '现有目录提取脚本执行失败：${errorMessage ?? "未知错误"}。'
            '请先用 get_page_info 确认当前 $currentUrl 是否为目录页，'
            '若不是请引导用户前往目录页；若是请修复脚本。'
            '旧脚本可由 get_cached_script(domain="$domain") 读取。';
      case FabFailureReason.emptyResult:
        return '现有脚本未提取到章节。请先用 get_page_info 确认当前 '
            '$currentUrl 是否为目录页：若不是，请在回复中引导用户前往小说目录页；'
            '若是目录页，请修复脚本（旧脚本由 get_cached_script(domain="$domain") 读取）。';
    }
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test --no-pub test/unit/services/agent_launcher/fab_launch_request_builder_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
cd D:/my_space/novel_builder
git add novel_app/lib/widgets/agent_chat/fab_launch_request_builder.dart novel_app/test/unit/services/agent_launcher/fab_launch_request_builder_test.dart
git commit -m "feat(添加书架): 添加 FabLaunchRequestBuilder 降级请求构造器

按 noScript/scriptError/emptyResult 三类失败生成 draftMessage，
分流指令由 agent 读首条 user message 自行判断目录页。"
```

---

### Task 7: FAB 三分支编排改造 `_handleAddNovel`

**Files:**
- Modify: `novel_app/lib/widgets/webview_add_novel_button.dart`（`_handleAddNovel` `:76-269`，imports）
- Test: `novel_app/test/unit/widgets/webview_add_novel_fab_orchestration_test.dart`

**Interfaces:**
- Consumes: Task 4 `contextualAgentLauncherProvider`、Task 5 新可见性 provider、Task 6 `FabLaunchRequestBuilder`。现有 `webviewCurrentSiteScriptProvider`/`webviewCurrentUrlProvider`/`webviewCurrentDomainProvider`/`webviewControllerProvider`/`WebViewJsExecutor`/`AddNovelPreviewSheet`/`novelRepositoryProvider`/`chapterRepositoryProvider`/`siteScriptRepositoryProvider`。
- Produces: 改造后的 `_handleAddNovel` 三分支编排。

- [ ] **Step 1: 写失败测试（编排逻辑单测）**

创建 `novel_app/test/unit/widgets/webview_add_novel_fab_orchestration_test.dart`：

```dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/core/providers/agent_launcher_providers.dart';
import 'package:novel_app/core/providers/webview_add_novel_providers.dart';
import 'package:novel_app/core/providers/webview_providers.dart';
import 'package:novel_app/services/agent_launcher/agent_launch_request.dart';
import 'package:novel_app/services/agent_launcher/contextual_agent_launcher.dart';
import 'package:novel_app/widgets/webview_add_novel_button.dart';

class _MockLauncher extends Mock implements ContextualAgentLauncher {}

void main() {
  late _MockLauncher launcher;
  late ProviderContainer container;

  setUp(() {
    launcher = _MockLauncher();
    container = ProviderContainer(
      overrides: [
        contextualAgentLauncherProvider.overrideWithValue(launcher),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpFab(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: WebViewAddNovelFab(),
          ),
        ),
      ),
    );
  }

  testWidgets('无脚本时点击 FAB -> 触发 launcher.launch(autoSend, noScript)',
      (tester) async {
    // 设置无脚本 + http 页面
    container.read(webviewCurrentUrlProvider.notifier).state =
        'https://a.com/book/123';
    // webviewCurrentSiteScriptProvider 会返回 null（无该 domain 脚本）
    await tester.pump();
    // FAB 应可见
    expect(find.byTooltip('添加小说'), findsOneWidget);

    await tester.tap(find.byTooltip('添加小说'));
    await tester.pumpAndSettle();

    final captured = verify(
      launcher.launch(captureAny, captureThat(isA<AgentLaunchRequest>()),
          context: anyNamed('context')),
    ).captured;
    // launch 至少被调用一次
    expect(captured, isNotEmpty);
  });
}
```

> 说明：FAB 改造后，无脚本分支调用 `launcher.launch`。此测试验证"点击 -> launch 被调用"。完整的"有脚本成功/失败"分支涉及真实 WebView 执行 JS，在 widget 单测里不验证（留集成测试或手动验证）。若 `launch` 签名为 `launch(BuildContext, AgentLaunchRequest)`，调整 `verify` 捕获。

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test --no-pub test/unit/widgets/webview_add_novel_fab_orchestration_test.dart`
Expected: FAIL（当前 `_handleAddNovel` 无脚本时只 toast"未找到该网站的提取脚本"，不调 launcher）

- [ ] **Step 3: 改造 `_handleAddNovel`**

读 `novel_app/lib/widgets/webview_add_novel_button.dart:1-20`（imports）和 `:76-269`（`_handleAddNovel`）。

在 imports 追加：

```dart
import 'package:novel_app/core/providers/agent_launcher_providers.dart';
import 'package:novel_app/widgets/agent_chat/fab_launch_request_builder.dart';
```

把 `_handleAddNovel` 的**开头**（原 `:76-103` 取脚本+控制器+URL 段）改造为三分支调度。保留 `:126-269` 的"解析返回值 -> isInBookshelf -> 预览 -> 入库"逻辑不变（那是快速路径成功的后续）。

新的 `_handleAddNovel` 开头：

```dart
Future<void> _handleAddNovel(BuildContext context) async {
  // 1. 取当前 URL 与域名
  final currentUrl = ref.read(webviewCurrentUrlProvider);
  if (currentUrl.isEmpty) {
    _toast('无法获取当前页面链接', isError: true);
    return;
  }
  final domain = ref.read(webviewCurrentDomainProvider);
  if (domain == null) {
    _toast('当前页面不是 http(s) 页面', isError: true);
    return;
  }

  // 2. 取脚本（可能为 null -> 无脚本降级）
  final script = ref.read(webviewCurrentSiteScriptProvider).valueOrNull;

  // 3. 取 WebView 控制器
  final controller = ref.read(webviewControllerProvider);
  if (controller == null) {
    _toast('浏览器未就绪', isError: true);
    return;
  }

  // 4. 无脚本分支 -> 降级 agent
  if (script == null) {
    await _launchAgent(context, currentUrl, domain, null,
        FabFailureReason.noScript);
    return;
  }

  setState(() => _isExtracting = true);
  try {
    // 5. 有脚本分支：校验 -> 执行 -> 解析（保留原逻辑）
    final validationError = WebViewJsExecutor.validateScript(script.chapterListJs);
    if (validationError != null) {
      // 校验失败 -> 降级修复
      await _launchAgent(context, currentUrl, domain, script.chapterListJs,
          FabFailureReason.scriptError,
          errorMessage: validationError);
      return;
    }

    final resolvedScript = script.chapterListJs.replaceAll('{{URL}}', currentUrl);
    final functionBody = WebViewJsExecutor.extractAsyncFunctionBody(resolvedScript);
    final jsResult = await controller
        .callAsyncJavaScript(functionBody: functionBody)
        .timeout(const Duration(seconds: 60));

    if (jsResult == null) {
      await _launchAgent(context, currentUrl, domain, script.chapterListJs,
          FabFailureReason.emptyResult);
      return;
    }
    if (jsResult.error != null) {
      await _launchAgent(context, currentUrl, domain, script.chapterListJs,
          FabFailureReason.scriptError,
          errorMessage: jsResult.error);
      return;
    }

    final resultStr = WebViewJsExecutor.stringifyJsResult(jsResult.value);
    final data = jsonDecode(resultStr) as Map<String, dynamic>;
    final extractedTitle = (data['title'] as String?)?.trim() ?? '';
    final chaptersRaw = data['chapters'] as List<dynamic>?;

    if (extractedTitle.isEmpty ||
        chaptersRaw == null ||
        chaptersRaw.isEmpty) {
      await _launchAgent(context, currentUrl, domain, script.chapterListJs,
          FabFailureReason.emptyResult);
      return;
    }

    // ... 保留原 :150-269 的"转类型化数据 -> isInBookshelf -> 预览 -> 入库"逻辑 ...
    // （此处省略，保持原代码不变，只把 _isExtracting=false 在 finally 保留）
  } on TimeoutException {
    await _launchAgent(context, currentUrl, domain, script.chapterListJs,
        FabFailureReason.scriptError,
        errorMessage: '提取超时(>60s)');
  } catch (e) {
    await _launchAgent(context, currentUrl, domain, script.chapterListJs,
        FabFailureReason.scriptError,
        errorMessage: e.toString());
  } finally {
    if (mounted) setState(() => _isExtracting = false);
  }
}

/// 降级触发 agent
Future<void> _launchAgent(
  BuildContext context,
  String currentUrl,
  String domain,
  String? oldScript,
  FabFailureReason reason, {
  String? errorMessage,
}) async {
  final launcher = ref.read(contextualAgentLauncherProvider);
  final request = FabLaunchRequestBuilder.build(
    currentUrl: currentUrl,
    domain: domain,
    oldScript: oldScript,
    reason: reason,
    errorMessage: errorMessage,
  );
  await launcher.launch(context, request);
}
```

> 注意：原 `:150-269` 的章节转换/isInBookshelf/预览/入库逻辑**原样保留**在 `try` 块中（计划里省略是为避免重复，实施时只改分支头尾，不动中段）。`controller.callAsyncJavaScript(...)` 的调用方式按原 `:124` 的真实写法保持（原代码用 `.timeout(...)` 链式，此处示意）。

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test --no-pub test/unit/widgets/webview_add_novel_fab_orchestration_test.dart`
Expected: PASS

- [ ] **Step 5: 运行全量回归**

Run: `flutter test --no-pub -j 1 test/unit/widgets/ test/unit/providers/ test/unit/services/`
Expected: 全部 PASS

- [ ] **Step 6: 提交**

```bash
cd D:/my_space/novel_builder
git add novel_app/lib/widgets/webview_add_novel_button.dart novel_app/test/unit/widgets/webview_add_novel_fab_orchestration_test.dart
git commit -m "feat(添加书架): FAB 改造为三分支编排

有脚本走快速路径入库；脚本失败/无脚本降级触发提取 agent。
职责分离：agent 只管脚本，FAB 管书架数据，靠 site_scripts 表解耦。"
```

---

### Task 8: agent 分流指令验证（手动 + 集成）

**Files:**
- 无新文件（验证 Task 6 的 draftMessage 是否真的引导 agent 正确分流）
- 参考现有集成测试：`novel_app/test/integration/webview_extract_headless_integration_test.dart`

**说明：** agent 内部分流（目录页判断 vs 修复脚本）完全靠 `FabLaunchRequestBuilder` 生成的 `draftMessage`，不需要改 `webview_extract_scenario.dart` 的 `buildSystemPrompt`（静态模板）。本任务通过手动验证 + 参考集成测试确认分流生效。

- [ ] **Step 1: 确认现有集成测试模式**

读 `novel_app/test/integration/webview_extract_headless_integration_test.dart` 前 60 行，了解 headless 提取的集成测试如何 mock WebView + 验证 `save_script`。

- [ ] **Step 2: 手动验证清单**

在真机/模拟器上验证三个场景（记录到 `docs/superpowers/specs/2026-07-08-contextual-agent-launcher-design.md` 的 review 备注，或单独的手测记录）：

1. **无脚本站点**：访问一个 `site_scripts` 表里没有的域名目录页 -> 点 FAB -> 对话框展开 -> agent 自动开跑 -> `get_page_info` 判定目录页 -> 生成两段脚本 -> `save_script` -> 对话框提示"脚本已就绪" -> 重新点 FAB -> 快速路径入库成功。
2. **脚本失效**：人为破坏一个已有脚本的 `chapterListJs`（如改错选择器）-> 在目录页点 FAB -> 快速路径空结果 -> 降级 agent -> draftMessage 引导"先用 get_page_info 确认目录页" -> agent 判定目录页 -> 修复脚本 -> save_script -> 重试 FAB 成功。
3. **非目录页**：在章节正文页点 FAB -> 快速路径空结果 -> 降级 agent -> `get_page_info` 判定非目录页 -> agent 在对话框发文字"请前往小说目录页" -> 不提取、不存脚本。

- [ ] **Step 3: 运行全部测试确认无回归**

Run: `flutter test --no-pub -j 1 test/unit/ test/integration/`
Expected: 全部 PASS（集成测试若依赖真实网络/WebView 可跳过，记录原因）

- [ ] **Step 4: 提交手测记录（可选）**

若有手测记录文件，提交：

```bash
cd D:/my_space/novel_builder
git add <手测记录文件>
git commit -m "test(添加书架): 记录 agent 分流手测结果"
```

---

## Self-Review

**1. Spec 覆盖：**
- §3 启动器核心 -> Task 1/2/3/4 ✓
- §4 整体架构 -> Task 4 编排 ✓
- §5 ContextualAgentLauncher API -> Task 1/4 ✓
- §6.1 FAB 三分支 -> Task 7 ✓
- §6.1 FAB 可见性改造 -> Task 5 ✓
- §6.2 降级 request -> Task 6 ✓
- §6.3 agent 分流 -> 靠 Task 6 draftMessage + Task 8 验证（不改 buildSystemPrompt）✓
- §6.4 用户重试入库 -> Task 7 快速路径保留 + Task 8 手测场景1 ✓
- §6.5 进度展示 -> 复用现有 extractionTaskProvider（无需改动）✓
- §7 添加章节契约 -> spec 已记录，不在本计划实现 ✓
- §9 错误处理 -> Task 7 catch 分支降级 + Task 4 防重入 ✓
- §10 测试 -> 各 Task 均含测试 ✓

**2. 占位符扫描：** Task 7 Step 3 的 `_handleAddNovel` 中段标注"保留原逻辑省略"——这是为避免重复原文件的 100+ 行，实施时需照搬 `:150-269`。这是计划里唯一需要实施者回看原文件的地方，已明确标注行号。其余步骤代码完整。

**3. 类型一致性：**
- `AgentLaunchRequest`（scenarioId/context/draftMessage/mode/title）全 Task 一致 ✓
- `LaunchMode.autoSend/draftOnly` 全 Task 一致 ✓
- `FabFailureReason.noScript/scriptError/emptyResult` Task 6/7 一致 ✓
- `FabLaunchRequestBuilder.build` 签名 Task 6 定义、Task 7 调用一致 ✓
- `ContextualAgentLauncher.launch(BuildContext, AgentLaunchRequest)` Task 4 定义、Task 7 调用一致 ✓
- `AgentChatLauncherEntry.open(context, {initialDraft})` Task 3 定义、Task 4 调用一致 ✓
- `AgentChatDialog({initialDraft})` Task 2 定义、Task 3 调用一致 ✓

**4. 已知实施风险：**
- Task 4 的 `_FakeScenarioSessionsNotifier` 若 `ScenarioSessionsNotifier` 不可继承（final/sealed），需改 `@GenerateMocks` + `build_runner`。已在 Task 4 Step 5 备注。
- Task 7 的 `controller.callAsyncJavaScript(...)` 写法需对照原文件 `:124` 真实写法（原代码用 `.timeout` 链式），实施时照搬原句。
- `webviewCurrentDomainProvider` 已存在（`webview_add_novel_providers.dart:22-32`），Task 5/7 直接复用，无需新建。
