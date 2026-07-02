/// 场景会话 — 每个 scenarioId 对应一个独立运行时
///
/// v32 统一历史模型：
/// - 内部以 agent 视角的 `List<ChatMessage>`（_agentMessages）为真理源，
///   含完整 ReAct 链（system/user/assistant/tool）。
/// - DB 直接存 agent ChatMessage（chat_messages 表 v32），hydrate 时 1:1 还原。
/// - UI 通过 _projectUiMessages 把 agent messages 投影为 AgentChatMessage（含 segments）。
/// - 落库时机：user 消息即时落库；assistant 回合（含 tool 调用/结果）在
///   AgentDoneEvent/cancel 时从 _pendingSegments 重建并批量落库。
/// - 压缩 / retry / rollback 同步删 DB（deleteMessagesBefore），保证内存与 DB 一致。
///
/// 隔离设计（保留）：
/// - 每个 scenarioId → 独立的 ScenarioSession
/// - 每个 ScenarioSession 有自己的 _pendingSegments、_agentSub、CancellationToken
/// - 切场景不杀 Agent，只是 UI 切到另一个 session 的视图
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/agent_chat_message.dart';
import '../../models/chat_session.dart';
import '../../models/chat_message_record.dart';
import '../../services/logger_service.dart';
import '../../services/novel_agent/agent_event.dart';
import '../../services/novel_agent/agent_scenario.dart';
import '../../services/novel_agent/agent_scenario_factory.dart';
import '../../services/novel_agent/novel_agent_service.dart';
import '../../services/dsl_engine/llm_provider.dart' show ChatMessage, ToolCall;
import '../../utils/cancellation_token.dart';
import 'chat_session_providers.dart';
import 'current_novel_provider.dart';
import 'database_providers.dart';
import 'agent_chat_state.dart';
import 'reading_context_providers.dart';
import 'webview_providers.dart';

/// 场景会话生命周期状态
enum SessionLifecycle {
  fresh,
  active,
  idle,
  disposed,
}

/// 场景会话 — 每个场景的独立运行时
class ScenarioSession {
  final String scenarioId;
  final Ref _ref;

  /// 当前会话 id（可空：用户从未建过 session / 还没从 DB 选中）
  int? _sessionId;
  int? get sessionId => _sessionId;

  // ===== agent 视角历史（v32 真理源）=====
  /// 完整 ReAct 链：system(运行时注入不存)/user/assistant/tool。
  /// hydrate 时从 DB 1:1 还原；运行时由 agent 事件流增量更新。
  final List<ChatMessage> _agentMessages = [];

  // ===== 运行时状态 =====
  bool _isRunning = false;
  CancellationToken? _currentToken;
  final List<AgentChatSegment> _pendingSegments = [];
  StreamSubscription<AgentEvent>? _agentSub;

  // ===== 会话状态 =====
  late AgentChatState _state;
  SessionLifecycle _lifecycle = SessionLifecycle.fresh;

  // ===== 当前小说（按 Session 隔离）=====
  CurrentNovel? _currentNovel;

  // ===== 状态变更通知回调 =====
  VoidCallback? _onStateChanged;

  ScenarioSession({
    required this.scenarioId,
    required Ref ref,
    int? initialSessionId,
  })  : _ref = ref,
        _sessionId = initialSessionId {
    final info = AgentScenarioFactory.availableScenarios
        .where((s) => s.id == scenarioId)
        .firstOrNull;
    _state = AgentChatState(
      scenarioId: scenarioId,
      scenarioDisplayName: info?.displayName ?? scenarioId,
    );
  }

  /// UI 视图消息：从 _agentMessages 投影出 user/assistant（含 segments）。
  List<AgentChatMessage> get _uiMessages => _projectUiMessages(_agentMessages);

  /// 投影：agent ChatMessage 列表 → UI AgentChatMessage 列表
  ///
  /// 规则：
  /// - system：跳过（含压缩提示，不展示）
  /// - user：直接转 AgentChatMessage.user
  /// - assistant：收集紧跟其后、toolCallId 匹配的 tool 消息作为 ToolCallSegment
  /// - tool：已被前一个 assistant 吸收，跳过
  static List<AgentChatMessage> _projectUiMessages(List<ChatMessage> agentMsgs) {
    final ui = <AgentChatMessage>[];
    for (var i = 0; i < agentMsgs.length; i++) {
      final m = agentMsgs[i];
      switch (m.role) {
        case 'system':
          continue;
        case 'user':
          ui.add(AgentChatMessage.user(m.content ?? ''));
          break;
        case 'assistant':
          final segments = <AgentChatSegment>[];
          if (m.content != null && m.content!.isNotEmpty) {
            segments.add(TextSegment(m.content!));
          }
          for (final tc in m.toolCalls ?? const <ToolCall>[]) {
            final toolMsg = _findToolResult(agentMsgs, i, tc.id);
            segments.add(ToolCallSegment(AgentToolCall(
              id: tc.id,
              name: tc.name,
              arguments: tc.arguments,
              status: toolMsg != null
                  ? AgentToolStatus.completed
                  : AgentToolStatus.running,
              result: toolMsg?.content,
            )));
          }
          ui.add(AgentChatMessage.assistantFromSegments(segments));
          break;
        case 'tool':
          // 已被 assistant 吸收
          break;
        default:
          break;
      }
    }
    return ui;
  }

  /// 从 fromIndex+1 开始找 role='tool' 且 toolCallId 匹配的消息
  static ChatMessage? _findToolResult(
      List<ChatMessage> msgs, int fromIndex, String toolCallId) {
    for (var i = fromIndex + 1; i < msgs.length; i++) {
      final m = msgs[i];
      if (m.role == 'tool' && m.toolCallId == toolCallId) return m;
      if (m.role == 'assistant' || m.role == 'user') break;
    }
    return null;
  }

  /// 由 ScenarioSessionsNotifier 在 UI 切换 sessionId 时调用。仅在确实改变时清空并重新 hydrate。
  void adoptSession(int? newSessionId) {
    if (_sessionId == newSessionId) return;
    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 切换 sessionId $_sessionId → $newSessionId',
      category: LogCategory.ai,
      tags: ['session', 'switch', scenarioId],
    );
    _sessionId = newSessionId;
    _pendingSegments.clear();
    _agentMessages.clear();
    _state = _state.copyWith(
      messages: const [],
      isLoading: false,
      streamingSegments: const [],
      error: null,
      clearCurrentNovel: true,
    );
    _currentNovel = null;
    _lifecycle = SessionLifecycle.fresh;
    _notifyStateChanged();
  }

  /// 如果 _sessionId 不为空且 _agentMessages 为空，主动从 DB 加载。
  Future<void> hydrateIfNeeded() async {
    final sid = _sessionId;
    if (sid == null) return;
    if (_agentMessages.isNotEmpty) return;
    try {
      final repo = _ref.read(chatSessionRepositoryProvider);
      final session = await repo.getSession(sid);
      if (session == null) {
        LoggerService.instance.w(
          'ScenarioSession [$scenarioId] hydrate 失败：sessionId=$sid 不存在',
          category: LogCategory.ai,
          tags: ['session', 'hydrate', 'missing', scenarioId],
        );
        return;
      }
      final records = await repo.listMessages(sid);
      _agentMessages.clear();
      for (final r in records) {
        _agentMessages.add(r.toAgentMessage());
      }
      _state = _state.copyWith(
        messages: _uiMessages,
        clearCurrentNovel: true,
        scenarioDisplayName: _state.scenarioDisplayName,
      );
      _currentNovel = null;
      LoggerService.instance.i(
        'ScenarioSession [$scenarioId] hydrate sessionId=$sid → ${_agentMessages.length} 条 agent 消息',
        category: LogCategory.ai,
        tags: ['session', 'hydrate', 'success', scenarioId],
      );
      _notifyStateChanged();
    } catch (e, st) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] hydrate 失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['session', 'hydrate', 'failed', scenarioId],
      );
    }
  }

  /// 冷启动用：sessionId 未知时选最近 session 再 hydrate。
  Future<void> hydrateFromRecentIfNeeded() => _resolveSessionId(autoCreate: false);

  Future<void> _resolveSessionId({required bool autoCreate}) async {
    if (_sessionId != null) {
      await hydrateIfNeeded();
      return;
    }
    if (!autoCreate && _agentMessages.isNotEmpty) return;
    try {
      final repo = _ref.read(chatSessionRepositoryProvider);
      final list = await repo.listSessionsByScenario(scenarioId, limit: 1);
      if (list.isNotEmpty) {
        _sessionId = list.first.id;
        _ref.read(currentChatSessionIdProvider.notifier).state = _sessionId;
        LoggerService.instance.i(
          'ScenarioSession [$scenarioId] 复用最近 session id=$_sessionId',
          category: LogCategory.ai,
          tags: ['session', 'reuse', scenarioId],
        );
        await hydrateIfNeeded();
        return;
      }
      if (!autoCreate) return;
      final id = await repo.createSession(ChatSession(
        scenarioId: scenarioId,
        title: '',
        currentNovelId: _currentNovel?.id,
        currentNovelTitle: _currentNovel?.title,
      ));
      _sessionId = id;
      _ref.read(currentChatSessionIdProvider.notifier).state = id;
      LoggerService.instance.i(
        'ScenarioSession [$scenarioId] 新建 session id=$id',
        category: LogCategory.ai,
        tags: ['session', 'create', scenarioId],
      );
    } catch (e, st) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] _resolveSessionId 失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['session', 'resolve_id', 'failed', scenarioId],
      );
    }
  }

  Future<void> _ensureSessionId() => _resolveSessionId(autoCreate: true);

  AgentChatState get state => _state;
  bool get isRunning => _isRunning;
  SessionLifecycle get lifecycle => _lifecycle;
  CurrentNovel? get currentNovel => _currentNovel;

  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  /// 发送消息 — Agent 在本 session 内独立运行
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

    await _ensureSessionId();

    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 发送消息: length=${content.length} sessionId=$_sessionId',
      category: LogCategory.ai,
      tags: ['session', 'send', scenarioId],
    );

    // user 消息即时进 _agentMessages + 落库
    final userMsg = ChatMessage(role: 'user', content: content.trim());
    _agentMessages.add(userMsg);
    _state = _state.copyWith(
      messages: _uiMessages,
      isLoading: true,
    );
    _notifyStateChanged();
    await _persistAgentMessage(userMsg);

    await _beginAgentRun(content.trim());
  }

  /// 启动一轮 Agent 回合
  Future<void> _beginAgentRun(String userInput) async {
    _lifecycle = SessionLifecycle.active;
    _isRunning = true;
    _currentToken = CancellationToken();
    _pendingSegments.clear();

    _state = _state.copyWith(
      isLoading: true,
      streamingSegments: const [],
      error: null,
    );
    _notifyStateChanged();

    try {
      await _runAgent(userInput);
    } catch (e, st) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] Agent 启动失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['session', 'agent_run', 'failed', scenarioId],
      );
      _finalizeAgentResponse(error: 'Agent 启动失败: $e');
    }
  }

  /// 重试上次失败的 Agent 回合。
  ///
  /// 找到 _agentMessages 里最后一条 user，删除其后所有消息（含 tool/assistant），
  /// 同步删 DB，然后用该 user 的 content 重新触发 Agent。
  Future<void> retryLastRound() async {
    if (_isRunning) {
      LoggerService.instance.w(
        'ScenarioSession [$scenarioId] 拒绝重试（Agent 运行中）',
        category: LogCategory.ai,
        tags: ['session', 'retry', 'busy', scenarioId],
      );
      _notifyStateError('Agent 正在运行，无法重试');
      return;
    }

    int lastUserIndex = -1;
    for (int i = _agentMessages.length - 1; i >= 0; i--) {
      if (_agentMessages[i].role == 'user') {
        lastUserIndex = i;
        break;
      }
    }
    if (lastUserIndex < 0) {
      LoggerService.instance.w(
        'ScenarioSession [$scenarioId] 拒绝重试：无 user 消息',
        category: LogCategory.ai,
        tags: ['session', 'retry', 'no_user', scenarioId],
      );
      _notifyStateError('没有可重试的用户消息');
      return;
    }

    final userContent = _agentMessages[lastUserIndex].content ?? '';
    final cutFrom = lastUserIndex + 1;
    final removedCount = _agentMessages.length - cutFrom;
    _agentMessages.removeRange(cutFrom, _agentMessages.length);

    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 重试：截断至 lastUserIndex=$lastUserIndex, '
      '删掉其后 $removedCount 条',
      category: LogCategory.ai,
      tags: ['session', 'retry', scenarioId],
    );

    _state = _state.copyWith(
      messages: _uiMessages,
      streamingSegments: const [],
      error: null,
    );
    _notifyStateChanged();

    // 同步删 DB：删掉 cutFrom 之后的所有消息
    await _deleteAgentMessagesFromDb(cutFrom);

    await _beginAgentRun(userContent);
  }

  /// 取消本 session 的 Agent（不影响其他 session）
  void cancel() {
    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 请求已取消',
      category: LogCategory.ai,
      tags: ['session', 'cancel', scenarioId],
    );

    if (_currentToken != null) {
      _currentToken!.cancel(reason: '用户主动取消');
      _currentToken = null;
    }
    _agentSub?.cancel();
    _agentSub = null;

    // 把 partial segments 落库为 assistant turn
    if (_pendingSegments.isNotEmpty) {
      _finalizeAgentResponse(partial: true);
    } else {
      _state = _state.copyWith(
        isLoading: false,
        streamingSegments: const [],
      );
      _isRunning = false;
      _lifecycle = SessionLifecycle.idle;
      _notifyStateChanged();
    }
  }

  /// 切换当前小说（本 session 独享）
  Future<CurrentNovel?> selectNovel(int novelId) async {
    final novel = await selectCurrentNovel(_ref, novelId);
    if (novel != null) {
      _currentNovel = novel;
      _state = _state.copyWith(currentNovel: novel);
      _notifyStateChanged();
      unawaited(_persistCurrentNovel());
    }
    return novel;
  }

  /// 清空对话（保留场景和小说上下文）
  void clearConversation() {
    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 清空对话 sessionId=$_sessionId',
      category: LogCategory.ai,
      tags: ['session', 'clear', scenarioId],
    );
    _pendingSegments.clear();
    _agentMessages.clear();

    _state = AgentChatState(
      scenarioId: scenarioId,
      scenarioDisplayName: _state.scenarioDisplayName,
      currentNovel: _currentNovel,
    );
    _notifyStateChanged();

    unawaited(_clearMessagesFromDb());
  }

  /// 回滚到指定 user 消息 — 删除该消息及之后的所有记录,
  /// 并通过 [contentCallback] 把该消息文本回传给 UI。
  ///
  /// [index] 指向 UI messages（AgentChatMessage）中的 user 消息。
  bool rollbackToMessage(
    int index, {
    required void Function(String content) contentCallback,
  }) {
    if (_isRunning) {
      LoggerService.instance.w(
        'ScenarioSession [$scenarioId] 拒绝回滚（Agent 运行中）',
        category: LogCategory.ai,
        tags: ['session', 'rollback', 'busy', scenarioId],
      );
      _notifyStateError('Agent 正在运行，无法回滚');
      return false;
    }
    final uiMsgs = _uiMessages;
    if (index < 0 || index >= uiMsgs.length) {
      LoggerService.instance.w(
        'ScenarioSession [$scenarioId] 回滚索引越界: index=$index, len=${uiMsgs.length}',
        category: LogCategory.ai,
        tags: ['session', 'rollback', 'out_of_bounds', scenarioId],
      );
      return false;
    }
    final target = uiMsgs[index];
    if (target.role != AgentChatRole.user) {
      LoggerService.instance.w(
        'ScenarioSession [$scenarioId] 回滚目标非 user 消息',
        category: LogCategory.ai,
        tags: ['session', 'rollback', 'not_user', scenarioId],
      );
      return false;
    }

    // UI index → agent index：投影后第 index 条 user 对应的 agent 位置
    int agentIdx = -1;
    int uiCount = 0;
    for (int i = 0; i < _agentMessages.length; i++) {
      if (_agentMessages[i].role == 'user') {
        if (uiCount == index) {
          agentIdx = i;
          break;
        }
        uiCount++;
      }
    }
    if (agentIdx < 0) return false;

    final userContent = _agentMessages[agentIdx].content ?? '';
    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 回滚至 agentIdx=$agentIdx, '
      '删除之后 ${_agentMessages.length - agentIdx} 条 agent 消息',
      category: LogCategory.ai,
      tags: ['session', 'rollback', scenarioId],
    );

    _agentMessages.removeRange(agentIdx, _agentMessages.length);
    _state = _state.copyWith(
      messages: _uiMessages,
      isLoading: false,
      streamingSegments: const [],
      error: null,
    );
    _notifyStateChanged();

    unawaited(_deleteAgentMessagesFromDb(agentIdx));
    contentCallback(userContent);
    return true;
  }

  void dispose() {
    _agentSub?.cancel();
    _agentSub = null;
    _currentToken = null;
    _lifecycle = SessionLifecycle.disposed;
  }

  // ===== 内部实现 =====

  /// 运行 Agent — 订阅全局 AgentService 的事件流
  Future<void> _runAgent(String userInput) async {
    final agentService = _ref.read(novelAgentServiceProvider);
    await _agentSub?.cancel();
    _agentSub = agentService.events.listen(_handleAgentEvent);

    // history = _agentMessages（去掉末尾的 user，由 service append）
    final history = List<ChatMessage>.from(_agentMessages);
    if (history.isNotEmpty && history.last.role == 'user') {
      history.removeLast();
    }

    final scenarioContext = _buildScenarioContext();

    await agentService.sendMessage(
      userInput: userInput,
      history: history,
      scenarioId: scenarioId,
      scenarioContext: scenarioContext,
    );
  }

  /// 处理 Agent 事件 — 只更新本 session 的 _pendingSegments
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
          streamingSegments: List<AgentChatSegment>.unmodifiable(_pendingSegments),
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
          streamingSegments: List<AgentChatSegment>.unmodifiable(_pendingSegments),
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
            // 落库用 fullResult（完整原始），UI 展示也用 fullResult（信息更全）
            result: e.fullResult ?? e.result,
          ));
        }
        if (e.success && (e.name == 'select_novel' || e.name == 'create_novel')) {
          _handleSelectNovelFromResult(e.result);
        }
        _state = _state.copyWith(
          streamingSegments: List<AgentChatSegment>.unmodifiable(_pendingSegments),
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

  /// 完成 Agent 响应 — 把 _pendingSegments 重建为 agent messages 并落库
  ///
  /// 重建规则（一个回合可能含多段 assistant/tool 交替）：
  /// - TextSegment 累积为当前 assistant 的 content
  /// - ToolCallSegment 触发 flush 当前 assistant（含已累积 toolCalls）+ 追加 tool 消息
  /// - [partial]=true（用户取消）时，running 状态的 tool_call 不追加 tool 消息
  void _finalizeAgentResponse({String? error, bool partial = false}) {
    if (error != null) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] Agent 错误: $error',
        category: LogCategory.ai,
        tags: ['session', 'agent-error', scenarioId],
      );
    }

    final newMessages = <ChatMessage>[];
    var pendingText = StringBuffer();
    var pendingToolCalls = <ToolCall>[];

    void flushAssistant() {
      final hasText = pendingText.isNotEmpty;
      final hasCalls = pendingToolCalls.isNotEmpty;
      if (!hasText && !hasCalls) return;
      newMessages.add(ChatMessage(
        role: 'assistant',
        content: hasText ? pendingText.toString() : null,
        toolCalls: hasCalls ? List<ToolCall>.from(pendingToolCalls) : null,
      ));
      pendingText = StringBuffer();
      pendingToolCalls = [];
    }

    for (final seg in _pendingSegments) {
      if (seg is TextSegment) {
        pendingText.write(seg.content);
      } else if (seg is ToolCallSegment) {
        final call = seg.call;
        pendingToolCalls.add(ToolCall(
          id: call.id,
          name: call.name,
          arguments: call.arguments,
        ));
        flushAssistant();
        if (call.status == AgentToolStatus.completed ||
            call.status == AgentToolStatus.error) {
          newMessages.add(ChatMessage(
            role: 'tool',
            content: call.result ?? '',
            toolCallId: call.id,
          ));
        }
      }
    }
    flushAssistant();

    _agentMessages.addAll(newMessages);

    _state = _state.copyWith(
      messages: _uiMessages,
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

    if (newMessages.isNotEmpty) {
      unawaited(_persistAgentMessages(newMessages, partial: partial));
    }
  }

  /// 解析 select_novel / create_novel 工具返回的 JSON，自动同步 currentNovel
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

  /// 处理上下文压缩事件 — 同步裁剪内存 + 删 DB
  void _handleCompaction(CompactionEvent e) {
    final cut = e.droppedAgentFromIndex;
    if (cut <= 0) {
      LoggerService.instance.i(
        'ScenarioSession [$scenarioId] 收到压缩事件(无裁剪): ${e.description}',
        category: LogCategory.ai,
        tags: ['session', 'compaction', scenarioId],
      );
      return;
    }
    final removed = cut.clamp(0, _agentMessages.length);
    _agentMessages.removeRange(0, removed);
    _state = _state.copyWith(messages: _uiMessages);
    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 压缩裁剪: 移除前 $removed 条 agent 消息, '
      '剩余 ${_agentMessages.length} 条',
      category: LogCategory.ai,
      tags: ['session', 'compaction', 'trim', scenarioId],
    );
    unawaited(_deleteAgentMessagesBeforeDb(cut));
  }

  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  void _notifyStateError(String error) {
    _state = _state.copyWith(error: error);
    _notifyStateChanged();
  }

  // ===== 持久化 =====

  /// 落库单条 agent 消息（user 消息即时落库用）
  Future<void> _persistAgentMessage(ChatMessage m) async {
    final sid = _sessionId ?? _ref.read(currentChatSessionIdProvider);
    if (sid == null) return;
    try {
      final repo = _ref.read(chatSessionRepositoryProvider);
      final idx = _agentMessages.indexOf(m);
      await repo.appendMessage(ChatMessageRecord.fromAgentMessage(
        sid,
        idx >= 0 ? idx : _agentMessages.length - 1,
        m,
      ));
      _ref.invalidate(chatSessionsByScenarioProvider(scenarioId));
    } catch (e, st) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] 落库 agent 消息失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['session', 'persist_msg', 'failed', scenarioId],
      );
    }
  }

  /// 批量落库多条 agent 消息（回合结束 finalize 用）
  ///
  /// agentMsgIndex 基于 _agentMessages 的最终位置计算（消息已 addAll 进去）。
  Future<void> _persistAgentMessages(List<ChatMessage> msgs,
      {bool partial = false}) async {
    final sid = _sessionId ?? _ref.read(currentChatSessionIdProvider);
    if (sid == null) return;
    try {
      final repo = _ref.read(chatSessionRepositoryProvider);
      final startIdx = _agentMessages.length - msgs.length;
      for (var i = 0; i < msgs.length; i++) {
        await repo.appendMessage(ChatMessageRecord.fromAgentMessage(
          sid,
          startIdx + i,
          msgs[i],
        ));
      }
      _ref.invalidate(chatSessionsByScenarioProvider(scenarioId));
      LoggerService.instance.d(
        'ScenarioSession [$scenarioId] 落库 ${msgs.length} 条 agent 消息 '
        'partial=$partial sessionId=$sid startIdx=$startIdx',
        category: LogCategory.ai,
        tags: ['session', 'persist_turn', partial ? 'partial' : 'ok', scenarioId],
      );
    } catch (e, st) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] 批量落库失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['session', 'persist_turn', 'failed', scenarioId],
      );
    }
  }

  Future<void> _persistCurrentNovel() async {
    final sid = _sessionId;
    if (sid == null) return;
    try {
      await _ref.read(chatSessionRepositoryProvider).updateCurrentNovel(
            sid,
            novelId: _currentNovel?.id,
            novelTitle: _currentNovel?.title,
          );
    } catch (e, st) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] 同步 currentNovel 失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['session', 'persist_novel', 'failed', scenarioId],
      );
    }
  }

  /// 删 DB 中 agentMsgIndex >= [fromIndex] 的消息（retry/rollback 用）
  ///
  /// 当前 repo 只有 deleteMessagesBefore（删 < beforeIndex）和 clearMessages，
  /// 这里用 clearMessages + 重写保留段实现"删尾部"。
  Future<void> _deleteAgentMessagesFromDb(int fromIndex) async {
    final sid = _sessionId;
    if (sid == null) return;
    try {
      final repo = _ref.read(chatSessionRepositoryProvider);
      final retained = List<ChatMessage>.from(_agentMessages);
      await repo.clearMessages(sid);
      for (var i = 0; i < retained.length; i++) {
        await repo.appendMessage(
            ChatMessageRecord.fromAgentMessage(sid, i, retained[i]));
      }
      _ref.invalidate(chatSessionsByScenarioProvider(scenarioId));
      LoggerService.instance.i(
        'ScenarioSession [$scenarioId] DB 重写: 保留 ${retained.length} 条 (fromIndex=$fromIndex)',
        category: LogCategory.ai,
        tags: ['session', 'db_rewrite', scenarioId],
      );
    } catch (e, st) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] DB 重写失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['session', 'db_rewrite', 'failed', scenarioId],
      );
    }
  }

  /// 删 DB 中 agentMsgIndex < [beforeIndex] 的消息（压缩用）
  Future<void> _deleteAgentMessagesBeforeDb(int beforeIndex) async {
    final sid = _sessionId;
    if (sid == null) return;
    try {
      final repo = _ref.read(chatSessionRepositoryProvider);
      await repo.deleteMessagesBefore(sid, beforeIndex);
      // 压缩后 agentMsgIndex 有空洞，重写保留段让索引紧凑
      final retained = List<ChatMessage>.from(_agentMessages);
      await repo.clearMessages(sid);
      for (var i = 0; i < retained.length; i++) {
        await repo.appendMessage(
            ChatMessageRecord.fromAgentMessage(sid, i, retained[i]));
      }
      _ref.invalidate(chatSessionsByScenarioProvider(scenarioId));
      LoggerService.instance.i(
        'ScenarioSession [$scenarioId] 压缩后 DB 重写: 保留 ${retained.length} 条',
        category: LogCategory.ai,
        tags: ['session', 'compaction_db', scenarioId],
      );
    } catch (e, st) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] 压缩 DB 清理失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['session', 'compaction_db', 'failed', scenarioId],
      );
    }
  }

  Future<void> _clearMessagesFromDb() async {
    final sid = _sessionId;
    if (sid == null) return;
    try {
      await _ref.read(chatSessionRepositoryProvider).clearMessages(sid);
      _ref.invalidate(chatSessionsByScenarioProvider(scenarioId));
    } catch (e, st) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] 清库 messages 失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['session', 'clear_db', 'failed', scenarioId],
      );
    }
  }

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
}
