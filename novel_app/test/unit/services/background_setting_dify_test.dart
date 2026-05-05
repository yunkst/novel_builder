import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/repositories/novel_repository.dart';
import 'package:novel_app/repositories/chapter_repository.dart';
import 'package:novel_app/repositories/character_repository.dart';
import 'package:novel_app/services/chapter_service.dart';
import 'package:novel_app/core/database/database_connection.dart';
import 'package:novel_app/core/interfaces/repositories/i_novel_repository.dart';
import 'package:novel_app/core/interfaces/repositories/i_chapter_repository.dart';
import 'package:novel_app/core/interfaces/repositories/i_character_repository.dart';
import 'package:novel_app/services/chapter_manager.dart';

import '../../helpers/test_database_setup.dart';

/// ChapterService - buildChapterGenerationInputs 背景设定传递测试
///
/// 测试 ChapterService.buildChapterGenerationInputs 方法是否正确传递背景设定给 Dify：
/// - 背景设定存在时应该传递 background_setting 字段
/// - 背景设定为空时应该传递空字符串
/// - 背景设定使用正确的字段（backgroundSetting 而非 description）
void main() {
  // 初始化测试环境 - 在所有其他代码之前调用
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  ChapterManager.setTestMode(true);
  TestDatabaseSetup.init();
  // 数据库连接
  late INovelRepository novelRepository;
  late IChapterRepository chapterRepository;
  late ICharacterRepository characterRepository;
  late ChapterService chapterService;

  // 测试数据
  final testNovelUrl = 'https://example.com/novel/test';
  final testBackgroundSetting = '这是一个测试背景设定：\n- 世界观：未来科幻世界\n- 主角：张三\n- 设定：人类已掌握超光速技术';

  /// 全局初始化
  setUpAll(() async {
    // 初始化测试数据库工厂
    TestDatabaseSetup.init();
  });

  /// 设置测试环境
  setUp(() async {
    // 创建真实内存数据库
    final db = await TestDatabaseSetup.createInMemoryDatabase();

    // 创建数据库连接
    final connection = DatabaseConnection.forTesting(db);

    // 初始化 repository
    novelRepository = NovelRepository(dbConnection: connection);
    chapterRepository = ChapterRepository(dbConnection: connection);
    characterRepository = CharacterRepository(dbConnection: connection);

    // 初始化 chapter service
    chapterService = ChapterService(
      chapterRepository: chapterRepository,
      characterRepository: characterRepository,
    );
  });

  group('buildChapterGenerationInputs - 背景设定传递测试', () {
    late Novel testNovel;
    late List<Chapter> testChapters;

    setUp(() {
      // 创建测试小说对象
      testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: testNovelUrl,
        description: '这是小说简介',
        backgroundSetting: testBackgroundSetting,
        isInBookshelf: true,
      );

      // 创建测试章节列表
      testChapters = [
        Chapter(
          title: '第一章',
          url: 'https://example.com/chapter/1',
          content: '这是第一章的内容',
          isCached: true,
          chapterIndex: 0,
        ),
        Chapter(
          title: '第二章',
          url: 'https://example.com/chapter/2',
          content: '这是第二章的内容',
          isCached: true,
          chapterIndex: 1,
        ),
      ];
    });

    test('背景设定存在时 - 应该传递 background_setting 字段', () async {
      // Arrange（准备）
      const userInput = '请生成第三章内容';

      // Act（执行）
      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: testNovel,
        chapters: testChapters,
        afterIndex: 1,
        userInput: userInput,
        characterIds: [],
      );

      // Assert（断言）
      expect(inputs, containsPair('background_setting', isNotNull));
      expect(inputs['background_setting'], testBackgroundSetting);
      expect(inputs['background_setting'], isNotEmpty);
    });

    test('背景设定为空字符串时 - 应该传递空字符串', () async {
      // Arrange（准备）
      final novelWithEmptyBackground = testNovel.copyWith(
        backgroundSetting: '',
      );
      const userInput = '请生成第三章内容';

      // Act（执行）
      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: novelWithEmptyBackground,
        chapters: testChapters,
        afterIndex: 1,
        userInput: userInput,
        characterIds: [],
      );

      // Assert（断言）
      expect(inputs, containsPair('background_setting', isNotNull));
      expect(inputs['background_setting'], '');
    });

    test('背景设定为 null 时 - copyWith 的行为', () async {
      // Note: Novel.copyWith 使用 backgroundSetting ?? this.backgroundSetting
      // 传入 null 会保留原值，而不是设为 null
      // 这是 copyWith 的标准语义：null 表示"不更新此字段"
      final novelWithNullBackground = testNovel.copyWith(
        backgroundSetting: null,
      );

      // 因为 copyWith 的语义，backgroundSetting 应该保持原值
      expect(novelWithNullBackground.backgroundSetting, testBackgroundSetting);

      // 如果要测试真正的 null 行为，直接创建新的 Novel 对象
      final novelWithExplicitNull = Novel(
        title: testNovel.title,
        author: testNovel.author,
        url: testNovel.url,
        backgroundSetting: null,
      );

      const userInput = '请生成第三章内容';

      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: novelWithExplicitNull,
        chapters: testChapters,
        afterIndex: 1,
        userInput: userInput,
        characterIds: [],
      );

      // null 会被转换为空字符串
      expect(inputs, containsPair('background_setting', ''));
    });

    test('背景设定应该使用 backgroundSetting 字段而非 description', () async {
      // Arrange（准备）
      final novelWithDifferentFields = testNovel.copyWith(
        description: '这是小说简介（description字段）',
        backgroundSetting: testBackgroundSetting,
      );
      const userInput = '请生成第三章内容';

      // Act（执行）
      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: novelWithDifferentFields,
        chapters: testChapters,
        afterIndex: 1,
        userInput: userInput,
        characterIds: [],
      );

      // Assert（断言）
      // 应该使用 backgroundSetting 而非 description
      expect(inputs['background_setting'], testBackgroundSetting);
      expect(inputs['background_setting'], isNot(novelWithDifferentFields.description));
    });

    test('完整输入验证 - 应该包含所有必需字段', () async {
      // Arrange（准备）
      const userInput = '请生成第三章内容';

      // Act（执行）
      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: testNovel,
        chapters: testChapters,
        afterIndex: 1,
        userInput: userInput,
        characterIds: [],
      );

      // Assert（断言）
      // 验证所有必需字段都存在
      expect(inputs, containsPair('user_input', userInput));
      expect(inputs, containsPair('cmd', ''));
      expect(inputs, containsPair('current_chapter_content', ''));
      expect(inputs, containsPair('history_chapters_content', isNotNull));
      expect(inputs, containsPair('background_setting', testBackgroundSetting));
      expect(inputs, containsPair('ai_writer_setting', isNotNull));
      expect(inputs, containsPair('next_chapter_overview', ''));
      expect(inputs, containsPair('roles', isNotNull));
    });

    test('背景设定包含特殊字符 - 应该正确传递', () async {
      // Arrange（准备）
      const specialBackgroundSetting = r'''
# 背景设定

这是一个包含 **Markdown** 格式的背景设定：

- 世界观：未来世界 @#$%
- 主角："李四" & '王五'
- 设定：人类已掌握 <光速> 技术

## 详细设定

1. 技术水平：超光速
2. 社会结构：联邦制
3. 特殊符号：！@#¥%……&*（）——+={}[]|\:;"'<>,.?/
''';
      final novelWithSpecialBackground = testNovel.copyWith(
        backgroundSetting: specialBackgroundSetting,
      );
      const userInput = '请生成第三章内容';

      // Act（执行）
      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: novelWithSpecialBackground,
        chapters: testChapters,
        afterIndex: 1,
        userInput: userInput,
        characterIds: [],
      );

      // Assert（断言）
      expect(inputs['background_setting'], specialBackgroundSetting);
      expect(inputs['background_setting'], contains('世界观'));
    });
  });

  group('buildChapterGenerationInputs - 边界情况测试', () {
    test('空章节列表 - 应该正常工作', () async {
      // Arrange（准备）
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: testNovelUrl,
        backgroundSetting: testBackgroundSetting,
      );
      const userInput = '请生成第一章内容';

      // Act（执行）
      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: testNovel,
        chapters: [],
        afterIndex: -1,
        userInput: userInput,
        characterIds: [],
      );

      // Assert（断言）
      expect(inputs, containsPair('background_setting', testBackgroundSetting));
      expect(inputs, containsPair('history_chapters_content', isNotNull));
    });

    test('超长背景设定 - 应该正确传递', () async {
      // Arrange（准备）
      final longBackgroundSetting = '背景设定' * 10000; // 约 50,000 字符
      final novelWithLongBackground = Novel(
        title: '测试小说',
        author: '测试作者',
        url: testNovelUrl,
        backgroundSetting: longBackgroundSetting,
      );
      const userInput = '请生成内容';

      // Act（执行）
      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: novelWithLongBackground,
        chapters: [],
        afterIndex: -1,
        userInput: userInput,
        characterIds: [],
      );

      // Assert（断言）
      expect(inputs['background_setting'], longBackgroundSetting);
      // '背景设定' 是 4 个字符，4 * 10000 = 40000
      expect(inputs['background_setting']!.length, 40000);
    });

    test('afterIndex 为负数 - 应该正常工作', () async {
      // Arrange（准备）
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: testNovelUrl,
        backgroundSetting: testBackgroundSetting,
      );
      const userInput = '请生成第一章内容';

      // Act（执行）
      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: testNovel,
        chapters: [],
        afterIndex: -1,
        userInput: userInput,
        characterIds: [],
      );

      // Assert（断言）
      expect(inputs, containsPair('background_setting', testBackgroundSetting));
    });
  });

  group('NovelRepository - 背景设定存储测试', () {
    test('updateBackgroundSetting 应该正确更新背景设定', () async {
      // Arrange（准备）
      // 先插入测试小说
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: testNovelUrl,
        backgroundSetting: '初始背景设定',
      );
      await novelRepository.addToBookshelf(testNovel);

      const newBackgroundSetting = '这是新的背景设定';
      final novelUrl = testNovelUrl;

      // Act（执行）
      final result = await novelRepository.updateBackgroundSetting(
        novelUrl,
        newBackgroundSetting,
      );

      // Assert（断言）
      expect(result, greaterThan(0));

      // 验证更新是否成功
      final retrieved = await novelRepository.getBackgroundSetting(novelUrl);
      expect(retrieved, newBackgroundSetting);
    });

    test('updateBackgroundSetting 传入 null - 应该清除背景设定', () async {
      // Arrange（准备）
      // 先插入测试小说
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: testNovelUrl,
        backgroundSetting: '初始背景设定',
      );
      await novelRepository.addToBookshelf(testNovel);

      final novelUrl = testNovelUrl;

      // Act（执行）
      final result = await novelRepository.updateBackgroundSetting(
        novelUrl,
        null,
      );

      // Assert（断言）
      expect(result, greaterThan(0));

      // 验证更新是否成功
      final retrieved = await novelRepository.getBackgroundSetting(novelUrl);
      expect(retrieved, null);
    });

    test('getBackgroundSetting 应该返回正确的背景设定', () async {
      // Arrange（准备）
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: testNovelUrl,
        backgroundSetting: testBackgroundSetting,
      );
      await novelRepository.addToBookshelf(testNovel);

      final novelUrl = testNovelUrl;

      // Act（执行）
      final result = await novelRepository.getBackgroundSetting(novelUrl);

      // Assert（断言）
      expect(result, testBackgroundSetting);
    });

    test('getBackgroundSetting 不存在的小说 - 应该返回 null', () async {
      // Arrange（准备）
      const nonExistentUrl = 'https://example.com/novel/nonexistent';

      // Act（执行）
      final result = await novelRepository.getBackgroundSetting(nonExistentUrl);

      // Assert（断言）
      expect(result, isNull);
    });

    test('背景设定的完整流程 - 应该正确存储和读取', () async {
      // Arrange（准备）
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: testNovelUrl,
        backgroundSetting: '初始背景设定',
      );
      await novelRepository.addToBookshelf(testNovel);

      final novelUrl = testNovelUrl;
      const background1 = '初始背景设定';
      const background2 = '更新后的背景设定';

      // Act & Assert（执行并断言）
      // 1. 存储初始背景设定
      var result = await novelRepository.updateBackgroundSetting(
        novelUrl,
        background1,
      );
      expect(result, greaterThan(0));

      var retrieved = await novelRepository.getBackgroundSetting(novelUrl);
      expect(retrieved, background1);

      // 2. 更新背景设定
      result = await novelRepository.updateBackgroundSetting(
        novelUrl,
        background2,
      );
      expect(result, greaterThan(0));

      retrieved = await novelRepository.getBackgroundSetting(novelUrl);
      expect(retrieved, background2);

      // 3. 清除背景设定
      result = await novelRepository.updateBackgroundSetting(
        novelUrl,
        null,
      );
      expect(result, greaterThan(0));

      retrieved = await novelRepository.getBackgroundSetting(novelUrl);
      expect(retrieved, isNull);
    });
  });
}
