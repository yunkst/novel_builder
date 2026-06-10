import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/hermes_message.dart';
import '../../services/dsl_engine/llm_provider.dart';
import '../../services/logger_service.dart';
import '../../services/novel_agent/agent_event.dart';
import '../../services/novel_agent/agent_scenario.dart';
import '../../services/novel_agent/agent_scenario_factory.dart';
import '../../services/novel_agent/novel_agent_service.dart';
import 'agent_scenario_provider.dart';
import 'reading_context_providers.dart';
import 'webview_providers.dart';

/// Hermes Chat 状态
class HermesChatState {
  final List<HermesMessage> messages;
  final bool isLoading;
  final String? streamingContent;
  final String? error;

  // ===== Agent 扩展字段 (Phase 3) =====
  /// 是否有待处理的工具调用（用于在消息气泡下方展示进度）
  final List<AgentToolCall> agentToolCalls;
  /// 当前是否等待用户确认
  final PendingConfirmation? pendingConfirmation;
  /// 当前场景 ID
  final String scenarioId;
  /// 当前场景显示名
  final String scenarioDisplayName;

  const HermesChatState({
    this.messages = const [],
    this.isLoading = false,
    this.streamingContent,
    this.error,
    this.agentToolCalls = const [],
    this.pendingConfirmation,
    this.scenarioId = ScenarioIds.writing,
    this.scenarioDisplayName = '小说写作助手',
  });

  HermesChatState copyWith({
    List<HermesMessage>? messages,
    bool? isLoading,
    String? streamingContent,
    String? error,
    List<AgentToolCall>? agentToolCalls,
    PendingConfirmation? pendingConfirmation,
    bool clearPendingConfirmation = false,
    String? scenarioId,
    String? scenarioDisplayName,
  }) {
    return HermesChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      streamingContent: streamingContent,
      error: error,
      agentToolCalls: agentToolCalls ?? this.agentToolCalls,
      pendingConfirmation: clearPendingConfirmation
          ? null
          : pendingConfirmation ?? this.pendingConfirmation,
      scenarioId: scenarioId ?? this.scenarioId,
      scenarioDisplayName: scenarioDisplayName ?? this.scenarioDisplayName,
    );
  }
}

/// Hermes Chat Notifier
class HermesChatNotifier extends StateNotifier<HermesChatState> {
  final Ref _ref;
  String _pendingContent = '';

  // ===== Agent 相关 (Phase 3) =====
  StreamSubscription<AgentEvent>? _agentSub;

  HermesChatNotifier(this._ref) : super(const HermesChatState()) {
    // 监听场景自动切换
    _ref.listen<String>(
      currentAgentScenarioProvider,
      (prev, next) {
        if (prev != next && !_isSwitchingFromUI) {
          _autoSwitchScenario(next);
        }
      },
    );
  }

  /// 是否正在从 UI 手动切换（避免和自动切换冲突）
  bool _isSwitchingFromUI = false;

  /// 自动切换场景（由 Provider 变化触发）
  void _autoSwitchScenario(String scenarioId) {
    final info = AgentScenarioFactory.availableScenarios
        .where((s) => s.id == scenarioId)
        .firstOrNull;
    if (info == null) return;
    switchScenario(info.id, info.displayName);
  }

  /// 发送消息
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    LoggerService.instance.d(
      'Hermes 发送消息: length=${content.length}, scenario=${state.scenarioId}',
      category: LogCategory.ai,
      tags: ['provider', 'hermes', 'send', state.scenarioId],
    );

    final userMessage = HermesMessage.user(content.trim());
    final updatedMessages = [...state.messages, userMessage];

    // 清除之前的状态
    state = state.copyWith(
      messages: updatedMessages,
      isLoading: true,
      streamingContent: null,
      error: null,
      agentToolCalls: const [],
      clearPendingConfirmation: true,
    );

    _pendingContent = '';

    try {
      await _sendViaLocalAgent(content);
    } catch (e, st) {
      LoggerService.instance.e(
        'Hermes 发送消息失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['provider', 'hermes', 'send'],
      );
      _finalizeAgentResponse(error: '发送消息失败: $e');
      rethrow;
    }
  }

  /// 构造当前场景上下文
  AgentScenarioContext _buildScenarioContext() {
    final readingContext = _ref.read(readingContextProvider);
    final webviewController = _ref.read(webviewControllerProvider);
    final currentUrl = _ref.read(webviewCurrentUrlProvider);

    return AgentScenarioContext(
      readingContext: readingContext,
      webviewController: webviewController,
      currentUrl: currentUrl,
    );
  }

  /// 本地 Agent 模式
  Future<void> _sendViaLocalAgent(String userInput) async {
    final scenarioId = state.scenarioId;
    LoggerService.instance.d(
      'Hermes 本地 Agent 模式启动 (scenario=$scenarioId)',
      category: LogCategory.ai,
      tags: ['provider', 'hermes', 'agent', scenarioId],
    );
    final agentService = _ref.read(novelAgentServiceProvider);

    // 取消之前的订阅
    await _agentSub?.cancel();

    // 订阅事件流
    _agentSub = agentService.events.listen((event) {
      switch (event) {
        case TextDeltaEvent e:
          _pendingContent += e.text;
          state = state.copyWith(streamingContent: _pendingContent);

        case ToolCallStartEvent e:
          final call = AgentToolCall(
            id: e.toolCallId,
            name: e.name,
            arguments: e.args,
            status: AgentToolStatus.running,
          );
          state = state.copyWith(
            agentToolCalls: [...state.agentToolCalls, call],
          );

        case ToolCallEndEvent e:
          state = state.copyWith(
            agentToolCalls: state.agentToolCalls.map((c) {
              if (c.id != e.toolCallId) return c;
              return c.copyWith(
                status: e.success ? AgentToolStatus.completed : AgentToolStatus.error,
                result: e.result,
              );
            }).toList(),
          );

        case ConfirmationRequestedEvent e:
          state = state.copyWith(pendingConfirmation: e.confirmation);

        case AgentDoneEvent _:
          _finalizeAgentResponse();

        case AgentErrorEvent e:
          _finalizeAgentResponse(error: e.error);
      }
    });

    // 构造历史消息（不含刚加入的 user message）
    final history = <ChatMessage>[];
    for (final m in state.messages) {
      history.add(ChatMessage(role: m.role.name, content: m.content));
    }
    // 移除最后一条（刚加入的 user message，避免重复）
    if (history.isNotEmpty && history.last.role == 'user') {
      history.removeLast();
    }

    // 构造场景上下文
    final scenarioContext = _buildScenarioContext();

    await agentService.sendMessage(
      userInput: userInput,
      history: history,
      scenarioId: scenarioId,
      scenarioContext: scenarioContext,
      requestConfirmation: _requestConfirmation,
    );
  }

  /// 切换场景（清空对话历史）
  void switchScenario(String scenarioId, String displayName) {
    if (state.scenarioId == scenarioId) return;

    LoggerService.instance.i(
      'Hermes 场景切换: ${state.scenarioId} → $scenarioId',
      category: LogCategory.ai,
      tags: ['provider', 'hermes', 'scenario-switch', scenarioId],
    );

    // 取消正在运行的 Agent
    _agentSub?.cancel();
    _agentSub = null;
    for (final c in _pendingConfirmations.values) {
      if (!c.isCompleted) c.complete(false);
    }
    _pendingConfirmations.clear();

    // 同步 currentAgentScenarioProvider（手动切换时）
    _isSwitchingFromUI = true;
    _ref.read(currentAgentScenarioProvider.notifier).state = scenarioId;
    _isSwitchingFromUI = false;

    // 清空对话历史并设置新场景
    _pendingContent = '';
    state = HermesChatState(
      scenarioId: scenarioId,
      scenarioDisplayName: displayName,
    );
  }

  /// 用户确认（暴露给 UI 层调用）
  void respondToConfirmation(bool approved) {
    final pending = state.pendingConfirmation;
    if (pending == null) return;
    pending.respond(approved);
    state = state.copyWith(clearPendingConfirmation: true);
  }

  /// 内部确认回调（供 AgentLoop 调用）
  Future<bool> _requestConfirmation(
    String toolName,
    Map<String, dynamic> args,
    String toolCallId,
  ) async {
    final completer = Completer<bool>();
    _pendingConfirmations[toolCallId] = completer;

    try {
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => false, // 30s 超时自动拒绝
      );
    } finally {
      _pendingConfirmations.remove(toolCallId);
    }
  }

  final Map<String, Completer<bool>> _pendingConfirmations = {};

  void _finalizeAgentResponse({String? error}) {
    if (error != null) {
      LoggerService.instance.e(
        'Hermes Agent 错误: $error',
        category: LogCategory.ai,
        tags: ['provider', 'hermes', 'agent-error'],
      );
    } else {
      LoggerService.instance.i(
        'Hermes Agent 响应完成: contentLength=${_pendingContent.length}',
        category: LogCategory.ai,
        tags: ['provider', 'hermes', 'done'],
      );
    }
    final assistantMessage = _pendingContent.isNotEmpty
        ? HermesMessage.assistant(_pendingContent)
        : null;
    final newMessages = assistantMessage != null
        ? [...state.messages, assistantMessage]
        : state.messages;

    state = state.copyWith(
      messages: newMessages,
      isLoading: false,
      streamingContent: null,
      error: error,
      clearPendingConfirmation: true,
    );
    _pendingContent = '';
  }

  /// 停止当前生成
  void cancelRequest() {
    // 本地 Agent：取消事件订阅
    _agentSub?.cancel();
    _agentSub = null;

    // 完成所有未确认的请求（视为拒绝）
    for (final c in _pendingConfirmations.values) {
      if (!c.isCompleted) c.complete(false);
    }
    _pendingConfirmations.clear();

    // 保留已生成内容
    if (_pendingContent.isNotEmpty) {
      final assistantMessage = HermesMessage.assistant(_pendingContent);
      final finalMessages = [...state.messages, assistantMessage];
      state = state.copyWith(
        messages: finalMessages,
        isLoading: false,
        streamingContent: null,
        agentToolCalls: const [],
        clearPendingConfirmation: true,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        streamingContent: null,
        agentToolCalls: const [],
        clearPendingConfirmation: true,
      );
    }
    _pendingContent = '';
  }

  /// 清空会话
  void clearConversation() {
    _pendingContent = '';
    state = HermesChatState(
      scenarioId: state.scenarioId,
      scenarioDisplayName: state.scenarioDisplayName,
    );
  }

  @override
  void dispose() {
    _agentSub?.cancel();
    for (final c in _pendingConfirmations.values) {
      if (!c.isCompleted) c.complete(false);
    }
    super.dispose();
  }
}

/// Hermes Chat Provider (keepAlive 保持全局状态)
final hermesChatProvider =
    StateNotifierProvider<HermesChatNotifier, HermesChatState>((ref) {
  return HermesChatNotifier(ref);
});
