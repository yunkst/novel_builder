import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:novel_app/services/chapter_history_service.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/services/api_service_wrapper.dart';
import 'package:novel_app/models/chapter.dart';

// 生成Mock类
@GenerateMocks([DatabaseService, ApiServiceWrapper])
import 'chapter_history_service_test.mocks.dart';

void main() {
  late ChapterHistoryService historyService;
  late MockDatabaseService mockDatabaseService;
  late MockApiServiceWrapper mockApiService;

  setUp(() {
    mockDatabaseService = MockDatabaseService();
    mockApiService = MockApiServiceWrapper();
    historyService = ChapterHistoryService(
      databaseService: mockDatabaseService,
      apiService: mockApiService,
    );
  });

  group('ChapterHistoryService - 获取历史章节内容', () {
    final testChapters = [
      Chapter(
        title: '第一章',
        url: 'https://example.com/chapter/1',
      ),
      Chapter(
        title: '第二章',
        url: 'https://example.com/chapter/2',
      ),
      Chapter(
        title: '第三章',
        url: 'https://example.com/chapter/3',
      ),
      Chapter(
        title: '第四章',
        url: 'https://example.com/chapter/4',
      ),
    ];

    test('应该成功从缓存获取1章历史内容', () async {
      final currentChapter = testChapters[2]; // 第三章

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .thenAnswer((_) async => '第二章的内容');

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 1,
      );

      expect(result, contains('第二章'));
      expect(result, contains('第二章的内容'));
      expect(result, isNot(contains('第一章')));
      verify(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .called(1);
      verifyNever(mockApiService.getChapterContent(any));
    });

    test('应该成功从缓存获取2章历史内容', () async {
      final currentChapter = testChapters[3]; // 第四章

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/3'))
          .thenAnswer((_) async => '第三章的内容');
      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .thenAnswer((_) async => '第二章的内容');

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 2,
      );

      expect(result, contains('第三章'));
      expect(result, contains('第二章'));
      expect(result, contains('第三章的内容'));
      expect(result, contains('第二章的内容'));
    });

    test('当缓存未命中时应该从API获取', () async {
      final currentChapter = testChapters[2]; // 第三章

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .thenAnswer((_) async => null);
      when(mockApiService.getChapterContent('https://example.com/chapter/2'))
          .thenAnswer((_) async => '从API获取的第二章内容');

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 1,
      );

      expect(result, contains('第二章'));
      expect(result, contains('从API获取的第二章内容'));
      verify(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .called(1);
      verify(mockApiService.getChapterContent('https://example.com/chapter/2'))
          .called(1);
    });

    test('当缓存内容为空字符串时应该从API获取', () async {
      final currentChapter = testChapters[2]; // 第三章

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .thenAnswer((_) async => '');
      when(mockApiService.getChapterContent('https://example.com/chapter/2'))
          .thenAnswer((_) async => '从API获取的章节内容');

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 1,
      );

      expect(result, contains('从API获取的章节内容'));
      verify(mockApiService.getChapterContent('https://example.com/chapter/2'))
          .called(1);
    });

    test('当前章节在列表开头时不应返回历史内容', () async {
      final currentChapter = testChapters[0]; // 第一章

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 2,
      );

      expect(result, isEmpty);
      verifyNever(mockDatabaseService.getCachedChapter(any));
      verifyNever(mockApiService.getChapterContent(any));
    });

    test('当前章节不在列表中时应返回空字符串', () async {
      final unknownChapter = Chapter(
        title: '未知章节',
        url: 'https://example.com/chapter/999',
      );

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: unknownChapter,
        maxHistoryCount: 2,
      );

      expect(result, isEmpty);
      verifyNever(mockDatabaseService.getCachedChapter(any));
      verifyNever(mockApiService.getChapterContent(any));
    });

    test('当历史章节超出列表边界时应忽略', () async {
      final currentChapter = testChapters[1]; // 第二章

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/1'))
          .thenAnswer((_) async => '第一章的内容');

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 5, // 请求5章，但只有1章可用
      );

      expect(result, contains('第一章'));
      expect(result, isNot(contains('第二章')));
      verify(mockDatabaseService.getCachedChapter('https://example.com/chapter/1'))
          .called(1);
    });

    test('当获取历史章节失败时应继续处理其他章节', () async {
      final currentChapter = testChapters[3]; // 第四章

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/3'))
          .thenThrow(Exception('数据库错误'));
      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .thenAnswer((_) async => '第二章的内容');

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 2,
      );

      // 第三章失败，但第二章应该成功
      expect(result, contains('第二章'));
      expect(result, isNot(contains('第三章')));
    });

    test('应该正确格式化历史章节内容', () async {
      final currentChapter = testChapters[2]; // 第三章

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .thenAnswer((_) async => '这是第二章的内容');

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 1,
      );

      // 验证格式: "历史章节: {title}\n\n{content}"
      expect(result, startsWith('历史章节: 第二章\n\n'));
      expect(result, endsWith('这是第二章的内容'));
    });

    test('多个历史章节应该用双换行符分隔', () async {
      final currentChapter = testChapters[3]; // 第四章

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/3'))
          .thenAnswer((_) async => '第三章内容');
      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .thenAnswer((_) async => '第二章内容');

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 2,
      );

      // 验证两个历史章节被 \n\n 分隔
      final parts = result.split('\n\n');
      expect(parts.length, greaterThan(2));
      expect(result, contains('\n\n'));
    });
  });

  group('ChapterHistoryService - 获取历史章节列表', () {
    final testChapters = [
      Chapter(
        title: '第一章',
        url: 'https://example.com/chapter/1',
      ),
      Chapter(
        title: '第二章',
        url: 'https://example.com/chapter/2',
      ),
      Chapter(
        title: '第三章',
        url: 'https://example.com/chapter/3',
      ),
    ];

    test('应该返回纯内容列表，不包含标题前缀', () async {
      final currentChapter = testChapters[2]; // 第三章

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .thenAnswer((_) async => '纯内容1');
      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/1'))
          .thenAnswer((_) async => '纯内容2');

      final result = await historyService.fetchHistoryChaptersList(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 2,
      );

      expect(result, hasLength(2));
      expect(result[0], '纯内容1'); // 最近的历史章节
      expect(result[1], '纯内容2'); // 更早的历史章节
      expect(result[0], isNot(contains('历史章节:')));
      expect(result[1], isNot(contains('历史章节:')));
    });

    test('当章节不在列表中应返回空列表', () async {
      final unknownChapter = Chapter(
        title: '未知章节',
        url: 'https://example.com/chapter/999',
      );

      final result = await historyService.fetchHistoryChaptersList(
        chapters: testChapters,
        currentChapter: unknownChapter,
        maxHistoryCount: 2,
      );

      expect(result, isEmpty);
    });

    test('当获取失败时应跳过该章节', () async {
      final currentChapter = testChapters[2]; // 第三章

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .thenThrow(Exception('获取失败'));
      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/1'))
          .thenAnswer((_) async => '成功的内容');

      final result = await historyService.fetchHistoryChaptersList(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 2,
      );

      expect(result, hasLength(1));
      expect(result[0], '成功的内容');
    });

    test('缓存和API回退逻辑应该正常工作', () async {
      final currentChapter = testChapters[2]; // 第三章

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .thenAnswer((_) async => null);
      when(mockApiService.getChapterContent('https://example.com/chapter/2'))
          .thenAnswer((_) async => '从API获取');

      final result = await historyService.fetchHistoryChaptersList(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 1,
      );

      expect(result, hasLength(1));
      expect(result[0], '从API获取');
      verify(mockApiService.getChapterContent('https://example.com/chapter/2'))
          .called(1);
    });
  });

  group('ChapterHistoryService - 边界情况', () {
    test('空章节列表应返回空结果', () async {
      final currentChapter = Chapter(
        title: '第一章',
        url: 'https://example.com/chapter/1',
      );

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: [],
        currentChapter: currentChapter,
        maxHistoryCount: 2,
      );

      expect(result, isEmpty);
    });

    test('maxHistoryCount为0时应返回空结果', () async {
      final testChapters = [
        Chapter(
          title: '第一章',
          url: 'https://example.com/chapter/1',
        ),
        Chapter(
          title: '第二章',
          url: 'https://example.com/chapter/2',
        ),
      ];

      final currentChapter = testChapters[1];

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 0,
      );

      expect(result, isEmpty);
      verifyNever(mockDatabaseService.getCachedChapter(any));
    });

    test('maxHistoryCount为负数时应返回空结果', () async {
      final testChapters = [
        Chapter(
          title: '第一章',
          url: 'https://example.com/chapter/1',
        ),
        Chapter(
          title: '第二章',
          url: 'https://example.com/chapter/2',
        ),
      ];

      final currentChapter = testChapters[1];

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: -1,
      );

      expect(result, isEmpty);
    });

    test('所有历史章节都失败时应返回空字符串', () async {
      final testChapters = [
        Chapter(
          title: '第一章',
          url: 'https://example.com/chapter/1',
        ),
        Chapter(
          title: '第二章',
          url: 'https://example.com/chapter/2',
        ),
      ];

      final currentChapter = testChapters[1];

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/1'))
          .thenThrow(Exception('全部失败'));
      when(mockApiService.getChapterContent('https://example.com/chapter/1'))
          .thenThrow(Exception('API也失败'));

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 1,
      );

      expect(result, isEmpty);
    });

    test('应该处理包含特殊字符的章节内容', () async {
      final testChapters = [
        Chapter(
          title: '第一章',
          url: 'https://example.com/chapter/1',
        ),
        Chapter(
          title: '第二章',
          url: 'https://example.com/chapter/2',
        ),
      ];

      final currentChapter = testChapters[1];
      final specialContent = '内容\n包含\n换行符\t和制表符"以及引号\'';

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/1'))
          .thenAnswer((_) async => specialContent);

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 1,
      );

      expect(result, contains(specialContent));
    });

    test('应该处理超长章节内容', () async {
      final testChapters = [
        Chapter(
          title: '第一章',
          url: 'https://example.com/chapter/1',
        ),
        Chapter(
          title: '第二章',
          url: 'https://example.com/chapter/2',
        ),
      ];

      final currentChapter = testChapters[1];
      final longContent = 'A' * 100000; // 100KB的内容

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/1'))
          .thenAnswer((_) async => longContent);

      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
        maxHistoryCount: 1,
      );

      expect(result, hasLength(longContent.length + '历史章节: 第一章\n\n'.length));
    });

    test('默认maxHistoryCount应为2', () async {
      final testChapters = [
        Chapter(title: '第一章', url: 'https://example.com/chapter/1'),
        Chapter(title: '第二章', url: 'https://example.com/chapter/2'),
        Chapter(title: '第三章', url: 'https://example.com/chapter/3'),
        Chapter(title: '第四章', url: 'https://example.com/chapter/4'),
      ];

      final currentChapter = testChapters[3];

      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/3'))
          .thenAnswer((_) async => '第三章');
      when(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .thenAnswer((_) async => '第二章');

      // 不指定maxHistoryCount，应使用默认值2
      final result = await historyService.fetchHistoryChaptersContent(
        chapters: testChapters,
        currentChapter: currentChapter,
      );

      expect(result, contains('第三章'));
      expect(result, contains('第二章'));
      expect(result, isNot(contains('第一章')));
      verify(mockDatabaseService.getCachedChapter('https://example.com/chapter/3'))
          .called(1);
      verify(mockDatabaseService.getCachedChapter('https://example.com/chapter/2'))
          .called(1);
      verifyNever(mockDatabaseService.getCachedChapter('https://example.com/chapter/1'));
    });
  });

  group('ChapterHistoryService - 工厂方法', () {
    test('create()应该返回有效实例', () {
      final service = ChapterHistoryService.create();
      expect(service, isNotNull);
      expect(service, isA<ChapterHistoryService>());
    });

    test('手动构造函数应该接受自定义依赖', () {
      final customService = ChapterHistoryService(
        databaseService: mockDatabaseService,
        apiService: mockApiService,
      );

      expect(customService, isNotNull);
      expect(customService, isA<ChapterHistoryService>());
    });
  });
}
