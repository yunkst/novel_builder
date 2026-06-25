/// 测试用 LLM 请求记录 Mock
///
/// 替换 LlmProvider 中的 HTTP 客户端，拦截请求并记录：
/// - model / temperature / maxTokens
/// - messages (system + user)
/// - response_format（结构化输出方法使用）
///
/// 默认返回 'MOCK_LLM_RESPONSE'，可通过 [setMockContent] 自定义。
library;

import 'dart:convert';

import 'package:novel_app/services/dsl_engine/llm_provider.dart';

class PromptRecordingMock implements LlmHttpClient {
  final List<RecordedRequest> recordedRequests = [];

  /// 自定义 mock 返回内容（默认 'MOCK_LLM_RESPONSE'）
  String _mockContent = 'MOCK_LLM_RESPONSE';

  /// 设置 mock 返回内容
  ///
  /// 用于结构化输出方法（如 immersiveScript），LLM 需返回合法 JSON。
  void setMockContent(String content) {
    _mockContent = content;
  }

  Map<String, dynamic> _blockingResponseBody() => {
        'choices': [
          {
            'message': {'content': _mockContent, 'role': 'assistant'},
            'finish_reason': 'stop',
          }
        ],
        'usage': {'prompt_tokens': 0, 'completion_tokens': 0, 'total_tokens': 0},
      };

  String _blockingResponseString() =>
      const JsonEncoder().convert(_blockingResponseBody());

  String _streamChunkString(Map<String, dynamic> chunk) =>
      'data: ${const JsonEncoder().convert(chunk)}\n';

  @override
  Future<String> postJson(
    String url,
    Map<String, String> headers,
    String body,
  ) async {
    final bodyMap = jsonDecode(body) as Map<String, dynamic>;
    recordedRequests.add(RecordedRequest(
      url: url,
      headers: Map.from(headers),
      body: bodyMap,
    ));
    return _blockingResponseString();
  }

  @override
  Stream<String> postJsonStream(
    String url,
    Map<String, String> headers,
    String body,
  ) async* {
    final bodyMap = jsonDecode(body) as Map<String, dynamic>;
    recordedRequests.add(RecordedRequest(
      url: url,
      headers: Map.from(headers),
      body: bodyMap,
    ));
    yield _streamChunkString({
      'choices': [
        {
          'delta': {'content': _mockContent, 'role': 'assistant'},
          'finish_reason': null,
        }
      ]
    });
    yield _streamChunkString({
      'choices': [
        {'delta': {}, 'finish_reason': 'stop'}
      ]
    });
    yield 'data: [DONE]\n';
  }

  /// 最后一次 LLM 调用的 prompt 快照
  PromptSnapshot? get lastSnapshot => recordedRequests.isEmpty
      ? null
      : PromptSnapshot.fromRequestBody(recordedRequests.last.body);

  void clear() {
    recordedRequests.clear();
  }
}

class RecordedRequest {
  final String url;
  final Map<String, String> headers;
  final Map<String, dynamic> body;

  RecordedRequest({required this.url, required this.headers, required this.body});
}

/// 发给 LLM 的 prompt 快照（从 OpenAI 格式 HTTP body 提取）
class PromptSnapshot {
  final String? systemPrompt;
  final String? userMessage;
  final String? assistantMessage;
  final String model;
  final double? temperature;
  final int? maxTokens;
  final Map<String, dynamic>? responseFormat;

  PromptSnapshot({
    this.systemPrompt,
    this.userMessage,
    this.assistantMessage,
    required this.model,
    this.temperature,
    this.maxTokens,
    this.responseFormat,
  });

  factory PromptSnapshot.fromRequestBody(Map<String, dynamic> body) {
    final messages = (body['messages'] as List<dynamic>?) ?? [];
    String? system;
    String? user;
    String? assistant;
    for (final msg in messages) {
      final m = msg as Map<String, dynamic>;
      final role = m['role'] as String?;
      final content = m['content'];
      if (role == 'system') system = content?.toString();
      if (role == 'user') user = content?.toString();
      if (role == 'assistant') assistant = content?.toString();
    }
    return PromptSnapshot(
      systemPrompt: system,
      userMessage: user,
      assistantMessage: assistant,
      model: body['model'] as String? ?? '',
      temperature: (body['temperature'] as num?)?.toDouble(),
      maxTokens: (body['max_tokens'] as num?)?.toInt(),
      responseFormat: body['response_format'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (systemPrompt != null) 'system_prompt': systemPrompt,
        if (userMessage != null) 'user_message': userMessage,
        if (assistantMessage != null) 'assistant_message': assistantMessage,
        'model': model,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (responseFormat != null) 'response_format': responseFormat,
      };

  @override
  String toString() => const JsonEncoder.withIndent('  ').convert(toJson());
}
