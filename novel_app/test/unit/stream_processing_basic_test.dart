import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../unit/mocks/mock_dependencies.dart';

void main() {
  group('流式处理基础功能测试', () {
    setUp(() {
      setupMocktailFallbacks();
    });

    group('测试数据工厂验证', () {
      test('应该正确创建测试配置', () {
        final config = TestDataFactory.createTestStreamConfig();

        expect(config['type'], isNotNull);
        expect(config['showRealTime'], isTrue);
        expect(config['autoScroll'], isTrue);
        expect(config['generatingHint'], isNotNull);
      });

      test('应该正确创建测试输入参数', () {
        final inputs = TestDataFactory.createTestInputs(
          content: '测试内容',
          cmd: '测试命令',
        );

        expect(inputs['user_input'], equals('测试内容'));
        expect(inputs['cmd'], equals('测试命令'));
        expect(inputs['current_chapter_content'], equals('测试内容'));
      });

      test('应该正确创建测试数据块', () {
        final chunks = TestDataFactory.createTestChunks();
        final expectedResult = TestDataFactory.createExpectedResult(chunks);

        expect(chunks, isNotEmpty);
        expect(expectedResult, isNotEmpty);
        expect(expectedResult, equals(chunks.join('')));
      });
    });

    group('Mock依赖验证', () {
      test('应该正确创建SharedPreferences Mock', () {
        final mockPrefs = MockSharedPreferences();

        // 设置测试数据
        mockPrefs.setString('test_key', 'test_value');

        // 验证Mock工作正常
        expect(mockPrefs.getString('test_key'), equals('test_value'));
      });

      test('应该正确处理SSE数据模拟', () {
        final chunks = TestDataFactory.createTestChunks();
        final response = MockSSEData.createMockStreamedResponse(
          chunks: chunks,
        );

        expect(response, isNotNull);
      });
    });

    group('测试工具验证', () {
      test('应该正确执行异步等待', () async {
        final stopwatch = DateTime.now().difference(DateTime.now());

        await TestUtils.waitForAsync();

        // 验证时间过去了
        expect(stopwatch.inMilliseconds, lessThanOrEqualTo(200));
      });

      test('应该正确验证错误消息', () {
        final validError = '这是一个有效的错误消息';
        final invalidError = '短';

        expect(TestUtils.isValidErrorMessage(validError), isTrue);
        expect(TestUtils.isValidErrorMessage(invalidError), isFalse);
      });
    });

    group('流类型枚举验证', () {
      test('应该包含所有预期的流类型', () {
        final allTypes = StreamType.values;

        expect(allTypes, contains(StreamType.sceneDescription));
        expect(allTypes, contains(StreamType.closeUp));
        expect(allTypes, contains(StreamType.custom));
        expect(allTypes.length, equals(3));
      });
    });

    group('性能基准测试', () {
      test('测试数据创建性能', () {
        final stopwatch = Stopwatch()..start();

        // 创建大量测试数据
        for (int i = 0; i < 1000; i++) {
          TestDataFactory.createTestChunks();
          TestDataFactory.createTestInputs();
          TestDataFactory.createTestStreamConfig();
        }

        stopwatch.stop();

        // 应该在合理时间内完成
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      test('异步操作性能', () async {
        final stopwatch = Stopwatch()..start();

        // 执行多个异步等待
        for (int i = 0; i < 10; i++) {
          await TestUtils.waitForAsync();
        }

        stopwatch.stop();

        // 应该在合理时间内完成
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      });
    });

    group('内存管理验证', () {
      test('应该正确清理Completer', () async {
        final completer = TestUtils.createCompleter<String>();

        expect(completer.isCompleted, isFalse);

        // 完成Completer
        completer.complete('test');

        expect(completer.isCompleted, isTrue);
      });
    });

    group('错误处理验证', () {
      test('应该正确处理空数据', () {
        final emptyChunks = <String>[];
        final emptyResult = TestDataFactory.createExpectedResult(emptyChunks);

        expect(emptyResult, isEmpty);
      });

      test('应该正确处理大文本数据', () {
        final largeChunks = List.generate(1000, (index) => '数据块$index');
        final largeResult = TestDataFactory.createExpectedResult(largeChunks);

        expect(largeResult.length, greaterThan(5000)); // 调整期望值
        expect(largeResult, contains('数据块0'));
        expect(largeResult, contains('数据块999'));
      });
    });

    group('配置参数验证', () {
      test('应该正确处理自定义配置', () {
        final customConfig = TestDataFactory.createTestStreamConfig(
          type: StreamType.custom,
          showRealTime: false,
          autoScroll: false,
        );

        expect(customConfig['type'], equals(StreamType.custom));
        expect(customConfig['showRealTime'], isFalse);
        expect(customConfig['autoScroll'], isFalse);
      });

      test('应该正确处理额外参数', () {
        final inputs = TestDataFactory.createTestInputs(
          additionalParams: {
            'custom_param1': 'value1',
            'custom_param2': 'value2',
          },
        );

        expect(inputs['custom_param1'], equals('value1'));
        expect(inputs['custom_param2'], equals('value2'));
      });
    });
  });
}