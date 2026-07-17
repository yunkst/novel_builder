# LLM 重试 UI 展示设计

- **日期**:2026-07-17
- **作者**:与 Claude Code 协同设计
- **状态**:草案,待用户审阅(第 2 轮,修正第 1 轮审查 12 个问题)
- **范围**:仅 Flutter 端 `novel_app`,后端零改动、AI 工具链零改动
- **依赖**:本日已落地的"LLM HTTP 错误统一重试"(`retry_helper` 删 `NonRetryableHttpException`、`isRetryableStatus` 改为 `>= 400`、所有 4xx/5xx 统一抛 `RetryableHttpException`)。没有那层改动,本设计展示的重试就太稀薄、价值有限。

## 1. 背景与目标

### 1.1 现状

今天刚刚把所有 4xx/5xx 也纳入重试(传输层 8 次 + 回合层 2 次,最坏 ~123s)。但 UI 完全看不到重试发生了什么:

- `withRetry`(`retry_helper.dart:115-147`)的循环只在 `LoggerService.instance.w(...)` 打日志,**无 emit 通道**
- `IoLlmHttpClient.postJson` / `postJsonStream`(`llm_provider.dart:925-1023`)包了 withRetry,内部循环最多 8 次,对外只抛最终异常或返回结果
- `agent_loop.dart:398-422` round-level 重试块只在 `LoggerService.instance.w(...)` 打日志,**无 emit**

后果:用户点完"发送"后,面对一个 401 或者代理网关波动,会看到"思考中..."卡住几十秒甚至 2 分钟,毫无反馈。改善策略(刚改完)已经把错误的暴露面放大,展示机制就更需要跟上。

### 1.2 目标

让 Agent Chat 底部输入栏上方出现一个浮动横幅,在 LLM 重试时显示:

- 当前正在重试哪一层(传输层 8 次 vs 回合层 2 次)
- 当前次数(N/M)
- 错误码类别(429/5xx/网络断开…)
- 下次重试倒计时

### 1.3 非目标(显式排除)

| 项 | 理由 |
|---|---|
| 取消按钮 | 需要给 `withRetry` 注入 CancellationToken,改动 `retry_helper` + `IoLlmHttpClient`。用户决定本轮无取消按钮(改动最小,避免改 withRetry) |
| 重试历史列表/历史详情 | 横幅只反映"当前活跃"重试;YAGNI,需要时再加 |
| 详细错误体展示(后端 message) | 用户决定只显示错误码类别,普通用户用不到详细 body |
| subagent 重试区分(runId 隔离) | 用户决定"所有重试都显示";见 §3.1.1 + §4 数据流——通过让 round-level 重试直接调 `RetrySignals.reportRound`(不走事件流过滤),实现"所有重试都显示" |
| 横幅随 conversation 滚动 / 钉在视口底部 | 钉在底部浮动固定位置即可 |
| 改后端 / 改数据库 | 纯前端新增 |

## 2. 关键设计决策(已与用户确认)

| 维度 | 决策 | 依据 |
|---|---|---|
| 范围 | **传输层(8次) + round-level(2次)都展示** | 用户在头脑风暴阶段确认。前者高频普遍,后者是兜底可见 |
| 位置 | **底部输入栏上方浮动横幅** | 用户在 3 选 1 原型里选 C(另两个候选:气泡内顶部横条、气泡上方独立行) |
| 样式 | **变体 2**:转圈 + 错误码类别 + 倒计时 | 用户在三版内容密度里选"标准";传输层橙/回合层蓝 |
| 取消按钮 | **无** | 用户明确无。理由:加取消需改 withRetry 接 CancellationToken,改动 `retry_helper.dart` + `IoLlmHttpClient`,超出本次 |
| 传输层信号传递 | **`withRetry` 加 `onRetry` 回调 + 模块级单例 `RetrySignals`** | 用户在三方案里选这条;另两个方案(StreamController 注入 IoLlmHttpClient + 包装层在 ScenarioSession 重试)都被否 |
| 错误详情 | **只显示码类别** | 用户确认不展示后端 message |
| subagent 重试 | **所有重试都显示**(不区分 main / sub session runId) | 用户确认;走方案 B(详见 §3.1、§4)——round-level 在 emit RetryEvent 同一行直接调 `RetrySignals.reportRound`,绕过 `shouldMainSessionHandleEvent` 过滤 |

## 3. 方案选择

### 3.1 传输层信号如何传出(`withRetry` → UI)

| 候选 | 优劣 | 结论 |
|---|---|---|
| **A. `withRetry` 加 `onRetry` 回调 + 模块级单例 `RetrySignals`** | 改动小(只动 `retry_helper` 签名 + `IoLlmHttpClient` 两处调用);复用性好(任何传入 onRetry 的调用方都能用);测试独立 | ✅ 采用 |
| B. `IoLlmHttpClient` 构造注入 `StreamController<RetryEvent>? retrySink` | 生命周期清晰,但 sink 链路长(从 LlmProvider 到 ScenarioSession 再到 UI 绕一圈);`RetryEvent` 与 `AgentEvent` 类名语义重叠易混 | 否 |
| C. ScenarioSession 包一层"包装器"在外面重试 | 改动最大,重写现有 `chat`/`chatStream` 的重试语义,不推荐 | 否 |

### 3.1.1 round-level 信号如何传出(为什么**不**走事件流)

调研发现 `SubagentStateProjector` / `EventTagger` / `scenario_session._handleAgentEvent` 都用 `shouldMainSessionHandleEvent` 过滤 `runId != mainSessionId` 的事件。这意味着在 `scenario_session` 桥接 `RetrySignals` 会自动屏蔽子 Agent 的 round-level 重试——和"所有重试都显示"冲突。

| 候选 | 优劣 | 结论 |
|---|---|---|
| **B. 在 `agent_loop.dart` emit RetryEvent 同一行直接调 `RetrySignals.reportRound`** | 绕过事件流过滤;同时顺手解决了 §6.2 的 clear race(双方都在源头调,不依赖事件流时序) | ✅ 采用 |
| 改 `shouldMainSessionHandleEvent` 让 RetryEvent 不过滤 | 需要单独判 type + runId 分支,污染通用过滤函数,语义模糊 | 否 |
| 改 `RetrySignals` 为多 runId 持有 | 大幅复杂化,需订阅/反订阅生命周期管理,用户也未要求 subagent 区分 | 否 |

**两层 emit 路径不同**:传输层重试经 `withRetry` 的 `onRetry` 回调报告;回合层重试**不走 withRetry**(`agent_loop` 的 round-level 是手写 catch + `Future.delayed` + continue,见 `agent_loop.dart:398-422`),在 catch 块 `await Future.delayed` 前直接调 `RetrySignals.reportRound`。下表只列传输层;round-level 见 §3.1.1。

由共享工具 `String categorizeRetryError(Object error)` 统一实现(详见 §5),后续维护只改一处:

```
429                → 限流
408                → 请求超时
4xx(其他)           → 请求错误 {code}
5xx                → 服务端 {code}
Socket/Handshake   → 网络断开
TimeoutException   → 响应超时
其它                → 重试中
```

不在 UI 上显示后端 message(body),按用户决定;诊断细节只在 `LoggerService` 日志 + `LlmLogger` 落盘记录里有。

### 3.3 共存/互斥规则

两层重试**不会真正同时发生**:round-level 触发时,传输层那一轮已经结束(要么成功要么最终 rethrow)。所以横幅单一状态足够:

| 时序 | 横幅 |
|---|---|
| 阻塞 chat 重试中(指数退避等待) | 橙色 "网络重试 N/8 · 错误类别 · Xs 后重试" |
| 流式握手重试中(指数退避等待) | 橙色 "网络重试 N/3 · 错误类别 · Xs 后重试" |
| 传输层全失败 → round-level 接管 | 蓝色 "回合重试 N/2 · 错误类别" |
| round-level 完成新一轮 → 传输层又开始重试 | 回到橙色 |

注:`maxAttempts` 由 `withRetry` 的 `config.maxAttempts` 动态传入(阻塞=8、流式握手=3),不在 `RetryState` 里硬编码。

## 4. 数据流

```
┌─────────────────────────┐         ┌───────────────────────────┐
│ 传输层 withRetry          │         │ round-level agent_loop    │
│ (8 次 阻塞 / 3 次 握手,    │         │ (2 次)                     │
│  IoLlmHttpClient)         │         │                            │
└──────────┬───────────────┘         └─────────────┬─────────────┘
           │ onRetry 回调                            │ 在 emit RetryEvent 的
           │ (attempt, maxAttempts,                  │ 同一行直接调
           │  delayMs, error)                        │ RetrySignals.reportRound
           │                                         │ (绕过事件流过滤,
           │                                         │  子 Agent 重试也能显示)
           ▼                                         ▼
                 RetrySignals 单例
                 (ValueNotifier<RetryState?>)
                          │
                          ▼
                retry_banner widget
                (ValueListenableBuilder)
                transport→橙 / round→蓝

RetryEvent 仍 emit 到事件流(用于可能用到的 subagent 详情页等未来扩展),
但 round-level 重试横幅**不依赖**事件流(直接调 RetrySignals),
避免 shouldMainSessionHandleEvent 过滤掉子 Agent 的 RetryEvent。
```

## 5. 组件清单

| 文件 | 操作 | 说明 |
|---|---|---|
| 🆕 `lib/services/dsl_engine/retry_signals.dart` | 新增 | 模块级单例 `RetrySignals`,`ValueNotifier<RetryState?>`,含 `reportTransport` / `reportRound` / `clear`;同文件放 `categorizeRetryError(Object)` 静态工具(供 `IoLlmHttpClient` 与 `agent_loop.dart` 共用,避免映射逻辑重复) |
| `lib/utils/retry_helper.dart` | 改签名 | `withRetry` 加可选 `onRetry(int attempt, int maxAttempts, int delayMs, Object error)` 回调(默认值 null,完全向后兼容);在 `await Future.delayed` 前调用 `onRetry(attempt, config.maxAttempts, delayMs, e)`(`maxAttempts` 由 withRetry 透传 `config.maxAttempts`,调用方无需重复传) |
| `lib/services/dsl_engine/llm_provider.dart` | 改动 | `IoLlmHttpClient.postJson` / `postJsonStream` 的 `withRetry` 注入 onRetry → `categorizeRetryError(error)` 后 `RetrySignals.reportTransport(... maxAttempts: config.maxAttempts ...)`;**`postJson` 成功 return 时**、**`postJsonStream` 握手成功(拿到 `_StreamHandshake` 后)各单点 `RetrySignals.clear()`**,rethrow 时**不 clear**(让 round-level 覆盖,无空白闪烁) |
| `lib/services/novel_agent/agent_event.dart` | 新增事件 | `RetryEvent extends AgentEvent`,字段 `attempt` / `maxAttempts` / `delayMs` / `errorCategory`;**必须** `const RetryEvent({...super.runId})` 转发 runId,否则 `EventTagger` 打标失败、sealed class 契约违反 |
| `lib/services/novel_agent/agent_loop.dart` | 改动 | (1) round-level 重试块(line ~398-422)在 `await Future.delayed` 前加 `emit(RetryEvent(...))` + `RetrySignals.reportRound(...)` **同一行**;(2) `emit AgentErrorEvent` 同一行 `RetrySignals.clear()`;(3) `emit AgentDoneEvent` 同一行 `RetrySignals.clear()` |
| `lib/services/novel_agent/subagent_state_projector.dart` | **必改(漏则编译失败)** | `EventTagger.tag` 与 `SubagentStateProjector.project` 两个对 `AgentEvent` 的 exhaustive switch 必须加 `case RetryEvent e => ...`(tagger: copy 并转发 e.runId;projector: no-op 或 future hook,本设计不接 RetrySignals) |
| `lib/core/providers/scenario_session.dart` | 改动(必加) | 因 §3.1.1 决定 `RetryEvent` 不再走 `scenario_session._handleAgentEvent` 桥接;但主 Agent 自身的 `RetryEvent`(`runId == null` 或 `mainSessionId`)不会被 `shouldMainSessionHandleEvent` 过滤,会进入 switch。`_handleAgentEvent` switch **必须**补 `case RetryEvent _:` 作为 no-op,否则新版 Dart sealed 模式匹配 / analyzer 警告 |
| 🆕 `lib/widgets/agent_chat/retry_banner.dart` | 新增 | 底部横幅 widget,`ValueListenableBuilder` 订阅 `RetrySignals.instance.notifier`;倒计时 `Timer.periodic(1s)`;橙/蓝配色 |

### 5.1 `RetryState` 数据模型(在 `retry_signals.dart` 里定义)

```dart
enum RetryLevel { transport, round }

class RetryState {
  final RetryLevel level;
  final int attempt;
  final int maxAttempts;
  final int delayMs;
  final String errorCategory;
  final DateTime receivedAt; // 计算倒计时用
}
```

`RetryEvent` 完整签名(必须转发 `super.runId`):

```dart
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
    super.runId,  // 转发:EventTagger 依赖此打 runId
  });
}
```

### 5.2 `RetrySignals` 单例 API

```dart
class RetrySignals {
  static final RetrySignals instance = RetrySignals._();
  RetrySignals._();

  final ValueNotifier<RetryState?> notifier = ValueNotifier(null);

  /// 传输层 withRetry 报告一次重试。覆盖式(总是写入最新)。
  void reportTransport({
    required int attempt,
    required int maxAttempts,  // 动态:阻塞=8、流式握手=3
    required int delayMs,
    required Object error,
  });

  /// 回合层 agent_loop 报告一次重试。在 emit RetryEvent 同一行调用,
  /// 绕过事件流过滤(子 Agent 重试也能显示)。
  void reportRound({
    required int attempt,
    required int maxAttempts,
    required int delayMs,
    required Object error,
  });

  /// 重试结束(postJson 成功 / AgentErrorEvent / AgentDoneEvent):清空让横幅消失。
  void clear();
}

/// 错误类别映射(传输层与回合层共用,避免重复逻辑)。
/// `429 → 限流`、`408 → 请求超时`、`4xx → 请求错误 {code}`、`5xx → 服务端 {code}`、
/// `Socket/Handshake → 网络断开`、`TimeoutException → 响应超时`、其它 → 重试中。
String categorizeRetryError(Object error);
```

UI 端用 `RetrySignals.instance.notifier`(不暴露 setter),通过 `ValueListenableBuilder<RetryState?>` 订阅。null → 横幅不渲染。

### 5.3 横幅 widget 行为

- **位置**:在 `agent_chat_dialog.dart` 的 Column 中,于 `_buildContextTag()` 与 `_buildInputBar(...)` 之间插入 `RetryBanner()`(与 `_buildErrorBar` 同级,条件渲染)。具体行号参照 `agent_chat_dialog.dart:158-159`。
- **配色**:transport→橙色 (`Colors.orange` 或项目里 `appColors.warningTint`);round→蓝色 (`Colors.blue` 或 `appColors.infoTint`)
- **文案**:
  - 阻塞传输层:`⟳ 网络重试 3/8 · 限流 · 2s 后重试`
  - 流式握手:`⟳ 网络重试 2/3 · 服务端 503 · 2s 后重试`
  - 回合层:`⟳ 回合重试 1/2 · 限流`
- **倒计时**:`onRetry` 提供 `delayMs`;Banner 收到后启 `Timer.periodic(1s)` 倒计时显示「Xs 后重试」。`delayMs <= 1000` 时只显示「重试中」。**倒计时到 0 时**(fn() 正在重试中,新一轮即将/正在发),文案切换为「重试中…」(不再显示秒数),直到下一次 `onRetry` 到达重置,或 `clear()` 让横幅消失。

## 6. 错误处理

### 6.1 横幅不消失 / 回调内异常

如果 `withRetry` 内的 `onRetry` 回调本身抛异常(理论上不该,但防御式编码),用 try/catch 包住,不影响重试主流程。`RetrySignals.report*` 失败 → log warn → 不影响调用方。

### 6.2 clear 策略(关键:无空白闪烁)

**核心原则**:传输层 `withRetry` 内**不调** clear,只在最外层真正终态时 clear。

- **传输层**:`IoLlmHttpClient.postJson` / `postJsonStream` 的 `onRetry` **只 `reportTransport`**(写入最新 state),不 clear。
  - `postJson` 成功 return 时:**单点 `RetrySignals.clear()`**(横幅消失)。
  - `postJsonStream` **握手成功**(2xx,`await withRetry(...)` 返回 `_StreamHandshake` 后,行号 ~1002-1006):**单点 `RetrySignals.clear()`**——否则橙色"网络重试 N/3"会残留到流结束期间误导用户。
  - `rethrow` 时:**不 clear**,让上层 `agent_loop` 准备 `emit RetryEvent` + `reportRound` 直接覆盖 state,无中间空白闪烁。
- **回合层**:`agent_loop.dart` round-level 在 `emit RetryEvent` + `reportRound` **同一行**调;round 重试最终失败 → `emit AgentErrorEvent` **同一行** `clear`;round 重试成功(进入下一轮 ChatStream)→ 传输层新一轮会自己 `reportTransport`(覆盖前一个 round state),无需 clear。
- **最终兜底**:`emit AgentDoneEvent` 同一行 `clear()`。

为什么不用 `try/finally`:finally 在 `rethrow` 前必跑,会清掉下一轮 race-condition 的状态。无 finally 的"成功 clear / rethrow 不 clear" 是确定性无空白的方案。

### 6.3 测试可达性

`RetrySignals` 单例对测试不友好(状态跨用例残留)。

- **单元测试**:setup 里 `RetrySignals.instance.clear();` + `addTearDown(() => RetrySignals.instance.clear());`
- **Widget 测试**:除了上面的 clear,**还需** `pumpWidget` 后 `tester.pumpAndSettle` 确保旧 widget dispose,避免 `ValueListenableBuilder` 的 listener 泄漏到下一个用例;必要时 `RetrySignals.instance.notifier.dispose()` 后重建(单例内部可加一个 factory reset 钩子,放在 `RetrySignals.instance`)。
- **多 session 串号限制**:`RetrySignals` 是模块级单例,`ScenarioSession` 按 `scenarioId` 隔离,但全局单例会让 Scenario A 看对话时 Scenario B 后台重试让 A 的横幅也显示。**本次范围接受(YAGNI)**,后续若需要 per-session 隔离再改为可注入实例。
- **factory reset 钩子**:测试需要时,`RetrySignals` 提供 `@visibleForTesting void resetForTest()`,内部 `notifier.value = null` + 重建 `ValueNotifier`,供 widget test tearDown 调用,语义明确。
- 备选(本次不实现):把 `RetrySignals` 构造参数化,测试传新实例。但当前需求规模下单例够用,YAGNI。

### 6.4 流式握手成功后,流中段断开的行为

- **流式握手成功(2xx)后**:横幅仍可能短暂显示上一次的"网络重试 N/3"(因为握手成功不在 `onRetry` 序列里,需要本次 postJson 的成功 return 才 clear);传输层下一处成功 return 时 clear → 橙色横幅消失。
- **流中段断开**(Socket / Timeout):不走 withRetry(避免 UI 内容重复、避免向 LLM 二次发同一请求),但抛出的异常会被 `agent_loop` round-level catch 捕获并触发 round-level 重试 → `emit RetryEvent` + `reportRound` → 显示**蓝色回合重试横幅**。即流中段断开 = 蓝色横幅(无橙色,因为没走 withRetry)。

## 7. 测试策略

| 层 | 文件 | 验证点 |
|---|---|---|
| 工具 | `test/unit/utils/retry_helper_test.dart` | onRetry 调用次数 = fn 失败次数(成功路径 0 次;中途成功 n 次调用 n 次;全失败 maxAttempts-1 次);`attempt` / `maxAttempts` / `delayMs` / `error` 参数正确 |
| 信号 | `test/unit/services/dsl_engine/retry_signals_test.dart`(新增) | `reportTransport` / `reportRound` 写入最新 state;`clear()` 复位;`ValueNotifier` 通知 listener;`categorizeRetryError` 各分支(429/408/5xx/Socket/Timeout/其它) |
| Provider | `test/unit/services/dsl_engine/llm_provider_retry_test.dart`(新增或扩展) | postJson 重试时 `RetrySignals` 收到 `RetryableHttpException` 经 `categorizeRetryError` 映射的 `errorCategory`,且 `maxAttempts` 传入正确(阻塞=8 / 流式=3);postJson 成功时 clear,rethrow 时**不** clear |
| Agent | `test/unit/services/novel_agent/agent_loop_retry_test.dart`(扩展) | round-level 重试 `emit RetryEvent` + `RetrySignals.reportRound` 同调;`AgentErrorEvent` / `AgentDoneEvent` emit 时 clear;RetryEvent **必须转发 `super.runId`** |
| Sealed | `test/unit/services/novel_agent/subagent_state_projector_test.dart`(若有) | `EventTagger.tag(RetryEvent)` 正确转发 runId |
| Widget | `test/widget/agent_chat/retry_banner_test.dart`(新增) | 横幅出现/消失、橙蓝配色、倒计时数字递减、`Xs 后重试` 到 0 时切"重试中…"的边界、文案格式 |

## 8. 实施拆分(供后续 writing-plans 引用)

1. **底层**:`retry_helper.dart` 加 `onRetry`(向后兼容,默认值 null)
2. **信号层**:新建 `retry_signals.dart`(`RetrySignals` 单例 + `RetryState` + `RetryLevel` + `categorizeRetryError`),含单元测试
3. **LLM 接线**:`llm_provider.dart` 注入 onRetry → `reportTransport`;postJson 成功 return 单点 clear(无 finally)
4. **Agent 接线**:
   1. `agent_event.dart` 新增 `RetryEvent`(**含 `super.runId`**)
   2. `subagent_state_projector.dart` `EventTagger.tag` + `SubagentStateProjector.project` **两个 exhaustive switch 加 `case RetryEvent`**(漏则编译失败)
   3. `agent_loop.dart` round-level 重试块 `emit RetryEvent` + `reportRound(maxAttempts: _config.networkRetryPerRound)` 同一行;`AgentErrorEvent` / `AgentDoneEvent` emit 时 clear
   4. `scenario_session.dart` `_handleAgentEvent` switch 加 `case RetryEvent:` 为 no-op(防新版 Dart 模式匹配 / 静态分析警告)
5. **UI**:新建 `retry_banner.dart`,接到 `agent_chat_dialog.dart` 的 `_buildContextTag` 与 `_buildInputBar` 之间(行号 ~158-159)
6. **测试**:按上面 §7 分层补齐
7. **文档**:CLAUDE.md changelog;`novel_app/CLAUDE.md` 的"AI 集成"段落补一段"传输层/回合层重试 UI 展示"

## 9. 后续扩展点(本次不做)

- `withRetry` 支持 `CancellationToken`,让横幅加"取消重试"按钮
- 横幅可展开看历史重试列表
- subagent 重试区分为不同 runId 标签或独立显示
- 错误体后端 message 折叠展开
- 横幅跟随 conversation 滚动 vs 钉视口固定(本设计选固定)

## 10. 相关已有设计

- `2026-07-15-agent-ocr-extractor-design.md` — 同模块(Agent)近期变更参考
- `2026-07-16-save-script-ocr-design.md` — 同模块近期变更参考
- `2026-07-13-agent-chat-image-upload-design.md` — `AgentChatSegment` / 投影层新增子类的先例,可参考

## 11. 用户审查关卡

请用户审阅本文件后,如需修改请告知。任何修改后都会重新跑规格审查循环(spec-document-reviewer 子代理),通过后才进入 writing-plans。
