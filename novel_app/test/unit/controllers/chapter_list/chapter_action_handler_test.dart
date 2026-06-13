/// ChapterActionHandler 章节操作处理器单元测试
///
/// 使用 mockito Mock IChapterRepository，
/// 验证章节操作的业务逻辑（插入/删除/缓存检查）。
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/controllers/chapter_list/chapter_action_handler_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/controllers/chapter_list/chapter_action_handler.dart';
import 'package:novel_app/core/interfaces/repositories/i_chapter_repository.dart';

// 生成 MockIChapterRepository
@GenerateMocks([IChapterRepository])
import 'chapter_action_handler_test.mocks.dart';

void main() {
  late ChapterActionHandler handler;
  late MockIChapterRepository mockRepo;

  setUp(() {
    mockRepo = MockIChapterRepository();
    handler = ChapterActionHandler(chapterRepository: mockRepo);
  });

  group('ChapterActionHandler', () {
    group('insertChapter', () {
      test('应调用 repository.createCustomChapter', () async {
        when(mockRepo.createCustomChapter(
          'novel_url',
          '新章节',
          '章节内容',
          5,
        )).thenAnswer((_) async => 1);

        await handler.insertChapter(
          novelUrl: 'novel_url',
          title: '新章节',
          content: '章节内容',
          insertIndex: 5,
        );

        verify(mockRepo.createCustomChapter(
          'novel_url',
          '新章节',
          '章节内容',
          5,
        )).called(1);
      });

      test('repository 抛出异常时应 rethrow', () async {
        when(mockRepo.createCustomChapter(any, any, any, any))
            .thenThrow(Exception('数据库错误'));

        expect(
          () => handler.insertChapter(
            novelUrl: 'novel_url',
            title: '新章节',
            content: '内容',
            insertIndex: 0,
          ),
          throwsException,
        );
      });
    });

    group('deleteChapter', () {
      test('应调用 repository.deleteCustomChapter', () async {
        when(mockRepo.deleteCustomChapter('custom://chapter_1'))
            .thenAnswer((_) async {});

        await handler.deleteChapter('custom://chapter_1');

        verify(mockRepo.deleteCustomChapter('custom://chapter_1')).called(1);
      });

      test('repository 抛出异常时应 rethrow', () async {
        when(mockRepo.deleteCustomChapter(any))
            .thenThrow(Exception('删除失败'));

        expect(
          () => handler.deleteChapter('custom://chapter_1'),
          throwsException,
        );
      });
    });

    group('isChapterCached', () {
      test('应委托给 repository.isChapterCached', () async {
        when(mockRepo.isChapterCached('chapter_url'))
            .thenAnswer((_) async => true);

        final result = await handler.isChapterCached('chapter_url');

        expect(result, isTrue);
        verify(mockRepo.isChapterCached('chapter_url')).called(1);
      });

      test('应正确返回 false（未缓存）', () async {
        when(mockRepo.isChapterCached('chapter_url'))
            .thenAnswer((_) async => false);

        final result = await handler.isChapterCached('chapter_url');

        expect(result, isFalse);
      });

      test('repository 异常时应 rethrow', () async {
        when(mockRepo.isChapterCached(any)).thenThrow(Exception('查询失败'));

        expect(
          () => handler.isChapterCached('chapter_url'),
          throwsException,
        );
      });
    });

    group('areChaptersCached', () {
      test('应委托给 repository.getChaptersCacheStatus', () async {
        final mockResult = {
          'ch1': true,
          'ch2': false,
          'ch3': true,
        };
        when(mockRepo.getChaptersCacheStatus(['ch1', 'ch2', 'ch3']))
            .thenAnswer((_) async => mockResult);

        final result =
            await handler.areChaptersCached(['ch1', 'ch2', 'ch3']);

        expect(result, mockResult);
        verify(mockRepo.getChaptersCacheStatus(['ch1', 'ch2', 'ch3'])).called(1);
      });

      test('空 URL 列表应正常返回', () async {
        when(mockRepo.getChaptersCacheStatus([]))
            .thenAnswer((_) async => {});

        final result = await handler.areChaptersCached([]);

        expect(result, isEmpty);
      });

      test('repository 异常时应 rethrow', () async {
        when(mockRepo.getChaptersCacheStatus(any))
            .thenThrow(Exception('查询失败'));

        expect(
          () => handler.areChaptersCached(['ch1']),
          throwsException,
        );
      });
    });
  });
}
