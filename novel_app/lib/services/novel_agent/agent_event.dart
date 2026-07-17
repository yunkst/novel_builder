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
  // running 期间已生成的字符数（流式进度），落库前应清为 null。
  // 仅 create_chapter / update_chapter_content 这类内部走 LLM 流式的工具会写入。
  final int? progressChars;

  const AgentToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.status = AgentToolStatus.running,
    this.result,
    this.progressChars,
  });

  AgentToolCall copyWith({
    AgentToolStatus? status,
    String? result,
    int? progressChars,
    // copyWith 的 null 语义二义性：progressChars: null 既可能表示"不变"也可能表示"清空"。
    // 这里默认 null = 不变（被 ?? this.progressChars 覆盖）；需要清空时传 clearProgress: true。
    bool clearProgress = false,
  }) {
    return AgentToolCall(
      id: id,
      name: name,
      arguments: arguments,
      status: status ?? this.status,
      result: result ?? this.result,
      progressChars:
          clearProgress ? null : (progressChars ?? this.progressChars),
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
  /// 运行实例标识。null = 主 Agent 旧路径；非 null = 某次 dispatch_subagent 派出的子 Agent。
  /// 由 NovelAgentService/SubagentRunner 在 emit 包装时注入。
  /// ⚠️ 未来新增 AgentEvent 子类时，必须同步加可选命名参数 `runId` 并转发给 super，
  /// 否则该事件无法被 EventTagger 打标、会导致事件隔离失效。
  final String? runId;
  const AgentEvent({this.runId});
}

/// 文本增量（LLM 思考输出）
class TextDeltaEvent extends AgentEvent {
  final String text;
  const TextDeltaEvent(this.text, {super.runId});
}

/// 工具调用开始
class ToolCallStartEvent extends AgentEvent {
  final String name;
  final Map<String, dynamic> args;
  final String toolCallId;
  const ToolCallStartEvent(this.name, this.args, this.toolCallId,
      {super.runId});
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
    super.runId,
  });
}

/// 工具调用进度（流式生成中）
///
/// 由内部走 LLM 流式的工具（如 create_chapter / update_chapter_content）在生成正文时
/// 逐 chunk 上报已生成字符数。AgentLoop 节流后 emit，UI 据此在工具卡片 running 态
/// 显示「已生成 N 字」。完成后由 ToolCallEndEvent 把卡片切到 completed。
class ToolProgressEvent extends AgentEvent {
  final String toolCallId;
  final int generatedChars;
  const ToolProgressEvent(this.toolCallId, this.generatedChars,
      {super.runId});
}

/// Agent 循环结束
class AgentDoneEvent extends AgentEvent {
  const AgentDoneEvent({super.runId});
}

/// Agent 错误
class AgentErrorEvent extends AgentEvent {
  final String error;
  const AgentErrorEvent(this.error, {super.runId});
}

/// 运行中注入的 user 补充消息
///
/// 触发场景：用户在运行中（agent 已发首轮 user 但 loop 还在跑）追加新消息。
/// 与普通 sendMessage 的差别：不打断当前 LLM stream / 当前 tool 调用，
/// 在 AgentLoop 检查点 A 边界被 drain 到 messages 里供下一轮 LLM 看到。
///
/// [scenarioId] 标识触发 inject 的场景，避免跨 scenario 的 broadcast 流把
/// 计数加到错误 session 的状态里（每个 ScenarioSession 都会监听 events 流）。
///
/// UI 用 [text] 渲染"已补充 X 条"提示；ScenarioSession 拿到这个事件 +1
/// supplementaryCount（仅当 [scenarioId] 匹配本 session 的 _state.scenarioId），
/// 便于"恢复 sendMessage 时清零"。
class InjectedUserInputEvent extends AgentEvent {
  final String text;
  final String? scenarioId;

  const InjectedUserInputEvent(
    this.text, {
    this.scenarioId,
    super.runId,
  });
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
    super.runId,
  });

  /// 压缩率（0-1）
  double get compressionRatio =>
      originalChars > 0 ? removedChars / originalChars : 0;

  /// 友好描述
  String get description =>
      '已压缩上下文：$removedChars 字符'
      '（保留 $keptMessageCount 条，丢弃 $droppedMessageCount 条）';
}