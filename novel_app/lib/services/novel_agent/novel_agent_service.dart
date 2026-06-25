/// 本地小说写作 Agent 门面服务
///
/// Phase 2: 封装 AgentLoop，提供面向 UI 的接口
/// 重构: 支持多场景切换，通过 scenarioId 和 AgentScenarioContext 分派
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novel_app/services/logger_service.dart';
import 'package:novel_app/core/providers/services/ai_service_providers.dart';

import '../dsl_engine/llm_provider.dart';
import '../../utils/cancellation_token.dart';
import 'agent_event.dart';
import 'agent_loop.dart';
import 'agent_scenario.dart';
import 'agent_scenario_factory.dart';

class NovelAgentService {
  final Ref ref;
  final StreamController<AgentEvent> _controller =
      StreamController<AgentEvent>.broadcast();
  bool _isRunning = false;

  /// 当前运行回合的取消令牌（无任务运行时为 null）
  ///
  /// 由 [sendMessage] 创建并传递给 [AgentLoop.run]。
  /// 调用 [cancel] 触发后，AgentLoop 会在当前这轮 LLM 输出完成后
  /// 退出循环（不再执行工具、不再进入下一轮）。
  CancellationToken? _currentToken;

  NovelAgentService(this.ref);

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 事件流
  Stream<AgentEvent> get events => _controller.stream;

  /// 检查 LLM 是否已配置
  Future<bool> isConfigured() async {
    final configService = ref.read(llmConfigServiceProvider);
    await configService.ensureMigratedFromLegacy();
    final config = await configService.getActiveConfig();
    return config != null;
  }

  /// 检查指定场景的 LLM 是否已配置（考虑场景级回退链）
  Future<bool> isConfiguredForScenario(String scenarioId) async {
    final configService = ref.read(llmConfigServiceProvider);
    await configService.ensureMigratedFromLegacy();
    final config = await configService.getActiveConfig(scenarioId: scenarioId);
    return config != null;
  }

  /// 取消当前正在运行的 Agent 回合
  ///
  /// 取消是**温和的**：当前正在进行的 LLM 流式输出会自然完成，
  /// 但 ReAct 循环不会再执行工具、不会再进入下一轮。
  void cancel() {
    if (_currentToken != null) {
      LoggerService.instance.i(
        'Agent 已取消（用户主动）',
        category: LogCategory.ai,
        tags: ['agent', 'service', 'cancel'],
      );
      _currentToken!.cancel(reason: '用户主动取消');
      _currentToken = null;
    }
  }

  /// 发送消息给 Agent
  ///
  /// [userInput] 用户输入
  /// [history] 之前的对话历史（用于上下文）
  /// [scenarioId] 场景标识（'writing' | 'webview_extract' | ...）
  /// [scenarioContext] 场景上下文参数
  /// [messageOwners] 可选对齐信息：长度 = [history] 的长度，
  ///   元素为 history 中每条消息对应的 HermesMessage 在 UI 列表中的索引。
  ///   透传给 AgentLoop 用于压缩时反推被丢弃的 HermesMessage 区间，
  ///   通知 UI 同步裁剪。
  Future<void> sendMessage({
    required String userInput,
    required List<ChatMessage> history,
    required String scenarioId,
    required AgentScenarioContext scenarioContext,
    List<int>? messageOwners,
  }) async {
    if (_isRunning) {
      _controller.add(const AgentErrorEvent('Agent 正在运行中'));
      LoggerService.instance.w('Agent 拒绝请求（已在运行中）',
          category: LogCategory.ai, tags: ['agent', 'service', 'busy']);
      return;
    }

    if (!await isConfiguredForScenario(scenarioId)) {
      _controller.add(const AgentErrorEvent(
          '请先在 hermes 窗口右上角设置中配置 LLM 后端，或在设置 → AI 配置中配置全局默认 LLM'));
      LoggerService.instance.w(
          'Agent 拒绝请求（未配置 LLM）: scenario=$scenarioId',
          category: LogCategory.ai, tags: ['agent', 'service', 'not_configured']);
      return;
    }

    _isRunning = true;
    final token = CancellationToken();
    _currentToken = token;

    try {
      LoggerService.instance.d('Agent 请求处理: "$userInput" (history=${history.length}条, scenario=$scenarioId)',
          category: LogCategory.ai, tags: ['agent', 'service', 'request', scenarioId]);

      // 构造 LLM Provider（从 LlmConfigService 获取激活配置，支持场景级覆盖）
      final configService = ref.read(llmConfigServiceProvider);
      await configService.ensureMigratedFromLegacy();
      final activeConfig =
          await configService.getActiveConfig(scenarioId: scenarioId);
      if (activeConfig == null) {
        _controller.add(const AgentErrorEvent(
            '请先在 hermes 窗口右上角设置中配置 LLM 后端，或在设置 → AI 配置中配置全局默认 LLM'));
        return;
      }
      final llmProviderConfig = configService.buildLlmProviderConfig(activeConfig);
      final config = LlmConfig(
        baseUrl: llmProviderConfig.baseUrl,
        apiKey: llmProviderConfig.apiKey,
        defaultModel: llmProviderConfig.defaultModel,
        timeout: const Duration(seconds: 120),
      );
      final llm = LlmProvider(config, httpClient: IoLlmHttpClient());

      // 构造场景（异步，可能需要初始化 Headless WebView）
      final scenario =
          await AgentScenarioFactory(ref).build(scenarioId, scenarioContext);

      try {
        // 构造循环
        final loop = AgentLoop(llm: llm, scenario: scenario);

        // 加载场景经验记忆（在 buildSystemPrompt 前调用，让场景有缓存）
        await scenario.getMemories();

        // 构造 system prompt（由场景生成）
        final systemPrompt = scenario.buildSystemPrompt(scenarioContext);

        // 构造初始消息
        final initialMessages = [
          ...history,
          ChatMessage(role: 'user', content: userInput),
        ];

        // 运行循环
        await loop.run(
          initialMessages: initialMessages,
          systemPrompt: systemPrompt,
          emit: (event) => _controller.add(event),
          cancellationToken: token,
          messageOwners: messageOwners,
        );

        final cancelledTag = token.isCancelled ? ' (cancelled)' : '';
        LoggerService.instance.i('Agent 请求处理完成$cancelledTag (scenario=$scenarioId)',
            category: LogCategory.ai, tags: ['agent', 'service', 'complete', scenarioId]);
      } finally {
        // 场景资源清理（如释放 HeadlessWebViewPool 使用权）
        await scenario.cleanup();
      }
    } catch (e, stack) {
      LoggerService.instance.e('Agent 请求处理失败: $e',
          stackTrace: stack.toString(),
          category: LogCategory.ai,
          tags: ['agent', 'service', 'error']);
      _controller.add(AgentErrorEvent(e.toString()));
    } finally {
      _isRunning = false;
      _currentToken = null;
    }
  }

  /// 取消当前运行（仅关闭流，不中断底层 HTTP）
  void dispose() {
    _controller.close();
  }
}

/// Agent 服务 Provider
final novelAgentServiceProvider = Provider<NovelAgentService>((ref) {
  LoggerService.instance.i('NovelAgentService 初始化',
      category: LogCategory.ai, tags: ['agent', 'service', 'init']);
  final service = NovelAgentService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
