import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:novel_app/services/api_service_wrapper.dart';
import 'package:novel_app/core/interfaces/repositories/i_chapter_repository.dart';
import 'package:novel_app/core/interfaces/repositories/i_novel_repository.dart';
import 'package:novel_app/controllers/chapter_list/chapter_loader.dart';

// 生成Mock类
@GenerateMocks([
  ApiServiceWrapper,
  IChapterRepository,
  INovelRepository,
])
import 'custom_novel_fix_verification_test.mocks.dart';

void main() {
  group('自定义小说修复验证测试', () {
    late MockApiServiceWrapper mockApi;
    late MockIChapterRepository mockChapterRepo;
    late MockINovelRepository mockNovelRepo;
    late ChapterLoader chapterLoader;

    setUp(() {
      mockApi = MockApiServiceWrapper();
      mockChapterRepo = MockIChapterRepository();
      mockNovelRepo = MockINovelRepository();
      chapterLoader = ChapterLoader(
        api: mockApi,
        chapterRepository: mockChapterRepo,
        novelRepository: mockNovelRepo,
      );
    });

    group('场景1: 正常加载自定义小说', () {
      test('应该从数据库加载用户创建的章节', () async {
        // Arrange
        final customNovelUrl = 'custom://novel/123';
        final userChapters = [
          Chapter(
            title: '第一章',
            url: 'custom://chapter/1',
            content: '用户创建的内容',
            isCached: true,
            chapterIndex: 0,
            isUserInserted: true,
          ),
        ];

        when(mockChapterRepo.getCachedNovelChapters(customNovelUrl))
            .thenAnswer((_) async => userChapters);

        // Act
        final result = await chapterLoader.loadChapters(customNovelUrl);

        // Assert
        expect(result, isNotEmpty);
        expect(result.first.isUserInserted, isTrue);
        verifyNever(mockApi.init());
      });
    });

    group('场景2: 刷新自定义小说章节', () {
      test('refreshFromBackend应该返回数据库中的章节', () async {
        // Arrange
        final customNovelUrl = 'custom://novel/123';
        final userChapters = [
          Chapter(
            title: '第一章',
            url: 'custom://chapter/1',
            content: '用户创建的内容',
            isCached: true,
            chapterIndex: 0,
            isUserInserted: true,
          ),
          Chapter(
            title: '第二章',
            url: 'custom://chapter/2',
            content: '用户创建的内容2',
            isCached: true,
            chapterIndex: 1,
            isUserInserted: true,
          ),
        ];

        when(mockChapterRepo.getCachedNovelChapters(customNovelUrl))
            .thenAnswer((_) async => userChapters);

        // Act - 模拟用户点击"重试"
        final result = await chapterLoader.refreshFromBackend(
          customNovelUrl,
          forceRefresh: true,
        );

        // Assert - 关键验证：章节不应该丢失
        expect(result, isNotEmpty, reason: '刷新后章节不应该为空');
        expect(result.length, equals(2), reason: '所有用户章节应该保留');
        expect(result.every((c) => c.isUserInserted), isTrue,
            reason: '用户章节标记应该保留');
      });
    });

    group('场景3: 空章节的自定义小说', () {
      test('应该正确处理空章节列表', () async {
        // Arrange
        final customNovelUrl = 'custom://novel/empty';
        when(mockChapterRepo.getCachedNovelChapters(customNovelUrl))
            .thenAnswer((_) async => []);

        // Act
        final result = await chapterLoader.loadChapters(customNovelUrl);

        // Assert
        expect(result, isEmpty);
        verifyNever(mockApi.init());
      });

      test('刷新空章节的自定义小说应该返回空列表', () async {
        // Arrange
        final customNovelUrl = 'custom://novel/empty';
        when(mockChapterRepo.getCachedNovelChapters(customNovelUrl))
            .thenAnswer((_) async => []);

        // Act
        final result = await chapterLoader.refreshFromBackend(
          customNovelUrl,
          forceRefresh: true,
        );

        // Assert
        expect(result, isEmpty);
      });
    });

    group('场景4: 普通小说不受影响', () {
      test('普通小说应该走正常的API流程', () async {
        // Arrange
        final normalNovelUrl = 'https://example.com/novel/123';
        final normalChapters = [
          Chapter(
            title: '第一章',
            url: 'https://example.com/chapter/1',
            isCached: false,
            chapterIndex: 0,
          ),
        ];

        when(mockApi.init()).thenAnswer((_) async {});
        when(mockApi.getChapters(normalNovelUrl, forceRefresh: false))
            .thenAnswer((_) async => normalChapters);
        when(mockChapterRepo.cacheNovelChapters(normalNovelUrl, normalChapters))
            .thenAnswer((_) async {});
        when(mockChapterRepo.getCachedNovelChapters(normalNovelUrl))
            .thenAnswer((_) async => []);

        // Act
        await chapterLoader.initApi();
        final result = await chapterLoader.loadChapters(normalNovelUrl);

        // Assert
        expect(result, isNotEmpty);
        verify(mockApi.init()).called(1);
      });
    });
  });
}