import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/ai_accompaniment_settings.dart';
import 'package:novel_app/screens/chapter_list_screen_riverpod.dart';
import 'package:novel_app/core/providers/service_providers.dart';
import 'package:novel_app/core/providers/database_providers.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:novel_app/services/api_service_wrapper.dart';
import 'package:novel_app/services/dify_service.dart';
import 'package:novel_app/services/preload_service.dart';
import '../../test_bootstrap.dart';

@GenerateNiceMocks([
  MockSpec<DatabaseService>(),
  MockSpec<ApiServiceWrapper>(),
  MockSpec<DifyService>(),
  MockSpec<PreloadService>(),
])
import 'chapter_list_screen_riverpod_test.mocks.dart';

void main() {
  // 初始化测试环境
  setUpAll(() {
    initTests();
  });

  group('ChapterListScreenRiverpod - Widget 渲染测试', () {
    late MockDatabaseService mockDatabaseService;
    late MockApiServiceWrapper mockApiService;
    late MockDifyService mockDifyService;
    late MockPreloadService mockPreloadService;

    setUp(() {
      mockDatabaseService = MockDatabaseService();
      mockApiService = MockApiServiceWrapper();
      mockDifyService = MockDifyService();
      mockPreloadService = MockPreloadService();

      // 设置 Mock 返回值
      when(mockDatabaseService.isInBookshelf(any))
          .thenAnswer((_) async => false);
      when(mockDatabaseService.getCachedNovelChapters(any))
          .thenAnswer((_) async => []);
      when(mockDatabaseService.getLastReadChapter(any))
          .thenAnswer((_) async => 0);
      when(mockDatabaseService.getAiAccompanimentSettings(any))
          .thenAnswer((_) async => const AiAccompanimentSettings());
    });

    testWidgets('测试1: Widget应该正确创建', (WidgetTester tester) async {
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://test.com/novel',
      );

      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(mockDatabaseService),
          apiServiceWrapperProvider.overrideWithValue(mockApiService),
          difyServiceProvider.overrideWithValue(mockDifyService),
          preloadServiceProvider.overrideWithValue(mockPreloadService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterListScreenRiverpod(novel: testNovel),
          ),
        ),
      );

      // 验证 Widget 存在
      expect(find.byType(ChapterListScreenRiverpod), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试2: 应该显示 Scaffold', (WidgetTester tester) async {
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://test.com/novel',
      );

      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(mockDatabaseService),
          apiServiceWrapperProvider.overrideWithValue(mockApiService),
          difyServiceProvider.overrideWithValue(mockDifyService),
          preloadServiceProvider.overrideWithValue(mockPreloadService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterListScreenRiverpod(novel: testNovel),
          ),
        ),
      );

      // 验证 Scaffold 存在
      expect(find.byType(Scaffold), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试3: 应该有 AppBar', (WidgetTester tester) async {
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://test.com/novel',
      );

      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(mockDatabaseService),
          apiServiceWrapperProvider.overrideWithValue(mockApiService),
          difyServiceProvider.overrideWithValue(mockDifyService),
          preloadServiceProvider.overrideWithValue(mockPreloadService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterListScreenRiverpod(novel: testNovel),
          ),
        ),
      );

      // 验证 AppBar 存在
      expect(find.byType(AppBar), findsOneWidget);

      container.dispose();
    });
  });

  group('ChapterListScreenRiverpod - 类型检查测试', () {
    testWidgets('测试4: Widget类型应该是 ChapterListScreenRiverpod',
        (WidgetTester tester) async {
      final testNovel = Novel(
        title: '测试小说',
        author: '测试作者',
        url: 'https://test.com/novel',
      );

      final mockDatabaseService = MockDatabaseService();
      final mockApiService = MockApiServiceWrapper();
      final mockDifyService = MockDifyService();
      final mockPreloadService = MockPreloadService();

      when(mockDatabaseService.isInBookshelf(any))
          .thenAnswer((_) async => false);
      when(mockDatabaseService.getCachedNovelChapters(any))
          .thenAnswer((_) async => []);
      when(mockDatabaseService.getLastReadChapter(any))
          .thenAnswer((_) async => 0);
      when(mockDatabaseService.getAiAccompanimentSettings(any))
          .thenAnswer((_) async => const AiAccompanimentSettings());

      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(mockDatabaseService),
          apiServiceWrapperProvider.overrideWithValue(mockApiService),
          difyServiceProvider.overrideWithValue(mockDifyService),
          preloadServiceProvider.overrideWithValue(mockPreloadService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterListScreenRiverpod(novel: testNovel),
          ),
        ),
      );

      // 验证 Widget 类型
      expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ChapterListScreenRiverpod &&
                widget.novel.title == '测试小说',
          ),
          findsOneWidget);

      container.dispose();
    });
  });
}
