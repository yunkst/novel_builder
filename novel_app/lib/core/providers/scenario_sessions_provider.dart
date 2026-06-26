/// 场景会话管理器 — 按 scenarioId 管理 ScenarioSession 实例
///
/// 对应 Hermes GatewayRunner 的 _agent_cache 机制：
/// - 按 session_key (scenarioId) 懒创建 AIAgent 实例
/// - LRU 淘汰空闲实例（_AGENT_CACHE_MAX_SIZE = 128）
/// - _AGENT_CACHE_IDLE_TTL_SECS = 3600（空闲 1 小时驱逐）
///
/// 在 Flutter 中简化为：
/// - 按 scenarioId 懒创建 ScenarioSession
/// - LRU 淘汰（最多 8 个 session，空闲的优先淘汰）
/// - Riverpod state 同步（`Map<scenarioId, HermesChatState>`）
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/logger_service.dart';
import '../../services/novel_agent/agent_scenario_factory.dart';
import 'agent_scenario_provider.dart';
import 'hermes_chat_state.dart';
import 'scenario_session.dart';

/// 最大并发 session 数
const _maxSessions = 8;

/// 场景会话管理器
class ScenarioSessionsNotifier
    extends StateNotifier<Map<String, HermesChatState>> {
  final Ref _ref;

  /// scenarioId → ScenarioSession 实例
  final Map<String, ScenarioSession> _sessions = {};

  /// 访问顺序（用于 LRU 淘汰），最近访问的在末尾
  final List<String> _accessOrder = [];

  ScenarioSessionsNotifier(this._ref) : super({});

  /// 获取指定场景的 session（懒创建）
  ScenarioSession get(String scenarioId) {
    // 更新访问顺序
    _accessOrder.remove(scenarioId);
    _accessOrder.add(scenarioId);

    if (_sessions.containsKey(scenarioId)) {
      return _sessions[scenarioId]!;
    }

    // 懒创建
    LoggerService.instance.i(
      'ScenarioSessions 创建新 session: $scenarioId',
      category: LogCategory.ai,
      tags: ['sessions', 'create', scenarioId],
    );

    final session = ScenarioSession(scenarioId: scenarioId, ref: _ref);
    session.setOnStateChanged(() => _syncState(scenarioId));
    _sessions[scenarioId] = session;

    // LRU 淘汰
    _evictIfNeeded();

    // 初始同步
    _syncState(scenarioId);

    return session;
  }

  /// 获取当前场景的 session（如果已创建）
  ScenarioSession? getIfExists(String scenarioId) {
    return _sessions[scenarioId];
  }

  /// 获取所有活跃 session 的 scenarioId
  List<String> get activeSessionIds => _sessions.keys.toList();

  /// 是否有指定场景的 session
  bool hasSession(String scenarioId) => _sessions.containsKey(scenarioId);

  /// 是否有指定场景正在运行
  bool isRunning(String scenarioId) {
    return _sessions[scenarioId]?.isRunning ?? false;
  }

  /// 销毁指定场景的 session
  void disposeSession(String scenarioId) {
    final session = _sessions.remove(scenarioId);
    if (session != null) {
      session.dispose();
      _accessOrder.remove(scenarioId);
      state = <String, HermesChatState>{...state}..remove(scenarioId);
      LoggerService.instance.i(
        'ScenarioSessions 销毁 session: $scenarioId',
        category: LogCategory.ai,
        tags: ['sessions', 'dispose', scenarioId],
      );
    }
  }

  /// 销毁所有 session
  @override
  void dispose() {
    for (final session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
    _accessOrder.clear();
    super.dispose();
  }

  // ===== 内部方法 =====

  /// 把 session 状态同步到 Riverpod state
  void _syncState(String scenarioId) {
    final session = _sessions[scenarioId];
    if (session == null) return;
    state = <String, HermesChatState>{...state, scenarioId: session.state};
  }

  /// LRU 淘汰 — 超过 _maxSessions 时淘汰最早的不在运行的 session
  void _evictIfNeeded() {
    while (_sessions.length > _maxSessions) {
      // 从访问顺序的头部找第一个不在运行的 session
      String? evictKey;
      for (final key in _accessOrder) {
        final session = _sessions[key];
        if (session != null && !session.isRunning) {
          evictKey = key;
          break;
        }
      }

      if (evictKey == null) {
        // 所有 session 都在运行，无法淘汰
        LoggerService.instance.w(
          'ScenarioSessions 无法淘汰：所有 ${_sessions.length} 个 session 都在运行中',
          category: LogCategory.ai,
          tags: ['sessions', 'evict', 'all_running'],
        );
        break;
      }

      LoggerService.instance.i(
        'ScenarioSessions LRU 淘汰 session: $evictKey',
        category: LogCategory.ai,
        tags: ['sessions', 'evict', evictKey],
      );

      final session = _sessions.remove(evictKey);
      session?.dispose();
      _accessOrder.remove(evictKey);
      state = <String, HermesChatState>{...state}..remove(evictKey);
    }
  }
}

/// 场景会话管理器 Provider
///
/// 全局单例，管理所有场景的 ScenarioSession 实例。
/// StateNotifierProvider 在 Riverpod 2.x 中默认不 autoDispose。
final scenarioSessionsProvider =
    StateNotifierProvider<ScenarioSessionsNotifier, Map<String, HermesChatState>>(
  (ref) {
    LoggerService.instance.i(
      'ScenarioSessionsNotifier 初始化',
      category: LogCategory.ai,
      tags: ['sessions', 'init'],
    );
    return ScenarioSessionsNotifier(ref);
  },
);

/// 当前场景的聊天状态 — UI 只 watch 这个
///
/// UI 层不直接感知 ScenarioSession 的存在，
/// 只通过这个 Provider 读取当前场景的 HermesChatState。
final currentChatStateProvider = Provider<HermesChatState>((ref) {
  final scenarioId = ref.watch(currentAgentScenarioProvider);
  final sessions = ref.watch(scenarioSessionsProvider);
  return sessions[scenarioId] ??
      HermesChatState(
        scenarioId: scenarioId,
        scenarioDisplayName: AgentScenarioFactory.availableScenarios
                .where((s) => s.id == scenarioId)
                .firstOrNull
                ?.displayName ??
            scenarioId,
      );
});

/// 当前场景的 session — 用于发送消息等操作
///
/// 懒创建：首次访问时自动创建对应场景的 ScenarioSession。
final currentSessionProvider = Provider<ScenarioSession?>((ref) {
  final scenarioId = ref.watch(currentAgentScenarioProvider);
  final notifier = ref.read(scenarioSessionsProvider.notifier);
  return notifier.get(scenarioId);
});
