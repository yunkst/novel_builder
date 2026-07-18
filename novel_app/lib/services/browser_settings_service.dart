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
  /// 桌面模式使用的 User-Agent（Edge 131，模拟桌面 Edge：番茄小说对 Windows
  /// 字样敏感，但对 Edge 也认；若失败可换 Chrome 字串）。
  /// 版本号不必追最新，服务器主要看 Windows + 浏览器关键字。
  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 '
      'Edg/131.0.0.0';

  /// 桌面模式注入 JS：覆盖 viewport meta 为桌面宽度 + 遮蔽 navigator 字段，
  /// 让响应式站点切 PC 布局。
  ///
  /// 设计要点：
  /// 1. **UA 自适配**：仅当 UA 含 `Windows NT`（桌面 UA）时执行；手机 UA（空串=
  ///    系统默认）直接 return，不破坏手机布局。运行时切换桌面/手机会 setSettings
  ///    UA + reload，reload 后本脚本重新执行并按新 UA 自适配，无需重建 WebView。
  /// 2. **复用 meta**：querySelector 找到现有 viewport meta 改其 content，找不到
  ///    才创建。不删除重建，避免站点 JS 缓存的 meta 引用失效。
  /// 3. **时机**：通过 initialUserScripts 在 `AT_DOCUMENT_START` 注入（DOMContentLoaded
  ///    之前），早于 onLoadStop + 站点 JS，能赶在响应式断点首次判断前拨正为桌面宽。
  /// 4. **允许缩放**：PC 页在手机屏字小，`user-scalable=yes` + `maximum-scale`
  ///    让用户双指放大。
  /// 5. **Navigator 遮蔽**：番茄小说等站点前端 JS 会读 `navigator.userAgent` /
  ///    `platform` / `maxTouchPoints` 二次判断设备类型。仅改 UA header 不够，
  ///    必须用 Object.defineProperty 覆盖这三个 getter，让 JS 看到与 UA 一致
  ///    的桌面值（Win64 / Win32 / 0）。
  ///
  /// 背景：Android WebView 的 layout viewport 宽度由页面 viewport meta 决定。
  /// 移动端站点多用 `width=device-width`，导致 layout viewport 等于 WebView
  /// 物理像素宽，响应式断点（如 min-width: 1280）命中手机分支。仅在 onLoadStop
  /// 改 viewport 太晚（布局已渲染），必须在文档解析阶段提前覆盖。iOS 上
  /// `preferredContentMode: DESKTOP` 已能处理，但本脚本靠 UA 自适配，跨平台无害。
  static const String desktopViewportOverrideJs = r'''
(function() {
  if (!/Windows NT/.test(navigator.userAgent)) return;

  // 遮蔽 navigator：让站点 JS 读到的 UA / platform / maxTouchPoints 与桌面 UA 一致。
  // 否则番茄小说等站点即便收到桌面 UA header，JS 读 navigator 仍命中手机分支。
  var fakeUA = navigator.userAgent;
  try {
    Object.defineProperty(navigator, 'userAgent', {
      get: function() { return fakeUA; }
    });
    Object.defineProperty(navigator, 'platform', {
      get: function() { return 'Win32'; }
    });
    Object.defineProperty(navigator, 'maxTouchPoints', {
      get: function() { return 0; }
    });
  } catch (e) {}

  function setDesktopViewport() {
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      document.head.appendChild(meta);
    }
    meta.content = 'width=1200, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes';
  }
  setDesktopViewport();
  document.addEventListener('DOMContentLoaded', setDesktopViewport);
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
