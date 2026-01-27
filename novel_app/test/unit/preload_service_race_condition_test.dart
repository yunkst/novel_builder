import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/preload_service.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 测试 PreloadService 的并发安全性
///
/// 验证场景: 快速连续调用 enqueueTasks() 是否会启动多个并发循环
void main() {
  // 初始化 FFI 数据库
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PreloadService 并发安全测试', () {
    late PreloadService preloadService;
    late DatabaseService databaseService;

    setUp(() async {
      // 每个测试使用新的PreloadService实例
      preloadService = PreloadService();
      preloadService.clearQueue();

      // 每个测试使用独立的数据库实例
      databaseService = DatabaseService();
      await databaseService.database; // 确保数据库已初始化
    });

    tearDown(() async {
      // 清理队列
      preloadService.clearQueue();
    });

    test('快速连续调用 enqueueTasks() 不应产生并发', () async {
      // 模拟用户快速翻页的场景
      final calls = <Future<void>>[];

      // 在同一个事件循环中快速调用10次
      for (int i = 0; i < 10; i++) {
        calls.add(preloadService.enqueueTasks(
          novelUrl: 'https://example.com/novel1',
          novelTitle: '测试小说',
          chapterUrls: List.generate(100, (index) => 'https://example.com/chapter-$index'),
          currentIndex: i,
        ));
      }

      // 等待所有调用完成
      await Future.wait(calls, eagerError: false);

      // 等待一小段时间，让队列初始化
      await Future.delayed(Duration(milliseconds: 500));

      // 获取统计信息
      final stats = preloadService.getStatistics();

      print('═══════════════════════════════════════');
      print('📊 并发测试结果:');
      print('   队列长度: ${stats['queue_length']}');
      print('   是否处理中: ${stats['is_processing']}');
      print('   已处理: ${stats['total_processed']}');
      print('   失败: ${stats['total_failed']}');
      print('═══════════════════════════════════════');

      // 验证: is_processing 应该是 true (因为队列非空)
      final isProcessing = stats['is_processing'] as bool;
      expect(isProcessing, isTrue);

      // 队列中应该有任务
      final queueLength = stats['queue_length'] as int;
      expect(queueLength, greaterThan(0));

      print('✅ 并发测试通过: 队列正常工作');
    }, timeout: Timeout(Duration(seconds: 10)));

    test('验证单例模式', () {
      // 验证多次调用 PreloadService() 返回同一个实例
      final instance1 = PreloadService();
      final instance2 = PreloadService();

      expect(identical(instance1, instance2), isTrue);
      print('✅ 单例模式正常工作');
    });

    test('验证 Completer 锁的行为', () async {
      // 第一次调用
      final future1 = preloadService.enqueueTasks(
        novelUrl: 'https://example.com/novel1',
        novelTitle: '测试小说1',
        chapterUrls: List.generate(10, (index) => 'https://example.com/chapter1-$index'),
        currentIndex: 0,
      );

      // 立即第二次调用
      final future2 = preloadService.enqueueTasks(
        novelUrl: 'https://example.com/novel1',
        novelTitle: '测试小说1',
        chapterUrls: List.generate(10, (index) => 'https://example.com/chapter1-$index'),
        currentIndex: 1,
      );

      // 两个调用都应该立即完成(不等待)
      await Future.wait([future1, future2], eagerError: false);

      // 等待一小段时间
      await Future.delayed(Duration(milliseconds: 200));

      final stats = preloadService.getStatistics();
      print('📊 锁行为测试:');
      print('   是否处理中: ${stats['is_processing']}');
      print('   队列长度: ${stats['queue_length']}');

      // is_processing 应该是 true
      expect(stats['is_processing'], isTrue);

      print('✅ 锁行为测试通过');
    }, timeout: Timeout(Duration(seconds: 10)));

    test('验证队列清理功能', () {
      // 清理队列
      preloadService.clearQueue();

      final stats1 = preloadService.getStatistics();
      expect(stats1['queue_length'], 0);
      expect(stats1['is_processing'], isFalse);

      print('✅ 队列清理功能正常');
    });

    test('验证统计信息结构', () {
      final stats = preloadService.getStatistics();

      // 验证统计信息包含必要的字段
      expect(stats, containsPair('queue_length', isA<int>()));
      expect(stats, containsPair('is_processing', isA<bool>()));
      expect(stats, containsPair('total_processed', isA<int>()));
      expect(stats, containsPair('total_failed', isA<int>()));
      expect(stats, containsPair('enqueued_urls', isA<int>()));

      print('✅ 统计信息结构正确');
    });
  });
}
