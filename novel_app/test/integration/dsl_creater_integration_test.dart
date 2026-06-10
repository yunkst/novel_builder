/// DSL 引擎集成测试 - 创建文章场景（真实 LLM API）
///
/// 复刻 tool/dsl_integration_test.dart 的工作流测试，但用 flutter_test 框架运行
/// 避免 LoggerService import flutter/material.dart 后无法用纯 dart run 的问题。
///
/// 覆盖创建文章场景:
///   - cmd=特写  → 走 LLM 分支生成场景特写
///   - cmd=总结  → 走 LLM 分支生成章节总结
///
/// 运行:
///   cd novel_app
///   flutter test test/integration/dsl_creater_integration_test.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

const apiBaseUrl = 'https://new-api.c2h4.cn/v1';
const apiKey = 'sk-WXwOAGUEUQ2QDTiJE8yElBHUSphtsohFUOShE2lOQJCSDnD7';
const defaultModel = 'DeepSeek-V4-Pro';

// ============================================================================
// 修复版 HTTP 客户端（避免 dart:io HttpClient 的中文编码问题）
// ============================================================================

class FixedHttpClient implements LlmHttpClient {
  final http.Client _client = http.Client();

  @override
  Future<String> postJson(
      String url, Map<String, String> headers, String body) async {
    final response = await _client.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    );
    if (response.statusCode >= 400) {
      throw HttpException(
        'HTTP ${response.statusCode}: ${response.body}',
        uri: Uri.parse(url),
      );
    }
    return response.body;
  }

  @override
  Stream<String> postJsonStream(
      String url, Map<String, String> headers, String body) async* {
    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll(headers);
    request.body = body;
    final streamed = await _client.send(request);
    if (streamed.statusCode >= 400) {
      final errBody = await streamed.stream.bytesToString();
      throw HttpException(
        'HTTP ${streamed.statusCode}: $errBody',
        uri: Uri.parse(url),
      );
    }
    yield* streamed.stream.transform(utf8.decoder);
  }
}

// ============================================================================
// 辅助函数
// ============================================================================

RealLlmExecutor createExecutor() {
  return RealLlmExecutor(
    provider: LlmProvider(
      LlmConfig(
        baseUrl: apiBaseUrl,
        apiKey: apiKey,
        defaultModel: defaultModel,
      ),
      httpClient: FixedHttpClient(),
    ),
    defaultModel: defaultModel,
  );
}

void injectInputs(
  WorkflowGraph graph,
  VariablePool pool,
  Map<String, dynamic> inputs,
) {
  final startNode = graph.rootNode;
  if (startNode == null) return;

  for (final entry in inputs.entries) {
    pool.add([startNode.id, entry.key], entry.value);
  }

  final variables = startNode.data['variables'] as List?;
  if (variables != null) {
    for (final v in variables) {
      if (v is! Map) continue;
      final name = v['variable']?.toString();
      if (name == null || inputs.containsKey(name)) continue;
      final defaultVal = v['default']?.toString();
      if (defaultVal != null && defaultVal.isNotEmpty) {
        pool.add([startNode.id, name], defaultVal);
      } else {
        pool.add([startNode.id, name], '');
      }
    }
  }
}

Future<NodeRunResult> nodeExecutor(
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

    case NodeType.ifElse:
      final processor = ConditionProcessor();
      final cases = DslParser().parseCases(node.data['cases']);
      for (final caseData in cases) {
        final r = processor.processConditions(
          variablePool: pool,
          conditions: caseData.conditions,
          operator: caseData.logicalOperator,
        );
        if (r.finalResult) {
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

    case NodeType.templateTransform:
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

    case NodeType.variableAggregator:
      final variables = node.data['variables'] as List?;
      if (variables != null) {
        for (final v in variables) {
          List<String> path;
          if (v is Map) {
            final selector = v['value_selector'];
            if (selector is! List) continue;
            path = selector.map((e) => e.toString()).toList();
          } else if (v is List) {
            path = v.map((e) => e.toString()).toList();
            if (path.length < 2) continue;
          } else {
            continue;
          }
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

// ============================================================================
// 主测试
// ============================================================================

void main() {
  test('creater.yml 创建文章 - cmd=特写 (流式)', () async {
    final yaml = File('test/fixtures/creater.yml').readAsStringSync();
    final parser = DslParser();
    final graph = parser.parseGraphConfig(yaml);
    print('   解析: ${graph.nodes.length} 个节点, ${graph.edges.length} 条边');

    final pool = VariablePool();
    injectInputs(graph, pool, {
      'cmd': '特写',
      'user_input': '描写一个古代将军在夕阳下回望战场的情景',
      'background_setting': '古代战争背景，王朝末年',
      'current_chapter_content': '将军站在山丘上，望着远方的战场',
    });

    // 验证变量注入
    final cmdSeg = pool.get(['1759138104711', 'cmd']);
    final userInputSeg = pool.get(['1759138104711', 'user_input']);
    print('   变量注入: cmd=${cmdSeg?.toObject()}, user_input=${userInputSeg?.toObject()}');

    final realLlm = createExecutor();
    final engine = GraphEngine(
      graph: graph,
      variablePool: pool,
      nodeExecutor: (node, p) => nodeExecutor(node, p, realLlm),
    );

    final events = await engine.run().toList();
    final lastEvent = events.last;
    expect(
      lastEvent,
      anyOf(isA<GraphRunSucceededEvent>(), isA<GraphRunPartialSucceededEvent>()),
    );

    // 第一个 if-else (1759151925879): cmd=特写 不在 cases 中 → false
    final ifElse1 = events
        .whereType<NodeRunSucceededEvent>()
        .where((e) => e.nodeId == '1759151925879');
    expect(ifElse1.isNotEmpty, true);
    expect(ifElse1.first.selectedHandle, 'false',
        reason: 'cmd=特写 在第一个 if-else 无匹配 case → 走 false');

    // 第二个 if-else (17622467453950): cmd=特写 匹配 97c88510 case
    final ifElse2 = events
        .whereType<NodeRunSucceededEvent>()
        .where((e) => e.nodeId == '17622467453950');
    expect(ifElse2.isNotEmpty, true);
    expect(ifElse2.first.selectedHandle, '97c88510-4690-44da-a5bb-cf8fc952ae69',
        reason: 'cmd=特写 在第二个 if-else 应匹配 97c88510 case');

    final llmEvents = events
        .whereType<NodeRunSucceededEvent>()
        .where((e) => e.nodeId == '1759151715295');
    expect(llmEvents.isNotEmpty, true, reason: 'LLM 节点应被执行');

    final llmOutput = llmEvents.first.outputs['text'] as String? ?? '';
    expect(llmOutput.isNotEmpty, true, reason: 'LLM 输出不应为空');

    final order = _extractExecutionOrder(events);
    final nodeTypes = <String>[];
    for (final id in order) {
      final node = graph.nodes.firstWhere(
        (n) => n.id == id,
        orElse: () => DslNode(id: id, type: NodeType.unknown, title: '', data: const {}),
      );
      nodeTypes.add('${node.type.name}(${node.title})');
    }

    print('   ✅ cmd=特写 通过');
    print('      节点执行路径: ${nodeTypes.join(' → ')}');
    print('      if-else#1 分支: ${ifElse1.first.selectedHandle}');
    print('      if-else#2 分支: ${ifElse2.first.selectedHandle}');
    print('      LLM 输出长度: ${llmOutput.length} 字符');
    print('      LLM 输出 (前 300 字符): ${llmOutput.substring(0, llmOutput.length > 300 ? 300 : llmOutput.length)}...');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('creater.yml 创建文章 - cmd=总结 (流式)', () async {
    final yaml = File('test/fixtures/creater.yml').readAsStringSync();
    final parser = DslParser();
    final graph = parser.parseGraphConfig(yaml);

    final pool = VariablePool();
    injectInputs(graph, pool, {
      'cmd': '总结',
      'current_chapter_content':
          '将军在战场上与敌军激战三天三夜，最终以少胜多，但付出了惨重的代价。战后他独自站在山丘上，望着夕阳下的战场，心中充满了对逝去战友的思念。',
    });

    final realLlm = createExecutor();
    final engine = GraphEngine(
      graph: graph,
      variablePool: pool,
      nodeExecutor: (node, p) => nodeExecutor(node, p, realLlm),
    );

    final events = await engine.run().toList();
    expect(
      events.last,
      anyOf(isA<GraphRunSucceededEvent>(), isA<GraphRunPartialSucceededEvent>()),
    );

    final ifElse1 = events
        .whereType<NodeRunSucceededEvent>()
        .where((e) => e.nodeId == '1759151925879');
    expect(ifElse1.isNotEmpty, true);
    expect(ifElse1.first.selectedHandle, 'd2112989-3424-433a-8ba6-ce2e3245bff1',
        reason: 'cmd=总结 应选 d2112989 分支');

    final llmEvents = events
        .whereType<NodeRunSucceededEvent>()
        .where((e) => e.nodeId == '1759151715295');
    expect(llmEvents.isNotEmpty, true);

    final llmOutput = llmEvents.first.outputs['text'] as String? ?? '';
    expect(llmOutput.isNotEmpty, true);

    final order = _extractExecutionOrder(events);
    final nodeTypes = <String>[];
    for (final id in order) {
      final node = graph.nodes.firstWhere(
        (n) => n.id == id,
        orElse: () => DslNode(id: id, type: NodeType.unknown, title: '', data: const {}),
      );
      nodeTypes.add('${node.type.name}(${node.title})');
    }

    print('   ✅ cmd=总结 通过');
    print('      节点执行路径: ${nodeTypes.join(' → ')}');
    print('      if-else#1 分支: ${ifElse1.first.selectedHandle}');
    print('      LLM 输出长度: ${llmOutput.length} 字符');
    print('      LLM 输出 (前 300 字符): ${llmOutput.substring(0, llmOutput.length > 300 ? 300 : llmOutput.length)}...');
  }, timeout: const Timeout(Duration(minutes: 3)));
  test('structured_info.yml 结构化信息 - cmd=生成 (structured_output)', () async {
    final yaml = File('test/fixtures/structured_info.yml').readAsStringSync();
    final parser = DslParser();
    final graph = parser.parseGraphConfig(yaml);
    print('   解析: ${graph.nodes.length} 个节点, ${graph.edges.length} 条边');

    final pool = VariablePool();
    injectInputs(graph, pool, {
      'cmd': '生成',
      'user_input': '一个年轻剑客在雨夜中独行的场景',
      'chapters_content':
          '夜雨如注，一袭白衣的剑客独自走在青石板路上。他的名字叫李云，江湖人称"白衣剑客"。他身材修长，面容清冷，腰间悬挂着一柄古朴的长剑。雨打在他身上，却仿佛与他无关。他目光如炬，每一步都沉稳有力，仿佛这世间没有什么能够让他动摇。',
    });

    // 验证变量注入
    final cmdSeg = pool.get(['1759138104711', 'cmd']);
    print('   变量注入: cmd=${cmdSeg?.toObject()}');

    final realLlm = createExecutor();
    final engine = GraphEngine(
      graph: graph,
      variablePool: pool,
      nodeExecutor: (node, p) => nodeExecutor(node, p, realLlm),
    );

    final events = await engine.run().toList();
    final lastEvent = events.last;
    expect(
      lastEvent,
      anyOf(isA<GraphRunSucceededEvent>(), isA<GraphRunPartialSucceededEvent>()),
    );

    // if-else (1765253093804): cmd=生成 匹配 case 'true'
    final ifElse = events
        .whereType<NodeRunSucceededEvent>()
        .where((e) => e.nodeId == '1765253093804');
    expect(ifElse.isNotEmpty, true);
    expect(ifElse.first.selectedHandle, 'true',
        reason: 'cmd=生成 应匹配 true case');

    // 至少有一个 LLM 节点被执行
    final llmEvents = events
        .whereType<NodeRunSucceededEvent>()
        .where((e) {
          final node = graph.nodes.firstWhere(
            (n) => n.id == e.nodeId,
            orElse: () => DslNode(id: '', type: NodeType.unknown, title: '', data: const {}),
          );
          return node.type == NodeType.llm;
        });
    expect(llmEvents.isNotEmpty, true, reason: '至少有一个 LLM 节点被执行');

    // 检查 structured_output 解析
    int jsonParsed = 0;
    int jsonFailed = 0;
    for (final e in llmEvents) {
      final node = graph.nodes.firstWhere(
        (n) => n.id == e.nodeId,
        orElse: () => DslNode(id: '', type: NodeType.unknown, title: '', data: const {}),
      );
      final hasStructuredOutput = node.data['structured_output_enabled'] == true;
      final text = e.outputs['text'] as String? ?? '';
      final structured = e.outputs['structured_output'];

      if (hasStructuredOutput && structured != null) {
        jsonParsed++;
        print('      节点 ${e.nodeId} (${node.title}): structured_output 类型=${structured.runtimeType}');
      } else if (hasStructuredOutput && text.isNotEmpty) {
        // 尝试手动解析
        try {
          final json = jsonDecode(text);
          if (json is Map<String, dynamic>) {
            jsonParsed++;
            print('      节点 ${e.nodeId} (${node.title}): JSON 手动解析成功');
          } else {
            jsonFailed++;
            print('      节点 ${e.nodeId} (${node.title}): JSON 解析但非 Map, type=${json.runtimeType}');
          }
        } catch (_) {
          jsonFailed++;
          print('      节点 ${e.nodeId} (${node.title}): JSON 解析失败');
          print('         text 内容 (前 500 字符): ${text.substring(0, text.length > 500 ? 500 : text.length)}');
        }
      }
    }

    print('   ✅ cmd=生成 通过');
    print('      if-else 分支: ${ifElse.first.selectedHandle}');
    print('      LLM 节点执行: ${llmEvents.length} 个');
    print('      structured_output: ${jsonParsed} 个成功, ${jsonFailed} 个失败');

    // 打印执行路径
    final order = _extractExecutionOrder(events);
    final nodeTypes = <String>[];
    for (final id in order) {
      final node = graph.nodes.firstWhere(
        (n) => n.id == id,
        orElse: () => DslNode(id: id, type: NodeType.unknown, title: '', data: const {}),
      );
      nodeTypes.add('${node.type.name}(${node.title})');
    }
    print('      节点执行路径: ${nodeTypes.join(' → ')}');

    // 打印 end 节点输出
    final endEvents = events.whereType<NodeRunSucceededEvent>().where((e) {
      final node = graph.nodes.firstWhere(
        (n) => n.id == e.nodeId,
        orElse: () => DslNode(id: '', type: NodeType.unknown, title: '', data: const {}),
      );
      return node.type == NodeType.end;
    });
    if (endEvents.isNotEmpty) {
      final endOutputs = endEvents.first.outputs;
      final contentStr = endOutputs['content']?.toString() ?? '';
      print('      end 输出 content 长度: ${contentStr.length}');
      if (contentStr.isNotEmpty) {
        print('      end 输出 (前 300 字符): ${contentStr.substring(0, contentStr.length > 300 ? 300 : contentStr.length)}...');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

List<String> _extractExecutionOrder(List<GraphEngineEvent> events) {
  return events
      .whereType<NodeRunSucceededEvent>()
      .map((e) => e.nodeId)
      .toList();
}
