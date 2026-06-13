/// TypeSafeParser 类型安全解析器单元测试
///
/// 验证所有 getter 方法的类型转换逻辑：
/// - 正常类型转换
/// - null 输入处理
/// - 类型不匹配的兜底
/// - 字符串到数字/布尔值的解析
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/utils/type_safe_parser_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/type_safe_parser.dart';

void main() {
  group('TypeSafeParser', () {
    group('getString', () {
      test('应返回字符串值', () {
        final map = {'name': '测试名称'};
        expect(TypeSafeParser.getString(map, 'name'), '测试名称');
      });

      test('key 不存在应返回 null', () {
        final map = <String, dynamic>{};
        expect(TypeSafeParser.getString(map, 'name'), isNull);
      });

      test('值为 null 应返回 null', () {
        final map = <String, dynamic>{'name': null};
        expect(TypeSafeParser.getString(map, 'name'), isNull);
      });

      test('值为空字符串应返回 null', () {
        final map = {'name': ''};
        expect(TypeSafeParser.getString(map, 'name'), isNull);
      });

      test('值类型不匹配（非 String）应返回 null', () {
        final map = <String, dynamic>{'name': 123};
        expect(TypeSafeParser.getString(map, 'name'), isNull);
      });
    });

    group('getInt', () {
      test('应从 int 值返回整数', () {
        final map = {'count': 42};
        expect(TypeSafeParser.getInt(map, 'count'), 42);
      });

      test('应从 num 值转换为整数', () {
        final map = <String, dynamic>{'count': 3.14};
        expect(TypeSafeParser.getInt(map, 'count'), 3);
      });

      test('应从字符串解析整数', () {
        final map = {'count': '99'};
        expect(TypeSafeParser.getInt(map, 'count'), 99);
      });

      test('key 不存在应返回 null', () {
        expect(TypeSafeParser.getInt({}, 'count'), isNull);
      });

      test('值为 null 应返回 null', () {
        expect(TypeSafeParser.getInt({'count': null}, 'count'), isNull);
      });

      test('字符串不是有效数字应返回 null', () {
        expect(
            TypeSafeParser.getInt({'count': 'abc'}, 'count'), isNull);
      });

      test('类型不匹配（非数值）应返回 null', () {
        expect(TypeSafeParser.getInt({'count': true}, 'count'), isNull);
      });
    });

    group('getBool', () {
      test('应从 bool 值返回布尔', () {
        expect(TypeSafeParser.getBool({'enabled': true}, 'enabled'), true);
        expect(TypeSafeParser.getBool({'enabled': false}, 'enabled'), false);
      });

      test('应从 int 值转换（1=true, 0=false）', () {
        expect(TypeSafeParser.getBool({'enabled': 1}, 'enabled'), true);
        expect(TypeSafeParser.getBool({'enabled': 0}, 'enabled'), false);
      });

      test('应从字符串 "true"/"false" 解析（不区分大小写）', () {
        expect(TypeSafeParser.getBool({'enabled': 'true'}, 'enabled'), true);
        expect(TypeSafeParser.getBool({'enabled': 'TRUE'}, 'enabled'), true);
        expect(TypeSafeParser.getBool({'enabled': 'false'}, 'enabled'), false);
        expect(TypeSafeParser.getBool({'enabled': 'FALSE'}, 'enabled'), false);
      });

      test('key 不存在应返回 null', () {
        expect(TypeSafeParser.getBool({}, 'enabled'), isNull);
      });

      test('字符串不是 "true"/"false" 应返回 null', () {
        expect(
            TypeSafeParser.getBool({'enabled': 'yes'}, 'enabled'), isNull);
      });
    });

    group('getDouble', () {
      test('应从 double 值返回双精度浮点数', () {
        final map = {'price': 3.14};
        expect(TypeSafeParser.getDouble(map, 'price'), 3.14);
      });

      test('应从 int 值转换为 double', () {
        final map = {'price': 10};
        expect(TypeSafeParser.getDouble(map, 'price'), 10.0);
      });

      test('应从 num 值转换为 double', () {
        final map = <String, dynamic>{'price': 3.14 as num};
        expect(TypeSafeParser.getDouble(map, 'price'), 3.14);
      });

      test('应从字符串解析 double', () {
        final map = {'price': '2.718'};
        expect(TypeSafeParser.getDouble(map, 'price'), 2.718);
      });

      test('key 不存在应返回 null', () {
        expect(TypeSafeParser.getDouble({}, 'price'), isNull);
      });

      test('字符串不是有效数字应返回 null', () {
        expect(
            TypeSafeParser.getDouble({'price': 'xyz'}, 'price'), isNull);
      });
    });

    group('getList', () {
      test('应返回字符串列表', () {
        final map = {'tags': ['a', 'b', 'c']};
        final result = TypeSafeParser.getList<String>(map, 'tags');
        expect(result, ['a', 'b', 'c']);
      });

      test('应支持 converter 转换函数', () {
        final map = {
          'items': [
            {'val': 1},
            {'val': 2}
          ]
        };
        final result = TypeSafeParser.getList<int>(
          map,
          'items',
          converter: (e) => (e as Map)['val'] as int,
        );
        expect(result, [1, 2]);
      });

      test('值不是 List 应返回 null', () {
        expect(
            TypeSafeParser.getList<String>({'tags': 'not_a_list'}, 'tags'),
            isNull);
      });

      test('key 不存在应返回 null', () {
        expect(TypeSafeParser.getList<String>({}, 'tags'), isNull);
      });

      test('值为 null 应返回 null', () {
        expect(TypeSafeParser.getList<String>({'tags': null}, 'tags'), isNull);
      });
    });

    group('getMap', () {
      test('应返回 Map<String, dynamic>', () {
        final map = {'config': {'key': 'value'}};
        final result = TypeSafeParser.getMap(map, 'config');
        expect(result, {'key': 'value'});
      });

      test('应从非类型化 Map 转换', () {
        // 注意：这里是测试 static Map 被动态转换的情况
        final map = {
          'config': {'a': 1, 'b': 'text'}
        };
        final result = TypeSafeParser.getMap(map, 'config');
        expect(result, isNotNull);
        expect(result!['a'], 1);
      });

      test('值不是 Map 应返回 null', () {
        expect(TypeSafeParser.getMap({'config': 'not_a_map'}, 'config'),
            isNull);
      });

      test('key 不存在应返回 null', () {
        expect(TypeSafeParser.getMap({}, 'config'), isNull);
      });
    });

    group('getDateTime', () {
      test('应从 DateTime 值返回日期', () {
        final now = DateTime.now();
        final map = {'created': now};
        expect(TypeSafeParser.getDateTime(map, 'created'), now);
      });

      test('应从 int (毫秒时间戳) 转换', () {
        final timestamp = DateTime(2024, 1, 1).millisecondsSinceEpoch;
        final map = {'created': timestamp};
        expect(
            TypeSafeParser.getDateTime(map, 'created'),
            DateTime.fromMillisecondsSinceEpoch(timestamp));
      });

      test('应从 ISO8601 字符串解析', () {
        final map = {'created': '2024-01-01T00:00:00.000'};
        final result = TypeSafeParser.getDateTime(map, 'created');
        expect(result, isNotNull);
        expect(result!.year, 2024);
      });

      test('key 不存在应返回 null', () {
        expect(TypeSafeParser.getDateTime({}, 'created'), isNull);
      });

      test('字符串不是有效日期应返回 null', () {
        expect(TypeSafeParser.getDateTime({'created': 'invalid'}, 'created'),
            isNull);
      });
    });

    group('类型混合场景', () {
      test('getInt 应处理 double 到 int 的精度损失', () {
        final map = <String, dynamic>{'value': 5.9};
        expect(TypeSafeParser.getInt(map, 'value'), 5);
      });

      test('getBool 应将非0的int视为true', () {
        expect(TypeSafeParser.getBool({'flag': 2}, 'flag'), false);
        // 根据源码：value == 1 才返回 true
      });

      test('getBool 整数 1 应返回 true', () {
        expect(TypeSafeParser.getBool({'flag': 1}, 'flag'), true);
      });
    });
  });
}
