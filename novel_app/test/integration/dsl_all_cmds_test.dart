/// DSL 引擎全分支集成测试 - 所有 cmd 场景
///
/// 覆盖:
///   creater.yml: 总结/场景描写/生成大纲/生成细纲/聊天/设定总结/特写
///   structured_info.yml: 生成/角色卡提示词描写/拍照/场面绘制/图生视频/大纲生成角色/生成剧本/提取角色/AI伴读/提取标签
///
/// 运行:
///   cd novel_app
///   flutter test test/integration/dsl_all_cmds_test.dart
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

const apiBaseUrl = String.fromEnvironment('TEST_API_BASE_URL');
const apiKey = String.fromEnvironment('TEST_API_KEY');
const defaultModel = String.fromEnvironment('TEST_DEFAULT_MODEL', defaultValue: 'deepseek-chat');

// ============================================================================
// HTTP 客户端
// ============================================================================

class FixedHttpClient implements LlmHttpClient {
  final http.Client _client = http.Client();

  @override
  Future<String> postJson(
      String url, Map<String, String> headers, String body) async {
    final response = await _client.post(
      Uri.parse(url), headers: headers, body: body,
    );
    if (response.statusCode >= 400) {
      throw HttpException('HTTP ${response.statusCode}: ${response.body}', uri: Uri.parse(url));
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
      throw HttpException('HTTP ${streamed.statusCode}: $errBody', uri: Uri.parse(url));
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
      LlmConfig(baseUrl: apiBaseUrl, apiKey: apiKey, defaultModel: defaultModel),
      httpClient: FixedHttpClient(),
    ),
    defaultModel: defaultModel,
  );
}

void injectInputs(WorkflowGraph graph, VariablePool pool, Map<String, dynamic> inputs) {
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

Future<NodeRunResult> nodeExecutor(DslNode node, VariablePool pool, RealLlmExecutor realLlm) async {
  final renderer = TemplateRenderer();
  switch (node.type) {
    case NodeType.start:
      return NodeRunResult(nodeId: node.id, status: NodeExecutionStatus.succeeded, outputs: const {});
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
      return NodeRunResult(nodeId: node.id, status: NodeExecutionStatus.succeeded, outputs: result);
    case NodeType.ifElse:
      final processor = ConditionProcessor();
      final cases = DslParser().parseCases(node.data['cases']);
      for (final caseData in cases) {
        final r = processor.processConditions(variablePool: pool, conditions: caseData.conditions, operator: caseData.logicalOperator);
        if (r.finalResult) {
          return NodeRunResult(nodeId: node.id, status: NodeExecutionStatus.succeeded, selectedHandle: caseData.caseId, outputs: {'selected_case_id': caseData.caseId});
        }
      }
      return NodeRunResult(nodeId: node.id, status: NodeExecutionStatus.succeeded, selectedHandle: 'false', outputs: {'selected_case_id': 'false'});
    case NodeType.templateTransform:
      final template = node.data['template']?.toString() ?? '';
      final variables = node.data['variables'] as List?;
      String result;
      if (variables is List && variables.isNotEmpty) {
        result = renderer.renderTemplateTransform(pool, template: template, variables: variables.cast<Map<String, dynamic>>());
      } else {
        result = renderer.convertTemplate(pool, template);
      }
      return NodeRunResult(nodeId: node.id, status: NodeExecutionStatus.succeeded, outputs: {'output': result});
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
          } else { continue; }
          final segment = pool.get(path);
          if (segment != null) {
            final val = segment.toObject();
            if (val != null && val.toString().isNotEmpty) {
              return NodeRunResult(nodeId: node.id, status: NodeExecutionStatus.succeeded, outputs: {'output': val});
            }
          }
        }
      }
      return NodeRunResult(nodeId: node.id, status: NodeExecutionStatus.succeeded, outputs: {'output': ''});
    case NodeType.llm:
      return realLlm.executeBlocking(node, pool);
    case NodeType.unknown:
      return NodeRunResult(nodeId: node.id, status: NodeExecutionStatus.succeeded, outputs: const {'output': ''});
  }
}

/// 运行完整工作流，返回结构化结果
Future<_RunResult> _runWorkflow({
  required String yamlPath,
  required Map<String, dynamic> inputs,
  required String expectedBranch,
  String? ifElseNodeId,
}) async {
  final yaml = File(yamlPath).readAsStringSync();
  final parser = DslParser();
  final graph = parser.parseGraphConfig(yaml);

  final pool = VariablePool();
  injectInputs(graph, pool, inputs);

  final realLlm = createExecutor();
  final engine = GraphEngine(
    graph: graph,
    variablePool: pool,
    nodeExecutor: (node, p) => nodeExecutor(node, p, realLlm),
  );

  final events = await engine.run().toList();

  // 提取执行路径
  final executionPath = <String>[];
  for (final e in events.whereType<NodeRunSucceededEvent>()) {
    final node = graph.nodes.firstWhere((n) => n.id == e.nodeId,
        orElse: () => DslNode(id: e.nodeId, type: NodeType.unknown, title: '', data: const {}));
    executionPath.add('${node.type.name}(${node.title})');
  }

  // 提取 if-else 分支
  String? actualBranch;
  if (ifElseNodeId != null) {
    final ifElseEvent = events.whereType<NodeRunSucceededEvent>().where((e) => e.nodeId == ifElseNodeId).firstOrNull;
    actualBranch = ifElseEvent?.selectedHandle;
  }

  // 提取 LLM 输出
  final llmOutputs = <String, String>{};
  for (final e in events.whereType<NodeRunSucceededEvent>()) {
    final node = graph.nodes.firstWhere((n) => n.id == e.nodeId,
        orElse: () => DslNode(id: e.nodeId, type: NodeType.unknown, title: '', data: const {}));
    if (node.type == NodeType.llm) {
      final text = e.outputs['text'] as String? ?? '';
      llmOutputs[node.title] = text;
    }
  }

  // 提取 end 输出
  final endEvent = events.whereType<NodeRunSucceededEvent>().where((e) {
    final node = graph.nodes.firstWhere((n) => n.id == e.nodeId,
        orElse: () => DslNode(id: e.nodeId, type: NodeType.unknown, title: '', data: const {}));
    return node.type == NodeType.end;
  }).firstOrNull;
  final endOutputs = endEvent?.outputs ?? {};

  final lastEvent = events.last;
  final succeeded = lastEvent is GraphRunSucceededEvent || lastEvent is GraphRunPartialSucceededEvent;

  return _RunResult(
    succeeded: succeeded,
    executionPath: executionPath,
    actualBranch: actualBranch,
    expectedBranch: expectedBranch,
    llmOutputs: llmOutputs,
    endOutputs: endOutputs,
    nodeCount: graph.nodes.length,
    edgeCount: graph.edges.length,
  );
}

class _RunResult {
  final bool succeeded;
  final List<String> executionPath;
  final String? actualBranch;
  final String expectedBranch;
  final Map<String, String> llmOutputs;
  final Map<String, dynamic> endOutputs;
  final int nodeCount;
  final int edgeCount;

  _RunResult({
    required this.succeeded,
    required this.executionPath,
    required this.actualBranch,
    required this.expectedBranch,
    required this.llmOutputs,
    required this.endOutputs,
    required this.nodeCount,
    required this.edgeCount,
  });
}

// ============================================================================
// 测试数据 - 小说场景背景
// ============================================================================

const novelContent = '夜雨如注，一袭白衣的剑客独自走在青石板路上。他的名字叫李云，江湖人称"白衣剑客"。'
    '他身材修长，面容清冷，腰间悬挂着一柄古朴的长剑。雨打在他身上，却仿佛与他无关。'
    '他目光如炬，每一步都沉稳有力，仿佛这世间没有什么能够让他动摇。';

const backgroundSetting = '武侠世界，江湖纷争不断，各大门派明争暗斗';

const roles = '李云：白衣剑客，性格冷峻，身手不凡';

const outline = '第一幕：李云独自雨夜行走\n第二幕：遭遇伏击\n第三幕：揭开身世之谜';

const outlineItem = '第一幕第一场：李云走在雨夜的青石板路上，内心独白';

// ============================================================================
// creater.yml 全分支测试
// ============================================================================

void main() {
  // -- creater.yml --
  group('creater.yml 全分支测试', () {
    test('cmd=总结', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/creater.yml',
        inputs: {'cmd': '总结', 'current_chapter_content': novelContent},
        expectedBranch: 'd2112989-3424-433a-8ba6-ce2e3245bff1',
        ifElseNodeId: '1759151925879',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      expect(r.llmOutputs.isNotEmpty, true);
      _printResult('总结', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=场景描写', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/creater.yml',
        inputs: {'cmd': '场景描写', 'user_input': '描写雨夜中独行的剑客', 'current_chapter_content': novelContent, 'background_setting': backgroundSetting},
        expectedBranch: '6fa240b8-f5f2-4152-9a71-49a2ecc29bdc',
        ifElseNodeId: '1759151925879',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      expect(r.llmOutputs.isNotEmpty, true);
      _printResult('场景描写', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=生成大纲', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/creater.yml',
        inputs: {'cmd': '生成大纲', 'user_input': '生成武侠小说大纲', 'background_setting': backgroundSetting, 'current_chapter_content': novelContent, 'outline': outline},
        expectedBranch: 'ffa133ba-8fe7-4bb9-89be-a2c28afde46b',
        ifElseNodeId: '1759151925879',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      expect(r.llmOutputs.isNotEmpty, true);
      _printResult('生成大纲', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=生成细纲', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/creater.yml',
        inputs: {'cmd': '生成细纲', 'user_input': '生成第一幕细纲', 'background_setting': backgroundSetting, 'current_chapter_content': novelContent, 'outline': outline, 'outline_item': outlineItem},
        expectedBranch: 'c6f3af15-0604-4717-9bb9-1e3ae8878ed7',
        ifElseNodeId: '1759151925879',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      expect(r.llmOutputs.isNotEmpty, true);
      _printResult('生成细纲', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=聊天', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/creater.yml',
        inputs: {'cmd': '聊天', 'user_input': '你好，帮我构思一个武侠角色', 'current_chapter_content': novelContent, 'roles': roles},
        expectedBranch: 'c414a0ea-9287-453f-ba61-4b79507e8dd7',
        ifElseNodeId: '1759151925879',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      expect(r.llmOutputs.isNotEmpty, true);
      _printResult('聊天', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=设定总结', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/creater.yml',
        inputs: {'cmd': '设定总结', 'current_chapter_content': novelContent, 'background_setting': backgroundSetting, 'roles': roles},
        expectedBranch: '287da9d9-4256-46e1-95b7-193441f0ea84',
        ifElseNodeId: '1759151925879',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      expect(r.llmOutputs.isNotEmpty, true);
      _printResult('设定总结', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=特写', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/creater.yml',
        inputs: {'cmd': '特写', 'user_input': '描写剑客在雨夜中的特写', 'current_chapter_content': novelContent, 'background_setting': backgroundSetting},
        expectedBranch: '97c88510-4690-44da-a5bb-cf8fc952ae69',
        ifElseNodeId: '17622467453950', // 第二个 if-else
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      expect(r.llmOutputs.isNotEmpty, true);
      _printResult('特写', r);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  // -- structured_info.yml --
  group('structured_info.yml 全分支测试', () {
    test('cmd=生成', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/structured_info.yml',
        inputs: {'cmd': '生成', 'user_input': '提取小说中的角色信息', 'chapters_content': novelContent},
        expectedBranch: 'true',
        ifElseNodeId: '1765253093804',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      expect(r.llmOutputs.isNotEmpty, true);
      _printResult('生成', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=角色卡提示词描写', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/structured_info.yml',
        inputs: {'cmd': '角色卡提示词描写', 'user_input': '为李云生成角色卡提示词', 'chapters_content': novelContent},
        expectedBranch: 'dea14d44-4aaa-43b4-b132-05b15a3ab7ca',
        ifElseNodeId: '1765253093804',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      _printResult('角色卡提示词描写', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=拍照', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/structured_info.yml',
        inputs: {'cmd': '拍照', 'user_input': '为剑客场景生成图片提示词', 'chapters_content': novelContent},
        expectedBranch: '4c4b1b82-c7ca-4926-8d11-bbf6843475ce',
        ifElseNodeId: '1765253093804',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      _printResult('拍照', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=场面绘制', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/structured_info.yml',
        inputs: {'cmd': '场面绘制', 'user_input': '绘制雨夜剑客的场面', 'chapters_content': novelContent},
        expectedBranch: 'e2df5d17-53cb-47a7-8e97-40eba21b1132',
        ifElseNodeId: '1765253093804',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      _printResult('场面绘制', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=图生视频', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/structured_info.yml',
        inputs: {'cmd': '图生视频', 'user_input': '将雨夜场景转为视频', 'chapters_content': novelContent},
        expectedBranch: '48b453c7-93e6-47c7-a3ac-1d796d93c2f6',
        ifElseNodeId: '1765253093804',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      _printResult('图生视频', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=大纲生成角色', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/structured_info.yml',
        inputs: {'cmd': '大纲生成角色', 'user_input': '从大纲中提取角色', 'chapters_content': novelContent},
        expectedBranch: 'e3f4fd99-7a3c-441a-abde-f997046c1a71',
        ifElseNodeId: '1765253093804',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      _printResult('大纲生成角色', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=生成剧本', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/structured_info.yml',
        inputs: {'cmd': '生成剧本', 'user_input': '将小说内容转为剧本', 'chapters_content': novelContent},
        expectedBranch: '3b3153f6-e5c8-4660-bc42-004b0d14eca4',
        ifElseNodeId: '1765253093804',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      _printResult('生成剧本', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=提取角色', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/structured_info.yml',
        inputs: {'cmd': '提取角色', 'user_input': '提取小说中的角色', 'chapters_content': novelContent},
        expectedBranch: 'd5f7f264-4309-4f60-b7f5-9e9cf8c9c3eb',
        ifElseNodeId: '1765253093804',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      _printResult('提取角色', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=AI伴读', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/structured_info.yml',
        inputs: {'cmd': 'AI伴读', 'user_input': '帮我理解这段内容', 'chapters_content': novelContent},
        expectedBranch: 'a210f2cf-e506-43c4-a9be-fb8d6cc5de27',
        ifElseNodeId: '1765253093804',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      _printResult('AI伴读', r);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cmd=提取标签', () async {
      final r = await _runWorkflow(
        yamlPath: 'test/fixtures/structured_info.yml',
        inputs: {'cmd': '提取标签', 'user_input': '提取小说标签', 'chapters_content': novelContent},
        expectedBranch: 'c2faa150-7fb6-4d43-89d6-80c07384d10f',
        ifElseNodeId: '1765253093804',
      );
      expect(r.succeeded, true);
      expect(r.actualBranch, r.expectedBranch);
      _printResult('提取标签', r);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

// ============================================================================
// 打印辅助
// ============================================================================

void _printResult(String cmd, _RunResult r) {
  final branchOk = r.actualBranch == r.expectedBranch ? '✅' : '❌';
  print('   $branchOk cmd=$cmd');
  print('      分支: ${r.actualBranch} (期望: ${r.expectedBranch})');
  print('      路径: ${r.executionPath.join(' → ')}');
  if (r.llmOutputs.isNotEmpty) {
    for (final e in r.llmOutputs.entries) {
      final preview = e.value.length > 150 ? '${e.value.substring(0, 150)}...' : e.value;
      print('      LLM(${e.key}): ${e.value.length} 字符 → $preview');
    }
  }
  if (r.endOutputs.isNotEmpty) {
    final content = r.endOutputs['content']?.toString() ?? '';
    if (content.isNotEmpty) {
      final preview = content.length > 200 ? '${content.substring(0, 200)}...' : content;
      print('      end 输出: ${content.length} 字符 → $preview');
    }
  }
}
