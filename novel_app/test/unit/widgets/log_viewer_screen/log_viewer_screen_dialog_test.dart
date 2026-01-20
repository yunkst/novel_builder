import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/screens/log_viewer_screen.dart';
import 'package:novel_app/services/logger_service.dart';
import '../test_helpers.dart';

/// LogViewerScreen 对话框测试
///
/// 测试堆栈信息对话框功能。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogViewerScreen 对话框', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TestHelpers.initLoggerService();
      TestHelpers.setupPathProviderMock();
    });

    tearDown(() async {
      await TestHelpers.clearLoggerService();
      LoggerService.resetForTesting();
    });

    testWidgets('点击堆栈信息链接应显示对话框', (tester) async {
      TestHelpers.addErrorLogWithStack('Error with stack', 'Line 1\nLine 2');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await tester.tap(find.text('查看堆栈信息'));
      await TestHelpers.waitForAnimations(tester);

      expect(find.text('堆栈信息'), findsOneWidget);
      expect(find.text('Line 1\nLine 2'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
      expect(find.text('复制'), findsOneWidget);
    });

    testWidgets('对话框标题应包含日志级别图标', (tester) async {
      TestHelpers.addErrorLogWithStack('Error', 'Stack here');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await tester.tap(find.text('查看堆栈信息'));
      await TestHelpers.waitForAnimations(tester);

      // 在 AlertDialog 内查找错误图标
      final alertDialog = find.byType(AlertDialog);
      expect(alertDialog, findsOneWidget);

      final errorIconInDialog = find.descendant(
        of: alertDialog,
        matching: find.byIcon(Icons.error_outline),
      );
      expect(errorIconInDialog, findsOneWidget);
    });

    testWidgets('复制堆栈按钮应工作', (tester) async {
      TestHelpers.addErrorLogWithStack('Error', 'Line 1\nLine 2');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await tester.tap(find.text('查看堆栈信息'));
      await TestHelpers.waitForAnimations(tester);

      await tester.tap(find.text('复制'));
      await TestHelpers.waitForAnimations(tester);

      expect(find.text('已复制堆栈信息'), findsOneWidget);
    });

    testWidgets('关闭按钮应关闭对话框', (tester) async {
      TestHelpers.addErrorLogWithStack('Warning', 'Warning stack');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await tester.tap(find.text('查看堆栈信息'));
      await TestHelpers.waitForAnimations(tester);

      expect(find.text('堆栈信息'), findsOneWidget);

      await tester.tap(find.text('关闭'));
      await TestHelpers.waitForAnimations(tester);

      expect(find.text('堆栈信息'), findsNothing);
    });

    testWidgets('警告级别对话框应显示警告图标', (tester) async {
      LoggerService.instance.w('Warning', stackTrace: 'Warning stack');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await tester.tap(find.text('查看堆栈信息'));
      await TestHelpers.waitForAnimations(tester);

      final alertDialog = find.byType(AlertDialog);
      final warningIconInDialog = find.descendant(
        of: alertDialog,
        matching: find.byIcon(Icons.warning_outlined),
      );
      expect(warningIconInDialog, findsOneWidget);
    });

    testWidgets('对话框应显示完整的堆栈信息', (tester) async {
      const longStack = 'Error at function1()\n'
          '  at function2() line 10\n'
          '  at function3() line 20\n'
          '  at main() line 100';

      TestHelpers.addErrorLogWithStack('Multi-line error', longStack);

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await tester.tap(find.text('查看堆栈信息'));
      await TestHelpers.waitForAnimations(tester);

      expect(find.text(longStack), findsOneWidget);
    });

    testWidgets('对话框应支持滚动查看长堆栈', (tester) async {
      final longStack = List.generate(50, (i) => 'Stack line $i').join('\n');
      TestHelpers.addErrorLogWithStack('Long stack', longStack);

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await tester.tap(find.text('查看堆栈信息'));
      await TestHelpers.waitForAnimations(tester);

      // 对话框内容应该是可滚动的
      final scrollView = find.byType(Scrollable);
      expect(scrollView, findsAtLeastNWidgets(1));
    });

    testWidgets('点击对话框外部应关闭对话框', (tester) async {
      TestHelpers.addErrorLogWithStack('Error', 'Stack');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      await tester.tap(find.text('查看堆栈信息'));
      await TestHelpers.waitForAnimations(tester);

      expect(find.byType(AlertDialog), findsOneWidget);

      // 点击对话框背景（Barrier）
      await tester.tapAt(const Offset(10, 10));
      await TestHelpers.waitForAnimations(tester);

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('多次打开和关闭对话框应正常工作', (tester) async {
      TestHelpers.addErrorLogWithStack('Error', 'Stack');

      await tester.pumpWidget(
        TestHelpers.makeTestableWidget(const LogViewerScreen()),
      );

      await TestHelpers.waitForAnimations(tester);

      // 第一次打开
      await tester.tap(find.text('查看堆栈信息'));
      await TestHelpers.waitForAnimations(tester);
      expect(find.byType(AlertDialog), findsOneWidget);

      // 关闭
      await tester.tap(find.text('关闭'));
      await TestHelpers.waitForAnimations(tester);
      expect(find.byType(AlertDialog), findsNothing);

      // 第二次打开
      await tester.tap(find.text('查看堆栈信息'));
      await TestHelpers.waitForAnimations(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
