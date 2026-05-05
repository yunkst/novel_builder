import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/services/preload_service.dart';
import 'package:novel_app/services/preload_progress_update.dart';
import 'package:novel_app/repositories/chapter_repository.dart';
import 'package:novel_app/core/database/database_connection.dart';
import 'package:novel_app/models/chapter.dart';

import '../../helpers/test_database_setup.dart';
import 'test_helpers.mocks.dart' as test_mocks;

/// PreloadService 自动缓存功能诊断测试（简化版）
///
/// 目的：定位自动缓存功能失效的根因
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDatabaseSetup.init();

  late ChapterRepository chapterRepository;
  late test_mocks.MockApiServiceWrapper mockApiService;
  late PreloadService preloadService;
  late Database db;

  const testNovelUrl = 'https://example.com/novel/test';

  setUp(() async {
    db = await TestDatabaseSetup.createInMemoryDatabase();
    final connection = DatabaseConnection.forTesting(db);
    chapterRepository = ChapterRepository(dbConnection: connection);
    mockApiService = test_mocks.MockApiServiceWrapper();

    preloadService = PreloadService(
      apiService: mockApiService,
      chapterRepository: chapterRepository,
    );
  });

  tearDown(() async {
    preloadService.dispose();
    await db.close();
  });

  // ============================================================
  // 测试1: filterUncachedChapters 正确性
  // ============================================================
  group('ChapterRepository filterUncachedChapters', () {
    test('未缓存章节应该被正确识别', () async {
      final urls = ['https://example.com/uc1', 'https://example.com/uc2'];
      final uncached = await chapterRepository.filterUncachedChapters(urls);
      expect(uncached, hasLength(2));
    });

    test('已缓存章节应该被过滤掉', () async {
      final url = 'https://example.com/c1';
      await chapterRepository.cacheChapter(
        testNovelUrl,
        Chapter(url: url, title: '测试', content: '内容'),
        '内容',
      );
      final uncached = await chapterRepository.filterUncachedChapters([url]);
      expect(uncached, isEmpty);
    });
  });

  // ============================================================
  // 测试2: enqueueTasks 任务队列创建
  // ============================================================
  group('enqueueTasks 任务队列', () {
    test('未缓存章节应该被加入队列', () async {
      await preloadService.enqueueTasks(
        novelUrl: testNovelUrl,
        novelTitle: '测试',
        chapterUrls: ['https://example.com/q1', 'https://example.com/q2'],
        currentIndex: 0,
      );

      final stats = preloadService.getStatistics();
      expect(stats['queue_length'], greaterThan(0));
      expect(stats['enqueued_urls'], greaterThan(0));
    });

    test('已缓存章节不应被加入队列', () async {
      await chapterRepository.cacheChapter(
        testNovelUrl,
        Chapter(url: 'https://example.com/cached1', title: '测试', content: '内容'),
        '内容',
      );

      await preloadService.enqueueTasks(
        novelUrl: testNovelUrl,
        novelTitle: '测试',
        chapterUrls: ['https://example.com/cached1'],
        currentIndex: 0,
      );

      final stats = preloadService.getStatistics();
      expect(stats['queue_length'], 0);
    });
  });

  // ============================================================
  // 测试3: _processQueue 是否执行（核心诊断）
  // ============================================================
  group('_processQueue 执行诊断', () {
    test('步骤1: 验证队列非空时 _processQueue 被触发', () async {
      // Arrange
      final url = 'https://example.com/exec1';
      when(mockApiService.getChapterContent(url))
          .thenAnswer((_) async => '执行内容');

      // Act
      await preloadService.enqueueTasks(
        novelUrl: testNovelUrl,
        novelTitle: '测试',
        chapterUrls: [url],
        currentIndex: 0,
      );

      // 立即检查 isProcessing
      // _processQueue 是 fire-and-forget，可能正在执行
      print('--- 立即检查 ---');
      print('isProcessing: ${preloadService.isProcessing}');
      print('queueLength: ${preloadService.queueLength}');
      final stats0 = preloadService.getStatistics();
      print('stats: $stats0');

      // 等待1秒
      await Future.delayed(Duration(seconds: 1));

      print('--- 1秒后检查 ---');
      final stats1 = preloadService.getStatistics();
      print('isProcessing: ${preloadService.isProcessing}');
      print('stats: $stats1');

      // Assert: 检查是否处理了任务
      // 如果 mock 工作正常，total_processed 应该 > 0
      // 如果 mock 不工作，total_failed 应该 > 0
      // 如果两者都是 0，说明 _processQueue 没有执行
      final processed = stats1['total_processed'] as int;
      final failed = stats1['total_failed'] as int;
      print('processed: $processed, failed: $failed');

      // 无论成功失败，至少应该有某种记录
      expect(processed + failed, greaterThan(0),
          reason: '_processQueue 应该至少尝试处理一个任务');
    }, timeout: Timeout(Duration(seconds: 5)));

    test('步骤2: 直接验证 mock 是否被调用', () async {
      // Arrange
      final url = 'https://example.com/verify_mock';
      when(mockApiService.getChapterContent(url))
          .thenAnswer((_) async => 'mock内容');

      // Act
      await preloadService.enqueueTasks(
        novelUrl: testNovelUrl,
        novelTitle: '测试',
        chapterUrls: [url],
        currentIndex: 0,
      );

      await Future.delayed(Duration(seconds: 1));

      // Assert: 验证 mock 是否被调用
      verify(mockApiService.getChapterContent(url)).called(1);
    }, timeout: Timeout(Duration(seconds: 5)));

    test('步骤3: 验证缓存是否写入数据库', () async {
      // Arrange
      final url = 'https://example.com/verify_cache';
      when(mockApiService.getChapterContent(url))
          .thenAnswer((_) async => '缓存验证内容');

      // Act
      await preloadService.enqueueTasks(
        novelUrl: testNovelUrl,
        novelTitle: '测试',
        chapterUrls: [url],
        currentIndex: 0,
      );

      await Future.delayed(Duration(seconds: 1));

      // Assert: 直接查数据库
      final cached = await chapterRepository.getCachedChapter(url);
      print('cached content: $cached');

      expect(cached, isNotNull,
          reason: '章节应该被缓存到数据库');
      expect(cached, '缓存验证内容');
    }, timeout: Timeout(Duration(seconds: 5)));
  });

  // ============================================================
  // 测试4: 速率限制验证
  // ============================================================
  group('速率限制', () {
    test('第一个任务无延迟', () async {
      final url = 'https://example.com/rate1';
      when(mockApiService.getChapterContent(url))
          .thenAnswer((_) async => '内容');

      final start = DateTime.now();
      await preloadService.enqueueTasks(
        novelUrl: testNovelUrl,
        novelTitle: '测试',
        chapterUrls: [url],
        currentIndex: 0,
      );

      await Future.delayed(Duration(seconds: 1));

      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inSeconds, lessThan(3),
          reason: '第一个任务不应有30秒延迟');
    }, timeout: Timeout(Duration(seconds: 5)));
  });

  // ============================================================
  // 测试5: 进度流验证
  // ============================================================
  group('进度流', () {
    test('缓存完成后应该发出进度事件', () async {
      final url = 'https://example.com/progress1';
      when(mockApiService.getChapterContent(url))
          .thenAnswer((_) async => '内容');

      final events = <PreloadProgressUpdate>[];
      final sub = preloadService.progressStream.listen((e) => events.add(e));

      await preloadService.enqueueTasks(
        novelUrl: testNovelUrl,
        novelTitle: '测试',
        chapterUrls: [url],
        currentIndex: 0,
      );

      await Future.delayed(Duration(seconds: 1));

      print('progress events count: ${events.length}');
      for (final e in events) {
        print('  event: novelUrl=${e.novelUrl}, chapterUrl=${e.chapterUrl}');
      }

      expect(events, isNotEmpty,
          reason: '应该发出至少一个进度事件');

      await sub.cancel();
    }, timeout: Timeout(Duration(seconds: 5)));
  });

  // ============================================================
  // 测试6: ChapterRepository 内存缓存一致性
  // ============================================================
  group('ChapterRepository 内存缓存', () {
    test('缓存后 isChapterCached 立即返回 true', () async {
      final url = 'https://example.com/mem1';
      await chapterRepository.cacheChapter(
        testNovelUrl,
        Chapter(url: url, title: '测试', content: '内容'),
        '内容',
      );
      expect(await chapterRepository.isChapterCached(url), isTrue);
    });

    test('新实例仍能通过数据库查询到缓存', () async {
      final url = 'https://example.com/mem2';
      await chapterRepository.cacheChapter(
        testNovelUrl,
        Chapter(url: url, title: '测试', content: '内容'),
        '内容',
      );

      // 创建新实例（模拟 AutoDispose 重建）
      final conn = DatabaseConnection.forTesting(db);
      final newRepo = ChapterRepository(dbConnection: conn);
      expect(await newRepo.isChapterCached(url), isTrue);
    });
  });
}
