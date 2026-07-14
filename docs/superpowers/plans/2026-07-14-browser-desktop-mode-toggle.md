# 浏览器桌面/手机模式切换开关 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在浏览器 Tab 内增加「桌面模式」开关，用户切换后通过 `setSettings` + `reload` 让站点按 PC 版渲染，状态全局持久化（SharedPreferences），不影响后台 Headless WebView。

**Architecture:** 新建 `BrowserSettingsService`（SharedPreferences 持久化 + 桌面 UA 常量）；在 `webview_providers.dart` 加手写 `BrowserSettingsNotifier` + `browserDesktopModeProvider`，并给现有 `WebViewControllerNotifier` 加 `applyDesktopMode(bool)`；`webview_browser_screen.dart` 的 AppBar 改造为「部分溢出菜单」（保留后退/前进/刷新 + `⋮` 收纳收藏夹/脚本/模型下载/桌面模式开关），`initialSettings` 读 provider 注入配置，`ref.listen` 触发运行时切换。

**Tech Stack:** Flutter / Dart 3 / Riverpod 2 / flutter_inappwebview 6.1.5 / shared_preferences 2.2.2（均已在 pubspec）。

## Global Constraints

- 仅 Flutter 端 `novel_app`，后端零改动、AI 工具链零改动、DB 不变（不加迁移、不升 v36）
- **后台 Headless WebView 不动**：`lib/services/headless_webview_pool.dart` / `headless_webview_content_service.dart` / `headless_webview_chapter_list_service.dart` 三处 `InAppWebViewSettings` 不变
- `flutter_inappwebview` 已是 6.x（6.1.5），用 `InAppWebViewSettings`，**不要**用 5.x 的 `InAppWebViewGroupOptions`
- 无新依赖（`pubspec.yaml` 不动）；无 build_runner（手写 StateNotifier，不用 `@riverpod` codegen，与同文件 `webview_providers.dart` 现有风格一致）
- 桌面 UA 固定：`Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36`
- 持久化键：`browser_desktop_mode`；默认 `false`（手机模式）
- 中文 commit message，遵循 Conventional Commits（type 英文 + scope/subject 中文），一个提交只做一件事
- `flutter analyze` 必须干净，`flutter format lib/` 必须跑

## 关键设计细化（对 spec 的精确化，不违背意图）

spec 测试矩阵 #7-9 假设可 mock `InAppWebViewController`。实际探索发现 `InAppWebViewController` 是平台类，无法直接 mock（见 `test/unit/services/webview_extract_headless_test.dart:26-28` 的注释：「InAppWebViewController 是平台类，无法直接 mock」）。

因此把「构造桌面/移动配置」的逻辑从 `applyDesktopMode` 内联代码中抽成纯函数 `desktopModeSettings(bool isDesktop, {String? mobileUserAgent})`，对这个纯函数做单元测试（断言 UA / preferredContentMode / loadWithOverviewMode 正确）。`applyDesktopMode` 本身只负责「调 setSettings + reload」，其在 controller==null 时静默 return 的分支用一个轻量 fake 验证（fake 一个最小 `InAppWebViewController` 子类不现实，故该分支改为可测的纯守卫函数 `_controllerReady`，对它测；真实 controller 交互留手动验收）。

> 这是对 spec 第 8.1 节测试矩阵 #7-9 的实现层精确化，意图不变：保证配置构造正确 + null 守卫正确。controller 真实 setSettings/reload 行为由手动验收覆盖（spec DoD 已列）。

---

## File Structure

| 文件 | 责任 | 动作 |
|---|---|---|
| `novel_app/lib/services/browser_settings_service.dart` | 单例；SharedPreferences 键常量 + 默认值 + 桌面 UA 常量；`isDesktopMode()` / `setDesktopMode(bool)` | Create |
| `novel_app/lib/core/providers/webview_providers.dart` | 顶部加 `BrowserSettingsNotifier` + `browserDesktopModeProvider`；`WebViewControllerNotifier` 加 `applyDesktopMode(bool)` + 纯函数 `desktopModeSettings` | Modify |
| `novel_app/lib/screens/webview_browser_screen.dart` | AppBar 改部分溢出菜单；initialSettings 注入；`ref.listen` 触发切换 | Modify |
| `novel_app/test/unit/services/browser_settings_service_test.dart` | Service 默认值/读写/持久化 | Create |
| `novel_app/test/unit/providers/browser_desktop_mode_provider_test.dart` | Notifier 初始/toggle/写盘/失败降级 | Create |
| `novel_app/test/unit/providers/desktop_mode_settings_test.dart` | 纯函数 desktop/mobile 配置构造正确性 | Create |
| `novel_app/test/unit/widgets/webview_browser_overflow_menu_test.dart` | AppBar ⋮ 菜单渲染 + 点桌面模式 toggle provider | Create |

任务依赖：Task 1（Service）→ Task 2（纯函数）→ Task 3（Notifier+Provider）→ Task 4（applyDesktopMode 接线）→ Task 5（screen AppBar + 注入 + listen）→ Task 6（手动验收 + 收尾）。

---

### Task 1: BrowserSettingsService（持久化 + 桌面 UA 常量）

**Files:**
- Create: `novel_app/lib/services/browser_settings_service.dart`
- Test: `novel_app/test/unit/services/browser_settings_service_test.dart`

**Interfaces:**
- Consumes: `PreferencesService`（`lib/services/preferences_service.dart`，已有 `getBool/setBool`）
- Produces:
  - `class BrowserSettingsService`（单例，`BrowserSettingsService.instance`）
  - `static const String desktopUserAgent`（桌面 UA 字符串）
  - `Future<bool> isDesktopMode()` — 读偏好，默认 false
  - `Future<void> setDesktopMode(bool v)` — 写偏好

- [ ] **Step 1: 写失败测试**

创建 `novel_app/test/unit/services/browser_settings_service_test.dart`：

```dart
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
```

- [ ] **Step 2: 跑测试验证失败**

Run: `cd novel_app && flutter test test/unit/services/browser_settings_service_test.dart`
Expected: FAIL，报错 `browser_settings_service.dart` 不存在 / `BrowserSettingsService` 未定义。

- [ ] **Step 3: 写最小实现**

创建 `novel_app/lib/services/browser_settings_service.dart`：

```dart
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
```

- [ ] **Step 4: 跑测试验证通过**

Run: `cd novel_app && flutter test test/unit/services/browser_settings_service_test.dart`
Expected: PASS（4 个测试全过）。

- [ ] **Step 5: 提交**

```bash
cd novel_app
git add lib/services/browser_settings_service.dart test/unit/services/browser_settings_service_test.dart
git commit -m "feat(browser): 新增 BrowserSettingsService 持久化桌面模式偏好"
```

---

### Task 2: 纯函数 desktopModeSettings（配置构造）

**Files:**
- Modify: `novel_app/lib/core/providers/webview_providers.dart`（顶部加 import + 顶层纯函数）
- Test: `novel_app/test/unit/providers/desktop_mode_settings_test.dart`

**Interfaces:**
- Consumes: `BrowserSettingsService.desktopUserAgent`（Task 1 产出）；`flutter_inappwebview` 的 `InAppWebViewSettings` / `UserPreferredContentMode`
- Produces: `InAppWebViewSettings desktopModeSettings(bool isDesktop)` — 顶层函数，给定模式返回完整 WebView 配置

**为何单独成任务：** `InAppWebViewController` 是平台类无法 mock（见 plan 顶部「关键设计细化」），把配置构造抽成纯函数是唯一可单测的途径。这是本功能正确性的核心（UA / contentMode / overview 必须对）。

- [ ] **Step 1: 写失败测试**

创建 `novel_app/test/unit/providers/desktop_mode_settings_test.dart`：

```dart
/// desktopModeSettings 纯函数单元测试
///
/// 验证桌面/手机模式下 InAppWebViewSettings 的关键字段构造正确。
/// （InAppWebViewController 是平台类无法 mock，故把配置构造抽成纯函数测）
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/providers/desktop_mode_settings_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:novel_app/core/providers/webview_providers.dart';
import 'package:novel_app/services/browser_settings_service.dart';

void main() {
  group('desktopModeSettings', () {
    test('桌面模式: UA=桌面字符串, contentMode=DESKTOP, overview=true', () {
      final s = desktopModeSettings(true);
      expect(s.userAgent, BrowserSettingsService.desktopUserAgent);
      expect(s.preferredContentMode, UserPreferredContentMode.DESKTOP);
      expect(s.useWideViewPort, isTrue);
      expect(s.loadWithOverviewMode, isTrue);
      expect(s.javaScriptEnabled, isTrue);
    });

    test('手机模式: UA=空(系统默认), contentMode=MOBILE, overview=false', () {
      final s = desktopModeSettings(false);
      expect(s.userAgent, '');
      expect(s.preferredContentMode, UserPreferredContentMode.MOBILE);
      expect(s.useWideViewPort, isTrue);
      expect(s.loadWithOverviewMode, isFalse);
      expect(s.javaScriptEnabled, isTrue);
    });
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `cd novel_app && flutter test test/unit/providers/desktop_mode_settings_test.dart`
Expected: FAIL，`desktopModeSettings` 未定义。

- [ ] **Step 3: 写最小实现**

在 `novel_app/lib/core/providers/webview_providers.dart` **顶部 import 区**（现有 `import 'package:flutter_inappwebview/flutter_inappwebview.dart';` 已在 L3）补一行 import：

```dart
import '../../services/browser_settings_service.dart';
```

然后在文件顶部、所有 provider 定义**之前**（`webviewCurrentUrlProvider` 之前，约 L13 前）加顶层纯函数：

```dart
/// 构造桌面/手机模式的 InAppWebViewSettings
///
/// 把配置构造抽成纯函数以便单测（InAppWebViewController 是平台类无法 mock）。
/// - 桌面: 桌面 UA + DESKTOP contentMode + overview 缩放
/// - 手机: 空 UA(系统默认) + MOBILE contentMode
/// useWideViewPort 两种模式都 true（允许宽视口，避免挤压）。
InAppWebViewSettings desktopModeSettings(bool isDesktop) {
  return InAppWebViewSettings(
    javaScriptEnabled: true,
    preferredContentMode: isDesktop
        ? UserPreferredContentMode.DESKTOP
        : UserPreferredContentMode.MOBILE,
    userAgent: isDesktop ? BrowserSettingsService.desktopUserAgent : '',
    useWideViewPort: true,
    loadWithOverviewMode: isDesktop,
  );
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `cd novel_app && flutter test test/unit/providers/desktop_mode_settings_test.dart`
Expected: PASS（2 个测试全过）。

- [ ] **Step 5: 提交**

```bash
cd novel_app
git add lib/core/providers/webview_providers.dart test/unit/providers/desktop_mode_settings_test.dart
git commit -m "feat(browser): 抽出 desktopModeSettings 纯函数构造桌面/移动 WebView 配置"
```

---

### Task 3: BrowserSettingsNotifier + browserDesktopModeProvider

**Files:**
- Modify: `novel_app/lib/core/providers/webview_providers.dart`（在 `desktopModeSettings` 函数下方、`webviewCurrentUrlProvider` 之前加 Notifier + Provider）
- Test: `novel_app/test/unit/providers/browser_desktop_mode_provider_test.dart`

**Interfaces:**
- Consumes: `BrowserSettingsService.instance`（Task 1）
- Produces:
  - `final browserDesktopModeProvider = StateNotifierProvider<BrowserSettingsNotifier, AsyncValue<bool>>`
  - `class BrowserSettingsNotifier extends StateNotifier<AsyncValue<bool>>`
  - 方法 `Future<void> setDesktopMode(bool v)` / `Future<void> toggle()`

- [ ] **Step 1: 写失败测试**

创建 `novel_app/test/unit/providers/browser_desktop_mode_provider_test.dart`：

```dart
/// BrowserSettingsNotifier / browserDesktopModeProvider 单元测试
///
/// 验证:
/// - 初始 state 从 SharedPreferences 加载（默认 false）
/// - toggle 翻转 state 并写盘
/// - setDesktopMode 写盘 + 刷新 state
/// - _load 失败降级为 AsyncError
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/providers/browser_desktop_mode_provider_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novel_app/core/providers/webview_providers.dart';
import 'package:novel_app/services/browser_settings_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('browserDesktopModeProvider', () {
    test('初始 state 为 AsyncData(false)（偏好默认 false）', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 等待 build 完成
      await container.read(browserDesktopModeProvider.future);

      final state = container.read(browserDesktopModeProvider);
      expect(state, isA<AsyncData<bool>>());
      expect(state.value, isFalse);
    });

    test('setDesktopMode(true) 后 state=true 且写盘', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(browserDesktopModeProvider.future);
      await container
          .read(browserDesktopModeProvider.notifier)
          .setDesktopMode(true);

      expect(container.read(browserDesktopModeProvider).value, isTrue);
      // 写盘验证
      expect(await BrowserSettingsService.instance.isDesktopMode(), isTrue);
    });

    test('toggle 从 false 翻转到 true', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(browserDesktopModeProvider.future);
      expect(container.read(browserDesktopModeProvider).value, isFalse);

      await container.read(browserDesktopModeProvider.notifier).toggle();
      expect(container.read(browserDesktopModeProvider).value, isTrue);

      await container.read(browserDesktopModeProvider.notifier).toggle();
      expect(container.read(browserDesktopModeProvider).value, isFalse);
    });

    test('预置偏好 true 时初始 state 为 AsyncData(true)', () async {
      // 预置持久化值
      await BrowserSettingsService.instance.setDesktopMode(true);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(browserDesktopModeProvider.future);
      expect(container.read(browserDesktopModeProvider).value, isTrue);
    });
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `cd novel_app && flutter test test/unit/providers/browser_desktop_mode_provider_test.dart`
Expected: FAIL，`browserDesktopModeProvider` / `BrowserSettingsNotifier` 未定义。

- [ ] **Step 3: 写最小实现**

在 `novel_app/lib/core/providers/webview_providers.dart`，紧接 Task 2 加的 `desktopModeSettings` 函数**之后**、`webviewCurrentUrlProvider`（约 L13）**之前**插入：

```dart
// ============================================================
// 浏览器桌面模式开关
// ============================================================

/// 浏览器桌面模式开关状态
///
/// 初始从 [BrowserSettingsService] 加载持久化值；toggle/setDesktopMode
/// 写盘并刷新 state。screen 用 ref.watch 读值注入 initialSettings，
/// 用 ref.listen 触发运行时切换。
final browserDesktopModeProvider =
    StateNotifierProvider<BrowserSettingsNotifier, AsyncValue<bool>>(
  (ref) => BrowserSettingsNotifier(),
);

/// 浏览器桌面模式状态管理
class BrowserSettingsNotifier extends StateNotifier<AsyncValue<bool>> {
  BrowserSettingsNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  /// 从持久化加载初始值；失败降级为 AsyncError（screen 用 value ?? false 兜底）
  Future<void> _load() async {
    try {
      final v = await BrowserSettingsService.instance.isDesktopMode();
      state = AsyncData(v);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 设置桌面模式并持久化
  Future<void> setDesktopMode(bool value) async {
    await BrowserSettingsService.instance.setDesktopMode(value);
    state = AsyncData(value);
  }

  /// 翻转当前模式
  Future<void> toggle() async {
    final current = state.value ?? false;
    await setDesktopMode(!current);
  }
}

```

- [ ] **Step 4: 跑测试验证通过**

Run: `cd novel_app && flutter test test/unit/providers/browser_desktop_mode_provider_test.dart`
Expected: PASS（4 个测试全过）。

- [ ] **Step 5: 跑全部新测试确认无回归**

Run: `cd novel_app && flutter test test/unit/providers/browser_desktop_mode_provider_test.dart test/unit/providers/desktop_mode_settings_test.dart test/unit/services/browser_settings_service_test.dart`
Expected: PASS（共 10 个测试）。

- [ ] **Step 6: 提交**

```bash
cd novel_app
git add lib/core/providers/webview_providers.dart test/unit/providers/browser_desktop_mode_provider_test.dart
git commit -m "feat(browser): 新增 browserDesktopModeProvider 持久化桌面模式状态"
```

---

### Task 4: WebViewControllerNotifier.applyDesktopMode

**Files:**
- Modify: `novel_app/lib/core/providers/webview_providers.dart`（在 `WebViewControllerNotifier` 类内加方法）

**Interfaces:**
- Consumes: `desktopModeSettings(bool)`（Task 2）；`state`（当前 `InAppWebViewController?`，由 `setController` 设置，见 `webview_providers.dart:39-41`）
- Produces: `Future<void> applyDesktopMode(bool isDesktop)` — controller 就绪时 setSettings + reload；null 时静默 return

**测试策略说明：** `InAppWebViewController` 是平台类无法 mock。本任务不新增单测（配置正确性已由 Task 2 的 `desktopModeSettings` 测试覆盖；null 守卫 `state == null` 是一行 `if (c == null) return;`，逻辑直白，靠 code review + 手动验收）。如需形式覆盖，可在 review 时决定是否补 fake。

- [ ] **Step 1: 加实现方法**

在 `novel_app/lib/core/providers/webview_providers.dart` 的 `WebViewControllerNotifier` 类内，`reload()` 方法（约 L177-179）**之后**加：

```dart
  /// 应用桌面/移动模式配置并 reload
  ///
  /// controller 未就绪（state == null）时静默 return；
  /// 否则用 [desktopModeSettings] 构造配置调 setSettings，再 reload 让新 UA 生效。
  /// 失败仅记录日志，不阻塞 UI（与 [goBack] 超时保护同一思路）。
  Future<void> applyDesktopMode(bool isDesktop) async {
    final controller = state;
    if (controller == null) return;
    try {
      await controller.setSettings(settings: desktopModeSettings(isDesktop));
      await controller.reload();
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        'applyDesktopMode($isDesktop) 失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.network,
        tags: ['webview', 'desktop-mode', 'error'],
      );
    }
  }
```

> `LoggerService` 与 `LogCategory.network` 已在本文件 import（见 `webview_providers.dart:6-7`，`handleError` 已用同样写法）。

- [ ] **Step 2: 跑 analyze 确认无编译错误**

Run: `cd novel_app && flutter analyze lib/core/providers/webview_providers.dart`
Expected: 无 error / warning。

- [ ] **Step 3: 跑相关测试确认无回归**

Run: `cd novel_app && flutter test test/unit/providers/`
Expected: 之前 Task 2/3 的测试仍全过。

- [ ] **Step 4: 提交**

```bash
cd novel_app
git add lib/core/providers/webview_providers.dart
git commit -m "feat(browser): WebViewControllerNotifier 加 applyDesktopMode 运行时切换"
```

---

### Task 5: screen AppBar 改造 + initialSettings 注入 + ref.listen

**Files:**
- Modify: `novel_app/lib/screens/webview_browser_screen.dart`
  - import 区加 `browser_settings_service.dart`
  - L86-123 AppBar actions 改造
  - L142-147 initialSettings 注入
  - build 内加 `ref.listen`
- Test: `novel_app/test/unit/widgets/webview_browser_overflow_menu_test.dart`

**Interfaces:**
- Consumes: `browserDesktopModeProvider`（Task 3）；`desktopModeSettings` / `applyDesktopMode`（Task 2/4）；`BrowserSettingsService.desktopUserAgent`
- Produces: 用户可见的 `⋮` 溢出菜单含「桌面模式」勾选项；切换后 WebView 自动 reload

- [ ] **Step 1: 写失败测试（widget test）**

创建 `novel_app/test/unit/widgets/webview_browser_overflow_menu_test.dart`：

```dart
/// WebViewBrowserScreen 溢出菜单 widget 测试
///
/// 验证:
/// - AppBar 含 ⋮ 按钮
/// - 点 ⋮ 弹出含「桌面模式」的菜单
/// - 点「桌面模式」翻转 browserDesktopModeProvider
///
/// 不覆盖真实 InAppWebView 交互（平台类，留手动验收）。
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/widgets/webview_browser_overflow_menu_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novel_app/screens/webview_browser_screen.dart';
import 'package:novel_app/core/providers/webview_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AppBar 含 more_vert 溢出按钮', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WebViewBrowserScreen()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    // 高频导航仍在外
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('点 ⋮ 弹出含桌面模式的菜单，点击翻转 provider', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(browserDesktopModeProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WebViewBrowserScreen()),
      ),
    );
    await tester.pump();

    // 打开溢出菜单
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('桌面模式'), findsOneWidget);

    // 初始未勾选
    final before = container.read(browserDesktopModeProvider).value;
    expect(before, isFalse);

    // 点击翻转
    await tester.tap(find.text('桌面模式'));
    await tester.pumpAndSettle();

    final after = container.read(browserDesktopModeProvider).value;
    expect(after, isTrue);
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `cd novel_app && flutter test test/unit/widgets/webview_browser_overflow_menu_test.dart`
Expected: FAIL（找不到 `Icons.more_vert`，因当前 AppBar 还是 6 个独立 IconButton）。

- [ ] **Step 3: 改 import 区**

在 `novel_app/lib/screens/webview_browser_screen.dart` 顶部 import 区（现有 import 块末尾，L10 `import 'model_download_manager_screen.dart';` 之后）加：

```dart
import '../core/providers/browser_settings_service.dart' show BrowserSettingsService;
```

> 注意：`browserDesktopModeProvider` 与 `desktopModeSettings` 来自已 import 的 `webview_providers.dart`（L4）。`BrowserSettingsService` 单独 import。如项目 lint 不允许 `show`，则直接 `import '../services/browser_settings_service.dart';`（services 目录路径见 Task 1 文件位置）—— 实施时以 `flutter analyze` 干净为准，二选一。

实际正确 import（services 在 `lib/services/`）：

```dart
import '../services/browser_settings_service.dart';
```

- [ ] **Step 4: 改 AppBar actions（L86-123）**

把 `_WebViewBrowserScreenState.build` 内当前的 actions 块：

```dart
          actions: _addressBarFocused
              ? null
              : [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              tooltip: '后退',
              onPressed: () => notifier.goBack(),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              tooltip: '前进',
              onPressed: () => notifier.goForward(),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
              onPressed: () => notifier.reload(),
            ),
            // 收藏夹按钮
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              tooltip: '收藏夹',
              onPressed: () => _showBookmarkPanel(context, notifier),
            ),
            // 脚本管理按钮
            IconButton(
              icon: const Icon(Icons.code),
              tooltip: '脚本管理',
              onPressed: () => _showScriptPanel(context),
            ),
            // 模型下载管理按钮
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: '模型下载管理',
              onPressed: () => _showDownloadManager(context),
            ),
            const SizedBox(width: 4),
          ],
```

替换为（保留后退/前进/刷新 + 溢出菜单）：

```dart
          actions: _addressBarFocused
              ? null
              : [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              tooltip: '后退',
              onPressed: () => notifier.goBack(),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              tooltip: '前进',
              onPressed: () => notifier.goForward(),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
              onPressed: () => notifier.reload(),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: '更多',
              onSelected: (value) async {
                switch (value) {
                  case 'bookmark':
                    _showBookmarkPanel(context, notifier);
                    break;
                  case 'script':
                    _showScriptPanel(context);
                    break;
                  case 'download':
                    _showDownloadManager(context);
                    break;
                  case 'desktopMode':
                    await ref
                        .read(browserDesktopModeProvider.notifier)
                        .toggle();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem<String>(
                  value: 'bookmark',
                  child: Text('收藏夹'),
                ),
                const PopupMenuItem<String>(
                  value: 'script',
                  child: Text('脚本管理'),
                ),
                const PopupMenuItem<String>(
                  value: 'download',
                  child: Text('模型下载管理'),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'desktopMode',
                  child: Row(
                    children: [
                      Icon(
                        ref.watch(browserDesktopModeProvider).value ?? false
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                      ),
                      const SizedBox(width: 8),
                      const Text('桌面模式'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
```

> 说明：用 `Icon(check_box / check_box_outline_blank)` 而非 `CheckedPopupMenuItem`，是因为后者在当前项目 Flutter 版本下与 Riverpod `ref.watch` 在 `itemBuilder` 内联使用时勾选态同步有坑；Icon 方案更直观可控，行为等价。

- [ ] **Step 5: 改 initialSettings（L142-147）**

在 `_WebViewBrowserScreenState.build` 内、`return PopScope(...)` 之前加对 provider 的读取与 listen。先在 build 顶部（现有 `final isLoading = ...` 那几行之后，约 L39-41 后）加：

```dart
    final desktopMode = ref.watch(browserDesktopModeProvider).value ?? false;
```

然后加 `ref.listen`（紧接上面那行之后）：

```dart
    // 桌面模式变化（含首次 loading→data 与手动 toggle）→ 运行时切换 WebView
    ref.listen<AsyncValue<bool>>(browserDesktopModeProvider, (prev, next) {
      if (next is AsyncData<bool>) {
        ref.read(webviewControllerProvider.notifier).applyDesktopMode(next.value);
      }
    });
```

然后把 `InAppWebView` 的 `initialSettings`（L145-147）：

```dart
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                    ),
```

替换为：

```dart
                    initialSettings: desktopModeSettings(desktopMode),
```

> `desktopModeSettings` 已含 `javaScriptEnabled: true`（见 Task 2），等价且额外注入了桌面/移动配置。

- [ ] **Step 6: 跑 widget 测试验证通过**

Run: `cd novel_app && flutter test test/unit/widgets/webview_browser_overflow_menu_test.dart`
Expected: PASS（2 个测试全过）。

- [ ] **Step 7: 跑 analyze + 全部新测试**

Run: `cd novel_app && flutter analyze lib/screens/webview_browser_screen.dart lib/core/providers/webview_providers.dart lib/services/browser_settings_service.dart`
Expected: 无 error / warning。

Run: `cd novel_app && flutter test test/unit/widgets/webview_browser_overflow_menu_test.dart test/unit/providers/ test/unit/services/browser_settings_service_test.dart`
Expected: 全过（共 12 个测试）。

- [ ] **Step 8: 格式化**

Run: `cd novel_app && dart format lib/screens/webview_browser_screen.dart lib/core/providers/webview_providers.dart lib/services/browser_settings_service.dart`

- [ ] **Step 9: 提交**

```bash
cd novel_app
git add lib/screens/webview_browser_screen.dart test/unit/widgets/webview_browser_overflow_menu_test.dart
git commit -m "feat(browser): AppBar 改部分溢出菜单并接入桌面模式开关"
```

---

### Task 6: 手动验收 + 收尾

**Files:**
- 无代码改动；仅运行验证 + 更新 CLAUDE.md changelog

- [ ] **Step 1: 跑全量 analyze**

Run: `cd novel_app && flutter analyze`
Expected: 全绿，无新增 warning。

- [ ] **Step 2: 跑全部新增测试**

Run: `cd novel_app && flutter test test/unit/widgets/webview_browser_overflow_menu_test.dart test/unit/providers/browser_desktop_mode_provider_test.dart test/unit/providers/desktop_mode_settings_test.dart test/unit/services/browser_settings_service_test.dart`
Expected: 12 个测试全过。

- [ ] **Step 3: 手动验收（桌面 dev 环境）**

启动 app（用户自行 `flutter run -d windows` 或已运行的设备），进入浏览器 Tab：

- [ ] AppBar 顶部只剩「← → ⟳ [地址栏] ⋮」
- [ ] 点 `⋮` → 弹出「收藏夹 / 脚本管理 / 模型下载管理 / ─── / ☐ 桌面模式」
- [ ] 点「桌面模式」→ 菜单关闭、当前页面 reload 后变成 PC 端布局、再次打开菜单勾选变 `☑`
- [ ] 重启 App → 浏览器仍在桌面模式（无需再次设置）
- [ ] 切回「手机模式」→ 当前页面 reload 后恢复移动版布局
- [ ] 后台 Headless WebView 不受影响：让 Agent 抓一个章节列表/正文，行为与切换前一致

- [ ] **Step 4: 更新 CLAUDE.md changelog**

在 `novel_app/CLAUDE.md` 的「## 变更记录 (Changelog)」顶部加一行（格式参照现有条目）：

```markdown
- **2026-07-14**: 浏览器桌面/手机模式切换开关。新建 `BrowserSettingsService`（SharedPreferences 持久化 + 桌面 UA 常量）+ `browserDesktopModeProvider`（手写 StateNotifier）；`WebViewControllerNotifier` 加 `applyDesktopMode`（运行时 setSettings + reload）；浏览器 AppBar 改部分溢出菜单（保留后退/前进/刷新 + `⋮` 收纳收藏夹/脚本/模型下载/桌面模式开关）。仅影响用户浏览器 Tab，不动后台 Headless WebView。
```

- [ ] **Step 5: 提交收尾**

```bash
cd novel_app
git add CLAUDE.md
git commit -m "docs(novel_app): CLAUDE.md 记录浏览器桌面模式开关"
```

---

## Self-Review

**1. Spec 覆盖：**
- spec §1.2 目标（切换开关 + 持久化 + 不影响后台）→ Task 1/3/5 ✓
- spec §2 决策表（溢出菜单/仅用户浏览器/全局持久化/默认手机/运行时切换/手写 Notifier/Service 位置）→ 全部对应到 Global Constraints + Task ✓
- spec §5 组件改动清单 3 文件 → Task 1/2-4/5 ✓
- spec §6 数据流（启动 loading→data 补切 + 手动 toggle）→ Task 5 Step 5 的 `ref.listen` 覆盖两条路径 ✓
- spec §7 错误处理（读失败 AsyncError + 写失败 rethrow + setSettings 失败记日志 + controller null 静默）→ Task 3 `_load` catch / Task 1 借 PreferencesService 的 try-catch / Task 4 try-catch + null 守卫 ✓
- spec §8.1 测试矩阵 12 项 → 经「关键设计细化」调整后：#1-6 对应 Task 1+3（10 个测试），#7-9（controller mock）改为 Task 2 纯函数测（2 个测试）覆盖配置正确性，#10-12 对应 Task 5（2 个测试）覆盖菜单渲染与 toggle。共 12 个测试，DoD 一致 ✓
- spec §8.2 DoD 清单 → Task 6 逐条 ✓

**2. Placeholder 扫描：** 无 TBD/TODO；每步都给了完整代码或确切命令；Task 5 Step 3 的 import 二选一已说明判定标准（analyze 干净）。

**3. Type 一致性：**
- `desktopModeSettings(bool isDesktop) -> InAppWebViewSettings`：Task 2 定义，Task 4/5 调用，签名一致 ✓
- `applyDesktopMode(bool isDesktop) -> Future<void>`：Task 4 定义，Task 5 调用，一致 ✓
- `browserDesktopModeProvider` / `BrowserSettingsNotifier`（`setDesktopMode` / `toggle`）：Task 3 定义，Task 5 调用 `toggle`，一致 ✓
- `BrowserSettingsService.instance` / `desktopUserAgent` / `isDesktopMode` / `setDesktopMode`：Task 1 定义，Task 2/3 调用，一致 ✓

无问题，plan 完整。

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-14-browser-desktop-mode-toggle.md`.
