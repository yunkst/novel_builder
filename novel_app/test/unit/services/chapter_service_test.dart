import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/chapter_service.dart';
import 'package:novel_app/services/database_service.dart';
import '../../test_bootstrap.dart';

@GenerateMocks([DatabaseService])
import 'chapter_service_test.mocks.dart';

/// ChapterService 单元测试
///
/// 测试章节服务的核心功能：
/// - 历史章节内容获取
/// - 前文章节列表获取
/// - 角色信息格式化
/// - AI参数构建
void main() {
  // 初始化数据库FFI
  initDatabaseTests();

  group('ChapterService 历史章节内容', () {
    late ChapterService chapterService;
    late MockDatabaseService mockDb;
    late List<Chapter> testChapters;
    late Novel testNovel;

    setUp(() {
      mockDb = MockDatabaseService();
      chapterService = ChapterService(databaseService: mockDb);

      // 创建测试数据
      testChapters = [
        Chapter(title: '第一章', url: 'chapter1', chapterIndex: 0),
        Chapter(title: '第二章', url: 'chapter2', chapterIndex: 1),
        Chapter(title: '第三章', url: 'chapter3', chapterIndex: 2),
        Chapter(title: '第四章', url: 'chapter4', chapterIndex: 3),
        Chapter(title: '第五章', url: 'chapter5', chapterIndex: 4),
      ];

      testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'test_novel',
        description: '这是一个测试小说的背景描述',
      );
    });

    test('空章节列表且无novel时应返回空字符串', () async {
      final result = await chapterService.getHistoryChaptersContent(
        chapters: [],
        afterIndex: 0,
      );

      expect(result, isEmpty);
    });

    test('空章节列表且有novel时应返回默认引导文本', () async {
      final result = await chapterService.getHistoryChaptersContent(
        chapters: [],
        afterIndex: 0,
        novel: testNovel,
      );

      expect(result, contains('这是小说的开始'));
      expect(result, contains('引人入胜的第一章'));
      expect(result, contains('小说背景：${testNovel.description}'));
      expect(result, contains('作者：${testNovel.author}'));
    });

    test('空章节列表novel无描述时应不显示背景', () async {
      final novelWithoutDesc = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'test_novel',
      );

      final result = await chapterService.getHistoryChaptersContent(
        chapters: [],
        afterIndex: 0,
        novel: novelWithoutDesc,
      );

      expect(result, contains('这是小说的开始'));
      expect(result, isNot(contains('小说背景：')));
    });

    test('应获取最近章节的内容', () async {
      // Mock数据库返回
      when(mockDb.getCachedChapter('chapter2')).thenAnswer((_) async => '第二章内容');
      when(mockDb.getCachedChapter('chapter3')).thenAnswer((_) async => '第三章内容');
      when(mockDb.getCachedChapter('chapter4')).thenAnswer((_) async => '第四章内容');

      final result = await chapterService.getHistoryChaptersContent(
        chapters: testChapters,
        afterIndex: 3, // 第四章
      );

      expect(result, contains('第四章'));
      expect(result, contains('第四章内容'));
      verify(mockDb.getCachedChapter('chapter4')).called(1);
    });

    test('未缓存的章节应被跳过', () async {
      when(mockDb.getCachedChapter('chapter1')).thenAnswer((_) async => null); // 未缓存
      when(mockDb.getCachedChapter('chapter2')).thenAnswer((_) async => '第二章内容');
      when(mockDb.getCachedChapter('chapter3')).thenAnswer((_) async => null); // 未缓存

      final result = await chapterService.getHistoryChaptersContent(
        chapters: testChapters,
        afterIndex: 2,
      );

      expect(result, contains('第二章'));
      expect(result, isNot(contains('第三章')));
    });

    test('索引越界时应返回空字符串', () async {
      final result = await chapterService.getHistoryChaptersContent(
        chapters: testChapters,
        afterIndex: 10, // 越界
      );

      expect(result, isEmpty);
    });

    test('负索引时应返回空字符串', () async {
      final result = await chapterService.getHistoryChaptersContent(
        chapters: testChapters,
        afterIndex: -1,
      );

      expect(result, isEmpty);
    });

    test('应正确格式化章节标题和内容', () async {
      when(mockDb.getCachedChapter('chapter1')).thenAnswer((_) async => '测试内容');

      final result = await chapterService.getHistoryChaptersContent(
        chapters: testChapters,
        afterIndex: 0,
      );

      expect(result, contains('第1章 第一章'));
      expect(result, contains('测试内容'));
    });

    test('多个历史章节应被拼接', () async {
      when(mockDb.getCachedChapter(any)).thenAnswer((_) async => '章节内容');

      final result = await chapterService.getHistoryChaptersContent(
        chapters: testChapters,
        afterIndex: 2,
      );

      // 应该包含多个章节
      expect(result, contains('第'));
      expect(result, contains('章'));
    });
  });

  group('ChapterService 前文章节内容列表', () {
    late ChapterService chapterService;
    late MockDatabaseService mockDb;
    late List<Chapter> testChapters;

    setUp(() {
      mockDb = MockDatabaseService();
      chapterService = ChapterService(databaseService: mockDb);

      testChapters = [
        Chapter(title: '第一章', url: 'chapter1', chapterIndex: 0),
        Chapter(title: '第二章', url: 'chapter2', chapterIndex: 1),
        Chapter(title: '第三章', url: 'chapter3', chapterIndex: 2),
      ];
    });

    test('应返回前文章节内容列表', () async {
      when(mockDb.getCachedChapter('chapter1')).thenAnswer((_) async => '第一章内容');
      when(mockDb.getCachedChapter('chapter2')).thenAnswer((_) async => '第二章内容');
      when(mockDb.getCachedChapter('chapter3')).thenAnswer((_) async => '第三章内容');

      final result = await chapterService.getPreviousChaptersContent(
        chapters: testChapters,
        afterIndex: 2,
      );

      expect(result, isA<List<String>>());
      expect(result.length, greaterThan(0));
    });

    test('未缓存章节应显示提示', () async {
      when(mockDb.getCachedChapter(any)).thenAnswer((_) async => null);

      final result = await chapterService.getPreviousChaptersContent(
        chapters: testChapters,
        afterIndex: 1,
      );

      expect(result, anyElement(contains('内容未缓存')));
    });

    test('已缓存章节应包含实际内容', () async {
      when(mockDb.getCachedChapter('chapter1')).thenAnswer((_) async => '实际内容');

      final result = await chapterService.getPreviousChaptersContent(
        chapters: testChapters,
        afterIndex: 0,
      );

      expect(result, anyElement(contains('实际内容')));
      expect(result, isNot(anyElement(contains('内容未缓存'))));
    });

    test('afterIndex为0时应只返回当前章', () async {
      when(mockDb.getCachedChapter('chapter1')).thenAnswer((_) async => '第一章内容');

      final result = await chapterService.getPreviousChaptersContent(
        chapters: testChapters,
        afterIndex: 0,
      );

      expect(result.length, 1);
      expect(result.first, contains('第1章'));
    });

    test('应正确格式化章节号', () async {
      when(mockDb.getCachedChapter(any)).thenAnswer((_) async => '内容');

      final result = await chapterService.getPreviousChaptersContent(
        chapters: testChapters,
        afterIndex: 2,
      );

      expect(result, anyElement(contains('第1章')));
      expect(result, anyElement(contains('第2章')));
      expect(result, anyElement(contains('第3章')));
    });
  });

  group('ChapterService 角色信息格式化', () {
    late ChapterService chapterService;
    late MockDatabaseService mockDb;

    setUp(() {
      mockDb = MockDatabaseService();
      chapterService = ChapterService(databaseService: mockDb);
    });

    test('空角色列表应返回默认文本', () async {
      final result = await chapterService.getRolesInfoForAI([]);

      expect(result, '无特定角色出场');
    });

    test('应查询数据库获取角色信息', () async {
      final characters = [
        Character(
          id: 1,
          novelUrl: 'test_novel',
          name: '张三',
          age: 25,
          appearanceFeatures: '英俊',
          personality: '勇敢',
        ),
      ];

      when(mockDb.getCharactersByIds([1])).thenAnswer((_) async => characters as List<Character>);

      await chapterService.getRolesInfoForAI([1]);

      verify(mockDb.getCharactersByIds([1])).called(1);
    });

    test('应返回格式化的角色信息', () async {
      final characters = [
        Character(
          id: 1,
          novelUrl: 'test_novel',
          name: '张三',
          age: 25,
          appearanceFeatures: '英俊',
          personality: '勇敢',
        ),
      ];

      when(mockDb.getCharactersByIds([1])).thenAnswer((_) async => characters as List<Character>);

      final result = await chapterService.getRolesInfoForAI([1]);

      expect(result, contains('张三'));
    });

    test('多个角色应被一起格式化', () async {
      final characters = [
        Character(id: 1, novelUrl: 'test_novel', name: '张三'),
        Character(id: 2, novelUrl: 'test_novel', name: '李四'),
      ];

      when(mockDb.getCharactersByIds([1, 2])).thenAnswer((_) async => characters as List<Character>);

      final result = await chapterService.getRolesInfoForAI([1, 2]);

      expect(result, contains('张三'));
      expect(result, contains('李四'));
    });
  });

  group('ChapterService AI参数构建', () {
    late ChapterService chapterService;
    late MockDatabaseService mockDb;
    late Novel testNovel;
    late List<Chapter> testChapters;

    setUp(() {
      mockDb = MockDatabaseService();
      chapterService = ChapterService(databaseService: mockDb);

      testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'test_novel',
        description: '背景设定',
      );

      testChapters = [
        Chapter(title: '第一章', url: 'chapter1', chapterIndex: 0),
        Chapter(title: '第二章', url: 'chapter2', chapterIndex: 1),
      ];

      // Mock数据库调用
      when(mockDb.getCachedChapter(any)).thenAnswer((_) async => '章节内容');
      when(mockDb.getCharactersByIds(any)).thenAnswer((_) async => []);
    });

    test('应构建完整的inputs参数', () async {
      final result = await chapterService.buildChapterGenerationInputs(
        novel: testNovel,
        chapters: testChapters,
        afterIndex: 1,
        userInput: '生成第二章',
        characterIds: [],
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result['user_input'], '生成第二章');
      expect(result['background_setting'], testNovel.description);
    });

    test('应包含历史章节内容', () async {
      final result = await chapterService.buildChapterGenerationInputs(
        novel: testNovel,
        chapters: testChapters,
        afterIndex: 1,
        userInput: '测试',
        characterIds: [],
      );

      expect(result.containsKey('history_chapters_content'), true);
      expect(result['history_chapters_content'], isNotEmpty);
    });

    test('应包含角色信息', () async {
      final result = await chapterService.buildChapterGenerationInputs(
        novel: testNovel,
        chapters: testChapters,
        afterIndex: 0,
        userInput: '测试',
        characterIds: [1, 2],
      );

      expect(result.containsKey('roles'), true);
      verify(mockDb.getCharactersByIds([1, 2])).called(1);
    });

    test('应包含空的cmd和current_chapter_content字段', () async {
      final result = await chapterService.buildChapterGenerationInputs(
        novel: testNovel,
        chapters: [],
        afterIndex: 0,
        userInput: '测试',
        characterIds: [],
      );

      expect(result['cmd'], '');
      expect(result['current_chapter_content'], '');
      expect(result['ai_writer_setting'], '');
      expect(result['next_chapter_overview'], '');
    });

    test('空章节列表时应使用默认引导文本', () async {
      final result = await chapterService.buildChapterGenerationInputs(
        novel: testNovel,
        chapters: [],
        afterIndex: 0,
        userInput: '创建第一章',
        characterIds: [],
      );

      expect(result['history_chapters_content'], contains('这是小说的开始'));
    });

    test('无描述的novel应设置background_setting为空字符串', () async {
      final novelWithoutDesc = Novel(
        title: '测试',
        author: '作者',
        url: 'test',
      );

      final result = await chapterService.buildChapterGenerationInputs(
        novel: novelWithoutDesc,
        chapters: [],
        afterIndex: 0,
        userInput: '测试',
        characterIds: [],
      );

      expect(result['background_setting'], '');
    });

    test('应正确传递所有必需参数', () async {
      final result = await chapterService.buildChapterGenerationInputs(
        novel: testNovel,
        chapters: testChapters,
        afterIndex: 1,
        userInput: '用户输入内容',
        characterIds: [1],
      );

      expect(result.keys, containsAll([
        'user_input',
        'cmd',
        'current_chapter_content',
        'history_chapters_content',
        'background_setting',
        'ai_writer_setting',
        'next_chapter_overview',
        'roles',
      ]));
    });
  });

  group('ChapterService 边界场景', () {
    late ChapterService chapterService;
    late MockDatabaseService mockDb;

    setUp(() {
      mockDb = MockDatabaseService();
      chapterService = ChapterService(databaseService: mockDb);
    });

    test('极长章节列表应正确处理', () async {
      final longChapterList = List.generate(
        100,
        (i) => Chapter(title: '第${i + 1}章', url: 'chapter$i', chapterIndex: i),
      );

      when(mockDb.getCachedChapter(any)).thenAnswer((_) async => '内容');

      final result = await chapterService.getHistoryChaptersContent(
        chapters: longChapterList,
        afterIndex: 99,
      );

      expect(result, isNotEmpty);
    });

    test('章节内容为空字符串时应被跳过', () async {
      final chapters = [
        Chapter(title: '第一章', url: 'chapter1', chapterIndex: 0),
        Chapter(title: '第二章', url: 'chapter2', chapterIndex: 1),
      ];

      when(mockDb.getCachedChapter('chapter1')).thenAnswer((_) async => '');
      when(mockDb.getCachedChapter('chapter2')).thenAnswer((_) async => '有内容');

      final result = await chapterService.getHistoryChaptersContent(
        chapters: chapters,
        afterIndex: 1,
      );

      expect(result, isNot(contains('第一章')));
      expect(result, contains('第二章'));
    });

    test('角色列表包含大量ID时应正确处理', () async {
      final manyIds = List.generate(50, (i) => i);
      final characters = manyIds
          .map((id) => Character(id: id, novelUrl: 'test_novel', name: '角色$id'))
          .toList();

      when(mockDb.getCharactersByIds(manyIds)).thenAnswer((_) async => characters as List<Character>);

      final result = await chapterService.getRolesInfoForAI(manyIds);

      expect(result, isNotEmpty);
      verify(mockDb.getCharactersByIds(manyIds)).called(1);
    });

    test('特殊字符在章节内容中应正常处理', () async {
      final chapters = [
        Chapter(title: '第一章', url: 'chapter1', chapterIndex: 0),
      ];

      const specialContent = '特殊字符: \n\t\r测试';

      when(mockDb.getCachedChapter('chapter1')).thenAnswer((_) async => specialContent);

      final result = await chapterService.getHistoryChaptersContent(
        chapters: chapters,
        afterIndex: 0,
      );

      expect(result, contains(specialContent));
    });
  });

  group('ChapterService 错误处理', () {
    test('DatabaseService抛出异常时应传播', () async {
      final mockDb = MockDatabaseService();
      final chapterService = ChapterService(databaseService: mockDb);

      final chapters = [
        Chapter(title: '第一章', url: 'chapter1', chapterIndex: 0),
      ];

      when(mockDb.getCachedChapter(any)).thenThrow(Exception('数据库错误'));

      expect(
        () => chapterService.getHistoryChaptersContent(
          chapters: chapters,
          afterIndex: 0,
        ),
        throwsException,
      );
    });

    test('获取角色失败时应传播异常', () async {
      final mockDb = MockDatabaseService();
      final chapterService = ChapterService(databaseService: mockDb);

      when(mockDb.getCharactersByIds(any)).thenThrow(Exception('查询失败'));

      expect(
        () => chapterService.getRolesInfoForAI([1]),
        throwsException,
      );
    });
  });

  group('ChapterService 默认构造函数', () {
    test('应使用默认DatabaseService实例', () {
      final chapterService = ChapterService();

      expect(chapterService, isNotNull);
    });
  });

  group('ChapterService 依赖注入', () {
    test('应使用传入的DatabaseService', () {
      final mockDb = MockDatabaseService();
      final chapterService = ChapterService(databaseService: mockDb);

      expect(chapterService, isNotNull);
    });

    test('传入null时应使用默认DatabaseService', () {
      final chapterService = ChapterService(databaseService: null);

      expect(chapterService, isNotNull);
    });
  });
}

/// 测试数据创建辅助
class ChapterTestData {
  static Chapter createChapter({
    required String title,
    required String url,
    required int index,
  }) {
    return Chapter(
      title: title,
      url: url,
      chapterIndex: index,
    );
  }

  static List<Chapter> createChapterList(int count) {
    return List.generate(
      count,
      (i) => createChapter(
        title: '第${i + 1}章',
        url: 'chapter$i',
        index: i,
      ),
    );
  }

  static Novel createTestNovel({
    String title = '测试小说',
    String author = '测试作者',
    String? description,
  }) {
    return Novel(
      title: title,
      author: author,
      url: 'test_novel',
      description: description,
    );
  }

  static Character createCharacter({
    required int id,
    required String name,
    String? backgroundStory,
  }) {
    return Character(
      id: id,
      novelUrl: 'test_novel',
      name: name,
      backgroundStory: backgroundStory,
    );
  }
}
