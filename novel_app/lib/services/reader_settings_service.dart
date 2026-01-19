import 'package:shared_preferences/shared_preferences.dart';

/// 阅读器设置服务
///
/// 负责管理阅读器的用户偏好设置持久化
class ReaderSettingsService {
  // ========== 单例模式 ==========
  static ReaderSettingsService? _instance;
  static ReaderSettingsService get instance {
    _instance ??= ReaderSettingsService._();
    return _instance!;
  }

  ReaderSettingsService._();

  // ========== SharedPreferences 键常量 ==========
  static const String _keyFontSize = 'reader_font_size';
  static const String _keyScrollSpeed = 'reader_scroll_speed';

  // ========== 默认值常量 ==========
  static const double _defaultFontSize = 18.0;
  static const double _defaultScrollSpeed = 1.0;

  // ========== 公开方法 ==========

  /// 获取字体大小
  Future<double> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyFontSize) ?? _defaultFontSize;
  }

  /// 设置字体大小
  Future<void> setFontSize(double fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, fontSize);
  }

  /// 获取滚动速度
  Future<double> getScrollSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyScrollSpeed) ?? _defaultScrollSpeed;
  }

  /// 设置滚动速度
  Future<void> setScrollSpeed(double scrollSpeed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyScrollSpeed, scrollSpeed);
  }

  /// 重置所有设置为默认值
  Future<void> resetToDefaults() async {
    await setFontSize(_defaultFontSize);
    await setScrollSpeed(_defaultScrollSpeed);
  }
}
