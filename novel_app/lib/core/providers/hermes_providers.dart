import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/hermes_message.dart';
import '../../services/dsl_engine/llm_provider.dart';
import '../../services/logger_service.dart';
import '../../services/novel_agent/agent_event.dart';
import '../../services/novel_agent/agent_scenario.dart';
import '../../services/novel_agent/agent_scenario_factory.dart';
import '../../services/novel_agent/novel_agent_service.dart';
import 'agent_scenario_provider.dart';
import 'current_novel_provider.dart';
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
  /// 当前场景 ID
  final String scenarioId;
  /// 当前场景显示名
  final String scenarioDisplayName;

  // ===== 当前小说 (Agent 写作场景) =====
  /// 当前 Agent 操作的目标小说（select_novel 工具设置）
  final CurrentNovel? currentNovel;

  const HermesChatState({
    this.messages = const [],
    this.isLoading = false,
    this.streamingSegments = const [],
    this.error,
    this.scenarioId = ScenarioIds.writing,
    this.scenarioDisplayName = '小说写作助手',
    this.currentNovel,
  });

  HermesChatState copyWith({
    List<HermesMessage>? messages,
    bool? isLoading,
    List<HermesSegment>? streamingSegments,
    String? error,
    String? scenarioId,
    String? scenarioDisplayName,
    CurrentNovel? currentNovel,
    bool clearCurrentNovel = false,
  }) {
    return HermesChatState(
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

  /// 按场景 ID 缓存对话历史，切换场景时保留/恢复各自的历史
  final Map<String, List<HermesMessage>> _historyCache = {};

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
    final currentNovel = _ref.read(currentNovelProvider);

    // webview_extract 场景使用 Headless WebView（不受页面生命周期影响）
    final useHeadless =
        state.scenarioId == ScenarioIds.webviewExtract;

    return AgentScenarioContext(
      readingContext: readingContext,
      // Headless 模式下不传可见 WebView controller（由工厂从池获取）
      webviewController: useHeadless ? null : webviewController,
      currentUrl: currentUrl,
      useHeadlessWebView: useHeadless,
      currentNovelId: currentNovel?.id,
      currentNovelTitle: currentNovel?.title,
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
          // select_novel 成功后自动更新 currentNovel 状态
          if (e.success && e.name == 'select_novel') {
            _handleSelectNovelFromResult(e.result);
          }
          state = state.copyWith(
            streamingSegments: List<HermesSegment>.unmodifiable(_pendingSegments),
          );

        case CompactionEvent e:
          // 上下文压缩事件：同步裁剪 UI 端 messages
          if (e.droppedHermesRange != null) {
            final range = e.droppedHermesRange!;
            final currentMsgs = List<HermesMessage>.from(state.messages);
            if (range.start < currentMsgs.length && range.end <= currentMsgs.length) {
              currentMsgs.removeRange(range.start, range.end);
              LoggerService.instance.i(
                'Hermes UI 裁剪: 移除 messages[${range.start},${range.end}), '
                '剩余 ${currentMsgs.length} 条',
                category: LogCategory.ai,
                tags: ['provider', 'hermes', 'compaction', 'ui-trim'],
              );
              state = state.copyWith(messages: currentMsgs);
            } else {
              LoggerService.instance.w(
                'Hermes UI 裁剪越界: range=[${range.start},${range.end}), '
                'messages.length=${currentMsgs.length}, 跳过裁剪',
                category: LogCategory.ai,
                tags: ['provider', 'hermes', 'compaction', 'out-of-bounds'],
              );
            }
          } else {
            LoggerService.instance.i(
              'Hermes 收到压缩事件(无 UI 对齐): ${e.description}',
              category: LogCategory.ai,
              tags: ['provider', 'hermes', 'compaction'],
            );
          }

        case AgentDoneEvent _:
          _finalizeAgentResponse();

        case AgentErrorEvent e:
          _finalizeAgentResponse(error: e.error);
      }
    });

    // 构造历史消息（不含刚加入的 user message）
    // 关键：把 ToolCallSegment 转成 OpenAI 标准的 assistant(tool_calls) + tool 消息，
    // 否则跨回合时工具调用结果丢失，LLM 无法引用上一轮查询数据。
    //
    // 同步构造 owners：每条 history 消息对应的 HermesMessage 在 state.messages 中的索引，
    // 用于压缩时反推被丢弃的 HermesMessage 区间，通知 UI 同步裁剪。
    // assistant(tool_calls) 展开成 1 + N 条时，N 条 tool 消息共享同一个 owner（该 assistant）。
    final history = <ChatMessage>[];
    final owners = <int>[];
    for (int msgIdx = 0; msgIdx < state.messages.length; msgIdx++) {
      final m = state.messages[msgIdx];
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
          owners.add(msgIdx);
          for (final c in withResults) {
            history.add(ChatMessage(role: 'tool', content: c.result, toolCallId: c.id));
            owners.add(msgIdx); // tool 消息归属同一 assistant HermesMessage
          }
        } else {
          history.add(ChatMessage(role: m.role.name, content: m.content));
          owners.add(msgIdx);
        }
      } else {
        history.add(ChatMessage(role: m.role.name, content: m.content));
        owners.add(msgIdx);
      }
    }
    if (history.isNotEmpty && history.last.role == 'user') {
      history.removeLast();
      owners.removeLast();
    }

    // 构造场景上下文
    final scenarioContext = _buildScenarioContext();

    await agentService.sendMessage(
      userInput: userInput,
      history: history,
      scenarioId: scenarioId,
      scenarioContext: scenarioContext,
      messageOwners: owners,
    );
  }

  /// 切换场景（按场景 ID 缓存/恢复对话历史）
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

    // 同步 currentAgentScenarioProvider（手动切换时）
    _isSwitchingFromUI = true;
    _ref.read(currentAgentScenarioProvider.notifier).state = scenarioId;
    _isSwitchingFromUI = false;
    LoggerService.instance.d(
      'Hermes 手动切换场景标记已重置: scenario=$scenarioId',
      category: LogCategory.ai,
      tags: ['provider', 'hermes', 'scenario_switch', 'ui_flag'],
    );

    // 保存当前场景的对话历史，恢复目标场景的对话历史
    _historyCache[state.scenarioId] = state.messages;
    final restored = _historyCache[scenarioId] ?? const [];
    _pendingSegments.clear();
    state = HermesChatState(
      messages: restored,
      scenarioId: scenarioId,
      scenarioDisplayName: displayName,
    );
  }

  /// 切换当前小说（暴露给 UI 和 select_novel 工具使用）
  ///
  /// 工具路径：由 _onToolResult 钩子解析 ToolCallEndEvent 自动调用
  /// UI 路径：HermesNovelPickerDialog 直接调用
  Future<CurrentNovel?> selectNovel(int novelId) async {
    final novel = await selectCurrentNovel(_ref, novelId);
    if (novel != null) {
      state = state.copyWith(currentNovel: novel);
    }
    return novel;
  }

  /// 解析 select_novel 工具返回的 JSON，自动同步 currentNovel 状态
  void _handleSelectNovelFromResult(String? result) {
    if (result == null) return;
    try {
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      if (parsed['success'] != true) return;
      final novelId = parsed['novelId'] as int?;
      if (novelId == null) return;
      // 异步更新，不阻塞事件处理链路
      selectNovel(novelId);
    } catch (e) {
      // 非 JSON 结果忽略
      LoggerService.instance.e(
        '解析 select_novel 结果失败: $result',
        category: LogCategory.ai,
        tags: ['provider', 'hermes', 'select_novel', 'parse_failed'],
      );
    }
  }

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
    LoggerService.instance.i(
      'Hermes 请求已取消',
      category: LogCategory.ai,
      tags: ['provider', 'hermes', 'cancel'],
    );
    // 触发底层 Agent 循环取消：温和停止 —— 不中断当前这轮 LLM 流式输出，
    // 但 ReAct 循环不再执行后续工具、不再进入下一轮。
    // 配合 AgentLoop 的取消检查点，避免后台静默跑完 maxRounds。
    _ref.read(novelAgentServiceProvider).cancel();

    // 本地 Agent：取消事件订阅
    _agentSub?.cancel();
    _agentSub = null;

    // 保留已生成的交替 segments
    if (_pendingSegments.isNotEmpty) {
      final segmentsSnapshot = List<HermesSegment>.unmodifiable(_pendingSegments);
      final partial = HermesMessage.assistantFromSegments(segmentsSnapshot);
      final finalMessages = [...state.messages, partial];
      state = state.copyWith(
        messages: finalMessages,
        isLoading: false,
        streamingSegments: const [],
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        streamingSegments: const [],
      );
    }
    _pendingSegments.clear();
  }

  /// 清空当前场景的对话历史
  void clearConversation() {
    LoggerService.instance.i(
      'Hermes 清空对话: scenario=${state.scenarioId}',
      category: LogCategory.ai,
      tags: ['provider', 'hermes', 'clear'],
    );
    _historyCache.remove(state.scenarioId);
    _pendingSegments.clear();
    state = HermesChatState(
      scenarioId: state.scenarioId,
      scenarioDisplayName: state.scenarioDisplayName,
    );
  }

  @override
  void dispose() {
    _agentSub?.cancel();
    super.dispose();
  }
}

/// Hermes Chat Provider
///
/// StateNotifierProvider 在 Riverpod 2.x 中默认不 autoDispose，
/// 因此用户离开页面后对话历史和 Agent 任务状态会一直保持。
/// 用户切换到 APP 其他页面后返回，仍能看到之前的任务执行情况。
final hermesChatProvider =
    StateNotifierProvider<HermesChatNotifier, HermesChatState>((ref) {
  return HermesChatNotifier(ref);
});
