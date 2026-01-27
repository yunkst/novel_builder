import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/controllers/chapter_list/chapter_action_handler.dart';
import 'package:novel_app/services/database_service.dart';
import '../../test_bootstrap.dart';
import '../../test_helpers/mock_data.dart';

@GenerateMocks([DatabaseService])
import 'chapter_action_handler_test.mocks.dart';

/// ChapterActionHandler 单元测试
void main() {
  // 初始化测试环境
  initDatabaseTests();

  group('ChapterActionHandler', () {
    late ChapterActionHandler handler;
    late MockDatabaseService mockDb;

    setUp(() {
      mockDb = MockDatabaseService();
      handler = ChapterActionHandler(
        databaseService: mockDb,
      );
    });

    test('insertChapter should call database', () async {
      when(mockDb.insertUserChapter(
        'novel-url', 'title', 'content', 0,
      )).thenAnswer((_) async {});

      await handler.insertChapter(
        novelUrl: 'novel-url',
        title: 'title',
        content: 'content',
        insertIndex: 0,
      );

      verify(mockDb.insertUserChapter(
        'novel-url', 'title', 'content', 0,
      )).called(1);
    });

    test('deleteChapter should call database', () async {
      when(mockDb.deleteUserChapter('chapter-url')).thenAnswer((_) async {});

      await handler.deleteChapter('chapter-url');

      verify(mockDb.deleteUserChapter('chapter-url')).called(1);
    });

    test('isChapterCached should call database', () async {
      when(mockDb.isChapterCached('chapter-url')).thenAnswer((_) async => true);

      final result = await handler.isChapterCached('chapter-url');

      expect(result, isTrue);
      verify(mockDb.isChapterCached('chapter-url')).called(1);
    });

    test('getPreviousChaptersContent should return chapters', () async {
      final chapters = MockData.createTestChapterList(count: 3);
      when(mockDb.getCachedChapter(any)).thenAnswer((_) async => 'content');

      final result = await handler.getPreviousChaptersContent(
        chapters: chapters,
        afterIndex: 2,
      );

      expect(result.length, 3);
    });
  });
}
