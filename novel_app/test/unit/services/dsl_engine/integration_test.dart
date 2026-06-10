/// 集成测试：完整工作流 E2E
///
/// 用 creater.yml + mock LLM Provider 验证整个 DSL 引擎的端到端执行：
/// 1. 解析 DSL → Graph
/// 2. 注入 user inputs → start 节点
/// 3. if-else 条件路由
/// 4. template-transform 模板渲染
/// 5. variable-aggregator 聚合
/// 6. LLM 节点（mock）→ end 节点输出
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/condition_processor.dart';
import 'package:novel_app/services/dsl_engine/dsl_parser.dart';
import 'package:novel_app/services/dsl_engine/graph_engine.dart';
import 'package:novel_app/services/dsl_engine/llm_provider.dart';
import 'package:novel_app/services/dsl_engine/models/variable_pool.dart';
import 'package:novel_app/services/dsl_engine/template_renderer.dart';

void main() {
  late DslParser parser;
  late TemplateRenderer renderer;

  setUp(() {
    parser = DslParser();
    renderer = TemplateRenderer();
  });

  group('creater.yml E2E', () {
    late String yaml;
    late WorkflowGraph graph;

    setUpAll(() {
      yaml = File('test/fixtures/creater.yml').readAsStringSync();
    });

    test('解析成功', () {
      graph = parser.parseGraphConfig(yaml);
      expect(graph.nodes.length, greaterThan(10));
      expect(graph.edges.length, greaterThan(10));
    });

    test('cmd=特写（不匹配任何 case）→ if-else fallback 到 false 分支 → 工作流完成', () async {
      graph = parser.parseGraphConfig(yaml);
      final pool = VariablePool();

      // 注入 start 节点变量
      pool.add(['1759138104711', 'cmd'], '特写');
      pool.add(['1759138104711', 'user_input'], '描写日落场景');
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
        nodeExecutor: _createrRealExecutor,
      );

      final events = await engine.run().toList();

      // 应该有 started + succeeded
      expect(events.first, isA<GraphRunStartedEvent>());
      expect(
        events.last,
        anyOf(isA<GraphRunSucceededEvent>(), isA<GraphRunPartialSucceededEvent>()),
      );

      // if-else 选 false（fallback）
      final ifElseEvents = events
          .whereType<NodeRunSucceededEvent>()
          .where((e) => e.nodeId == '1759151925879');
      expect(ifElseEvents.length, 1);
      expect(ifElseEvents.first.selectedHandle, 'false');

      // LLM 节点应被执行
      final llmEvents = events
          .whereType<NodeRunSucceededEvent>()
          .where((e) => e.nodeId == '1759151715295');
      expect(llmEvents.length, 1);
      expect(llmEvents.first.outputs, contains('text'));
    });

    test('cmd=总结 → if-else 选总结 case → 走 summary template 路径', () async {
      graph = parser.parseGraphConfig(yaml);
      final pool = VariablePool();

      pool.add(['1759138104711', 'cmd'], '总结');
      pool.add(['1759138104711', 'user_input'], '');
      pool.add(['1759138104711', 'background_setting'], '');
      pool.add(['1759138104711', 'current_chapter_content'], '内容');
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
        nodeExecutor: _createrRealExecutor,
      );

      final events = await engine.run().toList();
      expect(events.first, isA<GraphRunStartedEvent>());

      // 总结模式的 case_id 是 d2112989-3424-433a-8ba6-ce2e3245bff1
      final ifElseEvents = events
          .whereType<NodeRunSucceededEvent>()
          .where((e) => e.nodeId == '1759151925879');
      expect(ifElseEvents.length, 1);
      expect(ifElseEvents.first.selectedHandle,
          'd2112989-3424-433a-8ba6-ce2e3245bff1');

      // LLM 节点应被执行
      final llmEvents = events
          .whereType<NodeRunSucceededEvent>()
          .where((e) => e.nodeId == '1759151715295');
      expect(llmEvents.length, 1);
      expect(llmEvents.first.outputs, contains('text'));
    });

    test('cmd=聊天 → if-else 选聊天 case', () async {
      graph = parser.parseGraphConfig(yaml);
      final pool = VariablePool();

      pool.add(['1759138104711', 'cmd'], '聊天');
      pool.add(['1759138104711', 'user_input'], '');
      pool.add(['1759138104711', 'background_setting'], '');
      pool.add(['1759138104711', 'current_chapter_content'], '内容');
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
        nodeExecutor: _createrRealExecutor,
      );

      final events = await engine.run().toList();
      final ifElseEvents = events
          .whereType<NodeRunSucceededEvent>()
          .where((e) => e.nodeId == '1759151925879');
      expect(ifElseEvents.length, 1);
      // 聊天 case_id 是 c414a0ea-9287-453f-ba61-4b79507e8dd7
      expect(ifElseEvents.first.selectedHandle,
          'c414a0ea-9287-453f-ba61-4b79507e8dd7');
    });
  });

  group('structured_info.yml E2E', () {
    test('解析成功', () {
      final yaml =
          File('test/fixtures/structured_info.yml').readAsStringSync();
      final dslGraph = parser.parseGraphConfig(yaml);
      expect(dslGraph.nodes.length, greaterThan(5));
    });
  });

  group('模板渲染集成', () {
    test('template-transform 节点实际渲染：使用 convertTemplate + Jinja2', () {
      final pool = VariablePool();
      pool.add(['start', 'setting'], 'AI写手设定');
      pool.add(['start', 'background'], '古代王朝');
      pool.add(['start', 'content'], '当前章节内容');

      // 模拟 creater.yml 中"正常撰写" template-transform 节点
      final result = renderer.renderTemplateTransform(
        pool,
        template: '设定：{{ setting }}\n背景：{{ background }}\n内容：{{ content }}',
        variables: [
          {
            'variable': 'setting',
            'value_selector': ['start', 'setting'],
          },
          {
            'variable': 'background',
            'value_selector': ['start', 'background'],
          },
          {
            'variable': 'content',
            'value_selector': ['start', 'content'],
          },
        ],
      );

      expect(result, contains('AI写手设定'));
      expect(result, contains('古代王朝'));
      expect(result, contains('当前章节内容'));
    });
  });
}

/// 完整的 creater.yml 节点执行器
///
/// 根据节点类型执行实际逻辑：
/// - start: 已在 pool 中注入
/// - end: 收集输出
/// - if-else: 评估条件
/// - template-transform: 渲染模板
/// - variable-aggregator: 聚合变量
/// - llm: mock 返回
Future<NodeRunResult> _createrRealExecutor(DslNode node, VariablePool pool) async {
  final renderer = TemplateRenderer();

  switch (node.type) {
    case NodeType.start:
      // start 节点已经在 pool 中注入了，直接成功
      return NodeRunResult(
        nodeId: node.id,
        status: NodeExecutionStatus.succeeded,
        outputs: {},
      );

    case NodeType.end:
      // 从 outputs 配置中提取
      final outputs = node.data['outputs'] as List?;
      final result = <String, dynamic>{};
      if (outputs != null) {
        for (final out in outputs) {
          if (out is Map<String, dynamic>) {
            final varName = out['variable']?.toString() ?? '';
            final selector = out['value_selector'] as List?;
            if (varName.isNotEmpty && selector != null) {
              final path = selector.map((e) => e.toString()).toList();
              final segment = pool.get(path);
              result[varName] = segment?.toObject() ?? '';
            }
          }
        }
      }
      return NodeRunResult(
        nodeId: node.id,
        status: NodeExecutionStatus.succeeded,
        outputs: result,
      );

    case NodeType.ifElse:
      return _executeIfElse(node, pool);

    case NodeType.templateTransform:
      return _executeTemplateTransform(node, pool, renderer);

    case NodeType.variableAggregator:
      return _executeVariableAggregator(node, pool);

    case NodeType.llm:
      return _executeLlm(node, pool, renderer);

    default:
      return NodeRunResult(
        nodeId: node.id,
        status: NodeExecutionStatus.succeeded,
        outputs: {'output': ''},
      );
  }
}

NodeRunResult _executeIfElse(DslNode node, VariablePool pool) {
  final processor = ConditionProcessor();
  final casesRaw = node.data['cases'];
  final cases = DslParser().parseCases(casesRaw);

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
        outputs: {'result': true, 'selected_case_id': caseData.caseId},
      );
    }
  }

  // 兜底：返回 false 分支
  return NodeRunResult(
    nodeId: node.id,
    status: NodeExecutionStatus.succeeded,
    selectedHandle: 'false',
    outputs: {'result': false, 'selected_case_id': 'false'},
  );
}

NodeRunResult _executeTemplateTransform(
    DslNode node, VariablePool pool, TemplateRenderer renderer) {
  final template = node.data['template']?.toString() ?? '';
  final variables = node.data['variables'] as List?;

  if (template.isEmpty) {
    return NodeRunResult(
      nodeId: node.id,
      status: NodeExecutionStatus.succeeded,
      outputs: {'output': ''},
    );
  }

  String result;
  if (variables is List && variables.isNotEmpty) {
    result = renderer.renderTemplateTransform(
      pool,
      template: template,
      variables: variables.cast<Map<String, dynamic>>(),
    );
  } else {
    // 无 variables 列表，直接 convertTemplate
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
  final isAdvanced = node.data['advanced_settings']?['group_enabled'] == true;

  if (isAdvanced) {
    // 高级模式：按 group 聚合（本项目未使用，简单处理）
    final result = <String, dynamic>{};
    if (variables != null) {
      for (final v in variables) {
        if (v is! Map) continue;
        final selector = v['value_selector'] as List?;
        if (selector == null) continue;
        final path = selector.map((e) => e.toString()).toList();
        final segment = pool.get(path);
        if (segment != null) {
          result['output'] = segment.toObject();
          break;
        }
      }
    }
    return NodeRunResult(
      nodeId: node.id,
      status: NodeExecutionStatus.succeeded,
      outputs: result.isNotEmpty ? result : {'output': ''},
    );
  }

  // 简单模式：取第一个非空值
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

NodeRunResult _executeLlm(
    DslNode node, VariablePool pool, TemplateRenderer renderer) {
  // Mock LLM：不实际调用 API，直接返回模板渲染结果
  final promptTemplate = node.data['prompt_template'] as List?;

  // 推断 edition_type: 从 prompt_template 最后一项中查找
  String editionType = 'basic';
  if (promptTemplate is List && promptTemplate.isNotEmpty) {
    final last = promptTemplate.last;
    if (last is Map) {
      editionType = (last['edition_type'] as String?) ?? 'basic';
    }
  }

  // 构建 messages
  final messages = <ChatMessage>[];
  if (promptTemplate is List) {
    for (final p in promptTemplate) {
      if (p is! Map) continue;
      final role = p['role']?.toString() ?? 'user';
      String content;

      if (editionType == 'jinja2' && p.containsKey('jinja2_text')) {
        final jinja2Text = p['jinja2_text']?.toString() ?? '';
        final jinja2VarsRaw = node.data['prompt_config']?['jinja2_variables'];
        final jinja2Vars = jinja2VarsRaw is List ? jinja2VarsRaw : <Map<String, dynamic>>[];
        content = renderer.renderTemplateWithJinja(
          pool,
          jinja2Text,
          jinja2Vars.cast<Map<String, dynamic>>(),
        );
      } else {
        final text = p['text']?.toString() ?? '';
        content = renderer.convertTemplate(pool, text);
      }

      messages.add(ChatMessage(role: role, content: content));
    }
  }

  // Mock: 返回最后一条消息内容（实际应调用 LLM API）
  final mockResponse = messages.isNotEmpty
      ? messages.map((m) => m.content).join('\n')
      : 'mock LLM response';

  return NodeRunResult(
    nodeId: node.id,
    status: NodeExecutionStatus.succeeded,
    outputs: {'text': mockResponse},
  );
}
