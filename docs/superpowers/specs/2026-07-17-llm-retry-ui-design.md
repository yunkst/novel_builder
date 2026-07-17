# LLM 重试 UI 展示设计

- **日期**:2026-07-17
- **作者**:与 Claude Code 协同设计
- **状态**:草案,待用户审阅
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
| subagent 重试隔离 | 用户决定"所有重试都显示",不区分 main / sub session runId |
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
| subagent 重试 | **所有重试都显示**(不区分 runId) | 用户确认;简化实现,RetrySignals 单例直接 report |

## 3. 方案选择

### 3.1 传输层信号如何传出(`withRetry` → UI)

| 候选 | 优劣 | 结论 |
|---|---|---|
| **A. `withRetry` 加 `onRetry` 回调 + 模块级单例 `RetrySignals`** | 改动小(只动 `retry_helper` 签名 + `IoLlmHttpClient` 两处调用);复用性好(任何传入 onRetry 的调用方都能用);测试独立 | ✅ 采用 |
| B. `IoLlmHttpClient` 构造注入 `StreamController<RetryEvent>? retrySink` | 生命周期清晰,但 sink 链路长(从 LlmProvider 到 ScenarioSession 再到 UI 绕一圈);`RetryEvent` 与 `AgentEvent` 类名语义重叠易混 | 否 |
| C. ScenarioSession 包一层"包装器"在外面重试 | 改动最大,重写现有 `chat`/`chatStream` 的重试语义,不推荐 | 否 |

### 3.2 错误码类别分类

在 `IoLlmHttpClient` onRetry 回调里根据异常类型 / `RetryableHttpException.statusCode` 映射:

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
| 传输层重试中(指数退避等待) | 橙色 "网络重试 N/8 · 错误类别 · Xs 后重试" |
| 传输层全失败 → round-level 接管 | 蓝色 "回合重试 N/2 · 错误类别" |
| round-level 完成新一轮 → 传输层又开始重试 | 回到橙色 |

## 4. 数据流

```
┌─────────────────────┐         ┌───────────────────────────┐
│ 传输层 withRetry     │         │ round-level agent_loop    │
│ (8次, IoLlmHttpClient)│        │ (2次, 已能 emit)          │
└──────────┬──────────┘         └─────────────┬─────────────┘
           │ onRetry 回调(attempt, max,        │ emit RetryEvent
           │   delayMs, error)                  │ (extends AgentEvent)
           ▼                                    ▼
   RetrySignals 单例               scenario_session._handleAgentEvent
   (ValueNotifier<RetryState?>)           │ report
           │                              │
           └──────────────┬───────────────┘
                          ▼
              retry_banner widget
              (ValueListenableBuilder)
              transport→橙 / round→蓝
```

## 5. 组件清单

| 文件 | 操作 | 说明 |
|---|---|---|
| 🆕 `lib/services/dsl_engine/retry_signals.dart` | 新增 | 模块级单例,`ValueNotifier<RetryState?>`,含 `reportTransport` / `reportRound` / `clear` |
| `lib/utils/retry_helper.dart` | 改签名 | `withRetry` 加可选 `onRetry(int attempt, int maxAttempts, int delayMs, Object error)`;在 `await Future.delayed` 前调用 |
| `lib/services/dsl_engine/llm_provider.dart` | 改动 | `IoLlmHttpClient.postJson` / `postJsonStream` 的 `withRetry` 注入 onRetry → 提取错误类别后 `RetrySignals.reportTransport(...)`;外层 `try/finally` 保证 `RetrySignals.clear()` |
| `lib/services/novel_agent/agent_event.dart` | 新增事件 | `RetryEvent extends AgentEvent`,字段 `attempt` / `maxAttempts` / `delayMs` / `errorCategory` |
| `lib/services/novel_agent/agent_loop.dart` | 改动 | round-level 重试块 (line ~398-422) 在 `await Future.delayed` 前加一行 `emit(RetryEvent(...))`;现有 `LoggerService.w` 保留 |
| `lib/core/providers/scenario_session.dart` | 改动 | `_handleAgentEvent` switch 加 `case RetryEvent` → `RetrySignals.reportRound(...)` |
| 🆕 `lib/widgets/agent_chat/retry_banner.dart` | 新增 | 底部横幅 widget,`ValueListenableBuilder` 订阅 `RetrySignals.instance`;倒计时用 `Timer.periodic(1s)`;橙/蓝配色 |

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

### 5.2 `RetrySignals` 单例 API

```dart
class RetrySignals {
  static final RetrySignals instance = RetrySignals._();
  RetrySignals._();

  final ValueNotifier<RetryState?> notifier = ValueNotifier(null);

  /// 传输层 withRetry 报告一次重试。覆盖式(总是写入最新)。
  void reportTransport({
    required int attempt,
    required int maxAttempts,
    required int delayMs,
    required String errorCategory,
  });

  /// 回合层 agent_loop 报告一次重试。同上。
  void reportRound({...});

  /// 重试结束(成功/最终失败/换轮),清空让横幅消失。
  void clear();
}
```

UI 端用 `RetrySignals.instance.notifier`(不暴露 setter),通过 `ValueListenableBuilder<RetryState?>` 订阅。null → 横幅不渲染。

### 5.3 横幅 widget 行为

- 位置:钉在 Agent Chat 输入栏上方(参考 `agent_chat_dialog.dart` 的输入栏布局)
- 配色:transport→橙色 (`Colors.orange` 或项目里 `appColors.warningTint`);round→蓝色 (`Colors.blue` 或 `appColors.infoTint`)
- 文案:
  - 传输层:`⟳ 网络重试 3/8 · 限流 · 2s 后重试`
  - 回合层:`⟳ 回合重试 1/2 · 限流`
- 倒计时:`onRetry` 提供 `delayMs`;Banner 收到后启 `Timer.periodic(1s)` 倒计时,显示 `Xs 后重试`。`delayMs <= 1000` 时只显示"重试中"。
- 过渡:下次 onRetry 到达 → 重置倒计时;`clear()` 调用 → 横幅消失(150ms 渐变 fade-out,YAGNI 备选)。

## 6. 错误处理

### 6.1 横幅不消失

如果 `withRetry` 内的 `onRetry` 抛异常(理论上不该,但防御式编码),用 try/catch 包住,不影响重试主流程。`RetrySignals.report*` 失败 → log warn → 不影响调用方。

### 6.2 clear 残留

`IoLlmHttpClient.postJson` 外层 try/finally:无论成功/失败,`finally` 里 `RetrySignals.clear()`。否则传输层成功但横幅残留(因为 onRetry 只在重试前调,成功后不再调,横幅永远显示着最后一次).

但 final clear 与 round-level 接管的时序可能竞争:`postJson` rethrow(传输层全失败)→ 同步 clear → agent_loop 准备 emit RetryEvent(回合层蓝色)→ 用户看到一闪而过的空白。优化:clear 延迟到 agent_loop 的 onError 兜底分支结束 / round-level 成功返回后再 clear。简化方案:接受这一闪空白;真不行就加 `Future.delayed(50ms)` 后 clear。

### 6.3 测试可达性

`RetrySignals` 单例对测试不友好(状态跨用例残留)。在测试 setup 里:
```dart
addTearDown(() => RetrySignals.instance.clear());
```
测试用例需要时显式 clear,避免"上一个用例留下的横幅状态"污染下一个用例。

### 6.4 流式握手成功后的空白期

`postJsonStream` 握手阶段最多重试 3 次(现有 `RetryConfig(maxAttempts: 3)`)。握手成功后,流中段断开不走 withRetry(避免 UI 内容重复),横幅自然消失。流中段断开不属于本设计要展示的"重试"范畴,符合预期。

## 7. 测试策略

| 层 | 文件 | 验证点 |
|---|---|---|
| 工具 | `test/unit/utils/retry_helper_test.dart` | onRetry 回调被调用 `maxAttempts-1` 次;`attempt`/`delayMs`/`error` 参数正确;成功/失败路径不调用或只调失败前的次数 |
| 信号 | `test/unit/services/dsl_engine/retry_signals_test.dart`(新增) | `reportTransport` / `reportRound` 写入最新 state;`clear()` 复位;ValueNotifier 通知 listener |
| Provider | `test/unit/services/dsl_engine/llm_provider_retry_test.dart`(新增或扩展) | postJson 重试时 `RetrySignals` 收到 `RetryableHttpException` 映射的 `errorCategory`;成功后 clear |
| Agent | `test/unit/services/novel_agent/agent_loop_retry_test.dart`(扩展) | round-level 重试 emit `RetryEvent`,UI 桥接到 `RetrySignals.reportRound` |
| Widget | `test/widget/agent_chat/retry_banner_test.dart`(新增) | 横幅出现/消失、橙蓝配色、倒计时数字递减、文案格式 |

## 8. 实施拆分(供后续 writing-plans 引用)

1. **底层**: `retry_helper.dart` 加 onRetry(向后兼容,默认值 null)
2. **信号层**: 新建 `retry_signals.dart`,含单元测试
3. **LLM 接线**: `llm_provider.dart` 注入 onRetry + try/finally clear
4. **Agent 接线**: `agent_event.dart` 新增 RetryEvent + `agent_loop.dart` emit + `scenario_session.dart` 桥接
5. **UI**: 新建 `retry_banner.dart`,接到 `agent_chat_dialog.dart` 的输入栏上方
6. **测试**: 按上面 §7 分层补齐
7. **文档**: CLAUDE.md changelog;若需要,把"传输层重试 UI"加进 novel_app 模块的"AI 集成"段落

## 9. 后续扩展点(本次不做)

- `withRetry` 支持 `CancellationToken`,让横幅加"取消重试"按钮
- 横幅可展开看历史重试列表(扇形气泡)
- subagent 重试区分为不同 runId 标签或独立显示
- 错误体后端 message 折叠展开
- 横幅跟随 conversation 滚动 vs 钉视口固定(本设计选固定)

## 10. 相关已有设计

- `2026-07-15-agent-ocr-extractor-design.md` — 同模块(Agent)近期变更参考
- `2026-07-16-save-script-ocr-design.md` — 同模块近期变更参考
- `2026-07-13-agent-chat-image-upload-design.md` — `AgentChatSegment` / 投影层新增子类的先例,可参考

## 11. 用户审查关卡

请用户审阅本文件后,如需修改请告知。任何修改后都会重新跑规格审查循环(spec-document-reviewer 子代理),通过后才进入 writing-plans。
