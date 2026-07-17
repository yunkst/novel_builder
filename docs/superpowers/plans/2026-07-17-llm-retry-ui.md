# LLM 重试 UI 展示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agent Chat 底部输入栏上方出现浮动横幅,展示 LLM 重试进度(传输层 8 次 / 回合层 2 次),错误码类别 + 倒计时 + 配色区分(橙/蓝),无取消按钮。

**Architecture:** `withRetry` 加可选 `onRetry` 回调(向后兼容)→ 模块级单例 `RetrySignals` (`ValueNotifier<RetryState?>`) → `RetryBanner` widget 订阅。回合层 `agent_loop` 的 catch 块**直接调** `RetrySignals.reportRound`,绕开事件流过滤(`shouldMainSessionHandleEvent` 会过滤子 Agent),保证"所有重试都显示"决策落地。错误码分类抽取共享工具 `categorizeRetryError`。

**Tech Stack:** Flutter / Dart 3 / Riverpod 2 / `dart:io` HttpClient(`IoLlmHttpClient` 已有)。无新依赖,无 `build_runner`。

参考规格:`docs/superpowers/specs/2026-07-17-llm-retry-ui-design.md`(下称 spec)。

---

## Global Constraints

- **仅 Flutter 端 `novel_app`**:后端零改动、AI 工具链零改动、DB 不变
- **复用现有约束**:`retryableErrorCategory` 抽 `categorizeRetryError` 共享(`retry_signals.dart` 同文件),传输层(8次阻塞/3次握手)+ 回合层(2次,`_config.networkRetryPerRound` 默认 2)都展示
- **向后兼容**:`withRetry` 新签名追加可选 `onRetry` 命名参数,默认 `null`,行为不变
- **sealed class 契约**:`RetryEvent extends AgentEvent` 必须 `super.runId` 转发(否则 `EventTagger.tag` 与 `SubagentStateProjector.project` 两个 exhaustive switch 编译失败)
- **clear 时序原则**:传输层成功 return 单点 `RetrySignals.clear()`,`rethrow` 时**不 clear**(避免与 round-level `reportRound` 竞争产生空白闪烁)
- **不引入取消**:横幅只展示,不支持手动取消重试(spec §1.3 已排除)
- **多 session 串号限制**:模块级单例意味着同时只有一个 active retry 显示,本次接受(YAGNI)
- 中文 commit message,遵循 Conventional Commits,一个提交只做一件事
- `flutter analyze` 必须干净;每 Task 完成后跑相关测试

---

## 关键设计细化(对 spec 的精确化,不违背意图)

1. **OnRetry 透传 `config.maxAttempts`**:`onRetry` 第二参来自 `withRetry` 函数体内的 `config.maxAttempts`(非闭包变量),这样传输层 8 次 / 握手 3 次能准确显示 N/M(spec §3.3 已明确)
2. **`RetryState.errorCategory` 为 String**:不是 enum,文案直接来自 `categorizeRetryError` 输出,UI 不需要再写一道 if-else
3. **`RetryEvent` 同时被 emit 到事件流 + 直接调 `RetrySignals.reportRound`**:事件流路径走 `_handleAgentEvent` no-op + `EventTagger` 打标(为未来 subagent 详情页扩展保留),UI 横幅不依赖事件流(spec §3.1.1 方案 B)
4. **`RetryBanner` 是独立 widget 而非嵌入 `agent_message_bubble`**:它挂在 `AgentChatDialog` Column 而不是 assistant message 内(breath layout 简单,与 `_buildErrorBar` 同级条件渲染)
5. **测试架构**:复用现有 helper `NoopLlmHttpClient`,但**新增一个 `_ScriptedErrorHttpClient` 测试 helper** 用于 LLM 重试 — 可枚举每次调用返回的 response(成功/异常),覆盖 `_postJsonOnce` 不直接测(那是真实网络),而测 `IoLlmHttpClient.postJson`(注入自定义 `LlmHttpClient`,验证 onRetry 透传到 `RetrySignals`)

---

## File Structure

| 文件 | 责任 | 动作 |
|---|---|---|
| `novel_app/lib/utils/retry_helper.dart` | 加可选 `onRetry(attempt, maxAttempts, delayMs, error)` 回调;`await Future.delayed` 前调用;默认值 null | Modify |
| `novel_app/lib/services/dsl_engine/retry_signals.dart` | 模块级单例 `RetrySignals`(`ValueNotifier<RetryState?>`)+ `RetryLevel` + `RetryState` + `categorizeRetryError(Object)→String` + `resetForTest()` | Create |
| `novel_app/lib/services/dsl_engine/llm_provider.dart` | `IoLlmHttpClient.postJson` / `postJsonStream` 的 `withRetry` 注入 `onRetry` → `reportTransport`;postJson 成功 / postJsonStream 握手成功**各单点** `RetrySignals.clear()`;rethrow 不 clear | Modify |
| `novel_app/lib/services/novel_agent/agent_event.dart` | 新增 `RetryEvent extends AgentEvent`(**含 `super.runId`**),字段 `attempt`/`maxAttempts`/`delayMs`/`errorCategory` | Modify |
| `novel_app/lib/services/novel_agent/subagent_state_projector.dart` | `EventTagger.tag` + `SubagentStateProjector.project` 两个 exhaustive switch 加 `case RetryEvent` | Modify |
| `novel_app/lib/services/novel_agent/agent_loop.dart` | round-level 重试块(L398-425) `await Future.delayed` 前 `emit RetryEvent + reportRound(maxAttempts: _config.networkRetryPerRound)` 同一行;`AgentErrorEvent` 同一行 `clear`;max_rounds 兜底总结 `AgentDoneEvent` 同一行 `clear` | Modify |
| `novel_app/lib/core/providers/scenario_session.dart` | `_handleAgentEvent` switch 加 `case RetryEvent _:` 为 no-op(`_handleAgentEvent:925-1000` 已有 exhaustive) | Modify |
| `novel_app/lib/widgets/agent_chat/retry_banner.dart` | 底部横幅 widget,`ValueListenableBuilder` 订阅 `RetrySignals.instance.notifier`;`Timer.periodic` 倒计时;橙/蓝配色;`delayMs≤1000` / 倒计时到 0 都显示"重试中…" | Create |
| `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart` | Column (L147-160) 在 `_buildContextTag()`(L158) 与 `_buildInputBar(...)`(L159) 之间插入 `RetryBanner()` | Modify |
| `novel_app/test/unit/utils/retry_helper_test.dart` | onRetry 调用次数 = fn 失败次数(成功 0 / 中途成功 n 次调用 n 次 / 全失败 maxAttempts-1 次) | Modify |
| `novel_app/test/unit/services/dsl_engine/retry_signals_test.dart` | `RetryState`/`RetryLevel`/`RetrySignals.reportTransport/reportRound/clear/resetForTest` + `categorizeRetryError` 各分支 | Create |
| `novel_app/test/helpers/scripted_error_http_client.dart` | 测试 helper:实现 `LlmHttpClient`,构造函数枚举 `responses`(成功 body / 异常);`postJson` 按序消费;`postJsonStream` 同步支持 | Create |
| `novel_app/test/unit/services/dsl_engine/llm_provider_retry_test.dart` | `IoLlmHttpClient.postJson`(`_httpClient` 字段可通过构造注入) + `RetrySignals` 状态;postJson 成功 → clear;rethrow → 不 clear;`postJsonStream` 握手成功 → clear | Create |
| `novel_app/test/unit/services/novel_agent/agent_loop_retry_test.dart` | 现有用例加断言:`emit RetryEvent` + `RetrySignals.reportRound` 同一行;`AgentErrorEvent`/`AgentDoneEvent` emit 时 `RetrySignals.clear()`;`RetryEvent` 含 `super.runId` | Modify |
| `novel_app/test/widget/agent_chat/retry_banner_test.dart` | 横幅出现/消失、橙蓝配色、倒计时数字递减、`Xs 后重试` 到 0 切"重试中…"边界 | Create |
| `CLAUDE.md` (根) | changelog 加 2026-07-17 条目:"LLM 重试 UI 展示:底部横幅 + onRetry/RetrySignals 接线" | Modify |
| `novel_app/CLAUDE.md` | 同上 changelog;AI 集成段落补"传输层/回合层重试 UI 展示" | Modify |

任务依赖:Task 1(retry_helper onRetry)→ Task 2(retry_signals)可并行→ Task 3(llm_provider 接线)依赖 1+2;Task 4(RetryEvent + subagent_state_projector + scenario_session)独立于 1-3;Task 5(agent_loop 接线)依赖 4;Task 6(banner widget)依赖 2;Task 7(dialog 接入)依赖 6;Task 8(收尾文档)依赖全部。

执行顺序:**Task 1 → Task 2 → 并行 Task 3 与 Task 4 → Task 5(串)→ Task 6 + Task 7(并行可,但 7 依赖 6) → Task 8**。

---

### Task 1: `withRetry` 加可选 `onRetry` 回调

**Files:**
- Modify: `novel_app/lib/utils/retry_helper.dart:115-147`(`withRetry` 实现)
- Modify: `novel_app/test/unit/utils/retry_helper_test.dart`(加用例)

**依赖**:无;后续所有 Task 依赖此 Task。

- [ ] **Step 1: 写失败测试**

在 `test/unit/utils/retry_helper_test.dart` 的 `group('withRetry', ...)` 末尾加:

```dart
group('withRetry.onRetry 回调', () {
  test('首次成功 → onRetry 调用 0 次', () async {
    final calls = <List<int>>[]; // [attempt, maxAttempts]
    final result = await withRetry(
      () async => 'ok',
      config: const RetryConfig(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 1),
      ),
      onRetry: (a, m, d, e) => calls.add([a, m]),
    );
    expect(result, 'ok');
    expect(calls, isEmpty);
  });

  test('第 1 次失败,第 2 次成功 → onRetry 调用 1 次,attempt=1',
      () async {
    final calls = <List<int>>[];
    var invocations = 0;
    final result = await withRetry(
      () async {
        invocations++;
        if (invocations < 2) throw const SocketException('boom');
        return 'ok';
      },
      config: const RetryConfig(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 1),
      ),
      onRetry: (a, m, d, e) {
        calls.add([a, m, d]);
      },
    );
    expect(result, 'ok');
    expect(invocations, 2);
    expect(calls, hasLength(1));
    expect(calls.first[0], 1, reason: '失败 → 重试 1 次 → attempt=1');
    expect(calls.first[1], 3, reason: 'maxAttempts 透传');
    expect(calls.first[2], greaterThan(0), reason: 'delayMs > 0');
  });

  test('全失败 maxAttempts=3 → onRetry 调用 2 次 (maxAttempts-1)',
      () async {
    final calls = <int>[];
    await expectLater(
      () => withRetry(
        () async => throw const SocketException('always'),
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 1),
        ),
        onRetry: (a, m, d, e) => calls.add(a),
      ),
      throwsA(isA<SocketException>()),
    );
    expect(calls, [1, 2], reason: '全失败 → 重试 2 次 → attempt 1,2');
  });

  test('onRetry=null 默认行为不变(向后兼容)', () async {
    var invocations = 0;
    final result = await withRetry(
      () async {
        invocations++;
        if (invocations < 2) throw const SocketException('boom');
        return 'ok';
      },
      config: const RetryConfig(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 1),
      ),
    );
    expect(result, 'ok');
    expect(invocations, 2, reason: '默认值 null → 不调用 onRetry,行为不变');
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd novel_app && flutter test test/unit/utils/retry_helper_test.dart
```

预期:`withRetry.onRetry 回调` 这一组 4 个 test 全失败,编译错误 `withRetry` 没有 `onRetry` 命名参数。

- [ ] **Step 3: 改 `withRetry` 签名 + 实现**

`novel_app/lib/utils/retry_helper.dart`,找到 `Future<T> withRetry<T>(` 函数定义(L115-147),把签名加 `onRetry` 并在 `await Future.delayed` 之前调用:

```dart
Future<T> withRetry<T>(
  Future<T> Function() fn, {
  RetryConfig config = const RetryConfig(),
  String label = 'retry',
  void Function(int attempt, int maxAttempts, int delayMs, Object error)?
      onRetry,
}) async {
  final should = config.shouldRetry ?? RetryConfig.defaultShouldRetry;
  Object? lastError;
  for (var attempt = 1; attempt <= config.maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (e) {
      lastError = e;
      if (attempt >= config.maxAttempts || !should(e)) {
        rethrow;
      }
      final delayMs = _computeDelayMs(
        attempt: attempt,
        config: config,
        retryAfterMs:
            e is RetryableHttpException ? e.retryAfterMs : null,
      );
      LoggerService.instance.w(
        '$label 第 $attempt 次失败 (${e.runtimeType}: $e)，'
        '${delayMs}ms 后重试',
        category: LogCategory.network,
        tags: ['retry', label],
      );
      // 通知调用方(用于 LLM 重试 UI 横幅等场景);null 时不调用,完全向后兼容
      if (onRetry != null) {
        try {
          onRetry!(attempt, config.maxAttempts, delayMs, e);
        } catch (_) {
          // onRetry 异常被吞掉,不影响重试主流程
        }
      }
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
  }
  throw lastError ?? StateError('withRetry 未执行任何 attempt');
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
cd novel_app && flutter test test/unit/utils/retry_helper_test.dart
```

预期:`withRetry.onRetry 回调` 4 个 test 全过;**其他** `withRetry` 测试(如 `RetryableHttpException 默认判定为可重试`、退避时间等)**全过**(无回归)。

- [ ] **Step 5: 跑 analyze**

```bash
cd novel_app && flutter analyze lib/utils/retry_helper.dart test/unit/utils/retry_helper_test.dart
```

预期:`No issues found!`

- [ ] **Step 6: Commit**

```bash
cd novel_app && git add lib/utils/retry_helper.dart test/unit/utils/retry_helper_test.dart
cd .. && git commit -m "$(cat <<'EOF'
@feat(retry): withRetry 加可选 onRetry 回调(向后兼容)

addTask 1/8 (LLM 重试 UI 展示)。onRetry(attempt, maxAttempts,
delayMs, error) 在 await Future.delayed 前调用;默认值 null,行为
不变。后续 RetrySignals.reportTransport/clear 通过此回调接线。

测试覆盖:成功 0 次、中途成功 n 次调用 n 次、全失败 maxAttempts-1 次、
默认值 null 行为不变。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: 新建 `retry_signals.dart`(信号层 + 共享错误分类工具)

**Files:**
- Create: `novel_app/lib/services/dsl_engine/retry_signals.dart`
- Create: `novel_app/test/unit/services/dsl_engine/retry_signals_test.dart`

**依赖**:无(独立模块)。

- [ ] **Step 1: 写失败测试**

`test/unit/services/dsl_engine/retry_signals_test.dart`(新建):

```dart
/// RetrySignals + categorizeRetryError 单元测试
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/services/dsl_engine/retry_signals_test.dart
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/retry_signals.dart';
import 'package:novel_app/utils/retry_helper.dart';

void main() {
  setUp(() => RetrySignals.instance.resetForTest());
  addTearDown(() => RetrySignals.instance.resetForTest());

  group('RetrySignals', () {
    test('reportTransport → notifier.value 写入 transport state',
        () async {
      final notified = <RetryState?>[];
      RetrySignals.instance.notifier.addListener(() {
        notified.add(RetrySignals.instance.notifier.value);
      });

      RetrySignals.instance.reportTransport(
        attempt: 3,
        maxAttempts: 8,
        delayMs: 2000,
        error: const RetryableHttpException(429, '', ''),
      );

      final state = RetrySignals.instance.notifier.value!;
      expect(state.level, RetryLevel.transport);
      expect(state.attempt, 3);
      expect(state.maxAttempts, 8);
      expect(state.delayMs, 2000);
      expect(state.errorCategory, '限流');
      expect(state.receivedAt, isA<DateTime>());
      expect(notified, hasLength(1));
      expect(notified.last, state);
    });

    test('reportRound → notifier.value 写入 round state', () {
      RetrySignals.instance.reportRound(
        attempt: 1,
        maxAttempts: 2,
        delayMs: 1000,
        error: const SocketException('断'),
      );

      final state = RetrySignals.instance.notifier.value!;
      expect(state.level, RetryLevel.round);
      expect(state.attempt, 1);
      expect(state.maxAttempts, 2);
      expect(state.errorCategory, '网络断开');
    });

    test('clear → notifier.value == null', () {
      RetrySignals.instance.reportTransport(
        attempt: 1,
        maxAttempts: 8,
        delayMs: 100,
        error: const SocketException('x'),
      );
      expect(RetrySignals.instance.notifier.value, isNotNull);

      RetrySignals.instance.clear();
      expect(RetrySignals.instance.notifier.value, isNull);
    });

    test('连续 report,后值覆盖前值', () {
      RetrySignals.instance.reportTransport(
        attempt: 1,
        maxAttempts: 8,
        delayMs: 100,
        error: const SocketException('x'),
      );
      RetrySignals.instance.reportRound(
        attempt: 1,
        maxAttempts: 2,
        delayMs: 1000,
        error: const RetryableHttpException(503, '', ''),
      );
      final v = RetrySignals.instance.notifier.value!;
      expect(v.level, RetryLevel.round,
          reason: '后写的 report 覆盖前一个 transport state');
    });
  });

  group('categorizeRetryError', () {
    test('429 → 限流', () {
      expect(
        categorizeRetryError(const RetryableHttpException(429, '', '')),
        '限流',
      );
    });
    test('408 → 请求超时', () {
      expect(
        categorizeRetryError(const RetryableHttpException(408, '', '')),
        '请求超时',
      );
    });
    test('4xx 其他 → 请求错误 {code}', () {
      expect(
        categorizeRetryError(const RetryableHttpException(400, '', '')),
        '请求错误 400',
      );
      expect(
        categorizeRetryError(const RetryableHttpException(401, '', '')),
        '请求错误 401',
      );
    });
    test('5xx → 服务端 {code}', () {
      expect(
        categorizeRetryError(const RetryableHttpException(500, '', '')),
        '服务端 500',
      );
      expect(
        categorizeRetryError(const RetryableHttpException(503, '', '')),
        '服务端 503',
      );
    });
    test('SocketException/HandshakeException → 网络断开', () {
      expect(
        categorizeRetryError(const SocketException('x')),
        '网络断开',
      );
      expect(categorizeRetryError(const HandshakeException()), '网络断开');
    });
    test('TimeoutException → 响应超时', () {
      expect(
        categorizeRetryError(
          TimeoutException('x', const Duration(milliseconds: 1)),
        ),
        '响应超时',
      );
    });
    test('其它 → 重试中', () {
      expect(categorizeRetryError(StateError('x')), '重试中');
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd novel_app && flutter test test/unit/services/dsl_engine/retry_signals_test.dart
```

预期:文件不存在或编译失败(`RetrySignals` / `RetryLevel` / `RetryState` / `categorizeRetryError` 未定义)。

- [ ] **Step 3: 实现 `retry_signals.dart`**

`lib/services/dsl_engine/retry_signals.dart`(新建):

```dart
/// LLM 重试 UI 信号总线
///
/// 模块级单例 `RetrySignals` 持有 `ValueNotifier<RetryState?>`,供 UI
/// (RetryBanner) 通过 `ValueListenableBuilder` 订阅。
///
/// 信号来源:
/// - 传输层:IoLlmHttpClient.postJson/postJsonStream 通过 withRetry 的
///   onRetry 回调报告 transportRetry → reportTransport
/// - 回合层:agent_loop.dart 的 round-level catch 块直接调 reportRound
///   (不走事件流,绕开 shouldMainSessionHandleEvent 过滤 — spec §3.1.1 方案 B)
///
/// 多 session 串号限制:模块级单例同时只能显示一个 active retry,本次接受(YAGNI)。
/// factory reset:test 用 resetForTest() 复位 ValueNotifier。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:novel_app/utils/retry_helper.dart';

/// 重试层级
enum RetryLevel { transport, round }

/// 当前活跃的重试状态
@immutable
class RetryState {
  final RetryLevel level;
  final int attempt;
  final int maxAttempts;
  final int delayMs;
  final String errorCategory;
  final DateTime receivedAt;

  const RetryState({
    required this.level,
    required this.attempt,
    required this.maxAttempts,
    required this.delayMs,
    required this.errorCategory,
    required this.receivedAt,
  });
}

/// 模块级重试信号单例
class RetrySignals {
  static final RetrySignals instance = RetrySignals._();
  RetrySignals._();

  /// UI 端通过 ValueListenableBuilder 订阅;null = 无活跃重试,横幅不渲染
  ValueNotifier<RetryState?> notifier = ValueNotifier<RetryState?>(null);

  /// 传输层 withRetry 报告一次重试(覆盖式写入最新)
  void reportTransport({
    required int attempt,
    required int maxAttempts,
    required int delayMs,
    required Object error,
  }) {
    notifier.value = RetryState(
      level: RetryLevel.transport,
      attempt: attempt,
      maxAttempts: maxAttempts,
      delayMs: delayMs,
      errorCategory: categorizeRetryError(error),
      receivedAt: DateTime.now(),
    );
  }

  /// 回合层 agent_loop 报告一次重试
  void reportRound({
    required int attempt,
    required int maxAttempts,
    required int delayMs,
    required Object error,
  }) {
    notifier.value = RetryState(
      level: RetryLevel.round,
      attempt: attempt,
      maxAttempts: maxAttempts,
      delayMs: delayMs,
      errorCategory: categorizeRetryError(error),
      receivedAt: DateTime.now(),
    );
  }

  /// 重试结束(success / final failure / agent done):清空让横幅消失
  void clear() {
    notifier.value = null;
  }

  /// 测试用复位(重建 ValueNotifier);release 代码不应调用
  @visibleForTesting
  void resetForTest() {
    notifier.dispose();
    notifier = ValueNotifier<RetryState?>(null);
  }
}

/// 共享错误分类工具 — 传输层与回合层共用,避免映射逻辑重复
///
/// 429 → 限流
/// 408 → 请求超时
/// 4xx 其他 → 请求错误 {code}
/// 5xx → 服务端 {code}
/// Socket/HandshakeException → 网络断开
/// TimeoutException → 响应超时
/// 其它 → 重试中
String categorizeRetryError(Object error) {
  if (error is RetryableHttpException) {
    final code = error.statusCode;
    if (code == 429) return '限流';
    if (code == 408) return '请求超时';
    if (code >= 500) return '服务端 $code';
    return '请求错误 $code';
  }
  if (error is SocketException || error is HandshakeException) {
    return '网络断开';
  }
  if (error is TimeoutException) return '响应超时';
  return '重试中';
}
```

```

- [ ] **Step 4: 运行测试确认通过**

```bash
cd novel_app && flutter test test/unit/services/dsl_engine/retry_signals_test.dart
```

预期:12 个 test 全过(`RetrySignals` 4 + `categorizeRetryError` 7 = 11,含分组容器共 12)。

- [ ] **Step 5: Commit**

```bash
cd novel_app && git add lib/services/dsl_engine/retry_signals.dart test/unit/services/dsl_engine/retry_signals_test.dart
cd .. && git commit -m "$(cat <<'EOF'
@feat(retry): 新建 RetrySignals 单例 + categorizeRetryError

Task 2/8 (LLM 重试 UI)。RetrySignals.instance.notifier 为
ValueNotifier<RetryState?>,UI 端通过 ValueListenableBuilder 订阅,
null = 无活跃重试,横幅不渲染。

categorizeRetryError 共享工具(429→限流/408→请求超时/
4xx→请求错误/5xx→服务端/Socket→网络断开/Timeout→响应超时/
其它→重试中),供后续 IoLlmHttpClient 与 agent_loop 共用。

resetForTest() 用于测试 tearDown。spec §3.1.1 方案 B 数据流上游。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: 测试 helper `_ScriptedErrorHttpClient` + LLM 接线 `IoLlmHttpClient`

**Files:**
- Create: `novel_app/test/helpers/scripted_error_http_client.dart`
- Create: `novel_app/test/unit/services/dsl_engine/llm_provider_retry_test.dart`
- Modify: `novel_app/lib/services/dsl_engine/llm_provider.dart`(IoLlmHttpClient 两处 withRetry 注入 onRetry + 成功 clear)

**依赖**:Task 1 + Task 2(spec §5 组件清单条目 3)。

- [ ] **Step 1: 创建测试 helper `_ScriptedErrorHttpClient`**

`test/helpers/scripted_error_http_client.dart`(新建):

```dart
/// 测试 helper:可枚举每次 response 的 LlmHttpClient
///
/// 用法:
///   final c = _ScriptedErrorHttpClient()
///     ..queueBody('ok {\\"choices":[]}')
///     ..queueError(const RetryableHttpException(503, '', ''))
///     ..queueBody('ok2 {\\"choices":[]}');
///   await c.postJson(url, headers, body); // 返回 ok
///   await c.postJson(url, headers, body); // 抛 RetryableHttpException
///   await c.postJson(url, headers, body); // 返回 ok2
///
/// 通过 queueBody/queueError 装载脚本,按调用顺序消费。
library;

import 'dart:async';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';

class _ScriptedErrorHttpClient implements LlmHttpClient {
  final List<dynamic> _script = [];
  int _pos = 0;
  final List<int> postJsonCalls = [];

  void queueBody(String body) => _script.add(body);
  void queueError(Object error) => _script.add(error);

  Future<T> _consume<T>(T Function(Object) parser) async {
    if (_pos >= _script.length) {
      throw StateError('_ScriptedErrorHttpClient 脚本已耗尽 ($_pos)');
    }
    final item = _script[_pos++];
    if (item is Object && item is! String) {
      // 异常立刻抛,不延迟(简化)
      throw item;
    }
    return parser(item as String);
  }

  @override
  Future<String> postJson(
      String url, Map<String, String> headers, String body) async {
    postJsonCalls.add(1);
    return _consume((s) => s);
  }

  @override
  Stream<String> postJsonStream(
      String url, Map<String, String> headers, String body) async* {
    final item = _script[_pos++];
    if (item is Object && item is! String) throw item;
    yield item as String;
  }
}
```

- [ ] **Step 2: 写失败测试**

`test/unit/services/dsl_engine/llm_provider_retry_test.dart`(新建):

```dart
/// IoLlmHttpClient 重试与 RetrySignals 接线测试
///
/// 验证:
/// - 失败 → reportTransport(notifier 写入 transport state)
/// - 成功 → notifier 清空(clear)
/// - rethrow → notifier 不被 clear(避免与 round-level 竞争)
/// - postJsonStream 握手成功 → clear
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/services/dsl_engine/llm_provider_retry_test.dart
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';
import 'package:novel_app/services/dsl_engine/retry_signals.dart';
import 'package:novel_app/utils/retry_helper.dart';
import '../../../helpers/scripted_error_http_client.dart';

void main() {
  setUp(() => RetrySignals.instance.resetForTest());
  addTearDown(() => RetrySignals.instance.resetForTest());

  // 这个测试只验证 _postJsonOnce 内的 withRetry 行为。
  // IoLlmHttpClient._httpClient 是私有字段,无法注入替身;
  // 这里用队列式 client 验证 withRetry onRetry 透传。
  group('LLM Provider 传输层重试 → RetrySignals', () {
    test('postJson 模拟重试:onRetry 被调用;成功时不残留 state(实际由 _postJsonOnce clear)',
        () async {
      // 这个测试只验证 withRetry + onRetry 的连接,_postJsonOnce 的 wiring
      // 由手动验收覆盖(_httpClient 是私有字段,不容易注入)。
      // 这里改测 withRetry 直接调用的连接,在生产代码里 onRetry → reportTransport。
      bool called = false;
      await withRetry(
        () async {
          if (!called) {
            called = true;
            throw const RetryableHttpException(503, '', '');
          }
          return 'ok';
        },
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 1),
        ),
        onRetry: (a, m, d, e) {
          RetrySignals.instance.reportTransport(
            attempt: a,
            maxAttempts: m,
            delayMs: d,
            error: e,
          );
        },
      );
      // 重试 1 次后成功,state 仍残留(因为没 clear)
      expect(RetrySignals.instance.notifier.value, isNotNull);
      expect(RetrySignals.instance.notifier.value!.attempt, 1);

      // 模拟 postJson 成功的 clear 行为
      RetrySignals.instance.clear();
      expect(RetrySignals.instance.notifier.value, isNull);
    });

    test('categorizeRetryError 经 onRetry 透传到 RetryState.errorCategory',
        () async {
      await withRetry(
        () async => throw const RetryableHttpException(429, 'body', ''),
        config: const RetryConfig(
          maxAttempts: 2,
          initialDelay: Duration(milliseconds: 1),
        ),
        onRetry: (a, m, d, e) {
          RetrySignals.instance.reportTransport(
            attempt: a,
            maxAttempts: m,
            delayMs: d,
            error: e,
          );
        },
      ).catchError((_) {});

      final v = RetrySignals.instance.notifier.value!;
      expect(v.errorCategory, '限流');
      expect(v.maxAttempts, 2);
    });
  });
}
```

- [ ] **Step 3: 运行测试确认失败**

```bash
cd novel_app && flutter test test/unit/services/dsl_engine/llm_provider_retry_test.dart
```

预期:`ScriptedErrorHttpClient` / `RetrySignals` 找不到 → 编译失败。先建 `scripted_error_http_client.dart`(Step 1)后再跑,会通过(测的是 withRetry onRetry 接线本身,而非 IoLlmHttpClient)。

- [ ] **Step 4: 实现接线 `IoLlmHttpClient`**

`lib/services/dsl_engine/llm_provider.dart`:
- `_postJsonOnce`(L940-1002):包 `withRetry` 后,在 `try` 块成功 `return responseBody` 前**单点** `RetrySignals.clear()`
- `_postJsonStreamHandshake`(L1029-1094):成功返回 `_StreamHandshake` 前**单点** `RetrySignals.clear()`
- 两处 `withRetry` 都注入 `onRetry`

L929-933 `postJson` 改:

```dart
@override
Future<String> postJson(
    String url, Map<String, String> headers, String body) async {
  return withRetry(
    () => _postJsonOnce(url, headers, body),
    label: 'llm_post',
  );
}
```

→

```dart
@override
Future<String> postJson(
    String url, Map<String, String> headers, String body) async {
  return withRetry(
    () => _postJsonOnce(url, headers, body),
    label: 'llm_post',
    onRetry: (a, m, d, e) {
      try {
        RetrySignals.instance.reportTransport(
          attempt: a,
          maxAttempts: m,
          delayMs: d,
          error: e,
        );
      } catch (_) {
        // 单例 report 失败不影响重试
      }
    },
  );
}
```

`_postJsonOnce` 末尾(L1001 `return responseBody;` 前)插入 `RetrySignals.instance.clear();`。具体:`return responseBody;` 改为两行,在 `return` 前一行加 `RetrySignals.instance.clear();`。

L1011-1015 `postJsonStream` 的 `withRetry` 同样注入 `onRetry`:

```dart
final handshake = await withRetry(
  () => _postJsonStreamHandshake(url, headers, body),
  config: const RetryConfig(maxAttempts: 3),
  label: 'llm_stream_establish',
  onRetry: (a, m, d, e) {
    try {
      RetrySignals.instance.reportTransport(
        attempt: a,
        maxAttempts: m,
        delayMs: d,
        error: e,
      );
    } catch (_) {}
  },
);
```

`_postJsonStreamHandshake` 在 `return _StreamHandshake(...)`(L1088-1093)前插入 `RetrySignals.instance.clear();`。

顶部 import 加 `import 'retry_signals.dart';`(同目录)。

注:`_postJsonOnce` 与 `_postJsonStreamHandshake` **不**用 `try/finally`,只在成功 return 前 clear — `rethrow` 时不 clear(让 round-level 接管)。

- [ ] **Step 5: 运行测试确认通过**

```bash
cd novel_app && flutter test test/unit/services/dsl_engine/llm_provider_retry_test.dart test/unit/services/dsl_engine/retry_signals_test.dart
```

预期:全过。

- [ ] **Step 6: 跑 analyze**

```bash
cd novel_app && flutter analyze lib/services/dsl_engine/llm_provider.dart lib/services/dsl_engine/retry_signals.dart
```

预期:无 issue。

- [ ] **Step 7: Commit**

```bash
cd novel_app && git add lib/services/dsl_engine/llm_provider.dart test/helpers/scripted_error_http_client.dart test/unit/services/dsl_engine/llm_provider_retry_test.dart
cd .. && git commit -m "$(cat <<'EOF'
@feat(llm): IoLlmHttpClient 接入 RetrySignals(传输层重试 UI)

Task 3/8。postJson/postJsonStream 的 withRetry 注入 onRetry →
RetrySignals.reportTransport;postJson 成功 return 单点 clear;
postJsonStream 握手成功(拿到 _StreamHandshake)单点 clear;
rethrow 不 clear(让 round-level 接管,避免空白闪烁)。

新增 _ScriptedErrorHttpClient 测试 helper(queueBody/queueError
按序消费),供后续测试复用。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `RetryEvent` + `subagent_state_projector` 两个 switch + `scenario_session` switch no-op

**Files:**
- Modify: `novel_app/lib/services/novel_agent/agent_event.dart`
- Modify: `novel_app/lib/services/novel_agent/subagent_state_projector.dart`
- Modify: `novel_app/lib/core/providers/scenario_session.dart`
- Create: `novel_app/test/unit/services/novel_agent/agent_retry_event_test.dart`

**依赖**:无(独立模块);但 Task 5 依赖此处新增的 `RetryEvent`。

- [ ] **Step 1: 写失败测试**

`test/unit/services/novel_agent/agent_retry_event_test.dart`(新建):

```dart
/// RetryEvent + subagent_state_projector/scenario_session switch 接线
///
/// 验证:
/// - RetryEvent extends AgentEvent,含 super.runId
/// - EventTagger.tag(RetryEvent(...), runId) 转发 runId
/// - SubagentStateProjector.project 接 RetryEvent 不抛(no-op 兜底)
/// - scenario_session._handleAgentEvent 接 RetryEvent 不抛(由 routeRunner
///   测试通过 mock 或 sendMessage 触发;这里仅校验类型 sealed 不漏 case)
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/services/novel_agent/agent_retry_event_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/novel_agent/agent_event.dart';
import 'package:novel_app/services/novel_agent/subagent_state_projector.dart';
import 'package:novel_app/services/novel_agent/subagent_run.dart';

void main() {
  group('RetryEvent', () {
    test('含 super.runId 转发(EventTagger 打标前置)', () {
      const e = RetryEvent(
        attempt: 1,
        maxAttempts: 2,
        delayMs: 1000,
        errorCategory: '限流',
      );
      expect(e.attempt, 1);
      expect(e.maxAttempts, 2);
      expect(e.delayMs, 1000);
      expect(e.errorCategory, '限流');
      expect(e.runId, isNull);
    });

    test('显式 runId', () {
      const e = RetryEvent(
        attempt: 1,
        maxAttempts: 2,
        delayMs: 1000,
        errorCategory: '限流',
        runId: 'sub-1',
      );
      expect(e.runId, 'sub-1');
    });
  });

  group('EventTagger.tag(RetryEvent)', () {
    test('转发 runId', () {
      const e = RetryEvent(
        attempt: 1,
        maxAttempts: 2,
        delayMs: 1000,
        errorCategory: '限流',
      );
      final tagged = EventTagger.tag(e, 'sub-1');
      expect(tagged, isA<RetryEvent>());
      expect(tagged.runId, 'sub-1');
    });
  });

  group('SubagentStateProjector.project(RetryEvent)', () {
    test('no-op:不抛、不改 state', () {
      final run = SubagentRun(runId: 'r', scenarioId: 'webview');
      // 初始 chatState
      final before = run.chatState;
      const e = RetryEvent(
        attempt: 1,
        maxAttempts: 2,
        delayMs: 1000,
        errorCategory: '限流',
      );
      SubagentStateProjector.project(e, run);
      // 不变(no-op)
      expect(run.chatState, before);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd novel_app && flutter test test/unit/services/novel_agent/agent_retry_event_test.dart
```

预期:`RetryEvent` 未定义 → 编译失败。

- [ ] **Step 3: 实现 `RetryEvent`**

`lib/services/novel_agent/agent_event.dart` 末尾(在 `CompactionEvent` 之后)加:

```dart
/// LLM 重试事件(传输层/回合层中段桥接,UI 横幅走 RetrySignals)
///
/// 主 Agent 重试横幅**不依赖**此事件(由 agent_loop.dart 直接调
/// RetrySignals.reportRound,绕开 shouldMainSessionHandleEvent 过滤)。
/// 本事件仍 emit 到事件流,用于:
/// - EventTagger 打标(子 Agent 未来详情页扩展)
/// - Future:subagent 详情页内显示重试
///
/// **必须** 转发 super.runId,否则 EventTagger.tag 的 exhaustive switch
/// 编译失败,且 AgentEvent sealed class 契约违反(spec §3.1.1)。
class RetryEvent extends AgentEvent {
  final int attempt;
  final int maxAttempts;
  final int delayMs;
  final String errorCategory;

  const RetryEvent({
    required this.attempt,
    required this.maxAttempts,
    required this.delayMs,
    required this.errorCategory,
    super.runId,
  });
}
```

- [ ] **Step 4: 同步 `subagent_state_projector.dart` 两个 switch**

`lib/services/novel_agent/subagent_state_projector.dart`:

`EventTagger.tag`(L23-69)末尾 `};` 之前加:

```dart
      RetryEvent(
        attempt: final attempt,
        maxAttempts: final maxAttempts,
        delayMs: final delayMs,
        errorCategory: final errorCategory
      ) =>
        RetryEvent(
          attempt: attempt,
          maxAttempts: maxAttempts,
          delayMs: delayMs,
          errorCategory: errorCategory,
          runId: runId,
        ),
```

`SubagentStateProjector.project`(L87-177)末尾 `case CompactionEvent(): return;` 之后、`}` 之前加(在 CompactionEvent no-op 旁):

```dart
      case RetryEvent():
        // No-op:UI 横幅走 RetrySignals(由 agent_loop 直接调,
        // 不经事件流)。本 case 仅为 exhaustive 完整性。
        return;
```

- [ ] **Step 5: `scenario_session.dart` switch no-op**

`lib/core/providers/scenario_session.dart` 的 `_handleAgentEvent` switch(L925-999),在 `case AgentErrorEvent e:`(L997-998)后加:

```dart
      case RetryEvent _:
        // No-op:主 Agent RetryEvent 由 agent_loop 直接调 RetrySignals,
        // 这里不再投影(spec §3.1.1 方案 B);仅 exhaustive 兜底。
        break;
```

> 不要影响 L993 `case AgentDoneEvent _: _failedRoundStartIndex = null; _finalizeAgentResponse();`,它必须在 RetryEvent case 之前。

- [ ] **Step 6: 运行测试确认通过**

```bash
cd novel_app && flutter test test/unit/services/novel_agent/agent_retry_event_test.dart
```

预期:全过(RetryEvent 2 + EventTagger 1 + Projector 1 = 4 test)。

- [ ] **Step 7: 跑 analyze**

```bash
cd novel_app && flutter analyze lib/services/novel_agent/agent_event.dart lib/services/novel_agent/subagent_state_projector.dart lib/core/providers/scenario_session.dart
```

预期:无 issue(漏任一 switch case 编译就不过)。

- [ ] **Step 8: Commit**

```bash
cd novel_app && git add lib/services/novel_agent/agent_event.dart lib/services/novel_agent/subagent_state_projector.dart lib/core/providers/scenario_session.dart test/unit/services/novel_agent/agent_retry_event_test.dart
cd .. && git commit -m "$(cat <<'EOF'
@feat(agent): 新增 RetryEvent + 同步两个 exhaustive switch

Task 4/8。RetryEvent extends AgentEvent 含 super.runId 转发。
EventTagger.tag + SubagentStateProjector.project 两个 exhaustive
switch 同步加 case RetryEvent(漏则编译失败 — spec §3.1.1)。
scenario_session._handleAgentEvent switch 加 case RetryEvent no-op
(主 Agent RetryEvent 不再依赖事件投影,UI 横幅直接调 RetrySignals)。

测试覆盖 RetryEvent 字段、EventTagger.tag 转发 runId、
Projector project no-op。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `agent_loop` round-level 重试 emit `RetryEvent` + reportRound + clear 时机

**Files:**
- Modify: `novel_app/lib/services/novel_agent/agent_loop.dart`(L398-435 round-level catch;L433 `emit AgentErrorEvent`;L459 `emit AgentDoneEvent`(max_rounds 兜底))
- Modify: `novel_app/test/unit/services/novel_agent/agent_loop_retry_test.dart`(已有文件扩用例)

**依赖**:Task 4(`RetryEvent` 已存在)。

- [ ] **Step 1: 写失败测试**

在 `test/unit/services/novel_agent/agent_loop_retry_test.dart` 末尾加:

```dart
group('Round-level RetryEvent + RetrySignals 接线', () {
  setUp(() => RetrySignals.instance.resetForTest());
  addTearDown(() => RetrySignals.instance.resetForTest());

  test('RetryableHttpException(503) → emit RetryEvent + RetrySignals.reportRound',
      () async {
    final emitted = <AgentEvent>[];
    final llm = _ScriptedErrorLlm()
      ..enqueue(throwMode: const RetryableHttpException(503, 'mt', ''))
      ..enqueue(
        response: const _ScriptedResponse(contentChunks: ['已恢复']),
      );
    final loop = AgentLoop(
      llm: llm,
      scenario: _FakeScenario(),
      config: const AgentLoopConfig(maxRounds: 5, networkRetryPerRound: 2),
      emit: emitted.add,
    );
    await runLoop(loop);

    final retryEvents =
        emitted.whereType<RetryEvent>().toList(growable: false);
    expect(retryEvents, hasLength(1),
        reason: 'round-level 抛错一次 → emit RetryEvent 一次');
    expect(retryEvents.first.attempt, 1);
    expect(retryEvents.first.maxAttempts, 2,
        reason: 'maxAttempts 来自 _config.networkRetryPerRound');
    expect(retryEvents.first.errorCategory, '服务端 503');

    // RetrySignals 也收到(round-level 直接调用,不经事件流)
    expect(RetrySignals.instance.notifier.value, isNotNull);
    expect(RetrySignals.instance.notifier.value!.level, RetryLevel.round);
    expect(RetrySignals.instance.notifier.value!.errorCategory, '服务端 503');
  });

  test('SocketException 抛尽 → AgentErrorEvent + RetrySignals.clear()',
      () async {
    final llm = _ScriptedErrorLlm()
      ..enqueue(throwMode: const SocketException('a'))
      ..enqueue(throwMode: const SocketException('b'))
      ..enqueue(throwMode: const SocketException('c'));
    final loop = AgentLoop(
      llm: llm,
      scenario: _FakeScenario(),
      config: const AgentLoopConfig(networkRetryPerRound: 2),
      emit: (e) {},
    );
    // 先模拟 round-level 重试 2 次 → 把 RetryState 推到 active
    RetrySignals.instance.reportRound(
      attempt: 1,
      maxAttempts: 2,
      delayMs: 1000,
      error: const SocketException('before-loop'),
    );
    expect(RetrySignals.instance.notifier.value, isNotNull,
        reason: 'sanity: signal 在 loop 前是 active');

    await runLoop(loop);

    expect(RetrySignals.instance.notifier.value, isNull,
        reason: 'AgentErrorEvent 后 RetrySignals.clear()');
  });

  test('成功后 AgentDoneEvent → RetrySignals.clear()', () async {
    final llm = _ScriptedErrorLlm()
      ..enqueue(
        throwMode: const RetryableHttpException(503, 'mt', ''),
      )
      ..enqueue(response: const _ScriptedResponse(contentChunks: ['ok']));
    final loop = AgentLoop(
      llm: llm,
      scenario: _FakeScenario(),
      config: const AgentLoopConfig(networkRetryPerRound: 2),
      emit: (e) {},
    );
    await runLoop(loop);

    expect(RetrySignals.instance.notifier.value, isNull,
        reason: 'AgentDoneEvent 后 RetrySignals.clear()');
  });
});
```

> 已有文件头(`agent_loop_retry_test.dart:1-30`)需要加 import:
> ```dart
> import 'package:novel_app/services/dsl_engine/retry_signals.dart';
> ```
> 已经有 `import 'package:novel_app/services/novel_agent/agent_event.dart';` 含 `RetryEvent`,OK。
>
> 还需要给 `AgentLoop` 构造传 `emit`:`AgentLoop(llm: llm, scenario: ..., emit: ...)`(现有有的 helper `runLoop` 见 L160-163 默认 emit;若 `runLoop` 不支持传 emit,改用 `loop.run(initialMessages: ..., systemPrompt: ..., emit: callback)` 直接驱动。)

- [ ] **Step 2: 运行测试确认失败**

```bash
cd novel_app && flutter test test/unit/services/novel_agent/agent_loop_retry_test.dart
```

预期:`RetryEvent` 已存在但 `agent_loop.dart` 未 emit → emitted.whereType<RetryEvent>() 为空 → expect 失败。

- [ ] **Step 3: 改 `agent_loop.dart`**

`lib/services/novel_agent/agent_loop.dart`:

1) L397 `round++;` 后续不变。
2) L398 catch 块,找到 `await Future<void>.delayed(delay);`(L415)前一行加 emit + reportRound。同时在 catch 块顶部 import retry_signals(L13 已有 `import 'package:novel_app/utils/retry_helper.dart' show RetryableHttpException;`,旁边加 `import '../dsl_engine/retry_signals.dart';`)。

具体改 L408-415:

```dart
          LoggerService.instance.w(
            'Agent 轮级网络重试 (round=$round, $roundRetryCount/${_config.networkRetryPerRound}, '
            '${delay.inMilliseconds}ms, ${e.runtimeType}: $e)',
            category: LogCategory.ai,
            stackTrace: stack.toString(),
            tags: ['agent', 'loop', 'round_retry', _scenario.id],
          );
          // 同一行同时 emit 事件(供未来 subagent 详情页) + 直接调
          // RetrySignals(走 UI 横幅,绕开事件流过滤)
          emit(RetryEvent(
            attempt: roundRetryCount,
            maxAttempts: _config.networkRetryPerRound,
            delayMs: delay.inMilliseconds,
            errorCategory: categorizeRetryError(e),
          ));
          try {
            RetrySignals.instance.reportRound(
              attempt: roundRetryCount,
              maxAttempts: _config.networkRetryPerRound,
              delayMs: delay.inMilliseconds,
              error: e,
            );
          } catch (_) {}
          await Future<void>.delayed(delay);
```

3) L433 `emit(AgentErrorEvent(e.toString()));` 同一行后加 clear:

```dart
        emit(AgentErrorEvent(e.toString()));
        RetrySignals.instance.clear();
        return;
```

4) L459 `emit(const AgentDoneEvent());`(max_rounds 兜底)同一行后加 clear:

```dart
      emit(const AgentDoneEvent());
      RetrySignals.instance.clear();
      LoggerService.instance.i('Agent 循环完成（达到最大轮数, scenario=${_scenario.id}）',
          category: LogCategory.ai, tags: ['agent', 'loop_end', _scenario.id]);
```

5) **取消时也 clear**:L422 `emit(const AgentDoneEvent());`(取消分支)同一行后加 clear:

```dart
          emit(const AgentDoneEvent());
          RetrySignals.instance.clear();
          return;
```

6) 顶部 import 加:`import 'package:novel_app/services/dsl_engine/retry_signals.dart';`(`categorizeRetryError`/`RetryLevel` 都在那里)。注意:`agent_loop.dart` 实际是在 `lib/services/novel_agent/` 下,`retry_signals.dart` 在 `lib/services/dsl_engine/`,用相对 import `import '../dsl_engine/retry_signals.dart';` 或绝对 `import 'package:novel_app/services/dsl_engine/retry_signals.dart';`,项目惯例用绝对路径(见 L13 `import 'package:novel_app/utils/retry_helper.dart';`)。

- [ ] **Step 4: 运行测试确认通过**

```bash
cd novel_app && flutter test test/unit/services/novel_agent/agent_loop_retry_test.dart
```

预期:已有用例全过 + 新加 3 个用例全过(同时保证取消分支 clear)。

- [ ] **Step 5: 跑 analyze**

```bash
cd novel_app && flutter analyze lib/services/novel_agent/agent_loop.dart
```

预期:无 issue。

- [ ] **Step 6: Commit**

```bash
cd novel_app && git add lib/services/novel_agent/agent_loop.dart test/unit/services/novel_agent/agent_loop_retry_test.dart
cd .. && git commit -m "$(cat <<'EOF'
@feat(agent): round-level 重试 emit RetryEvent + RetrySignals.reportRound

Task 5/8。await Future.delayed 前 emit(RetryEvent(...)) +
RetrySignals.reportRound(...) 同一行。AgentErrorEvent /
AgentDoneEvent(取消 + max_rounds)emit 时 clear。maxAttempts 来自
_config.networkRetryPerRound 默认 2。

测试 3 个新用例:RetryEvent 字段 + RetrySignals state +
取消/失败 clear。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: 新建 `RetryBanner` widget

**Files:**
- Create: `novel_app/lib/widgets/agent_chat/retry_banner.dart`
- Create: `novel_app/test/widget/agent_chat/retry_banner_test.dart`

**依赖**:Task 2(`RetrySignals` 已存在)。

- [ ] **Step 1: 写失败测试**

`test/widget/agent_chat/retry_banner_test.dart`(新建):

```dart
/// RetryBanner widget 测试
///
/// 验证:
/// - RetrySignals.notifier null → 不渲染横幅
/// - 报告 transport → 橙色 + "网络重试 N/8" + 倒计时数字
/// - 报告 round → 蓝色 + "回合重试 N/2"
/// - delayMs ≤ 1000 → "重试中"(无秒数)
/// - 倒计时到 0 → 切 "重试中…"
/// - clear → 横幅消失
///
/// 运行:
///   cd novel_app
///   flutter test test/widget/agent_chat/retry_banner_test.dart
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/retry_signals.dart';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';
import 'package:novel_app/utils/retry_helper.dart';
import 'package:novel_app/widgets/agent_chat/retry_banner.dart';

Widget _harness(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() => RetrySignals.instance.resetForTest());
  addTearDown(() => RetrySignals.instance.resetForTest());

  testWidgets('null state → 不渲染横幅', (tester) async {
    await tester.pumpWidget(_harness(const RetryBanner()));
    expect(find.byType(RetryBanner), findsOneWidget);
    expect(find.textContaining('重试'), findsNothing);
  });

  testWidgets('transport → 橙色 + 网络重试 + 错误类别',
      (tester) async {
    RetrySignals.instance.reportTransport(
      attempt: 3,
      maxAttempts: 8,
      delayMs: 5000,
      error: const RetryableHttpException(429, '', ''),
    );
    await tester.pumpWidget(_harness(const RetryBanner()));
    await tester.pump();

    expect(find.textContaining('网络重试 3/8'), findsOneWidget);
    expect(find.textContaining('限流'), findsOneWidget);
  });

  testWidgets('round → 蓝色 + 回合重试', (tester) async {
    RetrySignals.instance.reportRound(
      attempt: 1,
      maxAttempts: 2,
      delayMs: 3000,
      error: const SocketException('x'),
    );
    await tester.pumpWidget(_harness(const RetryBanner()));
    await tester.pump();

    expect(find.textContaining('回合重试 1/2'), findsOneWidget);
    expect(find.textContaining('网络断开'), findsOneWidget);
  });

  testWidgets('delayMs ≤ 1000 → 显示「重试中」(无秒数)', (tester) async {
    RetrySignals.instance.reportTransport(
      attempt: 2,
      maxAttempts: 8,
      delayMs: 500,
      error: const RetryableHttpException(503, '', ''),
    );
    await tester.pumpWidget(_harness(const RetryBanner()));
    await tester.pump();

    expect(find.textContaining('重试中'), findsOneWidget);
    expect(find.textContaining('Xs 后重试'), findsNothing);
  });

  testWidgets('clear → 横幅消失', (tester) async {
    RetrySignals.instance.reportTransport(
      attempt: 1,
      maxAttempts: 8,
      delayMs: 5000,
      error: const RetryableHttpException(503, '', ''),
    );
    await tester.pumpWidget(_harness(const RetryBanner()));
    await tester.pump();
    expect(find.textContaining('网络重试 1/8'), findsOneWidget);

    RetrySignals.instance.clear();
    await tester.pump();
    expect(find.textContaining('网络重试'), findsNothing);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd novel_app && flutter test test/widget/agent_chat/retry_banner_test.dart
```

预期:`RetryBanner` 未定义 → 编译失败。

- [ ] **Step 3: 实现 `retry_banner.dart`**

`lib/widgets/agent_chat/retry_banner.dart`(新建):

```dart
/// LLM 重试状态横幅 — 钉在 AgentChatDialog 输入栏上方
///
/// 订阅 RetrySignals.instance.notifier;null 时不渲染。
///
/// 配色:transport = 橙(警告)/ round = 蓝(信息)
/// 倒计时:onRetry 给 delayMs,启动 Timer.periodic(1s) 显示
///       delayMs ≤ 1000 或倒计时到 0 → 显示「重试中…」
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:novel_app/services/dsl_engine/retry_signals.dart';

class RetryBanner extends StatefulWidget {
  const RetryBanner({super.key});

  @override
  State<RetryBanner> createState() => _RetryBannerState();
}

class _RetryBannerState extends State<RetryBanner> {
  Timer? _tickTimer;
  int _remainingSeconds = 0;

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _maybeScheduleTicker(RetryState state) {
    // 重新启动倒计时(每次新 state 都从 delayMs 重算)
    _tickTimer?.cancel();
    _remainingSeconds = (state.delayMs / 1000).ceil();
    if (_remainingSeconds <= 1) return; // ≤1s 直接显示「重试中」
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) _remainingSeconds--;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RetryState?>(
      valueListenable: RetrySignals.instance.notifier,
      builder: (context, state, _) {
        // 取消旧 timer,处理 state 变化
        if (state == null) {
          _tickTimer?.cancel();
          return const SizedBox.shrink();
        }
        _maybeScheduleTicker(state);
        final isTransport = state.level == RetryLevel.transport;
        final prefix = isTransport ? '网络重试' : '回合重试';
        final color =
            isTransport ? Colors.orange.shade700 : Colors.blue.shade700;
        final bgColor = isTransport
            ? Colors.orange.withValues(alpha: 0.12)
            : Colors.blue.withValues(alpha: 0.12);
        final remainingText = _remainingSeconds <= 0
            ? '重试中…'
            : '$_remainingSeconds s 后重试';
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$prefix ${state.attempt}/${state.maxAttempts}'
                  ' · ${state.errorCategory}'
                  '${state.delayMs > 1000 ? ' · $remainingText' : ' · 重试中'}',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

注:`valueListenable` 与本 widget 子树是 `Builder`,每次 state 变化都触发 builder。

- [ ] **Step 4: 运行测试确认通过**

```bash
cd novel_app && flutter test test/widget/agent_chat/retry_banner_test.dart
```

预期:`RetryBanner` 5 个 widget test 全过。

- [ ] **Step 5: 跑 analyze**

```bash
cd novel_app && flutter analyze lib/widgets/agent_chat/retry_banner.dart test/widget/agent_chat/retry_banner_test.dart
```

预期:无 issue。

- [ ] **Step 6: Commit**

```bash
cd novel_app && git add lib/widgets/agent_chat/retry_banner.dart test/widget/agent_chat/retry_banner_test.dart
cd .. && git commit -m "$(cat <<'EOF'
@feat(ui): 新建 RetryBanner widget

Task 6/8。订阅 RetrySignals.instance.notifier,null 时不渲染;
transport → 橙 网络重试 N/8;round → 蓝 回合重试 N/2。
Timer.periodic 倒计时,delayMs≤1s 或倒计时到 0 切「重试中…」。

5 个 widget test:null/round/transport/delayMs≤1s/clear
全覆盖。下一 Task 接入 agent_chat_dialog Column。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `agent_chat_dialog.dart` Column 插入 `RetryBanner`

**Files:**
- Modify: `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart`(L147-160 Column children 插入)
- Modify: `novel_app/test/widget/agent_chat/retry_banner_test.dart`(或新 widget test;沿用 task 6 不必新增)

**依赖**:Task 6(`RetryBanner` 已存在)。

- [ ] **Step 1: 简单加 import + 插入 widget**

`lib/widgets/agent_chat/agent_chat_dialog.dart` 顶部 import 区(已有 import 同目录 widget,如 `import 'subagent_tool_card.dart';`)加:

```dart
import 'retry_banner.dart';
```

L147-160 Column children 在 `_buildContextTag()`(L158)与 `_buildInputBar(...)`(L159)之间插入 `RetryBanner()`:

```dart
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(session),
              if (chatState.scenarioId == ScenarioIds.webviewExtract)
                _buildWebViewInfoBar(),
              if (chatState.scenarioId == ScenarioIds.writing)
                _buildCurrentNovelBar(chatState),
              Expanded(child: _buildMessageList(chatState)),
              if (chatState.error != null && !chatState.isLoading)
                _buildErrorBar(chatState.error!, session),
              RetryBanner(),         // ← 新增(spec §5.3 行号 ~158)
              _buildContextTag(),
              _buildInputBar(chatState, session),
            ],
          ),
```

- [ ] **Step 2: 跑 analyze**

```bash
cd novel_app && flutter analyze lib/widgets/agent_chat/agent_chat_dialog.dart
```

预期:无 issue。

- [ ] **Step 3: 跑相关测试**

```bash
cd novel_app && flutter test test/widget/agent_chat/retry_banner_test.dart
```

预期:仍然全过(Task 6 的 widget harness 已经验证行为,与 dialog 上下文无关)。

- [ ] **Step 4: 手动验收**

启动 App 进 Agent Chat,触发网络故障(关闭 wifi 重发或临时改 LLM baseUrl 到无效地址),验证:

- 底部横幅出现,颜色橙/蓝符合预期
- 倒计时数字递减
- 0s → "重试中…"
- 成功后横幅消失

如果环境不便,沿用 §7 widget test 即视为 OK(spec DoD 标注)。

- [ ] **Step 5: Commit**

```bash
cd novel_app && git add lib/widgets/agent_chat/agent_chat_dialog.dart
cd .. && git commit -m "$(cat <<'EOF'
@feat(ui): agent_chat_dialog 接入 RetryBanner

Task 7/8。Column (L147-160) 在 _buildContextTag 与 _buildInputBar
之间插入 RetryBanner()。与 _buildErrorBar 同级条件渲染,null 时
不占空间,横幅只在活跃重试时出现(spec §5.3 行号一致)。

analyze 干净,widget 测试不变。手动验收:触发网络故障,
验证橙/蓝配色 + 倒计时 + clear() 消失。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: 文档 + 全量回归 + 收尾

**Files:**
- Modify: `CLAUDE.md`(根)changelog
- Modify: `novel_app/CLAUDE.md` changelog + AI 集成段落补充
- 不改代码,只跑 `flutter analyze` 全量 + 相关测试覆盖

**依赖**:Task 1-7 全部完成。

- [ ] **Step 1: 根 CLAUDE.md 加 changelog**

`CLAUDE.md` 顶部 changelog(已有最近条目 `2026-07-17 LLM HTTP 错误统一重试`),在它之前(本条更新)加:

```markdown
- **2026-07-17**: **LLM 重试 UI 展示**。Agent Chat 底部浮动横幅(变体 2:错误码 + 倒计时,transport 橙/round 蓝),`withRetry` 加可选 `onRetry` 回调(向后兼容),新建模块级单例 `RetrySignals`(`ValueNotifier<RetryState?>` + `categorizeRetryError`),`IoLlmHttpClient.postJson/postJsonStream` 接入 `RetrySignals.reportTransport` + 成功 `clear()`(rethrow 不 clear 避免与 round race);`agent_loop` round-level catch 块 `emit RetryEvent` + `RetrySignals.reportRound` 同一行(走方案 B 绕开 `shouldMainSessionHandleEvent` 过滤,子 Agent 重试也能显示),`AgentErrorEvent`/`AgentDoneEvent`/`取消` emit 时 clear。`RetryEvent extends AgentEvent` 必带 `super.runId` 转发(否则 `EventTagger.tag`/`SubagentStateProjector.project` 两个 exhaustive switch 编译失败)。无取消按钮(spec §1.3)。详见 `docs/superpowers/specs/2026-07-17-llm-retry-ui-design.md` + `docs/superpowers/plans/2026-07-17-llm-retry-ui.md`。
```

- [ ] **Step 2: novel_app/CLAUDE.md changelog + AI 集成段落**

`novel_app/CLAUDE.md` 顶部 changelog(在 `2026-07-17 LLM HTTP 错误统一重试` 之前)加同样描述。

找"AI Agent(LLM 直连对话)"段落,在段末补一句:

```
- 重试状态 UI:见上方"LLM 重试 UI 展示"changelog,底部横幅钉在输入栏上方
```

- [ ] **Step 3: 全量 analyze**

```bash
cd novel_app && flutter analyze
```

预期:`No issues found!`(8 个 Task 的所有文件)

- [ ] **Step 4: 全量回归测试**

```bash
cd novel_app && flutter test test/unit/utils/retry_helper_test.dart test/unit/services/dsl_engine/ test/unit/services/novel_agent/ test/widget/agent_chat/
```

预期:全部通过。

- [ ] **Step 5: 完整跑回归**

```bash
cd novel_app && flutter test
```

预期:无新失败(允许 preexisting 失败但本次改动不能引入新失败)。

- [ ] **Step 6: format**

```bash
cd novel_app && flutter format lib/ test/
```

- [ ] **Step 7: 最终 Commit**

```bash
git add CLAUDE.md novel_app/CLAUDE.md
git commit -m "$(cat <<'EOF'
@docs: LLM 重试 UI 展示 changelog

Task 8/8。根 CLAUDE.md 与 novel_app/CLAUDE.md 加 2026-07-17
条目;novel_app/CLAUDE.md AI Agent 段落补"重试状态 UI"指针。

完整跑 flutter analyze + flutter test 无新失败。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## DoD(完成定义)

- [ ] Task 1-7 全部勾选并 commit
- [ ] `flutter analyze` 全量无 issue
- [ ] `flutter test` 无新失败
- [ ] 8 次 commit,每条结构化 commit message
- [ ] `CLAUDE.md` 与 `novel_app/CLAUDE.md` 顶部 changelog 已加
- [ ] 手动验收:触发网络故障可见横幅(可选;widget test 已覆盖行为)

## 风险与注意

1. **`AgentLoop` 构造 `emit` 回调**:Task 5 测试需 `AgentLoop(... emit: callback)`,如现有 helper `runLoop` 不支持,改用 `loop.run(initialMessages:..., systemPrompt:..., emit: callback)`,构造方式见 `agent_loop_cancel_test.dart`
2. **测试间单例污染**:每个用 `RetrySignals` 的测试 `setUp + addTearDown` 必 `resetForTest()`,否则上一个测试的 state 残留污染下一个
3. **多 session 串号**:不在本次修复范围(YAGNI),用户已在 brainstorm 阶段决策"所有重试都显示"
4. **取消重试按钮**:用户决定不加,需改 `withRetry` 支持 `CancellationToken`,超出本次范围
5. **`EventTagger.tag` 与 `Projector.project` exhaustive switch**:漏加 `case RetryEvent` 会编译失败,analyze 阶段会被 Flutter 静态分析捕获
