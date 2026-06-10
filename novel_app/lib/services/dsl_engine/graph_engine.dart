/// GraphEngine：DSL 引擎的队列式状态机执行引擎
///
/// 忠实复现 Dify graphon/graph_engine 的核心语义：
/// - 节点就绪判断：所有入边已确定 AND 至少一条 TAKEN
/// - 边状态管理：UNKNOWN / TAKEN / SKIPPED
/// - 分支节点处理：selected_handle → 选中边 TAKEN，未选边 SKIPPED
/// - Skip 传播：未选分支的下游递归 SKIPPED
/// - 事件流：GraphRunStarted → NodeRunSucceeded × N → GraphRunSucceeded
///
/// Dart 单线程简化：不需要 threading/worker_pool，用 async/await 即可。
library;

import 'package:novel_app/services/dsl_engine/dsl_parser.dart';
import 'package:novel_app/services/dsl_engine/models/variable_pool.dart';
import 'package:novel_app/services/logger_service.dart';

// -- 边/节点状态枚举 --

enum EdgeState { unknown, taken, skipped }

enum NodeState { unknown, taken, skipped }

enum NodeExecutionStatus { succeeded, failed }

// -- 事件类型 --

sealed class GraphEngineEvent {}

class GraphRunStartedEvent extends GraphEngineEvent {}

class GraphRunSucceededEvent extends GraphEngineEvent {
  final Map<String, dynamic> outputs;
  GraphRunSucceededEvent({this.outputs = const {}});
}

class GraphRunFailedEvent extends GraphEngineEvent {
  final String error;
  GraphRunFailedEvent({required this.error});
}

class GraphRunPartialSucceededEvent extends GraphEngineEvent {
  final int exceptionsCount;
  final Map<String, dynamic> outputs;
  GraphRunPartialSucceededEvent(
      {required this.exceptionsCount, this.outputs = const {}});
}

class NodeRunSucceededEvent extends GraphEngineEvent {
  final String nodeId;
  final String? selectedHandle;
  final Map<String, dynamic> outputs;
  NodeRunSucceededEvent({
    required this.nodeId,
    this.selectedHandle,
    this.outputs = const {},
  });
}

class NodeRunFailedEvent extends GraphEngineEvent {
  final String nodeId;
  final String error;
  NodeRunFailedEvent({required this.nodeId, required this.error});
}

// -- 节点执行结果 --

class NodeRunResult {
  final String nodeId;
  final NodeExecutionStatus status;
  final String? selectedHandle; // 分支节点选择
  final Map<String, dynamic> outputs;
  final String? error;

  const NodeRunResult({
    required this.nodeId,
    required this.status,
    this.selectedHandle,
    this.outputs = const {},
    this.error,
  });
}

/// 节点执行器函数类型（异步，支持 LLM 等需要网络请求的节点）
typedef NodeExecutorFn = Future<NodeRunResult> Function(
  DslNode node,
  VariablePool pool,
);

// -- GraphStateManager --

class GraphStateManager {
  final WorkflowGraph _graph;
  final Map<String, EdgeState> _edgeStates = {};
  final Map<String, NodeState> _nodeStates = {};

  GraphStateManager(this._graph) {
    // 初始化所有边和节点状态为 UNKNOWN
    for (final edge in _graph.edges) {
      _edgeStates[edge.id] = EdgeState.unknown;
    }
    for (final node in _graph.nodes) {
      _nodeStates[node.id] = NodeState.unknown;
    }
  }

  // -- 边操作 --

  EdgeState getEdgeState(String edgeId) =>
      _edgeStates[edgeId] ?? EdgeState.unknown;

  void markEdgeTaken(String edgeId) {
    _edgeStates[edgeId] = EdgeState.taken;
  }

  void markEdgeSkipped(String edgeId) {
    _edgeStates[edgeId] = EdgeState.skipped;
  }

  // -- 节点操作 --

  NodeState getNodeState(String nodeId) =>
      _nodeStates[nodeId] ?? NodeState.unknown;

  void markNodeTaken(String nodeId) {
    _nodeStates[nodeId] = NodeState.taken;
  }

  void markNodeSkipped(String nodeId) {
    _nodeStates[nodeId] = NodeState.skipped;
  }

  /// 节点就绪判断：所有入边已确定 AND 至少一条 TAKEN
  bool isNodeReady(String nodeId) {
    final incoming = _graph.edges
        .where((e) => e.target == nodeId)
        .toList();
    if (incoming.isEmpty) return true;
    // 有 UNKNOWN 边 → 未就绪
    if (incoming.any((e) => getEdgeState(e.id) == EdgeState.unknown)) {
      return false;
    }
    // 至少一条 TAKEN → 就绪
    return incoming.any((e) => getEdgeState(e.id) == EdgeState.taken);
  }

  /// 分类分支边：按 selectedHandle 分为选中/未选中
  (List<DslEdge>, List<DslEdge>) categorizeBranchEdges(
    String nodeId,
    String selectedHandle,
  ) {
    final outgoing = _graph.edges
        .where((e) => e.source == nodeId)
        .toList();
    final selected = <DslEdge>[];
    final unselected = <DslEdge>[];
    for (final edge in outgoing) {
      if (edge.sourceHandle == selectedHandle) {
        selected.add(edge);
      } else {
        unselected.add(edge);
      }
    }
    return (selected, unselected);
  }
}

// -- SkipPropagator --

class SkipPropagator {
  final WorkflowGraph _graph;
  final GraphStateManager _sm;

  SkipPropagator(this._graph, this._sm);

  /// 从一条 SKIPPED 边开始递归传播
  void propagateSkipFromEdge(String edgeId) {
    final edge = _graph.edges.firstWhere((e) => e.id == edgeId);
    final downstreamId = edge.target;
    final incoming = _graph.edges
        .where((e) => e.target == downstreamId)
        .toList();

    // 有 UNKNOWN 边 → 停止
    if (incoming.any((e) => _sm.getEdgeState(e.id) == EdgeState.unknown)) {
      return;
    }
    // 有 TAKEN 边 → 节点可能执行
    if (incoming.any((e) => _sm.getEdgeState(e.id) == EdgeState.taken)) {
      _sm.markNodeTaken(downstreamId);
      return;
    }
    // 全 SKIPPED → 递归跳过
    _propagateSkipToNode(downstreamId);
  }

  void _propagateSkipToNode(String nodeId) {
    _sm.markNodeSkipped(nodeId);
    LoggerService.instance.d(
      '节点被 skip: $nodeId',
      category: LogCategory.general,
      tags: ['dsl', 'skip-propagate'],
    );
    final outgoing = _graph.edges
        .where((e) => e.source == nodeId)
        .toList();
    for (final edge in outgoing) {
      _sm.markEdgeSkipped(edge.id);
      propagateSkipFromEdge(edge.id);
    }
  }

  /// 跳过未选分支的所有边
  void skipBranchPaths(List<DslEdge> unselectedEdges) {
    for (final edge in unselectedEdges) {
      _sm.markEdgeSkipped(edge.id);
      propagateSkipFromEdge(edge.id);
    }
  }
}

// -- EdgeProcessor --

class EdgeProcessor {
  final WorkflowGraph _graph;
  final GraphStateManager _sm;
  final SkipPropagator _sp;

  EdgeProcessor(this._graph, this._sm, this._sp);

  /// 非分支节点成功 → 所有出边 TAKEN
  List<String> processNonBranchNodeEdges(String nodeId) {
    final outgoing = _graph.edges
        .where((e) => e.source == nodeId)
        .toList();
    return _processTakenEdges(outgoing);
  }

  /// 分支节点成功 → 选中边 TAKEN，未选边 SKIPPED
  List<String> handleBranchCompletion(String nodeId, String selectedHandle) {
    final (selected, unselected) =
        _sm.categorizeBranchEdges(nodeId, selectedHandle);
    LoggerService.instance.d(
      '分支选择完成: node=$nodeId, selectedHandle=$selectedHandle, '
      'selected=${selected.length}, unselected=${unselected.length}',
      category: LogCategory.general,
      tags: ['dsl', 'branch'],
    );
    _sp.skipBranchPaths(unselected);
    return _processTakenEdges(selected);
  }

  List<String> _processTakenEdges(List<DslEdge> edges) {
    final readyNodes = <String>[];
    for (final edge in edges) {
      _sm.markEdgeTaken(edge.id);
      if (_sm.isNodeReady(edge.target)) {
        readyNodes.add(edge.target);
      }
    }
    return readyNodes;
  }
}

// -- GraphEngine --

class GraphEngine {
  final WorkflowGraph graph;
  final VariablePool variablePool;
  final NodeExecutorFn _nodeExecutor;

  GraphEngine({
    required this.graph,
    required this.variablePool,
    required NodeExecutorFn nodeExecutor,
  }) : _nodeExecutor = nodeExecutor;

  /// 执行工作流，产生事件流（异步，支持 LLM 等网络节点）
  Stream<GraphEngineEvent> run() async* {
    LoggerService.instance.i(
      'GraphEngine.run 开始执行工作流',
      category: LogCategory.general,
      tags: ['dsl', 'graph-run'],
    );
    yield GraphRunStartedEvent();

    final sm = GraphStateManager(graph);
    final sp = SkipPropagator(graph, sm);
    final ep = EdgeProcessor(graph, sm, sp);

    final readyQueue = <String>[];
    final executing = <String>{};
    final failedNodes = <String>[];
    final outputs = <String, dynamic>{};

    // 入队根节点
    final rootNode = graph.rootNode;
    if (rootNode == null) {
      LoggerService.instance.e(
        '未找到根节点 (start)',
        stackTrace: StackTrace.current.toString(),
        category: LogCategory.general,
        tags: ['dsl', 'graph-run'],
      );
      yield GraphRunFailedEvent(error: 'No root node found');
      return;
    }
    sm.markNodeTaken(rootNode.id);
    readyQueue.add(rootNode.id);

    while (readyQueue.isNotEmpty) {
      final nodeId = readyQueue.removeAt(0);
      executing.add(nodeId);

      // 找到节点
      final node = graph.nodes.firstWhere(
        (n) => n.id == nodeId,
        orElse: () => DslNode(
            id: nodeId, type: NodeType.unknown, title: '', data: {}),
      );

      // 执行节点（异步）
      final result = await _nodeExecutor(node, variablePool);

      executing.remove(nodeId);

      if (result.status == NodeExecutionStatus.failed) {
        failedNodes.add(nodeId);
        LoggerService.instance.e(
          '节点执行失败: nodeId=$nodeId, error=${result.error}',
          category: LogCategory.general,
          tags: ['dsl', 'graph-run'],
        );
        yield NodeRunFailedEvent(
            nodeId: nodeId, error: result.error ?? 'Unknown error');
        // 继续处理其他就绪节点
        continue;
      }

      // 成功：写入输出到 VariablePool
      for (final entry in result.outputs.entries) {
        variablePool.add([nodeId, entry.key], entry.value);
      }

      yield NodeRunSucceededEvent(
        nodeId: nodeId,
        selectedHandle: result.selectedHandle,
        outputs: result.outputs,
      );

      // 处理下游边
      List<String> downstreamReady;
      if (node.type == NodeType.ifElse && result.selectedHandle != null) {
        downstreamReady =
            ep.handleBranchCompletion(nodeId, result.selectedHandle!);
      } else {
        downstreamReady = ep.processNonBranchNodeEdges(nodeId);
      }

      // 把就绪的下游节点入队
      for (final downId in downstreamReady) {
        if (!executing.contains(downId) &&
            !readyQueue.contains(downId) &&
            sm.getNodeState(downId) != NodeState.skipped) {
          sm.markNodeTaken(downId);
          readyQueue.add(downId);
        }
      }

      // 收集 end 节点输出
      if (node.type == NodeType.end) {
        outputs.addAll(result.outputs);
      }
    }

    // 终止事件
    if (failedNodes.isNotEmpty) {
      LoggerService.instance.i(
        'GraphEngine.run 完成(部分失败): failedCount=${failedNodes.length}',
        category: LogCategory.general,
        tags: ['dsl', 'graph-run'],
      );
      yield GraphRunPartialSucceededEvent(
        exceptionsCount: failedNodes.length,
        outputs: outputs,
      );
    } else {
      LoggerService.instance.i(
        'GraphEngine.run 完成(全部成功): outputKeys=${outputs.keys.toList()}',
        category: LogCategory.general,
        tags: ['dsl', 'graph-run'],
      );
      yield GraphRunSucceededEvent(outputs: outputs);
    }
  }
}
