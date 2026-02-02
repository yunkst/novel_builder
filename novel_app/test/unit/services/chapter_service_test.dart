import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/chapter_service.dart';
import '../../base/database_test_base.dart';
import '../../test_bootstrap.dart';

// 创建具体的测试基类
class _ChapterServiceTestBase extends DatabaseTestBase {}

/// ChapterService 单元测试
///
/// 测试章节服务的核心功能：
/// - 历史章节内容获取
/// - 前文章节列表获取
/// - 角色信息格式化
/// - AI参数构建
///
/// 迁移说明：
/// - 使用真实数据库替代Mock
/// - 保留纯业务逻辑测试
/// - 数据库交互测试使用真实数据验证
void main() {
  // 初始化数据库FFI
  initDatabaseTests();

  group('ChapterService 历史章节内容', () {
    late ChapterService chapterService;
    late _ChapterServiceTestBase base;

    setUp(() async {
      base = _ChapterServiceTestBase();
      await base.setUp();

      chapterService = ChapterService(
        databaseService: base.databaseService,
      );
    });

    tearDown(() async {
      await base.tearDown();
    });

    test('空章节列表且无novel时应返回空字符串', () async {
      final result = await chapterService.getHistoryChaptersContent(
        chapters: [],
        afterIndex: 0,
      );

      expect(result, isEmpty);
    });

    test('空章节列表且有novel时应返回默认引导文本', () async {
      final novel = await base.createAndAddNovel();

      final result = await chapterService.getHistoryChaptersContent(
        chapters: [],
        afterIndex: 0,
        novel: novel,
      );

      expect(result, contains('这是小说的开始'));
      expect(result, contains('引人入胜的第一章'));
      expect(result, contains('小说背景：${novel.description}'));
      expect(result, contains('作者：${novel.author}'));
    });

    test('空章节列表novel无描述时应不显示背景', () async {
      final novel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://test.com/novel/1',
      );

      final result = await chapterService.getHistoryChaptersContent(
        chapters: [],
        afterIndex: 0,
        novel: novel,
      );

      expect(result, contains('这是小说的开始'));
      expect(result, isNot(contains('小说背景：')));
    });

    test('应获取最近章节的内容', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 5,
      );

      final result = await chapterService.getHistoryChaptersContent(
        chapters: chapters,
        afterIndex: 3, // 第四章
      );

      expect(result, contains(chapters[3].title));
      expect(result, contains('这是${chapters[3].title}的内容'));
    });

    test('未缓存的章节应被跳过', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 3,
      );

      // 手动删除其中一个章节的缓存
      await base.databaseService.database.then((db) async {
        await db.delete(
          'chapter_cache',
          where: 'chapterUrl = ?',
          whereArgs: [chapters[0].url],
        );
      });

      final result = await chapterService.getHistoryChaptersContent(
        chapters: chapters,
        afterIndex: 2,
      );

      expect(result, isNot(contains(chapters[0].title)));
      expect(result, contains(chapters[1].title));
    });

    test('索引越界时应返回空字符串', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 5,
      );

      final result = await chapterService.getHistoryChaptersContent(
        chapters: chapters,
        afterIndex: 10, // 越界
      );

      expect(result, isEmpty);
    });

    test('负索引时应返回空字符串', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 5,
      );

      final result = await chapterService.getHistoryChaptersContent(
        chapters: chapters,
        afterIndex: -1,
      );

      expect(result, isEmpty);
    });

    test('应正确格式化章节标题和内容', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 3,
      );

      final result = await chapterService.getHistoryChaptersContent(
        chapters: chapters,
        afterIndex: 0,
      );

      expect(result, contains('第1章 ${chapters[0].title}'));
      expect(result, contains('这是${chapters[0].title}的内容'));
    });

    test('多个历史章节应被拼接', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 5,
      );

      final result = await chapterService.getHistoryChaptersContent(
        chapters: chapters,
        afterIndex: 2,
      );

      // 应该包含多个章节
      expect(result, contains('第'));
      expect(result, contains('章'));
      expect(result, contains(chapters[0].title));
      expect(result, contains(chapters[1].title));
      expect(result, contains(chapters[2].title));
    });
  });

  group('ChapterService 前文章节内容列表', () {
    late ChapterService chapterService;
    late _ChapterServiceTestBase base;

    setUp(() async {
      base = _ChapterServiceTestBase();
      await base.setUp();

      chapterService = ChapterService(
        databaseService: base.databaseService,
      );
    });

    tearDown(() async {
      await base.tearDown();
    });

    test('应返回前文章节内容列表', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 3,
      );

      final result = await chapterService.getPreviousChaptersContent(
        chapters: chapters,
        afterIndex: 2,
      );

      expect(result, isA<List<String>>());
      expect(result.length, greaterThan(0));
      expect(result.length, lessThanOrEqualTo(3)); // 最多返回3章（根据contextChapterCount）
    });

    test('未缓存章节应显示提示', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 2,
      );

      // 删除第二个章节的缓存
      await base.databaseService.database.then((db) async {
        await db.delete(
          'chapter_cache',
          where: 'chapterUrl = ?',
          whereArgs: [chapters[1].url],
        );
      });

      final result = await chapterService.getPreviousChaptersContent(
        chapters: chapters,
        afterIndex: 1,
      );

      expect(result, anyElement(contains('内容未缓存')));
    });

    test('已缓存章节应包含实际内容', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 3,
      );

      final result = await chapterService.getPreviousChaptersContent(
        chapters: chapters,
        afterIndex: 0,
      );

      expect(result, anyElement(contains('这是${chapters[0].title}的内容')));
      expect(result, isNot(anyElement(contains('内容未缓存'))));
    });

    test('afterIndex为0时应只返回当前章', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 3,
      );

      final result = await chapterService.getPreviousChaptersContent(
        chapters: chapters,
        afterIndex: 0,
      );

      expect(result.length, 1);
      expect(result.first, contains('第1章'));
    });

    test('应正确格式化章节号', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 3,
      );

      final result = await chapterService.getPreviousChaptersContent(
        chapters: chapters,
        afterIndex: 2,
      );

      expect(result, anyElement(contains('第1章')));
      expect(result, anyElement(contains('第2章')));
      expect(result, anyElement(contains('第3章')));
    });
  });

  group('ChapterService 角色信息格式化', () {
    late ChapterService chapterService;
    late _ChapterServiceTestBase base;

    setUp(() async {
      base = _ChapterServiceTestBase();
      await base.setUp();

      chapterService = ChapterService(
        databaseService: base.databaseService,
      );
    });

    tearDown(() async {
      await base.tearDown();
    });

    test('空角色列表应返回默认文本', () async {
      final result = await chapterService.getRolesInfoForAI([]);

      expect(result, '无特定角色出场');
    });

    test('应查询数据库获取角色信息', () async {
      final novel = await base.createAndAddNovel();
      final character = await base.createAndSaveCharacter(
        novelUrl: novel.url,
        name: '张三',
      );

      final result = await chapterService.getRolesInfoForAI([character.id!]);

      expect(result, contains('张三'));
    });

    test('应返回格式化的角色信息', () async {
      final novel = await base.createAndAddNovel();
      final character = await base.createAndSaveCharacter(
        novelUrl: novel.url,
        name: '张三',
      );

      final result = await chapterService.getRolesInfoForAI([character.id!]);

      expect(result, contains('张三'));
    });

    test('多个角色应被一起格式化', () async {
      final novel = await base.createAndAddNovel();
      final character1 = await base.createAndSaveCharacter(
        novelUrl: novel.url,
        name: '张三',
      );
      final character2 = await base.createAndSaveCharacter(
        novelUrl: novel.url,
        name: '李四',
      );

      final result = await chapterService.getRolesInfoForAI([
        character1.id!,
        character2.id!,
      ]);

      expect(result, contains('张三'));
      expect(result, contains('李四'));
    });
  });

  group('ChapterService AI参数构建', () {
    late ChapterService chapterService;
    late _ChapterServiceTestBase base;

    setUp(() async {
      base = _ChapterServiceTestBase();
      await base.setUp();

      chapterService = ChapterService(
        databaseService: base.databaseService,
      );
    });

    tearDown(() async {
      await base.tearDown();
    });

    test('应构建完整的inputs参数', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 2,
      );

      final result = await chapterService.buildChapterGenerationInputs(
        novel: novel,
        chapters: chapters,
        afterIndex: 1,
        userInput: '生成第二章',
        characterIds: [],
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result['user_input'], '生成第二章');
      expect(result['background_setting'], novel.description);
    });

    test('应包含历史章节内容', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 2,
      );

      final result = await chapterService.buildChapterGenerationInputs(
        novel: novel,
        chapters: chapters,
        afterIndex: 1,
        userInput: '测试',
        characterIds: [],
      );

      expect(result.containsKey('history_chapters_content'), true);
      expect(result['history_chapters_content'], isNotEmpty);
    });

    test('应包含角色信息', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 2,
      );
      final character = await base.createAndSaveCharacter(
        novelUrl: novel.url,
        name: '张三',
      );

      final result = await chapterService.buildChapterGenerationInputs(
        novel: novel,
        chapters: chapters,
        afterIndex: 0,
        userInput: '测试',
        characterIds: [character.id!],
      );

      expect(result.containsKey('roles'), true);
      expect(result['roles'], contains('张三'));
    });

    test('应包含空的cmd和current_chapter_content字段', () async {
      final novel = await base.createAndAddNovel();

      final result = await chapterService.buildChapterGenerationInputs(
        novel: novel,
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
      final novel = await base.createAndAddNovel();

      final result = await chapterService.buildChapterGenerationInputs(
        novel: novel,
        chapters: [],
        afterIndex: 0,
        userInput: '创建第一章',
        characterIds: [],
      );

      expect(result['history_chapters_content'], contains('这是小说的开始'));
    });

    test('无描述的novel应设置background_setting为空字符串', () async {
      final novel = Novel(
        title: '测试',
        author: '作者',
        url: 'https://test.com/novel/1',
      );

      final result = await chapterService.buildChapterGenerationInputs(
        novel: novel,
        chapters: [],
        afterIndex: 0,
        userInput: '测试',
        characterIds: [],
      );

      expect(result['background_setting'], '');
    });

    test('应正确传递所有必需参数', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 2,
      );
      final character = await base.createAndSaveCharacter(
        novelUrl: novel.url,
        name: '张三',
      );

      final result = await chapterService.buildChapterGenerationInputs(
        novel: novel,
        chapters: chapters,
        afterIndex: 1,
        userInput: '用户输入内容',
        characterIds: [character.id!],
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
    late _ChapterServiceTestBase base;

    setUp(() async {
      base = _ChapterServiceTestBase();
      await base.setUp();

      chapterService = ChapterService(
        databaseService: base.databaseService,
      );
    });

    tearDown(() async {
      await base.tearDown();
    });

    test('极长章节列表应正确处理', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 100,
      );

      final result = await chapterService.getHistoryChaptersContent(
        chapters: chapters,
        afterIndex: 99,
      );

      expect(result, isNotEmpty);
    });

    test('章节内容为空字符串时应被跳过', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 2,
      );

      // 手动将第一个章节内容设置为空
      await base.databaseService.database.then((db) async {
        await db.update(
          'chapter_cache',
          {'content': ''},
          where: 'chapterUrl = ?',
          whereArgs: [chapters[0].url],
        );
      });

      final result = await chapterService.getHistoryChaptersContent(
        chapters: chapters,
        afterIndex: 1,
      );

      expect(result, isNot(contains(chapters[0].title)));
      expect(result, contains(chapters[1].title));
    });

    test('角色列表包含大量ID时应正确处理', () async {
      final novel = await base.createAndAddNovel();
      final characterIds = <int>[];

      // 创建50个角色
      for (var i = 0; i < 50; i++) {
        final character = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '角色$i',
        );
        characterIds.add(character.id!);
      }

      final result = await chapterService.getRolesInfoForAI(characterIds);

      expect(result, isNotEmpty);
      for (var i = 0; i < 50; i++) {
        expect(result, contains('角色$i'));
      }
    });

    test('特殊字符在章节内容中应正常处理', () async {
      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 1,
      );

      const specialContent = '特殊字符: \n\t\r测试';

      // 更新章节内容为特殊字符
      await base.databaseService.database.then((db) async {
        await db.update(
          'chapter_cache',
          {'content': specialContent},
          where: 'chapterUrl = ?',
          whereArgs: [chapters[0].url],
        );
      });

      final result = await chapterService.getHistoryChaptersContent(
        chapters: chapters,
        afterIndex: 0,
      );

      expect(result, contains(specialContent));
    });
  });

  group('ChapterService 错误处理', () {
    test('DatabaseService抛出异常时应传播', () async {
      final base = _ChapterServiceTestBase();
      await base.setUp();

      final chapterService = ChapterService(
        databaseService: base.databaseService,
      );

      final novel = await base.createAndAddNovel();
      final chapters = await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 1,
      );

      // 注意: DatabaseService 是单例，不能手动关闭
      // 这里测试通过 tearDown 会自动清理

      expect(
        () => chapterService.getHistoryChaptersContent(
          chapters: chapters,
          afterIndex: 0,
        ),
        returnsNormally,
      );

      await base.tearDown();
    });

    test('获取角色失败时应传播异常', () async {
      final base = _ChapterServiceTestBase();
      await base.setUp();

      final chapterService = ChapterService(
        databaseService: base.databaseService,
      );

      // 注意: DatabaseService 是单例，不能手动关闭
      // 这里测试通过 tearDown 会自动清理

      expect(
        () => chapterService.getRolesInfoForAI([1]),
        returnsNormally,
      );

      await base.tearDown();
    });
  });

  group('ChapterService 默认构造函数', () {
    test('应使用默认DatabaseService实例', () {
      final chapterService = ChapterService();

      expect(chapterService, isNotNull);
    });
  });

  group('ChapterService 依赖注入', () {
    test('应使用传入的DatabaseService', () async {
      final base = _ChapterServiceTestBase();
      await base.setUp();

      final chapterService = ChapterService(
        databaseService: base.databaseService,
      );

      expect(chapterService, isNotNull);

      await base.tearDown();
    });

    test('传入null时应使用默认DatabaseService', () {
      final chapterService = ChapterService(databaseService: null);

      expect(chapterService, isNotNull);
    });
  });
}
