import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/services/logger_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// 测试辅助工具类
///
/// 提供通用的测试辅助方法，减少重复代码。
class TestHelpers {
  // ========== Widget 构建辅助 ==========

  /// 创建测试用的 MaterialApp 包装器
  ///
  /// 使用统一的测试配置，确保测试一致性。
  static Widget makeTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
      theme: ThemeData.light(),
      debugShowCheckedModeBanner: false,
    );
  }

  /// 创建带 Navigator 的测试 Widget
  ///
  /// 用于需要导航功能的测试场景。
  static Widget makeTestableWidgetWithNavigator(Widget child) {
    return MaterialApp(
      home: child,
      theme: ThemeData.light(),
      debugShowCheckedModeBanner: false,
      // 添加 Navigator 支持
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => child,
        );
      },
    );
  }

  // ========== LoggerService 测试辅助 ==========

  /// 初始化并重置 LoggerService
  ///
  /// 确保每个测试开始时 LoggerService 处于干净状态。
  static Future<void> initLoggerService() async {
    // 清除 SharedPreferences 中的旧数据
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // 重置并初始化 LoggerService
    LoggerService.resetForTesting();
    await LoggerService.instance.init();
  }

  /// 清空 LoggerService 中的所有日志
  static Future<void> clearLoggerService() async {
    await LoggerService.instance.clearLogs();
  }

  /// 添加测试日志数据
  ///
  /// 快速添加一组标准的测试日志。
  static Future<void> addSampleLogs() async {
    await initLoggerService();
    LoggerService.instance.d('Debug message');
    LoggerService.instance.i('Info message');
    LoggerService.instance.w('Warning message');
    LoggerService.instance.e('Error message');
  }

  /// 添加带堆栈信息的错误日志
  static void addErrorLogWithStack(String message, String stackTrace) {
    LoggerService.instance.e(message, stackTrace: stackTrace);
  }

  /// 添加指定数量的测试日志
  ///
  /// 用于测试大量日志场景。
  static void addMultipleLogs(int count) {
    for (int i = 0; i < count; i++) {
      LoggerService.instance.i('Test log message $i');
    }
  }

  /// 添加超长消息日志
  ///
  /// 用于测试超长文本显示。
  static void addLongMessageLog(int length) {
    final longMessage = 'A' * length;
    LoggerService.instance.i(longMessage);
  }

  // ========== 查找器辅助 ==========

  /// 查找 AppBar 中的过滤按钮
  ///
  /// 注意：过滤按钮是 PopupMenuButton，不是 IconButton
  static Finder findFilterButton() {
    return find.byType(PopupMenuButton<LogLevel?>);
  }

  /// 查找 AppBar 中的导出按钮
  static Finder findExportButton() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is IconButton &&
          widget.icon is Icon &&
          (widget.icon as Icon).icon == Icons.file_download,
    );
  }

  /// 查找 AppBar 中的复制按钮
  static Finder findCopyButton() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is IconButton &&
          widget.icon is Icon &&
          (widget.icon as Icon).icon == Icons.copy,
    );
  }

  /// 查找 AppBar 中的清空按钮
  static Finder findClearButton() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is IconButton &&
          widget.icon is Icon &&
          (widget.icon as Icon).icon == Icons.delete_outline,
    );
  }

  /// 查找日志级别的图标
  static Finder findLogLevelIcon(LogLevel level) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is Icon &&
          widget.icon == level.icon &&
          widget.color != null, // 确保有颜色设置
    );
  }

  /// 查找指定消息的日志卡片
  static Finder findLogCard(String message) {
    return find.descendant(
      of: find.byType(Card),
      matching: find.text(message),
    );
  }

  // ========== 交互辅助 ==========

  /// 点击过滤菜单中的指定级别
  ///
  /// 封装打开过滤菜单并选择级别的常用操作。
  static Future<void> selectLogLevel(WidgetTester tester, String level) async {
    await tester.tap(findFilterButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text(level));
    await tester.pumpAndSettle();
  }

  /// 等待 SnackBar 显示
  ///
  /// 使用 pump 而不是 pumpAndSettle 避免超时。
  static Future<void> waitForSnackBar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 等待动画完成
  ///
  /// 用于需要等待动画场景的简化调用。
  static Future<void> waitForAnimations(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  // ========== PathProvider Mock ==========

  /// 设置 PathProvider Mock
  ///
  /// 为需要文件系统访问的测试配置 Mock。
  static void setupPathProviderMock() {
    PathProviderPlatform.instance = FakePathProviderPlatform();
  }
}

/// Fake PathProviderPlatform for testing
class FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String> getApplicationDocumentsDirectory() async {
    return '/tmp/test_app_documents';
  }
}
