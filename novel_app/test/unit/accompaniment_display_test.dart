import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/database_service.dart';
import '../base/database_test_base.dart';
import '../test_bootstrap.dart';

/// AI伴读状态显示问题分析测试
///
/// 测试目标:
/// 1. 验证章节数据是否包含isAccompanied字段
/// 2. 验证数据库表结构是否支持isAccompanied
/// 3. 验证getChapters方法是否返回伴读状态
void main() {
  initDatabaseTests();

  group('AI伴读状态显示问题分析', () {
    late DatabaseTestBase testBase;

    setUp(() async {
      testBase = _AccompanimentTestBase();
      await testBase.setUp();
    });

    test('测试1: 检查chapter_cache表是否有isAccompanied字段', () async {
      final db = await testBase.databaseService.database;

      // 查询表结构
      final result = await db.rawQuery(
        "PRAGMA table_info(chapter_cache)",
      );

      print('\n=== chapter_cache 表结构 ===');
      for (var row in result) {
        print('  ${row['name']}: ${row['type']}');
      }

      // 检查是否有isAccompanied字段
      final hasIsAccompanied = result.any((row) => row['name'] == 'isAccompanied');

      expect(
        hasIsAccompanied,
        isTrue,
        reason: 'chapter_cache表应该包含isAccompanied字段',
      );
    });

    test('测试2: 检查novel_chapters表是否有isAccompanied字段', () async {
      final db = await testBase.databaseService.database;

      // 查询表结构
      final result = await db.rawQuery(
        "PRAGMA table_info(novel_chapters)",
      );

      print('\n=== novel_chapters 表结构 ===');
      for (var row in result) {
        print('  ${row['name']}: ${row['type']}');
      }

      // 检查是否有isAccompanied字段
      final hasIsAccompanied = result.any((row) => row['name'] == 'isAccompanied');

      expect(
        hasIsAccompanied,
        isTrue,
        reason: 'novel_chapters表应该包含isAccompanied字段',
      );
    });

    test('测试3: 验证缓存章节时isAccompanied字段被保存', () async {
      // 创建小说
      const novelUrl = 'https://example.com/novel1';
      await testBase.databaseService.addToBookshelf(
        Novel(
          title: '测试小说',
          author: '测试作者',
          url: novelUrl,
        ),
      );

      // 创建并缓存章节
      final chapter = Chapter(
        title: '第一章',
        url: 'https://example.com/chapter1',
        content: '这是第一章的内容',
        isAccompanied: true, // 标记为已伴读
      );

      await testBase.databaseService.cacheChapter(
        novelUrl,
        chapter,
        chapter.content ?? '',
      );

      // 标记为已伴读
      await testBase.databaseService.markChapterAsAccompanied(
        novelUrl,
        chapter.url,
      );

      // 从数据库查询章节
      final db = await testBase.databaseService.database;
      final result = await db.query(
        'chapter_cache',
        where: 'chapterUrl = ?',
        whereArgs: [chapter.url],
      );

      expect(result.isNotEmpty, isTrue);
      print('\n=== 缓存章节数据 ===');
      print('  isAccompanied: ${result.first['isAccompanied']}');

      // 验证isAccompanied字段被保存
      expect(
        result.first['isAccompanied'],
        equals(1),
        reason: 'isAccompanied应该被保存到数据库',
      );
    });

    test('测试4: 验证getChapters方法返回isAccompanied字段', () async {
      // 创建小说
      const novelUrl = 'https://example.com/novel2';
      await testBase.databaseService.addToBookshelf(
        Novel(
          title: '测试小说2',
          author: '测试作者',
          url: novelUrl,
        ),
      );

      // 创建章节
      final chapter = Chapter(
        title: '第一章',
        url: 'https://example.com/chapter2',
        content: '内容',
        isAccompanied: true,
      );

      // 先添加到novel_chapters表
      await testBase.databaseService.cacheNovelChapters(
        novelUrl,
        [chapter],
      );

      // 再缓存章节内容
      await testBase.databaseService.cacheChapter(
        novelUrl,
        chapter,
        chapter.content ?? '',
      );

      await testBase.databaseService.markChapterAsAccompanied(
        novelUrl,
        chapter.url,
      );

      // 调用getChapters
      final chapters = await testBase.databaseService.getChapters(novelUrl);

      expect(chapters.isNotEmpty, isTrue);
      print('\n=== getChapters返回结果 ===');
      print('  章节标题: ${chapters.first.title}');
      print('  isAccompanied: ${chapters.first.isAccompanied}');

      // 验证isAccompanied字段被返回
      expect(
        chapters.first.isAccompanied,
        isTrue,
        reason: 'getChapters应该返回包含isAccompanied的Chapter对象',
      );
    });

    test('测试5: 完整流程测试 - 模拟章节列表加载', () async {
      // 创建小说
      const novelUrl = 'https://example.com/novel3';
      await testBase.databaseService.addToBookshelf(
        Novel(
          title: '测试小说3',
          author: '测试作者',
          url: novelUrl,
        ),
      );

      // 添加多个章节,部分已伴读,部分未伴读
      final chapters = [
        Chapter(
          title: '第一章',
          url: '$novelUrl/chapter1',
          content: '内容1',
          chapterIndex: 0,
          isAccompanied: true,
        ),
        Chapter(
          title: '第二章',
          url: '$novelUrl/chapter2',
          content: '内容2',
          chapterIndex: 1,
          isAccompanied: false,
        ),
        Chapter(
          title: '第三章',
          url: '$novelUrl/chapter3',
          content: '内容3',
          chapterIndex: 2,
          isAccompanied: true,
        ),
      ];

      // 先添加到novel_chapters表
      await testBase.databaseService.cacheNovelChapters(
        novelUrl,
        chapters,
      );

      // 再缓存章节内容和标记伴读状态
      for (var chapter in chapters) {
        await testBase.databaseService.cacheChapter(
          novelUrl,
          chapter,
          chapter.content ?? '',
        );

        if (chapter.isAccompanied) {
          await testBase.databaseService.markChapterAsAccompanied(
            novelUrl,
            chapter.url,
          );
        }
      }

      // 加载章节列表
      final loadedChapters = await testBase.databaseService.getChapters(novelUrl);

      print('\n=== 章节列表伴读状态 ===');
      for (var chapter in loadedChapters) {
        print(
          '  ${chapter.title}: isAccompanied=${chapter.isAccompanied}',
        );
      }

      // 验证伴读状态正确
      expect(loadedChapters.length, equals(3));
      expect(loadedChapters[0].isAccompanied, isTrue,
          reason: '第一章应该已伴读');
      expect(loadedChapters[1].isAccompanied, isFalse,
          reason: '第二章应该未伴读');
      expect(loadedChapters[2].isAccompanied, isTrue,
          reason: '第三章应该已伴读');
    });
  });
}

class _AccompanimentTestBase extends DatabaseTestBase {}
