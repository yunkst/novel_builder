# GitHub Star 引导功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在「随心阅读」App 中加入引导用户去 GitHub 点 star 的功能，包括启动条件弹窗 + 设置页常驻入口，零后端纯本地实现。

**Architecture:** 单例 `StarPromptService` 管理 4 个 SharedPreferences key + 四门槛判定；`StarPromptDialog` 仿 `CrashReportDialog` 两按钮范式；启动挂钩点复用 `main.dart` HomePage `initState` post-frame callback（与 `NativeCrashReporter.checkAndReport` 并列）；设置页加一行 `ListTile`。

**Tech Stack:** Flutter 3.0+ / Dart 3.0+ / Riverpod（仅复用现有 `preferencesServiceProvider`）/ `shared_preferences`（已有）/ `url_launcher ^6.2.0`（已有）/ `flutter_test` + `shared_preferences` mock 注入。

## Global Constraints

- **4 个 preferences key 字面值固定**：`star_prompt_install_time`（int ms 时间戳） / `star_prompt_launch_count`（int） / `star_prompt_dismissed`（bool） / `star_prompt_next_show_time`（int ms 时间戳）
- **4 门槛常量字面值固定**：`_launchThreshold = 7` / `_installDaysThreshold = 3` / `_cooldownDays = 7` / 1 天 = 86400000 ms
- **复用 `kGitHubRepo` 常量**：从 `lib/services/native_crash_reporter.dart:27` import，不重新定义
- **不引入新依赖**：url_launcher / shared_preferences / package_info_plus 全在 pubspec
- **测试注入**：`SharedPreferences.setMockInitialValues({})` + `StarPromptService.resetForTest()` 范式（仿 `RetrySignals.resetForTest`）
- **不阻塞启动**：service 异常一律 try-catch 吞掉（仿 `NativeCrashReporter.checkAndReport` 范式）
- **commit 规范**：chinese-commit-conventions（type 英文 + scope 中文 + subject 中文动宾）
- **单 commit / task**：每个 task 结束独立 commit
- **零业务代码外影响**：不动 novel_agent / repositories / 数据库 schema / 后端 / CI workflow
- **复用现有 widget**：`_SettingsSection` 包裹 `ListTile` 模式（`lib/screens/settings_screen.dart:592`）；dialog 仿 `CrashReportDialog` AlertDialog + icon + content + actions 结构

---

## File Structure

### 新建（3 个）

| 文件 | 职责 |
|---|---|
| `lib/services/star_prompt_service.dart` | 单例服务。管 4 个 preferences key + `recordLaunch()` / `shouldShow()` / `onStarClicked()` / `onDismissed()` / `resetForTest()` |
| `lib/widgets/star_prompt_dialog.dart` | StatelessWidget。两按钮 + 文案。`showDialog<bool>` 返回 true=点主按钮，false=关闭 |
| `test/unit/services/star_prompt_service_test.dart` | 6 个 unit test 覆盖 4 公共方法 + 4 门槛矩阵 |
| `test/unit/widgets/star_prompt_dialog_test.dart` | 2 个 widget test 验证按钮 pop 值 + 文案关键句命中 |

### 修改（2 个）

| 文件 | 改动 |
|---|---|
| `lib/main.dart` | HomePage `_HomePageState.initState` post-frame callback，在 `NativeCrashReporter.checkAndReport` 后并列调用 `StarPromptService` 检查 + 弹窗 |
| `lib/screens/settings_screen.dart` | 加一个 `_SettingsSection`（或合并到现有"关于"段）含一行 `ListTile`（leading `Icons.star_outline`）tap 跳 `kGitHubRepo` |

### 复用（已存在）

- `lib/services/native_crash_reporter.dart:27` 的 `kGitHubRepo = 'https://github.com/yunkst/novel_builder'` —— import 复用
- `lib/services/preferences_service.dart` —— 已有 `getInt/setInt/getBool/setBool`
- `lib/widgets/crash_report_dialog.dart` —— dialog 结构范式

---

## Task 1: StarPromptService 基础 + recordLaunch

**Files:**
- Create: `lib/services/star_prompt_service.dart`
- Test: `test/unit/services/star_prompt_service_test.dart`

**Interfaces:**
- Consumes: `PreferencesService.instance.getInt/setInt/getBool/setBool`（已有）
- Produces: `StarPromptService.instance.recordLaunch()` —— 首次启动写 `install_time=now` + `launch_count=1`；非首次 `launch_count++`

- [ ] **Step 1: 创建 StarPromptService 空类（让编译过）**

创建 `lib/services/star_prompt_service.dart`：

```dart
/// GitHub Star 引导服务。
///
/// 管理 4 个 SharedPreferences key，控制启动时的 star 弹窗门槛与冷却：
/// - `star_prompt_install_time` (int ms 时间戳) 首次启动记录
/// - `star_prompt_launch_count` (int) 启动次数计数
/// - `star_prompt_dismissed` (bool) true = 永久不再弹（主按钮触发）
/// - `star_prompt_next_show_time` (int ms 时间戳) 下次允许弹窗时间（关闭按钮写）
///
/// 单例（仿 [NativeCrashReporter]），用 [PreferencesService.instance] 持久化。
library;

import 'preferences_service.dart';

class StarPromptService {
  StarPromptService._();

  static final StarPromptService instance = StarPromptService._();

  // preferences key（spec 固定字面值，不改）
  static const String _kInstallTime = 'star_prompt_install_time';
  static const String _kLaunchCount = 'star_prompt_launch_count';
  static const String _kDismissed = 'star_prompt_dismissed';
  static const String _kNextShowTime = 'star_prompt_next_show_time';

  // 门槛常量（spec 固定字面值，不改）
  static const int _launchThreshold = 7;
  static const int _installDaysThreshold = 3;
  static const int _cooldownDays = 7;
  static const int _msPerDay = 86400000;
}
```

- [ ] **Step 2: 创建测试文件骨架（一个测试 1 个 import + 1 个 setUp 即可）**

创建 `test/unit/services/star_prompt_service_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/services/star_prompt_service.dart';
import 'package:novel_app/services/preferences_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StarPromptService.instance.resetForTest();
  });

  test('recordLaunch 首次启动写入 install_time + count=1', () async {
    final beforeMs = DateTime.now().millisecondsSinceEpoch;
    await StarPromptService.instance.recordLaunch();
    final afterMs = DateTime.now().millisecondsSinceEpoch;

    final installTime = await PreferencesService.instance.getInt(
      'star_prompt_install_time',
    );
    final count = await PreferencesService.instance.getInt(
      'star_prompt_launch_count',
    );

    expect(installTime, greaterThanOrEqualTo(beforeMs));
    expect(installTime, lessThanOrEqualTo(afterMs));
    expect(count, 1);
  });
}
```

- [ ] **Step 3: 跑测试验证 RED（resetForTest 缺失导致编译错）**

Run: `cd novel_app && flutter test test/unit/services/star_prompt_service_test.dart`
Expected: COMPILE ERROR（`resetForTest` 方法不存在）

- [ ] **Step 4: 实现 resetForTest 桩（让编译过，但仍 RED）**

在 `StarPromptService` 类内加：

```dart
  /// 测试用：清全部 4 个 key + 重新初始化。
  Future<void> resetForTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kInstallTime);
    await prefs.remove(_kLaunchCount);
    await prefs.remove(_kDismissed);
    await prefs.remove(_kNextShowTime);
  }
```

- [ ] **Step 5: 跑测试验证 RED（recordLaunch 方法不存在）**

Run: `cd novel_app && flutter test test/unit/services/star_prompt_service_test.dart`
Expected: COMPILE ERROR（`recordLaunch` 方法不存在）

- [ ] **Step 6: 实现 recordLaunch 最小代码（让测试 GREEN）**

在 `StarPromptService` 类内 `resetForTest` 后加：

```dart
  /// 启动时调用：首次写 install_time + count=1；非首次 count++。
  Future<void> recordLaunch() async {
    final prefs = await PreferencesService.instance.getInstance();
    final hasInstallTime = prefs.containsKey(_kInstallTime);
    if (!hasInstallTime) {
      await PreferencesService.instance.setInt(
        _kInstallTime,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    final current = await PreferencesService.instance.getInt(_kLaunchCount);
    await PreferencesService.instance.setInt(_kLaunchCount, current + 1);
  }
```

- [ ] **Step 7: 跑测试验证 GREEN**

Run: `cd novel_app && flutter test test/unit/services/star_prompt_service_test.dart`
Expected: PASS（1 test passed）

- [ ] **Step 8: 补一个测试：非首次启动 count 累加**

在 `test/unit/services/star_prompt_service_test.dart` 的 `main()` 末尾、`test(...)` 之前加：

```dart
  test('recordLaunch 非首次启动 count 累加 + install_time 不变', () async {
    // 模拟已有状态：install_time 是昨天，count=3
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'star_prompt_install_time': yesterday,
      'star_prompt_launch_count': 3,
    });

    await StarPromptService.instance.recordLaunch();

    final installTime = await PreferencesService.instance.getInt(
      'star_prompt_install_time',
    );
    final count = await PreferencesService.instance.getInt(
      'star_prompt_launch_count',
    );

    expect(installTime, yesterday);
    expect(count, 4);
  });
```

- [ ] **Step 9: 跑全部测试验证 GREEN**

Run: `cd novel_app && flutter test test/unit/services/star_prompt_service_test.dart`
Expected: PASS（2 tests passed）

- [ ] **Step 10: Commit**

```bash
git add lib/services/star_prompt_service.dart test/unit/services/star_prompt_service_test.dart
git commit -m "feat(star引导): 新增 StarPromptService 基础 + recordLaunch"
```

---

## Task 2: shouldShow 四门槛判定

**Files:**
- Modify: `lib/services/star_prompt_service.dart`
- Modify: `test/unit/services/star_prompt_service_test.dart`

**Interfaces:**
- Consumes: 4 个 preferences key 读取（已有 from Task 1）
- Produces: `StarPromptService.instance.shouldShow() -> Future<bool>` —— 四门槛全满足返回 true

- [ ] **Step 1: 在测试文件加 4 门槛矩阵测试（全 RED）**

在 `test/unit/services/star_prompt_service_test.dart` 的 `main()` 末尾、最后一个 `test(...)` 之后加：

```dart
  group('shouldShow 四门槛判定', () {
    /// 辅助：构造「四门槛全满足」的初始 prefs（now=基准时间，count=7，install=4天前，无 dismiss，无 next_show）
    Future<void> setupAllMet() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'star_prompt_install_time': now - 4 * 86400000,
        'star_prompt_launch_count': 7,
        'star_prompt_dismissed': false,
        'star_prompt_next_show_time': 0,
      });
      await StarPromptService.instance.resetForTest();
    }

    test('门槛 1: launch_count < 7 → false', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'star_prompt_install_time': now - 4 * 86400000,
        'star_prompt_launch_count': 6,
      });
      await StarPromptService.instance.resetForTest();

      expect(await StarPromptService.instance.shouldShow(), isFalse);
    });

    test('门槛 2: install_time 距今 < 3 天 → false', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'star_prompt_install_time': now - 2 * 86400000,
        'star_prompt_launch_count': 7,
      });
      await StarPromptService.instance.resetForTest();

      expect(await StarPromptService.instance.shouldShow(), isFalse);
    });

    test('门槛 3: dismissed = true → false（永久关闭）', () async {
      await setupAllMet();
      await PreferencesService.instance.setBool('star_prompt_dismissed', true);

      expect(await StarPromptService.instance.shouldShow(), isFalse);
    });

    test('门槛 4: now < next_show_time → false（关闭冷却期内）', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'star_prompt_install_time': now - 4 * 86400000,
        'star_prompt_launch_count': 7,
        'star_prompt_dismissed': false,
        'star_prompt_next_show_time': now + 5 * 86400000, // 5 天后
      });
      await StarPromptService.instance.resetForTest();

      expect(await StarPromptService.instance.shouldShow(), isFalse);
    });

    test('四门槛全满足 → true', () async {
      await setupAllMet();

      expect(await StarPromptService.instance.shouldShow(), isTrue);
    });
  });
```

- [ ] **Step 2: 跑测试验证 RED（shouldShow 不存在）**

Run: `cd novel_app && flutter test test/unit/services/star_prompt_service_test.dart`
Expected: COMPILE ERROR（`shouldShow` 方法不存在）

- [ ] **Step 3: 实现 shouldShow（让全部 5 个新测试 GREEN）**

在 `StarPromptService` 类内 `recordLaunch` 后加：

```dart
  /// 是否应该弹窗（四门槛全满足）。
  ///
  /// 1. dismissed != true
  /// 2. launch_count >= 7
  /// 3. now - install_time >= 3 天
  /// 4. now >= next_show_time
  Future<bool> shouldShow() async {
    try {
      final dismissed =
          await PreferencesService.instance.getBool(_kDismissed);
      if (dismissed) return false;

      final count = await PreferencesService.instance.getInt(_kLaunchCount);
      if (count < _launchThreshold) return false;

      final installTime =
          await PreferencesService.instance.getInt(_kInstallTime);
      if (installTime == 0) return false;
      final daysSinceInstall =
          (DateTime.now().millisecondsSinceEpoch - installTime) ~/ _msPerDay;
      if (daysSinceInstall < _installDaysThreshold) return false;

      final nextShowTime =
          await PreferencesService.instance.getInt(_kNextShowTime);
      if (DateTime.now().millisecondsSinceEpoch < nextShowTime) return false;

      return true;
    } catch (_) {
      // 任何异常默认不弹，绝不阻塞启动。
      return false;
    }
  }
```

- [ ] **Step 4: 跑全部测试验证 GREEN**

Run: `cd novel_app && flutter test test/unit/services/star_prompt_service_test.dart`
Expected: PASS（2 from Task 1 + 5 from Task 2 = 7 tests passed）

- [ ] **Step 5: Commit**

```bash
git add lib/services/star_prompt_service.dart test/unit/services/star_prompt_service_test.dart
git commit -m "feat(star引导): shouldShow 四门槛判定 + 5 个矩阵测试"
```

---

## Task 3: onStarClicked + onDismissed

**Files:**
- Modify: `lib/services/star_prompt_service.dart`
- Modify: `test/unit/services/star_prompt_service_test.dart`

**Interfaces:**
- Produces:
  - `StarPromptService.instance.onStarClicked() -> Future<void>` —— 写 `dismissed = true`
  - `StarPromptService.instance.onDismissed() -> Future<void>` —— 写 `next_show_time = now + 7 天`

- [ ] **Step 1: 加 2 个测试（先 RED）**

在 `test/unit/services/star_prompt_service_test.dart` 的 `main()` 末尾加：

```dart
  test('onStarClicked 写 dismissed=true', () async {
    final beforeMs = DateTime.now().millisecondsSinceEpoch;
    await StarPromptService.instance.onStarClicked();
    final afterMs = DateTime.now().millisecondsSinceEpoch;

    final dismissed = await PreferencesService.instance.getBool(
      'star_prompt_dismissed',
    );
    expect(dismissed, isTrue);

    // 验证后续 shouldShow 永远 false（即使其他条件满足）
    SharedPreferences.setMockInitialValues({
      'star_prompt_install_time': beforeMs - 4 * 86400000,
      'star_prompt_launch_count': 7,
      'star_prompt_dismissed': true,
      'star_prompt_next_show_time': 0,
    });
    expect(await StarPromptService.instance.shouldShow(), isFalse);
  });

  test('onDismissed 写 next_show_time = now + 7 天，冷却期内不弹，7 天后恢复', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await StarPromptService.instance.onDismissed();

    final nextShow = await PreferencesService.instance.getInt(
      'star_prompt_next_show_time',
    );
    final sevenDaysLater = now + 7 * 86400000;
    // 允许 ±1000ms 时序误差
    expect(nextShow, greaterThanOrEqualTo(sevenDaysLater - 1000));
    expect(nextShow, lessThanOrEqualTo(sevenDaysLater + 1000));

    // 验证冷却期内不弹
    SharedPreferences.setMockInitialValues({
      'star_prompt_install_time': now - 4 * 86400000,
      'star_prompt_launch_count': 7,
      'star_prompt_dismissed': false,
      'star_prompt_next_show_time': now + 5 * 86400000, // 5 天后到期
    });
    expect(await StarPromptService.instance.shouldShow(), isFalse);
  });
```

- [ ] **Step 2: 跑测试验证 RED（方法不存在）**

Run: `cd novel_app && flutter test test/unit/services/star_prompt_service_test.dart`
Expected: COMPILE ERROR（`onStarClicked` / `onDismissed` 不存在）

- [ ] **Step 3: 实现 onStarClicked + onDismissed**

在 `StarPromptService` 类内 `shouldShow` 后加：

```dart
  /// 主按钮「⭐ 去 GitHub 点 Star」触发：标记永久关闭。
  ///
  /// 调用方负责 launchUrl（service 不依赖 url_launcher，方便单测）。
  Future<void> onStarClicked() async {
    await PreferencesService.instance.setBool(_kDismissed, true);
  }

  /// 关闭按钮触发：写冷却期，下次可弹时间 = now + 7 天。
  Future<void> onDismissed() async {
    final nextShow =
        DateTime.now().millisecondsSinceEpoch + _cooldownDays * _msPerDay;
    await PreferencesService.instance.setInt(_kNextShowTime, nextShow);
  }
```

- [ ] **Step 4: 跑全部测试验证 GREEN**

Run: `cd novel_app && flutter test test/unit/services/star_prompt_service_test.dart`
Expected: PASS（7 from Task 2 + 2 from Task 3 = 9 tests passed）

- [ ] **Step 5: 全栈 analyze 验证干净**

Run: `cd novel_app && flutter analyze lib/services/star_prompt_service.dart test/unit/services/star_prompt_service_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/services/star_prompt_service.dart test/unit/services/star_prompt_service_test.dart
git commit -m "feat(star引导): onStarClicked 永久关闭 + onDismissed 7 天冷却"
```

---

## Task 4: StarPromptDialog

**Files:**
- Create: `lib/widgets/star_prompt_dialog.dart`
- Test: `test/unit/widgets/star_prompt_dialog_test.dart`

**Interfaces:**
- Consumes: 无（纯 UI 组件）
- Produces: `StarPromptDialog` StatelessWidget；调用 `showDialog<bool>(builder: (_) => StarPromptDialog())` 返回 `true`（点主按钮跳 GitHub）或 `false`（点关闭）

- [ ] **Step 1: 创建测试文件**

创建 `test/unit/widgets/star_prompt_dialog_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/widgets/star_prompt_dialog.dart';

void main() {
  testWidgets('点主按钮 pop true', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const StarPromptDialog(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 主按钮文案包含「Star」
    await tester.tap(find.textContaining('Star'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('点「关闭」pop false + 文案关键句命中', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const StarPromptDialog(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 文案关键句必须命中
    expect(find.textContaining('开源'), findsOneWidget);
    expect(find.textContaining('Star'), findsWidgets);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
```

- [ ] **Step 2: 跑测试验证 RED**

Run: `cd novel_app && flutter test test/unit/widgets/star_prompt_dialog_test.dart`
Expected: COMPILE ERROR（`StarPromptDialog` 类不存在）

- [ ] **Step 3: 实现 StarPromptDialog**

创建 `lib/widgets/star_prompt_dialog.dart`：

```dart
/// GitHub Star 引导弹框。
///
/// 两按钮 + 真垦文桉：
/// - 主按钮「⭐ 去 GitHub 点 Star」→ pop(true)，调用方负责 launchUrl
/// - 「关闭」→ pop(false)，调用方负责写冷却期
///
/// 仿 [CrashReportDialog] 结构（AlertDialog + icon + content + actions），
/// 但内容更轻量（无 SelectableText / 无 Scrollbar）。
library;

import 'package:flutter/material.dart';

class StarPromptDialog extends StatelessWidget {
  const StarPromptDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      icon: Icon(Icons.star_outline, color: cs.primary, size: 40),
      title: const Text('喜欢「随心阅读」？'),
      content: const Text(
        '这是一个完全开源、免费、无广告的小说阅读 App。\n\n'
        '如果它对你有帮助，能不能顺手去 GitHub 点个 ⭐ Star？\n\n'
        'Star 对独立开发者意义重大——它能让更多人发现这个项目，'
        '也是支持我继续维护和更新的最大动力。只需点一下，几秒钟就好。',
        style: TextStyle(height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('关闭'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.star, size: 18),
          label: const Text('去 GitHub 点 Star'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 跑全部测试验证 GREEN**

Run: `cd novel_app && flutter test test/unit/widgets/star_prompt_dialog_test.dart`
Expected: PASS（2 tests passed）

- [ ] **Step 5: analyze 验证干净**

Run: `cd novel_app && flutter analyze lib/widgets/star_prompt_dialog.dart test/unit/widgets/star_prompt_dialog_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/star_prompt_dialog.dart test/unit/widgets/star_prompt_dialog_test.dart
git commit -m "feat(star引导): StarPromptDialog 两按钮 + 真垦文桉"
```

---

## Task 5: main.dart 启动挂钩

**Files:**
- Modify: `lib/main.dart`（在 `_HomePageState.initState` post-frame callback 内）

**Interfaces:**
- Consumes: `StarPromptService.instance.recordLaunch/shouldShow/onStarClicked/onDismissed`（Task 1-3）
- Consumes: `kGitHubRepo` 常量 + `url_launcher`（已有 from `native_crash_reporter.dart`）
- Consumes: `StarPromptDialog`（Task 4）

- [ ] **Step 1: 在 post-frame callback 内加 star 引导逻辑**

读 `lib/main.dart:312-317` 现有 post-frame callback（位于 `_HomePageState.initState`）：

```dart
    // 检测上次 native crash：post-frame 后弹框（需要 BuildContext）。
    // 只弹一次（_HomePageState 在 app 生命周期内只 initState 一次）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NativeCrashReporter.checkAndReport(context);
    });
```

替换为：

```dart
    // post-frame 后检查（crash 优先，star 其后；互不干扰）。
    // 只检查一次（_HomePageState 在 app 生命周期内只 initState 一次）。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // 1. 上次 native crash 报告
      await NativeCrashReporter.checkAndReport(context);
      if (!mounted) return;

      // 2. GitHub star 引导
      try {
        await StarPromptService.instance.recordLaunch();
        if (!mounted) return;
        final shouldShow = await StarPromptService.instance.shouldShow();
        if (!shouldShow || !mounted) return;
        final goStar = await showDialog<bool>(
          context: context,
          builder: (_) => const StarPromptDialog(),
        );
        if (goStar == true) {
          await StarPromptService.instance.onStarClicked();
          await launchUrl(Uri.parse(kGitHubRepo),
              mode: LaunchMode.externalApplication);
        } else {
          await StarPromptService.instance.onDismissed();
        }
      } catch (_) {
        // 任何异常吞掉，绝不阻塞启动。
      }
    });
```

- [ ] **Step 2: 加 import 头**

在 `lib/main.dart` 顶部 import 区（已有 `import 'package:url_launcher/url_launcher.dart';` 附近）加：

```dart
import 'services/star_prompt_service.dart';
import 'widgets/star_prompt_dialog.dart';
import 'services/native_crash_reporter.dart' show kGitHubRepo;
```

注：`kGitHubRepo` 是 `native_crash_reporter.dart` 的顶层 const string，可直接 `show kGitHubRepo` 引入，避免拉入整个文件。

- [ ] **Step 3: analyze 验证**

Run: `cd novel_app && flutter analyze lib/main.dart`
Expected: `No issues found!`

- [ ] **Step 4: 跑全 service 单测确认没回归**

Run: `cd novel_app && flutter test test/unit/services/star_prompt_service_test.dart test/unit/widgets/star_prompt_dialog_test.dart`
Expected: PASS（11 tests passed = 9 service + 2 dialog）

- [ ] **Step 5: 跑所在目录 analyze 验证没影响其他文件**

Run: `cd novel_app && flutter analyze lib/main.dart lib/services/ lib/widgets/`
Expected: `No issues found!`（或仅有既存 info 级警告）

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "feat(star引导): main.dart 启动挂钩 - recordLaunch + shouldShow + 弹窗"
```

---

## Task 6: settings_screen.dart 常驻入口

**Files:**
- Modify: `lib/screens/settings_screen.dart`

**Interfaces:**
- Consumes: `kGitHubRepo`（已有）+ `url_launcher.launchUrl`（已有）
- Produces: 设置页加一行 `ListTile`（leading `Icons.star_outline`，title「支持项目 · 去 GitHub 点 Star」），tap 跳 `kGitHubRepo`

- [ ] **Step 1: 找现有「关于」段位置**

读 `lib/screens/settings_screen.dart`，找到「关于 / 关于本 App / 版本号」所在 `_SettingsSection`（应在 350-400 行附近，参考 `grep -n ListTile lib/screens/settings_screen.dart` 定位）。

如果已有「关于」段（含版本号 / 仓库地址 ListTile），在它**上方或下方**新加一个 `_SettingsSection` 标题「支持项目」+ 一行 `ListTile`。
如果没有「关于」段，在设置页底部最后一段后追加新 `_SettingsSection`。

- [ ] **Step 2: 加新段 + ListTile**

在 `lib/screens/settings_screen.dart` 现有「关于」段（若有）的 `_SettingsSection` **之后**，加新段：

```dart
              const _SettingsSection(
                title: '支持项目',
                children: [
                  ListTile(
                    leading: Icon(Icons.star_outline),
                    title: Text('支持项目 · 去 GitHub 点 Star'),
                    subtitle: Text('「随心阅读」是开源免费项目，欢迎点 Star 支持'),
                    trailing: Icon(Icons.open_in_new, size: 18),
                    onTap: () async {
                      try {
                        await launchUrl(Uri.parse(kGitHubRepo),
                            mode: LaunchMode.externalApplication);
                      } catch (_) {
                        // 异常吞掉（无浏览器等）
                      }
                    },
                  ),
                ],
              ),
```

如果用追加方式（无现有「关于」段可放），加在 `Scaffold` 的 `body` 列表最后。

- [ ] **Step 3: 加 import 头**

在 `lib/screens/settings_screen.dart` 顶部 import 区加：

```dart
import 'package:url_launcher/url_launcher.dart';
import '../services/native_crash_reporter.dart' show kGitHubRepo;
```

（如果该文件已 import `url_launcher` 则跳过第一个。）

- [ ] **Step 4: analyze 验证**

Run: `cd novel_app && flutter analyze lib/screens/settings_screen.dart`
Expected: `No issues found!`（或仅有既存 info 级警告）

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat(star引导): 设置页加常驻 Star 入口"
```

---

## Task 7: 集成验证 + 手动验收清单

**Files:**
- Create: `docs/superpowers/plans/2026-07-28-github-star-prompt-manual-test-checklist.md`（验收清单产出物，不影响代码）

- [ ] **Step 1: 跑全 novel_app analyze**

Run: `cd novel_app && flutter analyze`
Expected: `No issues found!`（或仅有既存 info 级警告，不含本功能引入的新 issue）

- [ ] **Step 2: 跑全 novel_app test 套件（本功能相关 + 邻接）**

Run: `cd novel_app && flutter test test/unit/services/star_prompt_service_test.dart test/unit/widgets/star_prompt_dialog_test.dart`
Expected: PASS（11 tests passed）

- [ ] **Step 3: 跑邻接 widget 单测（不破其他）**

Run: `cd novel_app && flutter test test/unit/widgets/crash_report_dialog_test.dart 2>/dev/null || echo "（无此测试文件，跳过）"`
Expected: PASS 或「无此文件」

- [ ] **Step 4: 跑全 novel_app test 套件**

Run: `cd novel_app && flutter test --no-pub 2>&1 | tail -30`
Expected: 大部分 PASS，可能有既存的 bug/repro 失败（与本功能无关，按 git status 现状接受）

- [ ] **Step 5: 写手动验收清单到 docs**

创建 `docs/superpowers/plans/2026-07-28-github-star-prompt-manual-test-checklist.md`：

```markdown
# GitHub Star 引导功能 · 手动验收清单

**日期**: 2026-07-28
**功能范围**: StarPromptService + StarPromptDialog + main.dart 启动挂钩 + 设置页常驻入口

---

## 1. 全新安装路径

| # | 操作 | 预期 | 结果 |
|---|---|---|---|
| 1.1 | 全新安装（卸载重装或清数据）后启动 App | 不弹 star 弹窗（count=1，未达 7） | ☐ |
| 1.2 | 重启 6 次（每次退出再开，count 累加到 6，仍不足 3 天） | 第 6 次启动不弹 | ☐ |
| 1.3 | 改系统时间到 4 天后，重启 App（count=7 + install 满 3 天 + 无 dismiss + 无 next_show） | 弹出 star 弹窗 | ☐ |
| 1.4 | 弹窗文案含「开源」「Star」「GitHub」字样 | 全部命中 | ☐ |
| 1.5 | 弹窗有两个按钮：「去 GitHub 点 Star」+「关闭」 | 2 个 | ☐ |

## 2. 主按钮路径

| # | 操作 | 预期 | 结果 |
|---|---|---|---|
| 2.1 | 点「去 GitHub 点 Star」 | 跳转到 https://github.com/yunkst/novel_builder，弹窗关闭 | ☐ |
| 2.2 | 主按钮点过后再重启 App | 不再弹（永久关闭） | ☐ |
| 2.3 | 检查 SharedPreferences（设置 → 关于 → debug 或 adb 命令） | `star_prompt_dismissed = true` | ☐ |

## 3. 关闭路径

| # | 操作 | 预期 | 结果 |
|---|---|---|---|
| 3.1 | 满足门槛时点「关闭」 | 弹窗关闭，不跳转 | ☐ |
| 3.2 | 立即重启 App | 不弹（冷却期内） | ☐ |
| 3.3 | 改系统时间到 7 天后，重启 App（4 门槛全满足） | 再次弹窗 | ☐ |
| 3.4 | 检查 SharedPreferences | `star_prompt_next_show_time ≈ now + 7 天` | ☐ |

## 4. 设置页常驻入口

| # | 操作 | 预期 | 结果 |
|---|---|---|---|
| 4.1 | 打开设置页，滚到「支持项目」段 | 看到「支持项目 · 去 GitHub 点 Star」ListTile | ☐ |
| 4.2 | ListTile leading 是 `Icons.star_outline` 图标 | 星星轮廓 | ☐ |
| 4.3 | ListTile trailing 是 `Icons.open_in_new` 图标 | 外部链接图标 | ☐ |
| 4.4 | 点击该 ListTile | 跳转到 https://github.com/yunkst/novel_builder | ☐ |
| 4.5 | 即使点过主按钮（永久关闭弹窗），该入口仍在 | 可用 | ☐ |

## 5. 边界与异常

| # | 操作 | 预期 | 结果 |
|---|---|---|---|
| 5.1 | 卸载重装清数据 | 4 个 key 全部清空，install_time 重新记录 | ☐ |
| 5.2 | 关闭网络后启动 App（满足门槛） | 弹窗正常显示（外链跳转会失败被 catch） | ☐ |
| 5.3 | 同时存在 native crash dump | crash 弹窗优先弹出，关闭后才弹 star 弹窗（或不弹） | ☐ |
| 5.4 | launchUrl 失败（无浏览器等异常） | 弹窗已关闭、状态已写，App 不崩 | ☐ |

---

**验收人**: _______________
**日期**: _______________
**结果**: ☐ 全部通过 / ☐ 有项未通过（请注明）
```

- [ ] **Step 6: Commit 验收清单**

```bash
git add docs/superpowers/plans/2026-07-28-github-star-prompt-manual-test-checklist.md
git commit -m "docs(star引导): 手动验收清单（5 大场景 17 项）"
```

---

## Self-Review

**1. Spec coverage**（spec 章节 vs 任务）：

| spec 章节 | 覆盖 task |
|---|---|
| 2.1 双轨形态（设置入口 + 启动弹窗） | Task 6（设置）+ Task 5（启动） |
| 2.2 弹窗触发门槛（4 门槛） | Task 2（shouldShow 4 门槛测试） |
| 2.3 弹窗按钮（主按钮永久关 / 关闭冷却 7 天） | Task 3（onStarClicked/onDismissed）+ Task 4（dialog UI） |
| 2.4 持久化（4 个 preferences key） | Task 1（resetForTest 桩）+ Task 2/3（读写） |
| 3. 文件清单（2 新建 + 2 修改） | Task 1-6 全覆盖 |
| 4.1 service API（4 方法） | Task 1-3 |
| 4.2 触发时序（main.dart post-frame） | Task 5 |
| 4.3 弹窗文案 | Task 4 |
| 5. 测试策略（unit + widget + 手动） | Task 1-3（service unit）+ Task 4（widget）+ Task 7（手动清单） |
| 6. 边界与降级（launchUrl 失败 / prefs 异常） | Task 3 service catch / Task 5 main.dart try-catch / Task 6 settings tap try-catch |
| 7. YAGNI（不做项） | 不在 plan 中实现 |

**2. Placeholder scan**：
- ❌ 无 TBD / TODO / "implement later" / "add appropriate error handling"
- ❌ 无 "Similar to Task N" 省略
- ❌ 无 "fill in details" 含糊措辞
- ❌ 所有 API 名字（`shouldShow` / `onStarClicked` / `onDismissed` / `recordLaunch` / `resetForTest`）全文一致
- ❌ 所有 preferences key（`star_prompt_install_time` / `star_prompt_launch_count` / `star_prompt_dismissed` / `star_prompt_next_show_time`）全文一致
- ❌ 复用 `kGitHubRepo`（不重复定义）
- ⚠️ Task 1 Step 1 / Task 4 Step 3 写实现时，文案中有「包含『Star』」这类描述，落到代码里已经是完整代码，无 placeholder

**3. Type consistency**：
- `recordLaunch() -> Future<void>` Task 1 定义 → Task 5 调用 ✓
- `shouldShow() -> Future<bool>` Task 2 定义 → Task 5 调用 ✓
- `onStarClicked() -> Future<void>` Task 3 定义 → Task 5 调用 ✓
- `onDismissed() -> Future<void>` Task 3 定义 → Task 5 调用 ✓
- `resetForTest() -> Future<void>` Task 1 定义 → Task 1/2/3 测试 setUp 调用 ✓
- 4 个 preferences key Task 1 定义 → Task 2/3 测试 + 实现全文一致 ✓
- `_launchThreshold = 7` / `_installDaysThreshold = 3` / `_cooldownDays = 7` / `_msPerDay = 86400000` Task 1 定义 → Task 2 shouldShow + Task 3 onDismissed 使用 ✓
- `showDialog<bool>(builder: (_) => StarPromptDialog())` Task 4 定义 → Task 5 调用 ✓

无一致性冲突。
