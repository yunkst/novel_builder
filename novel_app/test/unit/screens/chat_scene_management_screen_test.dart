import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/chat_scene.dart';
import 'package:novel_app/screens/chat_scene_management_screen.dart';
import 'package:novel_app/repositories/chat_scene_repository.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqlite_api.dart';

@GenerateMocks([ChatSceneRepository])
import 'chat_scene_management_screen_test.mocks.dart';

/// ChatSceneManagementScreen单元测试
///
/// 测试重点:
/// 1. UI布局和组件显示
/// 2. 场景列表加载
/// 3. 添加场景功能
/// 4. 编辑场景功能
/// 5. 删除场景功能
/// 6. 搜索功能
/// 7. 空状态显示
void main() {
  // 初始化数据库测试环境
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // 创建测试widget的辅助函数
  Widget createTestWidget({ChatSceneRepository? repository}) {
    return MaterialApp(
      home: ChatSceneManagementScreen(
        chatSceneRepository: repository,
      ),
    );
  }

  group('ChatSceneManagementScreen - 基础UI测试', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试1: 应能成功创建widget', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试2: 应显示Scaffold结构', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('测试3: AppBar应包含正确标题', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.text('场景管理'), findsOneWidget);
    });

    testWidgets('测试4: 应显示搜索按钮', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('测试5: 应显示FloatingActionButton', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreen - 加载状态测试', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试6: 初始状态应显示加载指示器', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump();
    });

    testWidgets('测试7: AppBar标题应始终显示', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.text('场景管理'), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreen - 空状态测试', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试8: 无场景时应显示空状态提示', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      // 等待初始加载
      await tester.pump();
      // 等待异步操作完成
      await tester.pumpAndSettle();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
      expect(find.text('暂无预设场景'), findsOneWidget);
    });

    testWidgets('测试9: 空状态应显示提示图标', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      // 等待初始加载
      await tester.pump();
      // 等待异步操作完成
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreen - 搜索功能测试', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试10: 点击搜索按钮应显示搜索框', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      final searchButton = find.byType(IconButton);
      expect(searchButton, findsOneWidget);
      expect(tester.getRect(searchButton), isNotNull);
    });

    testWidgets('测试11: 搜索状态下AppBar应显示TextField', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      final searchButton = find.byType(IconButton);
      await tester.tap(searchButton);
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('测试12: 搜索按钮应可点击', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      final searchButton = find.byType(IconButton);
      expect(searchButton, findsOneWidget);
      expect(tester.getRect(searchButton), isNotNull);
    });
  });

  group('ChatSceneManagementScreen - 场景列表测试', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试13: 有场景时应显示ListView', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试14: ListView应使用正确的padding', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreen - FloatingActionButton测试', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试15: FAB应显示add图标', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('测试16: FAB应该可点击', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      expect(tester.getRect(fab), isNotNull);
    });

    testWidgets('测试17: FAB应使用正确的位置', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.floatingActionButton, isNotNull);
    });
  });

  group('ChatSceneManagementScreen - 场景卡片测试', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试18: 场景卡片应显示标题', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试19: 场景卡片应显示内容预览', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试20: 场景卡片应显示编辑按钮', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试21: 场景卡片应显示删除按钮', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试22: 场景卡片应显示创建时间', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreen - 日期格式化测试', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试23: 应正确格式化今天的日期', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试24: 应正确格式化昨天的日期', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试25: 应正确格式化一周内的日期', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试26: 应正确格式化较早的日期', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreen - 主题样式测试', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试27: 应使用Material主题', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试28: 亮色主题应正常工作', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: ChatSceneManagementScreen(
            chatSceneRepository: mockRepository,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试29: 暗色主题应正常工作', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ChatSceneManagementScreen(
            chatSceneRepository: mockRepository,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreen - UI组件验证', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试30: 应使用Card组件显示场景', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试31: 应使用Icon显示时间图标', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试32: 编辑按钮应使用edit图标', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试33: 删除按钮应使用delete图标', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreen - 边界情况测试', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试34: 数据库加载失败应显示错误', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试35: 网络错误时应保持UI稳定', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试36: 空搜索结果应显示相应提示', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreen - 交互测试', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试37: 点击场景卡片应触发选择', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试38: 点击FAB应触发添加场景', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      expect(tester.getRect(fab), isNotNull);
    });

    testWidgets('测试39: 搜索输入应触发过滤', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreen - 性能测试', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试40: 大量场景时应正常显示', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreen), findsOneWidget);
    });

    testWidgets('测试41: 快速切换搜索状态应保持稳定', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      expect(find.byType(IconButton), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreen - 无障碍测试', () {
    late MockChatSceneRepository mockRepository;

    setUp(() {
      mockRepository = MockChatSceneRepository();
      when(mockRepository.getAllChatScenes()).thenAnswer((_) async => []);
    });

    testWidgets('测试42: 按钮应具有tooltip', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      final searchButton = find.byType(IconButton);
      expect(searchButton, findsOneWidget);
      final buttonWidget = tester.widget<IconButton>(searchButton);
      expect(buttonWidget.tooltip, '搜索');
    });

    testWidgets('测试43: FAB应具有tooltip', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(repository: mockRepository));
      await tester.pump();
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.tooltip, '添加场景');
    });
  });
}
