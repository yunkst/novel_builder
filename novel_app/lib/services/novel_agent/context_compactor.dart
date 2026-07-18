/// 上下文压缩服务（v32 统一历史模型）
///
/// 触发条件：消息总字符数 ≥ 阈值（默认 500K 字符，≈ 125K tokens，适配 128K 上下文窗口）
/// 压缩策略：保留 system + 最近 N 条消息，丢弃早期消息
/// 工具调用安全：
///   1) 切点配对保护——不切断 assistant(toolCalls) 与其 tool 结果
///   2) 尾部完整消息（含 tool_calls/toolCallId 关联）
/// 可关闭：通过 [CompactorConfig.enabled] 控制
///
/// v32 变更：DB 也存 agent 消息，压缩时返回 [CompactionResult.droppedAgentFromIndex]，
/// ScenarioSession 据此同步裁剪内存 + 删 DB（deleteMessagesBefore）。
/// 不再需要 messageOwners / droppedHermesRange 的 UI 反推逻辑。
///
/// 工具结果截断不在本组件负责：实时工具结果在 agent_loop.dart 已被
/// [ToolResultFormatter] 截到 50000 字符，压缩阶段不再二次截断；超长的历史
/// tool 结果会随整条消息丢弃。
///
/// P1 已实现（cheap pre-pruning）：[compact] 第一步对压缩候选区间的老 tool result
/// 做 Pass 1 MD5 去重 + Pass 2 按工具类型 1-liner 改写（详见 [_pruneOldToolResults]）。
/// 预剪枝只改 tool result 的 content；assistant.toolCalls / system / user 不动，
/// toolCallId / 消息顺序不变。改写后同样 [preserveTailChars] 预算能装下更多消息，
/// 减少丢消息数。改写记录通过 [CompactionResult.rewrittenContent] 透传给
/// ScenarioSession 同步落库（hydrate 续聊时 LLM 看到精简版）。
///
/// P2 计划：用 LLM 生成结构化摘要替代规则式 1-liner（预剪枝层是 P2 的前置——
/// 先把总字符数降下来，减少需要 LLM 摘要的内容）。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:novel_app/services/logger_service.dart';

import '../dsl_engine/llm_provider.dart';

/// 预剪枝改写记录：被改写的 tool result 在"压缩前 messages"中的索引 + 新 content
///
/// 索引语义与 [CompactionResult.droppedAgentFromIndex] 一致（基于压缩前 messages）。
/// ScenarioSession 收到 [CompactionEvent] 后，先 removeRange(0, cut)，
/// 再对 index >= cut 的 entry 平移到 `index - cut` 写入 [ChatMessage.content]。
typedef RewrittenEntry = ({int index, String newContent});

/// 压缩配置
class CompactorConfig {
  /// 是否启用自动压缩
  final bool enabled;

  /// 上下文字符数阈值（超过此值触发压缩）
  ///
  /// 默认 500000 字符 ≈ 125K tokens（适配 GPT-4o/DeepSeek/Qwen 128K 上下文窗口）
  final int maxContextChars;

  /// 保留尾部字符数（最近的消息）
  ///
  /// 默认 100000 字符 ≈ 25K tokens（占总阈值的 20%，保证近期对话 + 工具结果不被丢）
  final int preserveTailChars;

  /// 是否启用 P1 预剪枝（去重 + 1-liner 改写老 tool result）
  ///
  /// 默认 true。false 时 [ContextCompactor.compact] 跳过预剪枝，
  /// 行为退化为 v32 的"按切点丢弃式"压缩。
  final bool prePruneEnabled;

  /// 去重阈值：tool result content > 此值才参与 Pass 1 去重
  ///
  /// 默认 200 字符。短 content 去重收益小、误判风险高（两条 `"OK"` 碰巧相同
  /// 不应被去重）。
  final int dedupThresholdChars;

  /// 1-liner 改写阈值：tool result content > 此值才被 Pass 2 改写为 1-liner
  ///
  /// 默认 500 字符。短结果改写收益低（500 → 100 也只省 400 字），且改写后
  /// LLM 看不到细节，对短结果负面收益大。
  final int longFieldChars;

  /// 保护最近 N 条 tool result 不做改写（尾部完整性）
  ///
  /// 默认 6 条（≈ 3 轮 tool 调用）。LLM 下一轮可能还会追问这些最近结果，
  /// 保留原文避免信息丢失。0 表示全部历史 tool result 都允许改写。
  final int protectRecentToolResults;

  const CompactorConfig({
    this.enabled = true,
    this.maxContextChars = 500000,
    this.preserveTailChars = 100000,
    this.prePruneEnabled = true,
    this.dedupThresholdChars = 200,
    this.longFieldChars = 500,
    this.protectRecentToolResults = 6,
  });

  /// 禁用压缩
  static const disabled = CompactorConfig(enabled: false);

  CompactorConfig copyWith({
    bool? enabled,
    int? maxContextChars,
    int? preserveTailChars,
    bool? prePruneEnabled,
    int? dedupThresholdChars,
    int? longFieldChars,
    int? protectRecentToolResults,
  }) {
    return CompactorConfig(
      enabled: enabled ?? this.enabled,
      maxContextChars: maxContextChars ?? this.maxContextChars,
      preserveTailChars: preserveTailChars ?? this.preserveTailChars,
      prePruneEnabled: prePruneEnabled ?? this.prePruneEnabled,
      dedupThresholdChars: dedupThresholdChars ?? this.dedupThresholdChars,
      longFieldChars: longFieldChars ?? this.longFieldChars,
      protectRecentToolResults:
          protectRecentToolResults ?? this.protectRecentToolResults,
    );
  }
}

/// 压缩结果
class CompactionResult {
  /// 重组后的消息列表
  final List<ChatMessage> messages;

  /// 释放的字符数
  final int removedChars;

  /// 原始字符数
  final int originalChars;

  /// 压缩后的字符数
  final int compactedChars;

  /// 保留的尾部消息条数
  final int keptMessageCount;

  /// 丢弃的消息条数
  final int droppedMessageCount;

  /// agent 内部 messages 中被丢弃的起始索引 [0, droppedAgentFromIndex)
  ///
  /// = 压缩前的 splitIndex。ScenarioSession 据此：
  /// 内存 removeRange(0, droppedAgentFromIndex) + DB deleteMessagesBefore(sid, droppedAgentFromIndex)。
  final int droppedAgentFromIndex;

  /// P1 预剪枝改写记录（基于压缩前 messages 索引）
  ///
  /// 落在 `[0, droppedAgentFromIndex)` 区间内的 entry 会被整条丢弃，ScenarioSession
  /// 无须同步；`>= droppedAgentFromIndex` 的 entry 需平移到 `index - cut` 写入 content。
  /// 空列表表示未发生改写（预剪枝关闭或无 tool result 可改）。
  final List<RewrittenEntry> rewrittenContent;

  const CompactionResult({
    required this.messages,
    required this.removedChars,
    required this.originalChars,
    required this.compactedChars,
    required this.keptMessageCount,
    required this.droppedMessageCount,
    required this.droppedAgentFromIndex,
    this.rewrittenContent = const [],
  });

  /// 压缩率（0-1，越大压缩越多）
  double get compressionRatio =>
      originalChars > 0 ? removedChars / originalChars : 0;
}

/// 上下文压缩器
///
/// 保留 system + 尾部消息，丢弃早期消息。保证 tool_calls 与 tool 响应的配对完整。
class ContextCompactor {
  final CompactorConfig _config;

  ContextCompactor({CompactorConfig? config})
      : _config = config ?? const CompactorConfig();

  /// 检查是否需要压缩
  ///
  /// 返回 true 表示消息总字符数超过阈值，需要压缩
  bool needsCompaction(List<ChatMessage> messages) {
    if (!_config.enabled) return false;
    final totalChars = _estimateTotalChars(messages);
    return totalChars >= _config.maxContextChars;
  }

  /// 执行压缩
  ///
  /// [messages] 当前消息列表（含 system prompt）
  /// [systemPrompt] 系统提示词（始终保留）
  ///
  /// 流程：
  /// 1) P1 预剪枝：改写老 tool result content（去重 + 1-liner）
  /// 2) 边界选择：从后向前累加找到保留起始位置（含配对保护）
  /// 3) 重组：system + 压缩提示 + 保留尾部
  ///
  /// 返回 [CompactionResult]，包含重组后的消息列表 + 被丢弃的起始索引 + 改写记录。
  CompactionResult compact({
    required List<ChatMessage> messages,
    required String systemPrompt,
  }) {
    // 1. P1 预剪枝：改写老 tool result（仅 content，不动 toolCallId/顺序/配对）
    final pruned = _config.prePruneEnabled
        ? _pruneOldToolResults(messages)
        : (messages: messages, rewrittenContent: const <RewrittenEntry>[]);

    // 2. 边界选择：从后向前累加，找到保留的起始位置（含配对保护）
    final splitIndex = _selectSplitIndex(pruned.messages);

    // 3. 构建压缩后的消息列表
    final compacted = <ChatMessage>[
      // system prompt 始终保留
      ChatMessage(role: 'system', content: systemPrompt),
      // 压缩提示（告知 LLM 上下文已被压缩）
      ChatMessage(
        role: 'system',
        content: _buildCompactionNote(splitIndex, pruned.messages.length),
      ),
      // 保留尾部消息（splitIndex 已保证 tool_call/tool 配对完整）
      ...pruned.messages.sublist(splitIndex),
    ];

    final originalChars = _estimateTotalChars(messages);
    final compactedChars = _estimateTotalChars(compacted);
    final droppedCount = splitIndex;
    final keptCount = pruned.messages.length - splitIndex;

    LoggerService.instance.i(
      '上下文压缩完成: $originalChars→$compactedChars 字 '
      '(释放 ${originalChars - compactedChars} 字, '
      '保留 $keptCount 条, 丢弃 $droppedCount 条, '
      '预剪枝改写 ${pruned.rewrittenContent.length} 条, '
      'droppedAgentFromIndex=$splitIndex)',
      category: LogCategory.ai,
      tags: ['agent', 'compaction', 'complete'],
    );

    return CompactionResult(
      messages: compacted,
      removedChars: originalChars - compactedChars,
      originalChars: originalChars,
      compactedChars: compactedChars,
      keptMessageCount: keptCount,
      droppedMessageCount: droppedCount,
      droppedAgentFromIndex: splitIndex,
      rewrittenContent: pruned.rewrittenContent,
    );
  }

  /// 从后向前选择保留边界（含 tool_call/tool 配对保护）
  ///
  /// 从最后一条消息开始向前累加字符数，直到超过 [preserveTailChars]。
  /// 若候选切点会切断 assistant(toolCalls) → tool(result) 的配对，
  /// 回退到 assistant 之前，避免保留孤立的 tool 消息导致 API 400。
  ///
  /// 返回保留起始索引（含），即 messages[splitIndex..] 会被保留。
  int _selectSplitIndex(List<ChatMessage> messages) {
    int accumulatedChars = 0;
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      // system 消息不参与尾部计数（它们会在 compact() 中单独处理）
      if (m.role == 'system') continue;

      final charCount = _estimateMessageChars(m);
      accumulatedChars += charCount;

      if (accumulatedChars > _config.preserveTailChars) {
        // 候选切点：保留 [i+1, end)
        return _protectToolPairing(messages, i + 1);
      }
    }
    // 所有消息都在预算内，无需压缩
    return 0;
  }

  /// 配对保护：若切点落在 assistant(toolCalls) 与其 tool 结果之间，回退。
  ///
  /// [splitIndex] 原始候选切点（messages[splitIndex] 是保留段的第一条）。
  /// 若 messages[splitIndex-1] 是 assistant 且带 toolCalls，
  /// 且 messages[splitIndex] 是 tool（其 toolCallId 属于前一个 assistant），
  /// 则把切点回退到 splitIndex-1（把 assistant 也纳入保留段，配对完整）。
  /// 递归向前检查，直到切点安全或顶到 system。
  int _protectToolPairing(List<ChatMessage> messages, int splitIndex) {
    int split = splitIndex;
    while (split > 1 && split < messages.length) {
      final prev = messages[split - 1];
      final curr = messages[split];
      if (prev.role == 'assistant' &&
          (prev.toolCalls?.isNotEmpty ?? false) &&
          curr.role == 'tool' &&
          (prev.toolCalls?.any((t) => t.id == curr.toolCallId) ?? false)) {
        split = split - 1;
        continue;
      }
      break;
    }
    return split;
  }

  /// 构建压缩提示消息
  ///
  /// 告知 LLM 早期上下文已被压缩，帮助它理解当前状态。
  String _buildCompactionNote(int droppedCount, int totalCount) {
    return '[上下文压缩] 早期 $droppedCount 条消息已被压缩移除。'
        '请基于保留的最近 ${totalCount - droppedCount} 条消息继续对话。'
        '如果缺少关键信息，请使用工具重新查询。';
  }

  /// 估算消息列表总字符数
  int _estimateTotalChars(List<ChatMessage> messages) {
    return messages.fold(0, (sum, m) => sum + _estimateMessageChars(m));
  }

  /// 估算单条消息的字符数
  int _estimateMessageChars(ChatMessage m) {
    var len = (m.content?.length ?? 0);

    // tool_calls 参数也计入
    if (m.toolCalls != null) {
      for (final tc in m.toolCalls!) {
        len += tc.name.length;
        len += _safeJsonEncode(tc.arguments).length;
      }
    }

    // tool 角色消息的 toolCallId 也计入
    if (m.toolCallId != null) {
      len += m.toolCallId!.length;
    }

    return len;
  }

  /// 安全的 JSON 编码（失败时返回空字符串）
  String _safeJsonEncode(dynamic obj) {
    try {
      return jsonEncode(obj);
    } catch (_) {
      return obj.toString();
    }
  }

  // ============================================================
  // P1 预剪枝（cheap pre-pruning）
  // ============================================================
  //
  // 借鉴 hermes-agent 的 _prune_old_tool_results（Phase 1 廉价预处理）：
  // - Pass 1: MD5 去重（content > dedupThresholdChars 的旧重复替换为 "[dup]" 标记）
  // - Pass 2: 1-liner 改写（按工具类型生成结构化摘要）
  // 两条 Pass 共用"可改写区间"=[0, protectEnd)，protectEnd 是从末尾向前数
  // protectRecentToolResults 条 tool result 之后的索引。
  //
  // 只改 tool result 的 content，不动：
  // - assistant 消息的 toolCalls（含 arguments，LLM 决策上下文）
  // - user / system 消息的 content
  // - 任意消息的 toolCallId / 消息顺序 / 配对关系
  //
  // 改写后的 content 必须是合法 JSON 字符串（read_chapter_content 纯文本特例除外），
  // 保证 agent_loop L530-538 的 jsonDecode 回退路径不被触发。

  /// 预剪枝主流程：返回改写后的 messages 列表 + 改写记录
  ///
  /// 构造新 List 保持原长度与索引顺序，原 messages 不动。
  /// rewrittenContent 的 index 是"压缩前 messages 索引"（与 droppedAgentFromIndex 同语义）。
  ({List<ChatMessage> messages, List<RewrittenEntry> rewrittenContent})
      _pruneOldToolResults(List<ChatMessage> messages) {
    // 1) 算出"可改写区间"结束索引（protectEnd 及其之后是受保护的尾部 tool result）
    final protectEnd = _calcProtectEnd(messages);

    // tool result 总数 <= protectRecentToolResults 时，全保护，直接返回
    if (protectEnd == 0) {
      return (messages: messages, rewrittenContent: const []);
    }

    // 2) 构建 toolCallId → toolName 索引（仅在改写时按需查，无需查整个 messages）
    //    在 protected 区间内也可能需要（其实不需要，因为 protectEnd 内的不改），
    //    但为简单起见全量建索引（O(n)），后续 Pass 2 内部判断 protectEnd 边界。
    final callIdToToolName = _buildToolCallIdIndex(messages);

    // 3) Pass 1：MD5 去重（仅在 [0, protectEnd) 内对超阈值 content 做去重）
    final dedupResult = _dedupOldToolResults(
      messages,
      protectEnd,
      callIdToToolName,
    );

    // 4) Pass 2：对剩余未改写、content > longFieldChars 的 tool result 做 1-liner
    final oneLinerResult = _oneLinerOldToolResults(
      dedupResult.messages,
      protectEnd,
      callIdToToolName,
      dedupResult.rewrittenIndexes,
    );

    // 合并改写 entries（按 index 升序，便于 ScenarioSession 顺序处理）
    final entries = <RewrittenEntry>[
      ...dedupResult.entries,
      ...oneLinerResult.entries,
    ]..sort((a, b) => a.index.compareTo(b.index));

    return (messages: oneLinerResult.messages, rewrittenContent: entries);
  }

  /// 计算"可改写区间"结束索引（exclusive）
  ///
  /// 从 messages 末尾向前数 [CompactorConfig.protectRecentToolResults] 条
  /// role=='tool' 的消息，其索引（含）至末尾为受保护尾部。
  /// 返回的 protectEnd 是"可改写区间最后位置（exclusive）"，即 [0, protectEnd) 可改写。
  ///
  /// tool result 总数 <= N 时返回 0（全部保护）。
  int _calcProtectEnd(List<ChatMessage> messages) {
    final n = _config.protectRecentToolResults;
    if (n <= 0) return messages.length;

    int toolCount = 0;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'tool') {
        toolCount++;
        if (toolCount == n) return i;
      }
    }
    return 0; // tool result 不足 N 条，全保护
  }

  /// 构建 toolCallId → toolName 索引
  ///
  /// 复用 `_protectToolPairing` 的回溯模式：对每条 tool 消息，先查正向建好的
  /// `id → name` 映射（来自所有 assistant.toolCalls）；命中即用，否则回溯找最近的
  /// 带 toolCalls 的 assistant。找不到则标 `'unknown'`。
  Map<String, String> _buildToolCallIdIndex(List<ChatMessage> messages) {
    // 1) 正向建 id → name 映射（assistant 端声明）
    final forward = <String, String>{};
    for (final m in messages) {
      if (m.role == 'assistant' && m.toolCalls != null) {
        for (final tc in m.toolCalls!) {
          forward[tc.id] = tc.name;
        }
      }
    }

    final result = <String, String>{};
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m.role != 'tool' || m.toolCallId == null) continue;
      final id = m.toolCallId!;
      if (forward.containsKey(id)) {
        result[id] = forward[id]!;
        continue;
      }
      // 2) 回溯找最近的 assistant(toolCalls)
      for (int j = i - 1; j >= 0; j--) {
        final prev = messages[j];
        if (prev.role == 'assistant' && prev.toolCalls != null) {
          for (final tc in prev.toolCalls!) {
            if (tc.id == id) {
              result[id] = tc.name;
              break;
            }
          }
          if (result.containsKey(id)) break;
        }
      }
      // 3) 仍找不到：标记 unknown
      result.putIfAbsent(id, () => 'unknown');
    }
    return result;
  }

  /// Pass 1：MD5 去重（仅在 [0, protectEnd) 内对超阈值 content 做去重）
  ///
  /// 同一 content 在区间内多次出现时，**只保留最后一条**（最新结果）的原文，
  /// 前面所有重复替换为 `"[toolName dup of ${lastIdx}#${md5前缀}]"`。
  /// 这样 LLM 看到的是"这个工具被调用过多次，最近一次的结果在第 N 条"，最早的
  /// 重复被压缩为一个标记，节省 token 同时不丢关键信息。
  ///
  /// 只对 content.length > [CompactorConfig.dedupThresholdChars] 的消息参与去重。
  /// 算法：两遍扫描——第一遍记录每个 MD5 的最后出现索引；第二遍替换非最后索引。
  ({List<ChatMessage> messages, List<RewrittenEntry> entries, Set<int> rewrittenIndexes})
      _dedupOldToolResults(
    List<ChatMessage> messages,
    int protectEnd,
    Map<String, String> callIdToToolName,
  ) {
    final lastSeen = <String, int>{}; // md5 → 最后出现的原 messages 索引

    // 第一遍：记录每个 MD5 的最后索引
    for (int i = 0; i < protectEnd; i++) {
      final m = messages[i];
      if (m.role != 'tool' || m.content == null) continue;
      final content = m.content!;
      if (content.length <= _config.dedupThresholdChars) continue;
      lastSeen[_md5Hash(content)] = i;
    }

    // 第二遍：替换非最后索引的重复
    final result = List<ChatMessage>.from(messages);
    final entries = <RewrittenEntry>[];
    final rewrittenIndexes = <int>{};

    for (int i = 0; i < protectEnd; i++) {
      final m = messages[i];
      if (m.role != 'tool' || m.content == null) continue;
      final content = m.content!;
      if (content.length <= _config.dedupThresholdChars) continue;

      final md5 = _md5Hash(content);
      final lastIdx = lastSeen[md5]!;
      if (lastIdx == i) continue; // 最后一条保留原文

      // 重复：替换为 dup 标记（指向最后一条）
      final toolName = callIdToToolName[m.toolCallId ?? ''] ?? 'unknown';
      final md5Short = md5.substring(0, 6);
      final newContent =
          jsonEncode('[$toolName dup of $lastIdx#$md5Short]');
      entries.add((index: i, newContent: newContent));
      rewrittenIndexes.add(i);
      result[i] = ChatMessage(
        role: m.role,
        content: newContent,
        name: m.name,
        toolCallId: m.toolCallId,
        toolCalls: m.toolCalls,
      );
    }
    return (messages: result, entries: entries, rewrittenIndexes: rewrittenIndexes);
  }

  /// Pass 2：1-liner 改写（仅在 [0, protectEnd) 内对长 content 做摘要）
  ///
  /// 跳过已被 Pass 1 改写过的 index；对剩余的 `content.length > longFieldChars`
  /// 的 tool result 调 [_summarizeToolResult] 生成 1-liner。
  ({List<ChatMessage> messages, List<RewrittenEntry> entries})
      _oneLinerOldToolResults(
    List<ChatMessage> messages,
    int protectEnd,
    Map<String, String> callIdToToolName,
    Set<int> alreadyRewritten,
  ) {
    final result = List<ChatMessage>.from(messages);
    final entries = <RewrittenEntry>[];

    for (int i = 0; i < protectEnd; i++) {
      if (alreadyRewritten.contains(i)) continue;
      final m = messages[i];
      if (m.role != 'tool' || m.content == null) continue;
      if (m.content!.length <= _config.longFieldChars) continue;

      final toolName =
          callIdToToolName[m.toolCallId ?? ''] ?? 'unknown';
      final newContent = _summarizeToolResult(toolName, m.content!);
      entries.add((index: i, newContent: newContent));
      result[i] = ChatMessage(
        role: m.role,
        content: newContent,
        name: m.name,
        toolCallId: m.toolCallId,
        toolCalls: m.toolCalls,
      );
    }
    return (messages: result, entries: entries);
  }

  /// 按工具名分发到具体 1-liner 生成器
  String _summarizeToolResult(String toolName, String content) {
    switch (toolName) {
      case 'read_chapter_content':
        return _summarizeReadChapter(content);
      case 'list_chapters':
        return _summarizeListChapters(content);
      case 'search_in_chapters':
        return _summarizeSearchInChapters(content);
      case 'execute_js':
        return _summarizeExecuteJs(content);
      default:
        return _summarizeGeneric(toolName, content);
    }
  }

  /// read_chapter_content 返回纯文本（非 JSON），1-liner 直接给字符数
  ///
  /// 注意：直接返回纯文本（外层不再 jsonEncode），因为原 content 本身就是纯文本，
  /// 保持格式一致；若强行 jsonEncode 反而会让 LLM 多看一层引号。
  String _summarizeReadChapter(String content) {
    return '[read_chapter] ${content.length} 字';
  }

  /// list_chapters：从 JSON 读 count 字段；错误分支保留 error/message
  String _summarizeListChapters(String content) {
    final json = _safeJsonDecode(content);
    if (json == null) return _summarizeGeneric('list_chapters', content);

    if (json.containsKey('error')) {
      return jsonEncode({
        'error': json['error'],
        if (json['message'] != null) 'message': json['message'],
      });
    }
    final count = json['count'] ?? 0;
    return jsonEncode('[list_chapters] $count 章');
  }

  /// search_in_chapters：从 JSON 读 keyword/totalChaptersHit/totalMatches
  String _summarizeSearchInChapters(String content) {
    final json = _safeJsonDecode(content);
    if (json == null) return _summarizeGeneric('search_in_chapters', content);

    if (json.containsKey('error')) {
      return jsonEncode({
        'error': json['error'],
        if (json['message'] != null) 'message': json['message'],
      });
    }
    final kw = json['keyword'] ?? '';
    final chaptersHit = json['totalChaptersHit'] ?? 0;
    final totalMatches = json['totalMatches'] ?? 0;
    return jsonEncode('[search] 搜"$kw" 命中 $chaptersHit 章/$totalMatches 处');
  }

  /// execute_js：从 `__meta.{run_id, mode}` 推断
  String _summarizeExecuteJs(String content) {
    final json = _safeJsonDecode(content);
    if (json == null) return _summarizeGeneric('execute_js', content);

    if (json.containsKey('error')) {
      return jsonEncode({
        'error': json['error'],
        if (json['message'] != null) 'message': json['message'],
      });
    }
    final meta = json['__meta'];
    if (meta is Map) {
      final mode = meta['mode']?.toString() ?? '?';
      final runId = meta['run_id']?.toString() ?? '?';
      final runIdShort = runId.length > 8 ? runId.substring(0, 8) : runId;
      return jsonEncode('[execute_js] $mode r-$runIdShort');
    }
    return _summarizeGeneric('execute_js', content);
  }

  /// 通用 fallback：未知工具名时只报工具名 + content 字符数
  String _summarizeGeneric(String toolName, String content) {
    return jsonEncode('[$toolName] (${content.length} 字符)');
  }

  /// MD5 哈希（hex 字符串）
  String _md5Hash(String s) {
    return md5.convert(utf8.encode(s)).toString();
  }

  /// 安全的 JSON 解码（非 Map 返回 null，解析失败返回 null）
  Map<String, dynamic>? _safeJsonDecode(String s) {
    try {
      final decoded = jsonDecode(s);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
