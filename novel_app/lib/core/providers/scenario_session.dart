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
///
/// 多 session 持久化：
/// - 一个 ScenarioSession 内含一个 sessionId（会话 id），可被 UI 切换
/// - 切换 sessionId 时清空 in-memory messages，重新从 DB hydrate
/// - _persistUserMessage / _persistAssistantTurn 在合适时机把消息落库
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/hermes_message.dart';
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

  /// 当前会话 id（可空：用户从未建过 session / 还没从 DB 选中）
  int? _sessionId;

  int? get sessionId => _sessionId;

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
    int? initialSessionId,
  })  : _ref = ref,
        _sessionId = initialSessionId {
    final info = AgentScenarioFactory.availableScenarios
        .where((s) => s.id == scenarioId)
        .firstOrNull;
    _state = HermesChatState(
      scenarioId: scenarioId,
      scenarioDisplayName: info?.displayName ?? scenarioId,
    );
  }

  /// 由 ScenarioSessionsNotifier 在 UI 切换 sessionId 时调用。
  ///
  /// 仅在确实改变时清空 messages 并标记需要重新 hydrate；否则 noop。
  void adoptSession(int? newSessionId) {
    if (_sessionId == newSessionId) return;
    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 切换 sessionId $_sessionId → $newSessionId',
      category: LogCategory.ai,
      tags: ['session', 'switch', scenarioId],
    );
    _sessionId = newSessionId;
    _pendingSegments.clear();
    // 清空 messages（保留 currentNovel 等场景上下文）
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

  /// 如果 _sessionId 不为空且 _state.messages 为空，主动从 DB 加载。
  ///
  /// 调用方负责在 adoptSession 后或冷启动时调用一次。
  /// 内部捕获异常：DB 读失败时留下空 messages，不影响 agent 后续运行。
  Future<void> hydrateIfNeeded() async {
    final sid = _sessionId;
    if (sid == null) return;
    if (_state.messages.isNotEmpty) {
      // 已经有内容（in-memory），跳过 hydrate
      return;
    }
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
      final messages = <HermesMessage>[];
      for (final r in records) {
        // 跳过坏数据：segs 和 content 都空的记录直接丢弃
        if (r.segments.isEmpty && r.content.isEmpty) continue;
        messages.add(r.toHermesMessage());
      }
      // 注意：currentNovel 不从 DB 恢复（DB 只存了 id/title，没 url）。
      // 让用户下次调 select_novel 工具时由 _buildScenarioContext 走默认 null 路径，
      // 避免构造出不完整的 CurrentNovel。
      _state = _state.copyWith(
        messages: messages,
        clearCurrentNovel: true,
        scenarioDisplayName: _state.scenarioDisplayName,
      );
      _currentNovel = null;
      LoggerService.instance.i(
        'ScenarioSession [$scenarioId] hydrate sessionId=$sid → ${messages.length} 条消息',
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

  /// 冷启动用：sessionId 未知时，主动从 DB 选该 scenario 最近的 session，
  /// 写入 _sessionId + currentChatSessionIdProvider，再 hydrate。
  ///
  /// DB 无任何 session 时不创建（等到用户发第一条消息时由 [sendMessage]
  /// 内部的 [sendMessage] 走 `_resolveSessionId(autoCreate: true)` 流程再建）。
  Future<void> hydrateFromRecentIfNeeded() => _resolveSessionId(autoCreate: false);

  /// 确保 _sessionId 非空：复用最近一个；DB 无则视 [autoCreate] 决定是否新建。
  /// 完成后统一触发 hydrate（in-memory messages 仍空时从 DB 拉取）。
  ///
  /// 失败时只记日志不抛错（agent 仍能跑）。
  Future<void> _resolveSessionId({required bool autoCreate}) async {
    if (_sessionId != null) {
      await hydrateIfNeeded();
      return;
    }
    if (!autoCreate && _state.messages.isNotEmpty) return;
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
      if (!autoCreate) return; // 冷启动分支：等用户首条消息再建
      final id = await repo.createSession(ChatSession(
        scenarioId: scenarioId,
        title: '', // displayTitle getter 会回退成「新对话 时间」
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

  /// 旧名 _ensureSessionId 的入口，等价于 [sendMessage] 内的「确保有 sessionId」
  Future<void> _ensureSessionId() => _resolveSessionId(autoCreate: true);

  /// 落库 user message（sendMessage 每回合只调一次，无需去重）

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
  ///
  /// 多 session 持久化：
  /// 1) 如果当前还没 sessionId，主动从 DB 选最近一个或新建一条；
  /// 2) 新建 / 复用 session 后，user message 落库。
  /// 3) 不存在则：先 hydrate（如果已有 session 但 messages 空）再发。
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

    // 多 session：确保有 sessionId；否则新建
    await _ensureSessionId();

    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 发送消息: length=${content.length} sessionId=$_sessionId',
      category: LogCategory.ai,
      tags: ['session', 'send', scenarioId],
    );

    final userMessage = HermesMessage.user(content.trim());
    _state = _state.copyWith(
      messages: [..._state.messages, userMessage],
      isLoading: true,
    );
    _notifyStateChanged();

    // 落库 user message（异步，失败不阻塞主流程）
    unawaited(_persistUserMessage(userMessage));

    // 启动 Agent 一轮（_beginAgentRun 负责状态切换 + 调 _runAgent + 异常兜底）
    await _beginAgentRun(content.trim());
  }

  /// 启动一轮 Agent 回合的公共逻辑（sendMessage / retryLastRound 共用）。
  ///
  /// 负责：lifecycle/isRunning/token/清 pending + 进 loading + 清 error +
  /// 调 [_runAgent] + 异常兜底。
  ///
  /// **不负责** add user 消息与落库（由调用方 [sendMessage] / [retryLastRound]
  /// 自行决定是否新增 user 消息、是否落库）。
  ///
  /// [userInput] 是本轮要发给 LLM 的用户输入文本（NovelAgentService 会把它
  /// append 成 history 末尾的 user 消息）。
  Future<void> _beginAgentRun(String userInput) async {
    _lifecycle = SessionLifecycle.active;
    _isRunning = true;
    _currentToken = CancellationToken();
    _pendingSegments.clear();

    _state = _state.copyWith(
      isLoading: true,
      streamingSegments: const [],
      // copyWith 的 error 参数无 ?? 兜底，不传即清空（见 hermes_chat_state.dart）
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
  /// 找到 messages 里**最后一条 user 消息**，删除它**之后**的所有消息
  /// （保留该 user 本身——区别于 [rollbackToMessage] 删 user 及之后全部），
  /// 然后用该 user 的 content 重新触发 Agent。
  ///
  /// 典型失败场景与重试后状态：
  /// - 末尾是 user（首轮 LLM 就挂 / 未配置）→ 无后置消息，直接重发该 user
  /// - 末尾是 assistant 半成品（多轮后挂）→ 删半成品 assistant，重发末尾 user
  ///
  /// 仅改内存 messages，不碰 DB（与 [rollbackToMessage] 一致）。
  /// user 消息在首次 [sendMessage] 时已落库，重试不重复落库。
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

    final messages = _state.messages;
    // 从后往前找最后一条 user 消息
    int lastUserIndex = -1;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == HermesRole.user) {
        lastUserIndex = i;
        break;
      }
    }
    if (lastUserIndex < 0) {
      LoggerService.instance.w(
        'ScenarioSession [$scenarioId] 拒绝重试：messages 中无 user 消息',
        category: LogCategory.ai,
        tags: ['session', 'retry', 'no_user', scenarioId],
      );
      _notifyStateError('没有可重试的用户消息');
      return;
    }

    final userContent = messages[lastUserIndex].content;
    // 截断：保留 [0, lastUserIndex+1)，即保留 user 本身、删掉其后所有
    final retained = messages.sublist(0, lastUserIndex + 1);

    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 重试：截断至 lastUserIndex=$lastUserIndex, '
      '删掉其后 ${messages.length - retained.length} 条',
      category: LogCategory.ai,
      tags: ['session', 'retry', scenarioId],
    );

    _state = _state.copyWith(
      messages: retained,
      streamingSegments: const [],
      error: null,
    );
    _notifyStateChanged();

    await _beginAgentRun(userContent);
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
    HermesMessage? partial;
    if (_pendingSegments.isNotEmpty) {
      final segmentsSnapshot = List<HermesSegment>.unmodifiable(_pendingSegments);
      partial = HermesMessage.assistantFromSegments(segmentsSnapshot);
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

    // partial 落库（标 status='partial' 由 toolcall 状态保留）
    if (partial != null) {
      unawaited(_persistAssistantTurn(partial, partial: true));
    }
  }

  /// 切换当前小说（本 session 独享）
  Future<CurrentNovel?> selectNovel(int novelId) async {
    final novel = await selectCurrentNovel(_ref, novelId);
    if (novel != null) {
      _currentNovel = novel;
      _state = _state.copyWith(currentNovel: novel);
      _notifyStateChanged();
      // 同步到 chat_sessions.currentNovelId / currentNovelTitle
      unawaited(_persistCurrentNovel());
    }
    return novel;
  }

  /// 清空对话（保留场景和小说上下文）
  ///
  /// 持久化路径：删除 chat_messages 全部行（chat_sessions 保留，
  /// 之后可继续往这个 session 写新消息）。
  void clearConversation() {
    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 清空对话 sessionId=$_sessionId',
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

    // 同步删除 messages 行
    unawaited(_clearMessagesFromDb());
  }

  /// 回滚到指定 user 消息 — 删除该消息及之后的所有记录,
  /// 并通过 [contentCallback] 把该消息文本回传给 UI(由 UI 填入输入框)。
  ///
  /// 约束:
  /// - Agent 运行中(`_isRunning == true`)不允许回滚,通过 error 通知 UI,返回 false。
  /// - [index] 必须指向 user 消息;越界或非 user 消息返回 false。
  /// - 保留 `scenarioId` / `displayName` / `currentNovel`(与 [clearConversation] 一致)。
  ///
  /// 返回 true 表示回滚成功。
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
    if (index < 0 || index >= _state.messages.length) {
      LoggerService.instance.w(
        'ScenarioSession [$scenarioId] 回滚索引越界: index=$index, len=${_state.messages.length}',
        category: LogCategory.ai,
        tags: ['session', 'rollback', 'out_of_bounds', scenarioId],
      );
      return false;
    }
    final target = _state.messages[index];
    if (target.role != HermesRole.user) {
      LoggerService.instance.w(
        'ScenarioSession [$scenarioId] 回滚目标非 user 消息: role=${target.role}',
        category: LogCategory.ai,
        tags: ['session', 'rollback', 'not_user', scenarioId],
      );
      return false;
    }

    final removedCount = _state.messages.length - index;
    LoggerService.instance.i(
      'ScenarioSession [$scenarioId] 回滚至 index=$index, 删除之后 $removedCount 条消息',
      category: LogCategory.ai,
      tags: ['session', 'rollback', scenarioId],
    );

    final userContent = target.content;
    final retained = _state.messages.sublist(0, index);
    _state = _state.copyWith(
      messages: retained,
      isLoading: false,
      streamingSegments: const [],
      error: null,
    );
    _notifyStateChanged();

    contentCallback(userContent);
    return true;
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

    // 构造历史消息 + 压缩对齐 owner（单次遍历）
    final (history, owners) = _buildHistoryAndOwners();

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
        if (e.success && (e.name == 'select_novel' || e.name == 'create_novel')) {
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

    // 落库 assistant turn
    if (assistantMessage != null) {
      unawaited(_persistAssistantTurn(assistantMessage));
    }
  }

  /// 解析 select_novel / create_novel 工具返回的 JSON，自动同步 currentNovel
  ///
  /// 两者返回结构一致（均含 success + novelId + title）：
  /// - select_novel：切换到已有小说
  /// - create_novel：创建新小说后自动切到该书
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

  /// 落库 user message（sendMessage 每回合只调一次，无需去重）
  Future<void> _persistUserMessage(HermesMessage message) async {
    final sid = _sessionId ?? _ref.read(currentChatSessionIdProvider);
    if (sid == null) return;
    try {
      final repo = _ref.read(chatSessionRepositoryProvider);
      await repo.appendMessage(ChatMessageRecord.fromHermesMessage(
        sid,
        0, // orderIndex 由 repo 内部用 MAX+1 覆盖
        message,
      ));
      // 让 UI 历史抽屉的列表刷新（updatedAt 排序会变）
      _ref.invalidate(chatSessionsByScenarioProvider(scenarioId));
    } catch (e, st) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] 落库 user message 失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['session', 'persist_user', 'failed', scenarioId],
      );
    }
  }

  /// 落库 assistant turn（含工具调用详情）。
  ///
  /// [partial] = true 表示用户中途取消，segments 中可能含 status=running 的
  /// tool_call —— 按决策仍写入，列表渲染时可显示「已中断」标记。
  Future<void> _persistAssistantTurn(
    HermesMessage message, {
    bool partial = false,
  }) async {
    final sid = _sessionId ?? _ref.read(currentChatSessionIdProvider);
    if (sid == null) return;
    try {
      final repo = _ref.read(chatSessionRepositoryProvider);
      await repo.appendMessage(ChatMessageRecord.fromHermesMessage(
        sid,
        0,
        message,
      ));
      _ref.invalidate(chatSessionsByScenarioProvider(scenarioId));
      LoggerService.instance.d(
        'ScenarioSession [$scenarioId] 落库 assistant turn partial=$partial sessionId=$sid',
        category: LogCategory.ai,
        tags: ['session', 'persist_assistant', partial ? 'partial' : 'ok', scenarioId],
      );
    } catch (e, st) {
      LoggerService.instance.e(
        'ScenarioSession [$scenarioId] 落库 assistant turn 失败: $e',
        stackTrace: st.toString(),
        category: LogCategory.ai,
        tags: ['session', 'persist_assistant', 'failed', scenarioId],
      );
    }
  }

  /// 同步 currentNovel 到 chat_sessions（selectNovel 后调用）
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

  /// 清库当前 session 全部 messages（clearConversation 时调用）
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

  /// 构造 LLM 历史消息 + 压缩对齐 owner（单次遍历，避免两份「末尾是 user 则 removeLast」逻辑漂移）
  (List<ChatMessage>, List<int>) _buildHistoryAndOwners() {
    final history = <ChatMessage>[];
    final owners = <int>[];
    final messages = _state.messages;
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m.role == HermesRole.assistant) {
        final toolCalls = m.toolCalls;
        final withResults =
            toolCalls.where((c) => c.result != null).toList();
        if (toolCalls.isNotEmpty) {
          history.add(ChatMessage(
            role: 'assistant',
            content: m.content.isEmpty ? null : m.content,
            toolCalls: toolCalls
                .map((c) => ToolCall(
                    id: c.id, name: c.name, arguments: c.arguments))
                .toList(),
          ));
          for (final c in withResults) {
            history.add(ChatMessage(
                role: 'tool', content: c.result, toolCallId: c.id));
          }
          owners.add(i);
          for (final _ in withResults) {
            owners.add(i);
          }
        } else {
          history.add(ChatMessage(role: m.role.name, content: m.content));
          owners.add(i);
        }
      } else {
        history.add(ChatMessage(role: m.role.name, content: m.content));
        owners.add(i);
      }
    }
    // 末尾是 user 消息会被 NovelAgentService 自行 append，这里不重复带
    if (messages.isNotEmpty && messages.last.role == HermesRole.user) {
      history.removeLast();
      owners.removeLast();
    }
    return (history, owners);
  }
}
