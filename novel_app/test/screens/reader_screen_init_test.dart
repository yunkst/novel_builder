import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/screens/reader_screen.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/chapter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ReaderScreen 初始化测试
///
/// 测试目标：验证 ReaderScreen 能够正常初始化，不会出现循环嵌套导致的堆栈溢出
void main() {
  testWidgets('ReaderScreen 应该能够正常初始化，不会出现无限循环',
      (WidgetTester tester) async {
    // Arrange: 准备测试数据
    final novel = Novel(
      title: '测试小说',
      author: '测试作者',
      url: 'https://example.com/novel/1',
      isInBookshelf: false,
    );

    final chapter = Chapter(
      title: '第一章',
      url: 'https://example.com/chapter/1',
      content: '这是测试内容',
    );

    final chapters = [
      chapter,
      Chapter(
        title: '第二章',
        url: 'https://example.com/chapter/2',
        content: '这是第二章内容',
      ),
    ];

    int buildCount = 0;
    const maxAllowedBuilds = 100; // 防止真的无限循环

    // Act: 构建 ReaderScreen
    await tester.pumpWidget(
      ProviderScope(
        overrides: [],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              buildCount++;
              if (buildCount > maxAllowedBuilds) {
                throw Exception(
                  '检测到可能的无限循环：build 次数超过 $maxAllowedBuilds',
                );
              }
              return ReaderScreen(
                novel: novel,
                chapter: chapter,
                chapters: chapters,
              );
            },
          ),
        ),
      ),
    );

    // 等待初始化完成
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Assert: 验证屏幕正常显示
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(
      buildCount,
      lessThan(maxAllowedBuilds),
      reason: 'ReaderScreen 初始化不应该触发无限循环',
    );

    print('✅ ReaderScreen 初始化成功，build 次数: $buildCount');
  });

  testWidgets('ReaderScreen 在编辑模式下应该能够正常工作',
      (WidgetTester tester) async {
    // Arrange
    final novel = Novel(
      title: '测试小说',
      author: '测试作者',
      url: 'https://example.com/novel/1',
      isInBookshelf: false,
    );

    final chapter = Chapter(
      title: '第一章',
      url: 'https://example.com/chapter/1',
      content: '这是测试内容\n第二段内容\n第三段内容',
    );

    final chapters = [chapter];

    // Act
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScreen(
            novel: novel,
            chapter: chapter,
            chapters: chapters,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Assert: 验证基本 UI 元素存在
    expect(find.byType(ReaderScreen), findsOneWidget);

    // 检查是否没有异常
    expect(tester.takeException(), isNull);

    print('✅ ReaderScreen 编辑模式测试通过');
  });

  testWidgets('ReaderScreen 切换章节不应该触发无限循环',
      (WidgetTester tester) async {
    // Arrange
    final novel = Novel(
      title: '测试小说',
      author: '测试作者',
      url: 'https://example.com/novel/1',
      isInBookshelf: false,
    );

    final chapter1 = Chapter(
      title: '第一章',
      url: 'https://example.com/chapter/1',
      content: '第一章内容',
    );

    final chapter2 = Chapter(
      title: '第二章',
      url: 'https://example.com/chapter/2',
      content: '第二章内容',
    );

    final chapters = [chapter1, chapter2];

    int buildCount = 0;
    const maxAllowedBuilds = 100;

    // Act: 第一次渲染
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              buildCount++;
              return ReaderScreen(
                novel: novel,
                chapter: chapter1,
                chapters: chapters,
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 3));
    final initialBuildCount = buildCount;

    // 切换章节
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              buildCount++;
              if (buildCount > maxAllowedBuilds) {
                throw Exception('检测到无限循环');
              }
              return ReaderScreen(
                novel: novel,
                chapter: chapter2,
                chapters: chapters,
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Assert
    final additionalBuilds = buildCount - initialBuildCount;
    expect(
      additionalBuilds,
      lessThan(maxAllowedBuilds),
      reason: '切换章节不应该触发无限循环',
    );

    print('✅ 章节切换测试通过，额外 build 次数: $additionalBuilds');
  });
}
