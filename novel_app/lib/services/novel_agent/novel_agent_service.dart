/// 本地小说写作 Agent 门面服务
///
/// Phase 2: 封装 AgentLoop，提供面向 UI 的接口
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novel_app/services/logger_service.dart';

import '../../core/providers/reading_context_providers.dart';
import '../dsl_engine/dsl_engine_config.dart';
import '../dsl_engine/llm_provider.dart';
import '../dsl_engine/real_llm_executor.dart';
import 'agent_event.dart';
import 'agent_loop.dart';
import 'agent_system_prompt.dart';
import 'tool_executor.dart';

class NovelAgentService {
  final Ref ref;
  final StreamController<AgentEvent> _controller =
      StreamController<AgentEvent>.broadcast();
  bool _isRunning = false;

  NovelAgentService(this.ref);

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 事件流
  Stream<AgentEvent> get events => _controller.stream;

  /// 检查 LLM 是否已配置
  Future<bool> isConfigured() async {
    return await DslEngineConfig.isConfigured();
  }

  /// 发送消息给 Agent
  ///
  /// [userInput] 用户输入
  /// [history] 之前的对话历史（用于上下文）
  /// [requestConfirmation] 确认回调
  Future<void> sendMessage({
    required String userInput,
    required List<ChatMessage> history,
    required Future<bool> Function(
      String toolName,
      Map<String, dynamic> args,
      String toolCallId,
    ) requestConfirmation,
  }) async {
    if (_isRunning) {
      _controller.add(const AgentErrorEvent('Agent 正在运行中'));
      LoggerService.instance.w('Agent 拒绝请求（已在运行中）',
          category: LogCategory.ai, tags: ['agent', 'service', 'busy']);
      return;
    }

    if (!await isConfigured()) {
      _controller.add(const AgentErrorEvent(
          '请先在设置 → Dify/AI 设置中配置 DSL Engine（OpenAI 兼容 API）'));
      LoggerService.instance.w('Agent 拒绝请求（未配置 DSLEngine）',
          category: LogCategory.ai, tags: ['agent', 'service', 'not_configured']);
      return;
    }

    _isRunning = true;

    try {
      LoggerService.instance.d('Agent 请求处理: "$userInput" (history=${history.length}条)',
          category: LogCategory.ai, tags: ['agent', 'service', 'request']);

      // 构造 LLM Provider
      final config = LlmConfig(
        baseUrl: await DslEngineConfig.getApiUrl(),
        apiKey: await DslEngineConfig.getApiKey(),
        defaultModel: await DslEngineConfig.getModel() == ''
            ? 'deepseek-chat'
            : await DslEngineConfig.getModel(),
        timeout: const Duration(seconds: 120),
      );
      final llm = LlmProvider(config, httpClient: IoLlmHttpClient());

      // 构造工具执行器
      final tools = ToolExecutor(ref);

      // 构造循环
      final loop = AgentLoop(llm: llm, tools: tools);

      // 构造 system prompt
      final readingContext = ref.read(readingContextProvider);
      final systemPrompt = AgentSystemPrompt.build(
        readingContext: readingContext,
      );

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
        requestConfirmation: requestConfirmation,
      );

      LoggerService.instance.i('Agent 请求处理完成',
          category: LogCategory.ai, tags: ['agent', 'service', 'complete']);
    } catch (e, stack) {
      LoggerService.instance.e('Agent 请求处理失败: $e',
          stackTrace: stack.toString(),
          category: LogCategory.ai,
          tags: ['agent', 'service', 'error']);
      _controller.add(AgentErrorEvent(e.toString()));
    } finally {
      _isRunning = false;
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