# GitHub Star 引导功能设计

**日期**: 2026-07-28
**状态**: 已确认（待 spec review）
**分支**: master

---

## 1. 背景与目标

「随心阅读」是开源免费 App。GitHub Star 是开源项目最重要的曝光与反馈信号（影响 GitHub 搜索排序、潜在贡献者发现、作者持续维护动力）。当前 App 完全没有引导点 star 的入口，活跃用户也无从得知项目开源。

**目标**：在不打扰用户阅读体验的前提下，把留存用户引导到 GitHub 仓库点 star，提升项目 star 数。

**非目标**：
- 不做强制弹窗、不做频繁打扰
- 不做付费/评分引导（仅 star）
- 不后端化（纯本地 SharedPreferences 判定）

---

## 2. 设计要点

### 2.1 双轨形态

| 轨道 | 位置 | 触发 | 作用 |
|---|---|---|---|
| **A. 设置页常驻入口** | 设置页一个 `_SettingsSection` 内加一行 `ListTile` | 用户主动点 | 零打扰，照顾主动型用户，随时可跳转 |
| **B. 启动条件弹窗** | App 启动后主页就绪 post-frame 检查 | 满足门槛且不在冷却期 | 转化主力，但严格克制 |

### 2.2 弹窗触发门槛（全部满足才弹）

1. **未永久关闭**：`star_prompt_dismissed != true`
2. **启动次数达标**：`star_prompt_launch_count >= 7`
3. **安装时长达标**：`now - star_prompt_install_time >= 3 天`
4. **不在冷却期**：`now >= star_prompt_next_show_time`

四个条件任一不满足即跳过本次弹窗。门槛设计意图：**只对真正的留存用户弹**（用了 7 次 + 留了 3 天，基本是认可 App 的人），不走试用一次就走的用户。

### 2.3 弹窗按钮（两按钮，简洁）

| 按钮 | 行为 | 持久化 |
|---|---|---|
| **「⭐ 去 GitHub 点 Star」**（主按钮，FilledButton） | `launchUrl` 打开 `kGitHubRepo`（externalApplication），关闭弹窗 | 写 `star_prompt_dismissed = true`（永久不再弹） |
| **「关闭」**（TextButton） | 仅关闭弹窗 | 写 `star_prompt_next_show_time = now + 7 天`（冷却 7 天） |

**为什么主按钮点了就永久不再弹**：已经把用户带到 GitHub 仓库页了，用户能看到 star 按钮；再弹就是骚扰。无论用户实际点没点 star，App 侧无法感知（GitHub 不回传），只能信任用户。

**文案基调**：真诚、恳求，不卖惨不道德绑架。说明三点：(1) 开源免费；(2) star 对作者的意义（曝光/动力/反馈）；(3) 顺手即可。

### 2.4 持久化数据（SharedPreferences）

| key | 类型 | 默认 | 含义 |
|---|---|---|---|
| `star_prompt_install_time` | `int`（ms 时间戳） | 首次启动写入 `now` | 安装/首次启动时间，算"满 3 天" |
| `star_prompt_launch_count` | `int` | 0，每次启动 +1 | 启动次数计数 |
| `star_prompt_dismissed` | `bool` | false | true = 永久不再弹（主按钮触发） |
| `star_prompt_next_show_time` | `int`（ms 时间戳） | 0 | 下次允许弹窗的时间，点"关闭"后写 `now + 7天` |

---

## 3. 文件清单

### 新建

| 文件 | 职责 |
|---|---|
| `lib/services/star_prompt_service.dart` | 单例服务。管 4 个 preferences key + `shouldShow()` 判定 + `recordLaunch()` + `onStarClicked()` / `onDismissed()` |
| `lib/widgets/star_prompt_dialog.dart` | StatelessWidget。两按钮 + 文案，返回 `bool`（true=去点 star / false=关闭），仿 `CrashReportDialog` 结构 |

### 修改

| 文件 | 改动 |
|---|---|
| `lib/main.dart` | HomePage `_HomePageState.initState` 的 post-frame callback，在 `NativeCrashReporter.checkAndReport` 后并列调用 `StarPromptService` 检查 + 弹窗（crash 优先，star 其后；互不干扰） |
| `lib/screens/settings_screen.dart` | 在合适分组（如"关于"或"支持"段）加一行 `ListTile`，leading `Icons.star_outline`，tap → `launchUrl(kGitHubRepo)` |

### 复用

- `kGitHubRepo` 常量（`native_crash_reporter.dart:27` 已定义 `https://github.com/yunkst/novel_builder`）——直接 import，不重复定义
- `PreferencesService.instance` 的 `getInt/setInt/getBool/setBool`——已覆盖全部需求
- `CrashReportDialog` 的 dialog 结构范式（AlertDialog + icon + content + actions）

---

## 4. 关键逻辑

### 4.1 StarPromptService 核心 API

```dart
class StarPromptService {
  static final StarPromptService instance = StarPromptService._();
  StarPromptService._();

  static const _kInstallTime = 'star_prompt_install_time';
  static const _kLaunchCount = 'star_prompt_launch_count';
  static const _kDismissed = 'star_prompt_dismissed';
  static const _kNextShowTime = 'star_prompt_next_show_time';

  static const int _launchThreshold = 7;
  static const int _installDaysThreshold = 3;
  static const int _cooldownDays = 7;

  /// 启动时调用：计数 +1，并首次写入 install_time。
  Future<void> recordLaunch();

  /// 是否应该弹窗（四门槛全满足）。
  Future<bool> shouldShow();

  /// 主按钮：标记永久关闭（launchUrl 由调用方做）。
  Future<void> onStarClicked();

  /// 关闭按钮：写冷却期 next_show_time = now + 7 天。
  Future<void> onDismissed();
}
```

### 4.2 触发时序（main.dart post-frame）

```dart
WidgetsBinding.instance.addPostFrameCallback((_) async {
  if (!mounted) return;
  // 1. crash 优先（已有）
  await NativeCrashReporter.checkAndReport(context);
  // 2. star 引导其后（新增）
  if (!mounted) return;
  await StarPromptService.instance.recordLaunch();
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
});
```

### 4.3 弹窗文案（草稿）

> **标题**：喜欢「随心阅读」？
>
> **正文**：
> 这是一个完全开源、免费、无广告的小说阅读 App。
>
> 如果它对你有帮助，能不能顺手去 GitHub 点个 ⭐ Star？
>
> Star 对独立开发者意义重大——它能让更多人发现这个项目，也是支持我继续维护和更新的最大动力。只需点一下，几秒钟就好。
>
> **按钮**：⭐ 去 GitHub 点 Star ｜ 关闭

---

## 5. 测试策略

### 单元测试（`test/unit/services/star_prompt_service_test.dart`）

- `recordLaunch()`：首次写入 install_time + count 0→1；非首次 count 累加
- `shouldShow()` 四门槛矩阵：
  - count < 7 → false（即使时间够、未关、无冷却）
  - install < 3 天 → false
  - dismissed = true → false
  - now < next_show_time → false
  - 四门槛全满足 → true
- `onStarClicked()`：dismissed → true，shouldShow 永久 false
- `onDismissed()`：next_show_time = now + 7 天，期间 shouldShow false，7 天后恢复 true

测试用 `SharedPreferences.setMockInitialValues({})` 注入，`resetForTest()` 清状态（仿 `RetrySignals.resetForTest` 范式）。

### Widget 测试（`test/unit/widgets/star_prompt_dialog_test.dart`）

- 点主按钮 pop(true)；点关闭 pop(false)
- 文案关键句命中（"开源"、"Star"、"GitHub"）

### 手动验收清单

- 全新安装：启动 6 次（每次重启）均不弹；第 7 次但未满 3 天不弹；满 3 天后第 7+ 次启动弹
- 主按钮：跳转 GitHub + 再启动不弹
- 关闭：再启动不弹；7 天后（改系统时间或调阈值）再启动弹

---

## 6. 边界与降级

- **launchUrl 失败**（无浏览器/异常）：try-catch 吞掉，弹窗已关闭、状态已写，不影响 App
- **SharedPreferences 异常**：`PreferencesService` 内部已 try-catch rethrow；`shouldShow` 外层再包 try-catch，异常默认 false（不弹），绝不阻塞启动
- **后台转前台**：本期只在冷启动 post-frame 检查一次（与 crash 一致）；后台转前台不重复弹。若后续需支持，加 `WidgetsBindingObserver.didChangeAppLifecycleState` 钩子即可，YAGNI 本期不做
- **测试可重置**：`StarPromptService` 暴露 `resetForTest()` 清全部 key

---

## 7. 不做（YAGNI）

- 不做"已点过 star"按钮（两按钮已够，少一个决策负担）
- 不做后台转前台触发（冷启动已覆盖主要场景）
- 不做后端校验 star 状态（GitHub 不提供该 API，且涉及 token，过重）
- 不做频率上限外的更复杂算法（7 次 + 3 天 + 7 天冷却已足够克制）
- 不做分享/评分引导（本期只 star）
