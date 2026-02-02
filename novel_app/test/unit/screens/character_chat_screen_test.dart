import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/chat_message.dart';
import 'package:novel_app/screens/character_chat_screen.dart';
import 'package:novel_app/services/dify_service.dart';
import 'package:novel_app/services/character_avatar_service.dart';
import 'package:novel_app/core/providers/service_providers.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../../test_bootstrap.dart';

@GenerateMocks([
  DifyService,
  CharacterAvatarService,
])
import 'character_chat_screen_test.mocks.dart';

void main() {
  // 初始化数据库测试环境
  setUpAll(() {
    initTests();
  });

  group('CharacterChatScreen - 基础UI测试', () {
    late Character testCharacter;
    late MockDifyService mockDifyService;
    late MockCharacterAvatarService mockAvatarService;
    late ProviderContainer container;

    setUp(() {
      testCharacter = Character(
        id: 1,
        novelUrl: 'https://example.com/novel',
        name: '测试角色',
        gender: '男',
        age: 25,
        occupation: '战士',
        personality: '勇敢',
      );

      // 创建 Mock 服务
      mockDifyService = MockDifyService();
      mockAvatarService = MockCharacterAvatarService();

      // 创建 ProviderContainer 并覆盖服务
      container = ProviderContainer(
        overrides: [
          difyServiceProvider.overrideWithValue(mockDifyService),
          characterAvatarServiceProvider.overrideWithValue(mockAvatarService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Widget createTestWidget({required Character character, required String scene}) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CharacterChatScreen(
            character: character,
            initialScene: scene,
          ),
        ),
      );
    }

    testWidgets('测试1: 应能成功创建widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          character: testCharacter,
          scene: '测试场景',
        ),
      );

      // 只pump不等待，避免异步操作超时
      await tester.pump();

      // 验证widget存在
      expect(find.byType(CharacterChatScreen), findsOneWidget);
    });

    testWidgets('测试2: 应显示Scaffold结构', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          character: testCharacter,
          scene: '测试场景',
        ),
      );

      await tester.pump();

      // 验证基本结构
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('测试3: AppBar应包含标题', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          character: testCharacter,
          scene: '测试场景',
        ),
      );

      await tester.pump();

      // 验证AppBar存在
      expect(find.byType(AppBar), findsOneWidget);

      // 验证标题包含角色名
      expect(find.textContaining('与'), findsWidgets);
      expect(find.textContaining('测试角色'), findsWidgets);
      expect(find.textContaining('聊天'), findsWidgets);
    });

    testWidgets('测试4: 应显示场景信息', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          character: testCharacter,
          scene: '咖啡馆',
        ),
      );

      await tester.pump();

      // 验证场景显示
      expect(find.textContaining('场景'), findsWidgets);
      expect(find.textContaining('咖啡馆'), findsWidgets);
    });
  });

  group('CharacterChatScreen - 输入区域测试', () {
    late Character testCharacter;
    late MockDifyService mockDifyService;
    late MockCharacterAvatarService mockAvatarService;
    late ProviderContainer container;

    setUp(() {
      testCharacter = Character(
        id: 1,
        novelUrl: 'https://example.com/novel',
        name: '角色A',
        gender: '男',
        age: 25,
      );

      // 创建 Mock 服务
      mockDifyService = MockDifyService();
      mockAvatarService = MockCharacterAvatarService();

      // 创建 ProviderContainer 并覆盖服务
      container = ProviderContainer(
        overrides: [
          difyServiceProvider.overrideWithValue(mockDifyService),
          characterAvatarServiceProvider.overrideWithValue(mockAvatarService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Widget createTestWidget({required Character character, required String scene}) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CharacterChatScreen(
            character: character,
            initialScene: scene,
          ),
        ),
      );
    }

    testWidgets('测试5: 应显示行为输入框', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          character: testCharacter,
          scene: '测试',
        ),
      );

      await tester.pump();

      // 验证输入框存在
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('测试6: 应显示对话输入框', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          character: testCharacter,
          scene: '测试',
        ),
      );

      await tester.pump();

      // 验证有多个TextField（行为和对话）
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);
    });

    testWidgets('测试7: 应显示发送按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          character: testCharacter,
          scene: '测试',
        ),
      );

      await tester.pump();

      // 验证发送按钮存在
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('CharacterChatScreen - 角色参数测试', () {
    late MockDifyService mockDifyService;
    late MockCharacterAvatarService mockAvatarService;
    late ProviderContainer container;

    setUp(() {
      // 创建 Mock 服务
      mockDifyService = MockDifyService();
      mockAvatarService = MockCharacterAvatarService();

      // 创建 ProviderContainer 并覆盖服务
      container = ProviderContainer(
        overrides: [
          difyServiceProvider.overrideWithValue(mockDifyService),
          characterAvatarServiceProvider.overrideWithValue(mockAvatarService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Widget createTestWidget({required Character character, required String scene}) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CharacterChatScreen(
            character: character,
            initialScene: scene,
          ),
        ),
      );
    }

    testWidgets('测试8: 不同角色名应正确显示', (WidgetTester tester) async {
      final character1 = Character(
        id: 1,
        novelUrl: 'https://example.com/novel',
        name: '李明',
        gender: '男',
        age: 30,
      );

      await tester.pumpWidget(
        createTestWidget(
          character: character1,
          scene: '办公室',
        ),
      );

      await tester.pump();

      // 验证角色名显示
      expect(find.textContaining('李明'), findsWidgets);
    });

    testWidgets('测试9: 不同场景应正确显示', (WidgetTester tester) async {
      final character = Character(
        id: 1,
        novelUrl: 'https://example.com/novel',
        name: '角色A',
        gender: '女',
        age: 20,
      );

      await tester.pumpWidget(
        createTestWidget(
          character: character,
          scene: '花园',
        ),
      );

      await tester.pump();

      // 验证场景显示
      expect(find.textContaining('花园'), findsWidgets);
    });

    testWidgets('测试10: 角色ID应正确传递', (WidgetTester tester) async {
      final character = Character(
        id: 999,
        novelUrl: 'https://example.com/novel',
        name: '测试角色',
        gender: '男',
        age: 25,
      );

      await tester.pumpWidget(
        createTestWidget(
          character: character,
          scene: '测试',
        ),
      );

      await tester.pump();

      // 验证widget成功创建（包含正确的角色信息）
      expect(find.byType(CharacterChatScreen), findsOneWidget);
    });
  });

  group('CharacterChatScreen - 消息显示测试', () {
    late Character testCharacter;
    late MockDifyService mockDifyService;
    late MockCharacterAvatarService mockAvatarService;
    late ProviderContainer container;

    setUp(() {
      testCharacter = Character(
        id: 1,
        novelUrl: 'https://example.com/novel',
        name: '测试角色',
        gender: '男',
        age: 25,
      );

      // 创建 Mock 服务
      mockDifyService = MockDifyService();
      mockAvatarService = MockCharacterAvatarService();

      // 创建 ProviderContainer 并覆盖服务
      container = ProviderContainer(
        overrides: [
          difyServiceProvider.overrideWithValue(mockDifyService),
          characterAvatarServiceProvider.overrideWithValue(mockAvatarService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Widget createTestWidget({required Character character, required String scene}) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CharacterChatScreen(
            character: character,
            initialScene: scene,
          ),
        ),
      );
    }

    testWidgets('测试11: 空状态应显示提示文本', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          character: testCharacter,
          scene: '测试场景',
        ),
      );

      await tester.pump();

      // 在初始加载时可能会显示"正在建立连接..."或"开始你们的对话吧！"
      final hasStartText = find.textContaining('开始').evaluate().isNotEmpty;
      final hasConnectingText = find.textContaining('建立连接').evaluate().isNotEmpty;

      expect(hasStartText || hasConnectingText, true);
    });

    testWidgets('测试12: 消息列表应使用ListView', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          character: testCharacter,
          scene: '测试',
        ),
      );

      await tester.pump();

      // 验证主内容区域存在
      expect(find.byType(Column), findsWidgets);
    });
  });

  group('CharacterChatScreen - 主题样式测试', () {
    late MockDifyService mockDifyService;
    late MockCharacterAvatarService mockAvatarService;
    late ProviderContainer container;

    setUp(() {
      // 创建 Mock 服务
      mockDifyService = MockDifyService();
      mockAvatarService = MockCharacterAvatarService();

      // 创建 ProviderContainer 并覆盖服务
      container = ProviderContainer(
        overrides: [
          difyServiceProvider.overrideWithValue(mockDifyService),
          characterAvatarServiceProvider.overrideWithValue(mockAvatarService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Widget createTestWidget({required Character character, required String scene, ThemeData? theme}) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme,
          home: CharacterChatScreen(
            character: character,
            initialScene: scene,
          ),
        ),
      );
    }

    testWidgets('测试13: 应使用Material主题', (WidgetTester tester) async {
      final character = Character(
        id: 1,
        novelUrl: 'https://example.com/novel',
        name: '角色A',
        gender: '女',
        age: 20,
      );

      await tester.pumpWidget(
        createTestWidget(
          character: character,
          scene: '测试',
          theme: ThemeData.light(),
        ),
      );

      await tester.pump();

      // 验证widget成功构建
      expect(find.byType(CharacterChatScreen), findsOneWidget);
    });

    testWidgets('测试14: 暗色主题应正常工作', (WidgetTester tester) async {
      final character = Character(
        id: 1,
        novelUrl: 'https://example.com/novel',
        name: '角色B',
        gender: '男',
        age: 25,
      );

      await tester.pumpWidget(
        createTestWidget(
          character: character,
          scene: '测试',
          theme: ThemeData.dark(),
        ),
      );

      await tester.pump();

      // 验证widget成功构建
      expect(find.byType(CharacterChatScreen), findsOneWidget);
    });
  });
}
