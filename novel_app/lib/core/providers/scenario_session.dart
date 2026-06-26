/// 场景会话 — 每个 scenarioId 对应一个独立运行时
///
/// 参考 Hermes Agent 的三层隔离模型：
/// 1. AIAgent 实例隔离（每个 session_key 独立的 AIAgent）
/// 2. 独立事件流（每个会话有自己的 StreamConsumer）
/// 3. 会话状态机（fresh → active → idle → expired → finalized）
///
/// 在 Flutter 单线程环境中，不需要 ContextVar（Dart 没有进程全局变量问题）
/// 和线程局部中断（已有 CancellationToken），但核心思想 1:1 映射：
/// - 每个 scenarioId → 独立的 ScenarioSession
/// - 每个 ScenarioSession 有自己的 _pendingSegments、_agentSub、CancellationToken
/// - 切场景不杀 Agent，只是 UI 切到另一个 session 的视图
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/hermes_message.dart';
import '../../services/logger_service.dart';
import '../../services/novel_agent/agent_event.dart';
import '../../services/novel_agent/agent_scenario.dart';
import '../../services/novel_agent/agent_scenario_factory.dart';
import '../../services/novel_agent/novel_agent_service.dart';
import '../../services/dsl_engine/llm_provider.dart' show ChatMessage, ToolCall;
import '../../utils/cancellation_token.dart';
import 'current_novel_provider.dart';
import 'hermes_chat_state.dart';
import 'reading_context_providers.dart';
import 'webview_providers.dart';

/// 场景会话生命周期状态
///
/// 对应 Hermes 的 SessionEntry 状态机（简化版）：
/// fresh → active → idle → disposed
enum SessionLifecycle {
  /// 刚创建，尚未使用
  fresh,

  /// 正在运行（Agent 活跃）
  active,

  /// Agent 完成，等待下次使用
  idle,

  /// 已销毁（LRU 淘汰或手动关闭）
  disposed,
}

/// 场景会话 — 每个场景的独立运行时
///
/// 核心设计：
/// - 切场景不杀 Agent，只是 UI 切到另一个 session 的视图
/// - 每个 session 有独立的 _pendingSegments / _agentSub / CancellationToken
/// - 切回 A 场景时，能看到 A 上次对话的结果（即使 Agent 还在跑）
class ScenarioSession {
  final String scenarioId;
  final Ref _ref;

  // ===== 对应 Hermes 的 "AIAgent 实例状态" =====
  bool _isRunning = false;
  CancellationToken? _currentToken;

  // ===== 对应 Hermes 的 "per-session pending segments" =====
  final List<HermesSegment> _pendingSegments = [];

  // ===== 对应 Hermes 的 "独立事件订阅" =====
  StreamSubscription<AgentEvent>? _agentSub;

  // ===== 会话状态 =====
  late HermesChatState _state;
  SessionLifecycle _lifecycle = SessionLifecycle.fresh;

  // ===== 当前小说（按 Session 隔离） =====
  CurrentNovel? _currentNovel;

  // ===== 状态变更通知回调 =====
  VoidCallback? _onStateChanged;

  ScenarioSession({
    required this.scenarioId,
    required Ref ref,
  }) : _ref = ref {
    final info = AgentScenarioFactory.availableScenarios
        .where((s) => s.id == scenarioId)
        .firstOrNull;
    _state = HermesChatState(
      scenarioId: scenarioId,
      scenarioDisplayName: info?.displayName ?? scenarioId,
    );
  }

  // ===== 公开接口 =====

  /// 当前状态（只读视图，给 UI watch）
  HermesChatState get state => _state;

  /// 是否正在运行 Agent
  bool get isRunning => _isRunning;

  /// 会话生命周期
  SessionLifecycle get lifecycle => _lifecycle;

  /// 当前小说（本 session 独享）
  CurrentNovel? get currentNovel => _currentNovel;

  /// 设置状态变更通知回调
  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  /// 发送消息 — Agent 在本 session 内独立运行
  ///
  /// 同 session 内串行（上一个还在跑时拒绝新请求），但不同 session 之间并行。
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    if (_isRunning) {
      LoggerService.instance.w(
        'ScenarioSession [$scenarioId] 拒绝请求（已在运行中）',
        category: LogCategory.ai,
        tags: ['session', 'busy', scenarioId],
      );
      _notifyStateError('当前场景正在运行中，请稍后再试');
      return;
    }

    _lifecycle = SessionLifecycle.active;
    _isRunning = true;
    _currentToken = CancellationToken();
    _pendingSegments.clear();

    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 发送消息: length=${content.length}',
      category: LogCategory.ai,
      tags: ['session', 'send', scenarioId],
    );

    final userMessage = HermesMessage.user(content.trim());
    final updatedMessages = [..._state.messages, userMessage];

    _state = _state.copyWith(
      messages: updatedMessages,
      isLoading: true,
      streamingSegments: const [],
      error: null,
    );
    _notifyStateChanged();

    try {
      await _runAgent(content);
    } catch (e, st) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] 发送消息失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['session', 'send', scenarioId],
      );
      _finalizeAgentResponse(error: '发送消息失败: $e');
    }
  }

  /// 取消本 session 的 Agent（不影响其他 session）
  ///
  /// 对应 Hermes 的线程局部中断：只中断目标线程，不误杀其他会话。
  void cancel() {
    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 请求已取消',
      category: LogCategory.ai,
      tags: ['session', 'cancel', scenarioId],
    );

    // 触发底层 Agent 循环取消
    if (_currentToken != null) {
      _currentToken!.cancel(reason: '用户主动取消');
      _currentToken = null;
    }

    // 取消事件订阅
    _agentSub?.cancel();
    _agentSub = null;

    // 保留已生成的 partial segments
    if (_pendingSegments.isNotEmpty) {
      final segmentsSnapshot = List<HermesSegment>.unmodifiable(_pendingSegments);
      final partial = HermesMessage.assistantFromSegments(segmentsSnapshot);
      _state = _state.copyWith(
        messages: [..._state.messages, partial],
        isLoading: false,
        streamingSegments: const [],
      );
    } else {
      _state = _state.copyWith(
        isLoading: false,
        streamingSegments: const [],
      );
    }

    _pendingSegments.clear();
    _isRunning = false;
    _lifecycle = SessionLifecycle.idle;
    _notifyStateChanged();
  }

  /// 切换当前小说（本 session 独享）
  Future<CurrentNovel?> selectNovel(int novelId) async {
    final novel = await selectCurrentNovel(_ref, novelId);
    if (novel != null) {
      _currentNovel = novel;
      _state = _state.copyWith(currentNovel: novel);
      _notifyStateChanged();
    }
    return novel;
  }

  /// 清空对话（保留场景和小说上下文）
  void clearConversation() {
    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 清空对话',
      category: LogCategory.ai,
      tags: ['session', 'clear', scenarioId],
    );
    _pendingSegments.clear();

    // 清空时保留 scenarioId / displayName / currentNovel
    _state = HermesChatState(
      scenarioId: scenarioId,
      scenarioDisplayName: _state.scenarioDisplayName,
      currentNovel: _currentNovel,
    );
    _notifyStateChanged();
  }

  /// 销毁 session（对应 Hermes 的 session finalized）
  void dispose() {
    _agentSub?.cancel();
    _agentSub = null;
    _currentToken = null;
    _lifecycle = SessionLifecycle.disposed;
  }

  // ===== 内部实现 =====

  /// 运行 Agent — 订阅全局 AgentService 的事件流，只更新本 session 的状态
  Future<void> _runAgent(String userInput) async {
    final agentService = _ref.read(novelAgentServiceProvider);

    // 取消之前的订阅（同一 session 内串行，前一个应该已经结束）
    await _agentSub?.cancel();

    // 订阅事件流：按事件时序构建本 session 的 segments 列表
    _agentSub = agentService.events.listen(_handleAgentEvent);

    // 构造历史消息
    final history = _buildHistory();
    final owners = _buildOwners();

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

  /// 处理 Agent 事件 — 只更新本 session 的 _pendingSegments
  ///
  /// 关键隔离设计：每个 session 有独立的 _pendingSegments，
  /// 不会与其他 session 的流式数据混在一起。
  void _handleAgentEvent(AgentEvent event) {
    switch (event) {
      case TextDeltaEvent e:
        if (_pendingSegments.isNotEmpty &&
            _pendingSegments.last is TextSegment) {
          final idx = _pendingSegments.length - 1;
          final last = _pendingSegments[idx] as TextSegment;
          _pendingSegments[idx] = TextSegment(last.content + e.text);
        } else {
          _pendingSegments.add(TextSegment(e.text));
        }
        _state = _state.copyWith(
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
        _state = _state.copyWith(
          streamingSegments: List<HermesSegment>.unmodifiable(_pendingSegments),
        );

      case ToolCallEndEvent e:
        final idx = _pendingSegments.indexWhere(
          (s) => s is ToolCallSegment && s.call.id == e.toolCallId,
        );
        if (idx >= 0) {
          final old = (_pendingSegments[idx] as ToolCallSegment).call;
          _pendingSegments[idx] = ToolCallSegment(old.copyWith(
            status:
                e.success ? AgentToolStatus.completed : AgentToolStatus.error,
            result: e.result,
          ));
        }
        if (e.success && e.name == 'select_novel') {
          _handleSelectNovelFromResult(e.result);
        }
        _state = _state.copyWith(
          streamingSegments: List<HermesSegment>.unmodifiable(_pendingSegments),
        );

      case CompactionEvent e:
        _handleCompaction(e);

      case AgentDoneEvent _:
        _finalizeAgentResponse();

      case AgentErrorEvent e:
        _finalizeAgentResponse(error: e.error);
    }
    _notifyStateChanged();
  }

  /// 完成 Agent 响应 — 将 _pendingSegments 合入 messages
  void _finalizeAgentResponse({String? error}) {
    if (error != null) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] Agent 错误: $error',
        category: LogCategory.ai,
        tags: ['session', 'agent-error', scenarioId],
      );
    }

    final segmentsSnapshot = List<HermesSegment>.unmodifiable(_pendingSegments);
    final assistantMessage = segmentsSnapshot.isNotEmpty
        ? HermesMessage.assistantFromSegments(segmentsSnapshot)
        : null;
    final newMessages = assistantMessage != null
        ? [..._state.messages, assistantMessage]
        : _state.messages;

    _state = _state.copyWith(
      messages: newMessages,
      isLoading: false,
      streamingSegments: const [],
      error: error,
    );
    _pendingSegments.clear();
    _isRunning = false;
    _currentToken = null;
    _agentSub?.cancel();
    _agentSub = null;
    _lifecycle = SessionLifecycle.idle;
    _notifyStateChanged();
  }

  /// 解析 select_novel 工具返回的 JSON，自动同步 currentNovel
  void _handleSelectNovelFromResult(String? result) {
    if (result == null) return;
    try {
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      if (parsed['success'] != true) return;
      final novelId = parsed['novelId'] as int?;
      if (novelId == null) return;
      selectNovel(novelId);
    } catch (e) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] 解析 select_novel 结果失败: $result',
        category: LogCategory.ai,
        tags: ['session', 'select_novel', 'parse_failed', scenarioId],
      );
    }
  }

  /// 处理上下文压缩事件 — 同步裁剪本 session 的 messages
  void _handleCompaction(CompactionEvent e) {
    if (e.droppedHermesRange != null) {
      final range = e.droppedHermesRange!;
      final currentMsgs = List<HermesMessage>.from(_state.messages);
      if (range.start < currentMsgs.length && range.end <= currentMsgs.length) {
        currentMsgs.removeRange(range.start, range.end);
        LoggerService.instance.i(
          'ScenarioSession [$scenarioId] UI 裁剪: 移除 messages[${range.start},${range.end}), '
          '剩余 ${currentMsgs.length} 条',
          category: LogCategory.ai,
          tags: ['session', 'compaction', 'ui-trim', scenarioId],
        );
        _state = _state.copyWith(messages: currentMsgs);
      } else {
        LoggerService.instance.w(
          'ScenarioSession [$scenarioId] UI 裁剪越界: range=[${range.start},${range.end}), '
          'messages.length=${currentMsgs.length}, 跳过裁剪',
          category: LogCategory.ai,
          tags: ['session', 'compaction', 'out-of-bounds', scenarioId],
        );
      }
    } else {
      LoggerService.instance.i(
        'ScenarioSession [$scenarioId] 收到压缩事件(无 UI 对齐): ${e.description}',
        category: LogCategory.ai,
        tags: ['session', 'compaction', scenarioId],
      );
    }
  }

  /// 通知 UI 状态变更
  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  /// 通知 UI 错误（不中断运行）
  void _notifyStateError(String error) {
    _state = _state.copyWith(error: error);
    _notifyStateChanged();
  }

  // ===== 构造辅助方法 =====

  /// 构造当前场景上下文
  AgentScenarioContext _buildScenarioContext() {
    final readingContext = _ref.read(readingContextProvider);
    final webviewController = _ref.read(webviewControllerProvider);
    final currentUrl = _ref.read(webviewCurrentUrlProvider);

    final useHeadless = scenarioId == ScenarioIds.webviewExtract;

    return AgentScenarioContext(
      readingContext: readingContext,
      webviewController: useHeadless ? null : webviewController,
      currentUrl: currentUrl,
      useHeadlessWebView: useHeadless,
      currentNovelId: _currentNovel?.id,
      currentNovelTitle: _currentNovel?.title,
    );
  }

  /// 构造 LLM 历史消息
  List<ChatMessage> _buildHistory() {
    final history = <ChatMessage>[];
    for (final m in _state.messages) {
      if (m.role == HermesRole.assistant) {
        final toolCalls = m.toolCalls
            .map(
                (c) => ToolCall(id: c.id, name: c.name, arguments: c.arguments))
            .toList();
        final withResults =
            m.toolCalls.where((c) => c.result != null).toList();
        if (toolCalls.isNotEmpty) {
          history.add(ChatMessage(
            role: 'assistant',
            content: m.content.isEmpty ? null : m.content,
            toolCalls: toolCalls,
          ));
          for (final c in withResults) {
            history.add(ChatMessage(
                role: 'tool', content: c.result, toolCallId: c.id));
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
    return history;
  }

  /// 构造 messageOwners（用于压缩时 UI 对齐）
  List<int> _buildOwners() {
    final owners = <int>[];
    for (int msgIdx = 0; msgIdx < _state.messages.length; msgIdx++) {
      final m = _state.messages[msgIdx];
      if (m.role == HermesRole.assistant) {
        final toolCalls = m.toolCalls;
        if (toolCalls.isNotEmpty) {
          owners.add(msgIdx);
          for (final _ in toolCalls.where((c) => c.result != null)) {
            owners.add(msgIdx);
          }
        } else {
          owners.add(msgIdx);
        }
      } else {
        owners.add(msgIdx);
      }
    }
    if (owners.isNotEmpty && _state.messages.isNotEmpty &&
        _state.messages.last.role == HermesRole.user) {
      owners.removeLast();
    }
    return owners;
  }
}
