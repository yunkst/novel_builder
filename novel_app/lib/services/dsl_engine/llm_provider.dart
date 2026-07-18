/// LLM Provider：OpenAI 兼容 LLM API 客户端
///
/// 支持：
/// - 阻塞式 chat completion
/// - SSE 流式 chat completion
/// - response_format JSON 模式（structured_output）
/// - Function Calling (tools) — 新增 Phase 1
/// - 兼容 DeepSeek / OpenAI / 其他 OpenAI 协议的服务
///
/// 不依赖任何外部 HTTP 库，使用 stream_transformers + dart:io
/// （实际 HTTP 调用通过回调注入，便于测试和替换）
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:novel_app/services/llm_logger/llm_logger.dart';
import 'package:novel_app/services/dsl_engine/retry_signals.dart';
import 'package:novel_app/services/logger_service.dart';
import 'package:novel_app/utils/json_utils.dart';
import 'package:novel_app/utils/retry_helper.dart';

// -- 配置 --

class LlmConfig {
  final String baseUrl; // 如 https://api.deepseek.com/v1
  final String apiKey;
  final String defaultModel;
  final int maxTokens;
  final double temperature;

  const LlmConfig({
    this.baseUrl = '',
    this.apiKey = '',
    this.defaultModel = '',
    this.maxTokens = 4096,
    this.temperature = 0.7,
  });

  LlmConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? defaultModel,
    int? maxTokens,
    double? temperature,
  }) {
    return LlmConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      defaultModel: defaultModel ?? this.defaultModel,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
    );
  }
}

// -- 工具调用模型 (Phase 1: Function Calling) --

/// tool_calls arguments JSON 解析失败的标记 key
///
/// 解析失败时（流式拼接被截断 / JSON 不闭合 / 解析成功但不是对象），
/// [ToolCall.arguments] 会被填入包含此 key 的标记字典。
/// 上层 [ToolExecutor] 据此短路返回引导错误，避免 LLM 拿到空参 {} 而语义崩塌。
const String kArgsParseErrorKey = '__parse_error';

/// 解析失败的详细错误信息（来自 jsonDecode 的 FormatException 等）
const String kArgsParseErrorDetailKey = '__parse_error_detail';

/// 原始 JSON 字符串的预览（截断到 500 字符），供 LLM 自助修复时参考
const String kArgsRawPreviewKey = '__raw_args_preview';

/// 构造"解析失败"标记字典的私有辅助函数
Map<String, dynamic> _markParseError({
  required String detail,
  required String raw,
}) {
  return {
    kArgsParseErrorKey: true,
    kArgsParseErrorDetailKey: detail,
    kArgsRawPreviewKey:
        raw.length > 500 ? '${raw.substring(0, 500)}...(truncated)' : raw,
  };
}

/// LLM 返回的工具调用
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final func = json['function'] as Map<String, dynamic>? ?? {};
    var args = <String, dynamic>{};
    final rawArgs = func['arguments'];
    if (rawArgs is String && rawArgs.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawArgs);
        if (decoded is Map<String, dynamic>) {
          args = decoded;
        } else {
          // 合法 JSON 但不是对象（数组、字符串、数字）→ 标记错误
          args = _markParseError(
            detail: 'JSON 解析成功但不是对象: ${decoded.runtimeType}',
            raw: rawArgs,
          );
        }
      } catch (e) {
        // 流式拼接截断 / JSON 不闭合等 → 标记错误并保留预览
        LoggerService.instance.w(
          'ToolCall arguments 解析失败: id=${json['id']}, name=${func['name']}, err=$e',
          category: LogCategory.ai,
          tags: ['dsl', 'llm', 'tool_call', 'parse_error'],
        );
        args = _markParseError(detail: e.toString(), raw: rawArgs);
      }
    } else if (rawArgs is Map<String, dynamic>) {
      args = rawArgs;
    } else if (rawArgs != null && !(rawArgs is String && rawArgs.isEmpty)) {
      // 数字、bool 等异常类型 → 标记
      // 空字符串保持空 args（正常情况：某些工具无参）
      args = _markParseError(
        detail: 'arguments 字段类型异常: ${rawArgs.runtimeType}',
        raw: rawArgs.toString(),
      );
    }
    // rawArgs == null / 空字符串 → 保持空 args（正常情况：某些工具无参）
    return ToolCall(
      id: (json['id'] as String?) ?? '',
      name: (func['name'] as String?) ?? '',
      arguments: args,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'function',
        'function': {
          'name': name,
          'arguments': jsonEncode(arguments),
        },
      };
}

/// LLM 完整响应（Phase 1: 替代纯 String 返回）
class LlmResponse {
  final String content;
  final List<ToolCall> toolCalls;

  const LlmResponse({this.content = '', this.toolCalls = const []});

  bool get hasToolCalls => toolCalls.isNotEmpty;

  /// 兼容旧代码：隐式转换回纯文本
  @override
  String toString() => content;
}

// -- 消息 --

class ChatMessage {
  final String role; // 'system' | 'user' | 'assistant' | 'tool'
  final String? content; // 可为 null（当 assistant 只有 tool_calls 无文本时）
  final String? name; // 可选：发送者名称
  final String? toolCallId; // tool 角色关联的 tool_call ID
  final List<ToolCall>? toolCalls; // assistant 角色的工具调用

  const ChatMessage({
    required this.role,
    this.content,
    this.name,
    this.toolCallId,
    this.toolCalls,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'role': role};
    if (content != null) map['content'] = content;
    if (name != null) map['name'] = name;
    if (toolCallId != null) map['tool_call_id'] = toolCallId;
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      map['tool_calls'] = toolCalls!.map((tc) => tc.toJson()).toList();
    }
    return map;
  }
}

// -- SSE 解析器 --

class SseParseResult {
  final List<String> content;
  final List<String> reasoning;

  const SseParseResult({required this.content, required this.reasoning});
}

/// 流式响应累积结果（Phase 1: 支持 tool_calls 收集）
///
/// 注意：默认构造函数创建的是**可变**空列表，便于在流式消费中
/// 逐 chunk add/addAll。如果需要不可变实例请使用 `StreamingResult.withData()`。
class StreamingResult {
  final List<String> contentChunks;
  final List<String> reasoningChunks;
  final List<Map<String, dynamic>> toolCallDeltas;

  /// 创建可变空列表实例（用于流式累积）
  StreamingResult({
    List<String>? contentChunks,
    List<String>? reasoningChunks,
    List<Map<String, dynamic>>? toolCallDeltas,
  })  : contentChunks = contentChunks ?? [],
        reasoningChunks = reasoningChunks ?? [],
        toolCallDeltas = toolCallDeltas ?? [];

  String get fullContent => contentChunks.join();

  /// 从累积的 tool_call deltas 构建最终的 ToolCall 列表
  List<ToolCall> buildToolCalls() {
    if (toolCallDeltas.isEmpty) return [];

    // 按 index 聚合 tool_call deltas
    final aggregated = <int, _ToolCallDelta>{};
    for (final delta in toolCallDeltas) {
      final idx = (delta['index'] as int?) ?? 0;
      final entry =
          aggregated.putIfAbsent(idx, () => _ToolCallDelta(index: idx));

      final id = delta['id'] as String?;
      if (id != null) entry.id = id;

      final func = delta['function'] as Map<String, dynamic>?;
      if (func != null) {
        final name = func['name'] as String?;
        if (name != null) entry.name = name;
        final args = func['arguments'] as String?;
        if (args != null) entry.argumentsBuffer.write(args);
      }
    }

    return aggregated.values.where((d) => d.name != null).map((d) {
      var args = <String, dynamic>{};
      final argsStr = d.argumentsBuffer.toString();
      if (argsStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(argsStr);
          if (decoded is Map<String, dynamic>) {
            args = decoded;
          } else {
            args = _markParseError(
              detail: 'JSON 解析成功但不是对象: ${decoded.runtimeType}',
              raw: argsStr,
            );
          }
        } catch (e) {
          LoggerService.instance.w(
            'Streaming tool_call arguments 解析失败: '
            'name=${d.name}, id=${d.id}, argsLen=${argsStr.length}, err=$e',
            category: LogCategory.ai,
            tags: ['dsl', 'llm', 'tool_call', 'streaming_parse_error'],
          );
          args = _markParseError(detail: e.toString(), raw: argsStr);
        }
      }
      return ToolCall(id: d.id ?? '', name: d.name ?? '', arguments: args);
    }).toList();
  }
}

class _ToolCallDelta {
  final int index;
  String? id;
  String? name;
  final StringBuffer argumentsBuffer = StringBuffer();

  _ToolCallDelta({required this.index});
}

class SseParser {
  /// 解析单行 SSE `data:` 帧，提取 (contentChunk, reasoningChunk)。
  ///
  /// 抽出来的共用骨架，供 [parseSseStreamWithReasoning]（Dify reasoning）
  /// 与 [parseStreamingResult]（OpenAI tool_calls）复用：
  /// - 跳过非 data 行、空 payload、[DONE] 哨兵
  /// - 解析失败只 warn 一次，不影响后续帧
  /// - 返回的字符串列表可能为空（取决于该帧只更新了哪类字段）
  static (List<String>, List<String>) _parseDataPayload(String raw) {
    final content = <String>[];
    final reasoning = <String>[];

    final lines = raw.split('\n');
    for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;

      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;
        final first = choices.first as Map<String, dynamic>;
        final delta = first['delta'] as Map<String, dynamic>?;
        if (delta == null) continue;

        // reasoning_content（Dify deepseek 扩展）
        final rc = delta['reasoning_content'];
        if (rc is String && rc.isNotEmpty) {
          reasoning.add(rc);
        }

        // 正常 content
        final c = delta['content'];
        if (c is String && c.isNotEmpty) {
          content.add(c);
        }
      } catch (_) {
        LoggerService.instance.w(
          'SSE 行解析失败: $line',
          category: LogCategory.ai,
          tags: ['dsl', 'llm', 'sse'],
        );
        // 忽略解析失败
      }
    }

    return (content, reasoning);
  }

  /// 解析带 reasoning_content 的 SSE 流（Dify deepseek thinking 格式）
  static SseParseResult parseSseStreamWithReasoning(String raw) {
    final (content, reasoning) = _parseDataPayload(raw);
    return SseParseResult(content: content, reasoning: reasoning);
  }

  /// 解析流式响应为 StreamingResult（Phase 1: 支持 tool_calls）
  ///
  /// 复用 [_parseDataPayload] 提取 content / reasoning，额外收集
  /// delta.tool_calls 列表。
  static StreamingResult parseStreamingResult(String raw) {
    final (contentChunks, reasoningChunks) = _parseDataPayload(raw);
    final toolCallDeltas = <Map<String, dynamic>>[];

    final lines = raw.split('\n');
    for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;
        final first = choices.first as Map<String, dynamic>;
        final delta = first['delta'] as Map<String, dynamic>?;
        if (delta == null) continue;
        final tcDeltas = delta['tool_calls'] as List?;
        if (tcDeltas != null) {
          for (final tc in tcDeltas) {
            if (tc is Map<String, dynamic>) {
              toolCallDeltas.add(tc);
            }
          }
        }
      } catch (_) {
        // tool_calls 解析失败独立 warn，骨架里已有内容/推理 warn，不会重复
        LoggerService.instance.w(
          'SSE tool_calls 解析失败: $line',
          category: LogCategory.ai,
          tags: ['dsl', 'llm', 'sse', 'tool_calls'],
        );
      }
    }

    return StreamingResult(
      contentChunks: contentChunks,
      reasoningChunks: reasoningChunks,
      toolCallDeltas: toolCallDeltas,
    );
  }
}

// -- LLM Provider --

/// HTTP 客户端抽象（便于测试和替换真实 HTTP 库）
abstract class LlmHttpClient {
  Future<String> postJson(String url, Map<String, String> headers, String body);
  Stream<String> postJsonStream(
      String url, Map<String, String> headers, String body);
}

/// 流式 chat completion 的单帧事件
///
/// - [contentChunk] 文本增量（可能为空，例如当帧只更新 tool_calls）
/// - [toolCallDeltas] tool_calls 增量列表（可能为空）
/// - [finishReason] 当 LLM 完成一帧响应时由 choices[].finish_reason 给出；
///   - null 表示中间帧（未完成）
///   - 'stop' 表示文本流式结束
///   - 'tool_calls' 表示 LLM 决定调用工具
///   - 'length' 表示达到 max_tokens 上限
///   - 'content_filter' / 其他
class LlmStreamChunk {
  final String? contentChunk;
  final List<Map<String, dynamic>> toolCallDeltas;
  final String? finishReason;

  const LlmStreamChunk({
    this.contentChunk,
    this.toolCallDeltas = const [],
    this.finishReason,
  });

  bool get isContent => contentChunk != null && contentChunk!.isNotEmpty;
  bool get isToolCallDelta => toolCallDeltas.isNotEmpty;
  bool get isFinished => finishReason != null;

  @override
  String toString() =>
      'LlmStreamChunk(content=$contentChunk, deltas=${toolCallDeltas.length}, finish=$finishReason)';
}

class LlmProvider {
  final LlmConfig config;
  final LlmHttpClient _httpClient;

  /// 构造时必须注入 [httpClient]，编译期强制非空，
  /// 杜绝运行时才发现 httpClient 缺失（替代原 _requireHttpClient null 检查）。
  LlmProvider(this.config, {required LlmHttpClient httpClient})
      : _httpClient = httpClient;

  /// chat completions 端点 URL
  String get chatCompletionsUrl {
    var base = config.baseUrl;
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/chat/completions';
  }

  /// 构建请求体（Phase 1: 增加 tools / toolChoice 参数）
  Map<String, dynamic> buildRequestBody({
    required List<ChatMessage> messages,
    bool stream = false,
    String? model,
    int? maxTokens,
    double? temperature,
    Map<String, dynamic>? responseFormat,
    List<Map<String, dynamic>>? tools,
    String? toolChoice,
    Map<String, dynamic>? extra,
  }) {
    final body = <String, dynamic>{
      'model': model ?? config.defaultModel,
      'stream': stream,
      'temperature': temperature ?? config.temperature,
      'max_tokens': maxTokens ?? config.maxTokens,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
    if (responseFormat != null) {
      body['response_format'] = responseFormat;
    }
    if (tools != null && tools.isNotEmpty) {
      body['tools'] = _normalizeToolsSchema(tools);
    }
    if (toolChoice != null && toolChoice.isNotEmpty) {
      body['tool_choice'] = toolChoice;
    }
    if (extra != null) {
      body.addAll(extra);
    }
    return body;
  }

  /// 规范化 function 工具 schema，补全缺失的 `required` 字段。
  ///
  /// 严格的 OpenAI 兼容代理（new-api / OneAPI / 部分 DeepSeek 直连）在 JSON Schema
  /// 校验时要求 `function.parameters.required` 必须是数组；缺失会被当作 `null`，
  /// 导致 400 "null is not of type \"array\"`。webview_extract 等场景中的无参工具
  /// 往往只写 `parameters: {type: 'object', properties: {}}` 而遗漏 `required`。
  /// 本方法在请求体构造层统一补全：缺则补空数组，已有则原样保留。
  List<Map<String, dynamic>> _normalizeToolsSchema(
    List<Map<String, dynamic>> tools,
  ) {
    return tools.map((tool) {
      final fn = tool['function'];
      if (fn is! Map<String, dynamic>) return tool;

      final params = fn['parameters'];
      if (params is! Map<String, dynamic>) return tool;
      if (params.containsKey('required')) return tool;

      // 工具定义可能是 static const，必须深拷贝一层再修改
      final newParams = Map<String, dynamic>.from(params);
      newParams['required'] = <String>[];

      final newFn = Map<String, dynamic>.from(fn);
      newFn['parameters'] = newParams;

      final newTool = Map<String, dynamic>.from(tool);
      newTool['function'] = newFn;
      return newTool;
    }).toList();
  }

  /// 默认请求头
  Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      };

  /// 解析阻塞响应为 LlmResponse（Phase 1: 支持 tool_calls）
  static LlmResponse parseBlockingResponse(String rawBody) {
    final json = jsonDecode(rawBody) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      LoggerService.instance.w(
        'LLM 返回空响应（choices 为空）',
        category: LogCategory.ai,
        tags: ['dsl', 'llm', 'empty_response'],
      );
      return const LlmResponse();
    }
    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>?;
    if (message == null) {
      return LlmResponse(content: (first['text'] as String?) ?? '');
    }

    final content = (message['content'] as String?) ?? '';
    final toolCallsRaw = message['tool_calls'] as List?;
    final toolCalls = toolCallsRaw
            ?.map((tc) => ToolCall.fromJson(tc as Map<String, dynamic>))
            .toList() ??
        [];

    return LlmResponse(content: content, toolCalls: toolCalls);
  }

  /// 解析阻塞响应（仅文本，向后兼容旧代码）
  static String parseBlockingResponseText(String rawBody) {
    return parseBlockingResponse(rawBody).content;
  }

  /// 阻塞式调用：完整返回 LLM 响应（Phase 1: 返回 LlmResponse）
  Future<LlmResponse> chat({
    required List<ChatMessage> messages,
    String? model,
    int? maxTokens,
    double? temperature,
    Map<String, dynamic>? responseFormat,
    List<Map<String, dynamic>>? tools,
    String? toolChoice,
  }) async {
    LoggerService.instance.d(
      'LLM chat 阻塞调用入口: model=${model ?? config.defaultModel}, '
      'messages=${messages.length}, baseUrl=${config.baseUrl}, '
      'maxTokens=${maxTokens ?? config.maxTokens}, '
      'temperature=${temperature ?? config.temperature}',
      category: LogCategory.ai,
      tags: ['dsl', 'llm'],
    );
    final client = _httpClient;
    final body = buildRequestBody(
      messages: messages,
      model: model,
      maxTokens: maxTokens,
      temperature: temperature,
      responseFormat: responseFormat,
      tools: tools,
      toolChoice: toolChoice,
      stream: false,
    );
    try {
      final sw = Stopwatch()..start();
      final raw = await client.postJson(
          chatCompletionsUrl, defaultHeaders, jsonEncode(body));
      final response = parseBlockingResponse(raw);
      sw.stop();
      LoggerService.instance.i(
        'LLM chat 阻塞调用完成: contentLength=${response.content.length}, '
        'elapsed=${sw.elapsedMilliseconds}ms',
        category: LogCategory.ai,
        tags: ['dsl', 'llm'],
      );
      return response;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        'LLM chat 阻塞调用失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'llm'],
      );
      rethrow;
    }
  }

  /// 阻塞式调用（仅返回文本，向后兼容旧代码）
  Future<String> chatRaw({
    required List<ChatMessage> messages,
    String? model,
    int? maxTokens,
    double? temperature,
    Map<String, dynamic>? responseFormat,
  }) async {
    final response = await chat(
      messages: messages,
      model: model,
      maxTokens: maxTokens,
      temperature: temperature,
      responseFormat: responseFormat,
    );
    return response.content;
  }

  /// 结构化 JSON 调用 — 自动启用 json_object 模式 + 解析
  ///
  /// 适用于需要 LLM 返回结构化 JSON 的场景（如角色提取、关系提取等）。
  ///
  /// 设计要点：
  /// - 使用 `response_format: { type: "json_object" }` 强制合法 JSON
  /// - 自动在 system prompt 末尾追加 JSON schema 提示（DeepSeek 必须）
  /// - 解析时使用 [safeJsonDecode]（去除 markdown 包裹）
  /// - 支持解析失败自动重试
  ///
  /// **注意**：DeepSeek-V4-Pro 支持 json_object 但不支持 json_schema strict，
  /// 因此 [schemaDescription] 只是自然语言提示，不保证字段完全匹配。
  /// 调用方应在 Dart 侧做字段校验。
  ///
  /// [fromJson] — 从 `Map<String, dynamic>` 构造目标类型
  /// [schemaDescription] — JSON 结构描述（如 '格式: {"roles": [...], "background": "..."}'）
  /// [retryOnParseError] — JSON 解析失败时应用层重试次数（默认 0 次，
  ///   彻底交给 [withRetry] 的传输层重试；JSON 内容质量问题不应靠重试修复）
  /// [temperature] — 默认 0.3（低温度更确定性）
  Future<T?> chatForJson<T>({
    required List<ChatMessage> messages,
    required T Function(Map<String, dynamic>) fromJson,
    String schemaDescription = '',
    int retryOnParseError = 0,
    String? model,
    int? maxTokens,
    double? temperature,
  }) async {
    // 找到 system 消息，追加 schema 提示
    final systemIdx = messages.indexWhere((m) => m.role == 'system');
    final enrichedMessages = List<ChatMessage>.from(messages);
    if (systemIdx >= 0) {
      final original = messages[systemIdx];
      enrichedMessages[systemIdx] = ChatMessage(
        role: 'system',
        content: '${original.content ?? ''}\n\n'
            '你必须返回合法的 JSON 对象。$schemaDescription',
      );
    } else {
      enrichedMessages.insert(
        0,
        ChatMessage(
          role: 'system',
          content: '你必须返回合法的 JSON 对象。$schemaDescription',
        ),
      );
    }

    for (var attempt = 0; attempt <= retryOnParseError; attempt++) {
      try {
        final response = await chat(
          messages: enrichedMessages,
          model: model,
          maxTokens: maxTokens,
          temperature: temperature ?? 0.3,
          responseFormat: const {'type': 'json_object'},
        );

        if (response.content.trim().isEmpty) {
          LoggerService.instance.w(
            'chatForJson: LLM 返回空内容 (attempt $attempt)',
            category: LogCategory.ai,
            tags: ['dsl', 'llm', 'chatForJson', 'empty'],
          );
          continue;
        }

        // safeJsonDecode 已处理 markdown 包裹
        final json = safeJsonDecode(response.content);
        if (json is! Map<String, dynamic>) {
          LoggerService.instance.w(
            'chatForJson: JSON 不是对象 (attempt $attempt, type=${json.runtimeType})',
            category: LogCategory.ai,
            tags: ['dsl', 'llm', 'chatForJson', 'not_object'],
          );
          continue;
        }

        return fromJson(json);
      } on FormatException catch (e) {
        LoggerService.instance.w(
          'chatForJson: JSON 解析失败 (attempt $attempt): $e',
          category: LogCategory.ai,
          tags: ['dsl', 'llm', 'chatForJson', 'parse_error'],
        );
        if (attempt == retryOnParseError) rethrow;
      } catch (e, stackTrace) {
        LoggerService.instance.e(
          'chatForJson: 调用失败 (attempt $attempt): $e',
          stackTrace: stackTrace.toString(),
          category: LogCategory.ai,
          tags: ['dsl', 'llm', 'chatForJson', 'error'],
        );
        if (attempt == retryOnParseError) rethrow;
      }
    }
    return null;
  }

  Stream<String> chatStream({
    required List<ChatMessage> messages,
    String? model,
    int? maxTokens,
    double? temperature,
    Map<String, dynamic>? responseFormat,
  }) {
    LoggerService.instance.d(
      'LLM chatStream 流式调用入口: model=${model ?? config.defaultModel}, '
      'messages=${messages.length}, baseUrl=${config.baseUrl}, '
      'maxTokens=${maxTokens ?? config.maxTokens}, '
      'temperature=${temperature ?? config.temperature}',
      category: LogCategory.ai,
      tags: ['dsl', 'llm'],
    );
    final client = _httpClient;
    final body = buildRequestBody(
      messages: messages,
      model: model,
      maxTokens: maxTokens,
      temperature: temperature,
      responseFormat: responseFormat,
      tools: null, // 流式暂不支持 tool_calls 解析（用 chat + tools）
      stream: true,
    );
    return client
        .postJsonStream(chatCompletionsUrl, defaultHeaders, jsonEncode(body))
        .transform(const _LineSplitter())
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trim())
        .where((payload) => payload.isNotEmpty && payload != '[DONE]')
        .map((payload) {
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) return '';
        final first = choices.first as Map<String, dynamic>;
        final delta = first['delta'] as Map<String, dynamic>?;
        return (delta?['content'] as String?) ?? '';
      } catch (_) {
        return '';
      }
    }).where((chunk) => chunk.isNotEmpty);
  }

  /// 流式调用（支持 tools + tool_calls delta 聚合）
  ///
  /// 与 [chatStream] 不同，此方法：
  /// - 传入 [tools] 和 [toolChoice] 参数
  /// - 逐帧发出 [LlmStreamChunk]，包含文本增量、tool_calls delta 和 finish_reason
  /// - 调用方可逐 chunk 实时更新 UI，流结束后通过
  ///   [StreamingResult.buildToolCalls()] 聚合完整 ToolCall 列表
  ///
  /// 用法：
  /// ```dart
  /// final result = StreamingResult();
  /// await for (final chunk in provider.chatStreamWithTools(
  ///   messages: messages, tools: tools, toolChoice: 'auto',
  /// )) {
  ///   if (chunk.isContent) emit(TextDeltaEvent(chunk.contentChunk!));
  ///   if (chunk.isToolCallDelta) result.toolCallDeltas.addAll(chunk.toolCallDeltas);
  /// }
  /// final toolCalls = result.buildToolCalls();
  /// ```
  Stream<LlmStreamChunk> chatStreamWithTools({
    required List<ChatMessage> messages,
    String? model,
    int? maxTokens,
    double? temperature,
    List<Map<String, dynamic>>? tools,
    String? toolChoice,
  }) async* {
    LoggerService.instance.d(
      'LLM chatStreamWithTools 流式+工具调用入口: '
      'model=${model ?? config.defaultModel}, '
      'messages=${messages.length}, tools=${tools?.length ?? 0}, '
      'toolChoice=$toolChoice',
      category: LogCategory.ai,
      tags: ['dsl', 'llm', 'stream-tools'],
    );
    final client = _httpClient;
    final body = buildRequestBody(
      messages: messages,
      model: model,
      maxTokens: maxTokens,
      temperature: temperature,
      tools: tools,
      toolChoice: toolChoice,
      stream: true,
    );

    yield* client
        .postJsonStream(chatCompletionsUrl, defaultHeaders, jsonEncode(body))
        .transform(const _LineSplitter())
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trim())
        .where((payload) => payload.isNotEmpty && payload != '[DONE]')
        .map((payload) {
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) {
          return const LlmStreamChunk();
        }
        final first = choices.first as Map<String, dynamic>;
        final delta = first['delta'] as Map<String, dynamic>?;
        if (delta == null) {
          // 可能只有 finish_reason，没有 delta
          final finishReason = first['finish_reason'] as String?;
          if (finishReason != null) {
            return LlmStreamChunk(finishReason: finishReason);
          }
          return const LlmStreamChunk();
        }

        // 文本内容增量
        final content = (delta['content'] as String?) ?? '';

        // tool_calls 增量
        final tcDeltas = <Map<String, dynamic>>[];
        final tcRaw = delta['tool_calls'] as List?;
        if (tcRaw != null) {
          for (final tc in tcRaw) {
            if (tc is Map<String, dynamic>) {
              tcDeltas.add(tc);
            }
          }
        }

        // finish_reason（可能在任意帧上出现）
        final finishReason = first['finish_reason'] as String?;

        return LlmStreamChunk(
          contentChunk: content.isNotEmpty ? content : null,
          toolCallDeltas: tcDeltas,
          finishReason: finishReason,
        );
      } catch (e) {
        LoggerService.instance.w(
          'chatStreamWithTools SSE 行解析失败: $e',
          category: LogCategory.ai,
          tags: ['dsl', 'llm', 'stream-tools'],
        );
        return const LlmStreamChunk();
      }
    }).where((chunk) =>
            chunk.isContent || chunk.isToolCallDelta || chunk.isFinished);
  }
}

// LineSplitter 是 dart:convert 提供的，但 stream_transformers 也可替代
class _LineSplitter extends StreamTransformerBase<String, String> {
  const _LineSplitter();
  @override
  Stream<String> bind(Stream<String> stream) {
    final controller = StreamController<String>();
    final buffer = StringBuffer();
    stream.listen(
      (data) {
        buffer.write(data);
        final s = buffer.toString();
        final lines = s.split('\n');
        for (var i = 0; i < lines.length - 1; i++) {
          if (lines[i].isNotEmpty) controller.add(lines[i]);
        }
        buffer.clear();
        buffer.write(lines.last);
      },
      onError: controller.addError,
      onDone: () {
        if (buffer.isNotEmpty) controller.add(buffer.toString());
        controller.close();
      },
      cancelOnError: false,
    );
    return controller.stream;
  }
}

// ---------------------------------------------------------------------------
// IoLlmHttpClient: 使用 dart:io HttpClient 的真实 HTTP 客户端
// （从已删除的 real_llm_executor.dart 迁移至此，与 LlmHttpClient 接口同文件）
// ---------------------------------------------------------------------------

/// 流式握手阶段的结果（握手成功后供 [IoLlmHttpClient._wrapStreamWithLogging] 落盘）
class _StreamHandshake {
  final Stream<String> bodyStream;
  final String logId;
  final Stopwatch stopwatch;
  final StringBuffer responseBuffer;
  _StreamHandshake({
    required this.bodyStream,
    required this.logId,
    required this.stopwatch,
    required this.responseBuffer,
  });
}

/// 基于 dart:io HttpClient 的 LlmHttpClient 实现
class IoLlmHttpClient implements LlmHttpClient {
  // connectionTimeout: TCP/TLS 建连超时；idleTimeout: 空闲连接超时
  // 参照 lib/core/providers/services/network_service_providers.dart:82-84 项目惯例
  final io.HttpClient _client = io.HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 60);

  IoLlmHttpClient();

  @override
  Future<String> postJson(
      String url, Map<String, String> headers, String body) async {
    // 不传 config → 用 RetryConfig 默认值（maxAttempts=8, maxDelay=60s, initialDelay=500ms）。
    // 流式握手 postJsonStream 显式传 maxAttempts:3，与阻塞保持区分。
    return withRetry(
      () => _postJsonOnce(url, headers, body),
      label: 'llm_post',
      onRetry: (a, m, d, e) {
        try {
          RetrySignals.instance.reportTransport(
            attempt: a,
            maxAttempts: m,
            delayMs: d,
            error: e,
          );
        } catch (_) {
          // report 失败不影响重试
        }
      },
    );
  }

  /// 单次 HTTP 调用（被 [postJson] 包装重试）
  ///
  /// 4xx/5xx → 统一抛 [RetryableHttpException]（withRetry 全部重试）
  /// 2xx/3xx → 返回响应 body 字符串
  Future<String> _postJsonOnce(
      String url, Map<String, String> headers, String body) async {
    // ★ LLM 日志拦截：记录请求
    final logId = _generateLogId();
    final stopwatch = Stopwatch()..start();
    LlmLogger.instance.logRequest(
      id: logId,
      endpoint: url,
      requestBody: body,
      isStreaming: false,
    );

    final uri = Uri.parse(url);
    final request = await _client.postUrl(uri);
    headers.forEach((k, v) => request.headers.set(k, v));
    request.add(utf8.encode(body));
    final response = await request.close();
    final statusCode = response.statusCode;
    final responseBody = await response.transform(utf8.decoder).join();

    // ★ LLM 日志拦截：记录响应（重试失败也保留记录，便于诊断）
    stopwatch.stop();
    final isSuccess = statusCode < 400;
    LlmLogger.instance.logResponse(
      id: logId,
      responseBody: responseBody,
      durationMs: stopwatch.elapsedMilliseconds,
      isSuccess: isSuccess,
      errorMessage: isSuccess ? null : 'HTTP $statusCode',
    );

    if (statusCode >= 400) {
      // 所有 4xx/5xx 统一重试（用户策略：瞬态 4xx 也尽量自愈，避免直接打断会话）
      // 读 Retry-After 头（429/503 通常带）；解析失败返回 null 走指数退避
      final retryAfterMs = parseRetryAfterMs(
        response.headers.value('retry-after'),
      );
      LoggerService.instance.w(
        'LLM HTTP $statusCode (retryable): '
        '${retryAfterMs != null ? 'retryAfter=${retryAfterMs}ms, ' : ''}'
        'url=$url',
        category: LogCategory.ai,
        stackTrace: _buildHttpErrorContext(url, headers, body, responseBody),
        tags: ['dsl', 'llm', 'http', 'post_json', 'retryable'],
      );
      throw RetryableHttpException(
        statusCode,
        responseBody,
        url,
        retryAfterMs: retryAfterMs,
      );
    }
    RetrySignals.instance.clear();
    return responseBody;
  }

  @override
  Stream<String> postJsonStream(
      String url, Map<String, String> headers, String body) async* {
    // 握手阶段（到拿到 statusCode 为止）走 withRetry；
    // 5xx 重试、4xx 抛非可重试、网络层异常重试。
    // 握手成功（2xx）后流中段断开不再重试（避免 UI 内容重复），
    // 交给 agent_loop 的 round-level 重试处理。
    final handshake = await withRetry(
      () => _postJsonStreamHandshake(url, headers, body),
      config: const RetryConfig(maxAttempts: 3),
      label: 'llm_stream_establish',
      onRetry: (a, m, d, e) {
        try {
          RetrySignals.instance.reportTransport(
            attempt: a,
            maxAttempts: m,
            delayMs: d,
            error: e,
          );
        } catch (_) {
          // report 失败不影响重试
        }
      },
    );

    yield* _wrapStreamWithLogging(
      handshake.bodyStream,
      handshake.logId,
      handshake.stopwatch,
      handshake.responseBuffer,
    );
  }

  /// 流式握手阶段：到 statusCode 拿到为止
  ///
  /// 返回 [_StreamHandshake] 包含握手成功的 bodyStream 与日志上下文。
  /// 4xx/5xx → 统一抛 [RetryableHttpException]。
  Future<_StreamHandshake> _postJsonStreamHandshake(
      String url, Map<String, String> headers, String body) async {
    final logId = _generateLogId();
    final stopwatch = Stopwatch()..start();
    final responseBuffer = StringBuffer();
    LlmLogger.instance.logRequest(
      id: logId,
      endpoint: url,
      requestBody: body,
      isStreaming: true,
    );

    final uri = Uri.parse(url);
    final request = await _client.postUrl(uri);
    headers.forEach((k, v) => request.headers.set(k, v));
    request.add(utf8.encode(body));
    final response = await request.close();
    final statusCode = response.statusCode;
    if (statusCode >= 400) {
      // 错误响应通常很短，缓冲后一次性记录
      final errorBody = await response.transform(utf8.decoder).join();
      stopwatch.stop();
      LlmLogger.instance.logResponse(
        id: logId,
        responseBody: errorBody,
        durationMs: stopwatch.elapsedMilliseconds,
        isSuccess: false,
        errorMessage: 'HTTP $statusCode',
      );
      final ctx = _buildHttpErrorContext(url, headers, body, errorBody);
      // 读 Retry-After 头（429/503 通常带）；解析失败返回 null 走指数退避
      final retryAfterMs = parseRetryAfterMs(
        response.headers.value('retry-after'),
      );
      // 所有 4xx/5xx 统一重试（用户策略：瞬态 4xx 也尽量自愈）
      LoggerService.instance.w(
        'LLM HTTP $statusCode (stream, retryable): '
        '${retryAfterMs != null ? 'retryAfter=${retryAfterMs}ms, ' : ''}'
        'url=$url',
        category: LogCategory.ai,
        stackTrace: ctx,
        tags: ['dsl', 'llm', 'http', 'stream_establish', 'retryable'],
      );
      throw RetryableHttpException(
        statusCode,
        errorBody,
        url,
        retryAfterMs: retryAfterMs,
      );
    }
    RetrySignals.instance.clear();
    return _StreamHandshake(
      bodyStream: response.transform(utf8.decoder),
      logId: logId,
      stopwatch: stopwatch,
      responseBuffer: responseBuffer,
    );
  }

  /// 将流式响应包装，在流结束后记录完整响应到 LlmLogger
  ///
  /// 注意：落盘的是 [buffer] 重构出的**结构化 JSON**（OpenAI 兼容格式），
  /// 而非原始 SSE 文本——后者含大量 `data:` 帧前缀与 `[DONE]` 心跳，
  /// 会污染日志、撑大 JSONL 文件并导致 UI 端 JSON 高亮失败。
  /// [yield] 仍透传原始 chunk，流式渲染体验不受影响。
  Stream<String> _wrapStreamWithLogging(
    Stream<String> source,
    String logId,
    Stopwatch stopwatch,
    StringBuffer buffer,
  ) async* {
    try {
      await for (final chunk in source) {
        buffer.write(chunk);
        yield chunk;
      }
      // 流正常结束：将原始 SSE 文本重构为结构化 JSON 后记录。
      stopwatch.stop();
      LlmLogger.instance.logResponse(
        id: logId,
        responseBody: _reconstructStreamedJson(buffer.toString()),
        durationMs: stopwatch.elapsedMilliseconds,
        isSuccess: true,
      );
    } catch (e) {
      // 流异常中断
      stopwatch.stop();
      LlmLogger.instance.logError(
        id: logId,
        errorMessage: e.toString(),
        durationMs: stopwatch.elapsedMilliseconds,
      );
      rethrow;
    }
  }

  /// 将流式 SSE 原始文本重构为 OpenAI 兼容的非流式响应 JSON，
  /// 供 LLM 日志记录使用，避免 `data:` 帧前缀与 `[DONE]` 心跳污染落盘内容。
  ///
  /// 复用 [SseParser.parseStreamingResult] 提取 content / reasoning_content /
  /// tool_calls，并额外扫描顶层 `usage` 与 `choices[].finish_reason`
  /// （二者在标准 OpenAI 流式中仅出现于末尾帧，取最后非空值）。
  ///
  /// 解析完全失败（无任何有效内容）时回退为 `{"_stream_raw": ...}` 保留原始文本，
  /// 不丢失诊断信息。
  static String _reconstructStreamedJson(String raw) {
    final result = SseParser.parseStreamingResult(raw);

    // 提取 usage / finish_reason（顶层与 choices 字段，parseStreamingResult 未收集）
    Map<String, dynamic>? usage;
    String? finishReason;
    for (final line in raw.split('\n')) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      try {
        final obj = jsonDecode(payload) as Map<String, dynamic>;
        final u = obj['usage'] as Map<String, dynamic>?;
        if (u != null) usage = u;
        final choices = obj['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final fr = (choices.first as Map<String, dynamic>)['finish_reason'];
          if (fr is String) finishReason = fr;
        }
      } catch (_) {
        // 忽略单帧解析失败
      }
    }

    final content = result.fullContent;
    final reasoning = result.reasoningChunks.join();
    final toolCalls = result.buildToolCalls();

    // 解析无任何有效内容 → 回退原始文本，保留诊断信息
    if (content.isEmpty &&
        reasoning.isEmpty &&
        toolCalls.isEmpty &&
        usage == null &&
        finishReason == null) {
      return jsonEncode({
        '_stream_raw': raw,
        '_note': 'SSE 解析未提取到有效内容，保留原始流文本',
      });
    }

    final message = <String, dynamic>{
      'role': 'assistant',
      if (content.isNotEmpty) 'content': content,
    };
    if (reasoning.isNotEmpty) {
      message['reasoning_content'] = reasoning;
    }
    if (toolCalls.isNotEmpty) {
      message['tool_calls'] = toolCalls.map((t) => t.toJson()).toList();
    }

    return jsonEncode({
      'object': 'chat.completion',
      'choices': [
        {
          'index': 0,
          'finish_reason': finishReason ?? 'stop',
          'message': message,
        }
      ],
      if (usage != null) 'usage': usage,
      '_stream_meta': {
        'raw_size': raw.length,
        'content_chunk_count': result.contentChunks.length,
      },
    });
  }

  /// 构造 HTTP 错误诊断上下文（写入 stackTrace 字段，便于后续定位 4xx/5xx 根因）
  ///
  /// 记录：请求 URL、模型、消息数、请求体大小、以及 LLM 返回的错误响应体。
  /// 不记录 apiKey 与完整 messages 内容，避免泄露敏感信息与日志膨胀。
  static String _buildHttpErrorContext(String url, Map<String, String> headers,
      String body, String responseBody) {
    String model = 'unknown';
    int messageCount = -1;
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      model = decoded['model']?.toString() ?? 'unknown';
      final messages = decoded['messages'];
      if (messages is List) messageCount = messages.length;
    } catch (_) {
      // 请求体非合法 JSON 时忽略解析
    }
    final hasApiKey = headers['Authorization']?.isNotEmpty == true ||
        headers['authorization']?.isNotEmpty == true;
    // 限制错误响应体长度，避免超大错误页污染日志
    final errorSnippet = responseBody.length > 1000
        ? '${responseBody.substring(0, 1000)}...(truncated)'
        : responseBody;
    return [
      'LLM HTTP 错误诊断上下文:',
      '  url: $url',
      '  model: $model',
      '  messages: $messageCount 条',
      '  requestBodySize: ${body.length} 字节',
      '  apiKeyConfigured: $hasApiKey',
      '  responseBody: $errorSnippet',
    ].join('\n');
  }
}

/// 生成 LLM 日志记录 ID（时间戳 + 随机后缀）
String _generateLogId() {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final rand = Random().nextInt(9999).toString().padLeft(4, '0');
  return 'llm_${ts}_$rand';
}
