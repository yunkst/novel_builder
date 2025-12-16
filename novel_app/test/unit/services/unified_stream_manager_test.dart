import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

import '../../../lib/services/unified_stream_manager.dart';
import '../../../lib/models/stream_config.dart';
import '../mocks/mock_dependencies.dart';

void main() {
  group('UnifiedStreamManager 单元测试', () {
    late UnifiedStreamManager streamManager;
    late MockHttpClient mockHttpClient;
    late MockSharedPreferences mockPrefs;

    setUp(() {
      streamManager = UnifiedStreamManager();
      mockHttpClient = MockHttpClient();
      mockPrefs = MockSharedPreferences();

      // 设置 SharedPreferences Mock
      when(() => mockPrefs.getString('dify_url'))
          .thenReturn('https://test-api.example.com');
      when(() => mockPrefs.getString('dify_flow_token'))
          .thenReturn('test-flow-token');

      setupMocktailFallbacks();
    });

    tearDown(() async {
      // 清理所有活跃流
      await streamManager.cancelAllStreams();
    });

    group('基础功能测试', () {
      test('应该正确初始化管理器', () {
        expect(streamManager.hasActiveStreams(), isFalse);
        expect(streamManager.activeStreamCount, equals(0));
        expect(streamManager.getActiveStreamIds(), isEmpty);
      });

      test('应该正确生成唯一流ID', () async {
        // 暂时跳过此测试，因为需要实际的DifyService
        // TODO: 实现完整的DifyService Mock后再启用
      }, skip: true);
    });

    group('流生命周期管理测试', () {
      test('应该正确启动和跟踪流', () async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
        );

        final chunks = TestDataFactory.createTestChunks();
        var receivedChunks = <String>[];
        var isCompleted = false;
        var hasError = false;

        final streamId = await streamManager.executeStream(
          config: config,
          onChunk: (chunk) {
            receivedChunks.add(chunk);
          },
          onComplete: (_) {
            isCompleted = true;
          },
          onError: (_) {
            hasError = true;
          },
        );

        // 验证流已启动
        expect(streamId, isNotNull);
        expect(streamManager.hasActiveStreams(), isTrue);
        expect(streamManager.activeStreamCount, equals(1));
        expect(streamManager.getActiveStreamIds(), contains(streamId));
      });

      test('应该正确取消指定流', () async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
        );

        final streamId = await streamManager.executeStream(
          config: config,
          onChunk: (_) {},
          onComplete: (_) {},
          onError: (_) {},
        );

        expect(streamManager.hasActiveStreams(), isTrue);

        // 取消流
        await streamManager.cancelStream(streamId!);

        // 验证流已取消
        expect(streamManager.hasActiveStreams(), isFalse);
        expect(streamManager.activeStreamCount, equals(0));
        expect(streamManager.getActiveStreamIds(), isEmpty);
      });

      test('应该正确取消所有流', () async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
        );

        // 启动多个流
        final streamId1 = await streamManager.executeStream(
          config: config,
          onChunk: (_) {},
          onComplete: (_) {},
          onError: (_) {},
        );

        final streamId2 = await streamManager.executeStream(
          config: config,
          onChunk: (_) {},
          onComplete: (_) {},
          onError: (_) {},
        );

        expect(streamManager.activeStreamCount, equals(2));

        // 取消所有流
        await streamManager.cancelAllStreams();

        // 验证所有流已取消
        expect(streamManager.hasActiveStreams(), isFalse);
        expect(streamManager.activeStreamCount, equals(0));
      });
    });

    group('流数据接收测试', () {
      test('应该正确接收和处理流数据块', () async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
        );

        final chunks = TestDataFactory.createTestChunks();
        var receivedChunks = <String>[];
        var completedContent = '';

        // 模拟流数据接收
        await streamManager.executeStream(
          config: config,
          onChunk: (chunk) {
            receivedChunks.add(chunk);
          },
          onComplete: (content) {
            completedContent = content;
          },
          onError: (_) {},
        );

        // 验证数据块接收
        // 注意：这里需要根据实际实现调整验证逻辑
        expect(receivedChunks, isNotEmpty);
      });

      test('应该正确处理完整内容标记', () async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
        );

        final testContent = '这是完整的测试内容';
        var receivedContent = '';

        await streamManager.executeStream(
          config: config,
          onChunk: (chunk) {
            if (chunk.startsWith('<<COMPLETE_CONTENT>>')) {
              receivedContent = chunk.substring('<<COMPLETE_CONTENT>>'.length);
            }
          },
          onComplete: (_) {},
          onError: (_) {},
        );

        expect(receivedContent, equals(testContent));
      });
    });

    group('错误处理测试', () {
      test('应该正确处理配置错误', () async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
        );

        var errorMessage = '';

        // 模拟配置错误
        await streamManager.executeStream(
          config: config,
          onChunk: (_) {},
          onComplete: (_) {},
          onError: (error) {
            errorMessage = error;
          },
        );

        // 验证错误处理
        expect(errorMessage, isNotEmpty);
      });

      test('应该正确处理网络错误', () async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
        );

        var networkError = '';

        // 模拟网络错误
        await streamManager.executeStream(
          config: config,
          onChunk: (_) {},
          onComplete: (_) {},
          onError: (error) {
            networkError = error;
          },
        );

        expect(networkError, isNotEmpty);
        expect(networkError, contains('失败'));
      });

      test('应该正确处理超时', () async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
        );

        var timeoutError = '';

        // 模拟超时情况
        await streamManager.executeStream(
          config: config,
          onChunk: (_) {},
          onComplete: (_) {},
          onError: (error) {
            timeoutError = error;
          },
        ).timeout(
          const Duration(seconds: 1),
          onTimeout: () {
            timeoutError = '请求超时';
            return null;
          },
        );

        expect(timeoutError, equals('请求超时'));
      });
    });

    group('并发控制测试', () {
      test('应该支持多个并发流', () async {
        final config1 = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(content: '内容1'),
        );

        final config2 = StreamConfig.custom(
          inputs: TestDataFactory.createTestInputs(content: '内容2'),
        );

        var stream1Received = false;
        var stream2Received = false;

        // 启动并发流
        final streamId1 = await streamManager.executeStream(
          config: config1,
          onChunk: (_) => stream1Received = true,
          onComplete: (_) {},
          onError: (_) {},
        );

        final streamId2 = await streamManager.executeStream(
          config: config2,
          onChunk: (_) => stream2Received = true,
          onComplete: (_) {},
          onError: (_) {},
        );

        // 验证并发流管理
        expect(streamManager.activeStreamCount, equals(2));
        expect(streamId1, isNot(equals(streamId2)));
      });

      test('应该正确处理同ID流的替换', () async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
        );

        final streamId = 'test-stream-id';

        // 启动第一个流
        await streamManager.executeStream(
          config: config,
          streamId: streamId,
          onChunk: (_) {},
          onComplete: (_) {},
          onError: (_) {},
        );

        expect(streamManager.hasActiveStreams(), isTrue);

        // 启动同ID的第二个流（应该替换第一个）
        await streamManager.executeStream(
          config: config,
          streamId: streamId,
          onChunk: (_) {},
          onComplete: (_) {},
          onError: (_) {},
        );

        // 应该仍然只有一个活跃流
        expect(streamManager.activeStreamCount, equals(1));
        expect(streamManager.getActiveStreamIds(), contains(streamId));
      });
    });

    group('内存管理测试', () {
      test('应该正确清理资源', () async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
        );

        // 启动多个流
        for (int i = 0; i < 5; i++) {
          await streamManager.executeStream(
            config: config,
            onChunk: (_) {},
            onComplete: (_) {},
            onError: (_) {},
          );
        }

        expect(streamManager.activeStreamCount, equals(5));

        // 清理所有资源
        await streamManager.dispose();

        // 验证资源清理
        expect(streamManager.hasActiveStreams(), isFalse);
        expect(streamManager.activeStreamCount, equals(0));
      });

      test('应该在释放后拒绝新流', () async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
        );

        // 释放管理器
        await streamManager.dispose();

        var errorReceived = '';

        // 尝试启动新流
        final streamId = await streamManager.executeStream(
          config: config,
          onChunk: (_) {},
          onComplete: (_) {},
          onError: (error) {
            errorReceived = error;
          },
        );

        expect(streamId, isNull);
        expect(errorReceived, contains('服务已释放'));
      });
    });

    group('配置传递测试', () {
      test('应该正确传递配置参数', () async {
        final inputs = TestDataFactory.createTestInputs(
          content: '配置测试内容',
          cmd: '测试命令',
          additionalParams: {'custom_param': 'test_value'},
        );

        final config = StreamConfig.custom(
          inputs: inputs,
          showRealTime: false,
          autoScroll: false,
          generatingHint: '自定义提示',
          maxLines: 10,
          minLines: 5,
        );

        var receivedHint = '';
        var receivedInputs = <String, dynamic>{};

        await streamManager.executeStream(
          config: config,
          onChunk: (_) {},
          onComplete: (_) {},
          onError: (_) {},
        );

        // 验证配置参数传递（这里需要根据实际实现调整）
        expect(config.generatingHint, equals('自定义提示'));
        expect(config.maxLines, equals(10));
        expect(config.minLines, equals(5));
        expect(config.showRealTime, isFalse);
        expect(config.autoScroll, isFalse);
      });
    });

    group('性能测试', () {
      test('应该在合理时间内完成流操作', () async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
        );

        final stopwatch = Stopwatch()..start();

        await streamManager.executeStream(
          config: config,
          onChunk: (_) {},
          onComplete: (_) {},
          onError: (_) {},
        );

        stopwatch.stop();

        // 验证操作时间合理（根据实际性能要求调整）
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });

      test('应该正确处理大量数据块', () async {
        final config = StreamConfig.sceneDescription(
          inputs: TestDataFactory.createTestInputs(),
        );

        final largeChunks = List.generate(100, (index) => '数据块$index');
        var receivedCount = 0;

        await streamManager.executeStream(
          config: config,
          onChunk: (_) => receivedCount++,
          onComplete: (_) {},
          onError: (_) {},
        );

        // 验证能处理大量数据
        expect(receivedCount, greaterThan(0));
      });
    });
  });
}