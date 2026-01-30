import 'package:flutter/material.dart' as flutter;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/services/theme_service.dart';

void main() {
  group('ThemeService Tests', () {
    late ThemeService themeService;

    setUp(() async {
      // 在每次测试前设置 SharedPreferences 模拟
      SharedPreferences.setMockInitialValues({});
      themeService = ThemeService.instance;
      await themeService.init();
    });

    test('初始化应该使用默认暗色主题', () async {
      expect(themeService.themeMode, AppThemeMode.dark);
      expect(themeService.flutterThemeMode, flutter.ThemeMode.dark);
    });

    test('应该能够切换到亮色模式', () async {
      await themeService.setLightMode();
      expect(themeService.themeMode, AppThemeMode.light);
      expect(themeService.flutterThemeMode, flutter.ThemeMode.light);
    });

    test('应该能够切换到系统模式', () async {
      await themeService.setSystemMode();
      expect(themeService.themeMode, AppThemeMode.system);
      expect(themeService.flutterThemeMode, flutter.ThemeMode.system);
    });

    test('toggleTheme 应该在亮色和暗色之间切换', () async {
      // 默认是暗色
      expect(themeService.themeMode, AppThemeMode.dark);

      // 切换到亮色
      await themeService.toggleTheme();
      expect(themeService.themeMode, AppThemeMode.light);

      // 切换回暗色
      await themeService.toggleTheme();
      expect(themeService.themeMode, AppThemeMode.dark);
    });

    test('应该能够持久化主题设置', () async {
      // 设置为亮色
      await themeService.setLightMode();

      // 创建新实例
      final newService = ThemeService.instance;
      await newService.init();

      // 应该保持之前的设置
      expect(newService.themeMode, AppThemeMode.light);
    });

    test('getLightTheme 应该返回亮色主题', () {
      final lightTheme = themeService.getLightTheme();
      expect(lightTheme.colorScheme.brightness, Brightness.light);
      expect(lightTheme.useMaterial3, true);
    });

    test('getDarkTheme 应该返回暗色主题', () {
      final darkTheme = themeService.getDarkTheme();
      expect(darkTheme.colorScheme.brightness, Brightness.dark);
      expect(darkTheme.useMaterial3, true);
    });

    test('setThemeMode 相同模式时不应触发更新', () async {
      final initialMode = themeService.themeMode;
      bool notified = false;

      themeService.addListener(() {
        notified = true;
      });

      await themeService.setThemeMode(initialMode);
      expect(notified, false);
    });

    test('setThemeMode 不同模式时应该触发更新', () async {
      bool notified = false;

      themeService.addListener(() {
        notified = true;
      });

      await themeService.setThemeMode(AppThemeMode.light);
      expect(notified, true);
    });
  });
}
