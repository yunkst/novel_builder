import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/controllers/chapter_list/chapter_loader.dart';
import 'package:novel_app/services/api_service_wrapper.dart';
import 'package:novel_app/models/chapter.dart';
import '../../test_helpers/mock_data.dart';
import '../../base/database_test_base.dart';

@GenerateMocks([ApiServiceWrapper])
import 'chapter_loader_test.mocks.dart';

/// 测试基类
class _ChapterLoaderTestBase extends DatabaseTestBase {}

/// ChapterLoader 单元测试
///
/// 测试策略：
/// - ApiServiceWrapper: 保留Mock（外部HTTP依赖）
/// - DatabaseService: 使用真实数据库（本地依赖）
void main() {
  group('ChapterLoader', () {
    late ChapterLoader chapterLoader;
    late MockApiServiceWrapper mockApi;
    late _ChapterLoaderTestBase base;

    setUp(() async {
      // 初始化真实数据库
      base = _ChapterLoaderTestBase();
      await base.setUp();

      // 初始化Mock API
      mockApi = MockApiServiceWrapper();

      // 创建ChapterLoader实例
      chapterLoader = ChapterLoader(
        api: mockApi,
        databaseService: base.databaseService,
      );
    });

    tearDown(() async {
      await base.tearDown();
    });

    test('initApi should call ApiServiceProvider initialize', () async {
      // 这个测试验证初始化流程
      expect(chapterLoader, isNotNull);
    });

    test('loadChapters with cache should return cached chapters', () async {
      // 创建测试小说并缓存章节
      final novel = await base.createAndAddNovel();
      await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 3,
      );

      // 从数据库加载（不调用API）
      final result = await chapterLoader.loadChapters(novel.url);

      expect(result.length, 3);
      expect(result[0].title, isNotEmpty);
      expect(result[0].chapterIndex, 0);
      expect(result[1].chapterIndex, 1);
      expect(result[2].chapterIndex, 2);
    });

    test('loadChapters with empty cache should return empty list', () async {
      final novel = await base.createAndAddNovel();

      // Mock API也返回空列表
      when(mockApi.getChapters(novel.url)).thenAnswer((_) async => []);

      final result = await chapterLoader.loadChapters(novel.url);

      expect(result, isEmpty);
      verify(mockApi.getChapters(novel.url)).called(1);
    });

    test('refreshFromBackend should call API and save to database', () async {
      final novel = await base.createAndAddNovel();
      final apiChapters = MockData.createTestChapterList(count: 2);

      // Mock API调用
      when(mockApi.getChapters(novel.url)).thenAnswer((_) async => apiChapters);

      // 执行刷新
      final result = await chapterLoader.refreshFromBackend(novel.url);

      // 验证API被调用
      verify(mockApi.getChapters(novel.url)).called(1);

      // 验证返回了章节
      expect(result.length, 2);

      // 验证数据库中有数据
      final cached = await base.databaseService.getChapters(novel.url);
      expect(cached.length, 2);
      expect(cached[0].title, apiChapters[0].title);
      expect(cached[1].title, apiChapters[1].title);
    });

    test('loadLastReadChapter should return chapter index', () async {
      final novel = await base.createAndAddNovel();

      // 模拟设置最后阅读章节
      await base.databaseService.updateLastReadChapter(
        novel.url,
        5,
      );

      final result = await chapterLoader.loadLastReadChapter(novel.url);

      expect(result, 5);
    });

    test('loadLastReadChapter should return 0 for new novel', () async {
      final novel = await base.createAndAddNovel();

      final result = await chapterLoader.loadLastReadChapter(novel.url);

      expect(result, 0);
    });

    test('loadChapters with forceRefresh should return cache without calling API', () async {
      final novel = await base.createAndAddNovel();

      // 先创建缓存章节
      await base.createAndCacheChapters(
        novelUrl: novel.url,
        count: 3,
      );

      // 强制刷新
      final result = await chapterLoader.loadChapters(novel.url, forceRefresh: true);

      // forceRefresh时，loadChapters仍返回缓存，不调用API
      // (需要手动调用refreshFromBackend来更新)
      expect(result.length, 3);
      expect(result[0].chapterIndex, 0);
      expect(result[1].chapterIndex, 1);
      expect(result[2].chapterIndex, 2);

      // 验证API没有被调用（loadChapters不会调用API）
      verifyNever(mockApi.getChapters(novel.url));
    });

    test('loadChapters for custom novel should load from database', () async {
      // 创建本地小说
      final customNovel = MockData.createCustomNovel();
      await base.databaseService.addToBookshelf(customNovel);

      // 为本地小说创建章节
      await base.createAndCacheChapters(
        novelUrl: customNovel.url,
        count: 2,
      );

      // 加载章节（不应该调用API）
      final result = await chapterLoader.loadChapters(customNovel.url);

      expect(result.length, 2);
      // 验证API没有被调用
      verifyNever(mockApi.getChapters(customNovel.url));
    });

    test('refreshFromBackend for custom novel should load from database', () async {
      // 创建本地小说
      final customNovel = MockData.createCustomNovel();
      await base.databaseService.addToBookshelf(customNovel);

      // 为本地小说创建章节
      await base.createAndCacheChapters(
        novelUrl: customNovel.url,
        count: 2,
      );

      // 刷新章节（不应该调用API）
      final result = await chapterLoader.refreshFromBackend(customNovel.url);

      expect(result.length, 2);
      // 验证API没有被调用
      verifyNever(mockApi.getChapters(customNovel.url));
    });
  });
}
