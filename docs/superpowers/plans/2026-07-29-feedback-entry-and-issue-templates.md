# 问题反馈入口与 GitHub Issue 模板 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在设置页「关于」组加「问题反馈」入口，点击外部浏览器打开 GitHub `issues/new`；同时为仓库新增 3 个 GitHub Issue Forms 模板（Bug / 功能 / 提问），覆盖项目主要反馈场景。

**Architecture:** 设置页用现成的 `_SettingsSection` 容器追加一个 `ListTile` + 新抽 `_openFeedback()` 方法（与「支持项目 → 去 GitHub 点 Star」同款 `launchUrl` + `LaunchMode.externalApplication` + try/catch 静默范式）；Issue 模板放 `.github/ISSUE_TEMPLATE/` 用 Issue Forms YAML（带校验的现代格式），label 复用仓库已有的 `bug` / `enhancement` / `question`。零业务代码外影响、零新依赖、零 DB 变更。

**Tech Stack:** Flutter 3.0+ / Dart 3.0+ / `url_launcher ^6.2.0`（已有）/ `flutter_test` / `package_info_plus`（mock via `TestDefaultBinaryMessengerBinding`）/ GitHub Issue Forms（YAML）。

## Global Constraints

- **复用 `kGitHubRepo` 常量**：从 `lib/services/native_crash_reporter.dart:27` import，值 `'https://github.com/yunkst/novel_builder'`（末尾无斜杠），不重新定义
- **URL 拼接固定字面值**：`'$kGitHubRepo/issues/new'`（与 `native_crash_reporter.dart:102` 已存在的崩溃报告引导完全一致）
- **跳转范式固定**：`launchUrl(uri, mode: LaunchMode.externalApplication)` + try/catch 静默吞异常（与 `lib/screens/settings_screen.dart:441-448` 的 Star 入口一致）
- **不引入新依赖**：url_launcher / flutter_riverpod / package_info_plus / shared_preferences 全在 pubspec
- **测试注入**：`SharedPreferences.setMockInitialValues({})`（穿透到 `PreferencesService.instance` 单例，因此 `ThemeNotifier.build()` 真实跑即可，**无需 override themeNotifierProvider**）+ `ProviderScope` overrides 仅覆盖 `backupServiceProvider`（参考 `test/unit/widgets/webview_browser_overflow_menu_test.dart` 范式）
- **PackageInfo mock**：通过 `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler` 给 `plugins.flutter.io/package_info_plus` 通道注册 handler（项目里无现有先例，本任务需新引入）。SettingsScreen.initState 会调 `PackageInfo.fromPlatform()`，不 mock 会抛 `MissingPluginException`
- **MaterialApp.theme 来源**：用 `ThemeState(themeMode: AppThemeMode.light).getLightTheme()`，它已含 `AppColors.light` extension，保证 `context.appColors.neutral` 命中真实扩展而非兜底值
- **issue 模板 label 字面值**：`bug` / `enhancement` / `question`（仓库已存在，2026-07-29 通过 `gh label list` 确认）
- **issue 模板位置**：`.github/ISSUE_TEMPLATE/`（仓库根）
- **commit 规范**：chinese-commit-conventions（type 英文 + scope 中文 + subject 中文动宾）
- **单 commit / task**：每个 task 结束独立 commit
- **零业务代码外影响**：不动 novel_agent / repositories / 数据库 schema / 后端 / CI workflow / 现有设置页分组结构

---

## File Structure

### 新建（4 个）

| 文件 | 职责 |
|---|---|
| `novel_app/test/unit/screens/settings_feedback_entry_test.dart` | SettingsScreen widget 测试：验证「问题反馈」ListTile 存在 + 带 `open_in_new` 外链图标 + 点击 `onTap` 不抛异常 |
| `.github/ISSUE_TEMPLATE/bug_report.yml` | Bug 报告 Issue Forms（label: bug） |
| `.github/ISSUE_TEMPLATE/feature_request.yml` | 功能建议 Issue Forms（label: enhancement） |
| `.github/ISSUE_TEMPLATE/question.yml` | 提问 / 讨论 Issue Forms（label: question） |

### 修改（1 个）

| 文件 | 改动 |
|---|---|
| `novel_app/lib/screens/settings_screen.dart` | ①「关于」组（`title: '关于'` 的 `_SettingsSection`，约 349 行）末尾追加 1 个 `ListTile`；②新抽 `Future<void> _openFeedback()` 方法（仿 Star 入口 `_SettingsSection` 末尾 `onTap` 内联写法的轻量提取） |

### 复用（已存在）

- `lib/services/native_crash_reporter.dart:27` 的 `kGitHubRepo` —— settings_screen 已通过 `import '.../native_crash_reporter.dart' show kGitHubRepo;` 引入
- `lib/screens/settings_screen.dart:441-448` 的 Star 入口 `launchUrl` + 异常吞掉范式
- `test/utils/riverpod_test_utils.dart` 的 `RiverpodTestUtils.providerScopeWithMocks`

---

## Task 1: 设置页加「问题反馈」入口（TDD）

**Files:**
- Modify: `novel_app/lib/screens/settings_screen.dart:347-427`（「关于」组的 `children` 列表末尾 + 新方法追加到 class 内）
- Create: `novel_app/test/unit/screens/settings_feedback_entry_test.dart`

**Interfaces:**
- Consumes: `kGitHubRepo`（已 import），`url_launcher.launchUrl`（已 import），`Icons.feedback_outlined`（material library）
- Produces: 公开可见行为 —— 设置页「关于」组末尾出现 1 个 `ListTile`（title `问题反馈` / subtitle `报告 Bug 或提出功能建议` / trailing `Icons.open_in_new`），点击触发 `launchUrl('$kGitHubRepo/issues/new')`

### Step 1: 写失败的 widget 测试

新建 `novel_app/test/unit/screens/settings_feedback_entry_test.dart`：

```dart
/// 设置页「问题反馈」入口 widget 测试。
///
/// 验证:
/// - 「关于」组末尾出现「问题反馈」ListTile
/// - trailing 携带 open_in_new 外链图标
/// - 点击 onTap 不抛异常（url_launcher 在测试环境走失败路径，不校验具体 URL）
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/screens/settings_feedback_entry_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novel_app/core/providers/service_providers.dart';
import 'package:novel_app/core/providers/theme_provider.dart';
import 'package:novel_app/screens/settings_screen.dart';
import 'package:novel_app/services/backup_service.dart';

/// mock 掉 PackageInfo 的 platform channel,避免测试环境 MissingPluginException。
/// SettingsScreen.initState 会调 PackageInfo.fromPlatform(),不 mock 会抛错。
void _mockPackageInfoChannel() {
  const channel = MethodChannel('plugins.flutter.io/package_info_plus');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'getAll') {
      return <String, dynamic>{
        'appName': 'novel_app',
        'packageName': 'com.example.novel_app',
        'version': '2.0.2-test',
        'buildNumber': '999',
        'buildSignature': '',
        'installerStore': null,
      };
    }
    return null;
  });
}

/// 测试用 BackupService stub,getLastBackupTimeText 返回空字符串,跳过文件 IO。
///
/// SettingsScreen._loadLastBackupTime() 会 ref.read(backupServiceProvider)
/// .getLastBackupTimeText(); 不 stub 会真实读路径抛异常。
class _FakeBackupService implements BackupService {
  @override
  Future<String> getLastBackupTimeText() async => '';

  // 其余方法测试不关心,noSuchMethod 兜底。
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(Widget child) {
  // ThemeNotifier.build() 走 PreferencesService.instance 单例读 'theme_mode';
  // setUp 里的 setMockInitialValues({}) 能穿透到它,故无需 override themeNotifierProvider。
  // 但 build 是 async,需用 ref.listen 等 AsyncData 就绪 / 或直接 pumpAndSettle。
  return ProviderScope(
    overrides: [
      backupServiceProvider.overrideWithValue(_FakeBackupService()),
    ],
    child: MaterialApp(
      // 用 ThemeState.light 的主题数据,它已含 AppColors.light extension,
      // 保证 SettingsScreen 内 context.appColors.neutral 命中真实扩展。
      theme: const ThemeState(themeMode: AppThemeMode.light).getLightTheme(),
      home: child,
    ),
  );
}

void main() {
  setUpAll(_mockPackageInfoChannel);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('「关于」组出现「问题反馈」条目', (tester) async {
    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('问题反馈'), findsOneWidget);
  });

  testWidgets('「问题反馈」条目 trailing 是 open_in_new 外链图标',
      (tester) async {
    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    // 找到 ListTile 后检查 trailing
    final tile = find.widgetWithText(ListTile, '问题反馈');
    expect(tile, findsOneWidget);
    final listTile = tester.widget<ListTile>(tile);
    expect(listTile.trailing, isA<Icon>());
    expect((listTile.trailing! as Icon).icon, Icons.open_in_new);
  });

  testWidgets('点击「问题反馈」条目 onTap 不抛异常', (tester) async {
    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('问题反馈'));
    await tester.pump(); // 不调用 pumpAndSettle,launchUrl 在测试环境异步等待不会 settle

    // 无异常即通过(launchUrl 抛 PlatformException 被 try/catch 吞掉)
    expect(tester.takeException(), isNull);
  });
}
```

**实现注意**：若 `ThemeState` 构造或 `getLightTheme()` 在测试中因 `AppColors.light` / `AppTypography` 静态初始化抛错，fallback 是直接用 `ThemeData(useMaterial3: true)` 跑——`context.appColors` 在拿不到 extension 时兜底返回 `AppColors.dark`（见 `lib/core/theme/app_colors.dart:381-384`），`neutral` 字段在 dark/light 都存在，测试仍可定位 ListTile 文案与图标。先按上面的 `ThemeState.light` 写，编译/运行报错再退到 fallback。

### Step 2: 运行测试确认 RED

```bash
cd novel_app
flutter test test/unit/screens/settings_feedback_entry_test.dart
```

预期：FAIL（找不到「问题反馈」文案 — 因为还没实现）。

### Step 3: 在 settings_screen.dart 实现入口

修改 `novel_app/lib/screens/settings_screen.dart` 两处。

**3a)** 在「关于」组 `children: [...]` 列表（约第 354 行 `[ ... ]` 末尾、`关于组` 的 `children:` 参数里），**SwitchListTile 获取预览版（行 380-425）之后**追加一个新 `ListTile`：

```dart
ListTile(
  leading: Icon(Icons.feedback_outlined, color: appColors.neutral),
  title: const Text('问题反馈'),
  subtitle: const Text('报告 Bug 或提出功能建议'),
  trailing: const Icon(Icons.open_in_new, size: 18),
  onTap: _openFeedback,
),
```

**3b)** 在 `_SettingsScreenState` 类内（`build` 方法之后、`_getThemeModeText` 之前，约第 512 行附近）追加新方法：

```dart
/// 打开 GitHub issues/new 页,GitHub 会显示 3 个 Issue Forms 模板选择器
/// (Bug 报告 / 功能建议 / 提问),由用户自行选择。
///
/// 异常吞掉(无浏览器等),与 Star 入口 launchUrl 范式一致。
Future<void> _openFeedback() async {
  try {
    await launchUrl(
      Uri.parse('$kGitHubRepo/issues/new'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // 静默
  }
}
```

### Step 4: 运行测试确认 GREEN

```bash
cd novel_app
flutter test test/unit/screens/settings_feedback_entry_test.dart
```

预期：3 个测试全 PASS。

如失败：
- 测试报「找不到 '问题反馈'」 → 检查 ListTile 是否真的添加到「关于」组的 `children` 末尾(注意 SwitchListTile 之后)
- `takeException()` 非 null → 检查 `_openFeedback` try/catch 是否包住整个 `launchUrl` 调用
- platform channel 报 MissingPluginException → 检查 `_mockPackageInfoChannel` 是否在 `setUpAll` 调用,channel 名是否为 `plugins.flutter.io/package_info_plus`

### Step 5: 全量 analyze + 回归

```bash
cd novel_app
flutter analyze
flutter test test/unit/widgets/  # 至少覆盖 Star 入口相关测试不回归
```

预期：analyze 零 warning、相关测试无回归。

### Step 6: 提交

```bash
cd D:/my_space/novel_builder
git add novel_app/lib/screens/settings_screen.dart novel_app/test/unit/screens/settings_feedback_entry_test.dart
git commit -m "feat(settings): 关于组新增「问题反馈」入口跳转 GitHub issues/new"
```

---

## Task 2: 新增 3 个 GitHub Issue Forms 模板

**Files:**
- Create: `.github/ISSUE_TEMPLATE/bug_report.yml`
- Create: `.github/ISSUE_TEMPLATE/feature_request.yml`
- Create: `.github/ISSUE_TEMPLATE/question.yml`

**Interfaces:**
- Consumes: GitHub Issue Forms YAML schema（name / description / title / labels / body）
- Produces: GitHub issues/new 页面显示 3 个模板选项（Bug 报告 / 功能建议 / 提问）,提交后自动打对应 label

### Step 1: 创建 bug_report.yml

新建 `.github/ISSUE_TEMPLATE/bug_report.yml`：

```yaml
name: Bug 报告
description: 报告 App 崩溃、功能异常、提取脚本问题等
title: "[Bug]: "
labels: ["bug"]
body:
  - type: textarea
    id: steps
    attributes:
      label: 复现步骤
      description: 触发该问题的具体步骤(编号列出)
      placeholder: |
        1. 打开「xxx」页面
        2. 点击「xxx」按钮
        3. 输入「xxx」内容
        4. 实际结果与期望不符
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: 期望行为
      description: 你认为应该发生什么
    validations:
      required: false
  - type: textarea
    id: actual
    attributes:
      label: 实际行为
      description: 实际发生了什么,包含错误信息、截图描述等
    validations:
      required: true
  - type: input
    id: app_version
    attributes:
      label: App 版本
      description: "设置 → 关于应用 里的版本号,如 2.0.2-preview.5+114"
      placeholder: "2.0.2-preview.5+114"
    validations:
      required: true
  - type: dropdown
    id: platform
    attributes:
      label: 平台
      options:
        - Android
        - iOS
        - Windows
        - 其他
    validations:
      required: true
  - type: input
    id: site_url
    attributes:
      label: 涉及的小说站点 URL
      description: 如果是站点提取/OCR 问题,填对应小说目录页 URL;否则留空
      placeholder: "https://example.com/book/123"
    validations:
      required: false
  - type: textarea
    id: attachments
    attributes:
      label: 截图 / 日志
      description: 可拖图,可贴 LLM 调用日志(设置 → LLM 调用日志)
    validations:
      required: false
```

### Step 2: 创建 feature_request.yml

新建 `.github/ISSUE_TEMPLATE/feature_request.yml`：

```yaml
name: 功能建议
description: 提出新功能或对现有功能的改进建议
title: "[Feature]: "
labels: ["enhancement"]
body:
  - type: textarea
    id: problem
    attributes:
      label: 想解决的问题 / 场景
      description: 你在什么场景下遇到不便?为什么想做这个?
    validations:
      required: true
  - type: textarea
    id: desired
    attributes:
      label: 期望的效果
      description: 描述你希望的新行为或界面
    validations:
      required: true
  - type: textarea
    id: workaround
    attributes:
      label: 现在的临时办法
      description: 你目前是怎么绕过这个问题的?
    validations:
      required: false
```

### Step 3: 创建 question.yml

新建 `.github/ISSUE_TEMPLATE/question.yml`：

```yaml
name: 提问 / 讨论
description: 使用疑问、配置求助、功能咨询(非 bug 报告)
title: "[Question]: "
labels: ["question"]
body:
  - type: textarea
    id: question
    attributes:
      label: 你的疑问
      description: 把问题说清楚,附上 App 版本与平台会更易得到解答
    validations:
      required: true
  - type: textarea
    id: tried
    attributes:
      label: 已经试过什么
      description: 你查阅了哪些文档/尝试了哪些操作
    validations:
      required: false
```

### Step 4: YAML 语法校验

任一文件用 Python yaml 模块解析（避免 GitHub 不识别 = 用户看不到模板选择器）：

```bash
cd D:/my_space/novel_builder
python -c "
import yaml, sys
for f in ['.github/ISSUE_TEMPLATE/bug_report.yml', '.github/ISSUE_TEMPLATE/feature_request.yml', '.github/ISSUE_TEMPLATE/question.yml']:
    with open(f, encoding='utf-8') as fh:
        try:
            yaml.safe_load(fh)
            print(f'{f}: OK')
        except yaml.YAMLError as e:
            print(f'{f}: FAIL - {e}')
            sys.exit(1)
"
```

预期：3 个文件全部 `OK`。

### Step 5: 提交（不 push）

```bash
cd D:/my_space/novel_builder
git add .github/ISSUE_TEMPLATE/
git commit -m "chore(issue-template): 新增 Bug 报告/功能建议/提问三类 Issue Forms 模板"
```

**push 到 GitHub 在执行阶段与用户确认**(模板需要 push 到远端才能在 issues/new 出现)。建议下一步 `git push origin master`,push 后到 https://github.com/yunkst/novel_builder/issues/new 验证 3 个模板选项是否正常显示。

---

## Self-Review

- **Spec 覆盖**：
  - A. 设置页入口（spec §2.1）→ Task 1 ✓
  - B. 3 个 Issue Forms YAML（spec §2.2 模板 1/2/3）→ Task 2 三步骤 ✓
  - C. 错误处理（spec §2.3 launchUrl 静默）→ Task 1 Step 3b ✓
  - C. widget 测试（spec §3.1）→ Task 1 Step 1 ✓
  - 验收标准 1-5（spec §5）→ 覆盖在 Task 1 Step 4-5 + Task 2 Step 4-5 ✓
- **占位符扫描**：Task 1 Step 1 测试代码已给出完整 import / mock handler / `_FakeBackupService` / `_wrap` / 3 个测试用例，无 `TBD`/`TODO`/`类似 Task N`。Theme provider 经确认走 PreferencesService 单例（`setMockInitialValues` 可穿透），已明确"无需 override"；附 fallback 说明（`ThemeState.light` 报错退到 `ThemeData` + `AppColors` 兜底），属可执行兜底而非占位
- **类型一致性**：
  - `_openFeedback` 在 Step 3b 定义、在 Step 3a 引用 — 一致
  - `kGitHubRepo` URL 在 spec / Task 1 Step 3b / 验收标准 — 一致
  - 模板文件名 / labels / 字段 id — 一致
