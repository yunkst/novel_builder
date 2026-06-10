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

import 'package:novel_app/services/logger_service.dart';

// -- 配置 --

class LlmConfig {
  final String baseUrl; // 如 https://api.deepseek.com/v1
  final String apiKey;
  final String defaultModel;
  final int maxTokens;
  final double temperature;
  final Duration timeout;

  const LlmConfig({
    this.baseUrl = '',
    this.apiKey = '',
    this.defaultModel = '',
    this.maxTokens = 4096,
    this.temperature = 0.7,
    this.timeout = const Duration(seconds: 60),
  });

  LlmConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? defaultModel,
    int? maxTokens,
    double? temperature,
    Duration? timeout,
  }) {
    return LlmConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      defaultModel: defaultModel ?? this.defaultModel,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      timeout: timeout ?? this.timeout,
    );
  }
}

// -- 工具调用模型 (Phase 1: Function Calling) --

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
        args = jsonDecode(rawArgs) as Map<String, dynamic>;
      } catch (_) {
        // 参数解析失败，保持空
      }
    } else if (rawArgs is Map<String, dynamic>) {
      args = rawArgs;
    }
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
      final entry = aggregated.putIfAbsent(idx, () => _ToolCallDelta(index: idx));

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

    return aggregated.values
        .where((d) => d.name != null)
        .map((d) {
      var args = <String, dynamic>{};
      final argsStr = d.argumentsBuffer.toString();
      if (argsStr.isNotEmpty) {
        try {
          args = jsonDecode(argsStr) as Map<String, dynamic>;
        } catch (_) {}
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
  /// 解析标准 SSE 流，返回内容 chunk 列表
  static List<String> parseSseStream(String raw) {
    final result = parseSseStreamWithReasoning(raw);
    return result.content;
  }

  /// 解析带 reasoning_content 的 SSE 流（Dify deepseek thinking 格式）
  static SseParseResult parseSseStreamWithReasoning(String raw) {
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

    return SseParseResult(content: content, reasoning: reasoning);
  }

  /// 解析流式响应为 StreamingResult（Phase 1: 支持 tool_calls）
  static StreamingResult parseStreamingResult(String raw) {
    final contentChunks = <String>[];
    final reasoningChunks = <String>[];
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

        // reasoning_content
        final rc = delta['reasoning_content'];
        if (rc is String && rc.isNotEmpty) {
          reasoningChunks.add(rc);
        }

        // 正常 content
        final c = delta['content'];
        if (c is String && c.isNotEmpty) {
          contentChunks.add(c);
        }

        // tool_calls deltas
        final tcDeltas = delta['tool_calls'] as List?;
        if (tcDeltas != null) {
          for (final tc in tcDeltas) {
            if (tc is Map<String, dynamic>) {
              toolCallDeltas.add(tc);
            }
          }
        }
      } catch (_) {
        LoggerService.instance.w(
          'SSE 流式结果解析失败',
          category: LogCategory.ai,
          tags: ['dsl', 'llm', 'sse'],
        );
        // 忽略解析失败
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
  final LlmHttpClient? _httpClient; // null 时需在调用前注入

  LlmProvider(this.config, {LlmHttpClient? httpClient})
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
      body['tools'] = tools;
    }
    if (toolChoice != null && toolChoice.isNotEmpty) {
      body['tool_choice'] = toolChoice;
    }
    if (extra != null) {
      body.addAll(extra);
    }
    return body;
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
    if (choices == null || choices.isEmpty) return const LlmResponse();
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
    final client = _requireHttpClient();
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

  /// 流式调用：返回 chunk 流
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
    final client = _requireHttpClient();
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
    final client = _requireHttpClient();
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
    }).where((chunk) => chunk.isContent || chunk.isToolCallDelta || chunk.isFinished);
  }

  LlmHttpClient _requireHttpClient() {
    if (_httpClient == null) {
      LoggerService.instance.e(
        'LlmProvider.httpClient 未设置',
        stackTrace: StackTrace.current.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'llm'],
      );
      throw StateError(
          'LlmProvider.httpClient not set. Use constructor injection.');
    }
    return _httpClient!;
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