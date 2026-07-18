# 上下文压缩 UI 展示 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让 Agent Chat 用户能在 UI 上感知上下文压缩——一次性 SnackBar + 消息流内嵌可展开分隔条（M3）+ 持久落库重启可见。

**架构：** 压缩提示以 `role:'system'` 的"约定前缀 + KV + 自然语言"系统消息作为唯一真理源；运行时压缩路径与 hydrate 重启路径走同一个 `_projectUiMessages` 投影层，两条路径不会漂移。marker 渲染不依赖 `CompactionEvent`（事件只管 SnackBar + 日志）。

**技术栈：** Flutter / Dart / Riverpod / sqflite（novel_app）

**规格：** `docs/superpowers/specs/2026-07-18-context-compaction-ui-design.md`

---

## ⚠️ 实现者必读：索引语义与前置核实

在动任何代码前，必须理解以下现状（写计划时已核实，但实现者需独立验证）：

| 事实 | 证据 |
|---|---|
| `_agentMessages`（ScenarioSession 真理源）**不含** sys_prompt | `novel_agent_service.dart:183-186` 构造 `initialMessages` 只含 history + user；`scenario_session.dart:406/1115` 只 add user/assistant |
| agent_loop 本地 `messages` **含** sys_prompt（头部 prepend） | `agent_loop.dart:119-122` |
| `compact()` 的 messages 参数以 sys_prompt 开头 | `context_compactor_test.dart:70/97/129` 测试构造；agent_loop.dart:169-172 传 `messages: messages` |
| `droppedAgentFromIndex = splitIndex`，基于"含 sys_prompt 的 messages"索引 | `context_compactor.dart:242` |
| `_handleCompaction` 用 `cut = droppedAgentFromIndex` 对"不含 sys_prompt 的 _agentMessages"做 `removeRange(0, cut)` | `scenario_session.dart:1156/1168` |

**潜在 off-by-one：** `splitIndex`（含 sys_prompt 基底）与 `_agentMessages`（不含 sys_prompt 基底）存在 1 的偏移。现有代码 `removeRange(0, cut)` 直接用 cut，可能有错位。**Task 0 用真实数据验证此偏移是否已存在 bug**——若已存在且影响 marker 插入位置的正确性，先修；若现有 P1 测试覆盖说明已对齐（可能 compact 内部有我没看到的调整），则按现状推进。无论如何，Task 0 的结论决定 Task 4/5 的精确索引。

## 文件结构

| 文件 | 职责 | 动作 |
|---|---|---|
| `novel_app/lib/models/agent_chat_message.dart` | `AgentChatSegment` sealed + `AgentChatRole` enum + segmentsJson | 改 |
| `novel_app/lib/services/novel_agent/compaction_note_parser.dart` | 解析 `[上下文压缩\|...]` KV 前缀 | 新建 |
| `novel_app/lib/services/novel_agent/context_compactor.dart` | `_buildCompactionNote` 改 KV 格式 | 改 |
| `novel_app/lib/services/novel_agent/agent_event.dart` | `CompactionEvent` 加 `compactedChars` + `compactionNote` 字段 | 改 |
| `novel_app/lib/services/novel_agent/agent_loop.dart` | emit 处补传新字段 | 改 |
| `novel_app/lib/core/providers/scenario_session.dart` | `_handleCompaction` insert 压缩提示；`_projectUiMessages` system 分流 | 改 |
| `novel_app/lib/widgets/agent_chat/compaction_marker_card.dart` | M3 可展开卡片 | 新建 |
| `novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart` | itemBuilder marker 分支 + ref.listen SnackBar | 改 |

测试文件见各任务。

---

## 任务 0：前置索引核实（阻塞后续）

**目的：** 确定 Task 4/5 的精确插入索引，避免基于错误假设实现。

**文件：**
- 检查：`novel_app/lib/services/novel_agent/context_compactor.dart:182-271`
- 检查：`novel_app/lib/core/providers/scenario_session.dart:1154-1200`
- 检查：`novel_app/test/unit/services/novel_agent/context_compactor_test.dart`

- [ ] **步骤 1：阅读 `_selectSplitIndex` 与 `_handleCompaction` 全文**

确认 `splitIndex` 的返回值基底（messages 含 sys_prompt）与 `_agentMessages.removeRange(0, cut)` 的基底（不含 sys_prompt）是否需要对齐。重点看 `compact()` 内是否有 `splitIndex - 1` 之类的偏移修正（grep `splitIndex`、`droppedAgentFromIndex`）。

- [ ] **步骤 2：跑现有 compaction 测试**

运行：`cd novel_app && flutter test test/unit/services/novel_agent/context_compactor_test.dart`
预期：全 PASS。记录 `droppedAgentFromIndex` 在用例中的实际值，与"含 sys_prompt 基底"对照。

- [ ] **步骤 3：写一个断言索引对齐的临时测试**

在 `test/unit/services/novel_agent/context_compactor_test.dart` 末尾加：

```dart
test('droppedAgentFromIndex 与不含 sys_prompt 的 history 索引对齐', () {
  final compactor = ContextCompactor(
    config: const CompactorConfig(maxContextChars: 1000, preserveTailChars: 200),
  );
  const systemPrompt = 'sys';
  // history 不含 sys_prompt（模拟 _agentMessages）
  final history = <ChatMessage>[
    for (int i = 0; i < 5; i++) ChatMessage(role: 'user', content: 'msg_$i ${'x' * 200}'),
  ];
  final messages = <ChatMessage>[
    ChatMessage(role: 'system', content: systemPrompt),
    ...history,
  ];
  final result = compactor.compact(messages: messages, systemPrompt: systemPrompt);
  // 若 droppedAgentFromIndex 直接用于 history.removeRange(0, cut)，
  // 则 result.messages 中保留段的首条应 == history[cut]（history 基底）
  // 而非 messages[cut]（含 sys_prompt 基底）。本测试断言对齐基底。
  final keptHead = result.messages.skip(2).first; // 跳过 sys_prompt + 压缩提示
  // 断言 keptHead 在 history 中的位置
  final histIdx = history.indexOf(keptHead);
  expect(histIdx, result.droppedAgentFromIndex,
      reason: 'droppedAgentFromIndex 应基于 history（不含 sys_prompt）基底');
});
```

- [ ] **步骤 4：运行并记录结论**

运行：`flutter test test/unit/services/novel_agent/context_compactor_test.dart -p vm --plain-name "droppedAgentFromIndex"`
预期：**FAIL**（已知结论）。

**确定的结论（无需再现场判断）：** `_selectSplitIndex`(`context_compactor.dart:205-243`) 返回的 splitIndex 基于 `pruned.messages`（含 sys_prompt 头部），而 `_agentMessages`（`scenario_session.dart`）不含 sys_prompt。因此 `droppedAgentFromIndex` 是「含 sys_prompt 基底」的索引，与 `_agentMessages` 基底存在 off-by-one。

**对本计划的影响：**
- **marker 插入不受影响**——Task 4 永远用 `_agentMessages.insert(0, ...)`，头部位置与 cut 索引无关。
- **P1 改写平移（`newIdx = entry.index - cut`，`scenario_session.dart:1176`）可能也是 pre-existing bug**，但它是 2026-07-18 P1 提交引入的、与「压缩 UI」正交的问题。**本计划不修**（范围外），若 Task 9 回归测试发现改写错位，单独记 issue。删除临时测试，不 commit。

- [ ] **步骤 5：记录结论到本计划 Task 4 注释**

不 commit（临时测试已删）。

---

## 任务 1：数据模型——CompactionMarkerSegment + AgentChatRole.marker

**文件：**
- 修改：`novel_app/lib/models/agent_chat_message.dart`
- 测试：`novel_app/test/unit/models/agent_chat_message_test.dart`（若不存在则新建）

- [ ] **步骤 1：编写失败的测试**

```dart
// test/unit/models/agent_chat_message_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/agent_chat_message.dart';

void main() {
  group('CompactionMarkerSegment', () {
    test('segmentsToJson/FromJson 往返 marker 段', () {
      final seg = const CompactionMarkerSegment(
        droppedMessageCount: 23,
        keptMessageCount: 15,
        removedChars: 420000,
        originalChars: 580000,
        compactedChars: 160000,
        rewrittenCount: 8,
      );
      final msg = AgentChatMessage.compactionMarker(seg);
      final json = AgentChatMessage.segmentsToJson(msg.segments);
      final restored = AgentChatMessage.segmentsFromJson(json);
      expect(restored, hasLength(1));
      final r = restored.single as CompactionMarkerSegment;
      expect(r.droppedMessageCount, 23);
      expect(r.keptMessageCount, 15);
      expect(r.removedChars, 420000);
      expect(r.originalChars, 580000);
      expect(r.compactedChars, 160000);
      expect(r.rewrittenCount, 8);
    });

    test('compactionMarker 工厂 role == AgentChatRole.marker', () {
      final msg = AgentChatMessage.compactionMarker(const CompactionMarkerSegment(
        droppedMessageCount: 1, keptMessageCount: 1,
        removedChars: 10, originalChars: 20, compactedChars: 10,
      ));
      expect(msg.role, AgentChatRole.marker);
    });

    test('旧 DB 无 marker 段不崩', () {
      // 模拟只有 text 段的旧数据
      final json = '[{"type":"text","content":"hi"}]';
      final segs = AgentChatMessage.segmentsFromJson(json);
      expect(segs, hasLength(1));
      expect(segs.single, isA<TextSegment>());
    });
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`cd novel_app && flutter test test/unit/models/agent_chat_message_test.dart`
预期：FAIL，报错 `CompactionMarkerSegment` / `AgentChatRole.marker` / `compactionMarker` 未定义。

- [ ] **步骤 3：实现 model**

在 `lib/models/agent_chat_message.dart`：

(a) `AgentChatRole` 加值：
```dart
enum AgentChatRole {
  system,
  user,
  assistant,
  marker, // ← 新增
}
```

(b) `AgentChatSegment` sealed 加子类：
```dart
/// 上下文压缩分隔条（UI 投影层引入，不进 LLM）。
class CompactionMarkerSegment extends AgentChatSegment {
  final int droppedMessageCount;
  final int keptMessageCount;
  final int removedChars;
  final int originalChars;
  final int compactedChars;
  final int rewrittenCount;
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

(c) `AgentChatMessage` 加工厂：
```dart
factory AgentChatMessage.compactionMarker(CompactionMarkerSegment seg) {
  return AgentChatMessage(
    role: AgentChatRole.marker,
    segments: [seg],
    timestamp: seg.timestamp ?? DateTime.now(),
  );
}
```

(d) `segmentsToJson` 加分支（在 ImageSegment 分支后）：
```dart
if (s is CompactionMarkerSegment) {
  return {
    'type': 'marker',
    'droppedCount': s.droppedMessageCount,
    'keptCount': s.keptMessageCount,
    'removedChars': s.removedChars,
    'originalChars': s.originalChars,
    'compactedChars': s.compactedChars,
    'rewrittenCount': s.rewrittenCount,
    if (s.timestamp != null)
      'timestamp': s.timestamp!.millisecondsSinceEpoch,
  };
}
```

(e) `segmentsFromJson` 加分支（在 image 分支后）：
```dart
} else if (type == 'marker') {
  final ts = item['timestamp'];
  result.add(CompactionMarkerSegment(
    droppedMessageCount: item['droppedCount'] as int? ?? 0,
    keptMessageCount: item['keptCount'] as int? ?? 0,
    removedChars: item['removedChars'] as int? ?? 0,
    originalChars: item['originalChars'] as int? ?? 0,
    compactedChars: item['compactedChars'] as int? ?? 0,
    rewrittenCount: item['rewrittenCount'] as int? ?? 0,
    timestamp: ts is int
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : null,
  ));
}
```

(f) `toJson` / `fromJson` / `fromMap` 的 role switch 加 `marker` case（降级为 user 防御坏数据，但 marker 不应经此路径——marker 段走 segmentsJson）：
```dart
// fromJson role switch 加：
case 'marker':
  role = AgentChatRole.marker; // 注意：marker 消息的真正数据在 segmentsJson
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/unit/models/agent_chat_message_test.dart`
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add novel_app/lib/models/agent_chat_message.dart novel_app/test/unit/models/agent_chat_message_test.dart
git commit -m "@feat(agent): CompactionMarkerSegment + AgentChatRole.marker 数据模型

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 任务 2：KV 文本格式 + CompactionNoteParser

**文件：**
- 修改：`novel_app/lib/services/novel_agent/context_compactor.dart`（`_buildCompactionNote`）
- 创建：`novel_app/lib/services/novel_agent/compaction_note_parser.dart`
- 测试：`novel_app/test/unit/services/novel_agent/compaction_note_parser_test.dart`

- [ ] **步骤 1：编写解析器失败测试**

```dart
// test/unit/services/novel_agent/compaction_note_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/novel_agent/compaction_note_parser.dart';

void main() {
  group('CompactionNoteParser', () {
    const full = '[上下文压缩|droppedCount=23|keptCount=15|removedChars=420000|'
        'originalChars=580000|compactedChars=160000|rewrittenCount=8|timestamp=1706000101]\n'
        '早期 23 条消息已被压缩移除。请基于保留的最近 15 条消息继续对话。';

    test('解析全字段', () {
      final seg = CompactionNoteParser.parse(full)!;
      expect(seg.droppedMessageCount, 23);
      expect(seg.keptMessageCount, 15);
      expect(seg.removedChars, 420000);
      expect(seg.originalChars, 580000);
      expect(seg.compactedChars, 160000);
      expect(seg.rewrittenCount, 8);
      expect(seg.timestamp, isNotNull);
    });

    test('缺 rewrittenCount → 0', () {
      final seg = CompactionNoteParser.parse(
        '[上下文压缩|droppedCount=1|keptCount=1|removedChars=10|'
        'originalChars=20|compactedChars=10]\n后续。')!;
      expect(seg.rewrittenCount, 0);
    });

    test('缺 timestamp → null', () {
      final seg = CompactionNoteParser.parse(
        '[上下文压缩|droppedCount=1|keptCount=1|removedChars=10|'
        'originalChars=20|compactedChars=10]\n后续。')!;
      expect(seg.timestamp, isNull);
    });

    test('缺 compactedChars → 派生 original - removed', () {
      final seg = CompactionNoteParser.parse(
        '[上下文压缩|droppedCount=1|keptCount=1|removedChars=10|'
        'originalChars=30]\n后续。')!;
      expect(seg.compactedChars, 20);
    });

    test('坏前缀 → null', () {
      expect(CompactionNoteParser.parse('普通 system 消息'), isNull);
      expect(CompactionNoteParser.parse('[上下文压缩] 早期...'), isNull); // 注意是 ] 不是 |
    });

    test('缺必填字段 → null', () {
      expect(CompactionNoteParser.parse(
        '[上下文压缩|droppedCount=1|keptCount=1|removedChars=10]\n后续。'), isNull);
    });
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`cd novel_app && flutter test test/unit/services/novel_agent/compaction_note_parser_test.dart`
预期：FAIL，`compaction_note_parser.dart` 不存在。

- [ ] **步骤 3：创建解析器**

`lib/services/novel_agent/compaction_note_parser.dart`：
```dart
import '../../models/agent_chat_message.dart';

/// 解析 ContextCompactor 注入的压缩提示 system 消息（约定前缀 + KV）。
///
/// 格式见规格 §4.4：
/// [上下文压缩|droppedCount=23|keptCount=15|...|timestamp=1706000101]
/// 自然语言行（给 LLM 看）
///
/// 任何字段缺失/格式异常返回 null（调用方降级为 continue，不渲染 marker）。
class CompactionNoteParser {
  static const _prefix = '[上下文压缩|';

  static CompactionMarkerSegment? parse(String content) {
    if (!content.startsWith(_prefix)) return null;
    final bracketEnd = content.indexOf(']');
    if (bracketEnd < 0) return null;

    final kvBlock = content.substring(_prefix.length, bracketEnd);
    final kv = <String, String>{};
    for (final part in kvBlock.split('|')) {
      final eq = part.indexOf('=');
      if (eq < 0) continue;
      kv[part.substring(0, eq)] = part.substring(eq + 1);
    }

    int? intOrNull(String k) => int.tryParse(kv[k] ?? '');

    final dropped = intOrNull('droppedCount');
    final kept = intOrNull('keptCount');
    final removed = intOrNull('removedChars');
    final original = intOrNull('originalChars');
    // 必填字段缺失 → 降级
    if ([dropped, kept, removed, original].any((v) => v == null)) return null;

    final compacted = intOrNull('compactedChars') ?? (original! - removed!);
    final tsMs = intOrNull('timestamp');

    return CompactionMarkerSegment(
      droppedMessageCount: dropped!,
      keptMessageCount: kept!,
      removedChars: removed!,
      originalChars: original,
      compactedChars: compacted,
      rewrittenCount: intOrNull('rewrittenCount') ?? 0,
      timestamp: tsMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(tsMs),
    );
  }
}
```

- [ ] **步骤 4：运行解析器测试验证通过**

运行：`flutter test test/unit/services/novel_agent/compaction_note_parser_test.dart`
预期：PASS。

- [ ] **步骤 5：改 `_buildCompactionNote` 输出 KV 格式**

`context_compactor.dart` 当前 `_buildCompactionNote(int droppedCount, int totalCount)`：
```dart
String _buildCompactionNote(int droppedCount, int totalCount) {
  return '[上下文压缩] 早期 $droppedCount 条消息已被压缩移除。'
      '请基于保留的最近 ${totalCount - droppedCount} 条消息继续对话。'
      '如果缺少关键信息，请使用工具重新查询。';
}
```

改为接收完整统计（签名扩展）：
```dart
/// 构建压缩提示消息（KV 前缀 + 自然语言）。
///
/// KV 行供 [CompactionNoteParser] 解析还原 marker 统计；
/// 自然语言行继续给 LLM 看（业务语义不变）。
String _buildCompactionNote({
  required int droppedCount,
  required int keptCount,
  required int removedChars,
  required int originalChars,
  required int compactedChars,
  required int rewrittenCount,
}) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  return '[上下文压缩|droppedCount=$droppedCount|keptCount=$keptCount|'
      'removedChars=$removedChars|originalChars=$originalChars|'
      'compactedChars=$compactedChars|rewrittenCount=$rewrittenCount|timestamp=$ts]\n'
      '早期 $droppedCount 条消息已被压缩移除。'
      '请基于保留的最近 $keptCount 条消息继续对话。'
      '如果缺少关键信息，请使用工具重新查询。';
}
```

更新 `compact()` 内调用（`context_compactor.dart:212-215`）：
```dart
ChatMessage(
  role: 'system',
  content: _buildCompactionNote(
    droppedCount: droppedCount,
    keptCount: keptCount,
    removedChars: originalChars - compactedChars,
    originalChars: originalChars,
    compactedChars: compactedChars,
    rewrittenCount: pruned.rewrittenContent.length,
  ),
),
```

注意：`originalChars` / `compactedChars` / `keptCount` / `droppedCount` 在 `compact()` 内 line 220-223 已计算，需把这些变量声明提前到构造压缩提示之前（当前它们在构造 compacted 列表之后计算，需上移）。

- [ ] **步骤 6：更新现有 compaction 测试断言**

`context_compactor_test.dart:84-85` 当前断言 `result.messages[1].content` contains `'[上下文压缩]'`（旧格式 `]`）。改为断言新格式 `'[上下文压缩|'`：
```dart
expect(result.messages[1].content, contains('[上下文压缩|'));
```

- [ ] **步骤 7：运行全部 compaction 测试验证通过**

运行：`flutter test test/unit/services/novel_agent/context_compactor_test.dart test/unit/services/novel_agent/compaction_note_parser_test.dart`
预期：PASS。

- [ ] **步骤 8：Commit**

```bash
git add novel_app/lib/services/novel_agent/compaction_note_parser.dart \
        novel_app/lib/services/novel_agent/context_compactor.dart \
        novel_app/test/unit/services/novel_agent/compaction_note_parser_test.dart \
        novel_app/test/unit/services/novel_agent/context_compactor_test.dart
git commit -m "@feat(agent): 压缩提示 KV 格式 + CompactionNoteParser 解析器

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 任务 3：CompactionEvent 补字段

**文件：**
- 修改：`novel_app/lib/services/novel_agent/agent_event.dart`
- 修改：`novel_app/lib/services/novel_agent/agent_loop.dart`（emit 处）
- 测试：`novel_app/test/unit/services/novel_agent/agent_event_test.dart`（若不存在新建）

- [ ] **步骤 1：编写失败测试**

```dart
// test/unit/services/novel_agent/agent_event_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/novel_agent/agent_event.dart';

void main() {
  group('CompactionEvent', () {
    test('description 含改写数（rewrittenContent 非空）', () {
      final e = CompactionEvent(
        removedChars: 420000,
        originalChars: 580000,
        compactedChars: 160000,
        keptMessageCount: 15,
        droppedMessageCount: 23,
        droppedAgentFromIndex: 23,
        compactionNote: '[上下文压缩|...]\n后续。',
        rewrittenContent: const [
          (index: 25, newContent: 'x'),
          (index: 26, newContent: 'y'),
        ],
      );
      expect(e.description, contains('改写 2 条'));
      expect(e.description, contains('丢弃 23 条'));
    });

    test('description 无改写时不提改写', () {
      final e = CompactionEvent(
        removedChars: 100, originalChars: 200, compactedChars: 100,
        keptMessageCount: 1, droppedMessageCount: 1, droppedAgentFromIndex: 1,
        compactionNote: '[上下文压缩|...]\n后续。',
      );
      expect(e.description, isNot(contains('改写')));
    });
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`cd novel_app && flutter test test/unit/services/novel_agent/agent_event_test.dart`
预期：FAIL，`compactedChars` / `compactionNote` 命名参数不存在。

- [ ] **步骤 3：改 CompactionEvent**

`agent_event.dart` `CompactionEvent` 类：
```dart
class CompactionEvent extends AgentEvent {
  final int removedChars;
  final int originalChars;
  final int compactedChars;              // ← 新增
  final int keptMessageCount;
  final int droppedMessageCount;
  final int droppedAgentFromIndex;
  final String compactionNote;           // ← 新增：KV 文本，透传给 ScenarioSession 落库
  final List<RewrittenEntry> rewrittenContent;

  const CompactionEvent({
    required this.removedChars,
    required this.originalChars,
    required this.compactedChars,
    required this.keptMessageCount,
    required this.droppedMessageCount,
    required this.droppedAgentFromIndex,
    required this.compactionNote,
    this.rewrittenContent = const [],
    super.runId,
  });

  double get compressionRatio =>
      originalChars > 0 ? removedChars / originalChars : 0;

  String get description => '已压缩上下文：${removedChars ~/ 1000}K 字符'
      '（保留 $keptMessageCount 条，丢弃 $droppedMessageCount 条'
      '${rewrittenContent.isEmpty ? "" : "，改写 ${rewrittenContent.length} 条"}）';
}
```

> **注：** `compactionNote` 设为 required（非空），因为压缩提示总会有文本。若历史代码有不含 compactionNote 的构造点，需全部补齐（grep `CompactionEvent(` 全仓）。

- [ ] **步骤 4：改 agent_loop emit 处**

`agent_loop.dart:176-183`：
```dart
emit(CompactionEvent(
  removedChars: result.removedChars,
  originalChars: result.originalChars,
  compactedChars: result.compactedChars,        // ← 新增
  keptMessageCount: result.keptMessageCount,
  droppedMessageCount: result.droppedMessageCount,
  droppedAgentFromIndex: result.droppedAgentFromIndex,
  compactionNote: result.messages[1].content,   // ← 新增：压缩提示在 compacted.messages[1]
  rewrittenContent: result.rewrittenContent,
));
```

- [ ] **步骤 5：grep 全仓补齐其他 CompactionEvent 构造点**

运行：`cd novel_app && grep -rn "CompactionEvent(" lib/ test/`
对每个命中点补 `compactedChars` + `compactionNote` 参数（测试桩值即可，如 `compactedChars: 0, compactionNote: '[上下文压缩|...]'`）。

- [ ] **步骤 6：运行测试验证通过**

运行：`flutter test test/unit/services/novel_agent/agent_event_test.dart`
预期：PASS。再跑 `flutter analyze lib/services/novel_agent/` 确认无编译错误。

- [ ] **步骤 7：Commit**

```bash
git add novel_app/lib/services/novel_agent/agent_event.dart \
        novel_app/lib/services/novel_agent/agent_loop.dart \
        novel_app/test/unit/services/novel_agent/agent_event_test.dart \
        <其他 grep 命中的测试文件>
git commit -m "@feat(agent): CompactionEvent 补 compactedChars + compactionNote

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 任务 4：_handleCompaction 插入压缩提示 system 消息

**文件：**
- 修改：`novel_app/lib/core/providers/scenario_session.dart`（`_handleCompaction`）
- 测试：`novel_app/test/unit/core/providers/scenario_session_test.dart`（若不存在新建/扩充）

- [ ] **步骤 1：编写失败测试**

```dart
// test/unit/core/providers/scenario_session_test.dart（扩充）
test('_handleCompaction 后 _agentMessages 头部含压缩提示 system', () async {
  // 构造 session + _agentMessages（不含 sys_prompt）+ 触发 CompactionEvent
  // ... 见现有 scenario_session_test 的 setup 模式 ...
  final e = CompactionEvent(
    removedChars: 420000, originalChars: 580000, compactedChars: 160000,
    keptMessageCount: 15, droppedMessageCount: 23, droppedAgentFromIndex: 23,
    compactionNote: '[上下文压缩|droppedCount=23|keptCount=15|removedChars=420000|'
        'originalChars=580000|compactedChars=160000|rewrittenCount=0|timestamp=1706000101]\n后续。',
  );
  session.handleCompactionForTest(e); // 暴露测试入口或直接调 _handleCompaction
  expect(session.agentMessagesForTest.first.role, 'system');
  expect(session.agentMessagesForTest.first.content, startsWith('[上下文压缩|'));
});
```

> **注：** 若 ScenarioSession 没有暴露 `_handleCompaction` / `_agentMessages` 的测试入口，参考现有 `scenario_session_test.dart` 的 mock 模式（grep `handleCompaction` 或现有压缩测试）。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/unit/core/providers/scenario_session_test.dart`
预期：FAIL，压缩提示不在 _agentMessages 头部。

- [ ] **步骤 3：在 `_handleCompaction` 前先读 `_deleteAgentMessagesBeforeDb` 实现**

grep `scenario_session.dart:_deleteAgentMessagesBeforeDb`（约 1259 行附近），确认其实现是 `clearMessages + appendMessage(每条 _agentMessages 重写)` 的模式。**关键不变量** 依赖此实现：marker `insert(0, ...)` 后该函数会把 marker 作为 `agentMsgIndex=0` 整段重写落库。若实现不同（例如只按 id 删除不重写），则不变量 #1 失效，Task 4 需要调整落库策略。

`scenario_session.dart:1155-1200`，在 `removeRange` 之后、apply rewrittenContent 之前，插入压缩提示：

```dart
void _handleCompaction(CompactionEvent e) {
  final cut = e.droppedAgentFromIndex;
  if (cut <= 0) {
    // ... 现有无裁剪日志 ...
    return;
  }
  final removed = cut.clamp(0, _agentMessages.length);

  // 1) removeRange 丢弃前缀
  _agentMessages.removeRange(0, removed);

  // 2) 【新】头部插入压缩提示 system 消息（_agentMessages 不含 sys_prompt，
  //    压缩提示独占头部 index 0）。KV 文本由 ContextCompactor 生成、
  //    CompactionEvent.compactionNote 透传，保证与 agent_loop 本地 messages[1] 一致。
  _agentMessages.insert(0, ChatMessage(role: 'system', content: e.compactionNote));

  // 3) apply P1 预剪枝改写（现有逻辑，索引基底见 Task 0 结论）
  int appliedRewrite = 0;
  for (final entry in e.rewrittenContent) {
    if (entry.index < cut) continue;
    final newIdx = entry.index - cut;
    // 【Task 0 结论处插入偏移修正（若需要）】
    if (newIdx < 0 || newIdx >= _agentMessages.length) continue;
    final old = _agentMessages[newIdx];
    if (old.role != 'tool') continue;
    _agentMessages[newIdx] = ChatMessage(
      role: old.role, content: entry.newContent,
      name: old.name, toolCallId: old.toolCallId, toolCalls: old.toolCalls,
    );
    appliedRewrite++;
  }
  // ... 现有 copyWith + 日志 + _deleteAgentMessagesBeforeDb ...
}
```

> **Task 0 结论记录处：** 若 Task 0 发现 off-by-one（droppedAgentFromIndex 基于"含 sys_prompt 基底"，而 _agentMessages 不含），则 rewrittenContent 平移的 `newIdx = entry.index - cut` 可能也需要 ±1 修正。**在此处根据 Task 0 结论调整。** 但 marker insert 永远在 `insert(0, ...)`，不受影响。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/unit/core/providers/scenario_session_test.dart`
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add novel_app/lib/core/providers/scenario_session.dart novel_app/test/unit/core/providers/scenario_session_test.dart
git commit -m "@feat(agent): _handleCompaction 头部插入压缩提示 system 消息

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 任务 5：_projectUiMessages system 分流 → marker

**文件：**
- 修改：`novel_app/lib/core/providers/scenario_session.dart`（`_projectUiMessages`）
- 测试：`novel_app/test/unit/core/providers/scenario_session_projection_test.dart`（扩充或新建）

- [ ] **步骤 1：编写失败测试**

```dart
test('压缩提示 system 投影为 AgentChatRole.marker', () {
  final agentMsgs = <ChatMessage>[
    ChatMessage(role: 'system', content:
      '[上下文压缩|droppedCount=23|keptCount=15|removedChars=420000|'
      'originalChars=580000|compactedChars=160000|rewrittenCount=8|timestamp=1706000101]\n后续。'),
    ChatMessage(role: 'user', content: '继续'),
  ];
  final ui = ScenarioSession.projectUiMessagesForTest(agentMsgs);
  expect(ui[0].role, AgentChatRole.marker);
  expect(ui[0].segments.single, isA<CompactionMarkerSegment>());
  expect(ui[1].role, AgentChatRole.user);
});

test('普通 system 消息仍被 continue 跳过', () {
  final agentMsgs = <ChatMessage>[
    ChatMessage(role: 'system', content: 'You are a writer'),  // 非 [上下文压缩|
    ChatMessage(role: 'user', content: 'hi'),
  ];
  final ui = ScenarioSession.projectUiMessagesForTest(agentMsgs);
  expect(ui, hasLength(1));
  expect(ui.single.role, AgentChatRole.user);
});

test('坏前缀 KV 不崩，降级为 continue', () {
  final agentMsgs = <ChatMessage>[
    ChatMessage(role: 'system', content: '[上下文压缩|broken'),  // 无 ]
    ChatMessage(role: 'user', content: 'hi'),
  ];
  final ui = ScenarioSession.projectUiMessagesForTest(agentMsgs);
  expect(ui, hasLength(1));
  expect(ui.single.role, AgentChatRole.user);
});
```

> **注：** `_projectUiMessages` 当前是 static private。需加一个 `@visibleForTesting static` 包装（如 `projectUiMessagesForTest`），或把测试放在同文件内 `@visibleForTesting` 暴露。参考现有测试如何测投影层。

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/unit/core/providers/scenario_session_projection_test.dart`
预期：FAIL，marker 未生成（system 全 continue）。

- [ ] **步骤 3：改 `_projectUiMessages` 的 system case**

`scenario_session.dart:160-162`：
```dart
case 'system':
  // 压缩提示 system → marker；其余 system（sys_prompt 等）仍 continue
  final note = CompactionNoteParser.parse(m.content ?? '');
  if (note != null) {
    ui.add(AgentChatMessage.compactionMarker(note));
  }
  continue;
```

加 import：`import '../../services/novel_agent/compaction_note_parser.dart';`

- [ ] **步骤 4：暴露测试入口**

在 `_projectUiMessages` 旁加：
```dart
@visibleForTesting
static List<AgentChatMessage> projectUiMessagesForTest(List<ChatMessage> msgs) =>
    _projectUiMessages(msgs);
```

- [ ] **步骤 5：运行测试验证通过**

运行：`flutter test test/unit/core/providers/scenario_session_projection_test.dart`
预期：PASS。

- [ ] **步骤 6：Commit**

```bash
git add novel_app/lib/core/providers/scenario_session.dart novel_app/test/unit/core/providers/scenario_session_projection_test.dart
git commit -m "@feat(agent): _projectUiMessages 分流压缩提示为 marker

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 任务 6：hydrate 集成测试

**文件：**
- 测试：`novel_app/test/unit/core/providers/scenario_session_hydrate_test.dart`（扩充或新建）

- [ ] **步骤 1：前置核实 `ChatMessageRecord.toAgentMessage()` 保留 system role**

读 `novel_app/lib/models/chat_message_record.dart:64-80`，确认 `toAgentMessage()` 把 `role` 字段原样赋给 `ChatMessage.role`（已核实 line 80 `role: role`，system role 不丢）。这是 hydrate 路径能出 marker 的前提。

```dart
test('DB 含压缩提示 system → hydrate 后 _uiMessages 含 marker', () async {
  // 1) 用真实 sqflite ffi（参考现有 hydrate 测试 setup）建 session
  // 2) 直接 appendMessage 写入一条 role='system' content='[上下文压缩|...]' 消息
  // 3) session.hydrateIfNeeded()
  // 4) 断言 state.messages 含 AgentChatRole.marker 条目
  final repo = ...;
  await repo.createSession(...);
  await repo.appendMessage(ChatMessageRecord(
    sessionId: sid, agentMsgIndex: 0, role: 'system',
    content: '[上下文压缩|droppedCount=1|keptCount=1|removedChars=10|'
        'originalChars=20|compactedChars=10|rewrittenCount=0|timestamp=1706000101]\n后续。',
    timestamp: 1706000101,
  ));
  await session.hydrateIfNeeded();
  final ui = session.state.messages;
  expect(ui.any((m) => m.role == AgentChatRole.marker), isTrue);
});
```

> **注：** 参考现有 `scenario_session_hydrate_test.dart`（若存在）或 `chat_session_repository_test.dart` 的 sqflite_ffi setup 模式。

- [ ] **步骤 2：运行测试**

运行：`flutter test test/unit/core/providers/scenario_session_hydrate_test.dart`
预期：PASS（若 hydrate 路径已正确调用 _projectUiMessages，应直接通过——这正是"单一投影路径"不变量 #4 的验证）。

- [ ] **步骤 3：Commit（仅测试）**

```bash
git add novel_app/test/unit/core/providers/scenario_session_hydrate_test.dart
git commit -m "@test(agent): hydrate 后压缩提示还原为 marker

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 任务 7：CompactionMarkerCard widget

**文件：**
- 创建：`novel_app/lib/widgets/agent_chat/compaction_marker_card.dart`
- 测试：`novel_app/test/unit/widgets/agent_chat/compaction_marker_card_test.dart`

- [ ] **步骤 1：编写 widget 失败测试**

```dart
// test/unit/widgets/agent_chat/compaction_marker_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/agent_chat_message.dart';
import 'package:novel_app/widgets/agent_chat/compaction_marker_card.dart';

void main() {
  testWidgets('默认折叠，点击展开', (tester) async {
    final seg = const CompactionMarkerSegment(
      droppedMessageCount: 23, keptMessageCount: 15,
      removedChars: 420000, originalChars: 580000, compactedChars: 160000,
      rewrittenCount: 8,
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CompactionMarkerCard(segment: seg))));
    expect(find.textContaining('丢弃 23 条'), findsOneWidget);
    expect(find.textContaining('释放字符'), findsNothing);  // 展开内容

    await tester.tap(find.byType(CompactionMarkerCard));
    await tester.pumpAndSettle();
    expect(find.textContaining('释放字符'), findsOneWidget);
    expect(find.textContaining('改写 8 条'), findsOneWidget);
  });

  testWidgets('rewrittenCount=0 时不显示改写行', (tester) async {
    final seg = const CompactionMarkerSegment(
      droppedMessageCount: 1, keptMessageCount: 1,
      removedChars: 10, originalChars: 20, compactedChars: 10, rewrittenCount: 0,
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CompactionMarkerCard(segment: seg))));
    await tester.tap(find.byType(CompactionMarkerCard));
    await tester.pumpAndSettle();
    expect(find.textContaining('改写'), findsNothing);
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`cd novel_app && flutter test test/unit/widgets/agent_chat/compaction_marker_card_test.dart`
预期：FAIL，widget 不存在。

- [ ] **步骤 3：实现 widget**

`lib/widgets/agent_chat/compaction_marker_card.dart`：按规格 §5.1 的结构实现。**⚠️ 颜色字段核实（计划审查发现）**：`AppColors` 类（`core/theme/app_colors.dart`）**没有 `surface` 字段**，只有 `agentAccent / chatRoleBubble / ink / inkSoft`。背景色一律用 `Theme.of(context).colorScheme.surface`（与 `agent_message_bubble.dart` 内 tool 卡片一致，如 `theme.colorScheme.surface.withValues(alpha: 0.6)`），不要用 `context.appColors.surface`。边框/正文用 `context.appColors.inkSoft` / `context.appColors.ink`（这两个存在）。关键点：
- `StatefulWidget` + `_expanded` 状态
- 折叠态：居中 InkWell，`🗂 上下文已压缩 · 丢弃 N 条 ▾`
- 展开态：`AnimatedSize` 过渡，4 格统计 + 压缩率 `LinearProgressIndicator` + 不可回溯文案
- `rewrittenCount > 0` 时第 4 格追加「(其中 K 条 tool result 被改写)」+ 文案区分

```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/agent_chat_message.dart';

class CompactionMarkerCard extends StatefulWidget {
  final CompactionMarkerSegment segment;
  const CompactionMarkerCard({super.key, required this.segment});
  @override
  State<CompactionMarkerCard> createState() => _CompactionMarkerCardState();
}

class _CompactionMarkerCardState extends State<CompactionMarkerCard> {
  bool _expanded = false;

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K' : '$n';

  @override
  Widget build(BuildContext context) {
    final s = widget.segment;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: context.appColors.inkSoft.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🗂', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text('上下文已压缩 · 丢弃 ${s.droppedMessageCount} 条${_expanded ? '' : '  ▾'}'),
                ],
              ),
            ),
          ),
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
    return Container(
      margin: const EdgeInsets.only(top: 6),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: context.appColors.inkSoft.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 14, runSpacing: 6, children: [
            _stat('释放字符', _fmt(s.removedChars)),
            _stat('压缩前 → 后', '${_fmt(s.originalChars)} → ${_fmt(s.compactedChars)}'),
            _stat('丢弃消息', '${s.droppedMessageCount} 条'),
            _stat('保留消息', '${s.keptMessageCount} 条'
                '${s.rewrittenCount > 0 ? " (其中 ${s.rewrittenCount} 条 tool result 被改写)" : ""}'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text('${(s.compressionRatio * 100).round()}% 被释放'),
            const SizedBox(width: 8),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: s.compressionRatio, minHeight: 4,
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
            )),
          ]),
          const SizedBox(height: 8),
          Text(s.rewrittenCount > 0
              ? '被压缩/改写的内容不可回溯（预剪枝 1-liner 仅保留结构化摘要）'
              : '被压缩内容不可回溯（当前是简单截断，未生成摘要）'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    ]);
  }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/unit/widgets/agent_chat/compaction_marker_card_test.dart`
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add novel_app/lib/widgets/agent_chat/compaction_marker_card.dart \
        novel_app/test/unit/widgets/agent_chat/compaction_marker_card_test.dart
git commit -m "@feat(agent): CompactionMarkerCard M3 可展开卡片

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 任务 8：dialog itemBuilder marker 分支 + SnackBar

**文件：**
- 修改：`novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart`
- 测试：`novel_app/test/unit/widgets/agent_chat/agent_chat_dialog_test.dart`（扩充或新建）

- [ ] **步骤 1：编写失败测试**

```dart
testWidgets('marker role 渲染 CompactionMarkerCard', (tester) async {
  // 构造 chatState 含一条 marker message，pump dialog，断言 CompactionMarkerCard 出现
});

testWidgets('CompactionEvent 触发 SnackBar', (tester) async {
  // pump dialog + ScaffoldMessenger ancestor
  // 模拟 emit CompactionEvent
  // 断言 SnackBar 文案出现
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`cd novel_app && flutter test test/unit/widgets/agent_chat/agent_chat_dialog_test.dart`
预期：FAIL。

- [ ] **步骤 3：核实事件订阅方式（计划审查发现的关键修正）**

**⚠️ 关键：** agent 事件**不是 Riverpod provider**，是 `NovelAgentService.events` 的 **Stream**（`StreamController<AgentEvent>.broadcast()`）。dialog 现有用 `ref.listen(currentChatStateProvider, ...)`（`agent_chat_dialog.dart:120`）订阅 state，**没有现成的 agent 事件 StreamProvider**。

SnackBar 需要响应 `CompactionEvent`（瞬时事件，不进 chatState），有两种实现：

**(A) 推荐——加一个 StreamProvider 包装**：在 `core/providers/agent_chat_providers.dart` 加：
```dart
final agentEventsProvider = StreamProvider<AgentEvent>((ref) {
  return ref.read(novelAgentServiceProvider).events;
});
```
然后 dialog 用 `ref.listen<AsyncValue<AgentEvent>>(agentEventsProvider, (prev, next) { next.whenData((e) { if (e is CompactionEvent) ... }); })`。

**(B) 直接订阅 Stream**：在 `initState` 里 `ref.read(novelAgentServiceProvider).events.listen(...)`，`dispose` 里 cancel `StreamSubscription`。

**选 (A)**（声明式、与 RetryBanner 的订阅风格更接近、测试更易注入）。

核实 `novelAgentServiceProvider` 的定义位置（grep `novelAgentServiceProvider =`），以及 `AgentEvent` 的 import 路径（`services/novel_agent/agent_event.dart`）。

- [ ] **步骤 4：改 itemBuilder**

`agent_chat_dialog.dart:317-334`，把 `if/else` 改 `switch`：
```dart
final message = chatState.messages[index];
switch (message.role) {
  case AgentChatRole.marker:
    return CompactionMarkerCard(
      segment: message.segments.single as CompactionMarkerSegment,
    );
  case AgentChatRole.user:
  case AgentChatRole.assistant:
    final canRollback = message.role == AgentChatRole.user;
    return AgentMessageBubble(
      message: message,
      showTimestamp: true, // 默认显示，保留原 AgentMessageBubble 行为（计划审查发现原代码默认 true）
      onRollback: canRollback ? () => _handleRollback(index) : null,
    );
  case AgentChatRole.system:
    return const SizedBox.shrink(); // 防御：system 不应出现在 UI（投影层已过滤）
}
```

加 import：`import 'compaction_marker_card.dart';`

- [ ] **步骤 5：加 ref.listen SnackBar**

按步骤 3 选 (A)：用 `agentEventsProvider`（StreamProvider 包装）。

(a) 在 `core/providers/agent_chat_providers.dart` 顶部加 import + 新 provider：
```dart
import '../../services/novel_agent/agent_event.dart';
import 'chat_session_providers.dart';

final agentEventsProvider = StreamProvider<AgentEvent>((ref) {
  return ref.read(novelAgentServiceProvider).events;
});
```
（核实 `novelAgentServiceProvider` 在该文件已 export；若不在，需加上。）

(b) 在 `_AgentChatDialogState.build` 内加（参考 line 120 现有 `ref.listen(currentChatStateProvider, ...)` 模式）：
```dart
ref.listen<AsyncValue<AgentEvent>>(agentEventsProvider, (prev, next) {
  next.whenData((event) {
    if (event is! CompactionEvent) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(
      content: Text('🗂 ${event.description}'),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ));
  });
});
```

> dialog 若是 `showDialog` 弹层，`ScaffoldMessenger.maybeOf` 兜底（不崩）；若是 page（自有 Scaffold），直接 `ScaffoldMessenger.of(context)` 也行。按 Task 步骤 3 的核实结论选。

- [ ] **步骤 6：运行测试验证通过**

运行：`flutter test test/unit/widgets/agent_chat/agent_chat_dialog_test.dart`
预期：PASS。

- [ ] **步骤 7：Commit**

```bash
git add novel_app/lib/widgets/agent_chat/agent_chat_dialog.dart \
        novel_app/test/unit/widgets/agent_chat/agent_chat_dialog_test.dart
git commit -m "@feat(agent): dialog 渲染 marker + 压缩 SnackBar

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 任务 9：回归测试

**文件：**
- 测试：`novel_app/test/unit/core/providers/scenario_session_test.dart`（rollback、连续压缩、子 Agent）
- 测试：`novel_app/test/unit/services/novel_agent/context_compactor_test.dart`（KV 损坏降级）

- [ ] **步骤 1：连续压缩 2 次测试**

```dart
test('同一会话连续压缩 2 次 → _agentMessages 含 2 条压缩提示', () {
  // 触发第一次压缩 → insert 提示1
  // 触发第二次压缩 → removeRange 删掉提示1（在丢弃段）+ insert 提示2
  // 断言 _agentMessages 中 [上下文压缩| 出现次数 == 1（最新一条）
  //    或 == 2（若提示1 未在丢弃段）——根据实际 splitIndex 行为断言
});
```

- [ ] **步骤 2：rollback 与 marker 测试**

```dart
test('rollback 到 marker 之后 → marker 保留', () { ... });
test('rollback 到 marker 之前 → marker 随重写消失', () { ... });
test('marker 不是 user 消息，不渲染回滚按钮', () { ... });
```

- [ ] **步骤 3：KV 损坏降级测试**

```dart
test('压缩提示 content 损坏 → 投影层 continue 不崩', () {
  final ui = ScenarioSession.projectUiMessagesForTest([
    ChatMessage(role: 'system', content: '[上下文压缩|garbage'),  // 无 ]
    ChatMessage(role: 'user', content: 'hi'),
  ]);
  expect(ui, hasLength(1));
});
```

- [ ] **步骤 4：运行全部相关测试**

运行：`cd novel_app && flutter test test/unit/core/providers/ test/unit/services/novel_agent/ test/unit/widgets/agent_chat/`
预期：全 PASS。

- [ ] **步骤 5：flutter analyze**

运行：`flutter analyze lib/`
预期：无新增 error/warning。

- [ ] **步骤 6：Commit**

```bash
git add novel_app/test/
git commit -m "@test(agent): 压缩 UI 回归测试（连续压缩/rollback/KV损坏降级）

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 完成标准

- [ ] 5 个关键不变量全部有测试锁定：
  1. 压缩提示 `agentMsgIndex` 在 DB 重写后 = 0（任务 4/6）
  2. `_selectSplitIndex` 跳过所有 system（任务 2 的 compaction 测试已覆盖）
  3. marker 渲染不依赖 CompactionEvent（任务 6 hydrate 测试——无事件也出 marker）
  4. 内存/hydrate 同函数（任务 5/6 共用 `_projectUiMessages`）
  5. `rewrittenCount == rewrittenContent.length`（任务 2 的 compactionNote 构造处同步）
- [ ] `flutter analyze lib/` 无新增问题
- [ ] 全部任务 commit 完成
- [ ] 更新 `novel_app/CLAUDE.md` changelog（新增 2026-07-18 上下文压缩 UI 条目）
