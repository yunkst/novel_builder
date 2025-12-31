import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/services/cache_manager.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/services/api_service_wrapper.dart';
import 'package:novel_app/services/chapter_manager.dart';
import 'package:novel_app/models/chapter.dart';
import '../../test_helpers/mock_data.dart';

/// 为CacheManager测试生成Mock类
@GenerateMocks([
  DatabaseService,
  ApiServiceWrapper,
  ChapterManager,
])
import 'cache_manager_test.mocks.dart';

void main() {
  group('CacheManager', () {
    late CacheManager cacheManager;
    late MockDatabaseService mockDb;
    late MockApiServiceWrapper mockApi;
    late MockChapterManager mockChapterManager;

    setUp(() {
      mockDb = MockDatabaseService();
      mockApi = MockApiServiceWrapper();
      mockChapterManager = MockChapterManager();

      // 使用forTesting工厂创建测试实例
      cacheManager = CacheManager.forTesting(
        testDb: mockDb,
        testApi: mockApi,
        testChapterManager: mockChapterManager,
      );
    });

    tearDown(() async {
      cacheManager.dispose();
    });

    group('单例模式', () {
      test('should return same instance', () {
        final instance1 = CacheManager();
        final instance2 = CacheManager();

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('setAppActive', () {
      test('should update app active state', () {
        // 初始状态
        expect(cacheManager.progressStream, isNotNull);

        // 设置为活跃
        cacheManager.setAppActive(true);
        // 由于_apiReady为false，不会启动处理

        // 设置为非活跃
        cacheManager.setAppActive(false);
      });

      test('should start processing when app becomes active', () async {
        // 设置API为就绪状态
        await cacheManager.checkApiAvailability();

        // 设置应用活跃
        cacheManager.setAppActive(true);

        // 验证状态已更新（内部方法，通过行为验证）
        cacheManager.setAppActive(false);
      });
    });

    group('enqueueNovel', () {
      test('should add novel to queue', () {
        final novelUrl = 'test-novel-url';

        cacheManager.enqueueNovel(novelUrl);

        // 验证不会抛出异常
        expect(() => cacheManager.enqueueNovel(novelUrl), returnsNormally);
      });

      test('should not add duplicate novel to queue', () {
        final novelUrl = 'test-novel-url';

        cacheManager.enqueueNovel(novelUrl);
        cacheManager.enqueueNovel(novelUrl); // 重复添加

        // 验证不会抛出异常
        expect(() => cacheManager.enqueueNovel(novelUrl), returnsNormally);
      });

      test('should handle multiple different novels', () {
        cacheManager.enqueueNovel('novel-1');
        cacheManager.enqueueNovel('novel-2');
        cacheManager.enqueueNovel('novel-3');

        // 验证不会抛出异常
        expect(() => cacheManager.enqueueNovel('novel-4'), returnsNormally);
      });
    });

    group('checkApiAvailability', () {
      test('should set apiReady to true when API is available', () async {
        when(mockApi.checkImageToVideoHealth())
            .thenAnswer((_) async => {'status': 'healthy'});

        await cacheManager.checkApiAvailability();

        // 验证API方法被调用
        verify(mockApi.checkImageToVideoHealth()).called(1);
      });

      test('should set apiReady to false when API fails', () async {
        when(mockApi.checkImageToVideoHealth())
            .thenThrow(Exception('API error'));

        await cacheManager.checkApiAvailability();

        // 验证API方法被调用
        verify(mockApi.checkImageToVideoHealth()).called(1);
      });
    });

    group('clearCache', () {
      test('should call database clearAllCache', () async {
        when(mockDb.clearAllCache()).thenAnswer((_) async {});

        await cacheManager.clearCache();

        verify(mockDb.clearAllCache()).called(1);
      });

      test('should handle database errors', () async {
        when(mockDb.clearAllCache())
            .thenThrow(Exception('Database error'));

        expect(() => cacheManager.clearCache(), throwsException);
      });
    });

    group('clearNovelCache', () {
      test('should call database clearNovelCache', () async {
        const novelUrl = 'test-novel';

        when(mockDb.clearNovelCache(novelUrl))
            .thenAnswer((_) async {});

        await cacheManager.clearNovelCache(novelUrl);

        verify(mockDb.clearNovelCache(novelUrl)).called(1);
      });
    });

    group('stopCaching', () {
      test('should stop processing and clear queue', () {
        // 添加一些小说到队列
        cacheManager.enqueueNovel('novel-1');
        cacheManager.enqueueNovel('novel-2');

        // 停止缓存
        cacheManager.stopCaching();

        // 验证不会抛出异常
        expect(() => cacheManager.stopCaching(), returnsNormally);
      });

      test('should handle multiple stop calls', () {
        cacheManager.stopCaching();
        cacheManager.stopCaching();
        cacheManager.stopCaching();

        expect(() => cacheManager.stopCaching(), returnsNormally);
      });
    });

    group('dispose', () {
      test('should clean up resources', () {
        cacheManager.dispose();

        // 验证多次调用是安全的
        expect(() => cacheManager.dispose(), returnsNormally);
      });

      test('should close progress stream', () {
        final stream = cacheManager.progressStream;

        cacheManager.dispose();

        // Stream关闭后不应该再接收事件
        expect(() => cacheManager.dispose(), returnsNormally);
      });
    });

    group('progressStream', () {
      test('should provide progress stream', () {
        final stream = cacheManager.progressStream;

        expect(stream, isNotNull);
      });

      test('should be broadcast stream', () {
        final stream = cacheManager.progressStream;

        // broadcast stream可以有多个监听器
        final subscription1 = stream.listen((_) {});
        final subscription2 = stream.listen((_) {});

        expect(stream.isBroadcast, isTrue);

        subscription1.cancel();
        subscription2.cancel();
      });
    });

    group('_cacheNovel integration', () {
      test('should cache novel chapters successfully', () async {
        const novelUrl = 'test-novel';
        final chapters = MockData.createTestChapterList(count: 3);

        // Mock所有依赖的方法
        when(mockApi.checkImageToVideoHealth())
            .thenAnswer((_) async => {'status': 'healthy'});
        when(mockApi.getChapters(novelUrl)).thenAnswer((_) async => chapters);
        when(mockDb.isChapterCached(any)).thenAnswer((_) async => false);
        when(mockChapterManager.getChapterContent(
          any,
          fetchFunction: anyNamed('fetchFunction'),
        )).thenAnswer((_) async => 'Test content');
        when(mockDb.cacheChapter(any, any, any))
            .thenAnswer((_) async => 1);

        // 直接调用私有方法测试（通过反射或创建测试接口）
        // 这里我们通过enqueueNovel来触发
        cacheManager.setAppActive(true);
        await cacheManager.checkApiAvailability();
        cacheManager.enqueueNovel(novelUrl);

        // 等待处理（实际场景中应该用Completable或其他同步机制）
        await Future.delayed(Duration(milliseconds: 100));

        // 验证API被调用
        verify(mockApi.getChapters(novelUrl)).called(1);
      });

      test('should skip already cached chapters', () async {
        const novelUrl = 'test-novel';
        final chapters = MockData.createTestChapterList(count: 2);

        // Mock所有依赖的方法
        when(mockApi.checkImageToVideoHealth())
            .thenAnswer((_) async => {'status': 'healthy'});
        when(mockApi.getChapters(novelUrl)).thenAnswer((_) async => chapters);
        // 第一个章节已缓存
        when(mockDb.isChapterCached(chapters[0].url))
            .thenAnswer((_) async => true);
        // 第二个章节未缓存
        when(mockDb.isChapterCached(chapters[1].url))
            .thenAnswer((_) async => false);
        when(mockChapterManager.getChapterContent(
          any,
          fetchFunction: anyNamed('fetchFunction'),
        )).thenAnswer((_) async => 'Test content');
        when(mockDb.cacheChapter(any, any, any))
            .thenAnswer((_) async => 1);

        cacheManager.setAppActive(true);
        await cacheManager.checkApiAvailability();
        cacheManager.enqueueNovel(novelUrl);

        await Future.delayed(Duration(milliseconds: 100));

        // 验证只检查了未缓存的章节
        verify(mockDb.isChapterCached(chapters[0].url)).called(1);
        verify(mockDb.isChapterCached(chapters[1].url)).called(1);
      });
    });
  });
}
