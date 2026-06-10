/// DSL 解析器单元测试
///
/// 用 creater.yml 和 structured_info.yml 作为 fixture 测试 YAML → Graph 解析。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/dsl_parser.dart';
import 'package:novel_app/services/dsl_engine/models/models.dart';

void main() {
  group('DslParser.parseGraphConfig', () {
    late DslParser parser;

    setUp(() {
      parser = DslParser();
    });

    test('解析 creater.yml 不抛错', () {
      final yaml = File('test/fixtures/creater.yml').readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);
      expect(graph, isNotNull);
    });

    test('解析 structured_info.yml 不抛错', () {
      final yaml =
          File('test/fixtures/structured_info.yml').readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);
      expect(graph, isNotNull);
    });

    test('creater.yml 节点数量正确', () {
      final yaml = File('test/fixtures/creater.yml').readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);
      // start(1) + end(1) + if-else(3) + template-transform(14) + variable-aggregator(3) + llm(1) = 23
      expect(graph.nodes.length, greaterThanOrEqualTo(20));
    });

    test('creater.yml 边数量大于节点数量（DAG）', () {
      final yaml = File('test/fixtures/creater.yml').readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);
      expect(graph.edges.length, greaterThanOrEqualTo(graph.nodes.length));
    });

    test('有且仅有一个 start 节点', () {
      final yaml = File('test/fixtures/creater.yml').readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);
      final starts =
          graph.nodes.where((n) => n.type == NodeType.start).toList();
      expect(starts.length, 1);
    });

    test('有且仅有一个 end 节点', () {
      final yaml = File('test/fixtures/creater.yml').readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);
      final ends = graph.nodes.where((n) => n.type == NodeType.end).toList();
      expect(ends.length, 1);
    });

    test('start 节点有 variables 列表', () {
      final yaml = File('test/fixtures/creater.yml').readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);
      final start = graph.nodes.firstWhere((n) => n.type == NodeType.start);
      expect(start.data, isNotNull);
      expect(start.data!['variables'], isA<List>());
      expect((start.data!['variables'] as List).length, greaterThanOrEqualTo(7));
    });

    test('if-else 节点有 cases', () {
      final yaml = File('test/fixtures/creater.yml').readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);
      final ifElseNodes =
          graph.nodes.where((n) => n.type == NodeType.ifElse).toList();
      expect(ifElseNodes.length, greaterThanOrEqualTo(1));
      for (final node in ifElseNodes) {
        expect(node.data, isNotNull);
        // cases or conditions
        expect(
          node.data!.containsKey('cases') ||
              node.data!.containsKey('conditions'),
          isTrue,
        );
      }
    });

    test('llm 节点有 model 和 prompt_template', () {
      final yaml = File('test/fixtures/creater.yml').readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);
      final llmNodes =
          graph.nodes.where((n) => n.type == NodeType.llm).toList();
      expect(llmNodes.length, greaterThanOrEqualTo(1));
      for (final node in llmNodes) {
        expect(node.data, isNotNull);
        expect(node.data!.containsKey('model'), isTrue);
        expect(node.data!.containsKey('prompt_template'), isTrue);
      }
    });

    test('template-transform 节点有 template 和 variables', () {
      final yaml = File('test/fixtures/creater.yml').readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);
      final ttNodes = graph.nodes
          .where((n) => n.type == NodeType.templateTransform)
          .toList();
      expect(ttNodes.length, greaterThanOrEqualTo(1));
      for (final node in ttNodes) {
        expect(node.data, isNotNull);
        expect(node.data!.containsKey('template'), isTrue);
        expect(node.data!.containsKey('variables'), isTrue);
      }
    });

    test('variable-aggregator 节点有 variables', () {
      final yaml = File('test/fixtures/creater.yml').readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);
      final vaNodes = graph.nodes
          .where((n) => n.type == NodeType.variableAggregator)
          .toList();
      expect(vaNodes.length, greaterThanOrEqualTo(1));
      for (final node in vaNodes) {
        expect(node.data, isNotNull);
        expect(node.data!.containsKey('variables'), isTrue);
      }
    });

    test('edge 的 sourceHandle 标识分支目标', () {
      final yaml = File('test/fixtures/creater.yml').readAsStringSync();
      final graph = parser.parseGraphConfig(yaml);
      // 至少有一条 if-else 出边用 case_id 作为 sourceHandle
      final ifElseIds = graph.nodes
          .where((n) => n.type == NodeType.ifElse)
          .map((n) => n.id)
          .toSet();
      final branchEdges =
          graph.edges.where((e) => ifElseIds.contains(e.source)).toList();
      expect(branchEdges.length, greaterThanOrEqualTo(2));
      // 至少一条 sourceHandle 不是 'source'
      expect(
        branchEdges.any((e) => e.sourceHandle != 'source'),
        isTrue,
      );
    });

    test('空 YAML 抛错', () {
      expect(
        () => parser.parseGraphConfig(''),
        throwsA(isA<DslParseError>()),
      );
    });

    test('无效 YAML（无 graph 键）抛错', () {
      expect(
        () => parser.parseGraphConfig('app:\n  name: test\n'),
        throwsA(isA<DslParseError>()),
      );
    });
  });

  group('DslParser.parseConditions', () {
    late DslParser parser;

    setUp(() {
      parser = DslParser();
    });

    test('从 if-else cases 中提取 Condition 列表', () {
      final cases = [
        {
          'case_id': 'case1',
          'logical_operator': 'and',
          'conditions': [
            {
              'comparison_operator': 'is',
              'variable_selector': ['start', 'cmd'],
              'value': '总结',
            },
          ],
        },
      ];
      final result = parser.parseCases(cases);
      expect(result.length, 1);
      expect(result.first.caseId, 'case1');
      expect(result.first.logicalOperator, 'and');
      expect(result.first.conditions.length, 1);
      expect(result.first.conditions.first.comparisonOperator, 'is');
      expect(result.first.conditions.first.variableSelector, ['start', 'cmd']);
      expect(result.first.conditions.first.value, '总结');
    });

    test('多个 case 正确解析', () {
      final cases = [
        {
          'case_id': 'case_a',
          'logical_operator': 'and',
          'conditions': [
            {
              'comparison_operator': 'contains',
              'variable_selector': ['n1', 'v1'],
              'value': 'hello',
            },
          ],
        },
        {
          'case_id': 'case_b',
          'logical_operator': 'or',
          'conditions': [
            {
              'comparison_operator': '=',
              'variable_selector': ['n1', 'v2'],
              'value': '42',
            },
          ],
        },
      ];
      final result = parser.parseCases(cases);
      expect(result.length, 2);
      expect(result[0].caseId, 'case_a');
      expect(result[1].caseId, 'case_b');
    });
  });
}
