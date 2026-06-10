/// RealLlmExecutor：LLM 节点的真实执行器
///
/// 从 LLM 节点的 DSL data 中提取配置（模型名、prompt_template、structured_output 等），
/// 构造消息列表，调用 LlmProvider 真正请求 LLM API。
///
/// 支持：
/// - basic 模式：text 字段用 convertTemplate 渲染
/// - jinja2 模式：jinja2_text 字段用 renderTemplateWithJinja 渲染
/// - structured_output：通过 response_format json_object 请求 JSON
/// - 流式 + 阻塞两种调用方式
library;

import 'dart:convert';
import 'dart:io' as io;

import 'package:novel_app/services/dsl_engine/dsl_parser.dart';
import 'package:novel_app/services/dsl_engine/graph_engine.dart';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';
import 'package:novel_app/services/dsl_engine/models/variable_pool.dart';
import 'package:novel_app/services/dsl_engine/template_renderer.dart';
import 'package:novel_app/services/logger_service.dart';

class RealLlmExecutor {
  final LlmProvider _provider;
  final TemplateRenderer _renderer = TemplateRenderer();
  final String? _defaultModel; // 覆盖 DSL 中的 model

  RealLlmExecutor({
    required LlmProvider provider,
    String? defaultModel,
  })  : _provider = provider,
        _defaultModel = defaultModel;

  /// 阻塞调用：等待完整响应
  Future<NodeRunResult> executeBlocking(
    DslNode node,
    VariablePool pool,
  ) async {
    LoggerService.instance.d(
      'RealLlmExecutor.executeBlocking 入口: nodeId=${node.id}',
      category: LogCategory.ai,
      tags: ['dsl', 'llm'],
    );
    try {
      final config = LlmNodeConfig.fromNode(node, _defaultModel);
      final messages = _buildMessages(
        node,
        pool,
        structuredOutputEnabled: config.structuredOutputEnabled,
      );

      final sw = Stopwatch()..start();
      final response = await _provider.chat(
        messages: messages,
        model: config.model,
        maxTokens: config.maxTokens,
        temperature: config.temperature,
        responseFormat: config.structuredOutputEnabled
            ? {'type': 'json_object'}
            : null,
      );
      sw.stop();

      LoggerService.instance.i(
        'RealLlmExecutor.executeBlocking 完成: nodeId=${node.id}, '
        'contentLength=${response.content.length}, '
        'elapsed=${sw.elapsedMilliseconds}ms',
        category: LogCategory.ai,
        tags: ['dsl', 'llm'],
      );
      return _buildResult(node.id, response.content, config.structuredOutputEnabled);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        'RealLlmExecutor.executeBlocking 失败: nodeId=${node.id}, error=$e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'llm'],
      );
      return NodeRunResult(
        nodeId: node.id,
        status: NodeExecutionStatus.failed,
        error: e.toString(),
      );
    }
  }

  /// 流式调用：通过 onChunk 回调逐 chunk 输出
  Future<NodeRunResult> executeStreaming(
    DslNode node,
    VariablePool pool, {
    void Function(String chunk)? onChunk,
  }) async {
    LoggerService.instance.d(
      'RealLlmExecutor.executeStreaming 入口: nodeId=${node.id}',
      category: LogCategory.ai,
      tags: ['dsl', 'llm'],
    );
    try {
      final config = LlmNodeConfig.fromNode(node, _defaultModel);
      final messages = _buildMessages(
        node,
        pool,
        structuredOutputEnabled: config.structuredOutputEnabled,
      );

      final chunks = <String>[];
      final sw = Stopwatch()..start();
      int? firstChunkMs;
      await for (final chunk in _provider.chatStream(
        messages: messages,
        model: config.model,
        maxTokens: config.maxTokens,
        temperature: config.temperature,
        responseFormat: config.structuredOutputEnabled
            ? {'type': 'json_object'}
            : null,
      )) {
        if (chunks.isEmpty) {
          firstChunkMs = sw.elapsedMilliseconds;
        }
        chunks.add(chunk);
        onChunk?.call(chunk);
      }

      sw.stop();
      final fullText = chunks.join();
      LoggerService.instance.i(
        'RealLlmExecutor.executeStreaming 完成: nodeId=${node.id}, '
        'contentLength=${fullText.length}, chunkCount=${chunks.length}, '
        'firstChunk=${firstChunkMs}ms, total=${sw.elapsedMilliseconds}ms',
        category: LogCategory.ai,
        tags: ['dsl', 'llm'],
      );
      return _buildResult(node.id, fullText, config.structuredOutputEnabled);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        'RealLlmExecutor.executeStreaming 失败: nodeId=${node.id}, error=$e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'llm'],
      );
      return NodeRunResult(
        nodeId: node.id,
        status: NodeExecutionStatus.failed,
        error: e.toString(),
      );
    }
  }

  /// 构建 OpenAI 格式的消息列表
  ///
  /// 当 [structuredOutputEnabled] 为 true 时，参考 Dify 的
  /// structured_output.py 在 system prompt 前注入 JSON schema 约束提示，
  /// 确保模型输出 JSON 格式。
  List<ChatMessage> _buildMessages(
    DslNode node,
    VariablePool pool, {
    bool structuredOutputEnabled = false,
  }) {
    final promptTemplate = node.data['prompt_template'] as List?;
    if (promptTemplate == null || promptTemplate.isEmpty) {
      return [ChatMessage(role: 'user', content: '')];
    }

    // 推断 edition_type
    String editionType = 'basic';
    if (promptTemplate.isNotEmpty) {
      final last = promptTemplate.last;
      if (last is Map) {
        editionType = (last['edition_type'] as String?) ?? 'basic';
      }
    }

    // jinja2_variables
    final jinja2VarsRaw = node.data['prompt_config']?['jinja2_variables'];
    final jinja2Vars = jinja2VarsRaw is List
        ? jinja2VarsRaw.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    final messages = <ChatMessage>[];
    for (final p in promptTemplate) {
      if (p is! Map) continue;
      final role = p['role']?.toString() ?? 'user';
      String content;

      final pEditionType = (p['edition_type'] as String?) ?? editionType;
      if (pEditionType == 'jinja2' && p.containsKey('jinja2_text')) {
        final jinja2Text = p['jinja2_text']?.toString() ?? '';
        content = _renderer.renderTemplateWithJinja(
            pool, jinja2Text, jinja2Vars);
      } else {
        final text = p['text']?.toString() ?? '';
        content = _renderer.convertTemplate(pool, text);
      }

      messages.add(ChatMessage(role: role, content: content));
    }

    // structured_output: 注入 JSON schema 约束提示（Dify 风格）
    if (structuredOutputEnabled) {
      final schema = _extractStructuredOutputSchema(node);
      if (schema != null) {
        final schemaJson = jsonEncode(schema);
        final structuredPrompt =
            'You\'re a helpful AI assistant. You could answer questions and output in JSON format.\n'
            'constraints:\n'
            '    - You must output in JSON format.\n'
            '    - Do not output boolean value, use string type instead.\n'
            '    - Do not output integer or float value, use number type instead.\n'
            'Here is the JSON schema:\n$schemaJson\n';

        // 在 system prompt 前注入（或创建新的 system prompt）
        final systemIdx = messages.indexWhere((m) => m.role == 'system');
        if (systemIdx >= 0) {
          final existing = messages[systemIdx];
          messages[systemIdx] = ChatMessage(
            role: 'system',
            content: '$structuredPrompt\n${existing.content ?? ''}',
          );
        } else {
          messages.insert(0, ChatMessage(role: 'system', content: structuredPrompt));
        }

        LoggerService.instance.d(
          'structured_output: 注入 JSON schema 约束提示, schemaKeys=${(schema as Map).keys.toList()}',
          category: LogCategory.ai,
          tags: ['dsl', 'llm', 'structured-output'],
        );
      }
    }

    return messages;
  }

  /// 从节点 data 中提取 structured_output schema
  Map<String, dynamic>? _extractStructuredOutputSchema(DslNode node) {
    final structuredOutput = node.data['structured_output'];
    if (structuredOutput is Map<String, dynamic>) {
      final schema = structuredOutput['schema'];
      if (schema is Map<String, dynamic>) {
        return schema;
      }
    }
    return null;
  }

  /// 构建执行结果
  ///
  /// 当 [structuredOutputEnabled] 为 true 时，尝试解析 JSON。
  /// 参考 Dify 的 `_parse_structured_output`，增加鲁棒性：
  /// - 去除 markdown 代码围栏 ```json ... ```
  /// - 去除 deepseek-r1 的 `<think>...</think>` 前缀
  NodeRunResult _buildResult(
    String nodeId,
    String responseText,
    bool structuredOutputEnabled,
  ) {
    final outputs = <String, dynamic>{'text': responseText};

    if (structuredOutputEnabled && responseText.isNotEmpty) {
      try {
        var text = responseText.trim();

        // 去除 markdown 代码围栏
        if (text.startsWith('```')) {
          final fenceMatch = RegExp(r'^```(?:json)?\s*\n?').firstMatch(text);
          if (fenceMatch != null) {
            text = text.substring(fenceMatch.end);
          }
          if (text.endsWith('```')) {
            text = text.substring(0, text.length - 3);
          }
          text = text.trim();
        }

        final json = jsonDecode(text);
        if (json is Map<String, dynamic>) {
          outputs['structured_output'] = json;
        } else if (json is List && json.isNotEmpty) {
          // deepseek-r1 有时返回 [thinking, {...}] 格式
          final firstMap = json.firstWhere(
            (e) => e is Map<String, dynamic>,
            orElse: () => <String, dynamic>{},
          );
          if (firstMap is Map<String, dynamic> && firstMap.isNotEmpty) {
            outputs['structured_output'] = firstMap;
          }
        }
      } catch (_) {
        LoggerService.instance.w(
          'JSON structured_output 解析失败: nodeId=$nodeId, '
          'textLength=${responseText.length}',
          category: LogCategory.ai,
          tags: ['dsl', 'llm'],
        );
        // JSON 解析失败，保留原始文本
      }
    }

    return NodeRunResult(
      nodeId: nodeId,
      status: NodeExecutionStatus.succeeded,
      outputs: outputs,
    );
  }
}

/// LLM 节点配置（从 DSL data 中提取）
class LlmNodeConfig {
  final String model;
  final int maxTokens;
  final double temperature;
  final bool structuredOutputEnabled;

  const LlmNodeConfig({
    required this.model,
    required this.maxTokens,
    required this.temperature,
    required this.structuredOutputEnabled,
  });

  factory LlmNodeConfig.fromNode(DslNode node, String? defaultModel) {
    final modelData = node.data['model'] as Map?;
    final completionParams = modelData?['completion_params'] as Map?;

    // 模型名：优先用 defaultModel 覆盖，否则用 DSL 中的
    String model = modelData?['name']?.toString() ?? '';
    if (defaultModel != null && defaultModel.isNotEmpty) {
      model = defaultModel;
    }

    return LlmNodeConfig(
      model: model,
      maxTokens: completionParams?['max_tokens'] as int? ?? 4096,
      temperature:
          (completionParams?['temperature'] as num?)?.toDouble() ?? 0.7,
      structuredOutputEnabled:
          node.data['structured_output_enabled'] == true,
    );
  }
}

// ---------------------------------------------------------------------------
// IoLlmHttpClient: 使用 dart:io HttpClient 的真实 HTTP 客户端
// ---------------------------------------------------------------------------

/// 基于 dart:io HttpClient 的 LlmHttpClient 实现
class IoLlmHttpClient implements LlmHttpClient {
  final io.HttpClient _client = io.HttpClient();

  IoLlmHttpClient();

  @override
  Future<String> postJson(
      String url, Map<String, String> headers, String body) async {
    final uri = Uri.parse(url);
    final request = await _client.postUrl(uri);
    headers.forEach((k, v) => request.headers.set(k, v));
    request.add(utf8.encode(body));
    final response = await request.close();
    return await response.transform(utf8.decoder).join();
  }

  @override
  Stream<String> postJsonStream(
      String url, Map<String, String> headers, String body) async* {
    final uri = Uri.parse(url);
    final request = await _client.postUrl(uri);
    headers.forEach((k, v) => request.headers.set(k, v));
    request.add(utf8.encode(body));
    final response = await request.close();
    yield* response.transform(utf8.decoder);
  }
}