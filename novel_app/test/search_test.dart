import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/services/chapter_search_service.dart';

void main() {
  // 初始化FFI数据库工厂
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('搜索功能测试', () {
    late DatabaseService databaseService;
    late ChapterSearchService chapterSearchService;

    setUpAll(() async {
      // 初始化测试数据库
      databaseService = DatabaseService();
      chapterSearchService = ChapterSearchService();

      // 确保使用测试数据库
      await databaseService.database;
    });

    setUp(() async {
      // 每次测试前清理数据
      await _cleanupTestData();
      await _createTestData();
    });

    tearDown(() async {
      // 每次测试后清理数据
      await _cleanupTestData();
    });

    test('测试指定小说搜索 - 应该只返回目标小说的结果', () async {
      const targetNovelUrl = 'https://example.com/novel1';
      const keyword = '主角';

      // 先查看数据库中的数据
      final db = await databaseService.database;
      final allData = await db.query('chapter_cache');
      debugPrint('数据库中所有数据:');
      for (final row in allData) {
        debugPrint('  ${row['novelUrl']}: ${row['title']}');
        debugPrint('    内容: ${row['content']}');
      }

      // 手动测试SQL查询
      final manualResults = await db.rawQuery('''
        SELECT novelUrl, title, content
        FROM chapter_cache
        WHERE (content LIKE ? OR title LIKE ?) AND novelUrl = ?
      ''', ['%$keyword%', '%$keyword%', targetNovelUrl]);

      debugPrint('手动SQL查询结果:');
      for (final row in manualResults) {
        debugPrint('  ${row['novelUrl']}: ${row['title']}');
      }

      // 直接调用数据库服务
      final results = await databaseService.searchInCachedContent(
        keyword,
        novelUrl: targetNovelUrl,
      );

      debugPrint('数据库服务搜索结果:');
      for (final result in results) {
        debugPrint('  ${result.novelUrl}: ${result.chapterTitle}');
      }

      // 验证结果
      expect(results.isNotEmpty, true, reason: '应该找到相关结果');

      // 验证所有结果都来自目标小说
      for (final result in results) {
        expect(result.novelUrl, equals(targetNovelUrl),
               reason: '所有结果都应该来自目标小说');
      }

      // 验证找到的是预期的章节
      expect(results.length, equals(2), reason: '应该找到两个章节（都包含"主角"）');
      expect(results.any((r) => r.chapterTitle.contains('第一章')), true,
             reason: '应该找到第一章');
      expect(results.any((r) => r.chapterTitle.contains('第二章')), true,
             reason: '应该找到第二章');
    });

    test('测试跨小说搜索 - 应该返回所有小说的结果', () async {
      const keyword = '主角';

      // 调用搜索服务
      final results = await chapterSearchService.searchInAllNovels(keyword);

      // 验证结果
      expect(results.length, equals(4), reason: '应该找到所有小说中的结果');

      // 验证包含了两个不同的小说
      final novelUrls = results.map((r) => r.novelUrl).toSet();
      expect(novelUrls.length, equals(2), reason: '应该包含两个不同的小说');
      expect(novelUrls, contains('https://example.com/novel1'));
      expect(novelUrls, contains('https://example.com/novel2'));
    });

    test('测试搜索不存在的关键词 - 应该返回空结果', () async {
      const targetNovelUrl = 'https://example.com/novel1';
      const keyword = '不存在的关键词';

      final results = await chapterSearchService.searchInNovel(
        targetNovelUrl,
        keyword,
      );

      expect(results.isEmpty, true, reason: '不存在的关键词应该返回空结果');
    });

    test('测试搜索特定小说时应该排除其他小说', () async {
      const targetNovelUrl = 'https://example.com/novel1';
      const keyword = '异世界'; // 这个词只在小说2中出现

      final results = await chapterSearchService.searchInNovel(
        targetNovelUrl,
        keyword,
      );

      expect(results.isEmpty, true,
             reason: '搜索小说1时不应该找到只在小说2中出现的关键词');
    });
  });
}

Future<void> _createTestData() async {
  final db = await DatabaseService().database;

  // 创建两个小说的测试数据
  final novels = [
    {
      'url': 'https://example.com/novel1',
      'chapters': [
        {
          'url': 'https://example.com/novel1/chapter1',
          'title': '第一章：主角的诞生',
          'content': '这是一个关于年轻主角的故事，他的梦想是成为英雄',
          'index': 1,
        },
        {
          'url': 'https://example.com/novel1/chapter2',
          'title': '第二章：初遇同伴',
          'content': '在旅途中，主角遇到了一个神秘的伙伴',
          'index': 2,
        },
      ]
    },
    {
      'url': 'https://example.com/novel2',
      'chapters': [
        {
          'url': 'https://example.com/novel2/chapter1',
          'title': '第一章：异世界转生',
          'content': '突然间，主角发现自己来到了一个陌生的异世界',
          'index': 1,
        },
        {
          'url': 'https://example.com/novel2/chapter2',
          'title': '第二章：获得能力',
          'content': '在这个新世界，主角获得了特殊的能力',
          'index': 2,
        },
      ]
    },
  ];

  final now = DateTime.now().millisecondsSinceEpoch;

  for (final novel in novels) {
    for (final chapter in novel['chapters'] as List) {
      await db.insert('chapter_cache', {
        'novelUrl': novel['url'],
        'chapterUrl': chapter['url'],
        'title': chapter['title'],
        'content': chapter['content'],
        'chapterIndex': chapter['index'],
        'cachedAt': now,
      });
    }
  }
}

Future<void> _cleanupTestData() async {
  final db = await DatabaseService().database;

  // 清理测试数据
  await db.delete('chapter_cache',
    where: 'novelUrl LIKE ?',
    whereArgs: ['https://example.com/%']);
}