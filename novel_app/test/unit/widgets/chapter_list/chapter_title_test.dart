import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/widgets/chapter_list/chapter_title.dart';

void main() {
  // 辅助函数：获取MaterialApp的error颜色
  Color getErrorColor(WidgetTester tester, Finder finder) {
    return Theme.of(tester.element(finder)).colorScheme.error;
  }

  // 辅助函数：获取MaterialApp的已读颜色
  Color getReadColor(WidgetTester tester, Finder finder) {
    return Theme.of(tester.element(finder)).colorScheme.onSurface.withValues(alpha: 0.6);
  }

  group('ChapterTitle Widget Tests', () {
    group('基础渲染测试', () {
      testWidgets('应该正常渲染章节标题', (WidgetTester tester) async {
        const String testTitle = '第一章 测试章节';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChapterTitle(
                title: testTitle,
                isLastRead: false,
                isUserChapter: false,
                isRead: false,
              ),
            ),
          ),
        );

        expect(find.text(testTitle), findsOneWidget);
      });

      testWidgets('应该使用默认样式渲染普通章节', (WidgetTester tester) async {
        const String testTitle = '第一章 测试章节';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChapterTitle(
                title: testTitle,
                isLastRead: false,
                isUserChapter: false,
                isRead: false,
              ),
            ),
          ),
        );

        final Text titleWidget = tester.widget(find.text(testTitle));
        final TextStyle style = titleWidget.style!;

        // 普通章节：正常字重、非斜体、无颜色（默认黑色）
        expect(style.fontWeight, FontWeight.normal);
        expect(style.fontStyle, FontStyle.normal);
        expect(style.color, isNull);
      });
    });

    group('最后阅读状态测试', () {
      testWidgets('最后阅读章节应该显示为粗体', (WidgetTester tester) async {
        const String testTitle = '第十章 最后阅读';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChapterTitle(
                title: testTitle,
                isLastRead: true, // 最后阅读
                isUserChapter: false,
                isRead: false,
              ),
            ),
          ),
        );

        final Text titleWidget = tester.widget(find.text(testTitle));
        expect(titleWidget.style?.fontWeight, FontWeight.bold);
      });

      testWidgets('最后阅读章节应该显示为红色', (WidgetTester tester) async {
        const String testTitle = '第十章 最后阅读';

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ChapterTitle(
                    title: testTitle,
                    isLastRead: true, // 最后阅读
                    isUserChapter: false,
                    isRead: false,
                  );
                },
              ),
            ),
          ),
        );

        final Text titleWidget = tester.widget(find.text(testTitle));
        // 使用实际的colorScheme.error而不是Colors.red
        expect(titleWidget.style?.color, getErrorColor(tester, find.text(testTitle)));
      });

      testWidgets('最后阅读状态优先于已读状态', (WidgetTester tester) async {
        const String testTitle = '第十章 既最后阅读又已读';

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ChapterTitle(
                    title: testTitle,
                    isLastRead: true, // 最后阅读
                    isUserChapter: false,
                    isRead: true, // 同时也是已读
                  );
                },
              ),
            ),
          ),
        );

        final Text titleWidget = tester.widget(find.text(testTitle));

        // 最后阅读优先：红色、粗体
        expect(titleWidget.style?.color, getErrorColor(tester, find.text(testTitle)));
        expect(titleWidget.style?.fontWeight, FontWeight.bold);
      });
    });

    group('已读状态测试', () {
      testWidgets('已读章节应该显示为灰色', (WidgetTester tester) async {
        const String testTitle = '第五章 已读章节';

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ChapterTitle(
                    title: testTitle,
                    isLastRead: false,
                    isUserChapter: false,
                    isRead: true, // 已读
                  );
                },
              ),
            ),
          ),
        );

        final Text titleWidget = tester.widget(find.text(testTitle));
        expect(titleWidget.style?.color, getReadColor(tester, find.text(testTitle)));
      });

      testWidgets('已读章节应该保持正常字重', (WidgetTester tester) async {
        const String testTitle = '第五章 已读章节';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChapterTitle(
                title: testTitle,
                isLastRead: false,
                isUserChapter: false,
                isRead: true,
              ),
            ),
          ),
        );

        final Text titleWidget = tester.widget(find.text(testTitle));
        expect(titleWidget.style?.fontWeight, FontWeight.normal);
      });

      testWidgets('已读但不是最后阅读的章节应该灰色', (WidgetTester tester) async {
        const String testTitle = '第八章 已读但不是最后';

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ChapterTitle(
                    title: testTitle,
                    isLastRead: false, // 不是最后阅读
                    isUserChapter: false,
                    isRead: true, // 已读
                  );
                },
              ),
            ),
          ),
        );

        final Text titleWidget = tester.widget(find.text(testTitle));
        expect(titleWidget.style?.color, getReadColor(tester, find.text(testTitle)));
        expect(titleWidget.style?.fontWeight, FontWeight.normal);
      });
    });

    group('用户插入章节测试', () {
      testWidgets('用户插入章节应该显示为斜体', (WidgetTester tester) async {
        const String testTitle = '插入章节 用户自定义';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChapterTitle(
                title: testTitle,
                isLastRead: false,
                isUserChapter: true, // 用户插入
                isRead: false,
              ),
            ),
          ),
        );

        final Text titleWidget = tester.widget(find.text(testTitle));
        expect(titleWidget.style?.fontStyle, FontStyle.italic);
      });

      testWidgets('用户插入且已读章节应该斜体+灰色', (WidgetTester tester) async {
        const String testTitle = '插入章节 且已读';

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ChapterTitle(
                    title: testTitle,
                    isLastRead: false,
                    isUserChapter: true, // 用户插入
                    isRead: true, // 已读
                  );
                },
              ),
            ),
          ),
        );

        final Text titleWidget = tester.widget(find.text(testTitle));
        expect(titleWidget.style?.fontStyle, FontStyle.italic);
        expect(titleWidget.style?.color, getReadColor(tester, find.text(testTitle)));
      });

      testWidgets('用户插入且最后阅读章节应该斜体+红色+粗体',
          (WidgetTester tester) async {
        const String testTitle = '插入章节 且最后阅读';

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ChapterTitle(
                    title: testTitle,
                    isLastRead: true, // 最后阅读
                    isUserChapter: true, // 用户插入
                    isRead: false,
                  );
                },
              ),
            ),
          ),
        );

        final Text titleWidget = tester.widget(find.text(testTitle));
        expect(titleWidget.style?.fontStyle, FontStyle.italic);
        expect(titleWidget.style?.color, getErrorColor(tester, find.text(testTitle)));
        expect(titleWidget.style?.fontWeight, FontWeight.bold);
      });
    });

    group('边界情况测试', () {
      testWidgets('应该处理空字符串标题', (WidgetTester tester) async {
        const String testTitle = '';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChapterTitle(
                title: testTitle,
                isLastRead: false,
                isUserChapter: false,
                isRead: false,
              ),
            ),
          ),
        );

        expect(find.text(''), findsOneWidget);
      });

      testWidgets('应该处理超长标题', (WidgetTester tester) async {
        final String longTitle = '第一章 ' * 50; // 超长标题（300+字符）

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChapterTitle(
                title: longTitle,
                isLastRead: false,
                isUserChapter: false,
                isRead: false,
              ),
            ),
          ),
        );

        expect(find.text(longTitle), findsOneWidget);
      });

      testWidgets('应该处理特殊字符标题', (WidgetTester tester) async {
        const String specialTitle = '第一章：<>&\"\'测试\\n\\t章节';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChapterTitle(
                title: specialTitle,
                isLastRead: false,
                isUserChapter: false,
                isRead: false,
              ),
            ),
          ),
        );

        expect(find.text(specialTitle), findsOneWidget);
      });
    });

    group('优先级测试', () {
      testWidgets('所有状态都为false时应使用默认样式', (WidgetTester tester) async {
        const String testTitle = '普通章节';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChapterTitle(
                title: testTitle,
                isLastRead: false,
                isUserChapter: false,
                isRead: false,
              ),
            ),
          ),
        );

        final Text titleWidget = tester.widget(find.text(testTitle));
        final TextStyle style = titleWidget.style!;

        expect(style.fontWeight, FontWeight.normal);
        expect(style.fontStyle, FontStyle.normal);
        expect(style.color, isNull);
      });

      testWidgets('isLastRead=true时应忽略isRead状态', (WidgetTester tester) async {
        const String testTitle = '优先级测试';

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ChapterTitle(
                    title: testTitle,
                    isLastRead: true,
                    isUserChapter: false,
                    isRead: true,
                  );
                },
              ),
            ),
          ),
        );

        final Text titleWidget = tester.widget(find.text(testTitle));

        // 验证：红色（最后阅读）而非灰色（已读）
        expect(titleWidget.style?.color, getErrorColor(tester, find.text(testTitle)));
      });
    });
  });
}
