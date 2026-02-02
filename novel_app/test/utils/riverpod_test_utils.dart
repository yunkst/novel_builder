import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Riverpod 测试辅助类
///
/// 提供测试 Riverpod Provider 和 Widget 的工具方法
class RiverpodTestUtils {
  /// 创建测试用的 ProviderContainer
  ///
  /// [overrides] Provider 覆盖列表，用于注入 Mock 对象
  ///
  /// 返回一个配置好的 ProviderContainer 实例
  ///
  /// 使用示例:
  /// ```dart
  /// test('should create service', () {
  ///   final container = RiverpodTestUtils.createContainer();
  ///   final service = container.read(myServiceProvider);
  ///   expect(service, isA<MyService>());
  /// });
  /// ```
  static ProviderContainer createContainer({
    List<Override> overrides = const [],
  }) {
    return ProviderContainer(overrides: overrides);
  }

  /// 包装 Widget 为 ProviderScope
  ///
  /// [child] 要包装的 Widget
  /// [overrides] Provider 覆盖列表，用于注入 Mock 对象
  ///
  /// 返回一个包含 ProviderScope 的 Widget
  ///
  /// 使用示例:
  /// ```dart
  /// testWidgets('test widget', (tester) async {
  ///   await tester.pumpWidget(
  ///     MaterialApp(
  ///       home: RiverpodTestUtils.wrapWithProviders(MyWidget()),
  ///     ),
  ///   );
  /// });
  /// ```
  static Widget wrapWithProviders(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return UncontrolledProviderScope(
      container: createContainer(overrides: overrides),
      child: child,
    );
  }

  /// 在测试环境中运行 Widget 测试
  ///
  /// [tester] WidgetTester 实例
  /// [widget] 要测试的 Widget
  /// [overrides] Provider 覆盖列表，用于注入 Mock 对象
  ///
  /// 使用示例:
  /// ```dart
  /// testWidgets('test widget', (tester) async {
  ///   await RiverpodTestUtils.pumpWidgetWithProviders(
  ///     tester,
  ///     MyWidget(),
  ///   );
  ///   expect(find.byType(MyWidget), findsOneWidget);
  /// });
  /// ```
  static Future<void> pumpWidgetWithProviders(
    WidgetTester tester,
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: wrapWithProviders(widget, overrides: overrides),
      ),
    );
  }

  /// 创建带有 Mock Provider 的 ProviderScope
  ///
  /// [child] 要包装的 Widget
  /// [providers] 要覆盖的 Provider 映射
  ///
  /// 返回一个 ProviderScope Widget
  ///
  /// 使用示例:
  /// ```dart
  /// final mockRepo = MockNovelRepository();
  /// when(mockRepo.getNovels()).thenAnswer((_) async => []);
  ///
  /// testWidgets('test widget', (tester) async {
  ///   await tester.pumpWidget(
  ///     MaterialApp(
  ///       home: RiverpodTestUtils.providerScopeWithMocks(
  ///         MyWidget(),
  ///         [novelRepositoryProvider.overrideWithValue(mockRepo)],
  ///       ),
  ///     ),
  ///   );
  /// });
  /// ```
  static Widget providerScopeWithMocks(
    Widget child,
    List<Override> overrides,
  ) {
    return ProviderScope(
      overrides: overrides,
      child: child,
    );
  }

  /// 验证 Provider 是否正确创建
  ///
  /// [container] ProviderContainer 实例
  /// [provider] 要验证的 Provider
  /// [expectedType] 期望的类型
  ///
  /// 使用示例:
  /// ```dart
  /// test('should create logger service', () {
  ///   final container = RiverpodTestUtils.createContainer();
  ///   RiverpodTestUtils.verifyProvider(
  ///     container,
  ///     loggerServiceProvider,
  ///     LoggerService,
  ///   );
  /// });
  /// ```
  static void verifyProvider<T>(
    ProviderContainer container,
    ProviderBase<T> provider,
    Type expectedType,
  ) {
    final instance = container.read(provider);
    expect(instance, isA<T>());
    expect(instance.runtimeType, expectedType);
  }

  /// 在测试中读取 Provider 的值
  ///
  /// [container] ProviderContainer 实例
  /// [provider] 要读取的 Provider
  ///
  /// 返回 Provider 的当前值
  ///
  /// 使用示例:
  /// ```dart
  /// test('should return correct value', () {
  ///   final container = RiverpodTestUtils.createContainer();
  ///   final value = RiverpodTestUtils.readProvider(
  ///     container,
  ///     myProvider,
  ///   );
  ///   expect(value, equals('expected'));
  /// });
  /// ```
  static T readProvider<T>(
    ProviderContainer container,
    ProviderBase<T> provider,
  ) {
    return container.read(provider);
  }

  /// 监听 Provider 的变化
  ///
  /// [container] ProviderContainer 实例
  /// [provider] 要监听的 Provider
  /// [listener] 变化回调函数
  ///
  /// 返回一个订阅对象，调用 dispose 可取消监听
  ///
  /// 使用示例:
  /// ```dart
  /// test('should emit values', () {
  ///   final container = RiverpodTestUtils.createContainer();
  ///   final values = <int>[];
  ///
  ///   final subscription = RiverpodTestUtils.listenProvider(
  ///     container,
  ///     counterProvider,
  ///     (next) => values.add(next),
  ///   );
  ///
  ///   container.read(counterProvider.notifier).state++;
  ///   expect(values, equals([0, 1]));
  ///
  ///   subscription.close();
  /// });
  /// ```
  static ProviderSubscription<T> listenProvider<T>(
    ProviderContainer container,
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener,
  ) {
    return container.listen(provider, listener);
  }
}

/// Riverpod 测试扩展
///
/// 提供 WidgetTester 的扩展方法
extension RiverpodWidgetTesterExtension on WidgetTester {
  /// 使用 Provider 包装 Widget 并 pump
  ///
  /// [widget] 要测试的 Widget
  /// [overrides] Provider 覆盖列表
  ///
  /// 使用示例:
  /// ```dart
  /// testWidgets('test widget', (tester) async {
  ///   await tester.pumpWithProvider(MyWidget());
  ///   expect(find.byType(MyWidget), findsOneWidget);
  /// });
  /// ```
  Future<void> pumpWithProvider(
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      MaterialApp(
        home: ProviderScope(
          overrides: overrides,
          child: widget,
        ),
      ),
    );
  }
}

/// Riverpod 测试匹配器
///
/// 提供自定义的测试匹配器
class RiverpodMatchers {
  /// 验证 Provider 是否存在
  ///
  /// 使用示例:
  /// ```dart
  /// expect(
  ///   container.getAllProviders(),
  ///   RiverpodMatchers.containsProvider(loggerServiceProvider),
  /// );
  /// ```
  static Matcher containsProvider<T>(ProviderBase<T> provider) {
    return isA<ProviderBase<T>>().having(
      (p) => p.toString(),
      'provider',
      provider.toString(),
    );
  }
}

/// 测试用的 Mock Provider 创建助手
class MockProviderHelper {
  /// 创建一个 Mock Provider 覆盖
  ///
  /// [provider] 要覆盖的 Provider
  /// [mockInstance] Mock 实例
  ///
  /// 返回一个 Override 对象
  ///
  /// 使用示例:
  /// ```dart
  /// final mockRepo = MockNovelRepository();
  /// final override = MockProviderHelper.createOverride(
  ///   novelRepositoryProvider,
  ///   mockRepo,
  /// );
  ///
  /// final container = ProviderContainer(overrides: [override]);
  /// ```
  static Override createOverride<T>(
    ProviderBase<T> provider,
    T mockInstance,
  ) {
    return provider.overrideWithValue(mockInstance);
  }

  /// 批量创建 Mock Provider 覆盖
  ///
  /// [providers] Provider 和 Mock 实例的映射
  ///
  /// 返回 Override 列表
  ///
  /// 使用示例:
  /// ```dart
  /// final mockRepo = MockNovelRepository();
  /// final mockService = MockDatabaseService();
  ///
  /// final overrides = MockProviderHelper.createOverrides({
  ///   novelRepositoryProvider: mockRepo,
  ///   databaseServiceProvider: mockService,
  /// });
  ///
  /// final container = ProviderContainer(overrides: overrides);
  /// ```
  static List<Override> createOverrides(
    Map<ProviderBase, dynamic> providers,
  ) {
    return providers.entries
        .map((entry) => entry.key.overrideWithValue(entry.value))
        .toList();
  }
}
