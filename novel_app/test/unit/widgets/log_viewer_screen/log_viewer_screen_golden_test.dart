import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/screens/log_viewer_screen.dart';
import 'package:novel_app/services/logger_service.dart';
import '../test_helpers.dart';

/// LogViewerScreen Golden 测试
///
/// 使用 Golden 测试进行 UI 回归测试。
/// Golden 测试通过对比截图来检测 UI 变化。
///
/// 运行方式：
/// ```bash
/// # 更新 Golden 文件
/// flutter test --update-goldens
///
/// # 运行 Golden 测试
/// flutter test test/unit/widgets/log_viewer_screen/log_viewer_screen_golden_test.dart
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogViewerScreen Golden 测试', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await TestHelpers.initLoggerService();
      TestHelpers.setupPathProviderMock();
    });

    tearDown(() async {
      await TestHelpers.clearLoggerService();
      LoggerService.resetForTesting();
    });

    group('基础 UI Golden 测试', () {
      testWidgets('空状态 Golden 测试', (tester) async {
        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        await expectLater(
          find.byType(LogViewerScreen),
          matchesGoldenFile('goldens/log_viewer_empty_state.png'),
        );
      });

      testWidgets('有日志状态 Golden 测试', (tester) async {
        LoggerService.instance.i('Info message');
        LoggerService.instance.e('Error message');

        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await expectLater(
          find.byType(LogViewerScreen),
          matchesGoldenFile('goldens/log_viewer_with_logs.png'),
        );
      });

      testWidgets('不同级别日志颜色 Golden 测试', (tester) async {
        LoggerService.instance.d('Debug message');
        LoggerService.instance.i('Info message');
        LoggerService.instance.w('Warning message');
        LoggerService.instance.e('Error message');

        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await expectLater(
          find.byType(LogViewerScreen),
          matchesGoldenFile('goldens/log_viewer_log_levels.png'),
        );
      });
    });

    group('过滤状态 Golden 测试', () {
      testWidgets('ERROR 过滤状态 Golden 测试', (tester) async {
        await TestHelpers.addSampleLogs();

        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        // 应用 ERROR 过滤
        await TestHelpers.selectLogLevel(tester, 'ERROR');

        await expectLater(
          find.byType(LogViewerScreen),
          matchesGoldenFile('goldens/log_viewer_filtered_error.png'),
        );
      });

      testWidgets('过滤提示栏 Golden 测试', (tester) async {
        await TestHelpers.addSampleLogs();

        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        await TestHelpers.selectLogLevel(tester, 'DEBUG');

        await expectLater(
          find.byType(LogViewerScreen),
          matchesGoldenFile('goldens/log_viewer_filter_bar.png'),
        );
      });
    });

    group('对话框 Golden 测试', () {
      testWidgets('堆栈信息对话框 Golden 测试', (tester) async {
        TestHelpers.addErrorLogWithStack(
          'Error with stack',
          'Error at function1()\n  at function2() line 10\n  at main() line 100',
        );

        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        await tester.tap(find.text('查看堆栈信息'));
        await TestHelpers.waitForAnimations(tester);

        await expectLater(
          find.byType(AlertDialog),
          matchesGoldenFile('goldens/log_viewer_stack_dialog.png'),
        );
      });

      testWidgets('清空确认对话框 Golden 测试', (tester) async {
        LoggerService.instance.i('Test log');

        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        await tester.tap(TestHelpers.findClearButton());
        await TestHelpers.waitForAnimations(tester);

        await expectLater(
          find.byType(AlertDialog),
          matchesGoldenFile('goldens/log_viewer_clear_dialog.png'),
        );
      });

      testWidgets('过滤菜单 Golden 测试', (tester) async {
        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await TestHelpers.waitForAnimations(tester);

        await tester.tap(TestHelpers.findFilterButton());
        await TestHelpers.waitForAnimations(tester);

        // 菜单Golden测试跳过 - PopupMenu难以捕获为Golden文件
      }, skip: true);
    });

    group('大量日志 Golden 测试', () {
      testWidgets('多日志滚动状态 Golden 测试', (tester) async {
        TestHelpers.addMultipleLogs(20);

        await tester.pumpWidget(
          TestHelpers.makeTestableWidget(const LogViewerScreen()),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await expectLater(
          find.byType(LogViewerScreen),
          matchesGoldenFile('goldens/log_viewer_multiple_logs.png'),
        );
      });
    });

    group('主题适配 Golden 测试', () {
      testWidgets('深色主题 Golden 测试', (tester) async {
        LoggerService.instance.i('Test message');

        await tester.pumpWidget(
          MaterialApp(
            home: const LogViewerScreen(),
            theme: ThemeData.dark(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await expectLater(
          find.byType(LogViewerScreen),
          matchesGoldenFile('goldens/log_viewer_dark_theme.png'),
        );
      });
    });
  });
}
