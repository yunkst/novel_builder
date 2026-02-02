import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/providers/theme_provider.dart';

void main() {
  group('ThemeState', () {
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

    /// 测试默认种子颜色
    test('should have default seed color', () {
      final themeState = ThemeState(themeMode: AppThemeMode.dark);

      expect(themeState.seedColor, Colors.blue);
    });
  });
}
