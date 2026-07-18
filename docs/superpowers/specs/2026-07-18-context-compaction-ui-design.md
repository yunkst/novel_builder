# 上下文压缩 UI 展示设计

- **日期**:2026-07-18
- **作者**:与 Claude Code 协同设计
- **状态**:草案,待用户审阅
- **范围**:仅 Flutter 端 `novel_app`,后端零改动、DB schema 零改动
- **依赖**:本日已落地的 "ContextCompactor P1 预剪枝层"(2026-07-18 changelog)——`compact()` 新增 `_pruneOldToolResults`(MD5 去重 + 1-liner 改写),`CompactionResult`/`CompactionEvent` 已新增 `rewrittenContent`。本设计在此之上增加 UI 展示。

## 1. 背景与目标

### 1.1 现状

`ContextCompactor`(`context_compactor.dart`)在每轮 LLM 调用前检查 `needsCompaction(messages)`,默认阈值 500K 字符(≈125K tokens)。命中后执行 `compact()`:

- 保留 `system prompt` + 尾部消息,丢弃早期消息
- **P1 预剪枝**(本日已实现):先对老 tool result 做 MD5 去重 + 1-liner 改写,减少丢消息数
- `agent_loop.dart:161-168` emit `CompactionEvent`,只打一条 warning 日志

但 UI 完全静默:

- `_projectUiMessages`(`scenario_session.dart:160-162`)把所有 `role:'system'` 消息显式 `continue`——压缩提示 system 消息(含 `[上下文压缩]` 前缀的 LLM 提示文本)永远不会以气泡形式出现
- `_handleCompaction`(`scenario_session.dart:1145-1166`)只 `_state.copyWith(messages: _uiMessages)`,不设置任何压缩状态字段
- `CompactionEvent.description`(「已压缩上下文:N 字符…」)**只被 log 用,从不渲染**
- `agent_chat_dialog.dart` / `agent_message_bubble.dart` 全文 grep `compact|compaction` 零命中
- `SubagentStateProjector`(`subagent_state_projector.dart:173-175`)对 `CompactionEvent` 是 no-op

后果:用户在长会话里看到消息条数骤减,却不知道为什么——容易误以为是 bug 或丢数据。本日 P1 预剪枝让压缩语义从「只丢」变成「丢 + 改」两维,信息差更大。

### 1.2 目标

让用户在压缩发生时与发生后都能感知到:

1. **压缩发生的那一刻**:底部一次性 SnackBar,3 秒消失
2. **压缩发生的位置**:消息流内嵌分隔条,在「被裁剪的断点处」——位置即因果
3. **可展开看统计**:点开分隔条看 4 格统计 + 压缩率 + 不可回溯提示
4. **重启可见**:分隔条持久化到 DB,hydrate 后在原位可见

### 1.3 非目标(显式排除)

| 项 | 理由 |
|---|---|
| 查看被压缩内容 | 当前是简单截断 + 1-liner 改写,被丢/被改内容不在内存也不在 DB。支持查看需额外 shadow 备份(读 IO 翻倍)或 P2 LLM 摘要。用户决策:保持现状 |
| LLM 摘要替代截断 | P2 计划,与本设计正交。预剪枝层是 P2 前置(先把字符数降下来) |
| 多次压缩合并为计数 | 用户决策「每压缩一次插一条」——多条 marker 在消息流里自然呈现历史 |
| 改 `ChatMessage` 模型 / DB schema | v32 的 `chat_messages` 表已支持 `role='system'`,压缩提示作为 system 消息落库即可,零迁移 |
| 子 agent 压缩展示 | 子 agent 不跑 `compact`,marker 不会出现在子 agent 详情页;`SubagentStateProjector` 维持 no-op |
| marker 流式 segments | marker 是一次性快照(所有字段都在 DB 里),无「流式增长」概念 |

## 2. 设计决策一览(用户已确认)

| # | 决策 | 选项 | 用户选择 |
|---|---|---|---|
| D1 | 压缩信息出现在 UI 哪里? | A.消息流内嵌分隔条 / B.SnackBar 闪现 / C.输入栏常驻条 | **A**(消息流内嵌分隔条) |
| D2 | 分隔条样式? | M1.简洁单行 / M2.紧凑胶囊 / M3.可展开卡片 | **M3**(可展开卡片) |
| D3 | 重启可见性? | P1.持久化到 DB / P2.仅内存 | **P1**(持久落 DB) |
| D4 | 用户取向? | 面向所有人 / 面向 power user / 几乎隐形 | **面向所有人** |
| D5 | 瞬态提示? | 加一次性 SnackBar / 输入栏闪现 / 不加 | **加一次性 SnackBar** |
| D6 | 多次压缩? | 每插一条 / 合并计数 / 只留最新 | **每压缩一次插一条** |
| D7 | 查看被压内容? | 不支持 / 直接查看原文 / LLM 摘要 | **不支持(保持现状)** |
| D8 | `CompactionEvent` 补字段? | `compactedChars` + `rewrittenCount` | **补** |

## 3. 架构与数据流

### 3.1 核心原则:单一真理源 + 单一投影路径

压缩提示以 `role:'system'` 的**约定格式消息**作为唯一真理源:

- **运行时**(压缩刚发生)和 **hydrate** 时(App 重启还原)**都走同一个 `_projectUiMessages`**,避免两套逻辑漂移
- `CompactionEvent` 仍存在,但只服务于 ① 瞬时 SnackBar ② 日志 ③ `_handleCompaction` 内部决策;**marker 渲染不依赖事件**
- 不改 `ChatMessage` 模型、不改 DB schema(v32 system 角色已够用),全部用约定 content 前缀承载结构化数据

### 3.2 角色与文件改动一览

| 角色 | 文件 | 是否新增/改动 |
|---|---|---|
| 压缩触发与提示文本生成 | `services/novel_agent/context_compactor.dart` | **改**:`_buildCompactionNote` 改为「约定前缀 + KV + 自然语言」,被投影层与 LLM 双消费 |
| Agent 事件流 | `services/novel_agent/agent_event.dart` | **改**:`CompactionEvent` 补 `compactedChars` + `rewrittenContent.length`(已存在);`description` getter 补「改写 K 条」 |
| 内存处理 + 落库 | `core/providers/scenario_session.dart._handleCompaction` | **基本不动**:压缩提示已随 `compacted.messages` 进入 `_agentMessages`;现有 `removeRange + copyWith + _deleteAgentMessagesBeforeDb` 落库路径自动带上 |
| 内存 ↔ UI 投影 | `core/providers/scenario_session.dart._projectUiMessages` | **改**:`case 'system'` 分流——识别压缩提示前缀 → 生成 marker 角色条目;其余 system 仍 `continue` |
| 模型层 | `models/agent_chat_message.dart` | **改**:`AgentChatRole` 新增 `marker`;新增 `AgentChatMessage.compactionMarker(...)` 工厂;segmentsToJson/FromJson 新增 `type:'marker'` |
| Segment 类型 | `models/agent_chat_message.dart`(`AgentChatSegment` sealed) | **新增**:`CompactionMarkerSegment` 携带统计字段 |
| KV 解析工具 | `services/novel_agent/compaction_note_parser.dart`(新) | **新增**:解析 `[上下文压缩|...]` 前缀;null-tolerant |
| 渲染 | `widgets/agent_chat/compaction_marker_card.dart`(新) | **新增**:M3 可展开卡片 widget |
| 渲染 | `widgets/agent_chat/agent_chat_dialog.dart` | **改**:`itemBuilder` 加 `AgentChatRole.marker` 分支;`ref.listen<AgentEvent>` 监听 `CompactionEvent` 触发一次性 SnackBar |
| Hydrate | `core/providers/scenario_session.dart` 启动路径 | 不动,1:1 还原走同一投影函数 |

### 3.3 数据流总览

```
Round N 进入
  │
  ▼
agent_loop.dart:161  needsCompaction(messages) == true
  │
  ▼
ContextCompactor.compact(messages, systemPrompt)
  │  ├─ (新) P1 预剪枝:_pruneOldToolResults(改写老 tool result)
  │  ├─ 计算 splitIndex(含 tool_call 配对保护)
  │  ├─ 构造 compacted.messages = [systemPrompt, 压缩提示system, ...尾部]
  │  └─ 返回 CompactionResult { ..., rewrittenContent: [...] }
  │
  ▼
agent_loop 把 compacted.messages 写回 _agentMessages
  │  └─ 压缩提示 system 消息在 _agentMessages[1](系统 prompt 后)
  │
  ▼
agent_loop emit CompactionEvent(..., rewrittenContent: [...])
  │
  ├─ ref.listen<AgentEvent> 在 dialog 捕获 → showSnackBar(3s)
  │
  ▼
ScenarioSession._handleCompaction(e)   ←【基本不动】
  │  ① _agentMessages.removeRange(0, e.droppedAgentFromIndex)
  │     (压缩提示 system 已在头部,不被移除)
  │  ② (新语义)对 rewrittenContent 中 index>=cut 的 entry:
  │     _agentMessages[index - cut].content = entry.newContent
  │  ③ _state.copyWith(messages: _uiMessages)
  │     └─ _projectUiMessages(_agentMessages):
  │        ├─ systemPrompt        → continue
  │        ├─ 压缩提示system      → 解析前缀 → CompactionMarkerSegment → AgentChatRole.marker
  │        └─ 尾部消息           → user/assistant/tool 正常渲染
  │  ④ unawaited(_deleteAgentMessagesBeforeDb(cut))
  │     └─ clearMessages + 重写 _agentMessages
  │        压缩提示 + 改写后的 tool result 随重写一并落库 ✅
```

### 3.4 hydrate 路径(同一条投影路径)

```
App 启动 / 切 session
  │
  ▼
listMessages(sid) → List<ChatMessageRecord>
  │  含:systemPrompt、压缩提示 system、user/assistant/tool/...
  │
  ▼
record → ChatMessage → _agentMessages = [...]   ← 1:1 还原
  │
  ▼
_projectUiMessages(_agentMessages)  ← 与运行时同一函数
  │  └─ 压缩提示 system → marker(重启后可见 ✅)
  │
  ▼
_state.copyWith(messages: _uiMessages)
  │  └─ dialog itemBuilder 遇 AgentChatRole.marker → CompactionMarkerCard
```

### 3.5 边界场景

| 场景 | 行为 |
|---|---|
| **同一会话连续压缩 2 次** | `_selectSplitIndex` 跳过所有 system(含上一条压缩提示),不会把它计入字符预算;第 2 条 marker prepend 到头部 → 消息流出现 2 个 marker(符合 D6) |
| **压缩提示在配对保护边界** | 压缩提示在 `_agentMessages[0/1]`(头部),`_protectToolPairing` 只查尾部,互不干扰 |
| **rollback 到 marker 之前** | `rollbackToMessage` 按 user 消息定位,marker 不是 user 消息不会被选为回滚点;rollback 后 `_deleteAgentMessagesFromDb` 重写保留段——回滚点在 marker 之后 → marker 保留;之前 → marker 消失(回滚到「压缩前」状态合理) |
| **压缩提示 KV 解析失败** | 解析器返回 null → 投影层 `continue`,marker 不渲染,退化为现状(不崩) |
| **子 Agent 触发** | 子 agent 不跑 `compact`;`shouldMainSessionHandleEvent` 过滤;`SubagentStateProjector` 维持 no-op |
| **P1 预剪枝关闭** | `rewrittenContent` 为空列表,marker 展开态第 4 格只显示「M 条」不显示「其中 K 条改写」 |

## 4. 数据模型

### 4.1 新增 Segment 类型

```dart
/// models/agent_chat_message.dart
sealed class AgentChatSegment { ... }
class TextSegment           extends AgentChatSegment { ... }
class ToolCallSegment       extends AgentChatSegment { ... }
class ImageSegment          extends AgentChatSegment { ... }

/// 上下文压缩分隔条(v32+ UI 投影层引入)
///
/// 不进入 LLM(投影阶段已剥离,纯 UI 关注点)。
/// 字段镜像 [CompactionResult] 的统计 + 压缩率(用于 marker 展开卡片)。
class CompactionMarkerSegment extends AgentChatSegment {
  final int droppedMessageCount;
  final int keptMessageCount;
  final int removedChars;
  final int originalChars;
  final int compactedChars;
  final int rewrittenCount;    // [CompactionResult.rewrittenContent.length]
  final DateTime? timestamp;

  const CompactionMarkerSegment({
    required this.droppedMessageCount,
    required this.keptMessageCount,
    required this.removedChars,
    required this.originalChars,
    required this.compactedChars,
    this.rewrittenCount = 0,
    this.timestamp,
  });

  double get compressionRatio =>
      originalChars > 0 ? removedChars / originalChars : 0;
}
```

### 4.2 新增 Role 枚举值与 Message 工厂

```dart
/// models/agent_chat_message.dart
enum AgentChatRole {
  system,
  user,
  assistant,
  marker,  // ← 新增:压缩分隔条
}

class AgentChatMessage {
  // ... 现有 ...

  /// 创建压缩 marker 条目(agent_chat_dialog 用 role 分流渲染)
  factory AgentChatMessage.compactionMarker(CompactionMarkerSegment seg) {
    return AgentChatMessage(
      role: AgentChatRole.marker,
      segments: [seg],
      timestamp: seg.timestamp ?? DateTime.now(),
    );
  }
}
```

**为什么用 `AgentChatRole.marker` 而不是把 marker 挂在上一条 assistant 尾巴上?**

- 渲染简单,`itemBuilder` 用 role 分流
- 不动现有 `canRollback = role == user` 豁免逻辑(marker 不是 user,无回滚按钮天然正确)
- hydrate 路径与运行时走同一个 `_projectUiMessages`,无需特殊处理「选择宿主消息」

### 4.3 segments JSON 序列化扩展

`AgentChatMessage.segmentsToJson` / `segmentsFromJson` 新增分支:

```json
{ "type": "marker",
  "droppedCount": 23,
  "keptCount": 15,
  "removedChars": 420000,
  "originalChars": 580000,
  "compactedChars": 160000,
  "rewrittenCount": 8,
  "timestamp": 1706000101 }
```

向前兼容:旧 DB 无 marker 段,`segmentsFromJson` 现有"未知 type 跳过"逻辑天然安全。

### 4.4 压缩提示文本格式

`context_compactor.dart._buildCompactionNote` 改为:

```
[上下文压缩|droppedCount=23|keptCount=15|removedChars=420000|originalChars=580000|compactedChars=160000|rewrittenCount=8|timestamp=1706000101]
早期 23 条消息已被压缩移除。请基于保留的最近 15 条消息继续对话。如果缺少关键信息，请使用工具重新查询。
```

**关键设计点:**

- **约定前缀**:用与现有 `_buildCompactionNote` 一致的 `[上下文压缩|` 中文前缀,投影层 `startsWith('[上下文压缩|')` 单行匹配
- **KV 分隔**:用 `|`(不会出现在 LLM 自然语言里),保证不会误吞
- **自然语言行**保留原有提示语义,继续给 LLM 看
- **`timestamp`** 让 marker 在 DB 里按时间排序、对齐 hydrate 后顺序
- **`rewrittenCount`** 与 `rewrittenContent.length` 在 `compact()` 内同步写入(关键不变量 #5)

### 4.5 KV 解析器

新文件 `services/novel_agent/compaction_note_parser.dart`:

```dart
class CompactionNoteParser {
  static const _prefix = '[上下文压缩|';

  /// 解析压缩提示 system 消息的 KV 前缀。
  /// 任何字段缺失/类型异常都返回 null(由调用方降级为 continue)。
  static CompactionMarkerSegment? parse(String content) {
    if (!content.startsWith(_prefix)) return null;
    final bracketEnd = content.indexOf(']');
    if (bracketEnd < 0) return null;
    final kvBlock = content.substring(_prefix.length, bracketEnd);
    final lines = content.substring(bracketEnd + 1).trim();

    final kv = <String, String>{};
    for (final part in kvBlock.split('|')) {
      final eq = part.indexOf('=');
      if (eq < 0) continue;
      kv[part.substring(0, eq)] = part.substring(eq + 1);
    }

    int? intOrNull(String k) => int.tryParse(kv[k] ?? '');
    final dropped  = intOrNull('droppedCount');
    final kept     = intOrNull('keptCount');
    final removed  = intOrNull('removedChars');
    final original = intOrNull('originalChars');
    if ([dropped, kept, removed, original].any((v) => v == null)) {
      return null;  // 必填字段缺失 → 降级
    }
    return CompactionMarkerSegment(
      droppedMessageCount: dropped!,
      keptMessageCount: kept!,
      removedChars: removed!,
      originalChars: original!,
      compactedChars: intOrNull('compactedChars') ?? (original - removed),
      rewrittenCount: intOrNull('rewrittenCount') ?? 0,
      timestamp: intOrNull('timestamp')?.let((ms) => DateTime.fromMillisecondsSinceEpoch(ms)),
    );
  }
}
```

### 4.6 `CompactionEvent` 字段扩展

`agent_event.dart`:

```dart
class CompactionEvent extends AgentEvent {
  // 现有字段
  final int removedChars;
  final int originalChars;
  final int keptMessageCount;
  final int droppedMessageCount;
  final int droppedAgentFromIndex;
  final List<RewrittenEntry> rewrittenContent;

  // 新增
  final int compactedChars;     // 新增:[CompactionResult.compactedChars]
  // rewrittenCount 由 rewrittenContent.length 派生,但显式写在 description getter 里

  const CompactionEvent({
    required this.removedChars,
    required this.originalChars,
    required this.compactedChars,           // ← 新增必填
    required this.keptMessageCount,
    required this.droppedMessageCount,
    required this.droppedAgentFromIndex,
    this.rewrittenContent = const [],
    super.runId,
  });

  String get description => '已压缩上下文:${removedChars ~/ 1000}K 字符 '
      '(保留 $keptMessageCount 条,丢弃 $droppedMessageCount 条'
      '${rewrittenContent.isEmpty ? "" : ",改写 ${rewrittenContent.length} 条"})';
}
```

`compact()` 处构造 CompactionEvent 多带一个 `compactedChars` 参数(从 `CompactionResult.compactedChars` 来);`agent_loop.dart:130-200` 的 emit 段同步更新(见 §5.2)。

### 4.7 字段对齐表

| 字段 | CompactionResult | CompactionEvent | KV 文本 | CompactionMarkerSegment |
|---|---|---|---|---|
| droppedCount | `droppedMessageCount` | `droppedMessageCount` | `droppedCount` | `droppedMessageCount` |
| keptCount | `keptMessageCount` | `keptMessageCount` | `keptCount` | `keptMessageCount` |
| removedChars | `removedChars` | `removedChars` | `removedChars` | `removedChars` |
| originalChars | `originalChars` | `originalChars` | `originalChars` | `originalChars` |
| compactedChars | `compactedChars` | **`compactedChars` ←新增** | `compactedChars` | `compactedChars` |
| rewrittenCount | `rewrittenContent.length` | `rewrittenContent.length` | `rewrittenCount` | `rewrittenCount` |
| droppedAgentFromIndex | `droppedAgentFromIndex` | `droppedAgentFromIndex` | — | — |
| timestamp | — | — | `timestamp` | `timestamp` |

## 5. 组件与渲染

### 5.1 新 widget:`CompactionMarkerCard`

新文件 `widgets/agent_chat/compaction_marker_card.dart`:

```dart
class CompactionMarkerCard extends StatefulWidget {
  final CompactionMarkerSegment segment;
  const CompactionMarkerCard({super.key, required this.segment});

  @override
  State<CompactionMarkerCard> createState() => _CompactionMarkerCardState();
}

class _CompactionMarkerCardState extends State<CompactionMarkerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.segment;
    final colors = context.appColors;     // 项目主题色,不写死
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 折叠态:居中,渐变背景,圆角边框,整行可点
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.agentCardTop, colors.agentCardBottom],
              ),
              border: Border.all(color: colors.agentMarkerBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🗂', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      '上下文已压缩 · 丢弃 ${s.droppedMessageCount} 条'
                      '${_expanded ? '' : '  ▾'}',
                      style: TextStyle(color: colors.ink, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 展开态:4 格统计 + 压缩率条 + 不可回溯提示,AnimatedSize 过渡
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _expanded ? _buildExpanded(context, s) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded(BuildContext context, CompactionMarkerSegment s) {
    // 4 格统计(含 rewrittenCount 显示)
    return Container(/* ... */ child: Column(
      children: [
        Wrap(spacing: 14, runSpacing: 6, children: [
          _stat('释放字符', _format(s.removedChars)),
          _stat('压缩前 → 后', '${_format(s.originalChars)} → ${_format(s.compactedChars)}'),
          _stat('丢弃消息', '${s.droppedMessageCount} 条'),
          _stat('保留消息',
              '${s.keptMessageCount} 条'
              '${s.rewrittenCount > 0 ? " (其中 ${s.rewrittenCount} 条 tool result 被改写)" : ""}'),
        ]),
        // 压缩率条
        Row(/* 压缩率% + LinearProgressIndicator */),
        // 不可回溯说明
        Text(
          s.rewrittenCount > 0
              ? '被压缩/改写的内容不可回溯(预剪枝 1-liner 仅保留结构化摘要)'
              : '被压缩内容不可回溯(当前是简单截断,未生成摘要)',
          /* ... */
        ),
      ],
    ));
  }
}
```

### 5.2 `agent_chat_dialog.dart` 改动

**(a) `itemBuilder` 加 marker 分支**

```dart
itemBuilder: (context, index) {
  if (index == chatState.messages.length && chatState.isLoading) {
    // 流式末尾气泡(不变)
    return AgentMessageBubble(
      message: AgentChatMessage(role: AgentChatRole.assistant),
      streamingSegments: chatState.streamingSegments,
      showTimestamp: false,
    );
  }

  final message = chatState.messages[index];
  switch (message.role) {
    case AgentChatRole.marker:    // ← 新分支
      return CompactionMarkerCard(
        segment: message.segments.first as CompactionMarkerSegment,
      );
    case AgentChatRole.user:
    case AgentChatRole.assistant:
      final canRollback = message.role == AgentChatRole.user;
      return AgentMessageBubble(
        message: message,
        onRollback: canRollback ? () => _handleRollback(index) : null,
      );
  }
}
```

**(b) `ref.listen` 接 `CompactionEvent` → SnackBar**

```dart
ref.listen<AgentEvent>(agentService.eventsProvider, (prev, next) {
  if (next is CompactionEvent) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(
      content: Text('🗂 ${next.description}'),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ));
  }
});
```

> **实施注意**:dialog 用 `showDialog` 弹出,需在 `Builder` 或 `StatefulWidget` 内 `BuildContext` 拿 messenger。 `ScaffoldMessenger.maybeOf` 失败时静默,不崩。

### 5.3 关键视觉决策的代码锁定

| 决策 | 代码位置 |
|---|---|
| 默认折叠 | `_expanded = false`(新 widget) |
| 折叠态整行可点 | 整 `InkWell` onTap,无嵌套歧义 |
| 展开用 `AnimatedSize` 过渡 | 180ms easeOut |
| marker 无回滚按钮 | `canRollback = role == user` 自然豁免 marker |
| marker 不进 bubble | `_buildAssistantContent` switch 不动,marker 走 `CompactionMarkerCard` 自渲染 |
| 不可回溯文案 | 区分 `rewrittenCount > 0` 两种文案 |

### 5.4 复用与不改动

- `agent_message_bubble.dart` **不动**——marker 不进 bubble
- `AgentMessageBubble` 的 `streamingSegments` 参数对 marker 始终为 `null`,无需特殊处理
- `SubagentStateProjector` **不动**——子 agent 不跑 `compact`

## 6. 错误处理

| 失败点 | 处理 | 用户可见 |
|---|---|---|
| KV 文本损坏 | `CompactionNoteParser.parse` 返回 null → 投影层 `continue`,marker 不渲染 | 退化为无 marker(不崩) |
| `rewrittenCount` 字段缺失(旧 DB hydrate) | `??= 0`,展开第 4 格显示「M 条(其中 0 条改写)」 | 不崩 |
| `timestamp` 字段缺失 | marker 不显示时间副标 | 不崩 |
| `compactedChars` 字段缺失 | 派生 `original - removed` | 不崩 |
| `CompactionEvent` 落库失败(已有 `_deleteAgentMessagesBeforeDb` catch) | 已有 try/log,内存 marker 仍可见,重启 marker 缺失 | 与现状不一致行为一致 |
| dialog 无 ScaffoldMessenger ancestor | `ScaffoldMessenger.maybeOf` 失败,SnackBar 静默不弹 | 丢瞬时,marker 仍渲染 |
| 子 Agent 误触发 CompactionEvent | `shouldMainSessionHandleEvent` 过滤;`SubagentStateProjector` no-op | 不影响 |
| 同一会话压缩 2 次,第 1 条 marker KV 损坏 | 第 1 条降级 continue 不渲染,第 2 条正常 | 部分降级 |

## 7. 测试策略

### 7.1 测试矩阵

| 测试 | 文件 | 覆盖点 |
|---|---|---|
| **KV 格式** | `context_compactor_test.dart`(扩) | `_buildCompactionNote` 产出 KV 行 + 自然语言行;`rewrittenCount` 字段在 `prePruneEnabled=false` 时为 0 |
| **KV 解析** | `compaction_note_parser_test.dart`(新) | 正常解析全字段;缺 `rewrittenCount` → 0;缺 `timestamp` → null;缺 `compactedChars` → 派生;坏前缀 → null;自然语言行存在不影响解析 |
| **投影分流** | `scenario_session_projection_test.dart`(扩) | system 带压缩前缀 → `AgentChatRole.marker`;普通 system → continue;多条 marker 并存;KV 损坏 → continue 不崩 |
| **segments JSON** | `agent_chat_message_test.dart`(扩) | `type:'marker'` 往返;旧 DB 无 marker 段 → 不崩 |
| **`_handleCompaction`** | `scenario_session_test.dart`(扩) | `_agentMessages[0/1]` 是 system + 压缩提示;`_deleteAgentMessagesBeforeDb` 后 marker 落库;`rewrittenContent` 平移写入正确 |
| **marker 折叠/展开** | `compaction_marker_card_test.dart`(新) | 默认折叠;点击展开;4 格统计显示;`rewrittenCount=0` 时第 4 格不显示「其中 K 条」;展开「不可回溯」文案两种分支 |
| **dialog itemBuilder 分流** | `agent_chat_dialog_test.dart`(扩) | marker role → `CompactionMarkerCard`;user → bubble + 回滚按钮;marker 不渲染回滚按钮 |
| **SnackBar 触发** | `agent_chat_dialog_test.dart`(扩) | `CompactionEvent` → SnackBar 出现 3s;同一会话连续 2 次 → 2 次 SnackBar |
| **hydrate 后 marker** | `scenario_session_hydrate_test.dart`(扩) | 写入含 marker 的 DB → hydrate → `_uiMessages` 含 marker → itemBuilder 渲染 marker |
| **rollback 与 marker** | `scenario_session_rollback_test.dart`(扩) | 回滚点在 marker 之后 → 保留;之前 → marker 随重写消失 |

### 7.2 关键不变量(测试锁定)

1. 压缩提示的 `agentMsgIndex` 在 DB 重写后 = 1(紧随 systemPrompt)
2. `_selectSplitIndex` 跳过所有 system 消息(含压缩提示),不会把它计入 `preserveTailChars` 预算
3. **marker 渲染不依赖 `CompactionEvent`** —— 删掉 emit 也能从 DB hydrate 出 marker
4. 内存路径与 hydrate 路径走**同一个** `_projectUiMessages`
5. `rewrittenCount` 与 `rewrittenContent.length` 在 `compact()` 时同步写入,永远一致
6. `CompactionMarkerSegment.rewrittenCount == 0` 时,marker 展开第 4 格不展示「改写 K 条」,不可回溯文案走 v32 分支

### 7.3 不做(YAGNI)

- 不支持查看被压内容(D7 决策)
- 不做 marker 合并/计数(D6)
- 不改 `ChatMessage` 模型、不改 DB schema
- 不做 LLM 摘要(P2,与本设计正交)
- 不为 marker 加流式 segments

## 8. 实施拆分建议(供 writing-plans 用)

按改动面与依赖关系,推荐下列顺序:

1. **数据模型与序列化**:新增 `CompactionMarkerSegment`、`AgentChatRole.marker`、`AgentChatMessage.compactionMarker`、`segmentsToJson/FromJson` marker 分支(无 UI 影响)
2. **KV 文本与解析器**:改 `_buildCompactionNote`、新增 `CompactionNoteParser`、单测
3. **`CompactionEvent` 字段**:补 `compactedChars`、更新 `description`、`agent_loop` emit 处同步、配套单测
4. **投影层分流**:改 `_projectUiMessages` `case 'system'`、单测
5. **hydrate 测试**:DB 写入 marker → hydrate 还原 → 投影层识别的集成测试
6. **marker 渲染 widget**:新文件 `compaction_marker_card.dart` + widget test
7. **dialog itemBuilder 分支**:接 marker widget、widget test
8. **SnackBar**:dialog 内 `ref.listen<AgentEvent>` + `ScaffoldMessenger.maybeOf`、widget test
9. **回归测试**:rollback、连续压缩、子 Agent、KV 损坏降级
