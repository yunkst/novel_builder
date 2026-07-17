/// BrowserSettingsService 单元测试
///
/// 验证桌面模式偏好的读写与默认值，以及桌面 UA 常量。
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/services/browser_settings_service_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/services/browser_settings_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BrowserSettingsService', () {
    test('isDesktopMode 默认 false', () async {
      final svc = BrowserSettingsService.instance;
      expect(await svc.isDesktopMode(), isFalse);
    });

    test('setDesktopMode(true) 后 isDesktopMode 返回 true', () async {
      final svc = BrowserSettingsService.instance;
      await svc.setDesktopMode(true);
      expect(await svc.isDesktopMode(), isTrue);
    });

    test('setDesktopMode(false) 后 isDesktopMode 返回 false', () async {
      final svc = BrowserSettingsService.instance;
      await svc.setDesktopMode(true);
      await svc.setDesktopMode(false);
      expect(await svc.isDesktopMode(), isFalse);
    });

    test('desktopUserAgent 是 Windows Chrome 字符串', () {
      expect(BrowserSettingsService.desktopUserAgent,
          contains('Windows NT 10.0'));
      expect(BrowserSettingsService.desktopUserAgent, contains('Chrome/'));
    });

    test('desktopViewportOverrideJs 含桌面宽 viewport 覆盖逻辑', () {
      // 强制桌面宽，让响应式断点命中桌面分支
      expect(BrowserSettingsService.desktopViewportOverrideJs,
          contains('width=1024'));
      expect(BrowserSettingsService.desktopViewportOverrideJs,
          contains('name="viewport"'));
      // 必须先删除旧 meta，避免站点原 viewport meta 残留干扰
      expect(BrowserSettingsService.desktopViewportOverrideJs,
          contains('remove()'));
    });
  });
}
