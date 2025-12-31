import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/controllers/chapter_list/chapter_generator.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/services/dify_service.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import '../../test_helpers/mock_data.dart';

@GenerateMocks([DatabaseService, DifyService])
import 'chapter_generator_test.mocks.dart';

/// ChapterGenerator 单元测试
void main() {
  group('ChapterGenerator', () {
    late ChapterGenerator generator;
    late MockDatabaseService mockDb;
    late MockDifyService mockDify;

    setUp(() {
      mockDb = MockDatabaseService();
      mockDify = MockDifyService();
      generator = ChapterGenerator(
        databaseService: mockDb,
        difyService: mockDify,
      );
    });

    test('generateChapter should call DifyService', () async {
      final testNovel = MockData.createTestNovel();
      final chapters = MockData.createTestChapterList(count: 3);
      final responseData = '生成的章节内容';

      when(mockDb.getCachedChapter(any)).thenAnswer((_) async => '历史内容');
      when(mockDb.getCharactersByIds([])).thenAnswer((_) async => []);
      when(mockDify.runWorkflowStreaming(
        inputs: anyNamed('inputs'),
        onData: anyNamed('onData'),
        onError: anyNamed('onError'),
        onDone: anyNamed('onDone'),
      )).thenAnswer((_) async {
        final onData =  mockDify.runWorkflowStreaming as Map;
        // 模拟流式输出
        (onData['onData'] as Function)(responseData);
        (onData['onDone'] as Function)();
      });

      var receivedData = '';
      await generator.generateChapter(
        novel: testNovel,
        chapters: chapters,
        afterIndex: 2,
        userInput: '生成章节',
        characterIds: [],
        onData: (data) => receivedData = data,
        onError: (error) {},
        onDone: () {},
      );

      expect(receivedData, responseData);
    });

    test('generateChapter should include history context', () async {
      final testNovel = MockData.createTestNovel();
      final chapters = MockData.createTestChapterList(count: 5);

      when(mockDb.getCachedChapter(any)).thenAnswer((_) async => '章节内容');
      when(mockDb.getCharactersByIds([])).thenAnswer((_) async => []);
      when(mockDify.runWorkflowStreaming(
        inputs: anyNamed('inputs'),
        onData: anyNamed('onData'),
        onError: anyNamed('onError'),
        onDone: anyNamed('onDone'),
      )).thenAnswer((_) async {});

      await generator.generateChapter(
        novel: testNovel,
        chapters: chapters,
        afterIndex: 4,
        userInput: '生成章节',
        characterIds: [],
        onData: (data) {},
        onError: (error) {},
        onDone: () {},
      );

      // 验证传入了历史上下文
      final captured = verify(mockDify.runWorkflowStreaming(
        inputs: captureAnyNamed('inputs'),
        onData: anyNamed('onData'),
        onError: anyNamed('onError'),
        onDone: anyNamed('onDone'),
      )).captured;

      final inputs = captured.single['inputs'] as Map;
      expect(inputs['history_chapters_content'], isNotNull);
      expect(inputs['history_chapters_content'].toString().isNotEmpty, isTrue);
    });

    test('generateChapter should handle DifyService errors', () async {
      final testNovel = MockData.createTestNovel();
      final chapters = MockData.createTestChapterList(count: 2);
      var errorReceived = false;

      when(mockDb.getCachedChapter(any)).thenAnswer((_) async => '内容');
      when(mockDb.getCharactersByIds([])).thenAnswer((_) async => []);
      when(mockDify.runWorkflowStreaming(
        inputs: anyNamed('inputs'),
        onData: anyNamed('onData'),
        onError: anyNamed('onError'),
        onDone: anyNamed('onDone'),
      )).thenThrow(Exception('API Error'));

      await generator.generateChapter(
        novel: testNovel,
        chapters: chapters,
        afterIndex: 1,
        userInput: '生成章节',
        characterIds: [],
        onData: (data) {},
        onError: (error) => errorReceived = true,
        onDone: () {},
      );

      expect(errorReceived, isTrue);
    });

    test('generateChapter should include roles info', () async {
      final testNovel = MockData.createTestNovel();
      final chapters = MockData.createTestChapterList(count: 2);
      final characterIds = [1, 2];

      when(mockDb.getCachedChapter(any)).thenAnswer((_) async => '内容');
      when(mockDb.getCharactersByIds(characterIds)).thenAnswer((_) async => []);
      when(mockDify.runWorkflowStreaming(
        inputs: anyNamed('inputs'),
        onData: anyNamed('onData'),
        onError: anyNamed('onError'),
        onDone: anyNamed('onDone'),
      )).thenAnswer((_) async {});

      await generator.generateChapter(
        novel: testNovel,
        chapters: chapters,
        afterIndex: 1,
        userInput: '生成章节',
        characterIds: characterIds,
        onData: (data) {},
        onError: (error) {},
        onDone: () {},
      );

      verify(mockDb.getCharactersByIds(characterIds)).called(1);
    });
  });
}
