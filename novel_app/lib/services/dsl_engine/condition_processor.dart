/// ConditionProcessor：DSL 引擎的条件求值器
///
/// 严格复现 Dify graphon/utils/condition/processor.py 的 21 个算子 + 短路求值。
///
/// 算子列表（来自 Dify SupportedComparisonOperator）：
///   contains / not contains / start with / end with
///   is / is not / empty / not empty
///   in / not in / all of
///   = / ≠ / > / < / ≥ / ≤
///   null / not null
///   exists / not exists
library;

import 'package:novel_app/services/dsl_engine/models/segment.dart';
import 'package:novel_app/services/dsl_engine/models/variable_pool.dart';
import 'package:novel_app/services/logger_service.dart';

// -- 数据模型 --

/// 单个条件。
class Condition {
  final List<String> variableSelector;
  final String comparisonOperator;
  final dynamic value; // String | List<String> | bool | null

  const Condition({
    required this.variableSelector,
    required this.comparisonOperator,
    this.value,
  });
}

/// 条件检查结果。
class ConditionCheckResult {
  /// 已解析的输入条件（仅二元算子会填充）
  final List<Map<String, dynamic>> inputConditions;

  /// 每个条件的布尔结果
  final List<bool> groupResults;

  /// 组合后的最终结果（受 logical_operator 影响）
  final bool finalResult;

  const ConditionCheckResult({
    required this.inputConditions,
    required this.groupResults,
    required this.finalResult,
  });
}

// -- 主类 --

class ConditionProcessor {
  /// 算子分发表：与 Dify _CONDITION_EVALUATOR_NAMES 对齐
  static const Map<String, String> _operatorEvaluators = {
    'contains': '_assertContains',
    'not contains': '_assertNotContains',
    'start with': '_assertStartWith',
    'end with': '_assertEndWith',
    'is': '_assertIs',
    'is not': '_assertIsNot',
    'empty': '_assertEmpty',
    'not empty': '_assertNotEmpty',
    '=': '_assertEqual',
    '≠': '_assertNotEqual',
    '>': '_assertGreaterThan',
    '<': '_assertLessThan',
    '≥': '_assertGreaterThanOrEqual',
    '≤': '_assertLessThanOrEqual',
    'null': '_assertNull',
    'not null': '_assertNotNull',
    'in': '_assertIn',
    'not in': '_assertNotIn',
    'all of': '_evaluateAllOf',
    'exists': '_assertExists',
    'not exists': '_assertNotExists',
  };

  /// 一元算子：不需要 expected value
  static const Set<String> _unaryOperators = {
    'empty',
    'not empty',
    'null',
    'not null',
    'exists',
    'not exists',
  };

  /// 评估一组条件，支持 and/or 短路求值。
  ConditionCheckResult processConditions({
    required VariablePool variablePool,
    required List<Condition> conditions,
    required String operator, // 'and' | 'or'
  }) {
    LoggerService.instance.d(
      '条件求值开始: conditions=${conditions.length}, operator=$operator',
      category: LogCategory.ai,
      tags: ['dsl', 'condition'],
    );

    final inputConditions = <Map<String, dynamic>>[];
    final groupResults = <bool>[];

    for (final condition in conditions) {
      final variable = variablePool.get(condition.variableSelector);
      // exists / not exists 算子：变量不存在时直接判定，不抛错
      if (variable == null) {
        if (condition.comparisonOperator == 'exists' ||
            condition.comparisonOperator == 'not exists') {
          final result = _evaluateCondition(
            value: null,
            operator: condition.comparisonOperator,
            expected: null,
          );
          groupResults.add(result);
          // 短路
          if ((operator == 'and' && !result) ||
              (operator == 'or' && result)) {
            LoggerService.instance.d(
              '条件短路求值触发: operator=$operator, result=$result',
              category: LogCategory.ai,
              tags: ['dsl', 'condition'],
            );
            return ConditionCheckResult(
              inputConditions: inputConditions,
              groupResults: groupResults,
              finalResult: result,
            );
          }
          continue;
        }
        LoggerService.instance.e(
          '变量未找到: ${condition.variableSelector}',
          stackTrace: StackTrace.current.toString(),
          category: LogCategory.ai,
          tags: ['dsl', 'condition'],
        );
        throw ValueError(
            'Variable ${condition.variableSelector} not found');
      }

      final rawValue = variable.toObject();

      // 存在性算子（exists / not exists）
      if (condition.comparisonOperator == 'exists' ||
          condition.comparisonOperator == 'not exists') {
        final result = _evaluateCondition(
          value: rawValue,
          operator: condition.comparisonOperator,
          expected: null,
        );
        groupResults.add(result);
      } else {
        // 二元算子：需要 prepare expected value
        final actualValue = rawValue;
        final expectedValue = _prepareExpectedValue(
          variable: variable,
          variablePool: variablePool,
          expectedValue: condition.value,
        );
        inputConditions.add({
          'actual_value': actualValue,
          'expected_value': expectedValue,
          'comparison_operator': condition.comparisonOperator,
        });
        final result = _evaluateCondition(
          value: actualValue,
          operator: condition.comparisonOperator,
          expected: expectedValue,
        );
        groupResults.add(result);
      }

      // 短路求值
      if ((operator == 'and' && !groupResults.last) ||
          (operator == 'or' && groupResults.last)) {
        LoggerService.instance.d(
          '条件短路求值触发: operator=$operator, lastResult=${groupResults.last}',
          category: LogCategory.ai,
          tags: ['dsl', 'condition'],
        );
        return ConditionCheckResult(
          inputConditions: inputConditions,
          groupResults: groupResults,
          finalResult: groupResults.last,
        );
      }
    }

    final finalResult =
        operator == 'and' ? groupResults.every((r) => r) : groupResults.any((r) => r);
    LoggerService.instance.i(
      '条件求值完成: finalResult=$finalResult, results=$groupResults',
      category: LogCategory.ai,
      tags: ['dsl', 'condition'],
    );
    return ConditionCheckResult(
      inputConditions: inputConditions,
      groupResults: groupResults,
      finalResult: finalResult,
    );
  }

  // -- 算子分发 --

  bool _evaluateCondition({
    required dynamic value,
    required String operator,
    required dynamic expected,
  }) {
    final evaluatorName = _operatorEvaluators[operator];
    if (evaluatorName == null) {
      throw ValueError('Unsupported operator: $operator');
    }

    if (_unaryOperators.contains(operator)) {
      return _callUnary(evaluatorName, value);
    }
    return _callBinary(evaluatorName, value, expected);
  }

  bool _callUnary(String name, dynamic value) {
    switch (name) {
      case '_assertEmpty':
        return _assertEmpty(value: value);
      case '_assertNotEmpty':
        return _assertNotEmpty(value: value);
      case '_assertNull':
        return _assertNull(value: value);
      case '_assertNotNull':
        return _assertNotNull(value: value);
      case '_assertExists':
        return _assertExists(value: value);
      case '_assertNotExists':
        return _assertNotExists(value: value);
    }
    throw StateError('Unknown unary evaluator: $name');
  }

  bool _callBinary(String name, dynamic value, dynamic expected) {
    switch (name) {
      case '_assertContains':
        return _assertContains(value: value, expected: expected);
      case '_assertNotContains':
        return _assertNotContains(value: value, expected: expected);
      case '_assertStartWith':
        return _assertStartWith(value: value, expected: expected);
      case '_assertEndWith':
        return _assertEndWith(value: value, expected: expected);
      case '_assertIs':
        return _assertIs(value: value, expected: expected);
      case '_assertIsNot':
        return _assertIsNot(value: value, expected: expected);
      case '_assertEqual':
        return _assertEqual(value: value, expected: expected);
      case '_assertNotEqual':
        return _assertNotEqual(value: value, expected: expected);
      case '_assertGreaterThan':
        return _assertGreaterThan(value: value, expected: expected);
      case '_assertLessThan':
        return _assertLessThan(value: value, expected: expected);
      case '_assertGreaterThanOrEqual':
        return _assertGreaterThanOrEqual(value: value, expected: expected);
      case '_assertLessThanOrEqual':
        return _assertLessThanOrEqual(value: value, expected: expected);
      case '_assertIn':
        return _assertIn(value: value, expected: expected);
      case '_assertNotIn':
        return _assertNotIn(value: value, expected: expected);
      case '_evaluateAllOf':
        return _evaluateAllOf(value: value, expected: expected);
    }
    throw StateError('Unknown binary evaluator: $name');
  }

  // -- 算子实现（与 Dify 严格对齐）--

  bool _assertContains({required dynamic value, required dynamic expected}) {
    if (!_isTruthy(value)) return false;

    if (value is String) {
      final normalizedExpected = expected is String ? expected : expected.toString();
      return value.contains(normalizedExpected);
    }
    if (value is List) {
      return value.contains(expected);
    }
    throw ConditionTypeError('Invalid actual value type for contains: ${value.runtimeType}');
  }

  bool _assertNotContains({required dynamic value, required dynamic expected}) {
    if (!_isTruthy(value)) return true;

    if (value is String) {
      final normalizedExpected = expected is String ? expected : expected.toString();
      return !value.contains(normalizedExpected);
    }
    if (value is List) {
      return !value.contains(expected);
    }
    throw ConditionTypeError('Invalid actual value type for not contains: ${value.runtimeType}');
  }

  bool _assertStartWith({required dynamic value, required dynamic expected}) {
    if (!_isTruthy(value)) return false;
    if (value is! String) {
      throw ConditionTypeError('Invalid actual value type for start with: ${value.runtimeType}');
    }
    if (expected is! String) {
      throw ConditionTypeError('Expected value must be a string for start with');
    }
    return value.startsWith(expected);
  }

  bool _assertEndWith({required dynamic value, required dynamic expected}) {
    if (!_isTruthy(value)) return false;
    if (value is! String) {
      throw ConditionTypeError('Invalid actual value type for end with: ${value.runtimeType}');
    }
    if (expected is! String) {
      throw ConditionTypeError('Expected value must be a string for end with');
    }
    return value.endsWith(expected);
  }

  bool _assertIs({required dynamic value, required dynamic expected}) {
    if (value == null) return false;
    if (value is String || value is bool) {
      return value == expected;
    }
    throw ConditionTypeError('Invalid actual value type for is: ${value.runtimeType}');
  }

  bool _assertIsNot({required dynamic value, required dynamic expected}) {
    if (value == null) return false;
    if (value is String || value is bool) {
      return value != expected;
    }
    throw ConditionTypeError('Invalid actual value type for is not: ${value.runtimeType}');
  }

  bool _assertEmpty({required dynamic value}) => !_isTruthy(value);

  bool _assertNotEmpty({required dynamic value}) => _isTruthy(value);

  bool _assertEqual({required dynamic value, required dynamic expected}) {
    if (value == null) return false;
    final normalized = _normalizeNumericEqualityExpected(value: value, expected: expected);
    return value == normalized;
  }

  bool _assertNotEqual({required dynamic value, required dynamic expected}) {
    if (value == null) return false;
    final normalized = _normalizeNumericEqualityExpected(value: value, expected: expected);
    return value != normalized;
  }

  bool _assertGreaterThan({required dynamic value, required dynamic expected}) {
    if (value == null) return false;
    if (value is! num) {
      throw ConditionTypeError('Invalid actual value type for >: ${value.runtimeType}');
    }
    final (a, b) = _normalizeNumericValues(value, expected);
    return a > b;
  }

  bool _assertLessThan({required dynamic value, required dynamic expected}) {
    if (value == null) return false;
    if (value is! num) {
      throw ConditionTypeError('Invalid actual value type for <: ${value.runtimeType}');
    }
    final (a, b) = _normalizeNumericValues(value, expected);
    return a < b;
  }

  bool _assertGreaterThanOrEqual({required dynamic value, required dynamic expected}) {
    if (value == null) return false;
    if (value is! num) {
      throw ConditionTypeError('Invalid actual value type for ≥: ${value.runtimeType}');
    }
    final (a, b) = _normalizeNumericValues(value, expected);
    return a >= b;
  }

  bool _assertLessThanOrEqual({required dynamic value, required dynamic expected}) {
    if (value == null) return false;
    if (value is! num) {
      throw ConditionTypeError('Invalid actual value type for ≤: ${value.runtimeType}');
    }
    final (a, b) = _normalizeNumericValues(value, expected);
    return a <= b;
  }

  bool _assertNull({required dynamic value}) => value == null;

  bool _assertNotNull({required dynamic value}) => value != null;

  bool _assertIn({required dynamic value, required dynamic expected}) {
    if (!_isTruthy(value)) return false;
    if (expected is! List) {
      throw ConditionTypeError('Invalid expected value type for in: ${expected.runtimeType}');
    }
    return expected.contains(value);
  }

  bool _assertNotIn({required dynamic value, required dynamic expected}) {
    if (!_isTruthy(value)) return true;
    if (expected is! List) {
      throw ConditionTypeError('Invalid expected value type for not in: ${expected.runtimeType}');
    }
    return !expected.contains(value);
  }

  bool _evaluateAllOf({required dynamic value, required dynamic expected}) {
    if (!_isTruthy(value)) return false;
    if (expected is! List) {
      throw ConditionTypeError('all of operator expects a list');
    }
    if (expected.every((e) => e is String)) {
      // 字符串或列表都支持
      if (value is String) {
        return expected.every((item) => value.contains(item));
      }
      if (value is List) {
        return expected.every((item) => value.contains(item));
      }
      return false;
    }
    if (expected.every((e) => e is bool)) {
      if (value is List) {
        return expected.every((item) => value.contains(item));
      }
      return false;
    }
    throw ConditionTypeError(
        'all of operator expects homogeneous list of strings or booleans');
  }

  bool _assertExists({required dynamic value}) => value != null;

  bool _assertNotExists({required dynamic value}) => value == null;

  // -- 工具 --

  /// Dify 风格的真值判断：空字符串、null、空列表、空集合都视为 falsy
  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  /// 数值比较时的归一化（int/float/string 互转）
  (num, num) _normalizeNumericValues(num value, dynamic expected) {
    if (expected is String) {
      final expectedFloat = double.tryParse(expected);
      if (expectedFloat == null) {
        throw ConditionTypeError("Cannot convert '$expected' to number");
      }
      if (value is int && expectedFloat == expectedFloat.toInt()) {
        return (value, expectedFloat.toInt());
      }
      if (value is int) {
        return (value.toDouble(), expectedFloat);
      }
      return (value, expectedFloat);
    }
    if (expected is num) {
      if (value is int && expected is double) {
        return (value.toDouble(), expected);
      }
      return (value, expected);
    }
    throw ConditionTypeError('Cannot convert ${expected.runtimeType} to number');
  }

  /// `=` / `≠` 的 expected 归一化
  dynamic _normalizeNumericEqualityExpected({
    required dynamic value,
    required dynamic expected,
  }) {
    if (value is bool) {
      if (expected is bool || expected is int || expected is String) {
        return bool.tryParse(expected.toString()) ??
            (expected is int ? expected != 0 : null);
      }
      throw ConditionTypeError('Cannot convert ${expected.runtimeType} to bool');
    }
    if (value is int) {
      if (expected is int || expected is double || expected is String) {
        return int.tryParse(expected.toString());
      }
      throw ConditionTypeError('Cannot convert ${expected.runtimeType} to int');
    }
    if (value is double) {
      if (expected is int || expected is double || expected is String) {
        return double.tryParse(expected.toString());
      }
      throw ConditionTypeError('Cannot convert ${expected.runtimeType} to double');
    }
    throw ConditionTypeError('Invalid actual value type for equality: ${value.runtimeType}');
  }

  /// 处理 expected value：
  /// - string → 通过 convert_template 解析
  /// - BooleanSegment → 转 bool
  /// - 其他 → 原样返回
  dynamic _prepareExpectedValue({
    required Segment variable,
    required VariablePool variablePool,
    required dynamic expectedValue,
  }) {
    dynamic normalized;
    if (expectedValue is String) {
      normalized = variablePool.convertTemplate(expectedValue).text;
    } else {
      normalized = expectedValue;
    }

    if (normalized == null) return null;

    // boolean 段需要把字符串/数字转成 bool
    if (variable is BooleanSegment) {
      return _convertToBool(normalized);
    }

    if (normalized is String || normalized is bool) {
      return normalized;
    }
    if (normalized is List) {
      return normalized;
    }
    throw ConditionTypeError('unexpected expected value: $normalized');
  }

  /// Dify 风格 bool 转换：int → bool, str → JSON parse → bool
  bool _convertToBool(dynamic value) {
    if (value is int) return value != 0;
    if (value is String) {
      // Dify: json.loads(value), 接受 int/bool
      final s = value.trim();
      if (s == 'true') return true;
      if (s == 'false') return false;
      final n = int.tryParse(s);
      if (n != null) return n != 0;
      throw ConditionTypeError('Cannot convert "$value" to bool');
    }
    if (value is bool) return value;
    throw ConditionTypeError('Cannot convert ${value.runtimeType} to bool');
  }
}

/// 自定义 ValueError
class ValueError implements Exception {
  final String message;
  ValueError(this.message);
  @override
  String toString() => 'ValueError: $message';
}

/// 自定义 ConditionTypeError（Dart 内置 TypeError 不接受参数）
class ConditionTypeError implements Exception {
  final String message;
  ConditionTypeError(this.message);
  @override
  String toString() => 'ConditionTypeError: $message';
}
