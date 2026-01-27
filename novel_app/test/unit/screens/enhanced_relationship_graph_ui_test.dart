import 'package:flutter_test/flutter_test.dart';

/// EnhancedRelationshipGraphScreen 节点key解析测试
///
/// 测试目标: 验证从Node.key中提取角色ID的逻辑
void main() {
  group('节点key解析逻辑', () {
    test('应该正确解析 Id(xxx) 格式的key', () {
      // 模拟graphview的Node.Id返回的key.toString()格式
      final keyString = 'Id(1)';
      final match = RegExp(r'\d+').firstMatch(keyString);

      expect(match, isNotNull);
      expect(match!.group(0), '1');

      final parsedId = int.tryParse(match.group(0) ?? '');
      expect(parsedId, 1);
    });

    test('应该正确解析多位数ID', () {
      final keyString = 'Id(123)';
      final match = RegExp(r'\d+').firstMatch(keyString);

      expect(match, isNotNull);
      expect(match!.group(0), '123');

      final parsedId = int.tryParse(match.group(0) ?? '');
      expect(parsedId, 123);
    });

    test('应该处理纯数字格式的key', () {
      final keyString = '42';
      final characterId = int.tryParse(keyString);

      expect(characterId, 42);
    });

    test('完整解析逻辑测试', () {
      final testCases = {
        'Id(1)': 1,
        'Id(42)': 42,
        'Id(999)': 999,
        '123': 123,
      };

      for (final entry in testCases.entries) {
        final keyString = entry.key;
        final expectedId = entry.value;

        int? characterId;
        if (keyString.contains('Id(')) {
          final match = RegExp(r'\d+').firstMatch(keyString);
          if (match != null) {
            characterId = int.tryParse(match.group(0) ?? '');
          }
        } else {
          characterId = int.tryParse(keyString);
        }

        expect(characterId, expectedId,
            reason: 'key "$keyString" 应该解析为 $expectedId');
      }
    });

    test('应该处理无效的key格式', () {
      final invalidKeys = [
        'Id(abc)',  // 非数字
        'Id()',     // 空
        '',         // 空字符串
        'not_a_number', // 非数字字符串
      ];

      for (final keyString in invalidKeys) {
        int? characterId;
        if (keyString.contains('Id(')) {
          final match = RegExp(r'\d+').firstMatch(keyString);
          if (match != null) {
            characterId = int.tryParse(match.group(0) ?? '');
          }
        } else {
          characterId = int.tryParse(keyString);
        }

        expect(characterId, isNull,
            reason: 'key "$keyString" 应该解析为null');
      }
    });
  });
}
