/// Riverpod Theme Provider
///
/// 管理应用主题状态，支持亮色/暗色/跟随系统三种模式
/// 使用 @riverpod 注解自动生成代码
library;

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../services/preferences_service.dart';

part 'theme_provider.g.dart';

/// 应用主题模式枚举
enum AppThemeMode {
  light, // 亮色模式
  dark, // 暗色模式
  system, // 跟随系统
}

/// 主题状态类
///
/// 包含当前主题模式和相关配置
class ThemeState {
  final AppThemeMode themeMode;
  final Color seedColor;

  const ThemeState({
    required this.themeMode,
    this.seedColor = Colors.blue,
  });

  /// 获取Flutter的ThemeMode（用于MaterialApp）
  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// 生成亮色主题数据
  ThemeData getLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
  }

  /// 生成暗色主题数据
  ThemeData getDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }

  /// 复制并修改状态
  ThemeState copyWith({AppThemeMode? themeMode, Color? seedColor}) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      seedColor: seedColor ?? this.seedColor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeState &&
          runtimeType == other.runtimeType &&
          themeMode == other.themeMode &&
          seedColor == other.seedColor;

  @override
  int get hashCode => themeMode.hashCode ^ seedColor.hashCode;
}

/// ThemeNotifier
///
/// 管理主题状态，支持主题切换和持久化
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  static const String _themeModeKey = 'theme_mode';

  /// 初始化主题状态
  ///
  /// 从 SharedPreferences 加载保存的主题设置
  @override
  Future<ThemeState> build() async {
    // 保持状态，不被自动销毁
    ref.keepAlive();

    // 获取 PreferencesService
    final prefs = PreferencesService.instance;

    try {
      final themeModeString = await prefs.getString(_themeModeKey);

      AppThemeMode themeMode;
      if (themeModeString.isNotEmpty) {
        themeMode = AppThemeMode.values.firstWhere(
          (mode) => mode.toString() == themeModeString,
          orElse: () => AppThemeMode.dark,
        );
      } else {
        // 默认暗色主题
        themeMode = AppThemeMode.dark;
      }

      return ThemeState(themeMode: themeMode);
    } catch (e) {
      // 发生错误时使用默认主题
      return const ThemeState(themeMode: AppThemeMode.dark);
    }
  }

  /// 设置主题模式
  Future<void> setThemeMode(AppThemeMode mode) async {
    // 如果主题没有变化，不做任何操作
    final current = await future;
    if (current.themeMode == mode) return;

    try {
      final prefs = PreferencesService.instance;

      // 保存到 SharedPreferences
      await prefs.setString(_themeModeKey, mode.toString());

      // 更新状态
      state = AsyncData(current.copyWith(themeMode: mode));
    } catch (e) {
      // 保存失败时抛出错误
      throw Exception('保存主题模式失败: $e');
    }
  }

  /// 切换到亮色模式
  Future<void> setLightMode() async {
    await setThemeMode(AppThemeMode.light);
  }

  /// 切换到暗色模式
  Future<void> setDarkMode() async {
    await setThemeMode(AppThemeMode.dark);
  }

  /// 切换到系统模式
  Future<void> setSystemMode() async {
    await setThemeMode(AppThemeMode.system);
  }

  /// 在亮色和暗色之间切换
  Future<void> toggleTheme() async {
    final current = await future;

    AppThemeMode newMode;
    if (current.themeMode == AppThemeMode.light) {
      newMode = AppThemeMode.dark;
    } else if (current.themeMode == AppThemeMode.dark) {
      newMode = AppThemeMode.light;
    } else {
      // 系统模式下，切换到亮色
      newMode = AppThemeMode.light;
    }

    await setThemeMode(newMode);
  }
}
