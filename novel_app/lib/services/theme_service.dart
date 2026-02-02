import 'package:flutter/material.dart' as flutter;
import 'package:flutter/material.dart';
import 'preferences_service.dart';

/// 应用主题模式枚举
enum AppThemeMode {
  light, // 亮色模式
  dark, // 暗色模式
  system, // 跟随系统
}

/// 主题服务 - 管理应用主题配置和持久化
class ThemeService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static ThemeService? _instance;

  // 主题模式
  AppThemeMode _themeMode = AppThemeMode.dark;

  // 种子颜色
  final Color _seedColor = Colors.blue;

  // Preferences 服务实例
  static final PreferencesService _prefs = PreferencesService();

  /// 私有构造函数
  ThemeService._();

  /// 获取单例实例
  static ThemeService get instance {
    _instance ??= ThemeService._();
    return _instance!;
  }

  /// 初始化 - 从Preferences加载主题设置
  Future<void> init() async {
    try {
      final themeModeString = await _prefs.getString(_themeModeKey);

      if (themeModeString.isNotEmpty) {
        _themeMode = AppThemeMode.values.firstWhere(
          (mode) => mode.toString() == themeModeString,
          orElse: () => AppThemeMode.dark,
        );
        print('已加载主题模式: $_themeMode');
      } else {
        // 默认暗色主题
        _themeMode = AppThemeMode.dark;
        print('使用默认主题模式: $_themeMode');
      }

      notifyListeners();
    } catch (e) {
      print('初始化主题设置失败: $e');
      _themeMode = AppThemeMode.dark;
    }
  }

  /// 获取当前主题模式
  AppThemeMode get themeMode => _themeMode;

  /// 获取Flutter的ThemeMode（用于MaterialApp）
  flutter.ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return flutter.ThemeMode.light;
      case AppThemeMode.dark:
        return flutter.ThemeMode.dark;
      case AppThemeMode.system:
        return flutter.ThemeMode.system;
    }
  }

  /// 获取种子颜色
  Color get seedColor => _seedColor;

  /// 设置主题模式
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;

    try {
      await _prefs.setString(_themeModeKey, mode.toString());

      _themeMode = mode;
      print('主题模式已更改: $mode');
      notifyListeners();
    } catch (e) {
      print('保存主题模式失败: $e');
      rethrow;
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
    if (_themeMode == AppThemeMode.light) {
      await setDarkMode();
    } else if (_themeMode == AppThemeMode.dark) {
      await setLightMode();
    } else {
      // 系统模式下，切换到亮色
      await setLightMode();
    }
  }

  /// 生成亮色主题数据
  ThemeData getLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
  }

  /// 生成暗色主题数据
  ThemeData getDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }
}
