import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_bootstrap.dart';

/// Widget测试基类
///
/// 提供Widget测试的通用辅助方法
/// 所有Widget测试都应该继承此类
///
/// 使用示例：
/// ```dart
/// class MyWidgetTest extends WidgetTestBase {
///   @override
///   Widget createTestWidget() {
///     return MyWidget();
///   }
/// }
/// ```
abstract class WidgetTestBase {
  /// 创建要测试的Widget
  ///
  /// 子类必须实现此方法
  Widget createTestWidget();

  /// 构建并pump Widget
  ///
  /// 在测试中调用此方法来构建Widget
  Future<void> pumpWidget(
    WidgetTester tester, {
    Duration duration = const Duration(milliseconds: 100),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: createTestWidget(),
      ),
    );

    // 等待Widget完成构建
    await tester.pump(duration);
  }

  /// 等待异步操作完成
  ///
  /// 用于处理异步Widget的加载
  Future<void> waitForAsync({
    int pumpCount = 3,
    Duration duration = const Duration(milliseconds: 100),
  }) async {
    for (int i = 0; i < pumpCount; i++) {
      await Future.delayed(duration);
    }
  }

  /// 查找并点击文本
  ///
  /// 辅助方法：查找包含特定文本的Widget并点击
  Future<void> tapText(
    WidgetTester tester,
    String text, {
    bool skipOffstage = true,
  }) async {
    final finder = find.text(text, skipOffstage: skipOffstage);
    expect(finder, findsOneWidget, reason: '应该找到文本: $text');
    await tester.tap(finder);
  }

  /// 查找并点击图标
  ///
  /// 辅助方法：查找特定图标并点击
  Future<void> tapIcon(
    WidgetTester tester,
    IconData icon, {
    bool skipOffstage = true,
  }) async {
    final finder = find.byIcon(icon, skipOffstage: skipOffstage);
    expect(finder, findsOneWidget, reason: '应该找到图标');
    await tester.tap(finder);
  }

  /// 验证Widget存在
  ///
  /// 辅助方法：验证特定类型的Widget存在
  void expectWidgetExists<T extends Widget>({
    int count = 1,
  }) {
    expect(
      find.byType(T),
      findsNWidgets(count),
      reason: '应该找到 $count 个 ${T.toString()}',
    );
  }

  /// 验证文本存在
  ///
  /// 辅助方法：验证特定文本存在
  void expectTextExists(
    String text, {
    int count = 1,
    bool skipOffstage = true,
  }) {
    expect(
      find.text(text, skipOffstage: skipOffstage),
      findsNWidgets(count),
      reason: '应该找到文本: $text',
    );
  }

  /// 输入文本到TextField
  ///
  /// 辅助方法：向TextField输入文本
  Future<void> enterText(
    WidgetTester tester,
    String text, {
    Key? key,
    bool skipOffstage = true,
  }) async {
    final finder = key != null
        ? find.byKey(key, skipOffstage: skipOffstage)
        : find.byType(TextField, skipOffstage: skipOffstage);

    await tester.enterText(finder, text);
  }
}
