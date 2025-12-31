import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/controllers/chapter_list/chapter_reorder_controller.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/chapter.dart';
import '../../test_helpers/mock_data.dart';

@GenerateMocks([DatabaseService])
import 'chapter_reorder_controller_test.mocks.dart';

/// ChapterReorderController 单元测试
void main() {
  group('ChapterReorderController', () {
    late ChapterReorderController controller;
    late MockDatabaseService mockDb;

    setUp(() {
      mockDb = MockDatabaseService();
      controller = ChapterReorderController(
        databaseService: mockDb,
      );
    });

    test('onReorder should move chapter forward', () {
      final chapters = MockData.createTestChapterList(count: 5);

      final result = controller.onReorder(
        oldIndex: 0,
        newIndex: 3,
        chapters: chapters,
      );

      // 当从0移到3时，实际是移到索引2（因为oldIndex < newIndex）
      expect(result[0].title, '第2章 测试章节'); // 原索引1的章节现在在索引0
      expect(result[1].title, '第3章 测试章节'); // 原索引2的章节现在在索引1
      expect(result[2].title, '第1章 测试章节'); // 原索引0的章节移到索引2
      expect(result[3].title, '第4章 测试章节'); // 原索引3的章节现在在索引3
      expect(result[4].title, '第5章 测试章节'); // 原索引4的章节现在在索引4
    });

    test('onReorder should move chapter backward', () {
      final chapters = MockData.createTestChapterList(count: 5);

      final result = controller.onReorder(
        oldIndex: 4,
        newIndex: 1,
        chapters: chapters,
      );

      expect(result[1].title, '第5章 测试章节'); // 原索引4的章节移到索引1
    });

    test('onReorder should handle adjacent indices', () {
      final chapters = MockData.createTestChapterList(count: 3);

      final result = controller.onReorder(
        oldIndex: 1,
        newIndex: 0,
        chapters: chapters,
      );

      expect(result[0].title, '第2章 测试章节');
      expect(result[1].title, '第1章 测试章节');
    });

    test('saveReorderedChapters should call database', () async {
      final chapters = MockData.createTestChapterList(count: 3);
      when(mockDb.updateChaptersOrder('novel-url', chapters)).thenAnswer((_) async {});

      await controller.saveReorderedChapters(
        novelUrl: 'novel-url',
        chapters: chapters,
      );

      verify(mockDb.updateChaptersOrder('novel-url', chapters)).called(1);
    });

    test('saveReorderedChapters should handle errors', () async {
      final chapters = MockData.createTestChapterList(count: 3);
      when(mockDb.updateChaptersOrder('novel-url', chapters)).thenThrow(Exception('DB error'));

      expect(
        () => controller.saveReorderedChapters(
          novelUrl: 'novel-url',
          chapters: chapters,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
