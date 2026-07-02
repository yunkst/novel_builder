/// Agent Chat 状态定义
///
/// 独立文件，避免 agent_chat_providers.dart 和 scenario_sessions_provider.dart
/// 之间的循环依赖。
library;

import '../../models/agent_chat_message.dart';
import '../../services/novel_agent/agent_scenario.dart';
import 'current_novel_provider.dart';

/// Agent Chat 状态
class AgentChatState {
  final List<AgentChatMessage> messages;
  final bool isLoading;
  /// 实时流式 segments（当前回合进行中时非空）
  final List<AgentChatSegment> streamingSegments;
  final String? error;

  // ===== Agent 扩展字段 =====
  /// 当前场景 ID
  final String scenarioId;
  /// 当前场景显示名
  final String scenarioDisplayName;

  // ===== 当前小说 (Agent 写作场景) =====
  /// 当前 Agent 操作的目标小说（select_novel 工具设置）
  final CurrentNovel? currentNovel;

  const AgentChatState({
    this.messages = const [],
    this.isLoading = false,
    this.streamingSegments = const [],
    this.error,
    this.scenarioId = ScenarioIds.writing,
    this.scenarioDisplayName = '小说写作助手',
    this.currentNovel,
  });

  AgentChatState copyWith({
    List<AgentChatMessage>? messages,
    bool? isLoading,
    List<AgentChatSegment>? streamingSegments,
    String? error,
    String? scenarioId,
    String? scenarioDisplayName,
    CurrentNovel? currentNovel,
    bool clearCurrentNovel = false,
  }) {
    return AgentChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      streamingSegments: streamingSegments ?? this.streamingSegments,
      error: error,
      scenarioId: scenarioId ?? this.scenarioId,
      scenarioDisplayName: scenarioDisplayName ?? this.scenarioDisplayName,
      currentNovel:
          clearCurrentNovel ? null : (currentNovel ?? this.currentNovel),
    );
  }
}
