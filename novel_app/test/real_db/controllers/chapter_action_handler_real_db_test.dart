import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/controllers/chapter_list/chapter_action_handler.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/database_service.dart';
import '../../base/database_test_base.dart';
import '../../test_bootstrap.dart';
import '../../test_helpers/mock_data.dart';

/// ChapterActionHandler 单元测试（真实数据库版本）
///
/// 迁移说明：
/// - 从 MockDatabaseService 迁移到真实SQLite数据库
/// - 使用 DatabaseTestBase 基类提供数据库初始化和清理
/// - 测试更准确，能发现数据层的真实问题
///
/// 创建时间: 2025-01-30
/// 迁移自: chapter_action_handler_test.dart (Mock版本)
void main() {
  // 初始化数据库FFI
  initDatabaseTests();

  group('ChapterActionHandler (真实数据库)', () {
    late ChapterActionHandler handler;
    late ChapterActionHandlerTestBase base;

    setUp(() async {
      // 初始化测试基类
      base = ChapterActionHandlerTestBase();
      await base.setUp();

      // 创建 ChapterActionHandler 实例
      handler = ChapterActionHandler(
        databaseService: base.databaseService,
      );
    });

    tearDown(() async {
      // 清理测试环境
      await base.tearDown();
    });

    group('insertChapter', () {
      test('应成功插入用户章节到数据库', () async {
        // 准备测试数据：添加小说
        final novel = await base.createAndAddNovel(
          url: 'insert-test-novel',
          title: '插入测试小说',
        );

        // 执行测试：插入用户章节
        await handler.insertChapter(
          novelUrl: 'insert-test-novel',
          title: '用户自定义章节',
          content: '这是用户插入的章节内容',
          insertIndex: 0,
        );

        // 验证数据库状态
        final chapters = await base.databaseService.getChapters('insert-test-novel');
        expect(chapters.length, 1);

        // 验证章节属性
        final chapter = chapters.first;
        expect(chapter.title, '用户自定义章节');
        expect(chapter.isUserInserted, isTrue);
        expect(chapter.chapterIndex, 0);
      });

      test('应正确设置章节索引', () async {
        // 准备测试数据
        final novel = await base.createAndAddNovel(url: 'index-test-novel');
        await base.createAndCacheChapters(
          novelUrl: 'index-test-novel',
          count: 3,
        );

        // 执行测试：在索引2处插入用户章节
        await handler.insertChapter(
          novelUrl: 'index-test-novel',
          title: '插入的章节',
          content: '内容',
          insertIndex: 2,
        );

        // 验证数据库状态
        final chapters = await base.databaseService.getChapters('index-test-novel');
        expect(chapters.length, 4);

        // 验证插入的章节在正确的位置
        final insertedChapter = chapters.firstWhere(
          (c) => c.title == '插入的章节',
        );
        expect(insertedChapter.chapterIndex, 2);
        expect(insertedChapter.isUserInserted, isTrue);
      });

      test('插入多个用户章节应正确处理', () async {
        // 准备测试数据
        final novel = await base.createAndAddNovel(url: 'multi-insert-novel');

        // 执行测试：插入多个用户章节
        await handler.insertChapter(
          novelUrl: 'multi-insert-novel',
          title: '用户章节1',
          content: '内容1',
          insertIndex: 0,
        );

        await handler.insertChapter(
          novelUrl: 'multi-insert-novel',
          title: '用户章节2',
          content: '内容2',
          insertIndex: 1,
        );

        // 验证数据库状态
        final chapters = await base.databaseService.getChapters('multi-insert-novel');
        expect(chapters.length, 2);

        // 验证所有章节都是用户插入的
        for (final chapter in chapters) {
          expect(chapter.isUserInserted, isTrue);
        }
      });
    });

    group('deleteChapter', () {
      test('应成功删除用户章节', () async {
        // 准备测试数据
        final novel = await base.createAndAddNovel(url: 'delete-test-novel');

        // 创建用户章节
        final chapter = Chapter(
          title: '要删除的章节',
          url: 'user://chapter-to-delete',
          content: '内容',
          isCached: true,
          chapterIndex: 0,
          isUserInserted: true,
        );

        await base.databaseService.database.then((db) async {
          await db.insert('novel_chapters', {
            'novelUrl': 'delete-test-novel',
            'chapterUrl': 'user://chapter-to-delete',
            'title': '要删除的章节',
            'chapterIndex': 0,
            'isUserInserted': 1,
          });
        });

        // 验证初始状态
        var chapters = await base.databaseService.getChapters('delete-test-novel');
        expect(chapters.length, 1);

        // 执行测试：删除章节
        await handler.deleteChapter('user://chapter-to-delete');

        // 验证数据库状态
        chapters = await base.databaseService.getChapters('delete-test-novel');
        expect(chapters.length, 0);
      });

      test('删除不存在的章节不应报错', () async {
        // 执行测试：删除不存在的章节
        await handler.deleteChapter('non-existent-chapter');

        // 测试通过即表示没有报错
        expect(true, isTrue);
      });

      test('应只删除指定的章节', () async {
        // 准备测试数据
        final novel = await base.createAndAddNovel(url: 'multi-delete-novel');
        await base.createAndCacheChapters(
          novelUrl: 'multi-delete-novel',
          count: 3,
        );

        // 验证初始状态
        var chapters = await base.databaseService.getChapters('multi-delete-novel');
        expect(chapters.length, 3);

        // 执行测试：删除中间的章节
        final chapterToDelete = chapters[1];
        await handler.deleteChapter(chapterToDelete.url);

        // 验证数据库状态
        chapters = await base.databaseService.getChapters('multi-delete-novel');
        expect(chapters.length, 2);

        // 验证删除的是正确的章节
        expect(
          chapters.any((c) => c.url == chapterToDelete.url),
          isFalse,
        );
      });
    });

    group('isChapterCached', () {
      test('已缓存的章节应返回 true', () async {
        // 准备测试数据
        final novel = await base.createAndAddNovel(url: 'cached-check-novel');
        final chapters = await base.createAndCacheChapters(
          novelUrl: 'cached-check-novel',
          count: 2,
        );

        // 执行测试：检查第一个章节是否缓存
        final result = await handler.isChapterCached(chapters[0].url);

        // 验证结果
        expect(result, isTrue);
      });

      test('未缓存的章节应返回 false', () async {
        // 准备测试数据
        final novel = await base.createAndAddNovel(url: 'uncached-novel');

        // 创建章节元数据（不缓存内容）
        await base.createTestChapter(
          novelUrl: 'uncached-novel',
          url: 'uncached-chapter',
          title: '未缓存章节',
        );

        // 执行测试：检查章节是否缓存
        final result = await handler.isChapterCached('uncached-chapter');

        // 验证结果
        expect(result, isFalse);
      });

      test('不存在的章节应返回 false', () async {
        // 执行测试：检查不存在的章节
        final result = await handler.isChapterCached('non-existent-chapter');

        // 验证结果
        expect(result, isFalse);
      });
    });

    group('areChaptersCached', () {
      test('应返回所有章节的缓存状态', () async {
        // 准备测试数据
        final novel = await base.createAndAddNovel(url: 'batch-cache-novel');
        final chapters = await base.createAndCacheChapters(
          novelUrl: 'batch-cache-novel',
          count: 3,
        );

        // 删除中间章节的缓存（模拟部分缓存）
        final db = await base.databaseService.database;
        await db.delete(
          'chapter_cache',
          where: 'chapterUrl = ?',
          whereArgs: [chapters[1].url],
        );

        // 执行测试：检查所有章节的缓存状态
        final urls = chapters.map((c) => c.url).toList();
        final result = await handler.areChaptersCached(urls);

        // 验证结果
        expect(result.length, 3);
        expect(result[chapters[0].url], isTrue);
        expect(result[chapters[1].url], isFalse);
        expect(result[chapters[2].url], isTrue);
      });

      test('空URL列表应返回空Map', () async {
        // 执行测试
        final result = await handler.areChaptersCached([]);

        // 验证结果
        expect(result, isEmpty);
      });

      test('应正确处理全部未缓存的情况', () async {
        // 准备测试数据：只创建章节元数据，不缓存内容
        final novel = await base.createAndAddNovel(url: 'no-cache-novel');
        await base.createTestChapter(
          novelUrl: 'no-cache-novel',
          url: 'chapter-1',
          title: '第一章',
        );
        await base.createTestChapter(
          novelUrl: 'no-cache-novel',
          url: 'chapter-2',
          title: '第二章',
        );

        // 执行测试
        final result = await handler.areChaptersCached(['chapter-1', 'chapter-2']);

        // 验证结果
        expect(result['chapter-1'], isFalse);
        expect(result['chapter-2'], isFalse);
      });

      test('应正确处理全部已缓存的情况', () async {
        // 准备测试数据
        final novel = await base.createAndAddNovel(url: 'all-cache-novel');
        final chapters = await base.createAndCacheChapters(
          novelUrl: 'all-cache-novel',
          count: 3,
        );

        // 执行测试
        final urls = chapters.map((c) => c.url).toList();
        final result = await handler.areChaptersCached(urls);

        // 验证结果：所有章节都应该已缓存
        for (final url in urls) {
          expect(result[url], isTrue, reason: '章节 $url 应该已缓存');
        }
      });
    });

    // 注意: getPreviousChaptersContent 方法属于 ChapterService，不是 ChapterActionHandler
    // 相关测试应该移动到 chapter_service_real_db_test.dart 中
  });
}

/// ChapterActionHandler 测试基类
///
/// 继承 DatabaseTestBase，提供测试所需的数据库初始化和清理功能
class ChapterActionHandlerTestBase extends DatabaseTestBase {
  // 可以在这里添加特定于 ChapterActionHandler 测试的辅助方法
}
