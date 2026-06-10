/// GraphEngine 单元测试
///
/// 验证队列式状态机的核心语义：
/// 1. 节点就绪判断（isNodeReady）
/// 2. 边状态管理（UNKNOWN/TAKEN/SKIPPED）
/// 3. 分支节点处理（if-else → selected_handle → downstream）
/// 4. Skip 传播（未选分支的下游递归 SKIPPED）
/// 5. 完整工作流执行（linear + branching）
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/condition_processor.dart';
import 'package:novel_app/services/dsl_engine/dsl_parser.dart';
import 'package:novel_app/services/dsl_engine/graph_engine.dart';
import 'package:novel_app/services/dsl_engine/models/variable_pool.dart';

void main() {
  group('GraphStateManager', () {
    late GraphStateManager sm;
    late WorkflowGraph graph;

    setUp(() {
      // 构造一个简单 DAG: start → ifElse → tt1 / tt2 → end
      graph = _buildSimpleBranchGraph();
      sm = GraphStateManager(graph);
    });

    test('初始状态所有边为 UNKNOWN', () {
      for (final edge in graph.edges) {
        expect(sm.getEdgeState(edge.id), EdgeState.unknown);
      }
    });

    test('isNodeReady: 无入边节点 → true', () {
      // start 节点没有入边
      expect(sm.isNodeReady('start'), isTrue);
    });

    test('isNodeReady: 入边 UNKNOWN → false', () {
      // ifElse 有入边 start→ifElse，初始 UNKNOWN
      expect(sm.isNodeReady('ifElse'), isFalse);
    });

    test('isNodeReady: 入边 TAKEN → true', () {
      sm.markEdgeTaken('start_ifElse');
      expect(sm.isNodeReady('ifElse'), isTrue);
    });

    test('isNodeReady: 入边 SKIPPED → false', () {
      sm.markEdgeSkipped('start_ifElse');
      expect(sm.isNodeReady('ifElse'), isFalse);
    });

    test('isNodeReady: 多条入边，至少一条 TAKEN → true', () {
      // end 有两条入边（tt1→end, tt2→end）
      sm.markEdgeTaken('tt1_end');
      sm.markEdgeSkipped('tt2_end');
      expect(sm.isNodeReady('end'), isTrue);
    });

    test('isNodeReady: 多条入边，全是 SKIPPED → false', () {
      sm.markEdgeSkipped('tt1_end');
      sm.markEdgeSkipped('tt2_end');
      expect(sm.isNodeReady('end'), isFalse);
    });
  });

  group('EdgeProcessor + SkipPropagator', () {
    late GraphStateManager sm;
    late EdgeProcessor ep;
    late SkipPropagator sp;
    late WorkflowGraph graph;

    setUp(() {
      graph = _buildSimpleBranchGraph();
      sm = GraphStateManager(graph);
      sp = SkipPropagator(graph, sm);
      ep = EdgeProcessor(graph, sm, sp);
    });

    test('非分支节点成功 → 所有出边 TAKEN + 下游就绪', () {
      final readyNodes = ep.processNonBranchNodeEdges('start');
      expect(readyNodes, contains('ifElse'));
      expect(sm.getEdgeState('start_ifElse'), EdgeState.taken);
    });

    test('分支节点成功 + selected_handle → 选中边 TAKEN, 未选中边 SKIPPED', () {
      // 先让 start→ifElse TAKEN
      sm.markEdgeTaken('start_ifElse');

      // if-else 选 case1
      final readyNodes = ep.handleBranchCompletion('ifElse', 'case1');
      expect(sm.getEdgeState('ifElse_tt1'), EdgeState.taken);
      expect(sm.getEdgeState('ifElse_tt2'), EdgeState.skipped);
      expect(readyNodes, contains('tt1'));
    });

    test('Skip 传播: 未选分支下游被递归 SKIPPED', () {
      sm.markEdgeTaken('start_ifElse');
      ep.handleBranchCompletion('ifElse', 'case1');

      // tt2 及其出边 tt2→end 都应该 SKIPPED
      expect(sm.getNodeState('tt2'), NodeState.skipped);
      expect(sm.getEdgeState('tt2_end'), EdgeState.skipped);
    });

    test('多入边节点: 一条 SKIPPED 但另一条 TAKEN → 仍然就绪', () {
      sm.markEdgeTaken('start_ifElse');
      // 选 case1 → tt1 TAKEN, tt2 SKIPPED
      ep.handleBranchCompletion('ifElse', 'case1');
      // tt1→end TAKEN
      sm.markEdgeTaken('tt1_end');
      // tt2→end 已被 SKIPPED
      // end 有一条 TAKEN → 就绪
      expect(sm.isNodeReady('end'), isTrue);
    });
  });

  group('GraphEngine 完整工作流执行', () {
    test('线性 DAG: start → tt → end', () async {
      final graph = _buildLinearGraph();
      final pool = VariablePool();
      pool.add(['start', 'user_input'], 'hello');

      final engine = GraphEngine(
        graph: graph,
        variablePool: pool,
        nodeExecutor: _stubNodeExecutor,
      );

      final events = await engine.run().toList();
      expect(events.first, isA<GraphRunStartedEvent>());
      expect(events.last, isA<GraphRunSucceededEvent>());
    });

    test('分支 DAG: start → ifElse → tt1 / tt2 → end', () async {
      final graph = _buildSimpleBranchGraph();
      final pool = VariablePool();
      pool.add(['start', 'cmd'], '特写');

      final engine = GraphEngine(
        graph: graph,
        variablePool: pool,
        nodeExecutor: _branchingNodeExecutor,
      );

      final events = await engine.run().toList();
      expect(events.first, isA<GraphRunStartedEvent>());
      expect(events.last, isA<GraphRunSucceededEvent>());

      // 验证 if-else 选择了 'case1'
      final ifElseResult = events
          .whereType<NodeRunSucceededEvent>()
          .firstWhere((e) => e.nodeId == 'ifElse');
      expect(ifElseResult.selectedHandle, 'case1');
    });

    test('解析 creater.yml 并执行 (stub executor)', () async {
      final yaml = File('test/fixtures/creater.yml').readAsStringSync();
      final parser = DslParser();
      final dslGraph = parser.parseGraphConfig(yaml);

      final pool = VariablePool();
      // 注入 start 节点的 inputs
      pool.add(['1759138104711', 'cmd'], '特写');
      pool.add(['1759138104711', 'user_input'], '写一段场景描写');

      final engine = GraphEngine(
        graph: dslGraph,
        variablePool: pool,
        nodeExecutor: _createrStubExecutor,
      );

      final events = await engine.run().toList();
      // 应能完成整个流程
      expect(events.first, isA<GraphRunStartedEvent>());
      // 有 succeeded 或 partialSucceeded 事件
      expect(
        events.last,
        anyOf(isA<GraphRunSucceededEvent>(), isA<GraphRunPartialSucceededEvent>()),
      );
    });
  });
}

// -- 测试辅助 --

/// 线性图: start → tt → end
WorkflowGraph _buildLinearGraph() {
  return WorkflowGraph(
    nodes: [
      DslNode(id: 'start', type: NodeType.start, title: '开始', data: {}),
      DslNode(
          id: 'tt', type: NodeType.templateTransform, title: '模板', data: {}),
      DslNode(id: 'end', type: NodeType.end, title: '结束', data: {}),
    ],
    edges: [
      DslEdge(
          id: 'start_tt',
          source: 'start',
          target: 'tt',
          sourceHandle: 'source',
          targetHandle: 'target'),
      DslEdge(
          id: 'tt_end',
          source: 'tt',
          target: 'end',
          sourceHandle: 'source',
          targetHandle: 'target'),
    ],
  );
}

/// 分支图: start → ifElse(case1→tt1, false→tt2) → end
WorkflowGraph _buildSimpleBranchGraph() {
  return WorkflowGraph(
    nodes: [
      DslNode(id: 'start', type: NodeType.start, title: '开始', data: {}),
      DslNode(id: 'ifElse', type: NodeType.ifElse, title: '条件', data: {
        'cases': [
          {
            'case_id': 'case1',
            'logical_operator': 'and',
            'conditions': [
              {
                'comparison_operator': 'contains',
                'variable_selector': ['start', 'cmd'],
                'value': '特写',
              },
            ],
          },
        ],
      }),
      DslNode(
          id: 'tt1',
          type: NodeType.templateTransform,
          title: '模板1',
          data: {}),
      DslNode(
          id: 'tt2',
          type: NodeType.templateTransform,
          title: '模板2',
          data: {}),
      DslNode(id: 'end', type: NodeType.end, title: '结束', data: {}),
    ],
    edges: [
      DslEdge(
          id: 'start_ifElse',
          source: 'start',
          target: 'ifElse',
          sourceHandle: 'source',
          targetHandle: 'target'),
      DslEdge(
          id: 'ifElse_tt1',
          source: 'ifElse',
          target: 'tt1',
          sourceHandle: 'case1',
          targetHandle: 'target'),
      DslEdge(
          id: 'ifElse_tt2',
          source: 'ifElse',
          target: 'tt2',
          sourceHandle: 'false',
          targetHandle: 'target'),
      DslEdge(
          id: 'tt1_end',
          source: 'tt1',
          target: 'end',
          sourceHandle: 'source',
          targetHandle: 'target'),
      DslEdge(
          id: 'tt2_end',
          source: 'tt2',
          target: 'end',
          sourceHandle: 'source',
          targetHandle: 'target'),
    ],
  );
}

/// Stub executor: 所有节点直接成功
Future<NodeRunResult> _stubNodeExecutor(
  DslNode node,
  VariablePool pool,
) async {
  if (node.type == NodeType.end) {
    return NodeRunResult(
      nodeId: node.id,
      status: NodeExecutionStatus.succeeded,
      outputs: {'content': 'done'},
    );
  }
  return NodeRunResult(
    nodeId: node.id,
    status: NodeExecutionStatus.succeeded,
    outputs: {'output': 'stub'},
  );
}

/// 分支 executor: if-else 评估条件
Future<NodeRunResult> _branchingNodeExecutor(
  DslNode node,
  VariablePool pool,
) async {
  if (node.type == NodeType.ifElse) {
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
          outputs: {'result': true, 'selected_case_id': caseData.caseId},
        );
      }
    }
    // 无匹配
    return NodeRunResult(
      nodeId: node.id,
      status: NodeExecutionStatus.succeeded,
      selectedHandle: 'false',
      outputs: {'result': false, 'selected_case_id': 'false'},
    );
  }
  return _stubNodeExecutor(node, pool);
}

/// creater.yml stub executor
Future<NodeRunResult> _createrStubExecutor(DslNode node, VariablePool pool) async {
  if (node.type == NodeType.ifElse) {
    return _branchingNodeExecutor(node, pool);
  }
  if (node.type == NodeType.end) {
    return NodeRunResult(
      nodeId: node.id,
      status: NodeExecutionStatus.succeeded,
      outputs: {'content': 'done'},
    );
  }
  // 所有其他节点输出 stub
  return NodeRunResult(
    nodeId: node.id,
    status: NodeExecutionStatus.succeeded,
    outputs: {'output': 'stub'},
  );
}