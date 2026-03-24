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
import 'custom_novel_init_failure_test.mocks.dart';

void main() {
  group('自定义小说初始化失败Bug测试', () {
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

    test('场景1: 自定义小说应该从数据库加载章节，不需要API初始化', () async {
      // Arrange
      final customNovelUrl = 'custom://novel/123';

      final userChapters = [
        Chapter(
          title: '第一章',
          url: 'custom://chapter/1',
          content: '这是用户创建的章节内容',
          isCached: true,
          chapterIndex: 0,
          isUserInserted: true,
        ),
      ];

      // Mock: 返回用户创建的章节
      when(mockChapterRepo.getCachedNovelChapters(customNovelUrl))
          .thenAnswer((_) async => userChapters);

      // Act
      final result = await chapterLoader.loadChapters(customNovelUrl);

      // Assert
      expect(result, isNotEmpty);
      expect(result.length, equals(1));
      expect(result.first.title, equals('第一章'));
      expect(result.first.isUserInserted, isTrue);

      // Verify: 对于自定义小说，不应该调用API
      verifyNever(mockApi.init());
      verify(mockChapterRepo.getCachedNovelChapters(customNovelUrl)).called(1);
    });

    test('场景2: refreshFromBackend 对于自定义小说应该返回已缓存的章节', () async {
      // Arrange
      final customNovelUrl = 'custom://novel/123';

      final userChapters = [
        Chapter(
          title: '第一章',
          url: 'custom://chapter/1',
          content: '这是用户创建的章节内容',
          isCached: true,
          chapterIndex: 0,
          isUserInserted: true,
        ),
      ];

      // Mock: 返回用户创建的章节
      when(mockChapterRepo.getCachedNovelChapters(customNovelUrl))
          .thenAnswer((_) async => userChapters);

      // Act
      final result = await chapterLoader.refreshFromBackend(
        customNovelUrl,
        forceRefresh: true,
      );

      // Assert - 这是关键测试！
      // 对于自定义小说，refreshFromBackend 应该返回用户创建的章节
      // 而不是空列表
      expect(result, isNotEmpty, reason: '自定义小说刷新后章节不应该为空');
      expect(result.length, equals(1));
      expect(result.first.title, equals('第一章'));
      expect(result.first.isUserInserted, isTrue);
    });

    test('场景3: 多个章节的自定义小说刷新后应保留所有章节', () async {
      // Arrange
      final customNovelUrl = 'custom://novel/456';

      final userChapters = [
        Chapter(
          title: '第一章',
          url: 'custom://chapter/1',
          content: '第一章内容',
          isCached: true,
          chapterIndex: 0,
          isUserInserted: true,
        ),
        Chapter(
          title: '第二章',
          url: 'custom://chapter/2',
          content: '第二章内容',
          isCached: true,
          chapterIndex: 1,
          isUserInserted: true,
        ),
        Chapter(
          title: '第三章',
          url: 'custom://chapter/3',
          content: '第三章内容',
          isCached: true,
          chapterIndex: 2,
          isUserInserted: true,
        ),
      ];

      // Mock
      when(mockChapterRepo.getCachedNovelChapters(customNovelUrl))
          .thenAnswer((_) async => userChapters);

      // Act
      final result = await chapterLoader.refreshFromBackend(
        customNovelUrl,
        forceRefresh: true,
      );

      // Assert
      expect(result.length, equals(3), reason: '所有用户创建的章节应该被保留');
      expect(result[0].title, equals('第一章'));
      expect(result[1].title, equals('第二章'));
      expect(result[2].title, equals('第三章'));
    });
  });
}