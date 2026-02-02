import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/character_extraction_service.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/chapter.dart';
import '../../test_helpers/mock_data.dart';
import '../../test_bootstrap.dart';

/// CharacterExtractionService 单元测试
///
/// 测试角色提取服务的核心功能：
/// - 搜索包含角色名/别名的章节
/// - 提取匹配位置周围的上下文
/// - 合并并去重上下文片段
/// - 计算预计内容长度
void main() {
  // 设置FFI用于测试环境
  setUpAll(() {
    initTests();
  });

  group('CharacterExtractionService - 搜索章节测试', () {
    late DatabaseService dbService;
    late CharacterExtractionService extractionService;
    final testNovelUrl = 'https://test.com/novel/1';

    setUp(() async {
      // 使用全局DatabaseService单例，因为CharacterExtractionService内部使用单例
      // 这是单例模式的限制，理想情况应该支持依赖注入
      dbService = DatabaseService();
      extractionService = CharacterExtractionService();

      // 清理并创建测试数据
      final db = await dbService.database;
      await db.delete('chapter_cache');

      // 创建测试章节
      final chapters = [
        MockData.createTestChapter(
          title: '第一章 出场',
          url: '$testNovelUrl/chapter/1',
          content: '张三走进了房间，李四已经在那里等他了。',
          chapterIndex: 0,
        ),
        MockData.createTestChapter(
          title: '第二章 对话',
          url: '$testNovelUrl/chapter/2',
          content: '李四说："张三，你终于来了。"张三点点头。',
          chapterIndex: 1,
        ),
        MockData.createTestChapter(
          title: '第三章 冲突',
          url: '$testNovelUrl/chapter/3',
          content: '王五突然出现，打断了张三和李四的对话。',
          chapterIndex: 2,
        ),
        MockData.createTestChapter(
          title: '第四章 无关',
          url: '$testNovelUrl/chapter/4',
          content: '这是一个没有角色的平淡章节。',
          chapterIndex: 3,
        ),
      ];

      // 缓存章节
      for (final chapter in chapters) {
        await dbService.cacheChapter(
          testNovelUrl,
          chapter,
          chapter.content ?? '',
        );
      }
    });

    tearDown(() async {
      // 清理测试数据
      final db = await dbService.database;
      await db.delete('chapter_cache');
    });

    test('searchChaptersByName 应该找到包含正式名称的章节', () async {
      final matches = await extractionService.searchChaptersByName(
        novelUrl: testNovelUrl,
        names: ['张三'],
      );

      expect(matches.length, 3); // 第1、2、3章
      expect(matches[0].chapter.chapterIndex, 0);
      expect(matches[1].chapter.chapterIndex, 1);
      expect(matches[2].chapter.chapterIndex, 2);
    });

    test('searchChaptersByName 应该找到包含别名的章节', () async {
      final matches = await extractionService.searchChaptersByName(
        novelUrl: testNovelUrl,
        names: ['老张', '张三'],
      );

      expect(matches.length, 3); // 第1、2、3章包含张三
    });

    test('searchChaptersByName 应该正确统计匹配次数', () async {
      final matches = await extractionService.searchChaptersByName(
        novelUrl: testNovelUrl,
        names: ['张三'],
      );

      // 第一章1次，第二章2次，第三章1次
      expect(matches[0].matchCount, 1);
      expect(matches[1].matchCount, 2);
      expect(matches[2].matchCount, 1);
    });

    test('searchChaptersByName 应该按章节索引升序排列', () async {
      final matches = await extractionService.searchChaptersByName(
        novelUrl: testNovelUrl,
        names: ['李四'],
      );

      // 验证排序
      for (int i = 0; i < matches.length - 1; i++) {
        expect(matches[i].chapter.chapterIndex! <= matches[i + 1].chapter.chapterIndex!, isTrue);
      }
    });

    test('searchChaptersByName 空名字列表应该返回空结果', () async {
      final matches = await extractionService.searchChaptersByName(
        novelUrl: testNovelUrl,
        names: [],
      );

      expect(matches, isEmpty);
    });

    test('searchChaptersByName 未找到匹配应该返回空列表', () async {
      final matches = await extractionService.searchChaptersByName(
        novelUrl: testNovelUrl,
        names: ['不存在的角色'],
      );

      expect(matches, isEmpty);
    });
  });

  group('CharacterExtractionService - 上下文提取测试', () {
    late CharacterExtractionService extractionService;

    setUp(() {
      extractionService = CharacterExtractionService();
    });

    test('extractContextAroundMatches 整章模式应该返回完整内容', () {
      const content = '这是一个完整的章节内容，包含角色的对话和行动。';
      final contexts = extractionService.extractContextAroundMatches(
        content: content,
        matchPositions: [10, 20],
        contextLength: 100,
        useFullChapter: true,
      );

      expect(contexts.length, 1);
      expect(contexts[0], content);
    });

    test('extractContextAroundMatches 上下文模式应该提取正确范围', () {
      const content = '0123456789张三这是一段测试内容结束';
      final contexts = extractionService.extractContextAroundMatches(
        content: content,
        matchPositions: [10], // '张'的位置
        contextLength: 10,
        useFullChapter: false,
      );

      expect(contexts.length, 1);
      // 前后各5个字符
      expect(contexts[0], contains('张三'));
    });

    test('extractContextAroundMatches 边界情况处理', () {
      const content = '张三在开头';
      final contexts = extractionService.extractContextAroundMatches(
        content: content,
        matchPositions: [0], // 开头位置
        contextLength: 10,
        useFullChapter: false,
      );

      expect(contexts.length, 1);
      // 应该正确处理开头边界
      expect(contexts[0].length, lessThanOrEqualTo(10));
    });

    test('extractContextAroundMatches 多个匹配位置应该返回多个片段', () {
      const content = '张三在这里，李四也在那里，张三又出现了';
      final contexts = extractionService.extractContextAroundMatches(
        content: content,
        matchPositions: [0, 7, 20], // 三个匹配位置
        contextLength: 6,
        useFullChapter: false,
      );

      expect(contexts.length, 3);
    });
  });

  group('CharacterExtractionService - 合并去重测试', () {
    late CharacterExtractionService extractionService;

    setUp(() {
      extractionService = CharacterExtractionService();
    });

    test('mergeAndDeduplicateContexts 空列表应该返回空字符串', () {
      final merged = extractionService.mergeAndDeduplicateContexts([]);

      expect(merged, isEmpty);
    });

    test('mergeAndDeduplicateContexts 单个片段应该直接返回', () {
      final contexts = ['这是唯一的片段'];
      final merged = extractionService.mergeAndDeduplicateContexts(contexts);

      expect(merged, '这是唯一的片段');
    });

    test('mergeAndDeduplicateContexts 不重叠片段应该用分隔符连接', () {
      final contexts = ['第一个片段\n第二个片段', '第三个片段\n第四个片段', '第五个片段'];
      final merged = extractionService.mergeAndDeduplicateContexts(contexts);

      expect(merged, contains('第一个片段'));
      expect(merged, contains('第二个片段'));
      expect(merged, contains('第三个片段'));
      expect(merged, contains('第四个片段'));
      expect(merged, contains('第五个片段'));

      // 验证所有段落都被保留（无字数限制）
      final paragraphs = merged.split('\n').where((p) => p.isNotEmpty).toList();
      expect(paragraphs.length, 5);
    });

    test('mergeAndDeduplicateContexts 重叠片段应该去重', () {
      final contexts = [
        '第一段内容。\n第二段内容。\n第三段内容。',
        '第二段内容。\n第三段内容。\n第四段内容。',
      ];
      final merged = extractionService.mergeAndDeduplicateContexts(
        contexts,
      );

      // 第二段和第三段重复，应该被去重
      final paragraphs = merged.split('\n').where((p) => p.isNotEmpty).toList();
      expect(paragraphs.length, 4); // 第一段、第二段、第三段、第四段

      // 验证去重后长度小于原始长度之和
      expect(merged.length, lessThan(contexts[0].length + contexts[1].length));
    });
  });

  group('CharacterExtractionService - 长度估算测试', () {
    late CharacterExtractionService extractionService;

    setUp(() {
      extractionService = CharacterExtractionService();
    });

    test('estimateContentLength 整章模式应该返回实际长度', () {
      final chapter = MockData.createTestChapter(
        content: '这是一段100个字符的测试内容用于验证长度计算是否正确，这是一段100个字符的测试内容用于验证长度计算是否正确。',
      );

      final matches = [
        ChapterMatch(
          chapter: chapter,
          matchCount: 2,
          matchPositions: [0, 50],
        ),
      ];

      final estimated = extractionService.estimateContentLength(
        chapterMatches: matches,
        contextLength: 500,
        useFullChapter: true,
      );

      expect(estimated, chapter.content!.length);
    });

    test('estimateContentLength 上下文模式应该计算匹配次数乘以长度', () {
      final chapter = MockData.createTestChapter(
        content: '短内容',
      );

      final matches = [
        ChapterMatch(
          chapter: chapter,
          matchCount: 5,
          matchPositions: [0, 1, 2, 3, 4],
        ),
      ];

      final estimated = extractionService.estimateContentLength(
        chapterMatches: matches,
        contextLength: 200,
        useFullChapter: false,
      );

      expect(estimated, 5 * 200); // 1000
    });

    test('estimateContentLength 多章节应该累加', () {
      final chapters = [
        MockData.createTestChapter(
          url: 'url1',
          content: 'A' * 1000,
        ),
        MockData.createTestChapter(
          url: 'url2',
          content: 'B' * 2000,
        ),
      ];

      final matches = [
        ChapterMatch(
          chapter: chapters[0],
          matchCount: 1,
          matchPositions: [0],
        ),
        ChapterMatch(
          chapter: chapters[1],
          matchCount: 2,
          matchPositions: [0, 1000],
        ),
      ];

      final estimated = extractionService.estimateContentLength(
        chapterMatches: matches,
        contextLength: 300,
        useFullChapter: true,
      );

      expect(estimated, 1000 + 2000); // 3000
    });

    test('estimateContentLength 空内容应该返回0', () {
      final chapter = Chapter(
        title: '空章节',
        url: 'test',
        content: null,
        isCached: true,
      );

      final matches = [
        ChapterMatch(
          chapter: chapter,
          matchCount: 1,
          matchPositions: [0],
        ),
      ];

      final estimated = extractionService.estimateContentLength(
        chapterMatches: matches,
        contextLength: 500,
        useFullChapter: true,
      );

      expect(estimated, 0);
    });
  });
}
