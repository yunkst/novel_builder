import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/screens/log_viewer_screen.dart';
import 'package:novel_app/services/logger_service.dart';
import '../test_helpers.dart';

/// LogViewerScreen 基础渲染测试
///
/// 测试日志查看器的基础UI渲染功能。
void main() {
  // 初始化 Flutter 测试绑定
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogViewerScreen 基础渲染', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TestHelpers.initLoggerService();
      TestHelpers.setupPathProviderMock();
    });

    tearDown(() async {
      await TestHelpers.clearLoggerService();
      LoggerService.resetForTesting();
    });

    testWidgets('应正确渲染日志查看器', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      expect(find.text('应用日志'), findsOneWidget);
    });

    testWidgets('应显示过滤按钮', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      expect(TestHelpers.findFilterButton(), findsOneWidget);
    });

    testWidgets('应显示导出、复制、清空按钮', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      expect(TestHelpers.findExportButton(), findsOneWidget);
      expect(TestHelpers.findCopyButton(), findsOneWidget);
      expect(TestHelpers.findClearButton(), findsOneWidget);
    });

    testWidgets('无日志时应显示空状态', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      expect(find.text('暂无日志'), findsOneWidget);
      expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
    });

    testWidgets('应显示日志列表', (tester) async {
      LoggerService.instance.i('Test log message');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      expect(find.text('Test log message'), findsOneWidget);
    });

    testWidgets('应显示日志时间戳', (tester) async {
      LoggerService.instance.i('Test message');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      // 时间戳格式: YYYY-MM-DD HH:mm:ss
      final finder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(widget.data!),
      );

      expect(finder, findsAtLeastNWidgets(1));
    });

    testWidgets('应显示日志级别图标', (tester) async {
      LoggerService.instance.i('Info log');
      LoggerService.instance.e('Error log');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      expect(TestHelpers.findLogLevelIcon(LogLevel.info), findsOneWidget);
      expect(TestHelpers.findLogLevelIcon(LogLevel.error), findsOneWidget);
    });

    testWidgets('有堆栈信息的日志应显示查看链接', (tester) async {
      TestHelpers.addErrorLogWithStack('Error with stack', 'Stack line 1\nStack line 2');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      expect(find.text('查看堆栈信息'), findsOneWidget);
    });

    testWidgets('日志应以Card形式显示', (tester) async {
      LoggerService.instance.i('Test message');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('日志应使用等宽字体', (tester) async {
      LoggerService.instance.i('Test message');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      final messageText = find.text('Test message');
      final textStyle = tester.widget<Text>(messageText).style;
      expect(textStyle?.fontFamily, 'monospace');
    });

    testWidgets('应支持倒序显示（最新日志在最上方）', (tester) async {
      LoggerService.instance.i('First');
      LoggerService.instance.i('Second');
      LoggerService.instance.i('Third');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final cards = find.byType(Card);
      expect(cards, findsNWidgets(3));

      // 第一个Card应该是最后一条日志（Third）
      final firstText = find.descendant(
        of: cards.first,
        matching: find.text('Third'),
      );
      expect(firstText, findsOneWidget);
    });
  });
}
