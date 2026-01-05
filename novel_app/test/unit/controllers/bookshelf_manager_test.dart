import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/controllers/chapter_list/bookshelf_manager.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/models/novel.dart';
import '../../test_helpers/mock_data.dart';

@GenerateMocks([DatabaseService])
import 'bookshelf_manager_test.mocks.dart';

/// BookshelfManager 单元测试
void main() {
  group('BookshelfManager', () {
    late BookshelfManager manager;
    late MockDatabaseService mockDb;

    setUp(() {
      mockDb = MockDatabaseService();
      manager = BookshelfManager(
        databaseService: mockDb,
      );
    });

    test('isInBookshelf should call database', () async {
      when(mockDb.isInBookshelf('test-url')).thenAnswer((_) async => true);

      final result = await manager.isInBookshelf('test-url');

      expect(result, isTrue);
      verify(mockDb.isInBookshelf('test-url')).called(1);
    });

    test('addToBookshelf should call database', () async {
      final testNovel = MockData.createTestNovel();
      when(mockDb.addToBookshelf(testNovel)).thenAnswer((_) async => 1);

      await manager.addToBookshelf(testNovel);

      verify(mockDb.addToBookshelf(testNovel)).called(1);
    });

    test('removeFromBookshelf should call database', () async {
      when(mockDb.removeFromBookshelf('test-url')).thenAnswer((_) async => 1);

      await manager.removeFromBookshelf('test-url');

      verify(mockDb.removeFromBookshelf('test-url')).called(1);
    });

    test('clearNovelCache should call database', () async {
      when(mockDb.clearNovelCache('test-url')).thenAnswer((_) async {});

      await manager.clearNovelCache('test-url');

      verify(mockDb.clearNovelCache('test-url')).called(1);
    });
  });
}
