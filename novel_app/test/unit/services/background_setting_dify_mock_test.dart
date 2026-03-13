import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/services/chapter_service.dart';
import 'package:novel_app/core/interfaces/repositories/i_chapter_repository.dart';
import 'package:novel_app/core/interfaces/repositories/i_character_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock classes implementing interfaces
class MockChapterRepository extends Mock implements IChapterRepository {}
class MockCharacterRepository extends Mock implements ICharacterRepository {}

/// ChapterService - buildChapterGenerationInputs 背景设定传递测试
///
/// 测试 ChapterService.buildChapterGenerationInputs 方法是否正确传递背景设定给 Dify：
/// - 背景设定存在时应该传递 background_setting 字段
/// - 背景设定为空时应该传递空字符串
/// - 背景设定使用正确的字段（backgroundSetting 而非 description）
void main() {
  // 初始化测试环境
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'ai_writer_prompt': ''});

  late ChapterService chapterService;
  late MockChapterRepository mockChapterRepo;
  late MockCharacterRepository mockCharacterRepo;

  setUp(() {
    mockChapterRepo = MockChapterRepository();
    mockCharacterRepo = MockCharacterRepository();

    chapterService = ChapterService(
      chapterRepository: mockChapterRepo,
      characterRepository: mockCharacterRepo,
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
        url: 'https://example.com/novel/test',
        description: '这是小说简介',
        backgroundSetting: '这是一个测试背景设定：\n- 世界观：未来科幻世界\n- 主角：张三\n- 设定：人类已掌握超光速技术',
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

      // Mock repository responses
      when(mockCharacterRepository.getCharactersByIds(any))
          .thenAnswer((_) async => []);

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
      expect(inputs['background_setting'], testNovel.backgroundSetting);
      expect(inputs['background_setting'], isNotEmpty);
    });

    test('背景设定为空字符串时 - 应该传递空字符串', () async {
      // Arrange（准备）
      final novelWithEmptyBackground = testNovel.copyWith(
        backgroundSetting: '',
      );
      const userInput = '请生成第三章内容';

      // Mock repository responses
      when(mockCharacterRepository.getCharactersByIds(any))
          .thenAnswer((_) async => []);

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

    test('背景设定为 null 时 - 应该传递空字符串', () async {
      // Arrange（准备）
      final novelWithNullBackground = testNovel.copyWith(
        backgroundSetting: null,
      );
      const userInput = '请生成第三章内容';

      // Mock repository responses
      when(mockCharacterRepository.getCharactersByIds(any))
          .thenAnswer((_) async => []);

      // Act（执行）
      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: novelWithNullBackground,
        chapters: testChapters,
        afterIndex: 1,
        userInput: userInput,
        characterIds: [],
      );

      // Assert（断言）
      expect(inputs, containsPair('background_setting', isNotNull));
      expect(inputs['background_setting'], '');
    });

    test('背景设定应该使用 backgroundSetting 字段而非 description', () async {
      // Arrange（准备）
      final novelWithDifferentFields = testNovel.copyWith(
        description: '这是小说简介（description字段）',
        backgroundSetting: '这是背景设定（backgroundSetting字段）',
      );
      const userInput = '请生成第三章内容';

      // Mock repository responses
      when(mockCharacterRepository.getCharactersByIds(any))
          .thenAnswer((_) async => []);

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
      expect(inputs['background_setting'], '这是背景设定（backgroundSetting字段）');
      expect(inputs['background_setting'], isNot(novelWithDifferentFields.description));
    });

    test('完整输入验证 - 应该包含所有必需字段', () async {
      // Arrange（准备）
      const userInput = '请生成第三章内容';

      // Mock repository responses
      when(mockCharacterRepository.getCharactersByIds(any))
          .thenAnswer((_) async => []);

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
      expect(inputs, containsPair('background_setting', testNovel.backgroundSetting));
      expect(inputs, containsPair('ai_writer_setting', isNotNull));
      expect(inputs, containsPair('next_chapter_overview', ''));
      expect(inputs, containsPair('roles', isNotNull));
    });

    test('背景设定包含特殊字符 - 应该正确传递', () async {
      // Arrange（准备）
      const specialBackgroundSetting = r'''
# 背景设定

这是一个包含 **Markdown** 格式的背景设定：

- 世界观：未来世界
- 主角："李四" & '王五'
- 设定：人类已掌握 <光速> 技术

## 详细设定

1. 技术水平：超光速
2. 社会结构：联邦制
''';
      final novelWithSpecialBackground = testNovel.copyWith(
        backgroundSetting: specialBackgroundSetting,
      );
      const userInput = '请生成第三章内容';

      // Mock repository responses
      when(mockCharacterRepository.getCharactersByIds(any))
          .thenAnswer((_) async => []);

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

    test('空章节列表 - 应该正常工作', () async {
      // Arrange（准备）
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://example.com/novel/test',
        backgroundSetting: '测试背景设定',
      );
      const userInput = '请生成第一章内容';

      // Mock repository responses
      when(mockCharacterRepository.getCharactersByIds(any))
          .thenAnswer((_) async => []);

      // Act（执行）
      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: testNovel,
        chapters: [],
        afterIndex: -1,
        userInput: userInput,
        characterIds: [],
      );

      // Assert（断言）
      expect(inputs, containsPair('background_setting', '测试背景设定'));
      expect(inputs, containsPair('history_chapters_content', isNotNull));
    });

    test('超长背景设定 - 应该正确传递', () async {
      // Arrange（准备）
      final longBackgroundSetting = '背景设定' * 10000; // 约 50,000 字符
      final novelWithLongBackground = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://example.com/novel/test',
        backgroundSetting: longBackgroundSetting,
      );
      const userInput = '请生成内容';

      // Mock repository responses
      when(mockCharacterRepository.getCharactersByIds(any))
          .thenAnswer((_) async => []);

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
      expect(inputs['background_setting']!.length, 50000);
    });

    test('afterIndex 为负数 - 应该正常工作', () async {
      // Arrange（准备）
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://example.com/novel/test',
        backgroundSetting: '测试背景设定',
      );
      const userInput = '请生成第一章内容';

      // Mock repository responses
      when(mockCharacterRepository.getCharactersByIds(any))
          .thenAnswer((_) async => []);

      // Act（执行）
      final inputs = await chapterService.buildChapterGenerationInputs(
        novel: testNovel,
        chapters: [],
        afterIndex: -1,
        userInput: userInput,
        characterIds: [],
      );

      // Assert（断言）
      expect(inputs, containsPair('background_setting', '测试背景设定'));
    });
  });
}
