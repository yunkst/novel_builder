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
  /// 实时流式 segments（当前回合进行中时非空）
  final List<HermesSegment> streamingSegments;
  final String? error;

  // ===== Agent 扩展字段 (Phase 3) =====
  /// 当前是否等待用户确认
  final PendingConfirmation? pendingConfirmation;
  /// 当前场景 ID
  final String scenarioId;
  /// 当前场景显示名
  final String scenarioDisplayName;

  const HermesChatState({
    this.messages = const [],
    this.isLoading = false,
    this.streamingSegments = const [],
    this.error,
    this.pendingConfirmation,
    this.scenarioId = ScenarioIds.writing,
    this.scenarioDisplayName = '小说写作助手',
  });

  HermesChatState copyWith({
    List<HermesMessage>? messages,
    bool? isLoading,
    List<HermesSegment>? streamingSegments,
    String? error,
    PendingConfirmation? pendingConfirmation,
    bool clearPendingConfirmation = false,
    String? scenarioId,
    String? scenarioDisplayName,
  }) {
    return HermesChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      streamingSegments: streamingSegments ?? this.streamingSegments,
      error: error,
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

  /// 当前回合的 segments（私有，按事件流构建）
  /// 每个 TextDelta 追加到最后一个 TextSegment 或创建新的，
  /// 每个 ToolCallStart/ToolCallEnd 插入/更新 ToolCallSegment
  final List<HermesSegment> _pendingSegments = [];

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

    // 清除当前回合的临时状态
    _pendingSegments.clear();
    state = state.copyWith(
      messages: updatedMessages,
      isLoading: true,
      streamingSegments: const [],
      error: null,
      clearPendingConfirmation: true,
    );

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

    // 订阅事件流：按事件时序构建 segments 列表
    _agentSub = agentService.events.listen((event) {
      switch (event) {
        case TextDeltaEvent e:
          // 追加到最后一个 TextSegment，或创建新的
          if (_pendingSegments.isNotEmpty &&
              _pendingSegments.last is TextSegment) {
            final idx = _pendingSegments.length - 1;
            final last = _pendingSegments[idx] as TextSegment;
            _pendingSegments[idx] = TextSegment(last.content + e.text);
          } else {
            _pendingSegments.add(TextSegment(e.text));
          }
          state = state.copyWith(
            streamingSegments: List<HermesSegment>.unmodifiable(_pendingSegments),
          );

        case ToolCallStartEvent e:
          final call = AgentToolCall(
            id: e.toolCallId,
            name: e.name,
            arguments: e.args,
            status: AgentToolStatus.running,
          );
          _pendingSegments.add(ToolCallSegment(call));
          state = state.copyWith(
            streamingSegments: List<HermesSegment>.unmodifiable(_pendingSegments),
          );

        case ToolCallEndEvent e:
          // 找到对应 ToolCallSegment 并更新状态
          final idx = _pendingSegments.indexWhere(
            (s) => s is ToolCallSegment && s.call.id == e.toolCallId,
          );
          if (idx >= 0) {
            final old = (_pendingSegments[idx] as ToolCallSegment).call;
            _pendingSegments[idx] = ToolCallSegment(old.copyWith(
              status: e.success ? AgentToolStatus.completed : AgentToolStatus.error,
              result: e.result,
            ));
          }
          state = state.copyWith(
            streamingSegments: List<HermesSegment>.unmodifiable(_pendingSegments),
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
    // 关键：把 ToolCallSegment 转成 OpenAI 标准的 assistant(tool_calls) + tool 消息，
    // 否则跨回合时工具调用结果丢失，LLM 无法引用上一轮查询数据。
    final history = <ChatMessage>[];
    for (final m in state.messages) {
      if (m.role == HermesRole.assistant) {
        final toolCalls = m.toolCalls
            .map((c) => ToolCall(id: c.id, name: c.name, arguments: c.arguments))
            .toList();
        final withResults = m.toolCalls.where((c) => c.result != null).toList();
        if (toolCalls.isNotEmpty) {
          history.add(ChatMessage(
            role: 'assistant',
            content: m.content.isEmpty ? null : m.content,
            toolCalls: toolCalls,
          ));
          for (final c in withResults) {
            history.add(ChatMessage(role: 'tool', content: c.result, toolCallId: c.id));
          }
        } else {
          history.add(ChatMessage(role: m.role.name, content: m.content));
        }
      } else {
        history.add(ChatMessage(role: m.role.name, content: m.content));
      }
    }
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
    _pendingSegments.clear();
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
      // contentLength=0 表示 LLM 返回了空响应，需要告警
      final contentLength = _pendingContent.length;
      if (contentLength == 0) {
        LoggerService.instance.w(
          'Hermes Agent 响应完成: contentLength=0 [异常: 响应内容为空]',
          category: LogCategory.ai,
          tags: ['provider', 'hermes', 'done', 'abnormal-empty'],
        );
      } else {
        LoggerService.instance.i(
          'Hermes Agent 响应完成: contentLength=$contentLength',
          category: LogCategory.ai,
          tags: ['provider', 'hermes', 'done'],
        );
      }
    }
    final segmentsSnapshot = List<HermesSegment>.unmodifiable(_pendingSegments);
    final assistantMessage = segmentsSnapshot.isNotEmpty
        ? HermesMessage.assistantFromSegments(segmentsSnapshot)
        : null;
    final newMessages = assistantMessage != null
        ? [...state.messages, assistantMessage]
        : state.messages;

    state = state.copyWith(
      messages: newMessages,
      isLoading: false,
      streamingSegments: const [],
      error: error,
      clearPendingConfirmation: true,
    );
    _pendingSegments.clear();
  }

  /// 合并所有文本片段的临时内容（用于日志）
  String get _pendingContent => _pendingSegments
      .whereType<TextSegment>()
      .map((s) => s.content)
      .join('');

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

    // 保留已生成的交替 segments
    if (_pendingSegments.isNotEmpty) {
      final segmentsSnapshot = List<HermesSegment>.unmodifiable(_pendingSegments);
      final partial = HermesMessage.assistantFromSegments(segmentsSnapshot);
      final finalMessages = [...state.messages, partial];
      state = state.copyWith(
        messages: finalMessages,
        isLoading: false,
        streamingSegments: const [],
        clearPendingConfirmation: true,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        streamingSegments: const [],
        clearPendingConfirmation: true,
      );
    }
    _pendingSegments.clear();
  }

  /// 清空会话
  void clearConversation() {
    _pendingSegments.clear();
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
