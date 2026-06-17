/// Agent ReAct 循环核心
///
/// Phase 2: 实现思考-行动循环，管理 LLM 对话和工具调用
/// 重构: 依赖 AgentScenario 抽象，支持多场景切换
library;

import 'dart:convert';

import 'package:novel_app/services/logger_service.dart';
import 'package:novel_app/utils/cancellation_token.dart';

import '../dsl_engine/llm_provider.dart';
import 'agent_event.dart';
import 'agent_scenario.dart';
import 'context_compactor.dart';

/// Agent 循环配置
class AgentLoopConfig {
  final int maxRounds;
  final int toolResultMaxChars;

  /// 上下文压缩配置（默认启用）
  final CompactorConfig compaction;

  const AgentLoopConfig({
    this.maxRounds = 10,
    this.toolResultMaxChars = 2000,
    this.compaction = const CompactorConfig(),
  });
}

/// Agent ReAct 循环
///
/// 管理 LLM 对话、工具调用、确认流程。
/// 通过 [AgentScenario] 抽象支持不同场景的工具集和 system prompt。
class AgentLoop {
  final LlmProvider _llm;
  final AgentScenario _scenario;
  final AgentLoopConfig _config;
  final ContextCompactor _compactor;

  AgentLoop({
    required LlmProvider llm,
    required AgentScenario scenario,
    AgentLoopConfig? config,
  })  : _llm = llm,
        _scenario = scenario,
        _config = config ?? const AgentLoopConfig(),
        _compactor = ContextCompactor(
            config: (config ?? const AgentLoopConfig()).compaction);

  /// 运行 Agent 循环
  ///
  /// [initialMessages] 初始消息列表（不含 system prompt）
  /// [systemPrompt] 系统提示词
  /// [emit] 事件回调
  /// [requestConfirmation] 确认回调，返回 true 表示用户同意
  /// [cancellationToken] 取消令牌；触发取消后，当前这轮 LLM 输出完成，
  ///   但循环不再执行后续工具、不再进入下一轮（不中断底层 LLM HTTP）。
  Future<void> run({
    required List<ChatMessage> initialMessages,
    required String systemPrompt,
    required void Function(AgentEvent event) emit,
    required Future<bool> Function(
      String toolName,
      Map<String, dynamic> args,
      String toolCallId,
    ) requestConfirmation,
    CancellationToken? cancellationToken,
  }) async {
    final messages = <ChatMessage>[
      ChatMessage(role: 'system', content: systemPrompt),
      ...initialMessages,
    ];

    LoggerService.instance.i('Agent 循环开始 (scenario=${_scenario.id})',
        category: LogCategory.ai, tags: ['agent', 'loop_start', _scenario.id]);

    for (int round = 0; round < _config.maxRounds; round++) {
      // 检查点 A：进入新一轮前（例如上一轮工具执行后被取消）
      if (cancellationToken?.isCancelled == true) {
        LoggerService.instance.i(
            'Agent 循环已取消，不再进入第 $round 轮 (scenario=${_scenario.id})',
            category: LogCategory.ai,
            tags: ['agent', 'loop', 'cancelled', _scenario.id]);
        emit(const AgentDoneEvent());
        return;
      }

      try {
        LoggerService.instance.d('Agent 循环第 $round 轮 (${_scenario.id})',
            category: LogCategory.ai, tags: ['agent', 'loop', _scenario.id]);

        // 0. 上下文压缩检查（每轮 LLM 调用前）
        //    防止 messages 无限增长导致超出 LLM 上下文窗口
        if (_compactor.needsCompaction(messages)) {
          LoggerService.instance.w(
            '触发上下文压缩: 消息总量 ${_compactor.needsCompaction(messages) ? messages.length : 0} '
            '条，超过阈值 (${_config.compaction.maxContextChars} 字符)',
            category: LogCategory.ai,
            tags: ['agent', 'compaction', 'triggered', _scenario.id],
          );
          final result = _compactor.compact(
            messages: messages,
            systemPrompt: systemPrompt,
          );
          messages
            ..clear()
            ..addAll(result.messages);
          emit(CompactionEvent(
            removedChars: result.removedChars,
            originalChars: result.originalChars,
            keptMessageCount: result.keptMessageCount,
            droppedMessageCount: result.droppedMessageCount,
          ));
        }

        // 1. 调用 LLM（流式 + 工具定义），逐 chunk 实时 emit
        final toolsCount = _scenario.tools.length;
        LoggerService.instance.d('调用 LLM (round $round, $toolsCount 个工具, 流式, scenario=${_scenario.id})',
            category: LogCategory.ai, tags: ['agent', 'llm', 'request']);

        final streamingResult = StreamingResult();
        String? streamFinishReason;
        int contentChunkCount = 0;

        await for (final chunk in _llm.chatStreamWithTools(
          messages: messages,
          tools: _scenario.tools,
          toolChoice: 'auto',
        )) {
          // 实时 emit 文本增量 → UI 流式展示
          if (chunk.isContent) {
            contentChunkCount++;
            emit(TextDeltaEvent(chunk.contentChunk!));
          }
          // 累积 tool_calls delta
          if (chunk.isToolCallDelta) {
            streamingResult.toolCallDeltas.addAll(chunk.toolCallDeltas);
          }
          // 记录 finish_reason
          if (chunk.isFinished) {
            streamFinishReason = chunk.finishReason;
          }
        }

        // 2. 流结束后聚合 tool_calls
        final toolCalls = streamingResult.buildToolCalls();
        final fullContent = streamingResult.fullContent;

        // 检查点 B：本轮 LLM 流式输出已完整 emit，若已取消则不再执行工具 / 进入下一轮
        // 满足"让 agent 输出完，但不继续下一个循环"的语义
        if (cancellationToken?.isCancelled == true) {
          LoggerService.instance.i(
              'Agent 循环已取消（本轮 LLM 输出完，跳过工具与下一轮，scenario=${_scenario.id}）',
              category: LogCategory.ai,
              tags: ['agent', 'loop', 'cancelled', _scenario.id]);
          emit(const AgentDoneEvent());
          return;
        }

        // contentLength=0 但 finishReason 不是 tool_calls 时，说明 LLM 异常返回空内容，需要告警
        // contentLength=0 + finishReason=tool_calls 是正常的 ReAct 行为（LLM 决定调用工具）
        final isAbnormalEmpty = fullContent.isEmpty &&
            toolCalls.isEmpty &&
            streamFinishReason != 'tool_calls';
        final logMessage =
            'LLM 流式响应 (round $round): '
            'contentChunks=$contentChunkCount, '
            'contentLength=${fullContent.length}, '
            'toolCalls=${toolCalls.length}, '
            'finishReason=$streamFinishReason';
        if (isAbnormalEmpty) {
          LoggerService.instance.w(
            '$logMessage [异常: 响应内容为空]',
            category: LogCategory.ai,
            tags: ['agent', 'llm', 'response', 'abnormal-empty', _scenario.id],
          );
        } else {
          LoggerService.instance.i(
            logMessage,
            category: LogCategory.ai,
            tags: ['agent', 'llm', 'response', _scenario.id],
          );
        }

        // 3. 无工具调用 → 结束
        if (toolCalls.isEmpty) {
          emit(const AgentDoneEvent());
          LoggerService.instance.i('Agent 循环完成（无工具调用，共 $round 轮, scenario=${_scenario.id}）',
              category: LogCategory.ai, tags: ['agent', 'loop_end', _scenario.id]);
          return;
        }

        // 4. 注入 assistant 消息（含 tool_calls）
        messages.add(ChatMessage(
          role: 'assistant',
          content: fullContent.isNotEmpty ? fullContent : null,
          toolCalls: toolCalls,
        ));

        // 5. 执行每个工具调用
        for (final call in toolCalls) {
          // 检查点 C：批量工具执行中途被取消，跳过剩余工具
          if (cancellationToken?.isCancelled == true) {
            LoggerService.instance.i(
                'Agent 循环已取消，跳过工具 ${call.name} 及后续工具 (scenario=${_scenario.id})',
                category: LogCategory.ai,
                tags: ['agent', 'loop', 'cancelled', _scenario.id]);
            emit(const AgentDoneEvent());
            return;
          }

          LoggerService.instance.d('工具调度: ${call.name} (scenario=${_scenario.id})',
              category: LogCategory.ai, tags: ['agent', 'tool', call.name, _scenario.id]);
          emit(ToolCallStartEvent(call.name, call.arguments, call.id));

          Map<String, dynamic> result;

          // 破坏性操作确认
          if (_scenario.destructiveTools.contains(call.name)) {
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
              LoggerService.instance.i('用户拒绝工具: ${call.name} (scenario=${_scenario.id})',
                  category: LogCategory.ai,
                  tags: ['agent', 'tool', call.name, 'rejected', _scenario.id]);
              continue;
            }
          }

          // 执行工具（委托给场景）
          final rawResult = await _scenario.executeTool(call.name, call.arguments);
          try {
            result = jsonDecode(rawResult) as Map<String, dynamic>;
          } catch (_) {
            result = {'raw': rawResult};
          }

          // 截断过长结果：错误响应优先保留 error/message/suggestion 字段；
          // __meta（run_id 等关键元数据）始终保留到末尾，永不被截断。
          var resultStr = jsonEncode(result);

          // 剥离 __meta：体积小但承载 run_id 等句柄，必须送达 LLM
          final meta = result.remove('__meta');

          if (resultStr.length > _config.toolResultMaxChars) {
            if (result.containsKey('error')) {
              // 错误结果：优先保留错误信息，截断其余数据
              final errorInfo = <String, dynamic>{
                'error': result['error'],
              };
              if (result['message'] != null) {
                errorInfo['message'] = result['message'];
              }
              if (result['suggestion'] != null) {
                errorInfo['suggestion'] = result['suggestion'];
              }
              final errorStr = jsonEncode(errorInfo);
              final remaining =
                  _config.toolResultMaxChars - errorStr.length - 30;
              if (remaining > 200) {
                final truncated = <String, dynamic>{
                  ...errorInfo,
                  'partial_data': resultStr.substring(0, remaining),
                };
                resultStr = jsonEncode(truncated);
              } else {
                resultStr = errorStr;
              }
            } else {
              resultStr =
                  '${resultStr.substring(0, _config.toolResultMaxChars)}... [truncated]';
            }
          }

          // __meta 拼到末尾：永远不被截断预算影响，保证 run_id 可见
          if (meta != null) {
            resultStr = '$resultStr\n\n__meta=${jsonEncode(meta)}';
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
              '工具完成: ${call.name} (success=$toolSuccess, resultLen=${resultStr.length}, scenario=${_scenario.id})',
              category: LogCategory.ai,
              tags: ['agent', 'tool', call.name, toolSuccess ? 'success' : 'error', _scenario.id]);
        }
      } catch (e, stack) {
        LoggerService.instance.e('Agent 循环异常 (round $round, scenario=${_scenario.id}): $e',
            stackTrace: stack.toString(),
            category: LogCategory.ai,
            tags: ['agent', 'loop', 'error', _scenario.id]);
        emit(AgentErrorEvent(e.toString()));
        return;
      }
    }

    LoggerService.instance.i('Agent 达到最大轮数限制 (${_config.maxRounds}, scenario=${_scenario.id})，发起强制总结',
        category: LogCategory.ai, tags: ['agent', 'max_rounds', _scenario.id]);
    messages.add(ChatMessage(
      role: 'user',
      content: '请用一句话总结你已完成的操作。',
    ));
    try {
      // 流式总结：逐 chunk emit
      await for (final chunk in _llm.chatStreamWithTools(messages: messages)) {
        if (chunk.isContent) {
          emit(TextDeltaEvent(chunk.contentChunk!));
        }
      }
    } catch (_) {
      // 总结失败也不影响
    }
    emit(const AgentDoneEvent());
    LoggerService.instance.i('Agent 循环完成（达到最大轮数, scenario=${_scenario.id}）',
        category: LogCategory.ai, tags: ['agent', 'loop_end', _scenario.id]);
  }
}
