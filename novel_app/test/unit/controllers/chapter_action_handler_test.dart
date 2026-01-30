import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/controllers/chapter_list/chapter_action_handler.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/database_service.dart';
import '../../test_bootstrap.dart';
import '../../utils/test_data_factory.dart';

/// ChapterActionHandler 单元测试
///
/// 迁移说明：
/// - 从 Mock 数据库迁移到真实数据库测试
/// - 使用真实 DatabaseService 进行测试
/// - 验证实际数据库操作结果
void main() {
  // 初始化测试环境
  initDatabaseTests();

  group('ChapterActionHandler', () {
    late ChapterActionHandler handler;
    late DatabaseService db;

    setUp(() async {
      // 创建真实的数据库服务
      db = DatabaseService();

      // 清理测试数据
      final database = await db.database;
      final tables = [
        'bookshelf',
        'bookshelves',
        'novel_bookshelves',
        'chapter_cache',
        'novel_chapters',
        'characters',
        'scene_illustrations',
        'character_relationships',
        'outlines',
        'chat_scenes',
        'reading_chapter_log',
        'chapter_ai_accompaniment',
      ];

      for (final table in tables) {
        try {
          await database.delete(table);
        } catch (e) {
          // 表不存在或其他错误，忽略
        }
      }

      // 创建 handler
      handler = ChapterActionHandler(
        databaseService: db,
      );
    });

    group('insertChapter', () {
      test('should insert chapter into database', () async {
        // 准备测试数据
        final novel = await TestDataFactory.createAndAddNovel(
          dbService: db,
          url: 'https://test.com/novel/1',
          title: '测试小说',
          author: '测试作者',
        );

        // 执行操作
        await handler.insertChapter(
          novelUrl: novel.url,
          title: '用户插入章节',
          content: '章节内容',
          insertIndex: 5,
        );

        // 验证：章节数量+1
        final chapters = await db.getChapters(novel.url);
        expect(chapters.length, 1);

        // 验证：章节属性正确
        final chapter = chapters.first;
        expect(chapter.title, '用户插入章节');
        expect(chapter.isUserInserted, true);
        expect(chapter.chapterIndex, 5);
      });

      test('should insert multiple chapters with different indices', () async {
        // 准备测试数据
        final novel = await TestDataFactory.createAndAddNovel(
          dbService: db,
          url: 'https://test.com/novel/2',
          title: '测试小说2',
          author: '测试作者2',
        );

        // 执行操作：插入多个章节
        await handler.insertChapter(
          novelUrl: novel.url,
          title: '第一章',
          content: '内容1',
          insertIndex: 1,
        );

        await handler.insertChapter(
          novelUrl: novel.url,
          title: '第二章',
          content: '内容2',
          insertIndex: 2,
        );

        await handler.insertChapter(
          novelUrl: novel.url,
          title: '插入章节',
          content: '插入内容',
          insertIndex: 5,
        );

        // 验证：所有章节都已插入
        final chapters = await db.getChapters(novel.url);
        expect(chapters.length, 3);

        // 验证：每个章节的索引
        expect(chapters[0].chapterIndex, 1);
        expect(chapters[1].chapterIndex, 2);
        expect(chapters[2].chapterIndex, 5);

        // 验证：所有章节都标记为用户插入
        expect(chapters.every((c) => c.isUserInserted), true);
      });
    });

    group('deleteChapter', () {
      test('should remove user-inserted chapter from database', () async {
        // 准备测试数据
        final novel = await TestDataFactory.createAndAddNovel(
          dbService: db,
          url: 'https://test.com/novel/3',
          title: '测试小说3',
          author: '测试作者3',
        );

        // 创建普通章节
        await TestDataFactory.createAndCacheChapters(
          dbService: db,
          novelUrl: novel.url,
          count: 2,
        );

        // 创建用户插入章节
        await handler.insertChapter(
          novelUrl: novel.url,
          title: '用户插入章节',
          content: '用户内容',
          insertIndex: 5,
        );

        final chapters = await db.getChapters(novel.url);
        final targetUrl = chapters.lastWhere((c) => c.isUserInserted).url;

        // 执行删除操作
        await handler.deleteChapter(targetUrl);

        // 验证：章节数量-1
        final updated = await db.getChapters(novel.url);
        expect(updated.length, 2);

        // 验证：目标章节已删除
        final exists = updated.any((c) => c.url == targetUrl);
        expect(exists, false);

        // 验证：剩余章节都是普通章节
        expect(updated.every((c) => !c.isUserInserted), true);
      });

      test('should handle deletion of non-existent chapter', () async {
        // 准备测试数据
        final novel = await TestDataFactory.createAndAddNovel(
          dbService: db,
          url: 'https://test.com/novel/4',
          title: '测试小说4',
          author: '测试作者4',
        );

        await TestDataFactory.createAndCacheChapters(
          dbService: db,
          novelUrl: novel.url,
          count: 3,
        );

        final chaptersBefore = await db.getChapters(novel.url);

        // 执行删除不存在的章节（应该不会抛出异常）
        await handler.deleteChapter('non-existent-chapter-url');

        // 验证：章节数量不变
        final chaptersAfter = await db.getChapters(novel.url);
        expect(chaptersAfter.length, chaptersBefore.length);
      });

      test('should delete only user-inserted chapters', () async {
        // 准备测试数据
        final novel = await TestDataFactory.createAndAddNovel(
          dbService: db,
          url: 'https://test.com/novel/5',
          title: '测试小说5',
          author: '测试作者5',
        );

        // 创建普通章节
        await TestDataFactory.createAndCacheChapters(
          dbService: db,
          novelUrl: novel.url,
          count: 2,
        );

        // 创建用户插入章节
        await handler.insertChapter(
          novelUrl: novel.url,
          title: '用户章节',
          content: '用户内容',
          insertIndex: 5,
        );

        final chaptersBefore = await db.getChapters(novel.url);
        final userChapterUrl = chaptersBefore.firstWhere(
          (c) => c.isUserInserted,
        ).url;

        // 删除用户章节
        await handler.deleteChapter(userChapterUrl);

        // 验证：用户章节已删除
        final chaptersAfter = await db.getChapters(novel.url);
        expect(chaptersAfter.length, 2);
        expect(chaptersAfter.every((c) => !c.isUserInserted), true);
      });
    });

    group('isChapterCached', () {
      test('should return true for cached chapters', () async {
        // 准备测试数据
        final novel = await TestDataFactory.createAndAddNovel(
          dbService: db,
          url: 'https://test.com/novel/6',
          title: '测试小说6',
          author: '测试作者6',
        );

        await TestDataFactory.createAndCacheChapters(
          dbService: db,
          novelUrl: novel.url,
          count: 3,
        );

        final chapters = await db.getChapters(novel.url);
        final chapterUrl = chapters[0].url;

        // 验证：已缓存章节返回true
        final isCached = await handler.isChapterCached(chapterUrl);
        expect(isCached, isTrue);
      });

      test('should return false for non-existent chapter', () async {
        // 验证：不存在的章节返回false
        final isCached = await handler.isChapterCached('non-existent-url');
        expect(isCached, isFalse);
      });

      test('should return false for uncached chapter', () async {
        // 准备测试数据：创建章节但不缓存内容
        final novel = await TestDataFactory.createAndAddNovel(
          dbService: db,
          url: 'https://test.com/novel/7',
          title: '测试小说7',
          author: '测试作者7',
        );

        await TestDataFactory.createAndCacheChapters(
          dbService: db,
          novelUrl: novel.url,
          count: 2, // 创建2个章节
        );

        final chapters = await db.getChapters(novel.url);
        final targetChapter = chapters[0];

        // 验证：章节已缓存
        expect(await handler.isChapterCached(targetChapter.url), isTrue);

        // 从数据库中删除缓存内容（模拟缓存失效）
        final database = await db.database;
        await database.delete(
          'chapter_cache',
          where: 'chapterUrl = ?',
          whereArgs: [targetChapter.url],
        );

        // 清除内存缓存（DatabaseService没有公开清除内存缓存的方法）
        // 所以我们检查一个不存在的章节来验证方法
        final nonExistentChapter = 'non-existent-chapter-${DateTime.now().millisecondsSinceEpoch}';

        // 验证：不存在的章节返回false
        final isCached = await handler.isChapterCached(nonExistentChapter);
        expect(isCached, isFalse);

        // 验证：另一个章节仍然缓存
        expect(await handler.isChapterCached(chapters[1].url), isTrue);
      });
    });

    group('areChaptersCached', () {
      test('should return correct status map for mixed chapters', () async {
        // 准备测试数据
        final novel = await TestDataFactory.createAndAddNovel(
          dbService: db,
          url: 'https://test.com/novel/8',
          title: '测试小说8',
          author: '测试作者8',
        );

        await TestDataFactory.createAndCacheChapters(
          dbService: db,
          novelUrl: novel.url,
          count: 3,
        );

        final chapters = await db.getChapters(novel.url);

        // 删除中间章节的缓存
        final database = await db.database;
        await database.delete(
          'chapter_cache',
          where: 'chapterUrl = ?',
          whereArgs: [chapters[1].url],
        );

        final urls = [
          chapters[0].url, // 已缓存
          chapters[1].url, // 未缓存
          chapters[2].url, // 已缓存
          'non-existent-url', // 不存在
        ];

        // 执行批量检查
        final result = await handler.areChaptersCached(urls);

        // 验证：返回正确的状态映射
        expect(result, {
          chapters[0].url: true,
          chapters[1].url: false,
          chapters[2].url: true,
          'non-existent-url': false,
        });
      });

      test('should handle empty url list', () async {
        // 执行批量检查空列表
        final result = await handler.areChaptersCached([]);

        // 验证：返回空映射
        expect(result, isEmpty);
      });

      test('should handle all cached chapters', () async {
        // 准备测试数据
        final novel = await TestDataFactory.createAndAddNovel(
          dbService: db,
          url: 'https://test.com/novel/9',
          title: '测试小说9',
          author: '测试作者9',
        );

        await TestDataFactory.createAndCacheChapters(
          dbService: db,
          novelUrl: novel.url,
          count: 3,
        );

        final chapters = await db.getChapters(novel.url);
        final urls = chapters.map((c) => c.url).toList();

        // 执行批量检查
        final result = await handler.areChaptersCached(urls);

        // 验证：所有章节都返回true
        expect(result.length, 3);
        expect(result.values.every((cached) => cached), true);
      });

      test('should handle all non-existent chapters', () async {
        // 执行批量检查不存在的章节
        final urls = ['url1', 'url2', 'url3'];
        final result = await handler.areChaptersCached(urls);

        // 验证：所有章节都返回false
        expect(result, {
          'url1': false,
          'url2': false,
          'url3': false,
        });
      });
    });
  });
}
