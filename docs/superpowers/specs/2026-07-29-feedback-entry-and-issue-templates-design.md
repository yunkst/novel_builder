# 问题反馈入口与 GitHub Issue 模板设计

**日期**: 2026-07-29
**状态**: 已确认（待 spec review）
**分支**: master

---

## 1. 背景与目标

「随心阅读」（Novel Builder）是开源免费项目，仓库 `https://github.com/yunkst/novel_builder`。当前 App 内**没有任何反馈入口**——用户遇到 bug 或有功能建议时，只能自己去 GitHub 提 issue，门槛高、路径不可发现。设置页已有「支持项目」分组的「去 GitHub 点 Star」外链范式（`launchUrl` + `kGitHubRepo`），可复用同一套跳转机制。

同时，仓库 `.github/` 目录下有 `PULL_REQUEST_TEMPLATE.md` / `dependabot.yml` / `release_template.md`，但**没有 `ISSUE_TEMPLATE/`**，用户即使找到 issues 页也无引导，反馈质量参差。

**目标**：
1. 在设置页「关于」组加一个「问题反馈」入口，点击后用外部浏览器打开 `issues/new`，由 GitHub 显示模板选择器。
2. 用 GitHub 现代化 Issue Forms（YAML）准备 3 个模板（Bug 报告 / 功能建议 / 提问），覆盖项目主要反馈场景，并引用仓库已有 label。

**非目标**：
- 不在 App 内做模板选择 UI（复用 GitHub 原生选择器，YAGNI）
- 不预填设备/版本信息到 issue body（URL 预填有转义与长度风险，改为模板内提示用户从「设置 → 关于应用」复制）
- 不做 App 内反馈表单 / 不接后端反馈接口
- 不加 Toast 提示跳转失败（与 Star 入口一致，静默吞异常）

---

## 2. 设计要点

### 2.1 设置页入口（Flutter）

**归属**：「关于」组（`_SettingsSection(title: '关于', accentColor: appColors.neutral)`），放在组内**最末尾**（「获取预览版」开关之后）。

**理由**：「关于」组语义天然包含「联系开发者 / 反馈」，与「关于应用 / 检查更新 / 获取预览版」并列自然；放组末尾不打断「关于应用 → 检查更新」的版本信息连贯阅读。

**条目样式**（与组内其它 ListTile + Star 外链入口对齐）：

| 属性 | 值 |
|---|---|
| `leading` | `Icon(Icons.feedback_outlined, color: appColors.neutral)` |
| `title` | `问题反馈` |
| `subtitle` | `报告 Bug 或提出功能建议` |
| `trailing` | `Icon(Icons.open_in_new, size: 18)`（外链标识，与 Star 入口一致） |
| `onTap` | 调用新抽出的 `_openFeedback()` 方法 |

**跳转逻辑**：

```dart
Future<void> _openFeedback() async {
  try {
    await launchUrl(
      Uri.parse('$kGitHubRepo/issues/new'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // 异常吞掉（无浏览器等），与 Star 入口一致
  }
}
```

- 复用 `kGitHubRepo` 常量（`lib/services/native_crash_reporter.dart:27`，值 `'https://github.com/yunkst/novel_builder'`，末尾无斜杠），URL 拼接方式与 `native_crash_reporter.dart:102` 的 `'$kGitHubRepo/issues/new'` 完全一致。
- `kGitHubRepo` 已在 `settings_screen.dart` 通过 `import '../services/native_crash_reporter.dart' show kGitHubRepo;` 引入（Star 入口已用），无需新增 import。
- 跳转后由 GitHub 显示 3 个 Issue Forms 模板的选择器，用户自行选择 Bug / 功能 / 提问。

### 2.2 GitHub Issue 模板（`.github/ISSUE_TEMPLATE/`，3 个 Issue Forms YAML）

采用 GitHub 现代化 Issue Forms（`name` / `description` / `labels` / `body`），带字段校验、下拉、占位提示，体验优于旧 markdown 模板。三个模板引用的 label 仓库**均已存在**（`gh label list` 确认）：`bug`(#d73a4a) / `enhancement`(#a2eeef) / `question`(#d876e3)。

#### 模板 1：`bug_report.yml` — `labels: [bug]`

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| 复现步骤 | textarea | ✅ | 编号步骤 |
| 期望行为 | textarea | ❌ | |
| 实际行为 | textarea | ✅ | |
| App 版本 | input | ✅ | placeholder 提示「设置 → 关于应用」里的版本号，如 `2.0.2-preview.5+114` |
| 平台 | dropdown | ✅ | Android / iOS / Windows / 其他 |
| 涉及的小说站点 URL | input | ❌ | 针对站点提取/OCR 问题，选填 |
| 截图 / 日志 | textarea | ❌ | 提示可拖图、可贴 LLM 调用日志（设置 → LLM 调用日志） |

#### 模板 2：`feature_request.yml` — `labels: [enhancement]`

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| 想解决的问题 | textarea | ✅ | 痛点 / 场景 |
| 期望的效果 | textarea | ✅ | |
| 现在的临时办法 | textarea | ❌ | |

#### 模板 3：`question.yml` — `labels: [question]`

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| 你的疑问 | textarea | ✅ | |
| 已经试过什么 | textarea | ❌ | |

#### 关于「用 gh 工具」

`gh` CLI 没有生成 issue 模板的子命令——issue 模板本质是仓库文件。因此实现方式为：用 Write 创建 3 个 yml 文件 → git commit。push 到 GitHub 后 `issues/new` 自动出现模板选择器（是否 push 在实现阶段与用户确认）。

### 2.3 错误处理

- `launchUrl` 失败静默吞异常（与 Star 入口一致，YAGNI，不加 Toast）。
- 模板 YAML 语法错误会导致 GitHub 不显示该模板——实现时逐个用 YAML 校验确认（YAML 内不允许 tab 缩进，统一 2 空格）。

---

## 3. 测试

### 3.1 Flutter widget 测试

新增 `test/unit/screens/settings_feedback_entry_test.dart`：

1. 「关于」组内出现「问题反馈」条目（按 `find.text('问题反馈')` 定位）。
2. 该条目带 `open_in_new` 外链图标（验证外链语义）。
3. 点击 `onTap` 不抛异常（url_launcher 在测试环境难 mock，不校验跳转 URL，只保证入口存在且可交互）。

符合项目「测试维护成本不高于业务代码」原则——不引入复杂 mock，只做存在性与可交互性验证。

### 3.2 Issue 模板验证

- 3 个 yml 文件 push 后在 GitHub `issues/new` 手动确认模板选择器出现 3 个选项。
- 或本地用 YAML linter 校验语法。

---

## 4. 影响面

- **改动文件**：
  - `novel_app/lib/screens/settings_screen.dart`（加一个 ListTile + `_openFeedback()` 方法）
  - 新增 `novel_app/test/unit/screens/settings_feedback_entry_test.dart`
  - 新增 `.github/ISSUE_TEMPLATE/bug_report.yml`
  - 新增 `.github/ISSUE_TEMPLATE/feature_request.yml`
  - 新增 `.github/ISSUE_TEMPLATE/question.yml`
- **不改动**：`kGitHubRepo` 常量、url_launcher 依赖（已存在）、现有设置页分组结构、Star 入口行为。
- **零 DB 变更**、零新依赖、零原生配置。

---

## 5. 验收标准

1. 设置页「关于」组末尾出现「问题反馈」条目，带 `open_in_new` 图标。
2. 点击后用外部浏览器打开 `https://github.com/yunkst/novel_builder/issues/new`。
3. GitHub issues/new 页显示 3 个模板（Bug 报告 / 功能建议 / 提问），分别带 `bug` / `enhancement` / `question` label。
4. `flutter analyze` 零告警。
5. 新增 widget 测试通过。
