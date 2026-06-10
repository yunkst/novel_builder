/// Agent ReAct 循环核心
///
/// Phase 2: 实现思考-行动循环，管理 LLM 对话和工具调用
library;

import 'dart:convert';

import 'package:novel_app/services/logger_service.dart';

import '../dsl_engine/llm_provider.dart';
import 'agent_event.dart';
import 'agent_tools.dart';
import 'tool_executor.dart';

/// Agent 循环配置
class AgentLoopConfig {
  final int maxRounds;
  final int toolResultMaxChars;

  const AgentLoopConfig({
    this.maxRounds = 10,
    this.toolResultMaxChars = 2000,
  });
}

/// Agent ReAct 循环
///
/// 管理 LLM 对话、工具调用、确认流程
class AgentLoop {
  final LlmProvider _llm;
  final ToolExecutor _tools;
  final AgentLoopConfig _config;

  AgentLoop({
    required LlmProvider llm,
    required ToolExecutor tools,
    AgentLoopConfig? config,
  })  : _llm = llm,
        _tools = tools,
        _config = config ?? const AgentLoopConfig();

  /// 运行 Agent 循环
  ///
  /// [initialMessages] 初始消息列表（不含 system prompt）
  /// [systemPrompt] 系统提示词
  /// [emit] 事件回调
  /// [requestConfirmation] 确认回调，返回 true 表示用户同意
  Future<void> run({
    required List<ChatMessage> initialMessages,
    required String systemPrompt,
    required void Function(AgentEvent event) emit,
    required Future<bool> Function(
      String toolName,
      Map<String, dynamic> args,
      String toolCallId,
    ) requestConfirmation,
  }) async {
    final messages = <ChatMessage>[
      ChatMessage(role: 'system', content: systemPrompt),
      ...initialMessages,
    ];

    LoggerService.instance.i('Agent 循环开始',
        category: LogCategory.ai, tags: ['agent', 'loop_start']);

    for (int round = 0; round < _config.maxRounds; round++) {
      try {
        LoggerService.instance.d('Agent 循环第 $round 轮',
            category: LogCategory.ai, tags: ['agent', 'loop']);

        // 1. 调用 LLM（带工具定义）
        LoggerService.instance.d('调用 LLM (round $round, ${AgentTools.allTools.length} 个工具)',
            category: LogCategory.ai, tags: ['agent', 'llm', 'request']);
        final response = await _llm.chat(
          messages: messages,
          tools: AgentTools.allTools,
          toolChoice: 'auto',
        );
        LoggerService.instance.i('LLM 响应 (round $round, ${response.toolCalls.length} 个工具调用, content=${response.content.length}chars)',
            category: LogCategory.ai, tags: ['agent', 'llm', 'response']);

        // 2. 无工具调用 → 结束
        if (!response.hasToolCalls) {
          // 流式输出文本
          if (response.content.isNotEmpty) {
            emit(TextDeltaEvent(response.content));
          }
          emit(const AgentDoneEvent());
          LoggerService.instance.i('Agent 循环完成（无工具调用，共 $round 轮）',
              category: LogCategory.ai, tags: ['agent', 'loop_end']);
          return;
        }

        // 3. 注入 assistant 消息（含 tool_calls）
        messages.add(ChatMessage(
          role: 'assistant',
          content: response.content.isNotEmpty ? response.content : null,
          toolCalls: response.toolCalls,
        ));

        // 4. 执行每个工具调用
        for (final call in response.toolCalls) {
          LoggerService.instance.d('工具调度: ${call.name}',
              category: LogCategory.ai, tags: ['agent', 'tool', call.name]);
          emit(ToolCallStartEvent(call.name, call.arguments, call.id));

          Map<String, dynamic> result;

          // 破坏性操作确认
          if (_tools.isDestructive(call.name)) {
            final approved = await requestConfirmation(
              call.name,
              call.arguments,
              call.id,
            );
            if (!approved) {
              result = {
                'error': 'user_rejected',
                'message': '用户拒绝执行此操作',
              };
              messages.add(ChatMessage(
                role: 'tool',
                content: jsonEncode(result),
                toolCallId: call.id,
              ));
              emit(ToolCallEndEvent(
                call.name,
                call.id,
                jsonEncode(result),
                success: false,
              ));
              LoggerService.instance.i('用户拒绝工具: ${call.name}',
                  category: LogCategory.ai,
                  tags: ['agent', 'tool', call.name, 'rejected']);
              continue;
            }
          }

          // 执行工具
          final rawResult = await _tools.execute(call.name, call.arguments);
          try {
            result = jsonDecode(rawResult) as Map<String, dynamic>;
          } catch (_) {
            result = {'raw': rawResult};
          }

          // 截断过长结果
          var resultStr = jsonEncode(result);
          if (resultStr.length > _config.toolResultMaxChars) {
            resultStr = '${resultStr.substring(0, _config.toolResultMaxChars)}... [truncated]';
          }

          messages.add(ChatMessage(
            role: 'tool',
            content: resultStr,
            toolCallId: call.id,
          ));

          final toolSuccess = !result.containsKey('error');
          emit(ToolCallEndEvent(
            call.name,
            call.id,
            resultStr,
            success: toolSuccess,
          ));
          LoggerService.instance.i(
              '工具完成: ${call.name} (success=$toolSuccess, resultLen=${resultStr.length})',
              category: LogCategory.ai,
              tags: ['agent', 'tool', call.name, toolSuccess ? 'success' : 'error']);
        }
      } catch (e, stack) {
        LoggerService.instance.e('Agent 循环异常 (round $round): $e',
            stackTrace: stack.toString(),
            category: LogCategory.ai,
            tags: ['agent', 'loop', 'error']);
        emit(AgentErrorEvent(e.toString()));
        return;
      }
    }

    LoggerService.instance.i('Agent 达到最大轮数限制 (${_config.maxRounds})，发起强制总结',
        category: LogCategory.ai, tags: ['agent', 'max_rounds']);
    messages.add(ChatMessage(
      role: 'user',
      content: '请用一句话总结你已完成的操作。',
    ));
    try {
      final finalResponse = await _llm.chat(messages: messages);
      if (finalResponse.content.isNotEmpty) {
        emit(TextDeltaEvent(finalResponse.content));
      }
    } catch (_) {
      // 总结失败也不影响
    }
    emit(const AgentDoneEvent());
    LoggerService.instance.i('Agent 循环完成（达到最大轮数）',
        category: LogCategory.ai, tags: ['agent', 'loop_end']);
  }
}