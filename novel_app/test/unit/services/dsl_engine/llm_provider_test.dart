/// LLM Provider 单元测试
///
/// 验证 OpenAI 兼容 LLM Provider 的核心功能：
/// 1. 阻塞式 chat completion
/// 2. SSE 流式 chat completion
/// 3. response_format JSON 模式（structured_output）
/// 4. 配置管理（baseUrl / apiKey / model）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';

void main() {
  group('LlmConfig', () {
    test('默认配置', () {
      final config = LlmConfig();
      expect(config.baseUrl, '');
      expect(config.apiKey, '');
      expect(config.defaultModel, '');
      expect(config.maxTokens, 4096);
      expect(config.temperature, 0.7);
    });

    test('自定义配置', () {
      final config = LlmConfig(
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: 'sk-test',
        defaultModel: 'deepseek-chat',
        maxTokens: 8192,
        temperature: 0.5,
      );
      expect(config.baseUrl, 'https://api.deepseek.com/v1');
      expect(config.apiKey, 'sk-test');
      expect(config.defaultModel, 'deepseek-chat');
      expect(config.maxTokens, 8192);
      expect(config.temperature, 0.5);
    });
  });

  group('SSE Parser', () {
    test('解析标准 SSE 流', () {
      const sseData = 'data: {"choices":[{"delta":{"content":"Hello"}}]}\n'
          'data: {"choices":[{"delta":{"content":" world"}}]}\n'
          'data: {"choices":[{"delta":{"content":"!"}}]}\n'
          'data: [DONE]\n';

      final chunks = SseParser.parseSseStream(sseData);
      expect(chunks, ['Hello', ' world', '!']);
    });

    test('解析带空行的 SSE', () {
      const sseData = 'data: {"choices":[{"delta":{"content":"A"}}]}\n\n'
          'data: {"choices":[{"delta":{"content":"B"}}]}\n\n'
          'data: [DONE]\n\n';

      final chunks = SseParser.parseSseStream(sseData);
      expect(chunks, ['A', 'B']);
    });

    test('忽略非 data 行', () {
      const sseData = 'event: message_start\n'
          'data: {"choices":[{"delta":{"content":"X"}}]}\n'
          ': comment line\n'
          'data: [DONE]\n';

      final chunks = SseParser.parseSseStream(sseData);
      expect(chunks, ['X']);
    });

    test('空 delta content → 不产生 chunk', () {
      const sseData = 'data: {"choices":[{"delta":{"content":""}}]}\n'
          'data: {"choices":[{"delta":{"content":"Y"}}]}\n'
          'data: [DONE]\n';

      final chunks = SseParser.parseSseStream(sseData);
      expect(chunks, ['Y']);
    });

    test('delta 缺少 content 字段 → 不产生 chunk', () {
      const sseData = 'data: {"choices":[{"delta":{"role":"assistant"}}]}\n'
          'data: {"choices":[{"delta":{"content":"Z"}}]}\n'
          'data: [DONE]\n';

      final chunks = SseParser.parseSseStream(sseData);
      expect(chunks, ['Z']);
    });

    test('reasoning_content 分离（Dify thinking 格式）', () {
      const sseData = 'data: {"choices":[{"delta":{"reasoning_content":"thinking..."}}]}\n'
          'data: {"choices":[{"delta":{"content":"answer"}}]}\n'
          'data: [DONE]\n';

      final result = SseParser.parseSseStreamWithReasoning(sseData);
      expect(result.content, ['answer']);
      expect(result.reasoning, ['thinking...']);
    });
  });

  group('ChatMessage', () {
    test('构造 system / user / assistant 消息', () {
      final system = ChatMessage(role: 'system', content: 'You are a writer');
      final user = ChatMessage(role: 'user', content: 'Write a story');
      final assistant = ChatMessage(role: 'assistant', content: 'Here is...');

      expect(system.role, 'system');
      expect(user.role, 'user');
      expect(assistant.role, 'assistant');
    });

    test('toJson 生成 OpenAI 格式', () {
      final msg = ChatMessage(role: 'user', content: 'Hello');
      final json = msg.toJson();
      expect(json, {'role': 'user', 'content': 'Hello'});
    });
  });

  group('LlmProvider request building', () {
    test('阻塞式请求体构建', () {
      final provider = LlmProvider(LlmConfig(
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: 'sk-test',
        defaultModel: 'deepseek-chat',
      ), httpClient: _FakeHttpClient());

      final body = provider.buildRequestBody(
        messages: [
          ChatMessage(role: 'system', content: 'You are helpful'),
          ChatMessage(role: 'user', content: 'Hello'),
        ],
        stream: false,
      );

      expect(body['model'], 'deepseek-chat');
      expect(body['stream'], false);
      expect(body['temperature'], 0.7);
      expect(body['max_tokens'], 4096);
      expect(body['messages'].length, 2);
    });

    test('流式请求体构建', () {
      final provider = LlmProvider(LlmConfig(
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: 'sk-test',
        defaultModel: 'deepseek-chat',
      ), httpClient: _FakeHttpClient());

      final body = provider.buildRequestBody(
        messages: [ChatMessage(role: 'user', content: 'Hello')],
        stream: true,
      );

      expect(body['stream'], true);
    });

    test('覆盖 model 和参数', () {
      final provider = LlmProvider(LlmConfig(
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: 'sk-test',
        defaultModel: 'deepseek-chat',
      ), httpClient: _FakeHttpClient());

      final body = provider.buildRequestBody(
        messages: [ChatMessage(role: 'user', content: 'Hello')],
        model: 'deepseek-reasoner',
        maxTokens: 16384,
        temperature: 0.3,
        stream: false,
      );

      expect(body['model'], 'deepseek-reasoner');
      expect(body['max_tokens'], 16384);
      expect(body['temperature'], 0.3);
    });

    test('structured_output: response_format JSON 模式', () {
      final provider = LlmProvider(LlmConfig(
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: 'sk-test',
        defaultModel: 'deepseek-chat',
      ), httpClient: _FakeHttpClient());

      final body = provider.buildRequestBody(
        messages: [ChatMessage(role: 'user', content: 'Generate character')],
        stream: false,
        responseFormat: {'type': 'json_object'},
      );

      expect(body['response_format'], {'type': 'json_object'});
    });
  });

  group('LlmProvider URL construction', () {
    test('chat completions endpoint', () {
      final provider = LlmProvider(LlmConfig(
        baseUrl: 'https://api.deepseek.com/v1',
        apiKey: 'sk-test',
        defaultModel: 'deepseek-chat',
      ), httpClient: _FakeHttpClient());

      expect(provider.chatCompletionsUrl,
          'https://api.deepseek.com/v1/chat/completions');
    });

    test('baseUrl 末尾有 / 时去掉冗余', () {
      final provider = LlmProvider(LlmConfig(
        baseUrl: 'https://api.deepseek.com/v1/',
        apiKey: 'sk-test',
        defaultModel: 'deepseek-chat',
      ), httpClient: _FakeHttpClient());

      expect(provider.chatCompletionsUrl,
          'https://api.deepseek.com/v1/chat/completions');
    });
  });
}

/// 占位 HTTP 客户端：本测试只覆盖请求体构建/URL 拼接，不发真实请求
class _FakeHttpClient implements LlmHttpClient {
  @override
  Future<String> postJson(
          String url, Map<String, String> headers, String body) =>
      throw UnimplementedError();
  @override
  Stream<String> postJsonStream(
          String url, Map<String, String> headers, String body) =>
      throw UnimplementedError();
}