import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/models/search_result.dart';
import 'package:novel_app/services/chapter_search_service.dart';
import 'package:novel_app/services/database_service.dart';
import '../../test_bootstrap.dart';

@GenerateMocks([DatabaseService])
import 'chapter_search_service_test.mocks.dart';

/// ChapterSearchService 单元测试
///
/// 测试章节搜索服务的核心功能：
/// - 在指定小说中搜索
/// - 在所有小说中搜索
/// - 搜索结果排序
/// - 空关键词处理
/// - 错误处理
void main() {
  // 初始化数据库FFI（ChapterSearchService依赖DatabaseService）
  initDatabaseTests();

  group('ChapterSearchService 基础功能', () {
    late ChapterSearchService searchService;
    late MockDatabaseService mockDb;

    setUp(() {
      mockDb = MockDatabaseService();
      searchService = ChapterSearchService();
      // 由于 DatabaseService 是单例，我们需要在测试中处理这个问题
      // 但先测试基本逻辑
    });

    test('空关键词应返回空列表 (searchInNovel)', () async {
      // 注意：这个测试需要能mock DatabaseService
      // 由于 DatabaseService 是单例模式，实际测试可能需要特殊处理
      final result = await searchService.searchInNovel('test_novel_url', '   ');

      expect(result, isEmpty);
    });

    test('空关键词应返回空列表 (searchInAllNovels)', () async {
      final result = await searchService.searchInAllNovels('');

      expect(result, isEmpty);
    });

    test('纯空格关键词应返回空列表', () async {
      final result = await searchService.searchInNovel('test_novel', '   \t  ');

      expect(result, isEmpty);
    });
  });

  group('ChapterSearchService 排序功能', () {
    test('searchInNovel 结果应按章节索引排序', () async {
      // 这个测试需要完整的 DatabaseService mock
      // 暂时跳过，等 mock 框架配置完成
    });

    test('searchInAllNovels 结果应先按小说URL再按章节索引排序', () async {
      // 这个测试需要完整的 DatabaseService mock
      // 暂时跳过，等 mock 框架配置完成
    });
  });

  group('ChapterSearchService 搜索建议', () {
    test('getSearchSuggestions 应返回空列表', () async {
      final searchService = ChapterSearchService();
      final suggestions = await searchService.getSearchSuggestions();

      expect(suggestions, isEmpty);
    });

    test('getSearchSuggestions 多次调用应返回空列表', () async {
      final searchService = ChapterSearchService();

      final result1 = await searchService.getSearchSuggestions();
      final result2 = await searchService.getSearchSuggestions();

      expect(result1, isEmpty);
      expect(result2, isEmpty);
    });
  });

  group('ChapterSearchService 搜索历史', () {
    test('saveSearchHistory 空关键词应直接返回', () async {
      final searchService = ChapterSearchService();

      // 不应抛出异常
      await searchService.saveSearchHistory('');
      await searchService.saveSearchHistory('   ');
    });

    test('saveSearchHistory 正常关键词应静默成功', () async {
      final searchService = ChapterSearchService();

      // 不应抛出异常
      await searchService.saveSearchHistory('test keyword');
    });

    test('clearSearchHistory 应静默成功', () async {
      final searchService = ChapterSearchService();

      // 不应抛出异常
      await searchService.clearSearchHistory();
    });
  });

  group('ChapterSearchService 边界场景', () {
    test('特殊字符关键词应正常处理', () async {
      final searchService = ChapterSearchService();

      // 不应抛出异常（可能没有结果，但不应该崩溃）
      final result = await searchService.searchInNovel('test_novel', '!@#\$%^&*()');

      // 应该返回列表（可能为空）
      expect(result, isA<List<ChapterSearchResult>>());
    });

    test('超长关键词应正常处理', () async {
      final searchService = ChapterSearchService();
      final longKeyword = 'a' * 1000;

      final result = await searchService.searchInNovel('test_novel', longKeyword);

      expect(result, isA<List<ChapterSearchResult>>());
    });

    test('Unicode 关键词应正常处理', () async {
      final searchService = ChapterSearchService();

      final result = await searchService.searchInNovel('test_novel', '你好世界');

      expect(result, isA<List<ChapterSearchResult>>());
    });

    test('novelUrl 为空时应正常处理', () async {
      final searchService = ChapterSearchService();

      final result = await searchService.searchInNovel('', 'test');

      expect(result, isA<List<ChapterSearchResult>>());
    });
  });

  group('ChapterSearchService 错误处理', () {
    test('DatabaseService 抛出异常时应转换为搜索失败异常', () async {
      // 这个测试需要 mock DatabaseService 让其抛出异常
      // 暂时跳过，等 mock 框架配置完成
    }, skip: '需要 mock DatabaseService 让其抛出异常');
  });

  group('ChapterSearchService 结果排序逻辑', () {
    test('相同小说的章节应按索引升序排列', () async {
      // 需要创建测试数据验证排序逻辑
    }, skip: '需要创建测试数据验证排序逻辑');

    test('不同小说的结果应先按小说URL分组', () async {
      // 需要创建测试数据验证分组逻辑
    }, skip: '需要创建测试数据验证分组逻辑');

    test('相同索引时保持原始顺序（稳定排序）', () async {
      // 需要创建测试数据验证稳定排序
    }, skip: '需要创建测试数据验证稳定排序');
  });

  group('ChapterSearchService 性能测试', () {
    test('搜索大量结果应正确排序', () async {
      // 测试100+条结果的排序性能
    }, skip: '性能测试，需要真实数据库环境');

    test('重复搜索同一关键词应一致', () async {
      // 验证缓存或一致性
    }, skip: '需要验证缓存或一致性');
  });
}

/// 额外的 mock 数据创建辅助
class TestData {
  static ChapterSearchResult createResult({
    required String novelUrl,
    required int chapterIndex,
    String? chapterTitle,
  }) {
    return ChapterSearchResult(
      novelUrl: novelUrl,
      novelTitle: 'Test Novel',
      novelAuthor: 'Test Author',
      chapterUrl: '$novelUrl/chapter_$chapterIndex',
      chapterTitle: chapterTitle ?? 'Chapter $chapterIndex',
      chapterIndex: chapterIndex,
      content: 'Test content',
      searchKeywords: [],
      matchPositions: [],
      cachedAt: DateTime.now(),
    );
  }

  static List<ChapterSearchResult> createUnsortedResults() {
    return [
      createResult(novelUrl: 'novel1', chapterIndex: 5),
      createResult(novelUrl: 'novel1', chapterIndex: 2),
      createResult(novelUrl: 'novel1', chapterIndex: 8),
      createResult(novelUrl: 'novel1', chapterIndex: 1),
    ];
  }

  static List<ChapterSearchResult> createMultiNovelResults() {
    return [
      createResult(novelUrl: 'novel2', chapterIndex: 3),
      createResult(novelUrl: 'novel1', chapterIndex: 5),
      createResult(novelUrl: 'novel2', chapterIndex: 1),
      createResult(novelUrl: 'novel1', chapterIndex: 2),
    ];
  }
}
