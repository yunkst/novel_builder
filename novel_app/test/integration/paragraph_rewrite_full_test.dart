import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/services/rewrite_service.dart';
import 'package:novel_app/services/chapter_service.dart';
import 'package:novel_app/services/database_service.dart';

// 生成 Mock 类
@GenerateMocks([DatabaseService])
import 'paragraph_rewrite_full_test.mocks.dart';
import '../test_bootstrap.dart';

void main() {
  // 初始化数据库测试环境
  setUpAll(() {
    initTests();
  });

  group('段落改写完整集成测试', () {
    late MockDatabaseService mockDatabaseService;
    late RewriteService rewriteService;
    late ChapterService chapterService;

    setUp(() {
      mockDatabaseService = MockDatabaseService();
      rewriteService = RewriteService();
      chapterService = ChapterService(databaseService: mockDatabaseService);
    });

    group('章节上下文构建', () {
      test('获取历史章节内容 - 有章节', () async {
        final chapters = [
          Chapter(
            title: '第一章',
            url: 'https://example.com/chapter1',
          ),
          Chapter(
            title: '第二章',
            url: 'https://example.com/chapter2',
          ),
          Chapter(
            title: '第三章',
            url: 'https://example.com/chapter3',
          ),
        ];

        // Mock数据库返回
        when(mockDatabaseService.getCachedChapter('https://example.com/chapter1'))
            .thenAnswer((_) async => '第一章内容');
        when(mockDatabaseService.getCachedChapter('https://example.com/chapter2'))
            .thenAnswer((_) async => '第二章内容');
        when(mockDatabaseService.getCachedChapter('https://example.com/chapter3'))
            .thenAnswer((_) async => '第三章内容');

        final result = await chapterService.getHistoryChaptersContent(
          chapters: chapters,
          afterIndex: 2,
        );

        expect(result, contains('第一章内容'));
        expect(result, contains('第二章内容'));
        expect(result, contains('第三章内容'));
        verify(mockDatabaseService.getCachedChapter('https://example.com/chapter1')).called(1);
        verify(mockDatabaseService.getCachedChapter('https://example.com/chapter2')).called(1);
        verify(mockDatabaseService.getCachedChapter('https://example.com/chapter3')).called(1);
      });

      test('获取历史章节内容 - 空章节列表', () async {
        final novel = Novel(
          title: '测试小说',
          author: '测试作者',
          url: 'https://example.com/novel',
          description: '这是一个仙侠世界',
        );

        final result = await chapterService.getHistoryChaptersContent(
          chapters: [],
          afterIndex: 0,
          novel: novel,
        );

        expect(result, contains('这是小说的开始'));
        expect(result, contains('仙侠世界'));
        expect(result, contains('测试作者'));
      });

      test('获取前文章节列表', () async {
        final chapters = [
          Chapter(title: '第一章', url: 'chapter1'),
          Chapter(title: '第二章', url: 'chapter2'),
          Chapter(title: '第三章', url: 'chapter3'),
        ];

        when(mockDatabaseService.getCachedChapter('chapter1'))
            .thenAnswer((_) async => '第一章内容');
        when(mockDatabaseService.getCachedChapter('chapter2'))
            .thenAnswer((_) async => '第二章内容');
        when(mockDatabaseService.getCachedChapter('chapter3'))
            .thenAnswer((_) async => '第三章内容');

        final result = await chapterService.getPreviousChaptersContent(
          chapters: chapters,
          afterIndex: 2,
        );

        expect(result.length, greaterThan(0));
        expect(result[0], contains('第一章'));
        expect(result[0], contains('第一章内容'));
      });

      test('获取角色信息格式化文本', () async {
        final characters = [
          Character(
            id: 1,
            novelUrl: 'test',
            name: '张三',
            gender: '男',
            age: 30,
            occupation: '医生',
            personality: '冷静',
          ),
          Character(
            id: 2,
            novelUrl: 'test',
            name: '李四',
            gender: '女',
            age: 28,
            occupation: '护士',
            personality: '温柔',
          ),
        ];

        when(mockDatabaseService.getCharactersByIds([1, 2]))
            .thenAnswer((_) async => characters);

        final result = await chapterService.getRolesInfoForAI([1, 2]);

        expect(result, contains('张三'));
        expect(result, contains('李四'));
        expect(result, contains('医生'));
        expect(result, contains('护士'));
        expect(result, contains('冷静'));
        expect(result, contains('温柔'));
      });

      test('空角色ID列表返回默认文本', () async {
        final result = await chapterService.getRolesInfoForAI([]);

        expect(result, '无特定角色出场');
        verifyNever(mockDatabaseService.getCharactersByIds(any));
      });

      test('构建完整章节生成参数', () async {
        final novel = Novel(
          title: '测试小说',
          author: '作者',
          url: 'novel_url',
          description: '背景设定',
        );

        final chapters = [
          Chapter(title: '第一章', url: 'chapter1'),
        ];

        when(mockDatabaseService.getCachedChapter('chapter1'))
            .thenAnswer((_) async => '第一章内容');
        when(mockDatabaseService.getCharactersByIds([1, 2]))
            .thenAnswer((_) async => [
          Character(
            id: 1,
            novelUrl: 'test',
            name: '张三',
            gender: '男',
            age: 30,
          ),
        ]);

        final result = await chapterService.buildChapterGenerationInputs(
          novel: novel,
          chapters: chapters,
          afterIndex: 0,
          userInput: '生成新章节',
          characterIds: [1, 2],
        );

        expect(result['user_input'], '生成新章节');
        expect(result['background_setting'], '背景设定');
        expect(result['history_chapters_content'], contains('第一章内容'));
        expect(result['roles'], contains('张三'));
      });
    });

    group('改写服务集成', () {
      test('完整改写参数构建流程', () {
        final characters = [
          Character(
            novelUrl: 'test',
            name: '主角',
            gender: '男',
            age: 25,
            personality: '勇敢',
          ),
        ];

        final result = rewriteService.buildRewriteInputs(
          selectedText: '主角走进房间',
          userInput: '增加心理描写',
          fullContext: '这是第三章的内容',
          characters: characters,
        );

        expect(result['selected_text'], '主角走进房间');
        expect(result['user_input'], '增加心理描写');
        expect(result['current_chapter_content'], '这是第三章的内容');
        expect(result['cmd'], '特写');
        expect(result['roles'], contains('主角'));
        expect(result['roles'], contains('勇敢'));
      });

      test('包含历史章节的改写参数构建', () {
        final result = rewriteService.buildRewriteInputsWithHistory(
          selectedText: '战斗场景',
          userInput: '增加招式描写',
          currentChapterContent: '当前章节',
          historyChaptersContent: '第一章\n第二章\n第三章',
          backgroundSetting: '修仙世界',
          aiWriterSetting: '文笔华丽',
          rolesInfo: '主角：叶凡',
        );

        expect(result['choice_content'], '战斗场景');
        expect(result['user_input'], '增加招式描写');
        expect(result['history_chapters_content'], contains('第一章'));
        expect(result['background_setting'], '修仙世界');
        expect(result['ai_writer_setting'], '文笔华丽');
        expect(result['roles'], contains('叶凡'));
      });

      test('多角色改写参数构建', () {
        final characters = [
          Character(
            novelUrl: 'test',
            name: '张三',
            gender: '男',
            age: 30,
          ),
          Character(
            novelUrl: 'test',
            name: '李四',
            gender: '女',
            age: 28,
          ),
          Character(
            novelUrl: 'test',
            name: '王五',
            gender: '男',
            age: 35,
          ),
        ];

        final result = rewriteService.buildRewriteInputs(
          selectedText: '三人围坐在一起',
          userInput: '增加对话描写',
          fullContext: '聚会场景',
          characters: characters,
        );

        expect(result['roles'], contains('张三'));
        expect(result['roles'], contains('李四'));
        expect(result['roles'], contains('王五'));
      });
    });

    group('边界情况和错误处理', () {
      test('数据库查询失败处理', () async {
        final chapters = [
          Chapter(title: '第一章', url: 'chapter1'),
        ];

        when(mockDatabaseService.getCachedChapter('chapter1'))
            .thenAnswer((_) async => null);

        final result = await chapterService.getHistoryChaptersContent(
          chapters: chapters,
          afterIndex: 0,
        );

        // 未缓存的内容不应出现在结果中
        expect(result, isEmpty);
      });

      test('部分章节未缓存', () async {
        final chapters = [
          Chapter(title: '第一章', url: 'chapter1'),
          Chapter(title: '第二章', url: 'chapter2'),
          Chapter(title: '第三章', url: 'chapter3'),
        ];

        when(mockDatabaseService.getCachedChapter('chapter1'))
            .thenAnswer((_) async => '第一章内容');
        when(mockDatabaseService.getCachedChapter('chapter2'))
            .thenAnswer((_) async => null); // 未缓存
        when(mockDatabaseService.getCachedChapter('chapter3'))
            .thenAnswer((_) async => '第三章内容');

        final result = await chapterService.getHistoryChaptersContent(
          chapters: chapters,
          afterIndex: 2,
        );

        expect(result, contains('第一章内容'));
        expect(result, isNot(contains('第二章内容')));
        expect(result, contains('第三章内容'));
      });

      test('空字符串输入处理', () {
        final result = rewriteService.buildRewriteInputs(
          selectedText: '',
          userInput: '',
          fullContext: '',
          characters: [],
        );

        expect(result['selected_text'], isEmpty);
        expect(result['user_input'], isEmpty);
        expect(result['current_chapter_content'], isEmpty);
      });

      test('特殊字符输入处理', () {
        final specialText = '包含\n换行\t制表符"引号"\'单引号\'';

        final result = rewriteService.buildRewriteInputs(
          selectedText: specialText,
          userInput: '改写要求',
          fullContext: '上下文',
          characters: [],
        );

        expect(result['selected_text'], specialText);
      });

      test('超长内容处理', () {
        final longContent = List.generate(10000, (i) => '段落$i').join('\n');

        final result = rewriteService.buildRewriteInputsWithHistory(
          selectedText: longContent,
          userInput: '改写',
          currentChapterContent: longContent,
          historyChaptersContent: longContent,
          backgroundSetting: '背景',
          aiWriterSetting: '设定',
          rolesInfo: '角色',
        );

        expect(result['choice_content'].length, longContent.length);
        expect(result['current_chapter_content'].length, longContent.length);
        expect(result['history_chapters_content'].length, longContent.length);
      });
    });

    group('实际使用场景', () {
      test('场景1: 改写战斗段落', () {
        final characters = [
          Character(
            novelUrl: 'test',
            name: '叶凡',
            gender: '男',
            age: 20,
            personality: '坚毅不屈',
            occupation: '修士',
          ),
          Character(
            novelUrl: 'test',
            name: '敌人',
            gender: '男',
            age: 45,
            personality: '阴险狡诈',
            occupation: '魔修',
          ),
        ];

        final result = rewriteService.buildRewriteInputs(
          selectedText: '叶凡挥剑斩向敌人',
          userInput: '增加招式描写和气势渲染',
          fullContext: '这是第三章的高潮战斗',
          characters: characters,
        );

        expect(result['selected_text'], '叶凡挥剑斩向敌人');
        expect(result['user_input'], '增加招式描写和气势渲染');
        expect(result['current_chapter_content'], '这是第三章的高潮战斗');
        expect(result['roles'], contains('叶凡'));
        expect(result['roles'], contains('敌人'));
        expect(result['roles'], contains('坚毅不屈'));
        expect(result['roles'], contains('阴险狡诈'));
      });

      test('场景2: 改写对话段落', () {
        final characters = [
          Character(
            novelUrl: 'test',
            name: '女主角',
            gender: '女',
            age: 18,
            personality: '活泼可爱',
          ),
        ];

        final result = rewriteService.buildRewriteInputsWithHistory(
          selectedText: '"你好"她说道',
          userInput: '增加语气和动作描写',
          currentChapterContent: '两人初次见面的场景',
          historyChaptersContent: '第一章介绍\n第二章铺垫',
          backgroundSetting: '现代校园',
          aiWriterSetting: '青春校园风格',
          rolesInfo: '女主角：活泼可爱，喜欢说话',
        );

        expect(result['choice_content'], '"你好"她说道');
        expect(result['user_input'], '增加语气和动作描写');
        expect(result['history_chapters_content'], contains('第一章介绍'));
        expect(result['background_setting'], '现代校园');
        expect(result['ai_writer_setting'], '青春校园风格');
      });

      test('场景3: 从头生成章节', () async {
        final novel = Novel(
          title: '仙侠小说',
          author: '作者',
          url: 'novel_url',
          description: '一个宏大的修仙世界',
        );

        final result = await chapterService.getHistoryChaptersContent(
          chapters: [],
          afterIndex: 0,
          novel: novel,
        );

        expect(result, contains('这是小说的开始'));
        expect(result, contains('修仙世界'));
        expect(result, contains('作者'));
      });
    });

    group('性能和大数据量', () {
      test('大量历史章节处理', () async {
        final chapters = List.generate(50, (i) => Chapter(
          title: '第${i + 1}章',
          url: 'chapter$i',
        ));

        for (int i = 0; i < 50; i++) {
          when(mockDatabaseService.getCachedChapter('chapter$i'))
              .thenAnswer((_) async => '第${i + 1}章的内容');
        }

        final result = await chapterService.getHistoryChaptersContent(
          chapters: chapters,
          afterIndex: 49,
        );

        // 应该只包含最近的N章（contextChapterCount）
        expect(result, isNotEmpty);
        verify(mockDatabaseService.getCachedChapter(any)).called(greaterThan(0));
      });

      test('大量角色处理', () async {
        final characters = List.generate(20, (i) => Character(
          id: i + 1,
          novelUrl: 'test',
          name: '角色$i',
          gender: i % 2 == 0 ? '男' : '女',
          age: 20 + i,
        ));

        when(mockDatabaseService.getCharactersByIds(List.generate(20, (i) => i + 1)))
            .thenAnswer((_) async => characters);

        final result = await chapterService.getRolesInfoForAI(
          List.generate(20, (i) => i + 1),
        );

        expect(result, contains('角色0'));
        expect(result, contains('角色19'));
      });
    });

    group('Unicode和国际化', () {
      test('中文字符处理', () {
        final result = rewriteService.buildRewriteInputs(
          selectedText: '这是一个中文段落',
          userInput: '改写要求',
          fullContext: '中文上下文',
          characters: [],
        );

        expect(result['selected_text'], '这是一个中文段落');
      });

      test('Emoji表情处理', () {
        final textWithEmoji = '这是一个😊表情🎉段落';

        final result = rewriteService.buildRewriteInputs(
          selectedText: textWithEmoji,
          userInput: '改写',
          fullContext: '上下文',
          characters: [],
        );

        expect(result['selected_text'], textWithEmoji);
        expect(result['selected_text'], contains('😊'));
        expect(result['selected_text'], contains('🎉'));
      });

      test('混合语言文本处理', () {
        final mixedText = 'Hello 世界! This is 测试。';

        final result = rewriteService.buildRewriteInputs(
          selectedText: mixedText,
          userInput: '改写',
          fullContext: '上下文',
          characters: [],
        );

        expect(result['selected_text'], mixedText);
      });
    });
  });
}
