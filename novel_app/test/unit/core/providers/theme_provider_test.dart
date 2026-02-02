import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/core/providers/theme_provider.dart';

void main() {
  // 测试前初始化 Flutter 绑定
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider', () {
    late ProviderContainer container;

    setUp(() async {
      // 在每次测试前设置 SharedPreferences 模拟
      SharedPreferences.setMockInitialValues({});

      // 创建新的 ProviderContainer
      container = ProviderContainer();
    });

    tearDown(() {
      // 清理容器
      container.dispose();
    });

    /// 测试默认主题模式为暗色
    test('should load dark theme by default', () async {
      // 读取主题状态
      final themeAsync = container.read(themeNotifierProvider.future);

      final themeState = await themeAsync;

      expect(themeState.themeMode, AppThemeMode.dark);
      expect(themeState.seedColor, isNotNull);
    });

    /// 测试保存和加载主题模式
    test('should save and load theme mode', () async {
      // 获取 notifier
      final notifier = container.read(themeNotifierProvider.notifier);

      // 设置为亮色模式
      await notifier.setLightMode();

      // 等待状态更新
      final themeState = await container.read(themeNotifierProvider.future);

      expect(themeState.themeMode, AppThemeMode.light);
    });

    /// 测试主题模式切换
    test('should toggle between light and dark mode', () async {
      final notifier = container.read(themeNotifierProvider.notifier);

      // 切换主题
      await notifier.toggleTheme();

      var themeState = await container.read(themeNotifierProvider.future);

      // 应该从默认暗色切换到亮色
      expect(themeState.themeMode, AppThemeMode.light);

      // 再次切换
      await notifier.toggleTheme();

      themeState = await container.read(themeNotifierProvider.future);

      // 应该从亮色切换回暗色
      expect(themeState.themeMode, AppThemeMode.dark);
    });

    /// 测试设置系统主题模式
    test('should set system theme mode', () async {
      final notifier = container.read(themeNotifierProvider.notifier);

      await notifier.setSystemMode();

      final themeState = await container.read(themeNotifierProvider.future);

      expect(themeState.themeMode, AppThemeMode.system);
    });

    /// 测试 Flutter ThemeMode 转换
    test('should convert AppThemeMode to Flutter ThemeMode', () {
      final lightState = ThemeState(themeMode: AppThemeMode.light);
      expect(lightState.flutterThemeMode, ThemeMode.light);

      final darkState = ThemeState(themeMode: AppThemeMode.dark);
      expect(darkState.flutterThemeMode, ThemeMode.dark);

      final systemState = ThemeState(themeMode: AppThemeMode.system);
      expect(systemState.flutterThemeMode, ThemeMode.system);
    });

    /// 测试生成亮色主题
    test('should generate light theme', () {
      final themeState = ThemeState(themeMode: AppThemeMode.light);

      final lightTheme = themeState.getLightTheme();

      expect(lightTheme, isNotNull);
      expect(lightTheme.useMaterial3, isTrue);
      expect(lightTheme.colorScheme.brightness, Brightness.light);
    });

    /// 测试生成暗色主题
    test('should generate dark theme', () {
      final themeState = ThemeState(themeMode: AppThemeMode.dark);

      final darkTheme = themeState.getDarkTheme();

      expect(darkTheme, isNotNull);
      expect(darkTheme.useMaterial3, isTrue);
      expect(darkTheme.colorScheme.brightness, Brightness.dark);
    });

    /// 测试 ThemeState 相等性
    test('should compare ThemeState correctly', () {
      final state1 = ThemeState(themeMode: AppThemeMode.light);
      final state2 = ThemeState(themeMode: AppThemeMode.light);
      final state3 = ThemeState(themeMode: AppThemeMode.dark);

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    /// 测试 ThemeState copyWith
    test('should copy ThemeState with new values', () {
      final original = ThemeState(themeMode: AppThemeMode.light);
      final copy = original.copyWith(themeMode: AppThemeMode.dark);

      expect(original.themeMode, AppThemeMode.light);
      expect(copy.themeMode, AppThemeMode.dark);
      expect(original.seedColor, equals(copy.seedColor));
    });

    /// 测试 keepAlive
    test('should keep state alive', () async {
      // 第一次读取
      final state1 = await container.read(themeNotifierProvider.future);

      // 模拟没有其他监听者
      // 状态应该仍然存在，因为我们使用了 ref.keepAlive()

      // 再次读取
      final state2 = await container.read(themeNotifierProvider.future);

      // 应该是同一个状态实例
      expect(identical(state1, state2), isTrue);
    });
  });

  group('ThemeProvider Integration', () {
    late ProviderContainer container;

    setUp(() async {
      // 在每次测试前设置 SharedPreferences 模拟
      SharedPreferences.setMockInitialValues({});

      // 创建新的 ProviderContainer
      container = ProviderContainer();
    });

    tearDown(() {
      // 清理容器
      container.dispose();
    });

    /// 测试完整的主题切换流程
    test('should complete full theme switching flow', () async {
      final notifier = container.read(themeNotifierProvider.notifier);

      // 测试所有主题模式
      await notifier.setLightMode();
      expect((await container.read(themeNotifierProvider.future)).themeMode, AppThemeMode.light);

      await notifier.setDarkMode();
      expect((await container.read(themeNotifierProvider.future)).themeMode, AppThemeMode.dark);

      await notifier.setSystemMode();
      expect((await container.read(themeNotifierProvider.future)).themeMode, AppThemeMode.system);
    });

    /// 测试主题模式持久化
    test('should persist theme mode changes', () async {
      final notifier = container.read(themeNotifierProvider.notifier);

      // 设置主题模式
      await notifier.setLightMode();

      // 创建一个新的容器来模拟应用重启
      final newContainer = ProviderContainer();

      // 新容器应该加载相同的主题设置
      final newThemeState = await newContainer.read(themeNotifierProvider.future);

      expect(newThemeState.themeMode, AppThemeMode.light);

      newContainer.dispose();
    });
  });
}
