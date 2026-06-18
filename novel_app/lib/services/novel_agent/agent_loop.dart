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
    this.maxRounds = 50,
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
  /// [cancellationToken] 取消令牌；触发取消后，当前这轮 LLM 输出完成，
  ///   但循环不再执行后续工具、不再进入下一轮（不中断底层 LLM HTTP）。
  /// [messageOwners] 可选对齐信息：长度 = [initialMessages] 的长度，
  ///   元素为对应 HermesMessage 在 UI 列表中的索引，-1 表示 system 消息不映射。
  ///   压缩时透传给 [ContextCompactor.compact]，用于反推被丢弃的 HermesMessage 区间，
  ///   通过 [CompactionEvent.droppedHermesRange] 通知 UI 同步裁剪。
  Future<void> run({
    required List<ChatMessage> initialMessages,
    required String systemPrompt,
    required void Function(AgentEvent event) emit,
    CancellationToken? cancellationToken,
    List<int>? messageOwners,
  }) async {
    final messages = <ChatMessage>[
      ChatMessage(role: 'system', content: systemPrompt),
      ...initialMessages,
    ];

    // owners 同步构建：[0] = -1 (system prompt), 其后 = initialMessages 对应的 owner
    // 循环过程中新增的 assistant/tool 消息不映射到 UI，owner = -1
    final owners = List<int>.filled(messages.length, -1);
    if (messageOwners != null) {
      for (int i = 0; i < messageOwners.length && i + 1 < owners.length; i++) {
        owners[i + 1] = messageOwners[i];
      }
    }

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
          final preCompactionMsgCount = messages.length;
          LoggerService.instance.w(
            '触发上下文压缩: 消息总量 $preCompactionMsgCount '
            '条，超过阈值 (${_config.compaction.maxContextChars} 字符)',
            category: LogCategory.ai,
            tags: ['agent', 'compaction', 'triggered', _scenario.id],
          );
          final result = _compactor.compact(
            messages: messages,
            systemPrompt: systemPrompt,
            messageOwners: owners,
          );
          // 同步重置 owners：清空后重新填入 compact 后的新 messages 对应的 owners
          // compact 后的 messages 结构：[system prompt, 压缩提示, ...尾部 messages]
          // 前两条 owner 必为 -1
          final compactedOwners = <int>[-1, -1];
          // result.messages 的前 2 条是 compact 内部插入的 system,
          // 第 3 条起对应原 messages[splitIndex..]，splitIndex = preCompactionMsgCount - droppedCount
          final splitIndex = preCompactionMsgCount - result.droppedMessageCount;
          for (int i = 2; i < result.messages.length; i++) {
            final originalMsgIndex = (i - 2) + splitIndex;
            if (originalMsgIndex < owners.length) {
              compactedOwners.add(owners[originalMsgIndex]);
            } else {
              compactedOwners.add(-1);
            }
          }
          messages
            ..clear()
            ..addAll(result.messages);
          owners
            ..clear()
            ..addAll(compactedOwners);
          emit(CompactionEvent(
            removedChars: result.removedChars,
            originalChars: result.originalChars,
            keptMessageCount: result.keptMessageCount,
            droppedMessageCount: result.droppedMessageCount,
            droppedHermesRange: result.droppedHermesRange,
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

        // 异常 finishReason（length 截断 / content_filter 审查）独立告警
        if (streamFinishReason == 'length' ||
            streamFinishReason == 'content_filter') {
          LoggerService.instance.w(
            'LLM finish_reason=$streamFinishReason (round $round, scenario=${_scenario.id})',
            category: LogCategory.ai,
            tags: [
              'agent',
              'llm',
              'finish_reason',
              streamFinishReason!,
              _scenario.id,
            ],
          );
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

        // 3. 无工具调用 → 先把本轮 assistant 消息入栈，再检查场景是否要注入提示
        if (toolCalls.isEmpty) {
          // 把本轮 assistant 消息加入 messages
          // （无 tool_calls 时后续不会自动加入，但 follow-up 注入后 LLM 需要看到上文）
          if (fullContent.isNotEmpty) {
            messages.add(ChatMessage(
              role: 'assistant',
              content: fullContent,
            ));
          }

          // 场景注入钩子：允许场景在"即将结束"时追加一条 user 提示
          // 让 Agent 再尝试一轮（例如提示"已生成脚本但未保存，请调 save_script"）
          final injection = await _scenario.onNoToolCalls(messages);
          if (injection != null) {
            messages.add(ChatMessage(role: 'user', content: injection));
            emit(TextDeltaEvent('\n\n$injection\n\n'));
            LoggerService.instance.i(
              'Agent 循环注入场景提示 (round $round, scenario=${_scenario.id})，继续下一轮',
              category: LogCategory.ai,
              tags: ['agent', 'loop', 'injection', _scenario.id],
            );
            continue; // 不结束，继续下一轮
          }

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

          // 执行工具（委托给场景）
          final rawResult = await _scenario.executeTool(call.name, call.arguments);
          try {
            result = jsonDecode(rawResult) as Map<String, dynamic>;
          } catch (_) {
            LoggerService.instance.w(
              '工具结果 JSON 解析失败: ${call.name}, raw=${rawResult.length}字符',
              category: LogCategory.ai,
              tags: ['agent', 'tool', call.name, 'json_parse_failed'],
            );
            result = {'raw': rawResult};
          }

          // 截断过长结果：错误响应优先保留 error/message/suggestion 字段；
          // __meta（run_id 等关键元数据）始终保留到末尾，永不被截断。
          var resultStr = jsonEncode(result);

          // 剥离 __meta：体积小但承载 run_id 等句柄，必须送达 LLM
          final meta = result.remove('__meta');

          if (resultStr.length > _config.toolResultMaxChars) {
            LoggerService.instance.d(
              '工具结果截断: ${call.name} originalLen=${resultStr.length} → ${_config.toolResultMaxChars}',
              category: LogCategory.ai,
              tags: ['agent', 'tool', call.name, 'truncated'],
            );
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
    } catch (e) {
      // 总结失败也不影响
      LoggerService.instance.w(
        'Agent max_rounds 总结失败: $e',
        category: LogCategory.ai,
        tags: ['agent', 'max_rounds', 'summary_failed'],
      );
    }
    emit(const AgentDoneEvent());
    LoggerService.instance.i('Agent 循环完成（达到最大轮数, scenario=${_scenario.id}）',
        category: LogCategory.ai, tags: ['agent', 'loop_end', _scenario.id]);
  }
}
