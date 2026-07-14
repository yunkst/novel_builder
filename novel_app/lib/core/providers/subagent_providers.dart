/// 子 Agent 相关 Riverpod Providers
///
/// 任务 7 提前建好供 WritingScenario 消费（原本属任务 9）：
/// - [subagentRegistryProvider]：内存注册表（按 parentSessionId 索引）
/// - [subagentRunnerProvider]：调度器，注入 NovelAgentService 用于事件回流
///
/// 决策 1（任务 7）：子 Agent 事件直接发到 NovelAgentService.events 全局流，
/// 不再依赖 emitParent 转发。subagentRunnerProvider 在此组装。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/novel_agent/novel_agent_service.dart';
import '../../services/novel_agent/subagent_registry.dart';
import '../../services/novel_agent/subagent_run.dart';
import '../../services/novel_agent/subagent_runner.dart';
import 'chat_session_providers.dart';

/// 子 Agent 注册表
///
/// 生命周期：随主 ScenarioSession 一起 dispose（clearForSession）。
/// 应用级单例（无 family），所有 session 共享一份内存索引。
final subagentRegistryProvider = Provider<SubagentRegistry>((ref) {
  final registry = SubagentRegistry();
  ref.onDispose(registry.clearAll);
  return registry;
});

/// 子 Agent 调度器
///
/// 写作场景（WritingScenario）的 executeTool 路径调
/// `ref.read(subagentRunnerProvider).dispatch(...)` 派发子任务。
final subagentRunnerProvider = Provider<SubagentRunner>((ref) {
  final registry = ref.watch(subagentRegistryProvider);
  final agentService = ref.watch(novelAgentServiceProvider);
  return SubagentRunner(
    ref: ref,
    registry: registry,
    agentService: agentService,
  );
});

/// 按 (sessionId, runId) 索引查询单个 SubagentRun
///
/// 供 SubagentToolCard / SubagentDetailScreen 订阅。
/// 查不到返回 null（run 尚未创建 / 已 prune / parentSessionId 不匹配）。
///
/// 任务 8 已统一 parentSessionId 口径为 `sessionId.toString()`，
/// 因此入参 sessionId 用 String 与 [SubagentRegistry] 一致。
///
/// 参数为位置 record `(String sessionId, String runId)`，访问用 `$1` / `$2`。
final subagentRunProvider =
    Provider.family<SubagentRun?, (String sessionId, String runId)>(
  (ref, pair) {
    final registry = ref.watch(subagentRegistryProvider);
    return registry.get(pair.$1, pair.$2);
  },
);

/// 当前 session 派出的所有 subagent run（按 createdAt 升序）
///
/// 供 SubagentToolCard 列表 / 主气泡卡片渲染用。
/// `currentChatSessionIdProvider` 为 null（未选会话）时返回空列表。
///
/// 依赖链：
/// - [currentChatSessionIdProvider]：StateProvider<int?>，UI 切换时刷新
/// - [subagentRegistryProvider]：注册表，dispatch / cancel 时变更（订阅需 ref.invalidate）
final currentSubagentRunsProvider = Provider<List<SubagentRun>>((ref) {
  final registry = ref.watch(subagentRegistryProvider);
  final sessionId = ref.watch(currentChatSessionIdProvider);
  if (sessionId == null) return const <SubagentRun>[];
  return registry.listForSession(sessionId.toString());
});