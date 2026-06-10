/// DSL Assets 加载与执行验证测试
///
/// **目的**：验证 Flutter app 通过 `rootBundle.loadString` 加载打包在
/// `assets/dsl/` 下的两份 Dify 导出工作流，并用当前实现的
/// `DslParser` + `GraphEngine` + 各节点执行器完成端到端执行。
///
/// **覆盖**：
/// 1. 加载 `assets/dsl/creater.yml` 并解析为 WorkflowGraph
/// 2. 加载 `assets/dsl/structured_info.yml` 并解析为 WorkflowGraph
/// 3. 用 mock executor 跑通 creater.yml 的典型 cmd 路由
/// 4. 验证 template-transform + variable-aggregator + LLM 三类节点都能被核心消化
///
/// 这是 APK 打包后真正会运行的代码路径。
library;

import 'dart:convert' as _convert;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/condition_processor.dart';
import 'package:novel_app/services/dsl_engine/dsl_parser.dart';
import 'package:novel_app/services/dsl_engine/graph_engine.dart';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';
import 'package:novel_app/services/dsl_engine/models/variable_pool.dart';
import 'package:novel_app/services/dsl_engine/template_renderer.dart';

void main() {
  // 必须在 binding 初始化后才能注册 mock asset 通道
  TestWidgetsFlutterBinding.ensureInitialized();
  _MockAssetBundle.register();

  late DslParser parser;
  late TemplateRenderer renderer;

  setUp(() {
    parser = DslParser();
    renderer = TemplateRenderer();
  });

  group('从 assets/dsl/ 加载', () {
    test('creater.yml asset 加载成功', () async {
      final yaml = await rootBundle.loadString('assets/dsl/creater.yml');
      expect(yaml, isNotEmpty);
      expect(yaml, contains('workflow:'));
      expect(yaml, contains('graph:'));
      expect(yaml, contains('if-else'));
    });

    test('structured_info.yml asset 加载成功', () async {
      final yaml =
          await rootBundle.loadString('assets/dsl/structured_info.yml');
      expect(yaml, isNotEmpty);
      expect(yaml, contains('workflow:'));
      expect(yaml, contains('graph:'));
      expect(yaml, contains('llm'));
    });

    test('creater.yml 解析为完整 WorkflowGraph', () async {
      final yaml = await rootBundle.loadString('assets/dsl/creater.yml');
      final graph = parser.parseGraphConfig(yaml);

      // 实际是 23 个节点、30+ 边
      expect(graph.nodes.length, greaterThanOrEqualTo(20));
      expect(graph.edges.length, greaterThanOrEqualTo(20));

      // 必含 1 个 start / 至少 1 个 end / 至少 1 个 if-else / 至少 1 个 LLM
      expect(
        graph.nodes.where((n) => n.type == NodeType.start).length,
        1,
        reason: '应有 1 个 start 节点',
      );
      expect(
        graph.nodes.where((n) => n.type == NodeType.end).length,
        greaterThanOrEqualTo(1),
        reason: '至少 1 个 end 节点',
      );
      expect(
        graph.nodes.where((n) => n.type == NodeType.ifElse).length,
        greaterThanOrEqualTo(1),
        reason: '至少 1 个 if-else 节点',
      );
      expect(
        graph.nodes.where((n) => n.type == NodeType.llm).length,
        greaterThanOrEqualTo(1),
        reason: '至少 1 个 LLM 节点',
      );

      // 节点 ID 和 data 应非空
      final start = graph.nodes.firstWhere((n) => n.type == NodeType.start);
      expect(start.id, isNotEmpty);
      expect(start.data, isNotEmpty);
    });

    test('structured_info.yml 解析为完整 WorkflowGraph', () async {
      final yaml =
          await rootBundle.loadString('assets/dsl/structured_info.yml');
      final graph = parser.parseGraphConfig(yaml);

      // 应有多个节点和边
      expect(graph.nodes.length, greaterThanOrEqualTo(5));
      expect(graph.edges.length, greaterThanOrEqualTo(5));

      // 至少 1 个 LLM 节点
      expect(
        graph.nodes.where((n) => n.type == NodeType.llm).length,
        greaterThanOrEqualTo(1),
      );

      // 找一下带 structured_output 的 LLM 节点（核心能力）
      final llmNodes =
          graph.nodes.where((n) => n.type == NodeType.llm).toList();
      final hasStructuredOutput = llmNodes.any(
        (node) => node.data['structured_output_enabled'] == true,
      );
      expect(hasStructuredOutput, isTrue,
          reason: 'structured_info.yml 应有 LLM 节点带 structured_output');
    });
  });

  group('creater.yml 端到端执行（mock executor）', () {
    late String yaml;
    late WorkflowGraph graph;

    setUpAll(() async {
      yaml = await rootBundle.loadString('assets/dsl/creater.yml');
    });

    setUp(() {
      graph = parser.parseGraphConfig(yaml);
    });

    test('cmd=特写 → 走 false 兜底分支 → LLM 被调用 → end 输出', () async {
      final events = await _runCreater(graph, cmd: '特写');
      _expectSuccess(events);

      // if-else 应选 'false' 兜底
      _expectIfElseSelected(events, '1759151925879', 'false');

      // LLM 节点应被调用
      _expectLlmExecuted(events, '1759151715295');
    });

    test('cmd=总结 → 走 case d2112989-...-ce2e3245bff1', () async {
      final events = await _runCreater(graph, cmd: '总结');
      _expectSuccess(events);
      _expectIfElseSelected(
        events,
        '1759151925879',
        'd2112989-3424-433a-8ba6-ce2e3245bff1',
      );
      _expectLlmExecuted(events, '1759151715295');
    });

    test('cmd=聊天 → 走 case c414a0ea-...-4b79507e8dd7', () async {
      final events = await _runCreater(graph, cmd: '聊天');
      _expectSuccess(events);
      _expectIfElseSelected(
        events,
        '1759151925879',
        'c414a0ea-9287-453f-ba61-4b79507e8dd7',
      );
      _expectLlmExecuted(events, '1759151715295');
    });

    test('end 节点 outputs 收集到 content 字段', () async {
      final events = await _runCreater(graph, cmd: '总结');
      // 至少一个 end 节点产出了 output
      final endNodes =
          graph.nodes.where((n) => n.type == NodeType.end).toList();
      final endNodeIds = endNodes.map((e) => e.id).toSet();
      final endEvents = events
          .whereType<NodeRunSucceededEvent>()
          .where((e) => endNodeIds.contains(e.nodeId))
          .toList();
      expect(endEvents, isNotEmpty,
          reason: '至少一个 end 节点应被成功执行');
    });
  });

  group('structured_info.yml 端到端执行（mock executor）', () {
    late String yaml;
    late WorkflowGraph graph;

    setUpAll(() async {
      yaml = await rootBundle.loadString('assets/dsl/structured_info.yml');
    });

    setUp(() {
      graph = parser.parseGraphConfig(yaml);
    });

    test('cmd=生成 → 工作流能完整跑完（mock LLM）', () async {
      final events = await _runStructured(graph, cmd: '生成');
      expect(
        events.last,
        anyOf(
          isA<GraphRunSucceededEvent>(),
          isA<GraphRunPartialSucceededEvent>(),
        ),
      );
    });

    test('至少有一个 LLM 节点被调用到', () async {
      final events = await _runStructured(graph, cmd: '生成');
      final llmEvents = events.whereType<NodeRunSucceededEvent>().where((e) {
        final node = graph.nodes.firstWhere(
          (n) => n.id == e.nodeId,
          orElse: () => DslNode(
            id: '',
            type: NodeType.unknown,
            title: '',
            data: const {},
          ),
        );
        return node.type == NodeType.llm;
      });
      expect(llmEvents, isNotEmpty,
          reason: 'structured_info.yml 应至少执行一个 LLM 节点');
    });
  });

  group('核心能力交叉验证', () {
    test('template-transform 节点能被解析 + 渲染', () async {
      final yaml = await rootBundle.loadString('assets/dsl/creater.yml');
      final graph = parser.parseGraphConfig(yaml);

      final tts = graph.nodes
          .where((n) => n.type == NodeType.templateTransform)
          .toList();
      expect(tts, isNotEmpty,
          reason: 'creater.yml 必有 template-transform 节点');

      // 找出一个有完整 template + variables 的节点来跑实际渲染
      final ttWithContent = tts.firstWhere(
        (n) =>
            n.data['template'] is String &&
            (n.data['template'] as String).isNotEmpty &&
            n.data['variables'] is List,
        orElse: () => tts.first,
      );
      final template = ttWithContent.data['template'] as String;
      final variables = (ttWithContent.data['variables'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

      // 注入桩数据：所有 value_selector 都给一个可解析的值
      final pool = VariablePool();
      for (final v in variables) {
        final selector = (v['value_selector'] as List?)
            ?.map((e) => e.toString())
            .toList();
        if (selector != null && selector.length == 2) {
          pool.add(selector, '测试值_${selector[1]}');
        }
      }

      String rendered;
      try {
        rendered = renderer.renderTemplateTransform(
          pool,
          template: template,
          variables: variables,
        );
      } catch (e) {
        fail('渲染失败: $e');
      }
      expect(rendered, isNotEmpty);
    });

    test('variable-aggregator 节点能被识别', () async {
      final yaml =
          await rootBundle.loadString('assets/dsl/structured_info.yml');
      final graph = parser.parseGraphConfig(yaml);
      final aggs = graph.nodes
          .where((n) => n.type == NodeType.variableAggregator)
          .toList();
      // 验证结构合法
      for (final agg in aggs) {
        final variables = agg.data['variables'];
        expect(variables, anyOf(isNull, isA<List>()));
      }
    });

    test('if-else 节点能正确解析 cases（含 contains / is / = 等算子）',
        () async {
      final yaml = await rootBundle.loadString('assets/dsl/creater.yml');
      final graph = parser.parseGraphConfig(yaml);
      final ifElse = graph.nodes.firstWhere((n) => n.type == NodeType.ifElse);

      final cases = parser.parseCases(ifElse.data['cases']);
      expect(cases, isNotEmpty);

      // 至少见到 1 个 contains 算子（creater.yml 用 contains 路由 cmd）
      final operators = cases
          .expand((c) => c.conditions.map((cond) => cond.comparisonOperator))
          .toSet();
      expect(operators, contains('contains'),
          reason: 'creater.yml 应包含 contains 算子的条件');
    });
  });
}

// ---------------------------------------------------------------------------
// 测试辅助
// ---------------------------------------------------------------------------

/// 跑 creater.yml 一个 cmd 场景，返回事件列表
Future<List<GraphEngineEvent>> _runCreater(
  WorkflowGraph graph, {
  required String cmd,
}) async {
  final pool = VariablePool();
  // creater.yml start 节点 ID = 1759138104711
  pool.add(['1759138104711', 'cmd'], cmd);
  pool.add(['1759138104711', 'user_input'], '写一段场景描写');
  pool.add(['1759138104711', 'background_setting'], '古代王朝');
  pool.add(['1759138104711', 'current_chapter_content'], '夕阳西下');
  pool.add(['1759138104711', 'history_chapters_content'], '');
  pool.add(['1759138104711', 'next_chapter_overview'], '');
  pool.add(['1759138104711', 'ai_writer_setting'], '');
  pool.add(['1759138104711', 'roles'], '');
  pool.add(['1759138104711', 'choice_content'], '');
  pool.add(['1759138104711', 'outline'], '');
  pool.add(['1759138104711', 'outline_item'], '');
  pool.add(['1759138104711', 'scene'], '');
  pool.add(['1759138104711', 'chat_history'], '');

  final engine = GraphEngine(
    graph: graph,
    variablePool: pool,
    nodeExecutor: _buildMockExecutor(),
  );
  return await engine.run().toList();
}

/// 跑 structured_info.yml 一个 cmd 场景
Future<List<GraphEngineEvent>> _runStructured(
  WorkflowGraph graph, {
  required String cmd,
}) async {
  final pool = VariablePool();

  // 找到 start 节点，注入 cmd
  final start = graph.rootNode;
  if (start == null) {
    throw StateError('structured_info.yml 没有 start 节点');
  }

  // 把 start 节点声明的所有 inputs 都注入
  final inputs = start.data['variables'];
  if (inputs is List) {
    for (final v in inputs) {
      if (v is! Map) continue;
      final name = v['variable']?.toString();
      if (name == null) continue;
      // cmd 用我们传的，其他用空字符串
      final value = name == 'cmd' ? cmd : '';
      pool.add([start.id, name], value);
    }
  }

  final engine = GraphEngine(
    graph: graph,
    variablePool: pool,
    nodeExecutor: _buildMockExecutor(),
  );
  return await engine.run().toList();
}

/// 构造一个能处理所有 6 种节点类型的 mock executor
NodeExecutorFn _buildMockExecutor() {
  return (DslNode node, VariablePool pool) async {
    switch (node.type) {
      case NodeType.start:
        return NodeRunResult(
          nodeId: node.id,
          status: NodeExecutionStatus.succeeded,
          outputs: const {},
        );
      case NodeType.end:
        return NodeRunResult(
          nodeId: node.id,
          status: NodeExecutionStatus.succeeded,
          outputs: {'content': 'mock end output'},
        );
      case NodeType.ifElse:
        return _execIfElse(node, pool);
      case NodeType.templateTransform:
        return _execTemplateTransform(node, pool);
      case NodeType.variableAggregator:
        return _execVariableAggregator(node, pool);
      case NodeType.llm:
        return _execLlm(node, pool);
      case NodeType.unknown:
        return NodeRunResult(
          nodeId: node.id,
          status: NodeExecutionStatus.succeeded,
          outputs: const {'output': 'unknown stub'},
        );
    }
  };
}

NodeRunResult _execIfElse(DslNode node, VariablePool pool) {
  final cases = DslParser().parseCases(node.data['cases']);
  final processor = ConditionProcessor();
  for (final c in cases) {
    final r = processor.processConditions(
      variablePool: pool,
      conditions: c.conditions,
      operator: c.logicalOperator,
    );
    if (r.finalResult) {
      return NodeRunResult(
        nodeId: node.id,
        status: NodeExecutionStatus.succeeded,
        selectedHandle: c.caseId,
        outputs: {'selected_case_id': c.caseId},
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

NodeRunResult _execTemplateTransform(DslNode node, VariablePool pool) {
  final renderer = TemplateRenderer();
  final template = node.data['template']?.toString() ?? '';
  final variablesRaw = node.data['variables'];

  String result;
  if (variablesRaw is List && variablesRaw.isNotEmpty) {
    try {
      result = renderer.renderTemplateTransform(
        pool,
        template: template,
        variables: variablesRaw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList(),
      );
    } catch (_) {
      result = '';
    }
  } else {
    result = renderer.convertTemplate(pool, template);
  }
  return NodeRunResult(
    nodeId: node.id,
    status: NodeExecutionStatus.succeeded,
    outputs: {'output': result},
  );
}

NodeRunResult _execVariableAggregator(DslNode node, VariablePool pool) {
  final variables = node.data['variables'];
  if (variables is List) {
    for (final v in variables) {
      if (v is! Map) continue;
      final selector = v['value_selector'];
      if (selector is! List) continue;
      final path = selector.map((e) => e.toString()).toList();
      final seg = pool.get(path);
      if (seg != null) {
        final obj = seg.toObject();
        if (obj != null && obj.toString().isNotEmpty) {
          return NodeRunResult(
            nodeId: node.id,
            status: NodeExecutionStatus.succeeded,
            outputs: {'output': obj},
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

NodeRunResult _execLlm(DslNode node, VariablePool pool) {
  // Mock：直接给一个固定文本，验证引擎能消化 LLM 节点的输出
  return NodeRunResult(
    nodeId: node.id,
    status: NodeExecutionStatus.succeeded,
    outputs: {
      'text': '【mock LLM】已处理节点 ${node.id}',
    },
  );
}

// -- 断言辅助 --

void _expectSuccess(List<GraphEngineEvent> events) {
  expect(events.first, isA<GraphRunStartedEvent>());
  expect(
    events.last,
    anyOf(
      isA<GraphRunSucceededEvent>(),
      isA<GraphRunPartialSucceededEvent>(),
    ),
    reason: '工作流应以成功/部分成功结束，未抛 failed',
  );
}

void _expectIfElseSelected(
  List<GraphEngineEvent> events,
  String nodeId,
  String expectedHandle,
) {
  final hits = events
      .whereType<NodeRunSucceededEvent>()
      .where((e) => e.nodeId == nodeId)
      .toList();
  expect(hits, hasLength(1), reason: 'if-else 节点 $nodeId 应执行一次');
  expect(hits.first.selectedHandle, expectedHandle,
      reason: 'if-else 节点 $nodeId 选中的 handle 错误');
}

void _expectLlmExecuted(
  List<GraphEngineEvent> events,
  String nodeId,
) {
  final hits = events
      .whereType<NodeRunSucceededEvent>()
      .where((e) => e.nodeId == nodeId)
      .toList();
  expect(hits, hasLength(1), reason: 'LLM 节点 $nodeId 应执行一次');
  expect(hits.first.outputs, containsPair('text', isNotNull),
      reason: 'LLM 节点应产出 text 字段');
}

// ---------------------------------------------------------------------------
// Mock Asset Bundle
// ---------------------------------------------------------------------------

/// 把 rootBundle 的 asset 读取重定向到磁盘 fixture 文件
///
/// 真实 APK 启动时 Flutter 会从打包的 asset 读取；
/// 测试环境通过 [TestDefaultBinaryMessenger] 拦截 'flutter/assets' 通道，
/// 让 'assets/dsl/creater.yml' 这样的路径直接读 test/fixtures/creater.yml。
class _MockAssetBundle {
  static const Map<String, String> _assetToFile = {
    'assets/dsl/creater.yml': 'test/fixtures/creater.yml',
    'assets/dsl/structured_info.yml': 'test/fixtures/structured_info.yml',
  };

  static void register() {
    // [TestDefaultBinaryMessenger] 会在 TestWidgetsFlutterBinding 初始化后可用
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (ByteData? message) async {
      final key = message != null ? _convert.utf8.decode(message.buffer.asUint8List()) : '';
      final filePath = _assetToFile[key];
      if (filePath == null) {
        // 不认识的 asset key → 返回 null 让 rootBundle 抛 'unable to load asset'
        return null;
      }
      final file = File(filePath);
      if (!file.existsSync()) {
        throw StateError('Mock asset 文件不存在: $filePath');
      }
      final content = file.readAsStringSync();
      return ByteData.view(
        Uint8List.fromList(_convert.utf8.encode(content)).buffer,
      );
    });
  }
}
