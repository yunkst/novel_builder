# 浏览器桌面/手机模式切换开关设计

- **日期**：2026-07-14
- **作者**：yedazhi（与 Claude Code 协同设计）
- **状态**：草案，待用户审阅
- **范围**：仅 Flutter 端 `novel_app`，后端零改动、AI 工具链零改动、不影响后台 Headless WebView

## 1. 背景与目标

### 1.1 现状

`lib/screens/webview_browser_screen.dart` 是用户底部导航第二个 Tab（`Icons.public`，在 `main.dart` 用 `IndexedStack` 常驻，`active` 标记可见性）。当前浏览器纯手机模式：

- `InAppWebView.initialSettings`（`webview_browser_screen.dart:145-147`）仅设 `javaScriptEnabled: true`，**没有任何 UA / `preferredContentMode` / `useWideViewPort` / `loadWithOverviewMode` 设置**
- 项目里 `flutter_inappwebview: 6.1.5`（`pubspec.lock:421`），6.x 用 `InAppWebViewSettings`（不是 5.x 的 `InAppWebViewGroupOptions`）
- 全量搜索 `userAgent` / `preferredContentMode` / `useWideViewPort` / `loadWithOverviewMode` / `桌面` / `desktop` 在 `lib/` 下均无任何匹配 —— 完全从零建设
- AppBar actions 原 6 个图标，2026-07-17 移除 webview 模型下载链路后剩 5 个图标（后退/前进/刷新/收藏夹/脚本管理），用户反馈"顶部图标有点太多了"

持久化范式已就绪：

- `PreferencesService`（`lib/services/preferences_service.dart:31-276`）单例封装 `SharedPreferences`，所有 get/set 自带 try/catch + debugPrint；提供 `getBool/setBool` 接口
- `ReaderSettingsService`（`lib/services/reader_settings_service.dart`）+ `@riverpod` Notifier（`lib/core/providers/reader_settings_state.dart`）是项目里「Service + Riverpod 状态」的标准范式

### 1.2 目标

让用户能在浏览器 Tab 内一键切换「手机模式 / 桌面模式」，迫使站点按 PC 版渲染：

- AppBar 溢出菜单（`⋮`）加「桌面模式」开关项，带勾选态反映当前模式
- 切换后自动 `setSettings` + `reload`，新配置立刻生效
- 状态全局持久化（重启 App 保留）
- 后台 Headless WebView（AI Agent 抓取小说章节用，`lib/services/headless_webview_pool.dart` 等）**不受影响**，继续移动默认（站点提取脚本按移动端 DOM 写）

### 1.3 非目标（显式排除）

| 项 | 理由 |
|---|---|
| 后台 Headless WebView 同步切桌面 | 现有站点提取脚本按移动端 DOM 写；切桌面可能破坏抓取。本轮明确不动。 |
| UA 自定义输入框 | 桌面 UA 固定为标准 Chrome/Win 字符串。未来扩展点（Service 字段已可挂） |
| 多标签 / 多窗口 | 项目就单 WebView，YAGNI |
| 后端改动 | 后端零改动 |
| 数据库改动 | 纯 SharedPreferences 持久化 |

## 2. 关键设计决策（已与用户确认）

| 维度 | 决策 | 依据 |
|------|------|------|
| 入口形态 | **AppBar 溢出菜单 `PopupMenuButton(⋮)`**（部分溢出方案） | 用户确认。保留后退/前进/刷新在顶部（高频），收藏夹/脚本 + 桌面模式 开关收进 `⋮`。导航体验不变、顶部清爽 |
| 影响范围 | **仅用户浏览器 Tab** | 用户确认。后台 Headless WebView（AI 抓取）不动 |
| 状态持久化 | **全局 SharedPreferences 持久化** | 与项目「设置类偏好」惯例一致（参考 ReaderSettingsService） |
| 默认值 | **手机模式**（`desktopMode = false`） | 用户确认。现状即手机模式 |
| 切换时机 | **运行时 setSettings + reload**（不重建 WebView） | `IndexedStack` 常驻，WebView 不重建；与用户原方案一致；按 `flutter_inappwebview` 6.x 文档要求 |
| Provider 风格 | **手写 `StateNotifierProvider`**（放 `webview_providers.dart`） | 与同模块现有 `WebViewControllerNotifier` 风格一致（`webview_providers.dart:26-29, 32-42`），避免引入 codegen。`reader_settings_state.dart` 的 `@riverpod` 是另一风格，本轮不混用 |
| Service 文件位置 | **`lib/services/browser_settings_service.dart`** | 与 `reader_settings_service.dart` 平级，单例 + 键常量 + 默认值范式 |

## 3. 方案选择

考虑过两个候选：

- **方案 A（采用）**：Service + 手写 StateNotifier + 运行时 setSettings。Service 封装 SharedPreferences，Notifier 暴露 AsyncValue，screen 用 `ref.watch` 注入 initialSettings + `ref.listen` 触发切换。
- **方案 B（弃）**：直接用 `StateProvider<bool>` + 内存 + 在 Widget 的 onPressed 里手写持久化。改动文件少，但持久化散落在 UI 层、易漏读、不可测、与项目「Service + Notifier」范式不一致。

**选 A 的理由**：与 `ReaderSettingsService`/`ReaderSettingsStateNotifier` 是同一套「Service 持盘 + Notifier 持状态」范式；持久化集中、可测；运行时切换逻辑封装进 `WebViewControllerNotifier.applyDesktopMode()` 不污染 UI 层；为未来扩展（UA 自定义、字体缩放）留口子。

## 4. 架构

```
┌──────────────────────────────────────────────────────────────┐
│ AppBar overflow PopupMenuButton (⋮)                          │
│   ┌────────────────────┐                                    │
│   │ 收藏夹              │                                    │
│   │ 脚本管理            │                                    │
│   │ ───────────────  │                                    │
│   │ ✓ 桌面模式         │  ← CheckedPopupMenuItem            │
│   └────────────────────┘                                    │
│        │ onSelected                                          │
│        ▼                                                     │
│ ref.read(browserDesktopModeProvider.notifier).toggle()       │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│ BrowserSettingsNotifier.toggle()                             │
│   ├─► BrowserSettingsService.setDesktopMode(v)  // 写盘      │
│   └─► state = AsyncData(v)                     // 刷新 state │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼ ref.listen 触发
┌──────────────────────────────────────────────────────────────┐
│ WebViewControllerNotifier.applyDesktopMode(v)                │
│   state.setSettings(InAppWebViewSettings(...))   // 注入新配置│
│   state.reload()                                  // 重渲染   │
└──────────────────────────────────────────────────────────────┘

启动时:
  BrowserSettingsService.isDesktopMode() 
    └─► BrowserSettingsNotifier state = AsyncData(v)
          └─► screen.initialSettings 用 v 构造 InAppWebViewSettings
                └─► 首次 WebView 创建即正确模式
```

**不变的部分**：
- 后台 Headless WebView（`headless_webview_pool.dart` 等）
- `WebViewControllerNotifier` 现有方法（`goBack` / `goForward` / `reload` / `loadUrl` / `handleDownloadStart` 等）
- 后端、数据库、其他 Tab
- `main.dart`（底部导航结构不变）

## 5. 组件 / 文件改动

### 5.1 改动清单

| # | 文件 | 改动 | 估算行数 |
|---|---|---|---|
| 1 | `lib/services/browser_settings_service.dart` 🆕 | 单例 + 键常量 + 桌面 UA 常量 + `isDesktopMode()` / `setDesktopMode()` | ~50 |
| 2 | `lib/core/providers/webview_providers.dart` | 新增 `BrowserSettingsNotifier` + `browserDesktopModeProvider`；给 `WebViewControllerNotifier` 加 `applyDesktopMode(bool)` | +60 |
| 3 | `lib/screens/webview_browser_screen.dart` | AppBar actions 改造为部分溢出菜单（保留后退/前进/刷新 + `⋮` 含收藏夹/脚本/分隔线/桌面模式）；`InAppWebView.initialSettings` 读 provider 注入配置；`ref.listen` 触发切换 | +50 / -20 |

总计约 **+140 行，1 个新文件，2 处编辑**。无 `pubspec.yaml` 改动（依赖已齐），无 build_runner 运行。

### 5.2 新组件：`BrowserSettingsService`

```dart
import 'preferences_service.dart';

/// 浏览器设置服务
///
/// 管理浏览器相关偏好持久化（目前仅桌面模式开关）
class BrowserSettingsService {
  static BrowserSettingsService? _instance;
  static BrowserSettingsService get instance {
    _instance ??= BrowserSettingsService._();
    return _instance!;
  }
  BrowserSettingsService._();

  static const String _keyDesktopMode = 'browser_desktop_mode';
  static const bool _defaultDesktopMode = false;

  /// 桌面模式 User-Agent（Windows Chrome 120）
  /// 版本号不必追最新，服务器只看 Windows + Chrome 关键字
  static const String desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static final PreferencesService _prefs = PreferencesService();

  Future<bool> isDesktopMode() async =>
      _prefs.getBool(_keyDesktopMode, defaultValue: _defaultDesktopMode);

  Future<void> setDesktopMode(bool v) async =>
      _prefs.setBool(_keyDesktopMode, v);
}
```

放 `lib/services/browser_settings_service.dart`，照抄 `reader_settings_service.dart:6-71` 的单例 + 键常量 + 默认值范式。

### 5.3 新 Provider：`browserDesktopModeProvider`

加在 `lib/core/providers/webview_providers.dart` 顶部，与 `webviewControllerProvider` 平级。手写，不 codegen：

```dart
/// 浏览器桌面模式开关状态
final browserDesktopModeProvider =
    StateNotifierProvider<BrowserSettingsNotifier, AsyncValue<bool>>(
  (ref) => BrowserSettingsNotifier(),
);

class BrowserSettingsNotifier extends StateNotifier<AsyncValue<bool>> {
  BrowserSettingsNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await BrowserSettingsService.instance.isDesktopMode();
      state = AsyncValue.data(v);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setDesktopMode(bool v) async {
    await BrowserSettingsService.instance.setDesktopMode(v);
    state = AsyncValue.data(v);
  }

  Future<void> toggle() async {
    final current = state.value ?? false;
    await setDesktopMode(!current);
  }
}
```

风格与 `webview_providers.dart` 的 `WebViewControllerNotifier`（L32-42）一致：`StateNotifier` 手写 + 内部引用 Service 单例。

### 5.4 `WebViewControllerNotifier.applyDesktopMode(bool)`

加在 `lib/core/providers/webview_providers.dart` 的 `WebViewControllerNotifier` 内：

```dart
/// 应用桌面/移动模式配置并 reload
///
/// controller 未就绪（state == null）时静默 return。
/// 失败仅记录日志，不阻塞 UI（与 goBack 超时保护同一思路）。
Future<void> applyDesktopMode(bool isDesktop) async {
  final c = state;
  if (c == null) return;
  await c.setSettings(
    settings: InAppWebViewSettings(
      preferredContentMode: isDesktop
          ? UserPreferredContentMode.DESKTOP
          : UserPreferredContentMode.MOBILE,
      userAgent: isDesktop
          ? BrowserSettingsService.desktopUserAgent
          : '',
      useWideViewPort: true,
      loadWithOverviewMode: isDesktop,
    ),
  );
  await c.reload();
}
```

### 5.5 AppBar 改造（`webview_browser_screen.dart:86-123`）

**当前**：6 个 IconButton 顺序排列。
**改为**：保留后退/前进/刷新 3 个 IconButton + 1 个 `PopupMenuButton(icon: Icons.more_vert)`，菜单项：

```dart
PopupMenuButton<String>(
  icon: const Icon(Icons.more_vert),
  tooltip: '更多',
  onSelected: (value) async {
    final notifier = ref.read(webviewControllerProvider.notifier);
    switch (value) {
      case 'bookmark':
        _showBookmarkPanel(context, notifier);
        break;
      case 'script':
        _showScriptPanel(context);
        break;
      case 'desktopMode':
        await ref.read(browserDesktopModeProvider.notifier).toggle();
        break;
    }
  },
  itemBuilder: (_) {
    final isDesktop = ref.watch(browserDesktopModeProvider).value ?? false;
    return [
      const PopupMenuItem(value: 'bookmark', child: Text('收藏夹')),
      const PopupMenuItem(value: 'script', child: Text('脚本管理')),
      const PopupMenuDivider(),
      CheckedPopupMenuItem(
        value: 'desktopMode',
        checked: isDesktop,
        child: const Text('桌面模式'),
      ),
    ];
  },
),
```

地址栏聚焦时 actions 仍为 `null`（现有 L86-87 逻辑不变）。

### 5.6 initialSettings 注入 + 运行时切换

`webview_browser_screen.dart:142-147` 改为：

```dart
final desktopMode = ref.watch(browserDesktopModeProvider).value ?? false;

InAppWebView(
  initialUrlRequest: URLRequest(url: WebUri('https://so.com')),
  initialSettings: InAppWebViewSettings(
    javaScriptEnabled: true,
    preferredContentMode: desktopMode
        ? UserPreferredContentMode.DESKTOP
        : UserPreferredContentMode.MOBILE,
    userAgent: desktopMode ? BrowserSettingsService.desktopUserAgent : '',
    useWideViewPort: true,
    loadWithOverviewMode: desktopMode,
  ),
  // ... 其余 callbacks 不变
)
```

外加 build 内 `ref.listen(browserDesktopModeProvider, ...)` 触发切换：

```dart
ref.listen<AsyncValue<bool>>(browserDesktopModeProvider, (prev, next) {
  final v = next.value;
  if (v != null) {
    ref.read(webviewControllerProvider.notifier).applyDesktopMode(v);
  }
});
```

## 6. 数据流

### 6.1 启动

```
BrowserSettingsNotifier._load()
  ├─► BrowserSettingsService.isDesktopMode() (读 SharedPreferences)
  └─► state = AsyncData(false|true)
        └─► screen.initialSettings 用值构造 InAppWebViewSettings
              └─► InAppWebView 创建时即正确模式
```

注意：`AsyncValue.loading()` 时 `value == null`，screen 用默认值 `false`（手机模式）兜底，确保 WebView 创建不阻塞。Notifier 加载完成后 state 变 `AsyncData`，screen rebuild，但 `InAppWebView` 已创建、`initialSettings` 不再生效 → 此时若是 desktopMode 但 WebView 已用 mobile 创建，需要补一次切换。

**补救**：在 Notifier 首次拿到值后，如果 controller 已就绪，立即调一次 `applyDesktopMode`。具体做法：Notifier 内拿不到 `ref`（不在 Provider 体系里），所以补救在 screen 里更自然。改用：

```dart
ref.listen<AsyncValue<bool>>(browserDesktopModeProvider, (prev, next) {
  if (next is AsyncData<bool>) {
    // 同时覆盖：Notifier 首次从 loading → data（此时 WebView 已按 mobile 创建，需补切）
    // 以及后续手动切换
    ref.read(webviewControllerProvider.notifier).applyDesktopMode(next.value);
  }
});
```

这覆盖两条路径：
1. Notifier 首次拿到偏好值（loading → data）
2. 用户手动 toggle（data(v) → data(!v)）

### 6.2 切换

```
User 在 ⋮ 菜单点「桌面模式」
  ↓
PopupMenuButton onSelected('desktopMode')
  ↓
ref.read(browserDesktopModeProvider.notifier).toggle()
  ├─► BrowserSettingsService.setDesktopMode(v)  // 持久化
  └─► state = AsyncData(v)                       // 触发 ref.listen
        ↓
webviewControllerProvider.notifier.applyDesktopMode(v)
  ├─► controller.setSettings(InAppWebViewSettings(...))
  └─► controller.reload()
```

### 6.3 边界时序

- `controller.setController` 在 `onWebViewCreated` 触发 → `state = controller`（`webview_providers.dart:39-41`）
- `applyDesktopMode` 检查 `state == null` 时静默 return；controller 一就绪下次 listen 触发就能切换
- 若 controller 比偏好加载更晚就绪（罕见，正常是同步先后），listen 第一次触发时 `state != null` 直接生效

## 7. 错误处理 & 边界

### 7.1 错误路径

| 场景 | 处理 | 用户感知 |
|---|---|---|
| `SharedPreferences` 读取失败 | `BrowserSettingsNotifier._load()` catch → `state = AsyncError`；screen 用 `value ?? false` 兜底为手机模式 | 无感，按手机模式启动 |
| `SharedPreferences` 写入失败 | `setDesktopMode` rethrow（`PreferencesService` 已包 try/catch + debugPrint） | 切换不持久化，下次重启恢复；但本次会话内 state 已更新，UI 显示正确 |
| `controller.setSettings` / `reload` 失败 | `applyDesktopMode` 内 try/catch 记 `LoggerService` | 切换不生效，UI 显示已切换但 WebView 未变；用户可手动刷新验证 |
| 菜单打开时 controller 未就绪（极端） | `applyDesktopMode` 静默 return；用户后续刷新时 config 已正确（initialSettings 当时已用对的值） | 极端，几乎不可见 |
| 菜单打开时偏好还在 loading | `value ?? false` 显示为未勾选；listener loading→data 触发一次自动切换 | UI 短暂延迟变勾选，<1s |

### 7.2 边界规则

1. **持久化键**：`browser_desktop_mode`（独立键，便于未来扩展更多浏览器设置）
2. **UA 字符串**：固定 `Chrome/120.0.0.0`，版本号不必追最新；如未来需要更新，改 `BrowserSettingsService.desktopUserAgent` 常量即可
3. **后台 Headless WebView 不动**：`headless_webview_pool.dart` 等三个文件的 `InAppWebViewSettings` 不变（现状已是无 UA/桌面配置）
4. **AppBar 行为不变**：地址栏聚焦时 actions 仍为 `null`；`_addressBarFocused` 状态机不动
5. **`IndexedStack` 常驻**：`WebViewBrowserScreen` 不重建，controller 复用，`applyDesktopMode` 始终能找到 controller
6. **浏览器当前页面**：切换后 `reload()` 用新 UA 重新请求该 URL，站点按 PC 版返回内容；**不**清浏览历史、不影响前进/后退栈

### 7.3 降级

`flutter_inappwebview` 6.x 在所有支持平台（Android/iOS/Windows/macOS）都支持 `setSettings`/`reload`；最坏情况是平台不支持 desktop UA（如 Web 平台实验性），会导致站点仍返回移动版，这是站点行为，与本功能无关。

## 8. 测试 & 验收

### 8.1 测试矩阵

| # | 场景 | 类型 | 关键断言 |
|---|---|---|---|
| 1 | `BrowserSettingsService` 默认值 | unit (`SharedPreferences.setMockInitialValues({})`) | `isDesktopMode() == false` |
| 2 | `BrowserSettingsService.setDesktopMode(true)` 持久化 | 同上 | set 后 `isDesktopMode() == true`；清空 prefs 再读也是 true（实际是同一 mock instance） |
| 3 | `BrowserSettingsNotifier` 初始 state | unit (ProviderContainer + mocked service) | `state is AsyncData<bool>` 且 value == false（mock 默认） |
| 4 | `BrowserSettingsNotifier.toggle()` | 同上 | 第一次 toggle → AsyncData(true)；第二次 → AsyncData(false) |
| 5 | `toggle()` 写入持久化 | 同上 | toggle 后 `BrowserSettingsService.isDesktopMode()` 与新 state 一致 |
| 6 | `_load()` 失败 → AsyncError | unit（mock service 抛） | `state is AsyncError` |
| 7 | `WebViewControllerNotifier.applyDesktopMode(true)` | unit（mock InAppWebViewController） | 调 setSettings 参数含 `userAgent == desktopUserAgent` + `preferredContentMode == DESKTOP`，调 reload 1 次 |
| 8 | `applyDesktopMode(false)` | 同上 | `userAgent == ''`、`preferredContentMode == MOBILE`、`loadWithOverviewMode == false` |
| 9 | `applyDesktopMode` 在 controller 为 null 时静默 return | 同上 | 不抛异常、不调 setSettings |
| 10 | `WebViewBrowserScreen` AppBar 渲染包含 `⋮` 按钮 | widget test | 找到 `Icons.more_vert` 的 IconButton |
| 11 | 点 `⋮` 弹出菜单，点「桌面模式」 | widget test | provider 状态从 false → true；`ref.listen` 触发 → 调 `applyDesktopMode(true)`（mock controller 验证） |
| 12 | 菜单「桌面模式」checked 反映当前状态 | widget test | 初始 false 不勾选；toggle 后再次打开菜单勾选 |

### 8.2 验收标准（DoD）

- [ ] `lib/services/browser_settings_service.dart` 新建
- [ ] `lib/core/providers/webview_providers.dart` 加 `BrowserSettingsNotifier` + `browserDesktopModeProvider` + `applyDesktopMode`
- [ ] `lib/screens/webview_browser_screen.dart` AppBar 改部分溢出菜单 + initialSettings 注入 + ref.listen
- [ ] 12 个测试全部通过
- [ ] `flutter analyze` 干净
- [ ] `flutter format lib/` 已跑
- [ ] 手动验收（桌面 dev 环境）：
  - 打开浏览器 Tab → AppBar 顶部只剩「← → ⟳ [地址栏] ⋮」
  - 点 `⋮` → 弹出「收藏夹 / 脚本管理 / ─── / ☐ 桌面模式」
  - 点「桌面模式」→ 菜单关闭、当前页面 reload 后变成 PC 端布局、勾选变 `☑`
  - 重启 App → 浏览器仍在桌面模式（无需再次设置）
  - 切回「手机模式」→ 当前页面 reload 后恢复移动版布局
  - 后台 Headless WebView 不受影响：让 Agent 抓一个章节列表/正文，行为与切换前一致

## 9. 未来扩展（不在本轮范围）

- **UA 自定义输入框**：在 `⋮` 菜单的「桌面模式」下方加「自定义 UA…」入口，弹底部 sheet 输入字符串，存到 `BrowserSettingsService`
- **更多浏览器设置**：如默认缩放、字体大小、JavaScript 开关；每个都是 Service 一字段 + Notifier 一字段 + Popup 菜单一项
- **站点级模式偏好**：按域名记忆模式（`Map<String, bool>`），自动按站点切换
- **桌面模式对后台 Headless WebView 也生效**：前提是先重构站点提取脚本以兼容桌面版 DOM