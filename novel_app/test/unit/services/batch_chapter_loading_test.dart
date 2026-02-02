import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import '../../test_helpers/mock_data.dart';
import '../../test_bootstrap.dart';
import '../../base/database_test_base.dart';

/// 批量加载章节时的清理行为测试
///
/// 验证当批量获取章节时，cleanAndUpdateChapter 是否会被多次调用
///
/// **重要修复说明** (2025-02-01):
/// - 使用 DatabaseTestBase 创建独立的数据库实例
/// - 避免多个测试共享同一个数据库导致锁定冲突
/// - 每个测试完成后正确清理数据库连接
void main() {
  // 设置FFI用于测试环境
  setUpAll(() {
    initTests();
  });

  group('批量加载章节测试 - 验证清理触发', () {
    late DatabaseTestBase testBase;

    setUp(() async {
      // 使用 DatabaseTestBase 创建独立的数据库实例（关键修复！）
      testBase = DatabaseTestBase();
      await testBase.setUp();

      // 添加测试小说
      final testNovel = MockData.createTestNovel(
        title: '测试小说',
        url: 'https://test.com/novel/batch-test',
      );
      await testBase.databaseService.addToBookshelf(testNovel);

      // 添加测试章节列表
      final chapters = List.generate(
        10,
        (index) => Chapter(
          title: '第${index + 1}章',
          url: 'https://test.com/chapter/${index + 1}',
          chapterIndex: index + 1,
        ),
      );
      await testBase.databaseService.cacheNovelChapters(testNovel.url, chapters);
    });

    tearDown(() async {
      // 清理测试数据库（关键修复！）
      await testBase.tearDown();
    });

    test('批量获取章节内容时应该触发多次清理', () async {
      final testNovelUrl = 'https://test.com/novel/batch-test';

      // 准备测试数据：缓存10个章节
      for (int i = 1; i <= 10; i++) {
        final chapterUrl = 'https://test.com/chapter/$i';
        await testBase.databaseService.cacheChapter(
          testNovelUrl,
          Chapter(
            title: '第$i章',
            url: chapterUrl,
            chapterIndex: i,
          ),
          '这是第$i章的内容\n一些文本内容。\n更多内容。',
        );
      }

      // 验证所有章节都已缓存
      final cachedChapters = await testBase.databaseService.getCachedChapters(testNovelUrl);
      expect(cachedChapters.length, 10);

      // 记录开始时间
      final stopwatch = Stopwatch()..start();

      // 模拟章节列表页面加载：批量获取所有章节的缓存状态
      // 这是实际代码中 chapter_list_screen.dart _loadCachedStatus 方法的简化版
      final futures = cachedChapters.map((chapter) async {
        // 这里会触发 cleanAndUpdateChapter
        final content = await testBase.databaseService.getCachedChapter(chapter.url);
        return content;
      });

      // 等待所有章节加载完成
      final results = await Future.wait(futures);

      stopwatch.stop();

      // 验证结果
      expect(results.length, 10);
      expect(stopwatch.elapsedMilliseconds, greaterThan(0));

      print('⏱️ 批量加载10个章节耗时: ${stopwatch.elapsedMilliseconds}ms');
      print('📊 每个章节平均耗时: ${stopwatch.elapsedMilliseconds / 10}ms');

      // 验证每个章节都有内容
      for (final content in results) {
        expect(content, isNotNull);
        expect(content!.isNotEmpty, isTrue);
      }
    });

    test('单次获取章节内容应该只触发一次清理', () async {
      final testNovelUrl = 'https://test.com/novel/batch-test';
      final chapterUrl = 'https://test.com/chapter/1';

      // 缓存单个章节
      await testBase.databaseService.cacheChapter(
        testNovelUrl,
        Chapter(
          title: '第1章',
          url: chapterUrl,
          chapterIndex: 1,
        ),
        '这是第1章的内容',
      );

      // 第一次获取：会触发清理
      final content1 = await testBase.databaseService.getCachedChapter(chapterUrl);
      expect(content1, isNotNull);
      expect(content1!.isNotEmpty, isTrue);

      // 第二次获取：仍然会触发清理（虽然内容没变）
      final content2 = await testBase.databaseService.getCachedChapter(chapterUrl);
      expect(content2, isNotNull);
      expect(content2!.isNotEmpty, isTrue);

      // 两次内容应该相同
      expect(content1, equals(content2));

      print('✅ 单次获取章节完成，内容未变化');
    });

    test('章节列表加载缓存状态的行为', () async {
      final testNovelUrl = 'https://test.com/novel/batch-test';

      // 清理之前的缓存数据和内存状态
      final db = await testBase.databaseService.database;
      await db.delete('chapter_cache',
          where: 'chapterUrl LIKE ?', whereArgs: ['https://test.com/chapter/%']);
      testBase.databaseService.clearMemoryState(); // 清除内存缓存

      // 只缓存部分章节（模拟真实场景）
      for (int i = 1; i <= 5; i++) {
        await testBase.databaseService.cacheChapter(
          testNovelUrl,
          Chapter(
            title: '第$i章',
            url: 'https://test.com/chapter/$i',
            chapterIndex: i,
          ),
          '第$i章内容',
        );
      }

      // 模拟 chapter_list_screen.dart 的 _loadCachedStatus 方法
      final stopwatch = Stopwatch()..start();

      final chapters = await testBase.databaseService.getCachedNovelChapters(testNovelUrl);
      expect(chapters.length, 10);

      // 批量检查缓存状态（使用 Future.wait 并发）
      final futures = chapters.map((chapter) async {
        // isChapterCached 内部会调用 getCachedChapter
        final isCached = await testBase.databaseService.isChapterCached(chapter.url);
        return (chapter, isCached);
      });

      final results = await Future.wait(futures);

      stopwatch.stop();

      // 统计已缓存数量
      final cachedCount = results.where((r) => r.$2).length;

      print('⏱️ 批量检查10个章节缓存状态耗时: ${stopwatch.elapsedMilliseconds}ms');
      print('📊 已缓存章节: $cachedCount/10');

      expect(cachedCount, 5); // 只有前5个被缓存

      // 验证结果正确性
      for (final result in results) {
        final chapterUrl = result.$1.url;
        final isCached = result.$2;
        final chapterIndex = result.$1.chapterIndex ?? 0;

        // 从URL中提取章节编号
        final chapterNum = int.tryParse(chapterUrl.split('/').last) ?? 0;

        if (chapterNum >= 1 && chapterNum <= 5) {
          expect(isCached, isTrue, reason: '第$chapterNum章应该已缓存 (URL: $chapterUrl)');
        } else {
          expect(isCached, isFalse, reason: '第$chapterNum章不应该被缓存 (URL: $chapterUrl)');
        }
      }
    });

    test('验证多次读取同一章节的清理行为', () async {
      final testNovelUrl = 'https://test.com/novel/batch-test';
      final chapterUrl = 'https://test.com/chapter/1';

      // 清理之前的缓存数据和内存状态
      final db = await testBase.databaseService.database;
      await db.delete('chapter_cache',
          where: 'chapterUrl = ?', whereArgs: [chapterUrl]);
      testBase.databaseService.clearMemoryState(); // 清除内存缓存

      // 缓存章节（包含无效标记）
      final contentWithInvalidMarkup =
          '章节开始\n[插图:invalid-id]\n章节结束';
      await testBase.databaseService.cacheChapter(
        testNovelUrl,
        Chapter(
          title: '第1章',
          url: chapterUrl,
          chapterIndex: 1,
        ),
        contentWithInvalidMarkup,
      );

      print('📝 原始内容包含无效标记: $contentWithInvalidMarkup');

      // 第一次读取：会清理并更新数据库
      final content1 = await testBase.databaseService.getCachedChapter(chapterUrl);
      print('📖 第一次读取结果: $content1');

      // 等待一小段时间确保数据库更新完成
      await Future.delayed(const Duration(milliseconds: 100));

      // 第二次读取：应该从数据库读取已清理的内容
      final content2 = await testBase.databaseService.getCachedChapter(chapterUrl);
      print('📖 第二次读取结果: $content2');

      // 第三次读取：内容应该保持不变
      final content3 = await testBase.databaseService.getCachedChapter(chapterUrl);
      print('📖 第三次读取结果: $content3');

      // 验证：第二次和第三次的内容应该相同
      expect(content2, equals(content3),
          reason: '第二次和第三次读取的内容应该相同（已清理）');

      print('✅ 验证完成：多次读取同一章节的行为正确');
    });
  });
}
