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
  done,
  error,
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
  final String result; // 截断版（给 LLM 看，受 toolResultMaxChars 限制）
  final String? fullResult; // 未截断原始结果（给 DB 持久化，hydrate 续聊时 LLM 看到完整结果）
  final bool success;
  const ToolCallEndEvent(
    this.name,
    this.toolCallId,
    this.result, {
    this.fullResult,
    this.success = true,
  });
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
/// 在 Agent 循环自动压缩消息列表时触发。ScenarioSession 据此同步裁剪内存 + 删 DB。
class CompactionEvent extends AgentEvent {
  /// 释放的字符数
  final int removedChars;

  /// 原始字符数
  final int originalChars;

  /// 保留的消息条数
  final int keptMessageCount;

  /// 丢弃的消息条数
  final int droppedMessageCount;

  /// agent 内部 messages 中被丢弃的起始索引 [0, droppedAgentFromIndex)
  ///
  /// v32 起 DB 也存 agent 消息，ScenarioSession 收到本事件后：
  /// 1. 内存 _agentMessages.removeRange(0, droppedAgentFromIndex)
  /// 2. DB deleteMessagesBefore(sessionId, droppedAgentFromIndex)
  /// 内存与 DB 同步裁剪，跨会话不再"复活"已压缩内容。
  final int droppedAgentFromIndex;

  const CompactionEvent({
    required this.removedChars,
    required this.originalChars,
    required this.keptMessageCount,
    required this.droppedMessageCount,
    required this.droppedAgentFromIndex,
  });

  /// 压缩率（0-1）
  double get compressionRatio =>
      originalChars > 0 ? removedChars / originalChars : 0;

  /// 友好描述
  String get description =>
      '已压缩上下文：$removedChars 字符'
      '（保留 $keptMessageCount 条，丢弃 $droppedMessageCount 条）';
}