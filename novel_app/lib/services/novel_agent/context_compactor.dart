/// 上下文压缩服务（P0 最小可用版）
///
/// 参考 opencode 的混合策略实现：
/// - 触发条件：消息总字符数 ≥ 阈值（默认 60K 字符，≈ 15K tokens）
/// - 压缩策略：保留 system + 最近 N 条消息，丢弃早期消息
/// - 工具调用安全：保留尾部完整消息（含 tool_calls/toolCallId 关联）
/// - 可关闭：通过 [CompactorConfig.enabled] 控制
///
/// P1 计划：用 LLM 生成结构化摘要替代简单截断
library;

import 'dart:convert';

import 'package:novel_app/services/logger_service.dart';

import '../dsl_engine/llm_provider.dart';

/// 压缩配置
class CompactorConfig {
  /// 是否启用自动压缩
  final bool enabled;

  /// 上下文字符数阈值（超过此值触发压缩）
  ///
  /// 默认 60000 字符 ≈ 15K tokens（中文约 1.5 字符/token）
  final int maxContextChars;

  /// 保留尾部字符数（最近的消息）
  ///
  /// 默认 12000 字符 ≈ 3K tokens
  final int preserveTailChars;

  /// 工具输出截断长度（压缩时单个 tool 结果的最大字符数）
  ///
  /// 默认 2000 字符，与 opencode 一致
  final int toolOutputMaxChars;

  const CompactorConfig({
    this.enabled = true,
    this.maxContextChars = 60000,
    this.preserveTailChars = 12000,
    this.toolOutputMaxChars = 2000,
  });

  /// 禁用压缩
  static const disabled = CompactorConfig(enabled: false);

  CompactorConfig copyWith({
    bool? enabled,
    int? maxContextChars,
    int? preserveTailChars,
    int? toolOutputMaxChars,
  }) {
    return CompactorConfig(
      enabled: enabled ?? this.enabled,
      maxContextChars: maxContextChars ?? this.maxContextChars,
      preserveTailChars: preserveTailChars ?? this.preserveTailChars,
      toolOutputMaxChars: toolOutputMaxChars ?? this.toolOutputMaxChars,
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

  const CompactionResult({
    required this.messages,
    required this.removedChars,
    required this.originalChars,
    required this.compactedChars,
    required this.keptMessageCount,
    required this.droppedMessageCount,
  });

  /// 压缩率（0-1，越大压缩越多）
  double get compressionRatio =>
      originalChars > 0 ? removedChars / originalChars : 0;
}

/// 上下文压缩器
///
/// P0 策略：保留 system + 尾部消息，丢弃早期消息。
/// 确保 tool_calls 与 tool 响应的关联性不丢失。
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
  /// 返回 [CompactionResult]，包含重组后的消息列表
  CompactionResult compact({
    required List<ChatMessage> messages,
    required String systemPrompt,
  }) {
    final originalChars = _estimateTotalChars(messages);

    // 1. 边界选择：从后向前累加，找到保留的起始位置
    final splitIndex = _selectSplitIndex(messages);

    // 2. 构建压缩后的消息列表
    final compacted = <ChatMessage>[
      // system prompt 始终保留
      ChatMessage(role: 'system', content: systemPrompt),
      // 压缩提示（告知 LLM 上下文已被压缩）
      ChatMessage(
        role: 'system',
        content: _buildCompactionNote(splitIndex, messages.length),
      ),
      // 保留尾部消息（保证 tool_call_id 关联性）
      ...messages.sublist(splitIndex),
    ];

    final compactedChars = _estimateTotalChars(compacted);
    final droppedCount = splitIndex;
    final keptCount = messages.length - splitIndex;

    LoggerService.instance.i(
      '上下文压缩完成: $originalChars→$compactedChars 字 '
      '(释放 ${originalChars - compactedChars} 字, '
      '保留 $keptCount 条, 丢弃 $droppedCount 条)',
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
    );
  }

  /// 从后向前选择保留边界
  ///
  /// 从最后一条消息开始向前累加字符数，直到超过 [preserveTailChars]。
  /// 返回保留起始索引（含），即 messages[spliIndex..] 会被保留。
  int _selectSplitIndex(List<ChatMessage> messages) {
    int accumulatedChars = 0;
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      // system 消息不参与尾部计数（它们会在 compact() 中单独处理）
      if (m.role == 'system') continue;

      final charCount = _estimateMessageChars(m);
      accumulatedChars += charCount;

      if (accumulatedChars > _config.preserveTailChars) {
        // 当前消息导致超出保留预算，从下一条开始保留
        return i + 1;
      }
    }
    // 所有消息都在预算内，无需压缩
    return 0;
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
}
