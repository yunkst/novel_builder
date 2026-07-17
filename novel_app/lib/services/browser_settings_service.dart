import 'preferences_service.dart';

/// 浏览器设置服务
///
/// 管理浏览器相关用户偏好的持久化（目前仅桌面模式开关）。
/// 单例 + SharedPreferences，范式同 [ReaderSettingsService]。
class BrowserSettingsService {
  // ========== 单例模式 ==========
  static BrowserSettingsService? _instance;
  static BrowserSettingsService get instance {
    _instance ??= BrowserSettingsService._();
    return _instance!;
  }

  BrowserSettingsService._();

  // ========== SharedPreferences 键常量 ==========
  static const String _keyDesktopMode = 'browser_desktop_mode';

  // ========== 默认值常量 ==========
  static const bool _defaultDesktopMode = false;

  // ========== 桌面模式 User-Agent ==========
  /// 桌面模式使用的 User-Agent（Windows Chrome 120）。
  /// 版本号不必追最新，服务器只看 Windows + Chrome 关键字。
  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// 桌面模式注入 JS：删除现有 viewport meta，强制插入桌面宽度 viewport。
  ///
  /// Android WebView 的 layout viewport 宽度由页面 viewport meta 决定。
  /// 移动端站点多用 `width=device-width`，导致 layout viewport 等于 WebView
  /// 物理像素宽，响应式断点（如 min-width: 1280）命中手机分支。本脚本在
  /// onLoadStop 后覆盖 viewport meta 为桌面宽，让站点识别为桌面并按 PC 版
  /// 渲染。注意：iOS 上 `preferredContentMode: DESKTOP` 已能处理，但注入
  /// 脚本跨平台无害，统一执行以保持行为一致。
  static const String desktopViewportOverrideJs = r'''
(function() {
  var metas = document.querySelectorAll('meta[name="viewport"]');
  metas.forEach(function(m) { m.remove(); });
  var meta = document.createElement('meta');
  meta.name = 'viewport';
  meta.content = 'width=1024, initial-scale=1.0';
  document.head.appendChild(meta);
})();
''';

  // ========== Preferences 服务实例 ==========
  static final PreferencesService _prefs = PreferencesService();

  // ========== 公开方法 ==========

  /// 是否启用桌面模式（键不存在时返回默认 false）
  Future<bool> isDesktopMode() async {
    return _prefs.getBool(_keyDesktopMode, defaultValue: _defaultDesktopMode);
  }

  /// 设置桌面模式开关
  Future<void> setDesktopMode(bool value) async {
    await _prefs.setBool(_keyDesktopMode, value);
  }
}
