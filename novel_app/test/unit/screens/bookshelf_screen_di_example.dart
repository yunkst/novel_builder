/// BookshelfScreen依赖注入测试示例
///
/// 此文件展示如何使用依赖注入来测试BookshelfScreen，
/// 避免触发真实的数据库查询。

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/screens/bookshelf_screen.dart';
import 'package:novel_app/repositories/bookshelf_repository.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/services/preload_service.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/bookshelf.dart';

// 生成Mock类
@GenerateMocks([
  BookshelfRepository,
  DatabaseService,
  PreloadService,
])
import 'bookshelf_screen_di_example.mocks.dart';

void main() {
  group('BookshelfScreen 依赖注入测试', () {
    late MockBookshelfRepository mockRepository;
    late MockDatabaseService mockDatabaseService;
    late MockPreloadService mockPreloadService;

    setUp(() {
      mockRepository = MockBookshelfRepository();
      mockDatabaseService = MockDatabaseService();
      mockPreloadService = MockPreloadService();
    });

    testWidgets('应该使用注入的Mock Repository',
        (WidgetTester tester) async {
      // 准备测试数据
      final testNovels = [
        Novel(
          title: '测试小说1',
          author: '测试作者1',
          url: 'https://example.com/novel1',
          coverUrl: '',
          description: '测试描述',
        ),
        Novel(
          title: '测试小说2',
          author: '测试作者2',
          url: 'https://example.com/novel2',
          coverUrl: '',
          description: '测试描述',
        ),
      ];

      // 设置Mock行为
      when(mockRepository.getNovelsByBookshelf(1))
          .thenAnswer((_) async => testNovels);
      when(mockRepository.getBookshelves())
          .thenAnswer((_) async => [
                Bookshelf(
                  id: 1,
                  name: '全部小说',
                  createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  sortOrder: 0,
                  isSystem: true,
                ),
              ]);

      // 构建Widget时注入Mock依赖
      await tester.pumpWidget(
        MaterialApp(
          home: BookshelfScreen(
            bookshelfRepository: mockRepository,
            databaseService: mockDatabaseService,
            preloadService: mockPreloadService,
          ),
        ),
      );

      // 等待异步操作完成
      await tester.pumpAndSettle();

      // 验证Mock被调用（而不是真实数据库）
      verify(mockRepository.getNovelsByBookshelf(1)).called(1);

      // 验证UI显示了测试数据
      expect(find.text('测试小说1'), findsOneWidget);
      expect(find.text('测试小说2'), findsOneWidget);
    });

    testWidgets('应该显示空书架状态', (WidgetTester tester) async {
      // 设置Mock返回空列表
      when(mockRepository.getNovelsByBookshelf(1))
          .thenAnswer((_) async => []);
      when(mockRepository.getBookshelves())
          .thenAnswer((_) async => [
                Bookshelf(
                  id: 1,
                  name: '全部小说',
                  createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  sortOrder: 0,
                  isSystem: true,
                ),
              ]);

      await tester.pumpWidget(
        MaterialApp(
          home: BookshelfScreen(
            bookshelfRepository: mockRepository,
            databaseService: mockDatabaseService,
            preloadService: mockPreloadService,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证空状态提示
      expect(find.text('书架是空的'), findsOneWidget);
    });
  });
}
