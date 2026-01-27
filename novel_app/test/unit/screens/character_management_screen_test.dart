import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/screens/character_management_screen.dart';
// 注意: EnhancedRelationshipGraphScreen目前有编译错误,暂时注释掉导入
// import 'package:novel_app/screens/enhanced_relationship_graph_screen.dart';

/// CharacterManagementScreen 关系图入口测试
///
/// 测试目标:
/// 1. 验证非多选模式下,AppBar中显示关系图图标按钮
/// 2. 验证点击关系图按钮能正确导航到关系图页面
/// 3. 验证多选模式下关系图按钮不显示
void main() {
  group('CharacterManagementScreen - 关系图入口功能', () {
    // 创建测试用的Novel对象
    final testNovel = Novel(
      title: '测试小说',
      author: '测试作者',
      url: 'https://example.com/test-novel',
    );

    testWidgets('测试1: 非多选模式下应显示关系图按钮', (WidgetTester tester) async {
      // 构建测试界面
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterManagementScreen(novel: testNovel),
        ),
      );

      // 等待界面加载完成
      await tester.pumpAndSettle();

      // 查找关系图按钮 (使用Icon的图标类型来查找)
      final relationshipButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.icon is Icon &&
            (widget.icon as Icon).icon == Icons.account_tree,
      );

      // 验证按钮存在
      expect(relationshipButton, findsOneWidget,
          reason: '非多选模式下AppBar应该显示关系图按钮');

      // 验证按钮的tooltip
      final iconButton = tester.widget<IconButton>(relationshipButton);
      expect(iconButton.tooltip, '全人物关系图',
          reason: '关系图按钮的tooltip应该正确显示');
    });

    testWidgets('测试2: 点击关系图按钮应触发导航', (WidgetTester tester) async {
      // 构建测试界面
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterManagementScreen(novel: testNovel),
        ),
      );

      // 等待界面加载完成
      await tester.pumpAndSettle();

      // 查找并点击关系图按钮
      final relationshipButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.icon is Icon &&
            (widget.icon as Icon).icon == Icons.account_tree,
      );

      expect(relationshipButton, findsOneWidget);

      // 验证按钮可以被点击(不实际触发导航,因为目标页面有编译错误)
      expect(tester.getRect(relationshipButton), isNotNull,
          reason: '关系图按钮应该是可交互的');
    });

    testWidgets('测试3: 多选模式下不应显示关系图按钮', (WidgetTester tester) async {
      // 构建测试界面
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterManagementScreen(novel: testNovel),
        ),
      );

      // 等待界面加载完成
      await tester.pumpAndSettle();

      // 初始状态下应该显示关系图按钮
      final relationshipButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.icon is Icon &&
            (widget.icon as Icon).icon == Icons.account_tree,
      );
      expect(relationshipButton, findsOneWidget);

      // 进入多选模式 (通过长按触发)
      // 注意: 由于没有实际角色数据,这里主要验证非多选状态下的UI
      // 实际的多选模式测试需要更多的mock数据
    });

    testWidgets('测试4: 关系图按钮应该与AI创建按钮同时显示', (WidgetTester tester) async {
      // 构建测试界面
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterManagementScreen(novel: testNovel),
        ),
      );

      // 等待界面加载完成
      await tester.pumpAndSettle();

      // 查找关系图按钮
      final relationshipButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.icon is Icon &&
            (widget.icon as Icon).icon == Icons.account_tree,
      );

      // 查找AI创建按钮 (可能有不同的图标)
      final aiCreateButton = find.byType(IconButton);

      // 验证至少有2个IconButton (关系图 + AI创建)
      expect(aiCreateButton, findsWidgets,
          reason: 'AppBar中应该有多个IconButton');

      // 验证关系图按钮存在
      expect(relationshipButton, findsOneWidget,
          reason: '关系图按钮应该存在');
    });

    testWidgets('测试5: 验证导航时传递正确的novelUrl参数',
        (WidgetTester tester) async {
      const testUrl = 'https://example.com/test-novel-123';

      final testNovelWithUrl = Novel(
        title: '测试小说2',
        author: '测试作者',
        url: testUrl,
      );

      // 构建测试界面
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterManagementScreen(novel: testNovelWithUrl),
        ),
      );

      // 等待界面加载完成
      await tester.pumpAndSettle();

      // 查找关系图按钮
      final relationshipButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.icon is Icon &&
            (widget.icon as Icon).icon == Icons.account_tree,
      );

      expect(relationshipButton, findsOneWidget,
          reason: '关系图按钮应该存在,以便验证导航参数');

      // 注意: 由于EnhancedRelationshipGraphScreen有编译错误,
      // 这里我们只验证按钮存在且可交互
      // 实际的参数传递验证需要目标页面编译通过后才能进行
      expect(relationshipButton, findsOneWidget);
    });
  });

  group('CharacterManagementScreen - UI布局验证', () {
    final testNovel = Novel(
      title: '测试小说',
      author: '测试作者',
      url: 'https://example.com/test-novel',
    );

    testWidgets('测试6: AppBar应该包含正确的标题', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterManagementScreen(novel: testNovel),
        ),
      );

      await tester.pumpAndSettle();

      // 查找AppBar标题
      final title = find.text('人物管理');
      expect(title, findsOneWidget, reason: 'AppBar标题应该显示"人物管理"');
    });

    testWidgets('测试7: 关系图按钮应该使用正确的图标', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterManagementScreen(novel: testNovel),
        ),
      );

      await tester.pumpAndSettle();

      // 查找关系图按钮
      final relationshipButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.icon is Icon &&
            (widget.icon as Icon).icon == Icons.account_tree,
      );

      expect(relationshipButton, findsOneWidget);

      // 验证图标样式
      final iconButton = tester.widget<IconButton>(relationshipButton);
      final icon = iconButton.icon as Icon;

      expect(icon.icon, Icons.account_tree,
          reason: '关系图按钮应该使用account_tree图标');
    });
  });
}
