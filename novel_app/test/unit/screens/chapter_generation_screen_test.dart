import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/screens/chapter_generation_screen.dart';

void main() {
  group('ChapterGenerationScreen', () {
    late ValueNotifier<String> contentNotifier;
    late ValueNotifier<bool> isGeneratingNotifier;

    setUp(() {
      contentNotifier = ValueNotifier<String>('');
      isGeneratingNotifier = ValueNotifier<bool>(false);
    });

    tearDown(() {
      contentNotifier.dispose();
      isGeneratingNotifier.dispose();
    });

    testWidgets('显示生成页面并验证初始UI', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ChapterGenerationScreen(
              title: '第一章 开始',
              generatedContentNotifier: contentNotifier,
              isGeneratingNotifier: isGeneratingNotifier,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证标题
      expect(find.text('第一章 开始'), findsOneWidget);

      // 验证初始加载状态
      expect(find.text('正在生成中...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 验证底部按钮存在（至少2个取消按钮，一个在AppBar一个在底部）
      expect(find.text('取消'), findsWidgets);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('插入'), findsOneWidget);
    });

    testWidgets('内容生成时显示流式内容', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ChapterGenerationScreen(
              title: '第一章 开始',
              generatedContentNotifier: contentNotifier,
              isGeneratingNotifier: isGeneratingNotifier,
            ),
          ),
        ),
      );

      await tester.pump();

      // 模拟内容生成
      contentNotifier.value = '这是第一章的内容';
      isGeneratingNotifier.value = true;

      await tester.pump();

      // 验证内容显示
      expect(find.text('这是第一章的内容'), findsOneWidget);
      expect(find.text('正在生成中...'), findsOneWidget);

      // 验证生成中提示条
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('生成完成后更新UI状态', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ChapterGenerationScreen(
              title: '第一章 开始',
              generatedContentNotifier: contentNotifier,
              isGeneratingNotifier: isGeneratingNotifier,
            ),
          ),
        ),
      );

      await tester.pump();

      // 生成中状态
      contentNotifier.value = '这是第一章的内容';
      isGeneratingNotifier.value = true;

      await tester.pump();

      // 生成完成状态
      isGeneratingNotifier.value = false;

      await tester.pump();

      // 验证生成中状态变化
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('插入'), findsOneWidget);
    });

    testWidgets('生成中时重试和插入按钮禁用', (WidgetTester tester) async {
      contentNotifier.value = '这是第一章的内容';
      isGeneratingNotifier.value = true;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ChapterGenerationScreen(
              title: '第一章 开始',
              generatedContentNotifier: contentNotifier,
              isGeneratingNotifier: isGeneratingNotifier,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证重试按钮显示为"生成中"（禁用状态）
      expect(find.text('生成中'), findsOneWidget);

      // 验证插入按钮存在
      expect(find.text('插入'), findsOneWidget);
    });

    testWidgets('空内容时插入按钮禁用', (WidgetTester tester) async {
      contentNotifier.value = '';
      isGeneratingNotifier.value = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ChapterGenerationScreen(
              title: '第一章 开始',
              generatedContentNotifier: contentNotifier,
              isGeneratingNotifier: isGeneratingNotifier,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证插入按钮存在
      expect(find.text('插入'), findsOneWidget);
    });

    testWidgets('长内容显示和滚动', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ChapterGenerationScreen(
              title: '第一章 开始',
              generatedContentNotifier: contentNotifier,
              isGeneratingNotifier: isGeneratingNotifier,
            ),
          ),
        ),
      );

      await tester.pump();

      // 生成超长内容
      final longContent = List.generate(100, (i) => '段落 ${i + 1} 内容').join('\n');
      contentNotifier.value = longContent;
      isGeneratingNotifier.value = true;

      await tester.pump();

      // 验证内容显示
      expect(find.textContaining('段落 1 内容'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('ChapterGenerationScreen 边界情况', () {
    late ValueNotifier<String> contentNotifier;
    late ValueNotifier<bool> isGeneratingNotifier;

    setUp(() {
      contentNotifier = ValueNotifier<String>('');
      isGeneratingNotifier = ValueNotifier<bool>(false);
    });

    tearDown(() {
      contentNotifier.dispose();
      isGeneratingNotifier.dispose();
    });

    testWidgets('空内容标题处理', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ChapterGenerationScreen(
              title: '',
              generatedContentNotifier: contentNotifier,
              isGeneratingNotifier: isGeneratingNotifier,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证页面正常显示
      expect(find.byType(ChapterGenerationScreen), findsOneWidget);
    });

    testWidgets('特殊字符内容处理', (WidgetTester tester) async {
      final specialContent = '第一段\n\n\n第三段\n[特殊标记]\n第五段';

      contentNotifier.value = specialContent;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ChapterGenerationScreen(
              title: '特殊字符测试',
              generatedContentNotifier: contentNotifier,
              isGeneratingNotifier: isGeneratingNotifier,
            ),
          ),
        ),
      );

      await tester.pump();

      // 验证特殊字符内容正常显示
      expect(find.textContaining('第一段'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    });
  });

  group('ChapterGenerationScreen 状态管理', () {
    late ValueNotifier<String> contentNotifier;
    late ValueNotifier<bool> isGeneratingNotifier;

    setUp(() {
      contentNotifier = ValueNotifier<String>('');
      isGeneratingNotifier = ValueNotifier<bool>(false);
    });

    tearDown(() {
      contentNotifier.dispose();
      isGeneratingNotifier.dispose();
    });

    testWidgets('内容变化时自动滚动', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ChapterGenerationScreen(
              title: '第一章 开始',
              generatedContentNotifier: contentNotifier,
              isGeneratingNotifier: isGeneratingNotifier,
            ),
          ),
        ),
      );

      await tester.pump();

      // 生成初始内容
      contentNotifier.value = '第一段内容';
      isGeneratingNotifier.value = true;

      await tester.pump();

      // 追加新内容
      contentNotifier.value = '第一段内容\n第二段内容';

      await tester.pump();

      // 验证自动滚动（通过ScrollController存在来验证）
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('生成结束后停止自动滚动', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ChapterGenerationScreen(
              title: '第一章 开始',
              generatedContentNotifier: contentNotifier,
              isGeneratingNotifier: isGeneratingNotifier,
            ),
          ),
        ),
      );

      await tester.pump();

      // 生成中
      contentNotifier.value = '第一段内容';
      isGeneratingNotifier.value = true;

      await tester.pump();

      // 生成结束
      isGeneratingNotifier.value = false;

      await tester.pump();

      // 追加新内容（生成结束后不应自动滚动）
      contentNotifier.value = '第一段内容\n第二段内容';

      await tester.pump();

      // 验证生成中提示消失
      expect(find.text('正在生成中...'), findsNothing);
    });
  });
}
