import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/screens/multi_role_chat_screen.dart';
import 'package:novel_app/screens/providers/dify_provider.dart';
import 'package:novel_app/screens/providers/character_avatar_provider.dart';
import '../../test_bootstrap.dart';

void main() {
  // 初始化数据库测试环境
  setUpAll(() {
    initTests();
  });

  group('MultiRoleChatScreen - 基础UI测试', () {
    late List<Character> testCharacters;
    late String testPlay;
    late List<Map<String, dynamic>> testRoleStrategy;

    setUp(() {
      testCharacters = [
        Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '张三',
          gender: '男',
          age: 25,
          occupation: '战士',
          personality: '勇敢',
        ),
        Character(
          id: 2,
          novelUrl: 'https://example.com/novel',
          name: '李四',
          gender: '女',
          age: 23,
          occupation: '法师',
          personality: '聪明',
        ),
      ];

      testPlay = '测试剧本内容';

      testRoleStrategy = [
        {
          'name': '张三',
          'strategy': '勇敢的战士',
          'clothes': '盔甲',
        },
        {
          'name': '李四',
          'strategy': '聪明的法师',
          'clothes': '长袍',
        },
      ];
    });

    testWidgets('测试1: 应能成功创建widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: testCharacters,
              play: testPlay,
              roleStrategy: testRoleStrategy,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(MultiRoleChatScreen), findsOneWidget);
    });

    testWidgets('测试2: 应显示Scaffold结构', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: testCharacters,
              play: testPlay,
              roleStrategy: testRoleStrategy,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('测试3: AppBar应显示正确的主标题', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: testCharacters,
              play: testPlay,
              roleStrategy: testRoleStrategy,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('沉浸式对话'), findsOneWidget);
    });

    testWidgets('测试4: AppBar应显示所有角色名', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: testCharacters,
              play: testPlay,
              roleStrategy: testRoleStrategy,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证角色名出现在副标题中
      expect(find.textContaining('张三'), findsWidgets);
      expect(find.textContaining('李四'), findsWidgets);
    });

    testWidgets('测试5: 应显示角色策略按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: testCharacters,
              play: testPlay,
              roleStrategy: testRoleStrategy,
            ),
          ),
        ),
      );

      await tester.pump();

      // 查找info图标按钮
      final infoButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.icon is Icon &&
            (widget.icon as Icon).icon == Icons.info_outline,
      );

      expect(infoButton, findsOneWidget);
    });
  });

  group('MultiRoleChatScreen - 输入区域测试', () {
    late List<Character> testCharacters;
    late List<Map<String, dynamic>> testRoleStrategy;

    setUp(() {
      testCharacters = [
        Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色A',
          gender: '男',
          age: 25,
        ),
      ];

      testRoleStrategy = [
        {
          'name': '角色A',
          'strategy': '测试策略',
          'clothes': '测试服装',
        },
      ];
    });

    testWidgets('测试6: 应显示行为输入框', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: testCharacters,
              play: '测试剧本',
              roleStrategy: testRoleStrategy,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('测试7: 应显示对话输入框', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: testCharacters,
              play: '测试剧本',
              roleStrategy: testRoleStrategy,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证有TextField存在
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('测试8: 应显示发送按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: testCharacters,
              play: '测试剧本',
              roleStrategy: testRoleStrategy,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('测试9: 应显示角色提示信息', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: testCharacters,
              play: '测试剧本',
              roleStrategy: testRoleStrategy,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证角色提示图标
      expect(find.byIcon(Icons.people), findsOneWidget);

      // 验证提示文本
      expect(find.textContaining('正在与'), findsOneWidget);
      // "对话"可能出现在多个地方，所以我们检查至少有一个
      expect(find.textContaining('对话').evaluate().isNotEmpty, true);
    });
  });

  group('MultiRoleChatScreen - 多角色场景测试', () {
    testWidgets('测试10: 三个角色应正确显示', (WidgetTester tester) async {
      final threeCharacters = [
        Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色A',
          gender: '男',
          age: 25,
        ),
        Character(
          id: 2,
          novelUrl: 'https://example.com/novel',
          name: '角色B',
          gender: '女',
          age: 23,
        ),
        Character(
          id: 3,
          novelUrl: 'https://example.com/novel',
          name: '角色C',
          gender: '男',
          age: 30,
        ),
      ];

      final roleStrategy = threeCharacters.map((c) => {
        'name': c.name,
        'strategy': '测试策略',
        'clothes': '测试服装',
      }).toList();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: threeCharacters,
              play: '测试剧本',
              roleStrategy: roleStrategy,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证所有角色名都显示
      expect(find.textContaining('角色A'), findsWidgets);
      expect(find.textContaining('角色B'), findsWidgets);
      expect(find.textContaining('角色C'), findsWidgets);
    });

    testWidgets('测试11: 空角色列表应正常处理', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: [],
              play: '测试剧本',
              roleStrategy: [],
            ),
          ),
        ),
      );

      await tester.pump();

      // widget应该成功创建
      expect(find.byType(MultiRoleChatScreen), findsOneWidget);
    });

    testWidgets('测试12: userRole参数应正确传递', (WidgetTester tester) async {
      final characters = [
        Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '张三',
          gender: '男',
          age: 25,
        ),
      ];

      final roleStrategy = [
        {
          'name': '张三',
          'strategy': '测试策略',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: characters,
              play: '测试剧本',
              roleStrategy: roleStrategy,
              userRole: '张三',
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证屏幕正常构建
      expect(find.text('沉浸式对话'), findsOneWidget);
    });
  });

  group('MultiRoleChatScreen - 主题样式测试', () {
    testWidgets('测试13: 亮色主题应正常工作', (WidgetTester tester) async {
      final characters = [
        Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '测试角色',
          gender: '男',
          age: 25,
        ),
      ];

      final roleStrategy = [
        {
          'name': '测试角色',
          'strategy': '测试策略',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.light(),
            home: MultiRoleChatScreen(
              characters: characters,
              play: '测试剧本',
              roleStrategy: roleStrategy,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(MultiRoleChatScreen), findsOneWidget);
    });

    testWidgets('测试14: 暗色主题应正常工作', (WidgetTester tester) async {
      final characters = [
        Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '测试角色',
          gender: '男',
          age: 25,
        ),
      ];

      final roleStrategy = [
        {
          'name': '测试角色',
          'strategy': '测试策略',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: MultiRoleChatScreen(
              characters: characters,
              play: '测试剧本',
              roleStrategy: roleStrategy,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(MultiRoleChatScreen), findsOneWidget);
    });
  });

  group('MultiRoleChatScreen - 角色策略测试', () {
    testWidgets('测试15: 完整的策略信息应正确传递', (WidgetTester tester) async {
      final characters = [
        Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '战士',
          gender: '男',
          age: 25,
          occupation: '战士',
          personality: '勇敢',
        ),
        Character(
          id: 2,
          novelUrl: 'https://example.com/novel',
          name: '法师',
          gender: '女',
          age: 23,
          occupation: '法师',
          personality: '聪明',
        ),
      ];

      final roleStrategy = [
        {
          'name': '战士',
          'strategy': '勇敢的战士，喜欢冒险',
          'clothes': '重甲',
        },
        {
          'name': '法师',
          'strategy': '聪明的法师，擅长魔法',
          'clothes': '长袍',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: characters,
              play: '冒险故事',
              roleStrategy: roleStrategy,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证widget成功创建
      expect(find.byType(MultiRoleChatScreen), findsOneWidget);

      // 验证角色名显示
      expect(find.textContaining('战士'), findsWidgets);
      expect(find.textContaining('法师'), findsWidgets);
    });

    testWidgets('测试16: 策略列表为空应正常处理', (WidgetTester tester) async {
      final characters = [
        Character(
          id: 1,
          novelUrl: 'https://example.com/novel',
          name: '角色A',
          gender: '男',
          age: 25,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MultiRoleChatScreen(
              characters: characters,
              play: '测试剧本',
              roleStrategy: [],
            ),
          ),
        ),
      );

      await tester.pump();

      // widget应该成功创建
      expect(find.byType(MultiRoleChatScreen), findsOneWidget);
    });
  });
}
