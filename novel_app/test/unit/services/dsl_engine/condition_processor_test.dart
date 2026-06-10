/// ConditionProcessor 单元测试
///
/// 严格复现 Dify graphon/utils/condition/processor.py 的 21 个算子行为。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/condition_processor.dart';
import 'package:novel_app/services/dsl_engine/models/segment.dart';
import 'package:novel_app/services/dsl_engine/models/variable_pool.dart';

void main() {
  late VariablePool pool;
  late ConditionProcessor processor;

  setUp(() {
    pool = VariablePool();
    processor = ConditionProcessor();
  });

  // -- Helper --
  Condition _cond(
    String op, {
    required List<String> selector,
    dynamic value,
  }) {
    return Condition(
      variableSelector: selector,
      comparisonOperator: op,
      value: value,
    );
  }

  group('String operators', () {
    test('contains: 字符串包含子串 → true', () {
      pool.add(['n', 'text'], 'hello world');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('contains', selector: ['n', 'text'], value: 'world')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('contains: 字符串不包含子串 → false', () {
      pool.add(['n', 'text'], 'hello');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('contains', selector: ['n', 'text'], value: 'xyz')],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });

    test('contains: 空字符串/falsy 值 → false (Dify 行为)', () {
      pool.add(['n', 'text'], '');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('contains', selector: ['n', 'text'], value: 'a')],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });

    test('contains: 数组包含元素 → true', () {
      pool.add(['n', 'tags'], ['a', 'b', 'c']);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('contains', selector: ['n', 'tags'], value: 'b')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('not contains: 字符串不包含 → true', () {
      pool.add(['n', 'text'], 'hello');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('not contains', selector: ['n', 'text'], value: 'xyz')
        ],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('not contains: 空字符串/falsy → true (Dify 行为)', () {
      pool.add(['n', 'text'], '');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('not contains', selector: ['n', 'text'], value: 'a')
        ],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('start with: 前缀匹配', () {
      pool.add(['n', 'text'], 'hello world');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('start with', selector: ['n', 'text'], value: 'hello')
        ],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('start with: 前缀不匹配', () {
      pool.add(['n', 'text'], 'world');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('start with', selector: ['n', 'text'], value: 'hello')
        ],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });

    test('end with: 后缀匹配', () {
      pool.add(['n', 'text'], 'hello world');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('end with', selector: ['n', 'text'], value: 'world')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('end with: 后缀不匹配', () {
      pool.add(['n', 'text'], 'hello');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('end with', selector: ['n', 'text'], value: 'world')],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });
  });

  group('is / is not operators', () {
    test('is: 字符串完全匹配 → true', () {
      pool.add(['n', 'text'], 'abc');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('is', selector: ['n', 'text'], value: 'abc')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('is: 字符串不完全匹配 → false', () {
      pool.add(['n', 'text'], 'abc');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('is', selector: ['n', 'text'], value: 'abd')],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });

    test('is: NoneSegment (value=null) → false', () {
      pool.add(['n', 'text'], null);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('is', selector: ['n', 'text'], value: 'abc')],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });

    test('is: boolean false 匹配 "false" 字符串 → true', () {
      pool.add(['n', 'b'], false);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('is', selector: ['n', 'b'], value: 'false')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('is: boolean true 匹配 "true" 字符串 → true', () {
      pool.add(['n', 'b'], true);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('is', selector: ['n', 'b'], value: 'true')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('is not: 字符串不完全匹配 → true', () {
      pool.add(['n', 'text'], 'abc');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('is not', selector: ['n', 'text'], value: 'abd')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('is not: boolean true 匹配 "false" → true', () {
      pool.add(['n', 'b'], true);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('is not', selector: ['n', 'b'], value: 'false')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });
  });

  group('empty / not empty operators', () {
    test('empty: 空字符串 → true', () {
      pool.add(['n', 'text'], '');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('empty', selector: ['n', 'text'])],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('empty: null → true', () {
      pool.add(['n', 'text'], null);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('empty', selector: ['n', 'text'])],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('empty: 非空字符串 → false', () {
      pool.add(['n', 'text'], 'abc');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('empty', selector: ['n', 'text'])],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });

    test('not empty: 非空字符串 → true', () {
      pool.add(['n', 'text'], 'abc');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('not empty', selector: ['n', 'text'])],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('not empty: 空字符串 → false', () {
      pool.add(['n', 'text'], '');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('not empty', selector: ['n', 'text'])],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });
  });

  group('Number operators (= ≠ > < ≥ ≤)', () {
    test('=: 整数匹配 → true', () {
      pool.add(['n', 'v'], 22);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('=', selector: ['n', 'v'], value: '22')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('=: 整数不匹配 → false', () {
      pool.add(['n', 'v'], 22);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('=', selector: ['n', 'v'], value: '23')],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });

    test('≠: 整数不等 → true', () {
      pool.add(['n', 'v'], 23);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('≠', selector: ['n', 'v'], value: '22')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('>: 大于', () {
      pool.add(['n', 'v'], 23);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('>', selector: ['n', 'v'], value: '22')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('<: 小于', () {
      pool.add(['n', 'v'], 21);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('<', selector: ['n', 'v'], value: '22')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('≥: 大于等于 (边界值)', () {
      pool.add(['n', 'v'], 22);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('≥', selector: ['n', 'v'], value: '22')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('≤: 小于等于 (边界值)', () {
      pool.add(['n', 'v'], 21);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('≤', selector: ['n', 'v'], value: '21')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('浮点数比较: 1.1 ≥ 0.95 → true', () {
      pool.add(['n', 'v'], 1.1);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('≥', selector: ['n', 'v'], value: '0.95')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('整数 0 ≤ 0.95 → true (int 自动转 float)', () {
      pool.add(['n', 'v'], 0);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('≤', selector: ['n', 'v'], value: '0.95')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });
  });

  group('null / not null operators', () {
    test('null: NoneSegment → true', () {
      pool.add(['n', 'v'], null);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('null', selector: ['n', 'v'])],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('null: 非空 → false', () {
      pool.add(['n', 'v'], 'abc');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('null', selector: ['n', 'v'])],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });

    test('not null: 非空 → true', () {
      pool.add(['n', 'v'], 'abc');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('not null', selector: ['n', 'v'])],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('not null: null → false', () {
      pool.add(['n', 'v'], null);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('not null', selector: ['n', 'v'])],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });
  });

  group('in / not in operators', () {
    test('in: 值在列表中 → true', () {
      pool.add(['n', 'v'], 'b');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('in', selector: ['n', 'v'], value: ['a', 'b', 'c'])
        ],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('in: 值不在列表中 → false', () {
      pool.add(['n', 'v'], 'd');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('in', selector: ['n', 'v'], value: ['a', 'b', 'c'])
        ],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });

    test('not in: 值不在列表中 → true', () {
      pool.add(['n', 'v'], 'd');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('not in', selector: ['n', 'v'], value: ['a', 'b', 'c'])
        ],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('not in: 空/falsy value → true (Dify 行为)', () {
      pool.add(['n', 'v'], '');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('not in', selector: ['n', 'v'], value: ['a', 'b'])
        ],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });
  });

  group('all of operator', () {
    test('all of: 列表中所有期望值都存在 → true', () {
      pool.add(['n', 'tags'], ['a', 'b', 'c', 'd']);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('all of', selector: ['n', 'tags'], value: ['a', 'c'])
        ],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('all of: 期望值缺失 → false', () {
      pool.add(['n', 'tags'], ['a', 'b']);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('all of', selector: ['n', 'tags'], value: ['a', 'c'])
        ],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });

    test('all of: 字符串包含所有字符 → true', () {
      pool.add(['n', 's'], 'abc');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('all of', selector: ['n', 's'], value: ['a', 'c'])
        ],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });
  });

  group('exists / not exists operators', () {
    test('exists: 变量存在 → true', () {
      pool.add(['n', 'v'], 'abc');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('exists', selector: ['n', 'v'])],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('exists: NoneSegment (null) → false', () {
      pool.add(['n', 'v'], null);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('exists', selector: ['n', 'v'])],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });

    test('not exists: NoneSegment → true', () {
      pool.add(['n', 'v'], null);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('not exists', selector: ['n', 'v'])],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('exists: 变量不存在于池中 → false', () {
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('exists', selector: ['n', 'missing'])],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
    });
  });

  group('Logical operator: and / or', () {
    test('and 短路求值: 第一个为 false 时直接返回', () {
      // 用一个会抛错的 condition 来验证短路：不应该执行到第二个
      pool.add(['n', 'a'], 'x');
      pool.add(['n', 'b'], 'y');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('contains', selector: ['n', 'a'], value: 'X'),
          _cond('contains', selector: ['n', 'b'], value: 'y'),
        ],
        operator: 'and',
      );
      expect(r.finalResult, isFalse);
      // 第一个 condition 失败后，第二个不应该被评估
      expect(r.groupResults.length, 1);
    });

    test('and 全部为 true → true', () {
      pool.add(['n', 'a'], 'x');
      pool.add(['n', 'b'], 'y');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('contains', selector: ['n', 'a'], value: 'x'),
          _cond('contains', selector: ['n', 'b'], value: 'y'),
        ],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('or 短路求值: 第一个为 true 时直接返回', () {
      pool.add(['n', 'a'], 'x');
      pool.add(['n', 'b'], 'y');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('contains', selector: ['n', 'a'], value: 'x'),
          _cond('contains', selector: ['n', 'b'], value: 'Y'),
        ],
        operator: 'or',
      );
      expect(r.finalResult, isTrue);
      expect(r.groupResults.length, 1);
    });

    test('or 全部为 false → false', () {
      pool.add(['n', 'a'], 'x');
      pool.add(['n', 'b'], 'y');
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('contains', selector: ['n', 'a'], value: 'X'),
          _cond('contains', selector: ['n', 'b'], value: 'Y'),
        ],
        operator: 'or',
      );
      expect(r.finalResult, isFalse);
    });
  });

  group('Template substitution in expected value', () {
    test('expected value 中的 {{#...#}} 占位符被解析', () {
      pool.add(['n', 'text'], 'hello');
      pool.add(['n', 'expected'], 'hello');
      // expected value 通过 convert_template 解析为 "hello"
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [
          _cond('is', selector: ['n', 'text'], value: '{{#n.expected#}}')
        ],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });
  });

  group('Boolean expected value handling', () {
    test('"is" 操作符 + boolean 值 + "1" → true (Dify 行为)', () {
      pool.add(['n', 'v'], true);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('=', selector: ['n', 'v'], value: '1')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });

    test('"is" 操作符 + boolean false + "0" → true', () {
      pool.add(['n', 'v'], false);
      final r = processor.processConditions(
        variablePool: pool,
        conditions: [_cond('=', selector: ['n', 'v'], value: '0')],
        operator: 'and',
      );
      expect(r.finalResult, isTrue);
    });
  });

  group('Error handling', () {
    test('变量不存在 → 抛 ValueError', () {
      expect(
        () => processor.processConditions(
          variablePool: pool,
          conditions: [_cond('contains', selector: ['n', 'missing'], value: 'a')],
          operator: 'and',
        ),
        throwsA(isA<ValueError>()),
      );
    });

    test('"start with" 操作符 + 非字符串值 → 抛 ConditionTypeError', () {
      pool.add(['n', 'v'], 123);
      // 数值不能 start with，需要类型检查
      // Dify 行为: TypeError
      expect(
        () => processor.processConditions(
          variablePool: pool,
          conditions: [
            _cond('start with', selector: ['n', 'v'], value: 'abc')
          ],
          operator: 'and',
        ),
        throwsA(isA<ConditionTypeError>()),
      );
    });
  });
}
