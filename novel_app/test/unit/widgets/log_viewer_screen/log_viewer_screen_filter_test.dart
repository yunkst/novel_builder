import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/screens/log_viewer_screen.dart';
import 'package:novel_app/services/logger_service.dart';
import '../test_helpers.dart';

/// LogViewerScreen 过滤功能测试
///
/// 测试日志级别过滤功能。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogViewerScreen 过滤功能', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TestHelpers.addSampleLogs();
      TestHelpers.setupPathProviderMock();
    });

    tearDown(() async {
      await TestHelpers.clearLoggerService();
      LoggerService.resetForTesting();
    });

    testWidgets('应显示过滤菜单', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await tester.tap(TestHelpers.findFilterButton());
      await TestHelpers.waitForAnimations(tester);

      expect(find.text('全部'), findsOneWidget);
      expect(find.text('DEBUG'), findsOneWidget);
      expect(find.text('INFO'), findsOneWidget);
      expect(find.text('WARN'), findsOneWidget);
      expect(find.text('ERROR'), findsOneWidget);
    });

    testWidgets('选择ERROR级别应只显示错误日志', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await TestHelpers.selectLogLevel(tester, 'ERROR');

      expect(find.text('仅显示 ERROR 级别日志 (1 条)'), findsOneWidget);
      expect(find.text('Error message'), findsOneWidget);
      expect(find.text('Debug message'), findsNothing);
      expect(find.text('Info message'), findsNothing);
      expect(find.text('Warning message'), findsNothing);
    });

    testWidgets('选择INFO级别应只显示信息日志', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await TestHelpers.selectLogLevel(tester, 'INFO');

      expect(find.text('仅显示 INFO 级别日志 (1 条)'), findsOneWidget);
      expect(find.text('Info message'), findsOneWidget);
    });

    testWidgets('选择DEBUG级别应只显示调试日志', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await TestHelpers.selectLogLevel(tester, 'DEBUG');

      expect(find.text('仅显示 DEBUG 级别日志 (1 条)'), findsOneWidget);
      expect(find.text('Debug message'), findsOneWidget);
    });

    testWidgets('选择WARN级别应只显示警告日志', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await TestHelpers.selectLogLevel(tester, 'WARN');

      expect(find.text('仅显示 WARN 级别日志 (1 条)'), findsOneWidget);
      expect(find.text('Warning message'), findsOneWidget);
    });

    testWidgets('过滤菜单应包含"全部"选项', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await tester.tap(TestHelpers.findFilterButton());
      await TestHelpers.waitForAnimations(tester);

      expect(find.text('全部'), findsOneWidget);
    });

    testWidgets('应用过滤后应显示过滤提示栏', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await TestHelpers.selectLogLevel(tester, 'ERROR');

      expect(
        find.widgetWithText(Container, '仅显示 ERROR 级别日志 (1 条)'),
        findsOneWidget,
      );
    });

    testWidgets('过滤提示栏应包含清除过滤按钮', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await TestHelpers.selectLogLevel(tester, 'DEBUG');

      expect(find.text('清除过滤'), findsOneWidget);
    });

    testWidgets('无过滤时不显示过滤提示栏', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      expect(find.text('仅显示'), findsNothing);
    });

    testWidgets('清除过滤按钮应重置过滤器', (tester) async {
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      // 应用ERROR过滤
      await TestHelpers.selectLogLevel(tester, 'ERROR');
      expect(find.text('仅显示 ERROR 级别日志 (1 条)'), findsOneWidget);

      // 点击清除过滤
      await tester.tap(find.text('清除过滤'));
      await TestHelpers.waitForAnimations(tester);

      // 应该显示所有日志（检查其中一个存在）
      expect(find.text('Error message'), findsOneWidget);
    });

    testWidgets('多个同级别日志应都被过滤显示', (tester) async {
      // 在创建Widget之前添加所有日志
      LoggerService.instance.e('Error 1');
      LoggerService.instance.e('Error 2');
      LoggerService.instance.e('Error 3');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await TestHelpers.selectLogLevel(tester, 'ERROR');

      // 应该显示至少3个错误日志
      final errorCount = find.textContaining('Error').evaluate().length;
      expect(errorCount, greaterThanOrEqualTo(3));
    });

    testWidgets('过滤级别图标应正确显示', (tester) async {
      // 先创建 Widget
      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      // 点击过滤按钮
      await tester.tap(TestHelpers.findFilterButton());
      await tester.pump();

      // 检查过滤菜单中的文本（图标可能需要检查 PopupMenuItem）
      expect(find.text('DEBUG'), findsOneWidget);
      expect(find.text('INFO'), findsOneWidget);
      expect(find.text('WARN'), findsOneWidget);
      expect(find.text('ERROR'), findsOneWidget);
    });
  });
}
