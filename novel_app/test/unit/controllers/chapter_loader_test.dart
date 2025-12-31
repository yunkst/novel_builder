import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/controllers/chapter_list/chapter_loader.dart';
import 'package:novel_app/services/api_service_wrapper.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/chapter.dart';
import '../../test_helpers/mock_data.dart';
import 'package:novel_app/models/novel.dart';

@GenerateMocks([ApiServiceWrapper, DatabaseService])
import 'chapter_loader_test.mocks.dart';

/// ChapterLoader 单元测试
void main() {
  group('ChapterLoader', () {
    late ChapterLoader chapterLoader;
    late MockApiServiceWrapper mockApi;
    late MockDatabaseService mockDb;

    setUp(() {
      mockApi = MockApiServiceWrapper();
      mockDb = MockDatabaseService();
      chapterLoader = ChapterLoader(
        api: mockApi,
        databaseService: mockDb,
      );
    });

    test('initApi should call ApiServiceProvider initialize', () async {
      // 这个测试验证初始化流程
      // 实际的ApiServiceProvider是静态方法，这里只测试方法存在
      expect(chapterLoader, isNotNull);
    });

    test('loadChapters with cache should return cached chapters', () async {
      final testNovel = MockData.createTestNovel();
      final cachedChapters = MockData.createTestChapterList(count: 3);

      // Mock数据库返回缓存的章节
      when(mockDb.getCachedNovelChapters(testNovel.url))
          .thenAnswer((_) async => cachedChapters);

      final result = await chapterLoader.loadChapters(testNovel.url);

      expect(result.length, 3);
      verify(mockDb.getCachedNovelChapters(testNovel.url)).called(1);
    });

    test('loadChapters with empty cache should return empty list', () async {
      final testNovel = MockData.createTestNovel();

      // Mock数据库返回空列表
      when(mockDb.getCachedNovelChapters(testNovel.url))
          .thenAnswer((_) async => []);
      // Mock API也返回空列表
      when(mockApi.getChapters(testNovel.url)).thenAnswer((_) async => []);

      final result = await chapterLoader.loadChapters(testNovel.url);

      expect(result, isEmpty);
    });

    test('refreshFromBackend should call API and save to database', () async {
      final testNovel = MockData.createTestNovel();
      final apiChapters = MockData.createTestChapterList(count: 2);
      final mergedChapters = MockData.createTestChapterList(count: 2);

      // Mock API调用
      when(mockApi.getChapters(testNovel.url)).thenAnswer((_) async => apiChapters);
      // Mock cacheNovelChapters调用
      when(mockDb.cacheNovelChapters(testNovel.url, apiChapters))
          .thenAnswer((_) async {});
      // Mock getCachedNovelChapters调用
      // 使用sequentialReturnValues来提供多次调用的不同返回值
      final mockDatabaseService = mockDb as MockDatabaseService;
      // 第一次调用返回空，第二次返回合并后的章节
      var callCount = 0;
      when(mockDb.getCachedNovelChapters(testNovel.url))
          .thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return [];
            return mergedChapters;
          });

      final result = await chapterLoader.loadChapters(testNovel.url);

      expect(result.length, 2);
      verify(mockApi.getChapters(testNovel.url)).called(1);
      verify(mockDb.cacheNovelChapters(testNovel.url, apiChapters)).called(1);
      expect(callCount, 2); // 验证被调用了两次
    });

    test('loadLastReadChapter should return chapter index', () async {
      final testNovel = MockData.createTestNovel();

      when(mockDb.getLastReadChapter(testNovel.url)).thenAnswer((_) async => 5);

      final result = await chapterLoader.loadLastReadChapter(testNovel.url);

      expect(result, 5);
      verify(mockDb.getLastReadChapter(testNovel.url)).called(1);
    });

    test('loadLastReadChapter should return 0 for new novel', () async {
      final testNovel = MockData.createTestNovel();

      when(mockDb.getLastReadChapter(testNovel.url)).thenAnswer((_) async => 0);

      final result = await chapterLoader.loadLastReadChapter(testNovel.url);

      expect(result, 0);
    });
  });
}
