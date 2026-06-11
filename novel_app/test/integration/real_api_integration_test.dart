/// DSL 引擎真实 API 集成测试
///
/// 使用真实 LLM API 测试 DSL 引擎的完整工作流。
///
/// 运行方式:
///   cd novel_app
///   flutter test test/integration/real_api_integration_test.dart
///
/// 前置条件:
///   - 网络连接正常
///   - API 服务可用
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/condition_processor.dart';
import 'package:novel_app/services/dsl_engine/dsl_parser.dart';
import 'package:novel_app/services/dsl_engine/graph_engine.dart';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';
import 'package:novel_app/services/dsl_engine/models/variable_pool.dart';
import 'package:novel_app/services/dsl_engine/real_llm_executor.dart';
import 'package:novel_app/services/dsl_engine/template_renderer.dart';

// ============================================================================
// 配置
// ============================================================================

const apiBaseUrl = String.fromEnvironment('TEST_API_BASE_URL');
const apiKey = String.fromEnvironment('TEST_API_KEY');
const defaultModel = String.fromEnvironment('TEST_DEFAULT_MODEL', defaultValue: 'deepseek-chat');

// ============================================================================
// YAML 资源路径
// ============================================================================

const createrYamlPath = 'test/fixtures/creater.yml';
const structuredInfoYamlPath = 'test/fixtures/structured_info.yml';

// ============================================================================
// 测试
// ============================================================================

void main() {
  late DslParser parser;
  late TemplateRenderer renderer;

  setUp(() {
    parser = DslParser();
    renderer = TemplateRenderer();
  });

  group('真实 API - LLM Provider', () {
    test('阻塞调用 - 中文生成',
        timeout: const Timeout(Duration(minutes: 2)), () async {
      final provider = LlmProvider(
        LlmConfig(
          baseUrl: apiBaseUrl,
          apiKey: apiKey,
          defaultModel: defaultModel,
        ),
        httpClient: IoLlmHttpClient(),
      );

      final response = await provider.chat(
        messages: [
          ChatMessage(role: 'user', content: '请用一句话描述日落场景。'),
        ],
        maxTokens: 100,
      );

      expect(response.content, isNotEmpty);
      expect(response.content.length, greaterThan(10));
      print('✅ 阻塞调用响应: ${response.content}');
    });

    test('流式调用 - 中文生成',
        timeout: const Timeout(Duration(minutes: 2)), () async {
      final provider = LlmProvider(
        LlmConfig(
          baseUrl: apiBaseUrl,
          apiKey: apiKey,
          defaultModel: defaultModel,
        ),
        httpClient: IoLlmHttpClient(),
      );

      final chunks = <String>[];
      await for (final chunk in provider.chatStream(
        messages: [
          ChatMessage(role: 'user', content: '请用三句话描述古代宫殿。'),
        ],
        maxTokens: 200,
      )) {
        chunks.add(chunk);
      }

      final fullText = chunks.join();
      expect(fullText, isNotEmpty);
      expect(chunks.length, greaterThan(1));
      print('✅ 流式调用: ${chunks.length} chunks, 内容: $fullText');
    });

    test('结构化输出 - JSON 模式',
        timeout: const Timeout(Duration(minutes: 2)), () async {
      final provider = LlmProvider(
        LlmConfig(
          baseUrl: apiBaseUrl,
          apiKey: apiKey,
          defaultModel: defaultModel,
        ),
        httpClient: IoLlmHttpClient(),
      );

      final response = await provider.chat(
        messages: [
          ChatMessage(
            role: 'user',
            content: '请以JSON格式输出: {"name":"角色名","description":"描述"}',
          ),
        ],
        maxTokens: 200,
        responseFormat: {'type': 'json_object'},
      );

      expect(response.content, isNotEmpty);
      try {
        final parsed = jsonDecode(response.content);
        expect(parsed, isA<Map<String, dynamic>>());
        print('✅ 结构化输出: ${jsonEncode(parsed)}');
      } catch (e) {
        fail('响应不是有效 JSON: ${response.content}');
      }
    });
  });

  group('真实 API - RealLlmExecutor', () {
    test('executeBlocking - 从 DSL 节点提取配置并调用 LLM',
        timeout: const Timeout(Duration(minutes: 2)), () async {
      final yaml = File(createrYamlPath).readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);

      final llmNode = graph.nodes.firstWhere(
        (n) => n.type == NodeType.llm,
      );

      final pool = VariablePool();
      final startNode = graph.rootNode!;
      pool.add([startNode.id, 'cmd'], '特写');
      pool.add([startNode.id, 'user_input'], '描写一个古代将军在夕阳下回望战场的情景');
      pool.add([startNode.id, 'background_setting'], '古代战争背景');
      pool.add([startNode.id, 'current_chapter_content'], '将军站在山丘上');
      pool.add([startNode.id, 'history_chapters_content'], '');
      pool.add([startNode.id, 'next_chapter_overview'], '');
      pool.add([startNode.id, 'ai_writer_setting'], '');
      pool.add([startNode.id, 'roles'], '');
      pool.add([startNode.id, 'choice_content'], '');
      pool.add([startNode.id, 'outline'], '');
      pool.add([startNode.id, 'outline_item'], '');
      pool.add([startNode.id, 'scene'], '');
      pool.add([startNode.id, 'chat_history'], '');

      final executor = RealLlmExecutor(
        provider: LlmProvider(
          LlmConfig(
            baseUrl: apiBaseUrl,
            apiKey: apiKey,
            defaultModel: defaultModel,
          ),
          httpClient: IoLlmHttpClient(),
        ),
        defaultModel: defaultModel,
      );

      final result = await executor.executeBlocking(llmNode, pool);

      expect(result.status, NodeExecutionStatus.succeeded);
      expect(result.outputs, contains('text'));
      final text = result.outputs['text'] as String;
      expect(text, isNotEmpty);
      print('✅ RealLlmExecutor 阻塞: $text');
    });

    test('executeStreaming - 流式输出',
        timeout: const Timeout(Duration(minutes: 2)), () async {
      final yaml = File(createrYamlPath).readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);

      final llmNode = graph.nodes.firstWhere(
        (n) => n.type == NodeType.llm,
      );

      final pool = VariablePool();
      final startNode = graph.rootNode!;
      pool.add([startNode.id, 'cmd'], '特写');
      pool.add([startNode.id, 'user_input'], '描写雨夜中独行的剑客');
      pool.add([startNode.id, 'background_setting'], '武侠世界');
      pool.add([startNode.id, 'current_chapter_content'], '剑客在雨中行走');
      pool.add([startNode.id, 'history_chapters_content'], '');
      pool.add([startNode.id, 'next_chapter_overview'], '');
      pool.add([startNode.id, 'ai_writer_setting'], '');
      pool.add([startNode.id, 'roles'], '');
      pool.add([startNode.id, 'choice_content'], '');
      pool.add([startNode.id, 'outline'], '');
      pool.add([startNode.id, 'outline_item'], '');
      pool.add([startNode.id, 'scene'], '');
      pool.add([startNode.id, 'chat_history'], '');

      final executor = RealLlmExecutor(
        provider: LlmProvider(
          LlmConfig(
            baseUrl: apiBaseUrl,
            apiKey: apiKey,
            defaultModel: defaultModel,
          ),
          httpClient: IoLlmHttpClient(),
        ),
        defaultModel: defaultModel,
      );

      final chunks = <String>[];
      final result = await executor.executeStreaming(
        llmNode,
        pool,
        onChunk: (chunk) => chunks.add(chunk),
      );

      expect(result.status, NodeExecutionStatus.succeeded);
      expect(chunks, isNotEmpty);
      final fullText = chunks.join();
      expect(fullText, isNotEmpty);
      print('✅ RealLlmExecutor 流式: ${chunks.length} chunks, 内容: $fullText');
    });
  });

  group('真实 API - DSL 工作流 E2E', () {
    test('creater.yml - cmd=特写 完整工作流',
        timeout: const Timeout(Duration(minutes: 3)), () async {
      final yaml = File(createrYamlPath).readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);

      final pool = VariablePool();
      final startNode = graph.rootNode!;
      pool.add([startNode.id, 'cmd'], '特写');
      pool.add([startNode.id, 'user_input'], '描写一个古代将军在夕阳下回望战场的情景');
      pool.add([startNode.id, 'background_setting'], '古代战争背景，王朝末年');
      pool.add([startNode.id, 'current_chapter_content'], '将军站在山丘上，望着远方的战场');
      pool.add([startNode.id, 'history_chapters_content'], '');
      pool.add([startNode.id, 'next_chapter_overview'], '');
      pool.add([startNode.id, 'ai_writer_setting'], '');
      pool.add([startNode.id, 'roles'], '');
      pool.add([startNode.id, 'choice_content'], '');
      pool.add([startNode.id, 'outline'], '');
      pool.add([startNode.id, 'outline_item'], '');
      pool.add([startNode.id, 'scene'], '');
      pool.add([startNode.id, 'chat_history'], '');

      final realLlm = RealLlmExecutor(
        provider: LlmProvider(
          LlmConfig(
            baseUrl: apiBaseUrl,
            apiKey: apiKey,
            defaultModel: defaultModel,
          ),
          httpClient: IoLlmHttpClient(),
        ),
        defaultModel: defaultModel,
      );

      final engine = GraphEngine(
        graph: graph,
        variablePool: pool,
        nodeExecutor: (node, p) => _nodeExecutor(node, p, realLlm),
      );

      final events = await engine.run().toList();

      expect(events.first, isA<GraphRunStartedEvent>());
      expect(
        events.last,
        anyOf(
          isA<GraphRunSucceededEvent>(),
          isA<GraphRunPartialSucceededEvent>(),
        ),
      );

      // 验证 if-else 选择了 false 分支（特写不匹配任何 case）
      final ifElseEvents = events
          .whereType<NodeRunSucceededEvent>()
          .where((e) => e.nodeId == '1759151925879');
      expect(ifElseEvents.length, 1);
      expect(ifElseEvents.first.selectedHandle, 'false');

      // 验证 LLM 节点执行成功
      final llmEvents = events
          .whereType<NodeRunSucceededEvent>()
          .where((e) => e.nodeId == '1759151715295');
      expect(llmEvents.length, 1);
      expect(llmEvents.first.outputs, contains('text'));
      final llmOutput = llmEvents.first.outputs['text'] as String;
      expect(llmOutput, isNotEmpty);

      print('✅ creater.yml E2E 完成');
      print('   if-else 分支: false (特写)');
      print('   LLM 输出: ${llmOutput.substring(0, math.min(200, llmOutput.length))}...');
    });

    test('creater.yml - cmd=总结 完整工作流',
        timeout: const Timeout(Duration(minutes: 3)), () async {
      final yaml = File(createrYamlPath).readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);

      final pool = VariablePool();
      final startNode = graph.rootNode!;
      pool.add([startNode.id, 'cmd'], '总结');
      pool.add([startNode.id, 'user_input'], '');
      pool.add([startNode.id, 'background_setting'], '');
      pool.add([startNode.id, 'current_chapter_content'],
          '将军在战场上与敌军激战三天三夜，最终以少胜多，但付出了惨重的代价。战后他独自站在山丘上，望着夕阳下的战场，心中充满了对逝去战友的思念。');
      pool.add([startNode.id, 'history_chapters_content'], '');
      pool.add([startNode.id, 'next_chapter_overview'], '');
      pool.add([startNode.id, 'ai_writer_setting'], '');
      pool.add([startNode.id, 'roles'], '');
      pool.add([startNode.id, 'choice_content'], '');
      pool.add([startNode.id, 'outline'], '');
      pool.add([startNode.id, 'outline_item'], '');
      pool.add([startNode.id, 'scene'], '');
      pool.add([startNode.id, 'chat_history'], '');

      final realLlm = RealLlmExecutor(
        provider: LlmProvider(
          LlmConfig(
            baseUrl: apiBaseUrl,
            apiKey: apiKey,
            defaultModel: defaultModel,
          ),
          httpClient: IoLlmHttpClient(),
        ),
        defaultModel: defaultModel,
      );

      final engine = GraphEngine(
        graph: graph,
        variablePool: pool,
        nodeExecutor: (node, p) => _nodeExecutor(node, p, realLlm),
      );

      final events = await engine.run().toList();

      expect(events.first, isA<GraphRunStartedEvent>());
      expect(
        events.last,
        anyOf(
          isA<GraphRunSucceededEvent>(),
          isA<GraphRunPartialSucceededEvent>(),
        ),
      );

      final ifElseEvents = events
          .whereType<NodeRunSucceededEvent>()
          .where((e) => e.nodeId == '1759151925879');
      expect(ifElseEvents.length, 1);
      expect(ifElseEvents.first.selectedHandle,
          'd2112989-3424-433a-8ba6-ce2e3245bff1');

      final llmEvents = events
          .whereType<NodeRunSucceededEvent>()
          .where((e) => e.nodeId == '1759151715295');
      expect(llmEvents.length, 1);
      final llmOutput = llmEvents.first.outputs['text'] as String;
      expect(llmOutput, isNotEmpty);

      print('✅ creater.yml E2E (总结) 完成');
      print('   if-else 分支: 总结');
      print('   LLM 输出: ${llmOutput.substring(0, math.min(200, llmOutput.length))}...');
    });
  });

  group('真实 API - structured_info.yml E2E', () {
    test('structured_info.yml - cmd=生成 完整工作流',
        timeout: const Timeout(Duration(minutes: 3)), () async {
      final yaml = File(structuredInfoYamlPath).readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);

      final pool = VariablePool();
      final startNode = graph.rootNode!;
      pool.add([startNode.id, 'cmd'], '生成');
      pool.add([startNode.id, 'user_input'], '一个年轻剑客在雨夜中独行的场景');
      pool.add([startNode.id, 'background_setting'], '武侠世界');
      pool.add([startNode.id, 'current_chapter_content'], '');
      pool.add([startNode.id, 'history_chapters_content'], '');
      pool.add([startNode.id, 'next_chapter_overview'], '');
      pool.add([startNode.id, 'ai_writer_setting'], '');
      pool.add([startNode.id, 'roles'], '');
      pool.add([startNode.id, 'choice_content'], '');
      pool.add([startNode.id, 'outline'], '');
      pool.add([startNode.id, 'outline_item'], '');
      pool.add([startNode.id, 'scene'], '');
      pool.add([startNode.id, 'chat_history'], '');

      final realLlm = RealLlmExecutor(
        provider: LlmProvider(
          LlmConfig(
            baseUrl: apiBaseUrl,
            apiKey: apiKey,
            defaultModel: defaultModel,
          ),
          httpClient: IoLlmHttpClient(),
        ),
        defaultModel: defaultModel,
      );

      final engine = GraphEngine(
        graph: graph,
        variablePool: pool,
        nodeExecutor: (node, p) => _nodeExecutor(node, p, realLlm),
      );

      final events = await engine.run().toList();

      expect(events.first, isA<GraphRunStartedEvent>());
      expect(
        events.last,
        anyOf(
          isA<GraphRunSucceededEvent>(),
          isA<GraphRunPartialSucceededEvent>(),
        ),
      );

      // 收集所有 LLM 节点的输出
      final llmEvents = events
          .whereType<NodeRunSucceededEvent>()
          .where((e) {
            final node = graph.nodes.firstWhere(
              (n) => n.id == e.nodeId,
              orElse: () => DslNode(
                id: '', type: NodeType.unknown, title: '', data: const {},
              ),
            );
            return node.type == NodeType.llm;
          });

      print('✅ structured_info.yml E2E 完成');
      print('   执行了 ${llmEvents.length} 个 LLM 节点');
      for (final e in llmEvents) {
        final text = e.outputs['text']?.toString() ?? '';
        print('   节点 ${e.nodeId}: ${text.substring(0, math.min(100, text.length))}...');
      }
    });
  });
}

// ============================================================================
// 节点执行器（与 DslExecutor._nodeExecutor 相同逻辑）
// ============================================================================

Future<NodeRunResult> _nodeExecutor(
  DslNode node,
  VariablePool pool,
  RealLlmExecutor realLlm, {
  void Function(String chunk)? onChunk,
}) async {
  final renderer = TemplateRenderer();

  switch (node.type) {
    case NodeType.start:
      return NodeRunResult(
        nodeId: node.id,
        status: NodeExecutionStatus.succeeded,
        outputs: const {},
      );

    case NodeType.end:
      return _executeEnd(node, pool);

    case NodeType.ifElse:
      return _executeIfElse(node, pool);

    case NodeType.templateTransform:
      return _executeTemplateTransform(node, pool, renderer);

    case NodeType.variableAggregator:
      return _executeVariableAggregator(node, pool);

    case NodeType.llm:
      if (onChunk != null) {
        return realLlm.executeStreaming(node, pool, onChunk: onChunk);
      }
      return realLlm.executeBlocking(node, pool);

    case NodeType.unknown:
      return NodeRunResult(
        nodeId: node.id,
        status: NodeExecutionStatus.succeeded,
        outputs: const {'output': ''},
      );
  }
}

NodeRunResult _executeEnd(DslNode node, VariablePool pool) {
  final outputsConfig = node.data['outputs'] as List?;
  final result = <String, dynamic>{};
  if (outputsConfig != null) {
    for (final out in outputsConfig) {
      if (out is! Map) continue;
      final varName = out['variable']?.toString() ?? '';
      final selector = out['value_selector'] as List?;
      if (varName.isNotEmpty && selector != null) {
        final path = selector.map((e) => e.toString()).toList();
        final segment = pool.get(path);
        result[varName] = segment?.toObject() ?? '';
      }
    }
  }
  return NodeRunResult(
    nodeId: node.id,
    status: NodeExecutionStatus.succeeded,
    outputs: result,
  );
}

NodeRunResult _executeIfElse(DslNode node, VariablePool pool) {
  final processor = ConditionProcessor();
  final cases = DslParser().parseCases(node.data['cases']);

  for (final caseData in cases) {
    final result = processor.processConditions(
      variablePool: pool,
      conditions: caseData.conditions,
      operator: caseData.logicalOperator,
    );
    if (result.finalResult) {
      return NodeRunResult(
        nodeId: node.id,
        status: NodeExecutionStatus.succeeded,
        selectedHandle: caseData.caseId,
        outputs: {'selected_case_id': caseData.caseId},
      );
    }
  }

  return NodeRunResult(
    nodeId: node.id,
    status: NodeExecutionStatus.succeeded,
    selectedHandle: 'false',
    outputs: {'selected_case_id': 'false'},
  );
}

NodeRunResult _executeTemplateTransform(
    DslNode node, VariablePool pool, TemplateRenderer renderer) {
  final template = node.data['template']?.toString() ?? '';
  final variables = node.data['variables'] as List?;

  String result;
  if (variables is List && variables.isNotEmpty) {
    result = renderer.renderTemplateTransform(
      pool,
      template: template,
      variables: variables.cast<Map<String, dynamic>>(),
    );
  } else {
    result = renderer.convertTemplate(pool, template);
  }

  return NodeRunResult(
    nodeId: node.id,
    status: NodeExecutionStatus.succeeded,
    outputs: {'output': result},
  );
}

NodeRunResult _executeVariableAggregator(DslNode node, VariablePool pool) {
  final variables = node.data['variables'] as List?;

  if (variables != null) {
    for (final v in variables) {
      if (v is! Map) continue;
      final selector = v['value_selector'] as List?;
      if (selector == null) continue;
      final path = selector.map((e) => e.toString()).toList();
      final segment = pool.get(path);
      if (segment != null) {
        final val = segment.toObject();
        if (val != null && val.toString().isNotEmpty) {
          return NodeRunResult(
            nodeId: node.id,
            status: NodeExecutionStatus.succeeded,
            outputs: {'output': val},
          );
        }
      }
    }
  }

  return NodeRunResult(
    nodeId: node.id,
    status: NodeExecutionStatus.succeeded,
    outputs: {'output': ''},
  );
}