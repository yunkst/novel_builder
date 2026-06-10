/// DSL 解析器：将 Dify 导出的 YAML 转换为 Dart 图模型。
///
/// 主要功能：
/// - parseGraphConfig: YAML → WorkflowGraph
/// - parseCases: 解析 if-else 的 cases 列表
/// - 支持的节点类型：start / end / if-else / template-transform / variable-aggregator / llm
///
/// 严格保留 Dify DSL 的所有原始字段（data 是 Map），节点具体属性由各 Node 实现自行解析。
library;

import 'package:yaml/yaml.dart';

import 'condition_processor.dart';
import 'package:novel_app/services/logger_service.dart';

/// 节点类型枚举
enum NodeType {
  start,
  end,
  ifElse,
  templateTransform,
  variableAggregator,
  llm,
  unknown,
}

/// DSL 节点
class DslNode {
  final String id;
  final NodeType type;
  final String title;
  final Map<String, dynamic> data; // 原始 data 字段

  const DslNode({
    required this.id,
    required this.type,
    required this.title,
    required this.data,
  });
}

/// DSL 边
class DslEdge {
  final String id;
  final String source;
  final String target;
  final String sourceHandle;
  final String targetHandle;

  const DslEdge({
    required this.id,
    required this.source,
    required this.target,
    required this.sourceHandle,
    required this.targetHandle,
  });
}

/// 解析后的工作流图
class WorkflowGraph {
  final List<DslNode> nodes;
  final List<DslEdge> edges;

  const WorkflowGraph({required this.nodes, required this.edges});

  DslNode? get rootNode {
    // 第一个 start 类型节点
    try {
      return nodes.firstWhere((n) => n.type == NodeType.start);
    } catch (_) {
      return null;
    }
  }
}

/// DSL 解析错误
class DslParseError implements Exception {
  final String message;
  DslParseError(this.message);
  @override
  String toString() => 'DslParseError: $message';
}

class DslParser {
  /// 解析 YAML 字符串，返回 WorkflowGraph
  WorkflowGraph parseGraphConfig(String yaml) {
    LoggerService.instance.d(
      '开始解析 DSL 图配置',
      category: LogCategory.ai,
      tags: ['dsl', 'parse'],
    );

    if (yaml.isEmpty) {
      LoggerService.instance.e(
        'DSL YAML 内容为空',
        stackTrace: StackTrace.current.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'parse'],
      );
      throw DslParseError('Empty YAML content');
    }

    final dynamic doc;
    try {
      doc = loadYaml(yaml);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        'YAML 解析失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'parse'],
      );
      throw DslParseError('YAML decode failed: $e');
    }

    if (doc is! YamlMap) {
      LoggerService.instance.e(
        'YAML 根节点不是 Map',
        stackTrace: StackTrace.current.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'parse'],
      );
      throw DslParseError('YAML root must be a map');
    }

    final workflow = doc['workflow'];
    if (workflow == null || workflow is! YamlMap) {
      LoggerService.instance.e(
        '缺少 workflow 节点',
        stackTrace: StackTrace.current.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'parse'],
      );
      throw DslParseError('Missing workflow section');
    }

    final graph = workflow['graph'];
    if (graph == null || graph is! YamlMap) {
      LoggerService.instance.e(
        '缺少 workflow.graph 节点',
        stackTrace: StackTrace.current.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'parse'],
      );
      throw DslParseError('Missing workflow.graph section');
    }

    final edgesRaw = graph['edges'];
    final nodesRaw = graph['nodes'];
    if (nodesRaw is! YamlList) {
      LoggerService.instance.e(
        'workflow.graph.nodes 不是列表',
        stackTrace: StackTrace.current.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'parse'],
      );
      throw DslParseError('workflow.graph.nodes must be a list');
    }
    if (edgesRaw is! YamlList) {
      LoggerService.instance.e(
        'workflow.graph.edges 不是列表',
        stackTrace: StackTrace.current.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'parse'],
      );
      throw DslParseError('workflow.graph.edges must be a list');
    }

    final nodes = <DslNode>[];
    for (final nodeYaml in nodesRaw) {
      if (nodeYaml is YamlMap) {
        nodes.add(_parseNode(_yamlMapToMap(nodeYaml)));
      }
    }

    final edges = <DslEdge>[];
    for (final edgeYaml in edgesRaw) {
      if (edgeYaml is YamlMap) {
        edges.add(_parseEdge(_yamlMapToMap(edgeYaml)));
      }
    }

    LoggerService.instance.i(
      'DSL 图配置解析完成: nodes=${nodes.length}, edges=${edges.length}',
      category: LogCategory.ai,
      tags: ['dsl', 'parse'],
    );

    return WorkflowGraph(nodes: nodes, edges: edges);
  }

  /// 解析 if-else 的 cases 列表为 [IfElseCase]
  List<IfElseCase> parseCases(dynamic casesRaw) {
    if (casesRaw is! List) return [];
    final result = <IfElseCase>[];
    for (final caseYaml in casesRaw) {
      if (caseYaml is! Map) continue;
      final caseMap = caseYaml is YamlMap ? _yamlMapToMap(caseYaml) : Map<String, dynamic>.from(caseYaml);
      final caseId = caseMap['case_id']?.toString() ?? '';
      final logicalOp = caseMap['logical_operator']?.toString() ?? 'and';
      final conditionsRaw = caseMap['conditions'];
      final conditions = <Condition>[];
      if (conditionsRaw is List) {
        for (final condYaml in conditionsRaw) {
          if (condYaml is! Map) continue;
          final condMap = condYaml is YamlMap
              ? _yamlMapToMap(condYaml)
              : Map<String, dynamic>.from(condYaml);
          conditions.add(_parseCondition(condMap));
        }
      }
      result.add(IfElseCase(
        caseId: caseId,
        logicalOperator: logicalOp,
        conditions: conditions,
      ));
    }
    return result;
  }

  // -- 内部辅助 --

  DslNode _parseNode(Map<String, dynamic> nodeMap) {
    final data = nodeMap['data'];
    final dataMap = data is YamlMap
        ? _yamlMapToMap(data)
        : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});

    final type = _parseNodeType(dataMap['type']?.toString() ?? '');
    final id = nodeMap['id']?.toString() ?? '';
    final title = dataMap['title']?.toString() ?? '';

    return DslNode(id: id, type: type, title: title, data: dataMap);
  }

  DslEdge _parseEdge(Map<String, dynamic> edgeMap) {
    return DslEdge(
      id: edgeMap['id']?.toString() ?? '',
      source: edgeMap['source']?.toString() ?? '',
      target: edgeMap['target']?.toString() ?? '',
      sourceHandle: edgeMap['sourceHandle']?.toString() ?? 'source',
      targetHandle: edgeMap['targetHandle']?.toString() ?? 'target',
    );
  }

  NodeType _parseNodeType(String typeStr) {
    switch (typeStr) {
      case 'start':
        return NodeType.start;
      case 'end':
        return NodeType.end;
      case 'if-else':
        return NodeType.ifElse;
      case 'template-transform':
        return NodeType.templateTransform;
      case 'variable-aggregator':
        return NodeType.variableAggregator;
      case 'llm':
        return NodeType.llm;
      default:
        LoggerService.instance.w(
          '未知节点类型: "$typeStr"',
          category: LogCategory.ai,
          tags: ['dsl', 'parse'],
        );
        return NodeType.unknown;
    }
  }

  Condition _parseCondition(Map<String, dynamic> condMap) {
    final selectorRaw = condMap['variable_selector'];
    final selector = <String>[];
    if (selectorRaw is List) {
      for (final s in selectorRaw) {
        selector.add(s.toString());
      }
    }
    return Condition(
      variableSelector: selector,
      comparisonOperator: condMap['comparison_operator']?.toString() ?? '',
      value: condMap['value'],
    );
  }

  /// 把 YamlMap 转为普通 `Map<String, dynamic>`，递归处理嵌套
  Map<String, dynamic> _yamlMapToMap(YamlMap yamlMap) {
    final result = <String, dynamic>{};
    yamlMap.forEach((key, value) {
      result[key.toString()] = _yamlValueToDart(value);
    });
    return result;
  }

  dynamic _yamlValueToDart(dynamic value) {
    if (value is YamlMap) return _yamlMapToMap(value);
    if (value is YamlList) {
      return value.map(_yamlValueToDart).toList();
    }
    return value;
  }
}

/// if-else case 数据结构
class IfElseCase {
  final String caseId;
  final String logicalOperator;
  final List<Condition> conditions;

  const IfElseCase({
    required this.caseId,
    required this.logicalOperator,
    required this.conditions,
  });
}
