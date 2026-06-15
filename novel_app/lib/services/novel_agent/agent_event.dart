/// Agent 流式事件定义
///
/// Phase 2: ReAct 循环产生的事件流（用 sealed class + Dart 3 模式匹配）
library;

/// 工具调用展示信息（供 UI 渲染）
class AgentToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final AgentToolStatus status;
  final String? result;

  const AgentToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.status = AgentToolStatus.running,
    this.result,
  });

  AgentToolCall copyWith({
    AgentToolStatus? status,
    String? result,
  }) {
    return AgentToolCall(
      id: id,
      name: name,
      arguments: arguments,
      status: status ?? this.status,
      result: result ?? this.result,
    );
  }
}

enum AgentToolStatus { running, completed, error, rejected }

/// Agent 状态机
enum AgentState {
  idle,
  thinking,
  executing,
  waitingConfirm,
  done,
  error,
}

/// 确认请求
class PendingConfirmation {
  final String toolName;
  final Map<String, dynamic> args;
  final String toolCallId;
  final String description;
  final DateTime requestedAt;
  final Future<bool> Function(bool approved) respond;

  PendingConfirmation({
    required this.toolName,
    required this.args,
    required this.toolCallId,
    required this.description,
    required this.respond,
  }) : requestedAt = DateTime.now();
}

/// Agent 流式事件（sealed class）
sealed class AgentEvent {
  const AgentEvent();
}

/// 文本增量（LLM 思考输出）
class TextDeltaEvent extends AgentEvent {
  final String text;
  const TextDeltaEvent(this.text);
}

/// 工具调用开始
class ToolCallStartEvent extends AgentEvent {
  final String name;
  final Map<String, dynamic> args;
  final String toolCallId;
  const ToolCallStartEvent(this.name, this.args, this.toolCallId);
}

/// 工具调用结束
class ToolCallEndEvent extends AgentEvent {
  final String name;
  final String toolCallId;
  final String result;
  final bool success;
  const ToolCallEndEvent(
    this.name,
    this.toolCallId,
    this.result, {
    this.success = true,
  });
}

/// 等待用户确认破坏性操作
class ConfirmationRequestedEvent extends AgentEvent {
  final PendingConfirmation confirmation;
  const ConfirmationRequestedEvent(this.confirmation);
}

/// Agent 循环结束
class AgentDoneEvent extends AgentEvent {
  const AgentDoneEvent();
}

/// Agent 错误
class AgentErrorEvent extends AgentEvent {
  final String error;
  const AgentErrorEvent(this.error);
}

/// 上下文压缩事件
///
/// 在 Agent 循环自动压缩消息列表时触发，UI 可用于展示压缩提示。
class CompactionEvent extends AgentEvent {
  /// 释放的字符数
  final int removedChars;

  /// 原始字符数
  final int originalChars;

  /// 保留的消息条数
  final int keptMessageCount;

  /// 丢弃的消息条数
  final int droppedMessageCount;

  const CompactionEvent({
    required this.removedChars,
    required this.originalChars,
    required this.keptMessageCount,
    required this.droppedMessageCount,
  });

  /// 压缩率（0-1）
  double get compressionRatio =>
      originalChars > 0 ? removedChars / originalChars : 0;

  /// 友好描述
  String get description =>
      '已压缩上下文：$removedChars 字符'
      '（保留 $keptMessageCount 条，丢弃 $droppedMessageCount 条）';
}