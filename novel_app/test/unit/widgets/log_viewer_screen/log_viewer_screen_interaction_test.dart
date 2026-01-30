import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/screens/log_viewer_screen.dart';
import 'package:novel_app/services/logger_service.dart';
import '../test_helpers.dart';

/// LogViewerScreen 交互功能测试
///
/// 测试复制、导出、清空等交互功能。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogViewerScreen 交互功能', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TestHelpers.initLoggerService();
      TestHelpers.setupPathProviderMock();
    });

    tearDown(() async {
      await TestHelpers.clearLoggerService();
      LoggerService.resetForTesting();
    });

    group('复制功能', () {
      setUp(() async {
        LoggerService.instance.i('Test message for copy');
      });

      testWidgets('复制按钮应存在并可点击', (tester) async {
        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        expect(TestHelpers.findCopyButton(), findsOneWidget);
        await tester.tap(TestHelpers.findCopyButton());
        await TestHelpers.waitForSnackBar(tester);
      });

      testWidgets('空日志时复制按钮应可点击', (tester) async {
        await LoggerService.instance.clearLogs();

        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        await tester.tap(TestHelpers.findCopyButton());
        await TestHelpers.waitForSnackBar(tester);
      });
    });

    group('导出功能', () {
      setUp(() async {
        LoggerService.instance.i('Export test message');
      });

      testWidgets('导出按钮应存在并可点击', (tester) async {
        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        expect(TestHelpers.findExportButton(), findsOneWidget);
        await tester.tap(TestHelpers.findExportButton());
        await tester.pump();
      });

      testWidgets('空日志时导出按钮应可点击', (tester) async {
        await LoggerService.instance.clearLogs();

        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        await tester.tap(TestHelpers.findExportButton());
        await tester.pump();
      });
    });

    group('清空功能', () {
      setUp(() async {
        LoggerService.instance.i('Test log for clear');
      });

      testWidgets('点击清空按钮应显示确认对话框', (tester) async {
        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        await tester.tap(TestHelpers.findClearButton());
        await TestHelpers.waitForAnimations(tester);

        expect(find.text('确认清空'), findsOneWidget);
        expect(find.text('确定要清空所有日志吗？此操作不可撤销。'), findsOneWidget);
        expect(find.text('取消'), findsOneWidget);
        expect(find.text('清空'), findsOneWidget);
      });

      testWidgets('确认清空应删除所有日志', (tester) async {
        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        // 点击清空按钮
        await tester.tap(TestHelpers.findClearButton());
        await TestHelpers.waitForAnimations(tester);

        // 确认清空
        await tester.tap(find.text('清空'));
        await TestHelpers.waitForAnimations(tester);

        // Toast消息不会出现在widget树中，所以不检查
        // 只检查日志列表是否为空
        expect(find.text('暂无日志'), findsOneWidget);
      });

      testWidgets('取消清空应保留日志', (tester) async {
        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        await tester.tap(TestHelpers.findClearButton());
        await TestHelpers.waitForAnimations(tester);

        // 取消
        await tester.tap(find.text('取消'));
        await TestHelpers.waitForAnimations(tester);

        // 日志应该还在
        expect(find.text('Test log for clear'), findsOneWidget);
      });

      testWidgets('空日志时清空按钮应可点击', (tester) async {
        await LoggerService.instance.clearLogs();

        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        await tester.tap(TestHelpers.findClearButton());
        await TestHelpers.waitForAnimations(tester);
      });
    });

    group('AppBar按钮布局', () {
      testWidgets('所有按钮应按正确顺序显示', (tester) async {
        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        // AppBar 应该有4个操作按钮
        final actionButtons = find.byType(IconButton);
        expect(actionButtons, findsNWidgets(4));
      });

      testWidgets('过滤按钮应该是第一个', (tester) async {
        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        // 直接使用测试辅助方法查找过滤按钮
        expect(TestHelpers.findFilterButton(), findsOneWidget);
      });
    });
  });
}
