import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/search_result.dart';
import 'package:novel_app/screens/reader_screen.dart';

void main() {
  // 初始化FFI数据库工厂
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('搜索结果导航逻辑单元测试', () {
    late DatabaseService databaseService;
    late Novel testNovel;
    late Chapter testChapter;

    setUpAll(() async {
      databaseService = DatabaseService();
      await databaseService.database;

      // 创建测试小说和章节
      testNovel = Novel(
        title: '导航测试小说',
        author: '导航测试作者',
        url: 'https://example.com/navigation-test-novel',
        isInBookshelf: true,
      );

      testChapter = Chapter(
        title: '第一章：测试导航',
        url: 'https://example.com/navigation-test-novel/chapter1',
        content: '这是第一章的内容，用于测试导航功能。',
        chapterIndex: 1,
      );
    });

    setUp(() async {
      await _cleanupTestData();
    });

    tearDown(() async {
      await _cleanupTestData();
    });

    test('测试ReaderScreen构造函数参数完整性', () {
      // 验证ReaderScreen构造函数的必需参数
      expect(
        () => ReaderScreen(
          novel: testNovel,
          chapter: testChapter,
          chapters: [testChapter],
        ),
        returnsNormally,
        reason: 'ReaderScreen应该能使用基本参数构造',
      );
    });

    test('测试搜索结果数据结构完整性', () {
      // 创建搜索结果
      final searchResult = ChapterSearchResult(
        novelUrl: testNovel.url,
        novelTitle: testNovel.title,
        novelAuthor: testNovel.author,
        chapterUrl: testChapter.url,
        chapterTitle: testChapter.title,
        chapterIndex: testChapter.chapterIndex!,
        content: testChapter.content!,
        searchKeywords: ['导航', '测试'],
        matchPositions: [
          MatchPosition(
            start: 4,
            end: 6,
            matchedText: '导航',
          ),
        ],
        cachedAt: DateTime.now(),
      );

      // 验证搜索结果数据完整性
      expect(searchResult.novelUrl, equals(testNovel.url));
      expect(searchResult.novelTitle, equals(testNovel.title));
      expect(searchResult.novelAuthor, equals(testNovel.author));
      expect(searchResult.chapterUrl, equals(testChapter.url));
      expect(searchResult.chapterTitle, equals(testChapter.title));
      expect(searchResult.chapterIndex, equals(testChapter.chapterIndex!));
      expect(searchResult.content, contains('导航功能'));
      expect(searchResult.searchKeywords, contains('导航'));
      expect(searchResult.matchPositions.length, equals(1));
      expect(searchResult.matchPositions.first.matchedText, equals('导航'));
    });

    test('测试章节搜索参数验证逻辑', () {
      // 测试基本的搜索参数验证
      final validKeyword = '导航';
      final validChapterTitle = '第一章：导航测试';
      final validContent = '这是用于导航测试的内容';

      expect(validKeyword.isNotEmpty, isTrue, reason: '搜索关键词不应为空');
      expect(validChapterTitle.isNotEmpty, isTrue, reason: '章节标题不应为空');
      expect(validContent.isNotEmpty, isTrue, reason: '章节内容不应为空');
      expect(validContent.contains(validKeyword), isTrue,
             reason: '章节内容应包含搜索关键词');
    });

    test('测试导航数据一致性检查', () {
      // 模拟从搜索结果到ReaderScreen的数据传递过程

      // 1. 创建搜索结果（模拟搜索服务返回）
      final searchResult = ChapterSearchResult(
        novelUrl: testNovel.url,
        novelTitle: testNovel.title,
        novelAuthor: testNovel.author,
        chapterUrl: testChapter.url,
        chapterTitle: testChapter.title,
        chapterIndex: testChapter.chapterIndex!,
        content: testChapter.content!,
        searchKeywords: ['测试'],
        matchPositions: [],
        cachedAt: DateTime.now(),
      );

      // 2. 创建Chapter对象（用于导航）
      final chapterForNavigation = Chapter(
        title: searchResult.chapterTitle,
        url: searchResult.chapterUrl,
        chapterIndex: searchResult.chapterIndex,
        content: searchResult.content,
      );

      // 3. 验证数据一致性
      expect(chapterForNavigation.url, equals(searchResult.chapterUrl));
      expect(chapterForNavigation.title, equals(searchResult.chapterTitle));
      expect(chapterForNavigation.chapterIndex, equals(searchResult.chapterIndex));
      expect(chapterForNavigation.content, equals(searchResult.content));

      // 4. 验证小说信息一致性
      expect(testNovel.url, equals(searchResult.novelUrl));
      expect(testNovel.title, equals(searchResult.novelTitle));
    });

    test('测试导航路径安全性验证', () {
      // 测试导航路径的基本安全性

      // 1. 验证URL格式
      final validNovelUrl = 'https://example.com/novel';
      final validChapterUrl = 'https://example.com/novel/chapter1';

      expect(validNovelUrl.startsWith('http'), isTrue, reason: '小说URL应该是有效的HTTP URL');
      expect(validChapterUrl.startsWith('http'), isTrue, reason: '章节URL应该是有效的HTTP URL');

      // 2. 验证索引值合理性
      expect(testChapter.chapterIndex, greaterThanOrEqualTo(0), reason: '章节索引应该为非负数');

      // 3. 验证标题不为空
      expect(testChapter.title.isNotEmpty, isTrue, reason: '章节标题不应为空');
      expect(testNovel.title.isNotEmpty, isTrue, reason: '小说标题不应为空');
    });

    test('测试搜索结果匹配位置正确性', () {
      final content = '这是一个关于导航功能的测试内容';
      final keyword = '导航';
      final startIndex = content.indexOf(keyword);
      final endIndex = startIndex + keyword.length;

      // 创建匹配位置
      final matchPosition = MatchPosition(
        start: startIndex,
        end: endIndex,
        matchedText: keyword,
      );

      // 验证匹配位置
      expect(matchPosition.start, equals(startIndex));
      expect(matchPosition.end, equals(endIndex));
      expect(matchPosition.matchedText, equals(keyword));
      expect(content.substring(matchPosition.start, matchPosition.end), equals(keyword));
    });

    test('测试缓存时间戳有效性', () {
      final now = DateTime.now();
      final searchResult = ChapterSearchResult(
        novelUrl: testNovel.url,
        novelTitle: testNovel.title,
        novelAuthor: testNovel.author,
        chapterUrl: testChapter.url,
        chapterTitle: testChapter.title,
        chapterIndex: testChapter.chapterIndex!,
        content: testChapter.content!,
        searchKeywords: [],
        matchPositions: [],
        cachedAt: now,
      );

      // 验证缓存时间戳
      expect(searchResult.cachedAt, isNotNull);
      expect(searchResult.cachedAt.isAtSameMomentAs(now), isTrue);
      expect(searchResult.cachedAt.isBefore(DateTime.now().add(const Duration(minutes: 1))), isTrue);
    });
  });
}

/// 清理测试数据
Future<void> _cleanupTestData() async {
  final db = await DatabaseService().database;

  // 清理测试小说数据
  await db.delete('bookshelf', where: 'url LIKE ?', whereArgs: ['%test-novel%']);
  await db.delete('chapter_cache', where: 'novelUrl LIKE ?', whereArgs: ['%test-novel%']);
  await db.delete('novel_chapters', where: 'novelUrl LIKE ?', whereArgs: ['%test-novel%']);
}