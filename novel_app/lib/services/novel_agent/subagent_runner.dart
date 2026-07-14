/// 子 Agent 运行调度器
///
/// 职责：
/// - 4 并发 + 30 排队上限（按 parentSessionId 隔离计数）
/// - 起子 AgentLoop，emit 包装打 runId
/// - 聚合子 Agent AgentChatState（供详情页）
/// - 提取 finalSummary 返回给主 Agent
///
/// 并发模型：同一 parentSessionId 内，running < 4 立即启动，
/// 4 ≤ total ≤ 29 入队 FIFO，total ≥ 30 立即返回 max_subagents_reached。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logger_service.dart';
import '../dsl_engine/llm_provider.dart';
import '../../utils/cancellation_token.dart';
import '../../core/providers/services/ai_service_providers.dart';
import '../ai/ai_service_factory.dart';
import '../../core/providers/agent_chat_state.dart';
import '../../models/agent_chat_message.dart';
import 'agent_event.dart';
import 'agent_loop.dart';
import 'agent_scenario.dart';
import 'subagent_registry.dart';
import 'subagent_scenario.dart';
import 'subagent_run.dart';
import 'subagent_state_projector.dart';
import 'tool_executor.dart';

class SubagentRunner {
  static const int maxConcurrent = 4;
  static const int maxQueue = 30;

  final Ref ref;
  final SubagentRegistry registry;

  /// LLM Provider 工厂覆盖（仅测试用）。
  ///
  /// 非空时 [dispatch] 用本工厂构造 LLM；为 null 走 [_buildLlmForScenario] 默认链路。
  final LlmProvider Function(String scenarioId)? _llmProviderFactoryOverride;

  SubagentRunner({
    required this.ref,
    required this.registry,
    LlmProvider Function(String scenarioId)? llmProviderFactory,
  }) : _llmProviderFactoryOverride = llmProviderFactory;

  /// 测试用工厂：注入 [registry]，不依赖完整 [Ref]（forTest 路径不发真请求）。
  ///
  /// 测试如需注入 mock LLM 走真实 [dispatch] 链路，可传 [llmProviderFactory]。
  factory SubagentRunner.forTest({
    required SubagentRegistry registry,
    LlmProvider Function(String scenarioId)? llmProviderFactory,
  }) {
    return SubagentRunner(
      ref: _ThrowRef(),
      registry: registry,
      llmProviderFactory: llmProviderFactory,
    );
  }

  /// 入队一个子任务。
  ///
  /// 超过 [maxQueue] 立即返回错误 JSON；否则返回 run 后的结果 JSON。
  /// 调用方通常是主 Agent 的 ToolExecutor 路径，把 [parentToolCallId] 透传。
  Future<String> dispatch({
    required String parentSessionId,
    required String task,
    required List<String> allowedTools,
    required String parentToolCallId,
    int? parentCurrentNovelId,
    void Function(AgentEvent)? emitParent,
  }) async {
    if (registry.countActiveBySession(parentSessionId) >= maxQueue) {
      LoggerService.instance.w(
        'dispatch_subagent 拒绝：已达单轮上限 $maxQueue (session=$parentSessionId)',
        category: LogCategory.ai,
        tags: ['agent', 'subagent', 'max_reached'],
      );
      return jsonEncode({
        'error': 'max_subagents_reached',
        'message': '当前已有 $maxQueue 个子 Agent 在跑或排队，请等其中一些完成后再派。',
      });
    }

    final run = registry.create(
      parentSessionId: parentSessionId,
      task: task,
      allowedTools: allowedTools,
      toolCallId: parentToolCallId,
    );

    if (task.trim().isEmpty) {
      run.state = SubagentRunState.failed;
      run.errorMessage = 'task 不能为空';
      LoggerService.instance.w(
        'dispatch_subagent 拒绝：task 为空 (session=$parentSessionId)',
        category: LogCategory.ai,
        tags: ['agent', 'subagent', 'empty_task'],
      );
      return jsonEncode({'error': 'missing_param', 'message': 'task 不能为空'});
    }

    try {
      await _waitForSlot(parentSessionId);
      await _runOne(
        run,
        emitParent: emitParent,
        parentCurrentNovelId: parentCurrentNovelId,
      );
    } catch (e, stack) {
      // 异常路径兜底：避免 registry 留僵尸 run
      // 例如 _waitForSlot 抛 TimeoutException 时 run 还是 pending，会导致
      // countActiveBySession 误判后续 dispatch 达 30 上限。
      if (run.state == SubagentRunState.pending ||
          run.state == SubagentRunState.running) {
        run.state = SubagentRunState.failed;
        run.errorMessage = e.toString();
      }
      LoggerService.instance.e(
        '子 Agent dispatch 失败 (runId=${run.runId}): $e',
        stackTrace: stack.toString(),
        category: LogCategory.ai,
        tags: ['agent', 'subagent', 'dispatch_error'],
      );
      // 重新抛给主 Agent（WritingScenario.executeTool 会 catch 转 error JSON）
      rethrow;
    }

    return _buildResultJson(run);
  }

  /// 等待并发槽位：若当前 session 已有 ≥ maxConcurrent 个活跃 run 则自旋等待。
  ///
  /// 当前 AgentLoop 是顺序执行 tool_calls，所以本方法的等待场景实际上不会触发，
  /// 留作未来 AgentLoop 并行工具调用 / UI 直发 dispatch 时的扩展点。
  Future<void> _waitForSlot(String sessionId) async {
    var spins = 0;
    while (registry.countActiveBySession(sessionId) > maxConcurrent) {
      spins++;
      if (spins > 6000) {
        // 防御：自旋 5 分钟仍未等到槽位则放弃（避免死锁阻塞主 Agent）
        LoggerService.instance.e(
          'dispatch_subagent 等待槽位超时 (session=$sessionId)',
          category: LogCategory.ai,
          tags: ['agent', 'subagent', 'slot_timeout'],
        );
        throw TimeoutException('子 Agent 等待并发槽位超时');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> _runOne(
    SubagentRun run, {
    void Function(AgentEvent)? emitParent,
    int? parentCurrentNovelId,
  }) async {
    run.state = SubagentRunState.running;
    run.tokenSource = CancellationTokenSource();

    try {
      final scenario = SubagentScenario(
        task: run.task,
        allowedTools: run.allowedTools,
      );
      scenario.setToolDelegate((name, args, onProgress) async {
        return _executeToolForSubagent(
            name, args, onProgress, run, parentCurrentNovelId);
      });

      final llm = await _buildLlmForScenario('writing');
      final loop = AgentLoop(llm: llm, scenario: scenario);

      await loop.run(
        initialMessages: [
          ChatMessage(role: 'user', content: run.task),
        ],
        systemPrompt: scenario.buildSystemPrompt(AgentScenarioContext(
          currentNovelId: parentCurrentNovelId,
        )),
        emit: (event) => _onSubagentEvent(event, run, emitParent),
        cancellationToken: run.tokenSource!.token,
      );

      run.finalSummary = _extractSummary(run.chatState);
      run.state = run.tokenSource!.isCancelled
          ? SubagentRunState.cancelled
          : SubagentRunState.completed;
    } catch (e, stack) {
      LoggerService.instance.e(
          '子 Agent 运行失败 (runId=${run.runId}): $e',
          stackTrace: stack.toString(),
          category: LogCategory.ai,
          tags: ['agent', 'subagent', 'error']);
      run.state = SubagentRunState.failed;
      run.errorMessage = e.toString();
    } finally {
      await run.eventSub?.cancel();
      run.eventSub = null;
    }
  }

  void _onSubagentEvent(
      AgentEvent event, SubagentRun run, void Function(AgentEvent)? emitParent) {
    final tagged = EventTagger.tag(event, run.runId);
    SubagentStateProjector.project(tagged, run);
    emitParent?.call(tagged);
  }

  /// 从最终 chatState 倒序找首条非空 assistant 消息文本作为 finalSummary。
  String _extractSummary(AgentChatState state) {
    final msgs = state.messages;
    for (var i = msgs.length - 1; i >= 0; i--) {
      if (msgs[i].role == AgentChatRole.assistant) {
        final text = msgs[i].content;
        if (text.trim().isNotEmpty) return text;
      }
    }
    return '';
  }

  String _buildResultJson(SubagentRun run) {
    switch (run.state) {
      case SubagentRunState.completed:
        return jsonEncode({
          'success': true,
          'summary': run.finalSummary ?? '',
          'runId': run.runId,
        });
      case SubagentRunState.cancelled:
        return jsonEncode({
          'error': 'cancelled',
          'message': '子 Agent 被取消。',
          'runId': run.runId,
        });
      case SubagentRunState.failed:
        return jsonEncode({
          'error': 'subagent_failed',
          'message': run.errorMessage ?? '子 Agent 运行失败',
          'runId': run.runId,
        });
      default:
        return jsonEncode({'error': 'unknown_state', 'runId': run.runId});
    }
  }

  /// 为子 Agent 构造 LlmProvider。
  ///
  /// - 默认走 [llmConfigServiceProvider] 拿 writing 场景激活配置；
  /// - 测试可通过 [_llmProviderFactoryOverride] 注入 mock provider。
  Future<LlmProvider> _buildLlmForScenario(String scenarioId) async {
    final factoryOverride = _llmProviderFactoryOverride;
    if (factoryOverride != null) {
      return factoryOverride(scenarioId);
    }
    final configService = ref.read(llmConfigServiceProvider);
    await configService.ensureMigratedFromLegacy();
    await configService.ensureGlobalActiveMigrated();
    final activeConfig =
        await configService.getActiveConfig(scenarioId: scenarioId);
    if (activeConfig == null) {
      throw StateError('LLM 未配置（scenarioId=$scenarioId），子 Agent 无法启动');
    }
    final llmProviderConfig = configService.buildLlmProviderConfig(activeConfig);
    return AiServiceFactory.buildLlmProvider(llmProviderConfig);
  }

  Future<String> _executeToolForSubagent(
    String name,
    Map<String, dynamic> args,
    void Function(int)? onProgress,
    SubagentRun run,
    int? parentCurrentNovelId,
  ) async {
    final executor = ToolExecutor(ref);
    return executor.execute(
      name,
      args,
      scenarioContext: AgentScenarioContext(
        scenarioId: 'writing',
        currentNovelId: parentCurrentNovelId,
      ),
      onProgress: onProgress,
    );
  }

  /// 取消某 session 全部活跃 run（主 Agent cancel 时级联）。
  void cancelAllForSession(String sessionId) {
    for (final run in registry.listForSession(sessionId)) {
      if (!run.isTerminal) {
        run.tokenSource?.cancel(reason: '主 Agent 取消');
      }
    }
  }

  /// 测试专用：只入队 registry 不真跑。
  Future<String> enqueueForTest(
    String sessionId, {
    required String task,
    required List<String> allowedTools,
  }) async {
    if (registry.countActiveBySession(sessionId) >= maxQueue) {
      return jsonEncode({
        'error': 'max_subagents_reached',
        'message': '已达上限',
      });
    }
    final run = registry.create(
      parentSessionId: sessionId,
      task: task,
      allowedTools: allowedTools,
    );
    return jsonEncode({'success': true, 'runId': run.runId});
  }

  /// 测试专用：暴露 dispatch 入口但不要求 parentToolCallId（用空字符串占位）。
  Future<String> dispatchForTest({
    required String parentSessionId,
    required String task,
    required List<String> allowedTools,
  }) {
    return dispatch(
      parentSessionId: parentSessionId,
      task: task,
      allowedTools: allowedTools,
      parentToolCallId: 'test-tc',
    );
  }

  /// 测试专用：暴露 _buildResultJson。
  String buildResultJsonForTest(SubagentRun run) => _buildResultJson(run);
}

/// 测试用 Ref：forTest 路径若意外触发真实 ref 调用会立即抛错，便于定位。
class _ThrowRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('forTest Ref 不支持真实调用: ${invocation.memberName}');
}
