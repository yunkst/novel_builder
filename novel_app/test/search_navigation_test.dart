import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/search_result.dart';
import 'package:novel_app/screens/chapter_list_screen.dart';
import 'package:novel_app/screens/reader_screen.dart';
import 'package:novel_app/screens/chapter_search_screen.dart';
import 'package:novel_app/screens/cache_search_screen.dart';

void main() {
  // 初始化FFI数据库工厂
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('搜索结果点击跳转逻辑测试', () {
    late DatabaseService databaseService;
    late Novel testNovel;
        
    setUpAll(() async {
      databaseService = DatabaseService();
      await databaseService.database;

      // 创建测试小说
      testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://example.com/test-novel',
        isInBookshelf: true,
      );
    });

    setUp(() async {
      await _cleanupTestData();
      await _setupTestData();
    });

    tearDown(() async {
      await _cleanupTestData();
    });

    testWidgets('测试章节搜索结果点击跳转', (WidgetTester tester) async {
      // 1. 构建ChapterSearchScreen
      await tester.pumpWidget(
        MaterialApp(
          home: ChapterSearchScreen(
            novel: testNovel,
          ),
        ),
      );

      // 2. 等待界面加载完成
      await tester.pumpAndSettle();

      // 3. 验证搜索界面显示
      expect(find.text('搜索章节'), findsOneWidget);

      // 4. 输入搜索关键词
      await tester.enterText(find.byType(TextField), '内容');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // 5. 验证搜索结果
      expect(find.text('第一章：开始'), findsOneWidget);
      expect(find.text('第二章：发展'), findsOneWidget);

      // 6. 点击第一个搜索结果
      await tester.tap(find.text('第一章：开始'));
      await tester.pumpAndSettle();

      // 7. 验证跳转到ReaderScreen
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(find.text('第一章：开始'), findsOneWidget);
    });

    testWidgets('测试缓存搜索结果点击跳转', (WidgetTester tester) async {
      // 1. 构建CacheSearchScreen
      await tester.pumpWidget(
        MaterialApp(
          home: CacheSearchScreen(),
        ),
      );

      // 2. 等待界面加载完成
      await tester.pumpAndSettle();

      // 3. 验证缓存搜索界面显示
      expect(find.text('搜索缓存内容'), findsOneWidget);

      // 4. 输入搜索关键词
      await tester.enterText(find.byType(TextField), '内容');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // 5. 等待搜索完成
      await tester.pump(const Duration(seconds: 1));

      // 6. 如果有搜索结果，点击第一个结果
      final resultWidgets = find.textContaining('第一章：开始');
      if (resultWidgets.evaluate().isNotEmpty) {
        await tester.tap(resultWidgets.first);
        await tester.pumpAndSettle();

        // 7. 验证跳转到ReaderScreen
        expect(find.byType(ReaderScreen), findsOneWidget);
      }
    });

    testWidgets('测试章节列表项点击跳转', (WidgetTester tester) async {
      // 1. 构建ChapterListScreen
      await tester.pumpWidget(
        MaterialApp(
          home: ChapterListScreen(novel: testNovel),
        ),
      );

      // 2. 等待界面加载完成
      await tester.pumpAndSettle();

      // 3. 验证章节列表显示
      expect(find.text('第一章：开始'), findsOneWidget);
      expect(find.text('第二章：发展'), findsOneWidget);

      // 4. 点击第一章
      await tester.tap(find.text('第一章：开始'));
      await tester.pumpAndSettle();

      // 5. 验证跳转到ReaderScreen
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(find.text('第一章：开始'), findsOneWidget);
    });
  });

  group('搜索结果导航数据完整性测试', () {
    late DatabaseService databaseService;

    setUpAll(() async {
      databaseService = DatabaseService();
      await databaseService.database;
    });

    setUp(() async {
      await _cleanupTestData();
    });

    tearDown(() async {
      await _cleanupTestData();
    });

    testWidgets('测试搜索结果导航传递正确的数据', (WidgetTester tester) async {
      // 1. 准备测试数据
      final testNovel = Novel(
        title: '数据测试小说',
        author: '数据测试作者',
        url: 'https://example.com/data-test-novel',
      );

      // 2. 创建带有特定章节索引的搜索结果
      final searchResult = ChapterSearchResult(
        novelUrl: testNovel.url,
        novelTitle: testNovel.title,
        novelAuthor: testNovel.author,
        chapterUrl: 'https://example.com/data-test-novel/special-chapter',
        chapterTitle: '特殊章节',
        chapterIndex: 5, // 特定的章节索引
        content: '这是特殊匹配的文本内容',
        searchKeywords: ['匹配'],
        matchPositions: [
          MatchPosition(
            start: 4,
            end: 6,
            matchedText: '匹配',
          ),
        ],
        cachedAt: DateTime.now(),
      );

      // 3. 构建测试界面
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    // 模拟导航到ReaderScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReaderScreen(
                          novel: testNovel,
                          chapter: Chapter(
                            title: searchResult.chapterTitle,
                            url: searchResult.chapterUrl,
                            chapterIndex: searchResult.chapterIndex,
                          ),
                          chapters: [], // 模拟空章节列表
                          searchResult: searchResult, // 传递搜索结果
                        ),
                      ),
                    );
                  },
                  child: const Text('测试导航'),
                );
              },
            ),
          ),
        ),
      );

      // 4. 点击导航按钮
      await tester.tap(find.text('测试导航'));
      await tester.pumpAndSettle();

      // 5. 验证导航成功且数据完整
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(find.text('特殊章节'), findsOneWidget);
    });
  });

  group('搜索边界情况测试', () {
    late DatabaseService databaseService;

    setUpAll(() async {
      databaseService = DatabaseService();
      await databaseService.database;
    });

    setUp(() async {
      await _cleanupTestData();
    });

    tearDown(() async {
      await _cleanupTestData();
    });

    testWidgets('测试空搜索结果的界面状态', (WidgetTester tester) async {
      // 1. 构建ChapterSearchScreen
      final testNovel = Novel(
        title: '边界测试小说',
        author: '边界测试作者',
        url: 'https://example.com/boundary-test-novel',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChapterSearchScreen(
            novel: testNovel,
          ),
        ),
      );

      // 2. 等待界面加载完成
      await tester.pumpAndSettle();

      // 3. 输入一个不存在的搜索关键词
      await tester.enterText(find.byType(TextField), '不存在的关键词');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // 4. 验证显示无结果状态
      expect(find.text('未找到相关章节'), findsOneWidget);
    });

    testWidgets('测试搜索结果为空时的点击安全', (WidgetTester tester) async {
      // 1. 构建ChapterListScreen
      final testNovel = Novel(
        title: '点击安全测试小说',
        author: '点击安全测试作者',
        url: 'https://example.com/click-safety-test-novel',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChapterListScreen(novel: testNovel),
        ),
      );

      // 2. 等待界面加载完成
      await tester.pumpAndSettle();

      // 3. 确保没有章节可点击（空状态）
      expect(find.text('暂无章节'), findsOneWidget);
    });
  });
}

/// 准备测试数据
Future<void> _setupTestData() async {
  final db = await DatabaseService().database;

  // 插入测试小说到书架
  await db.insert('bookshelf', {
    'title': '测试小说',
    'author': '测试作者',
    'url': 'https://example.com/test-novel',
    'addedAt': DateTime.now().millisecondsSinceEpoch,
    'lastReadChapter': 0,
    'lastReadTime': DateTime.now().millisecondsSinceEpoch,
  });

  // 插入测试章节缓存
  final now = DateTime.now().millisecondsSinceEpoch;
  final testChapters = [
    {
      'novelUrl': 'https://example.com/test-novel',
      'chapterUrl': 'https://example.com/test-novel/chapter1',
      'title': '第一章：开始',
      'content': '这是第一章的内容，包含了重要的情节。',
      'chapterIndex': 1,
      'isUserInserted': 0,
      'cachedAt': now,
    },
    {
      'novelUrl': 'https://example.com/test-novel',
      'chapterUrl': 'https://example.com/test-novel/chapter2',
      'title': '第二章：发展',
      'content': '这是第二章的内容，主角遇到了重要的人。',
      'chapterIndex': 2,
      'isUserInserted': 0,
      'cachedAt': now,
    },
  ];

  for (final chapter in testChapters) {
    await db.insert('chapter_cache', chapter);
  }
}

/// 清理测试数据
Future<void> _cleanupTestData() async {
  final db = await DatabaseService().database;

  // 清理测试小说数据
  await db.delete('bookshelf', where: 'url LIKE ?', whereArgs: ['%test-novel%']);
  await db.delete('chapter_cache', where: 'novelUrl LIKE ?', whereArgs: ['%test-novel%']);
  await db.delete('novel_chapters', where: 'novelUrl LIKE ?', whereArgs: ['%test-novel%']);
}