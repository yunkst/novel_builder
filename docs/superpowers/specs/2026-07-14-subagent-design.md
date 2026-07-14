# Subagent 子 Agent 功能设计（novel_app）

- **日期**：2026-07-14
- **作者**：yedazhi（与 Claude Code 协同设计）
- **状态**：草案，待用户审阅
- **范围**：仅 Flutter 端 `novel_app`，后端零改动、数据库零持久化、不新增 DB 表
- **关联模块**：`lib/services/novel_agent/`、`lib/core/providers/`、`lib/widgets/agent_chat/`、`lib/screens/`

## 1. 背景与目标

### 1.1 现状

novel_app 的 AI 能力基于 `lib/services/novel_agent/` 下的 ReAct 对话循环：

- `AgentLoop`（`agent_loop.dart`）：单次运行的无状态 ReAct 循环，负责流式 LLM 调用、工具调用、上下文压缩、重试。
- `AgentScenario`（`agent_scenario.dart`）+ `ScenarioSession`（`core/providers/scenario_session.dart`）：一个场景实例对应一个用户可见的会话，持有对话历史、持久化到 `chat_messages` 表、向 UI 暴露 `AgentChatState`。
- `ToolExecutor`（`tool_executor.dart`）+ 7 个子执行器：负责具体工具（读章节、写章节、改大纲、读角色等）的调用。
- 事件流：`NovelAgentService.events` 是全局 broadcast `Stream<AgentEvent>`，所有 `ScenarioSession` 共用，当前靠「同 scenario 不并发 + sessionId 守卫」过滤事件。

这套架构已经为「子 Agent」打下了基础：

- `AgentLoop` 每次 `run()` 都新建，天然支持嵌套/并行。
- `ScenarioSession` 的状态机、持久化、UI 投影可以复用给子 Agent。
- 工具执行器已有 `OutlineExecutor`、`ChapterReadExecutor` 等，可被白名单控制。

但现有架构存在两个关键阻塞点：

1. **全局事件流没有 runId 标记**：一旦多个 AgentLoop 同时运行（主 Agent + 子 Agent 并行），事件会互相串扰。
2. **`NovelAgentService._runningByScenario` 用 `scenarioId` 作 key**：同一主 Agent 下并发多个子 Agent 时无法区分运行态。

### 1.2 目标

让主 Agent 在梳理大型小说大纲等复杂任务时，能够**主动派出子 Agent** 去独立执行子任务。用户可以：

- 在主 Agent 对话气泡里看到派出的子任务卡片；
- 子 Agent 运行期间，卡片实时显示进度摘要；
- 点击卡片进入 `SubagentDetailScreen`，查看子 Agent 的完整工作流（流式思考、工具调用、最终结果）；
- 关闭详情页后子 Agent 继续在后台运行，用户可通过主气泡卡片再次进入；
- 子 Agent 完成后，其最终总结自动回流到主 Agent，主 Agent 继续推理。

### 1.3 非目标（显式排除）

| 项 | 理由 |
|---|---|
| 子 Agent 再派子 Agent | 强制单层嵌套。子 Agent 的 `allowed_tools` 不含 `dispatch_subagent`，`SubagentScenario` 的 schema 也过滤掉它。 |
| 子 Agent 工作过程持久化到 DB | 决策为「不持久化」，只保留子 Agent 最终总结在主 Agent 对话历史中。App 杀后子 Agent 细节丢失。 |
| 角色模板 / 预设子 Agent 类型 | 不预设。子 Agent 能力完全由主 Agent 通过 `allowed_tools` 声明，人格由 `task` 文本 + 通用 system prompt 模板驱动。 |
| 任务列表独立 Screen | YAGNI。入口是主 Agent 气泡里的子任务卡片。 |
| 并发上限可配置 | 硬编码：同轮并行 4，单轮排队上限 30。未来若用户反馈再做成设置项。 |
| 后端改动 | 子 Agent 是纯前端本地运行，后端零改动。 |
| 数据库迁移 | 不新增表/列。 |

---

## 2. 关键设计决策（已与用户确认）

| 维度 | 决策 | 依据 |
|------|------|------|
| 谁派 | **LLM 工具调用 + UI 一等公民** | 主 Agent 通过 `dispatch_subagent` 工具调用派出；UI 把它提升为可点击、可查看详情的任务卡片。 |
| 能力边界 | **调用方声明 `allowed_tools` 白名单** | 灵活且可约束。不存在或不合法的工具名由 `guidanceError` 引导修正。 |
| 同步/异步 | **同轮多 `dispatch_subagent` 并行（同步工具语义）** | 一个 `tool_call` 仍阻塞主 Agent，但同一轮多个 `dispatch_subagent` 用 `Future.wait` 并行执行。 |
| 并发规则 | **同轮并行 4，排队到 30，超过 30 拒绝** | 用户明确：并发 4，排队到 30，超限报错。 |
| UI 形态 | **主气泡轻量进度卡片 + 详情页跳转** | 主气泡显示实时进度摘要；点击进入 `SubagentDetailScreen` 看完整工作流。 |
| 持久化 | **不持久化** | 子 Agent 细节纯内存。最终总结随主 Agent 消息持久化到 `chat_messages`。 |
| 子 Agent 人格 | **通用子 Agent system prompt 模板** | 一套固定模板约束 ReAct 纪律、结果格式、边界；具体任务由 `task` 文本驱动。 |
| 主气泡等待体验 | **工具卡片实时进度 + 可点击入口** | 用户能感知子 Agent 在跑、有东西可点。 |
| 详情页关闭行为 | **关闭不取消，显式停止按钮** | 符合移动端多任务习惯；取消子 Agent 需要通过详情页里的停止按钮。 |
| 事件流改造 | **`AgentEvent` 加 `runId` 字段 + 订阅方按 runId 过滤** | 改动最小，和现有 `ScenarioSession` 过滤机制最契合。 |
| 嵌套限制 | **强制单层嵌套** | 子 Agent 无法派子 Agent。 |

---

## 3. 方案选择

### 3.1 候选方案回顾

| 方案 | 简述 | 结论 |
|---|---|---|
| **A. 同步阻塞单工具** | `dispatch_subagent` 是工具，主 Agent 卡在一个调用上，子 Agent 跑完才返回。 | 太弱，无法并行。 |
| **B. 异步任务队列** | 派子 Agent 立即返回 taskId，主 Agent 后续轮询结果。 | 太重，需要队列、回调注入、LLM 轮询心智。 |
| **C. 同轮多 tool_call 并行（采用）** | 同一轮多个 `dispatch_subagent` 并行跑，结果一起交回主 Agent。 | 兼顾语义干净与并行能力。 |

**选 C 的理由**：以最小改动拿到并行能力；LLM 是否一次发多个 tool_call 由 prompt 引导，即使它串行派发也只是变慢，不破坏功能。

### 3.2 为什么不持久化子 Agent

- 子 Agent 本质是「计算过程」，最终产物是「总结」；总结进入主 Agent 历史即已落盘。
- 不持久化可大幅简化生命周期管理：无需新表、无需迁移、无需考虑主 Agent 回滚对子 Agent 的级联影响。
- 取舍：App 被杀后子 Agent 细节丢失。用户可在子 Agent 跑完、主 Agent 还在运行时回看；主 Agent 结束后只能看到卡片最终摘要。

---

## 4. 架构

```
┌─────────────────────────────────────────────────────────────────────┐
│ 主 Agent ScenarioSession                                            │
│  - 监听 NovelAgentService.events，按 runId 过滤                     │
│  - 持有 SubagentRegistry（内存）跟踪本会话派出的子 Agent              │
│  - UI 通过 currentChatStateProvider 渲染主气泡 + 子任务卡片       │
└──────────────────┬──────────────────────────────────────────────────┘
                   │ 主 Agent 某轮返回 tool_calls
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│ AgentLoop.run() 改造                                                │
│  - 本轮所有 tool_calls 按 name 分组：                                │
│    - 普通工具：走现有 ToolExecutor.execute（可并行或保持串行）      │
│    - dispatch_subagent：进入 SubagentRunner                         │
│  - 同一轮多个 dispatch_subagent → Future.wait 并行                  │
│  - SubagentRunner 内部维护「并行 4 + 队列 30」调度                  │
│  - 超 30 立即返回 guidanceError                                     │
└──────────────────┬──────────────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│ SubagentRegistry（内存，按 sessionId 隔离）                         │
│  Map<sessionId, Map<runId, SubagentRun>>                            │
│  - SubagentRun：                                                      │
│    - runId: uuid                                                      │
│    - parentSessionId                                                  │
│    - task: String                                                     │
│    - allowedTools: List<String>                                       │
│    - state: pending / running / completed / failed / cancelled        │
│    - chatState: AgentChatState                                        │
│    - tokenSource: CancellationTokenSource                             │
│    - finalSummary: String?                                            │
│    - errorMessage: String?                                            │
└──────────────────┬──────────────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│ SubagentScenario（AgentScenario 子类）                              │
│  - tools: 由 allowedTools 过滤后的子集                               │
│  - executeTool：调用前校验工具在白名单内；否则 guidanceError      │
│  - systemPrompt: 通用子 Agent 模板                                   │
│  - 不允许 dispatch_subagent 出现在 schema / 执行路径                │
└──────────────────┬──────────────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│ SubagentDetailScreen（新 Screen）                                   │
│  - 只读：展示子 Agent 的 AgentChatState                              │
│  - 顶部显示任务信息（task、allowedTools、状态）                     │
│  - 主体复用 agent_chat 的流式消息列表                                │
│  - 底部显式「停止」按钮                                              │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. 数据模型

### 5.1 AgentEvent 改造

`lib/services/novel_agent/agent_event.dart` 基类增加可选字段：

```dart
sealed class AgentEvent {
  const AgentEvent({this.runId});
  final String? runId; // null = 旧路径兼容；子 Agent 事件必须携带子 runId
}
```

所有子类构造函数同步加 `runId` 参数。

### 5.2 SubagentRun（内存模型）

```dart
class SubagentRun {
  final String runId;
  final String parentSessionId;
  final String task;
  final List<String> allowedTools;
  final DateTime createdAt;
  SubagentRunState state;
  AgentChatState chatState;              // 子 Agent 实时 UI 状态
  CancellationTokenSource? tokenSource;  // 用于取消子 Agent
  StreamSubscription<AgentEvent>? eventSub; // 监听全局事件流
  String? finalSummary;
  String? errorMessage;
}

enum SubagentRunState { pending, running, completed, failed, cancelled }
```

### 5.3 SubagentRegistry

```dart
class SubagentRegistry {
  final Map<String, Map<String, SubagentRun>> _runsBySession = {};

  SubagentRun create({
    required String parentSessionId,
    required String task,
    required List<String> allowedTools,
  });

  SubagentRun? get(String parentSessionId, String runId);
  List<SubagentRun> listForSession(String parentSessionId);
  void remove(String parentSessionId, String runId);
  void clearForSession(String parentSessionId);
}
```

Registry 是内存对象，不由 DB 持久化。生命周期随 `ScenarioSessionsNotifier` 一起 dispose（或更保守地，保留最近 N 个 run 供回看，N=20）。

---

## 6. 新工具定义

### 6.1 `dispatch_subagent`

注册位置：`lib/services/novel_agent/agent_tools.dart`

Function schema：

```json
{
  "name": "dispatch_subagent",
  "description": "派出一个子 Agent 独立执行子任务。子 Agent 只能使用 allowed_tools 列表中的工具，无法继续派子 Agent。",
  "parameters": {
    "type": "object",
    "properties": {
      "task": {
        "type": "string",
        "description": "交给子 Agent 的具体任务说明，例如：'请阅读第1-30章并梳理主要人物关系。'"
      },
      "allowed_tools": {
        "type": "array",
        "items": { "type": "string" },
        "description": "子 Agent 可调用的工具名白名单。必须从当前可用工具中选择，不能包含 dispatch_subagent。"
      }
    },
    "required": ["task", "allowed_tools"]
  }
}
```

### 6.2 校验规则

| 条件 | 结果 |
|---|---|
| `task` 缺失 | `guidanceError('missing_param', 'task 不能为空')` |
| `allowed_tools` 缺失或非数组 | `guidanceError('invalid_param', 'allowed_tools 必须是字符串数组')` |
| `allowed_tools` 含 `dispatch_subagent` | 过滤掉或返回 `guidanceError('forbidden_tool', '子 Agent 不能调用 dispatch_subagent')` |
| `allowed_tools` 含不存在的工具名 | 工具本身执行时返回 `guidanceError('unknown_tool', '工具 xxx 不存在')` |
| 单轮总数 > 30 | 返回 `guidanceError('max_subagents_reached', '单轮最多 30 个子 Agent')` |

---

## 7. AgentLoop 改造

### 7.1 同一轮多个工具调用的执行策略

当前 `AgentLoop` 第⑥步是 `for each call` 串行 await。**关键原则：普通工具的串行行为保持不变**（避免多个写工具并发冲突），只有 `dispatch_subagent` 走并行路径。具体分两组处理：

```dart
// 1. 先串行执行本轮所有「普通」工具（行为与现状完全一致）
for (final call in toolCalls.where((c) => c.name != 'dispatch_subagent')) {
  await _runRegularTool(call); // 沿用现有 ToolExecutor 路径
}

// 2. 再并行执行本轮所有 dispatch_subagent
final subagentCalls = toolCalls.where((c) => c.name == 'dispatch_subagent').toList();
final results = await Future.wait(
  subagentCalls.map((call) => _runSubagent(call)),
);
```

> 设计说明：同轮「普通工具 + 子 Agent」共存时，先跑完普通工具（它们通常快、且有写冲突风险），再统一并行派出子 Agent。这把改动面严格限制在 `dispatch_subagent` 路径，不触碰普通工具的现有执行语义。

### 7.2 子 Agent 并发调度

`_runSubagent` 内部委托 `SubagentRunner`：

```dart
class SubagentRunner {
  static const int _maxConcurrent = 4;
  static const int _maxQueue = 30;
  static final Map<String, SubagentRunner> _perSession = {};

  // 同一 session 内，正在跑的子 Agent 数 + 排队中的任务数
  int get _totalActive => _running.length + _queued.length;

  Future<String> run({
    required String parentSessionId,
    required String task,
    required List<String> allowedTools,
    required void Function(AgentEvent) emit,
  });
}
```

- 当 `_running.length < 4`：直接启动。
- 当 `4 <= _totalActive < 30`：入队 FIFO，等待有空位。
- 当 `_totalActive >= 30`：立即返回 JSON 错误（`guidanceError`），不排队。

### 7.3 子 Agent 运行流程

1. 生成 `runId`。
2. `SubagentRegistry.create(...)` 创建 `SubagentRun`，状态 `pending`，初始化空 `AgentChatState`。
3. **订阅全局事件流**（按 `runId` 过滤后只处理自己的事件）：
   ```dart
   run.eventSub = agentService.events
     .where((e) => e.runId == run.runId)
     .listen(run.chatState.handleEvent); // 复用现有事件→state 投影逻辑
   ```
4. 状态改 `running`。
5. 创建 `SubagentScenario`（注入 `allowedTools`、`task`、`runId`）—— 它是 `AgentScenario` 子类，负责工具白名单过滤和子 Agent system prompt。**不传入 `ScenarioSession`**，子 Agent 没有自己的会话持久化、不需要回滚/重试/多 session 等能力。
6. 创建 `CancellationTokenSource`（绑定到 `run.tokenSource`）。
7. 直接构造 `AgentLoop`，`run()` 传入子 scenario、token、`emit` 回调（emit 时强制带 `runId`），由 `SubagentRunner` 调起。
8. 子 Agent 循环期间，每条 `AgentEvent` 经 emit 走到 `agentService.events` 广播流，被 `SubagentRun` 自己的订阅收到，更新 `chatState`。
9. 子 Agent 结束后（无论正常、超轮、取消、错误）：
   - 正常：取 `chatState.messages` 最后一条 assistant 消息作为 `finalSummary`。
   - 失败/取消：把 `errorMessage` 写入结果。
   - 取消 `run.eventSub`。
   - `SubagentRun.state` 更新为 `completed` / `failed` / `cancelled`。
10. 返回 JSON 字符串给主 Agent 循环。

> **设计说明**：子 Agent **不**走 `ScenarioSession`，直接用 `SubagentRunner` + `AgentChatState` 持有状态。这样决策 §1.3「不持久化」是天然的——子 Agent 没有任何 `chat_messages` 表写入路径，也不需要回滚。子 Agent 唯一被持久化到 DB 的产物是其 `finalSummary`，作为主 Agent 工具调用的返回值进入主 Agent 的 assistant 消息。

### 7.4 子 Agent 通用 system prompt 模板

```markdown
你是一个专注的子 Agent。你的任务由父 Agent 明确指定，你只能使用被授权的工具列表。

纪律：
1. 每次调用工具前，先用一行简洁说明你的思考。
2. 只能使用 allowed_tools 中的工具；越权调用会被拒绝。
3. 读-写分离：写入工具（如 update_outline）前必须先读取当前内容。
4. 完成或失败后必须停止，不要再派子 Agent。
5. 最终结果必须是结构化的 Markdown，包含：
   - ## 任务目标
   - ## 执行步骤
   - ## 关键发现
   - ## 最终结论
```

（模板细节在实现阶段微调，但以上结构写入 spec。）

---

## 8. UI 设计

### 8.1 主 Agent 气泡里的 `SubagentToolCard`

位置：`lib/widgets/agent_chat/agent_message_bubble.dart` 在渲染 `ToolCallSegment` 时识别 `name == 'dispatch_subagent'`。

卡片状态：

- **等待中**：显示子任务标题（task 前 30 字）、spinner、「点击看详情」。
- **运行中**：显示实时进度摘要（最后一条思考片段、最近工具名、已耗时）。
- **已完成**：显示 ✅ + 结果摘要 + 可点击展开。
- **失败/取消**：显示 ❌ 或 🛑 + 原因。

点击卡片 → `Navigator.push(SubagentDetailScreen(sessionId: ..., runId: ...))`，同时传入 `parentSessionId` 和 `runId`（与 §9.1 `subagentRunProvider` 的元组参数对齐）。也可用命名路由 `/subagent` + arguments 对象。

### 8.2 `SubagentDetailScreen`

路径：新 Screen `lib/screens/subagent_detail_screen.dart`。

布局：

- **顶部**：任务标题（task）、allowed_tools 列表 chip、状态标签、运行时长。
- **中部**：复用 `agent_chat_dialog` 的聊天列表（只读，无输入框）。
  - `messages`：已完成的子 Agent 历史。
  - `streamingSegments`：正在跑的子 Agent 实时流。
- **底部**：仅一个「停止」按钮（仅 running 状态可见）。

返回键：直接退出，不取消子 Agent。

### 8.3 进度摘要投影规则

`SubagentToolCard` 不需要显示完整对话，只显示一条摘要，按以下优先级刷新：

1. 如果子 Agent 正在跑：最后一条 `TextDeltaEvent` 的文本片段（取最近 40 字） + 最近工具名。
2. 如果子 Agent 正在执行工具：`[工具名] 执行中...` + 进度字符数（若适用）。
3. 完成：`finalSummary` 的第一行或前 60 字。
4. 失败/取消：`errorMessage` 或 `已取消`。

---

## 9. Provider 调整

### 9.1 新增 Provider

```dart
// 全局子 Agent 注册表
final subagentRegistryProvider = Provider<SubagentRegistry>((ref) {
  return SubagentRegistry();
});

// 按 runId 取子 Agent 状态（用于详情页）
final subagentRunProvider = Provider.family<SubagentRun?, (String sessionId, String runId)>((ref, pair) {
  final registry = ref.watch(subagentRegistryProvider);
  return registry.get(pair.$1, pair.$2);
});

// 主 Agent 当前会话派出的所有子任务（用于卡片列表）
final currentSubagentRunsProvider = Provider<List<SubagentRun>>((ref) {
  final registry = ref.watch(subagentRegistryProvider);
  final sessionId = ref.watch(currentSessionIdProvider); // 或等效
  return registry.listForSession(sessionId ?? '');
});
```

### 9.2 现有 Provider 改造

- `currentChatStateProvider`：保持不变，主 Agent 状态不变。
- `ScenarioSession`：在 `_handleAgentEvent` 里**过滤掉子 Agent 事件**（避免主 Agent 把子 Agent 的流式文本/工具调用误吸收进主对话）。
  - 若 `event.runId == null` 或等于本会话主 runId：走主 Agent 逻辑。
  - 若 `event.runId` 属于本会话派出的子 Agent：**主 session 直接忽略**（事件由 `SubagentRun` 自己的订阅消费，不进主对话历史）；同时 `SubagentRegistry` 中对应 `SubagentRun` 的 `chatState` 已由其独立订阅更新。
- `NovelAgentService`：把 `_runningByScenario` / `_tokensByScenario` 的 key 升级为复合 key `(scenarioId, runId)`，或等效地以 `runId` 为唯一运行键。

---

## 10. 事件流改造（α 方案）

### 10.1 AgentEvent 加 runId

所有事件构造函数增加 `runId` 参数，默认 `null` 兼容旧路径。

### 10.2 NovelAgentService 运行态 key

从 `Map<String, bool> _runningByScenario` 改为 `Map<String, bool> _runningByRunId`：

- `runId` 由调用方（`ScenarioSession` 或 `SubagentRunner`）传入。
- 主 Agent 使用主 session 的 `runId`（可复用 `sessionId` 或单独生成）。
- 子 Agent 使用独立的 `runId`。

### 10.3 ScenarioSession 监听过滤

```dart
void _handleAgentEvent(AgentEvent event) {
  final eventRunId = event.runId;
  // 只处理属于本会话的事件
  if (eventRunId != null && eventRunId != _mainRunId && !_ownsSubagentRun(eventRunId)) {
    return;
  }
  // ... 现有逻辑
}
```

### 10.4 子 Agent 事件订阅

子 Agent **不使用 `ScenarioSession`**。每个 `SubagentRun` 自己订阅全局 `events` 流，只处理 `event.runId == childRunId` 的事件，更新自己的 `chatState`（供详情页渲染）。不需要单独 `eventsFor(runId)`，保持改动最小。

---

## 11. 取消语义

### 11.1 主 Agent 取消

当用户取消主 Agent 时（`ScenarioSession.cancel()`）：

- 主 Agent 的 `CancellationToken` 触发。
- 取消所有属于本会话的子 Agent：遍历 `SubagentRegistry` 中 `parentSessionId == sessionId` 且状态为 `running` 或 `pending`（排队中）的 run，调用 `run.tokenSource?.cancel()`（pending 的 run 在被调度起来前先标记 cancelled，不再启动）。
- 子 Agent 返回 `cancelled` 结果给主 Agent 工具调用，主 Agent 本轮按现有逻辑处理。

### 11.2 子 Agent 单独取消

在 `SubagentDetailScreen` 点击「停止」：

- 调用 `run.tokenSource?.cancel()`。
- `AgentLoop` 检测到 cancel，按现有语义停止当前轮；子 Agent 循环结束。
- `SubagentRun.state` 变为 `cancelled`。
- 子 Agent 的 `ToolCallEndEvent` 返回错误结果给主 Agent。
- 主 Agent 可以选择重派或继续其它推理。

### 11.3 详情页关闭

返回键或 `Navigator.pop` 不触发取消。子 Agent 在后台继续运行。用户可再次通过主气泡卡片进入。

---

## 12. 测试策略

### 12.1 单元测试

- `SubagentScenario`：
  - 白名单内工具可正常执行。
  - 白名单外工具返回 `guidanceError`。
  - `dispatch_subagent` 不在 schema 中。
- `SubagentRegistry`：
  - 创建/查询/列表/清理。
  - 同一 session 多个 run 隔离。
- `dispatch_subagent` 参数解析：
  - 缺 `task`、`allowed_tools` 非数组、含 `dispatch_subagent`、含不存在工具名。

### 12.2 AgentLoop 改造测试

- 单 `dispatch_subagent`：主 Agent 等待，子 Agent 完成，结果回流。
- 同一轮 3 个 `dispatch_subagent`：并行跑完，结果按 runId 正确回流。
- `dispatch_subagent` 与普通工具混合：普通工具仍按现有串行方式先跑完，子 Agent 再并行启动；互不干扰。
- 并发 4 排队：第 5 个子 Agent 进入 pending，第 1 个完成后第 5 个启动。
- 超 30：第 31 个立即返回 guidanceError。

### 12.3 Provider 测试

- `subagentRunProvider` 返回正确 run。
- `currentSubagentRunsProvider` 随 registry 更新而更新。
- `ScenarioSession` 事件过滤：不处理其它 run 的事件。

### 12.4 Widget 测试

- `SubagentToolCard`：等待中/运行中/完成/失败/取消 四种状态渲染。
- 点击卡片跳转 `SubagentDetailScreen`。
- `SubagentDetailScreen`：只读、显示 task/allowedTools、停止按钮可取消。

### 12.5 集成测试

- 使用 mock `LlmProvider` 驱动一次完整流程：主 Agent 派 `outline_researcher` 子 Agent → 子 Agent 读取大纲和章节 → 返回总结 → 主 Agent 拿到总结后继续生成最终输出。

---

## 13. 风险与缓解

| 风险 | 缓解 |
|---|---|
| 全局事件流加 runId 后，旧代码路径未全部兼容 | 所有 `AgentEvent` 子类构造函数加 `runId` 默认 `null`；旧调用点不强制修改；lint 扫描现有 `emit` 调用点。 |
| LLM 不一次发多个 `dispatch_subagent` | system prompt 里示范「多 dispatch 并行」用法；即使串行也只是变慢，不影响功能。 |
| 子 Agent 长时间运行导致主 Agent 卡片一直 waiting | 子 Agent 进度摘要会实时刷新；用户可随时点进详情页；设计预期接受主 Agent 此轮阻塞。 |
| 子 Agent 崩溃/网络错误污染主 Agent 上下文 | 子 Agent 返回的 `errorMessage` 结构化，主 Agent 可以据此重派或跳过。 |
| 内存中子 Agent 过多 | 单轮上限 30；Registry 保留最近 N=20 个 run；`ScenarioSessionsNotifier` dispose 时清理对应 session 的 runs。 |
| 子 Agent 写坏大纲/章节 | 所有写工具保留现有 read-before-write 校验；子 Agent 只是另一个 tool 调用者，权限由白名单控制。 |

---

## 14. 实现文件清单

### 新增文件

| 文件 | 职责 |
|---|---|
| `lib/services/novel_agent/subagent_registry.dart` | 内存子 Agent 注册表 |
| `lib/services/novel_agent/subagent_run.dart` | `SubagentRun` 模型 + 状态枚举 |
| `lib/services/novel_agent/subagent_scenario.dart` | 子 Agent 专用 Scenario 子类 |
| `lib/services/novel_agent/subagent_runner.dart` | 子 Agent 运行调度器（含 4/30 并发控制） |
| `lib/screens/subagent_detail_screen.dart` | 子 Agent 详情页（只读） |
| `lib/widgets/agent_chat/subagent_tool_card.dart` | 主气泡里的子任务卡片 |
| `lib/widgets/agent_chat/subagent_progress_summary.dart` | 卡片实时进度摘要组件 |
| `test/unit/services/novel_agent/subagent_registry_test.dart` | 注册表单元测试 |
| `test/unit/services/novel_agent/subagent_scenario_test.dart` | 子 Agent 场景单元测试 |
| `test/unit/services/novel_agent/subagent_runner_test.dart` | 并发调度测试 |
| `test/unit/services/novel_agent/agent_loop_subagent_test.dart` | AgentLoop 改造测试 |
| `test/widgets/agent_chat/subagent_tool_card_test.dart` | 卡片 Widget 测试 |
| `test/screens/subagent_detail_screen_test.dart` | 详情页 Widget 测试 |

### 修改文件

| 文件 | 修改内容 |
|---|---|
| `lib/services/novel_agent/agent_event.dart` | 基类加 `runId` 字段；所有子类同步加参数 |
| `lib/services/novel_agent/agent_tools.dart` | 注册 `dispatch_subagent` 工具 schema |
| `lib/services/novel_agent/agent_loop.dart` | 同一轮 tool_calls 拆分为「普通工具串行 + dispatch_subagent 并行」两组；集成 SubagentRunner |
| `lib/services/novel_agent/novel_agent_service.dart` | 运行态 key 改为 `runId`；保留事件广播 |
| `lib/core/providers/scenario_session.dart` | 按 runId 过滤事件；管理本会话 SubagentRegistry |
| `lib/core/providers/agent_chat_providers.dart` | 新增 `subagentRegistryProvider` 等 |
| `lib/core/providers/agent_chat_state.dart` | 可能不需要修改；若工具卡片需要扩展状态则加字段 |
| `lib/widgets/agent_chat/agent_message_bubble.dart` | 识别 `dispatch_subagent` ToolCallSegment，渲染 `SubagentToolCard` |
| `lib/widgets/agent_chat/tool_call_segment_widget.dart` | 若存在，需识别子任务卡片 |
| `lib/main.dart` | 注册 `/subagent` 路由（若使用 `Navigator.pushNamed`） |

---

## 15. 后续可演进（非本轮）

- 子 Agent 持久化（如果用户反馈需要跨 App 生命周期回看）。
- 角色模板（`role="outline_researcher"`）在 `allowed_tools` 白名单基础上叠加默认 prompt 模板。
- 用户手动派子 Agent（从主气泡菜单或独立入口）。
- 子 Agent 结果「应用到大纲」的快捷按钮。
- 并发上限做成 LLM 配置项。

---

## 16. 参考

- `novel_app/CLAUDE.md` 模块架构说明
- `novel_app/lib/services/novel_agent/agent_loop.dart` ReAct 循环实现
- `novel_app/lib/services/novel_agent/agent_scenario.dart` Scenario 抽象
- `novel_app/lib/services/novel_agent/agent_event.dart` 事件类型
- `novel_app/lib/services/novel_agent/novel_agent_service.dart` 全局事件桥接
- `novel_app/lib/core/providers/scenario_session.dart` 会话状态管理
- `novel_app/lib/widgets/agent_chat/agent_message_bubble.dart` 工具卡片渲染
