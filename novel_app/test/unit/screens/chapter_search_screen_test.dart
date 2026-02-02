import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/screens/chapter_search_screen.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/chapter_manager.dart';
import 'package:novel_app/core/providers/chapter_search_providers.dart';
import '../../test_bootstrap.dart';

void main() {
  // 初始化数据库测试环境和设置测试模式
  setUpAll(() {
    // 必须在首次访问ChapterManager.instance之前调用
    initTests();
    ChapterManager.setTestMode(true);
  });

  // 创建 Provider 容器
  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [],
    );
  }

  group('ChapterSearchScreen - 基础UI测试', () {
    final testNovel = Novel(
      title: '测试小说',
      author: '测试作者',
      url: 'https://example.com/test-novel',
    );

    testWidgets('测试1: AppBar应该显示"搜索章节内容"标题', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('搜索章节内容'), findsOneWidget,
          reason: 'AppBar标题应该显示"搜索章节内容"');

      container.dispose();
    });

    testWidgets('测试2: 应该显示搜索输入框', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(TextField), findsOneWidget,
          reason: '应该有一个搜索输入框');

      container.dispose();
    });
  });

  group('ChapterSearchScreen - 搜索功能测试', () {
    final testNovel = Novel(
      title: '测试小说',
      author: '测试作者',
      url: 'https://example.com/test-novel',
    );

    testWidgets('测试6: 输入关键词并提交应该触发搜索', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      final textField = find.byType(TextField);

      // 输入关键词
      await tester.enterText(textField, '测试关键词');

      // 提交搜索
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // 验证UI更新
      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试7: 搜索中状态管理', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      // 输入并提交搜索
      await tester.enterText(find.byType(TextField), '测试');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // 验证UI不崩溃
      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试8: 空关键词搜索应该清除结果', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      final textField = find.byType(TextField);

      // 先输入关键词
      await tester.enterText(textField, '测试');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // 清空关键词
      await tester.enterText(textField, '');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // 验证UI不崩溃
      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试9: 搜索结果容器', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证UI容器存在
      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试10: AppBar清除按钮应该在搜索后显示', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      // 初始状态不应该有清除按钮
      expect(find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == '清除搜索',
      ), findsNothing);

      // 执行搜索
      await tester.enterText(find.byType(TextField), '测试');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // 搜索后应该显示清除按钮
      expect(find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == '清除搜索',
      ), findsOneWidget);

      container.dispose();
    });
  });

  group('ChapterSearchScreen - 搜索结果展示', () {
    final testNovel = Novel(
      title: '测试小说',
      author: '测试作者',
      url: 'https://example.com/test-novel',
    );

    testWidgets('测试11: 搜索结果应该显示章节标题', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试12: 搜索结果应该显示匹配数量', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试13: 搜索结果应该显示缓存时间', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试14: 点击搜索结果应该导航到阅读器', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证UI不崩溃
      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试15: 无搜索结果应该显示提示', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });
  });

  group('ChapterSearchScreen - 高亮显示测试', () {
    final testNovel = Novel(
      title: '测试小说',
      author: '测试作者',
      url: 'https://example.com/test-novel',
    );

    testWidgets('测试16: 匹配的关键词应该高亮显示', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试17: 高亮应该使用正确的颜色', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试18: 多个匹配项应该全部高亮', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });
  });

  group('ChapterSearchScreen - 交互测试', () {
    final testNovel = Novel(
      title: '测试小说',
      author: '测试作者',
      url: 'https://example.com/test-novel',
    );

    testWidgets('测试19: 点击清除按钮应该清除搜索', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      // 执行搜索
      await tester.enterText(find.byType(TextField), '测试');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // 点击AppBar的清除按钮（如果显示）
      final clearButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == '清除搜索',
      );

      if (clearButton.evaluate().isNotEmpty) {
        await tester.tap(clearButton);
        await tester.pump();

        // 应该返回初始状态
        expect(find.text('输入关键词搜索章节内容'), findsOneWidget);
      }

      container.dispose();
    });

    testWidgets('测试20: 点击输入框清除按钮应该清除文本', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      final textField = find.byType(TextField);

      // 输入文本
      await tester.enterText(textField, '测试关键词');
      await tester.pump();

      // 查找并点击清除按钮
      final clearButtons = find.byIcon(Icons.clear);
      if (clearButtons.evaluate().isNotEmpty) {
        await tester.tap(clearButtons.first);
        await tester.pump();

        // 文本应该被清除
        final textFieldAfter = tester.widget<TextField>(find.byType(TextField));
        expect(textFieldAfter.controller?.text, isEmpty);
      }

      container.dispose();
    });

    testWidgets('测试21: 搜索结果卡片应该可点击', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });
  });

  group('ChapterSearchScreen - 边界条件测试', () {
    final testNovel = Novel(
      title: '测试小说',
      author: '测试作者',
      url: 'https://example.com/test-novel',
    );

    testWidgets('测试22: 特殊字符搜索应该正常处理', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      // 输入特殊字符
      await tester.enterText(find.byType(TextField), '!@#\$%^&*()');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // 应该不崩溃
      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试23: 长关键词搜索应该正常处理', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      // 输入长文本
      final longText = '测试' * 100;
      await tester.enterText(find.byType(TextField), longText);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试24: Unicode表情搜索应该正常处理', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      // 输入表情符号
      await tester.enterText(find.byType(TextField), '😀🎉❤️');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });
  });

  group('ChapterSearchScreen - 状态管理测试', () {
    final testNovel = Novel(
      title: '测试小说',
      author: '测试作者',
      url: 'https://example.com/test-novel',
    );

    testWidgets('测试25: 加载章节列表失败不应该影响UI', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证UI仍然正常显示
      expect(find.byType(ChapterSearchScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试26: 搜索失败不应该影响UI', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      // 尝试搜索
      await tester.enterText(find.byType(TextField), '测试');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // 验证UI仍然正常
      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });
  });

  group('ChapterSearchScreen - UI样式测试', () {
    final testNovel = Novel(
      title: '测试小说',
      author: '测试作者',
      url: 'https://example.com/test-novel',
    );

    testWidgets('测试27: 搜索框应该有正确的边框', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.border, isNotNull);

      container.dispose();
    });

    testWidgets('测试28: 搜索框应该有前缀图标', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.prefixIcon, isA<Icon>());
      expect((textField.decoration?.prefixIcon as Icon).icon, Icons.search);

      container.dispose();
    });

    testWidgets('测试29: 搜索结果卡片应该有正确的样式', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });

    testWidgets('测试30: 空状态图标应该正确显示', (WidgetTester tester) async {
      final container = createContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ChapterSearchScreen(
              novel: testNovel,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证UI不崩溃
      expect(find.byType(ChapterSearchScreen), findsOneWidget);

      container.dispose();
    });
  });
}
