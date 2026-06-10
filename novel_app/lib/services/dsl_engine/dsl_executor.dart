/// DslExecutor：DSL 引擎高级 API 门面
///
/// 对齐现有 `DifyService` 的接口，让调用方无感切换 Dify ↔ DSL Engine。
///
/// 用法：
/// ```dart
/// final executor = DslExecutor(config: LlmConfig(...));
///
/// // 流式执行 creater.yml
/// await executor.runStreaming(
///   inputs: {'cmd': '特写', 'user_input': '...'},
///   onData: (chunk) => print(chunk),
///   onDone: () => print('done'),
/// );
///
/// // 阻塞执行 structured_info.yml
/// final outputs = await executor.runBlocking(
///   inputs: {'cmd': '生成', 'user_input': '...'},
/// );
/// ```
library;

import 'package:flutter/services.dart' show rootBundle;

import 'condition_processor.dart';
import 'dsl_parser.dart';
import 'graph_engine.dart';
import 'llm_provider.dart';
import 'models/variable_pool.dart';
import 'real_llm_executor.dart';
import 'template_renderer.dart';
import 'package:novel_app/services/logger_service.dart';

class DslExecutor {
  final LlmConfig _llmConfig;
  final String? _defaultModel; // 覆盖 DSL 中配置的 model

  DslExecutor({
    required LlmConfig llmConfig,
    String? defaultModel,
  })  : _llmConfig = llmConfig,
        _defaultModel = defaultModel;

  /// 流式执行 creater.yml
  ///
  /// 对齐 DifyService.runWorkflowStreaming 的接口签名。
  Future<void> runStreaming({
    required Map<String, dynamic> inputs,
    required Function(String data) onData,
    Function(String error)? onError,
    Function()? onDone,
  }) async {
    LoggerService.instance.d(
      'DslExecutor.runStreaming 入口: inputs=${inputs.keys.toList()}',
      category: LogCategory.ai,
      tags: ['dsl', 'run-streaming'],
    );
    try {
      final yaml = await rootBundle.loadString('assets/dsl/creater.yml');
      final parser = DslParser();
      final graph = parser.parseGraphConfig(yaml);

      final pool = _injectInputs(graph, inputs);

      final realLlm = RealLlmExecutor(
        provider: LlmProvider(_llmConfig, httpClient: IoLlmHttpClient()),
        defaultModel: _defaultModel,
      );

      final engine = GraphEngine(
        graph: graph,
        variablePool: pool,
        nodeExecutor: (node, p) => _nodeExecutor(node, p, realLlm, onChunk: onData),
      );

      await for (final event in engine.run()) {
        if (event is NodeRunFailedEvent) {
          onError?.call(event.error);
        }
      }

      onDone?.call();
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        'DslExecutor.runStreaming 执行失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'run-streaming'],
      );
      onError?.call(e.toString());
    }
  }

  /// 阻塞执行 structured_info.yml
  ///
  /// 对齐 DifyService.runWorkflowBlocking 的接口签名。
  /// 返回 Dify 格式的 outputs Map（含 content 字段）。
  Future<Map<String, dynamic>?> runBlocking({
    required Map<String, dynamic> inputs,
  }) async {
    LoggerService.instance.d(
      'DslExecutor.runBlocking 入口: inputs=${inputs.keys.toList()}',
      category: LogCategory.ai,
      tags: ['dsl', 'run-blocking'],
    );
    try {
      final yaml = await rootBundle.loadString('assets/dsl/structured_info.yml');
      final parser = DslParser();
      final graph = parser.parseGraphConfig(yaml);

      final pool = _injectInputs(graph, inputs);

      final realLlm = RealLlmExecutor(
        provider: LlmProvider(_llmConfig, httpClient: IoLlmHttpClient()),
        defaultModel: _defaultModel,
      );

      final engine = GraphEngine(
        graph: graph,
        variablePool: pool,
        nodeExecutor: (node, p) => _nodeExecutor(node, p, realLlm),
      );
      final events = await engine.run().toList();

      // 收集 end 节点的 outputs
      final endNode = graph.nodes.firstWhere(
        (n) => n.type == NodeType.end,
        orElse: () => DslNode(
          id: '', type: NodeType.unknown, title: '', data: const {},
        ),
      );
      if (endNode.id.isEmpty) {
        LoggerService.instance.w(
          'structured_info.yml 未找到 end 节点，尝试从事件中提取 outputs',
          category: LogCategory.ai,
          tags: ['dsl', 'run-blocking'],
        );
        // 如果 end 节点不存在，从最后一个 event 收集
        for (final event in events.reversed) {
          if (event is GraphRunSucceededEvent) {
            return event.outputs;
          }
        }
        return null;
      }

      // 从 end 节点的 data.outputs 中提取 value_selector，从 pool 中取值
      final endOutputs = endNode.data['outputs'] as List?;
      if (endOutputs == null || endOutputs.isEmpty) {
        return null;
      }

      final result = <String, dynamic>{};
      for (final out in endOutputs) {
        if (out is! Map) continue;
        final varName = out['variable']?.toString() ?? '';
        final selector = out['value_selector'] as List?;
        if (varName.isEmpty || selector == null) continue;
        final path = selector.map((e) => e.toString()).toList();
        final segment = pool.get(path);
        if (segment != null) {
          result[varName] = segment.toObject();
        }
      }
      LoggerService.instance.i(
        'DslExecutor.runBlocking 完成: resultKeys=${result.keys.toList()}',
        category: LogCategory.ai,
        tags: ['dsl', 'run-blocking'],
      );
      return result;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        'DslExecutor.runBlocking 执行失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.ai,
        tags: ['dsl', 'run-blocking'],
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 内部方法
  // ---------------------------------------------------------------------------

  /// 把 inputs 注入到 VariablePool
  VariablePool _injectInputs(
      WorkflowGraph graph, Map<String, dynamic> inputs) {
    final pool = VariablePool();
    final startNode = graph.rootNode;
    if (startNode == null) return pool;

    // 注入所有 inputs 到 start 节点
    for (final entry in inputs.entries) {
      pool.add([startNode.id, entry.key], entry.value);
    }

    // 为 start 节点中声明但未在 inputs 中提供的变量设置默认值
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

    LoggerService.instance.d(
      'inputs 注入完成: startNode=${startNode.id}, inputs=${inputs.keys.toList()}',
      category: LogCategory.ai,
      tags: ['dsl', 'inject-inputs'],
    );

    return pool;
  }

  /// 节点执行器分发
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

  // -- 各节点类型的具体实现 --

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
        if (v is Map) {
          // 格式: [{value_selector: [nodeId, varName]}, ...]
          final selector = v['value_selector'];
          if (selector is! List) continue;
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
        } else if (v is List) {
          // 格式: [[nodeId, varName], ...] (Dify 导出的 YAML 原始格式)
          final path = v.map((e) => e.toString()).toList();
          if (path.length < 2) continue;
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
    }

    return NodeRunResult(
      nodeId: node.id,
      status: NodeExecutionStatus.succeeded,
      outputs: {'output': ''},
    );
  }
}