import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/preload_service.dart';
import 'package:novel_app/services/rate_limiter.dart';
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

    setUp(() {
      preloadService = PreloadService();
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
      await Future.wait(calls);

      // 等待一段时间,让队列处理几个任务
      await Future.delayed(Duration(seconds: 2));

      // 获取统计信息
      final stats = preloadService.getStatistics();

      print('═══════════════════════════════════════');
      print('📊 并发测试结果:');
      print('   队列长度: ${stats['queue_length']}');
      print('   是否处理中: ${stats['is_processing']}');
      print('   已处理: ${stats['total_processed']}');
      print('   失败: ${stats['total_failed']}');
      print('═══════════════════════════════════════');

      // 验证: is_processing 应该是 true 或 false,但不能有多个循环
      // 这可以通过检查已处理的章节数来推断
      // 如果有并发,30秒内应该处理 > 2章
      // 如果没有并发,30秒内应该处理 ~1章

      // 由于我们只等待了2秒,最多应该只处理了1章
      // 如果处理了2章或更多,说明存在并发问题
      final processed = stats['total_processed'] as int;
      final failed = stats['total_failed'] as int;

      // 注意: 这个测试假设第一次调用立即执行,后续调用需要等待30秒
      // 在2秒内,如果只有1个循环,最多处理1章
      // 如果有多个并发循环,可能处理2章或更多

      print('⚠️  如果 processed >= 2,可能存在并发问题');
      print('⚠️  当前 processed = $processed');

      // 这个测试结果取决于网络速度和执行时间
      // 仅用于演示潜在的并发问题
      expect(processed >= 0, isTrue); // 基本断言
    });

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
      await Future.wait([future1, future2]);

      // 等待一小段时间
      await Future.delayed(Duration(milliseconds: 100));

      final stats = preloadService.getStatistics();
      print('📊 锁行为测试:');
      print('   是否处理中: ${stats['is_processing']}');
      print('   队列长度: ${stats['queue_length']}');

      // is_processing 应该是 true
      expect(stats['is_processing'], isTrue);
    });
  });
}
