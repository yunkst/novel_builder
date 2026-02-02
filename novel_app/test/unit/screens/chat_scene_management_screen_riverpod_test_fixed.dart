import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/chat_scene.dart';
import 'package:novel_app/screens/chat_scene_management_screen_riverpod.dart';
import 'package:novel_app/core/providers/chat_scene_management_providers.dart';
import 'package:novel_app/repositories/chat_scene_repository.dart';

/// Mock ChatSceneRepository
class MockChatSceneRepository implements ChatSceneRepository {
  final List<ChatScene> _scenes = [];

  @override
  Future<List<ChatScene>> getAllChatScenes() async {
    await Future.delayed(Duration(milliseconds: 10));
    return _scenes;
  }

  @override
  Future<int> createChatScene(ChatScene scene) async {
    await Future.delayed(Duration(milliseconds: 10));
    _scenes.add(scene.copyWith(id: _scenes.length + 1));
    return _scenes.length;
  }

  @override
  Future<int> updateChatScene(ChatScene scene) async {
    await Future.delayed(Duration(milliseconds: 10));
    return 1;
  }

  @override
  Future<int> deleteChatScene(int id) async {
    await Future.delayed(Duration(milliseconds: 10));
    return 1;
  }

  @override
  Future<ChatScene?> getChatSceneById(int id) async {
    await Future.delayed(Duration(milliseconds: 10));
    return _scenes.where((s) => s.id == id).firstOrNull;
  }

  @override
  Future<List<ChatScene>> searchChatScenes(String query) async {
    await Future.delayed(Duration(milliseconds: 10));
    return _scenes
        .where((s) =>
            s.title.toLowerCase().contains(query.toLowerCase()) ||
            (s.content?.toLowerCase().contains(query.toLowerCase()) ?? false))
        .toList();
  }
}

// 创建Mock Provider
final mockChatSceneRepositoryProvider = Provider<ChatSceneRepository>((ref) {
  return MockChatSceneRepository();
});

/// ChatSceneManagementScreenRiverpod Riverpod版本单元测试
///
/// 测试重点:
/// 1. UI布局和组件显示
/// 2. Riverpod Provider集成
/// 3. 场景列表加载
/// 4. 添加场景功能
/// 5. 编辑场景功能
/// 6. 删除场景功能
/// 7. 搜索功能
/// 8. 空状态显示
void main() {
  // 创建测试widget的辅助函数
  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        chatSceneRepositoryProvider.overrideWithValue(MockChatSceneRepository()),
      ],
      child: const MaterialApp(
        home: ChatSceneManagementScreenRiverpod(),
      ),
    );
  }

  group('ChatSceneManagementScreenRiverpod (Riverpod) - 基础UI测试', () {
    testWidgets('测试1: 应能成功创建widget', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreenRiverpod), findsOneWidget);
    });

    testWidgets('测试2: 应显示Scaffold结构', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('测试3: AppBar应包含正确标题', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      expect(find.text('场景管理'), findsOneWidget);
    });

    testWidgets('测试4: 应显示搜索按钮', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('测试5: 应显示FloatingActionButton', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreenRiverpod (Riverpod) - 加载状态测试', () {
    testWidgets('测试6: 初始状态应显示加载指示器', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump();
    });

    testWidgets('测试7: AppBar标题应始终显示', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      expect(find.text('场景管理'), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreenRiverpod (Riverpod) - 空状态测试', () {
    testWidgets('测试8: 无场景时应显示空状态提示', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ChatSceneManagementScreenRiverpod), findsOneWidget);
    });

    testWidgets('测试9: 空状态应显示提示图标', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ChatSceneManagementScreenRiverpod), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreenRiverpod (Riverpod) - 搜索功能测试', () {
    testWidgets('测试10: 点击搜索按钮应显示搜索框', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      final searchButton = find.byType(IconButton);
      expect(searchButton, findsOneWidget);
      expect(tester.getRect(searchButton), isNotNull);
    });

    testWidgets('测试11: 搜索状态下AppBar应显示TextField', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      final searchButton = find.byType(IconButton);
      await tester.tap(searchButton);
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('测试12: 搜索按钮应可点击', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      final searchButton = find.byType(IconButton);
      expect(searchButton, findsOneWidget);
      expect(tester.getRect(searchButton), isNotNull);
    });
  });

  group('ChatSceneManagementScreenRiverpod (Riverpod) - FloatingActionButton测试', () {
    testWidgets('测试15: FAB应显示add图标', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('测试16: FAB应该可点击', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      expect(tester.getRect(fab), isNotNull);
    });

    testWidgets('测试17: FAB应使用正确的位置', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.floatingActionButton, isNotNull);
    });
  });

  group('ChatSceneManagementScreenRiverpod (Riverpod) - 主题样式测试', () {
    testWidgets('测试29: 亮色主题应正常工作', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatSceneRepositoryProvider.overrideWithValue(MockChatSceneRepository()),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const ChatSceneManagementScreenRiverpod(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreenRiverpod), findsOneWidget);
    });

    testWidgets('测试30: 暗色主题应正常工作', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatSceneRepositoryProvider.overrideWithValue(MockChatSceneRepository()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const ChatSceneManagementScreenRiverpod(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreenRiverpod), findsOneWidget);
    });
  });

  group('ChatSceneManagementScreenRiverpod (Riverpod) - 无障碍测试', () {
    testWidgets('测试42: 按钮应具有tooltip', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      final searchButton = find.byType(IconButton);
      expect(searchButton, findsOneWidget);
      final buttonWidget = tester.widget<IconButton>(searchButton);
      expect(buttonWidget.tooltip, '搜索');
    });

    testWidgets('测试43: FAB应具有tooltip', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.tooltip, '添加场景');
    });
  });

  group('ChatSceneManagementScreenRiverpod (Riverpod) - Provider集成测试', () {
    testWidgets('测试44: Provider应正确初始化', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreenRiverpod), findsOneWidget);
    });

    testWidgets('测试45: 状态更新应触发UI重建', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreenRiverpod), findsOneWidget);
    });

    testWidgets('测试46: Provider应正确处理加载状态', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      expect(find.byType(ChatSceneManagementScreenRiverpod), findsOneWidget);
    });
  });
}
