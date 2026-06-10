/// VariablePool：DSL 引擎的变量池，忠实复现 Dify graphon/runtime/variable_pool.py
///
/// - 双层字典结构：`Map<nodeId, Map<variableName, Segment>>`
/// - 支持 add / get / convert_template
/// - get 支持嵌套属性穿透（`[nodeId, varName, field1, field2]`）
/// - convert_template 解析 `{{#node_id.var#}}` 占位符
library;

import 'package:novel_app/services/dsl_engine/models/segment.dart';

class VariablePool {
  /// 双层字典：第一层 key 是节点 ID，第二层 key 是变量名
  final Map<String, Map<String, Segment>> _dict = {};

  /// 添加变量到池。
  /// selector 必须是 [nodeId, varName, ...] 形式。
  /// 当 selector 长度 > 2 时，视为对 ObjectSegment 嵌套字段的更新。
  void add(List<String> selector, dynamic value) {
    if (selector.isEmpty) {
      throw ArgumentError('Selector cannot be empty');
    }

    if (selector.length == 1) {
      // [nodeId] → 占位但不推荐
      _dict.putIfAbsent(selector[0], () => {});
      return;
    }

    if (selector.length == 2) {
      final nodeId = selector[0];
      final varName = selector[1];
      _dict.putIfAbsent(nodeId, () => {});
      _dict[nodeId]![varName] = segmentFromValue(value);
      return;
    }

    // selector.length > 2: 嵌套字段更新到 ObjectSegment
    final nodeId = selector[0];
    final varName = selector[1];
    final path = selector.sublist(2);

    _dict.putIfAbsent(nodeId, () => {});
    final existing = _dict[nodeId]![varName];

    if (existing is ObjectSegment) {
      // 在现有 ObjectSegment 上更新嵌套字段
      final newMap = Map<String, dynamic>.from(existing.value);
      _setNestedField(newMap, path, value);
      _dict[nodeId]![varName] = ObjectSegment(value: newMap);
    } else {
      // 重新构造一个 ObjectSegment
      final newMap = <String, dynamic>{};
      _setNestedField(newMap, path, value);
      _dict[nodeId]![varName] = ObjectSegment(value: newMap);
    }
  }

  /// 获取变量。
  /// selector 长度 = 2：返回 [nodeId, varName] 对应的 Segment
  /// selector 长度 > 2：在 [nodeId, varName] 的 ObjectSegment 中按 path 穿透
  /// selector 长度 < 2 或找不到：返回 null
  Segment? get(List<String> selector) {
    if (selector.length < 2) return null;

    final nodeId = selector[0];
    final varName = selector[1];
    final nodeVars = _dict[nodeId];
    if (nodeVars == null) return null;

    final segment = nodeVars[varName];
    if (segment == null) return null;

    if (selector.length == 2) return segment;

    // 嵌套访问
    if (segment is ObjectSegment) {
      return segment.getField(selector.sublist(2));
    }

    return null;
  }

  /// 是否包含指定变量
  bool contains(List<String> selector) => get(selector) != null;

  /// 移除某个节点的所有变量
  void removeNode(String nodeId) {
    _dict.remove(nodeId);
  }

  /// 清空池
  void clear() {
    _dict.clear();
  }

  /// 列出所有节点 ID
  Iterable<String> get nodeIds => _dict.keys;

  /// 列出某节点下的所有变量名
  Iterable<String>? variablesOf(String nodeId) => _dict[nodeId]?.keys;

  // -- 模板转换 --

  /// 解析模板中的 {{#node_id.var#}} 占位符。
  ///
  /// 规则（来自 Dify graphon/runtime/variable_pool.py）：
  /// - 正则: `\{\{#([a-zA-Z0-9_]{1,50}(?:\.[a-zA-Z_][a-zA-Z0-9_]{0,29}){1,10})#\}\}`
  /// - 第一个段是 node_id（1-50 字母数字下划线）
  /// - 后续段是属性名（首字符字母/下划线，后续可含数字）
  /// - 最多 1 + 10 = 11 段
  ///
  /// 未匹配的占位符降级为空字符串（Dify 行为）。
  SegmentGroup convertTemplate(String template) {
    final segments = <Segment>[];
    final pattern = _variablePattern;
    int lastEnd = 0;

    for (final match in pattern.allMatches(template)) {
      // 添加占位符之前的纯文本
      if (match.start > lastEnd) {
        final text = template.substring(lastEnd, match.start);
        segments.add(StringSegment(value: text));
      }

      // 解析占位符
      final path = match.group(1)!.split('.');
      final segment = get(path);
      if (segment != null) {
        segments.add(segment);
      } else {
        // 未解析到，降级为空串
        segments.add(const StringSegment(value: ''));
      }

      lastEnd = match.end;
    }

    // 添加末尾纯文本
    if (lastEnd < template.length) {
      final text = template.substring(lastEnd);
      segments.add(StringSegment(value: text));
    }

    return SegmentGroup(segments: segments);
  }

  // -- 内部辅助 --

  static final _variablePattern = RegExp(
    r'\{\{#([a-zA-Z0-9_]{1,50}(?:\.[a-zA-Z_][a-zA-Z0-9_]{0,29}){1,10})#\}\}',
  );

  void _setNestedField(
      Map<String, dynamic> map, List<String> path, dynamic value) {
    if (path.isEmpty) return;
    if (path.length == 1) {
      map[path[0]] = value;
      return;
    }
    final key = path[0];
    if (!map.containsKey(key) || map[key] is! Map<String, dynamic>) {
      map[key] = <String, dynamic>{};
    }
    _setNestedField(map[key] as Map<String, dynamic>, path.sublist(1), value);
  }
}
