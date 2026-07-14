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
  });
}
