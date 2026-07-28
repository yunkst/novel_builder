# 后端服务作为进阶功能隐藏 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让新手的 onboarding 与设置页主路径不再被后端概念打扰；后端依赖的三项功能（备份/日志/文生图）收纳到设置页的「进阶服务」折叠分组；Agent 文生图工具后端不可用时清晰告知「进阶功能 + 需本地部署 + 配置路径」。

**Architecture:** 三处纯 UI / 文案改动，零架构变更。onboarding 6→5 步删后端页（步骤索引左移）；settings 新增折叠分组（给 `_SettingsSection` 加可选折叠参数）；media_executor 三处 catch 的 message 文案改为新模板，按 host 是否配置分支。

**Tech Stack:** Flutter 3 / Dart / Riverpod / Material3 / `_SettingsSection`（项目自定义）/ `ApiServiceWrapper.getHost()`（async `Future<String?>`，行 140）。

## Global Constraints

- **不动架构** —— 代码层优雅降级已完备，本次只动 UI 入口、文案、错误消息
- **不动 LLM / DSL Engine 链路**，不动 `ApiServiceWrapper` / `BackupService` / `LogReporterService` 实现，不动 `BackendSettingsScreen` / `BackupManagementScreen` / `LogReportSettingsScreen` 内部
- **不动 DB schema**，不引入新依赖
- **路径字字对齐**：文案中的路径必须是「设置 → 进阶服务 → 后端服务配置」（与 Task 2 落地后的设置页一致）
- **commit 规范**：遵循 `chore:` / `feat:` / `refactor:` / `docs:` / `test:` 前缀；Co-Authored-By: Claude <noreply@anthropic.com>
- **worktree**：`D:/my_space/novel_builder/.claude/worktrees/onboarding-backend-hidden/`，分支 `worktree-onboarding-backend-hidden`

## 文件清单

| 文件 | 改动 |
|---|---|
| `novel_app/lib/screens/onboarding/onboarding_screen.dart` | 删 6→5 步、删后端配置页方法、删相关字段/dispose/import、加"阅读增强亮点"页轻提示、类注释同步 |
| `novel_app/lib/screens/settings_screen.dart` | `_SettingsSection` 加可选折叠参数；新增「进阶服务」分组（移入 3 Tile + 加徽章）；两分组 subtitle 同步；「数据」/「诊断」分组收尾 |
| `novel_app/lib/services/novel_agent/tool_executor/media_executor.dart` | 三处 catch 改造：抽常量 `_kBackendUnconfiguredMsg` / `_kBackendUnreachableMsg`；按 host 是否为空分支选择文案 |
| `novel_app/test/unit/services/novel_agent/text2img_tools_test.dart` | Task 3 同步断言新文案关键词（不破坏现有 `error: 'backend_unavailable'` 与 `contains('connection refused')` 断言） |

---

## Task 1: onboarding 删后端配置步（6→5 步）

**Files:**
- Modify: `novel_app/lib/screens/onboarding/onboarding_screen.dart` (类注释 16-22；常量 42/45；字段 49-50；dispose 63-64；`_saveBackendAndContinue` 102-143；PageView children 248-296 删 index 1 并左移；`_buildBottomBar` 602/611-612/654/672-682；`_buildBackendConfigPage` 400-488；新建轻提示)

**Interfaces:**
- Consumes: 无前置
- Produces: `_stepCount = 5`；删除 `_indexBackend` 常量；新增「阅读增强亮点」页底部的轻提示文案；`_buildBottomBar` 不再识别后端步

- [ ] **Step 1: 改常量与删除后端字段**

在 `novel_app/lib/screens/onboarding/onboarding_screen.dart` 中：

1.1. 行 42：`static const int _stepCount = 6;` 改为 `static const int _stepCount = 5;`

1.2. 行 45：删除 `static const int _indexBackend = 1;`

1.3. 行 46 `_indexAi = 2` 改为 `static const int _indexAi = 1;`

1.4. 行 49-50：删除这两个字段：
```dart
final TextEditingController _backendHostController = TextEditingController();
final TextEditingController _backendTokenController = TextEditingController();
```

1.5. 行 63-64（dispose 内）：删除对应两行 `_backendHostController.dispose();` 与 `_backendTokenController.dispose();`

- [ ] **Step 2: 删除 `_saveBackendAndContinue` 方法**

行 102-143：删除整个方法 `_saveBackendAndContinue` 及其上方行 101 的注释 `/// 保存后端配置并前进（后端为可选，留空直接前进）`。

- [ ] **Step 3: 改 PageView children（删 index 1 并左移）**

行 248-296 的 `children:` 列表改造：

3.1. 删除行 257-258 `// 1 - 后端服务（可选）\n_buildBackendConfigPage(context),`

3.2. 行 259-260 `// 2 - AI 引擎（关键）\n_buildAiConfigPage(context),` 中注释改为 `// 1 - AI 引擎（关键）`

3.3. 行 261-262 `// 3 - 找书\n` 中注释改为 `// 2 - 找书`

3.4. 行 274-275 `// 4 - 阅读增强亮点\n` 中注释改为 `// 3 - 阅读增强亮点`

3.5. 行 288-289 `// 5 - 完成\n` 中注释改为 `// 4 - 完成`

- [ ] **Step 4: 改 `_buildBottomBar`（移除后端步识别）**

行 602：删除 `final isBackendPage = _currentPage == _indexBackend;`（涉及 `_indexBackend` 已删除）。

行 611-612：删除以下分支：
```dart
} else if (isBackendPage) {
  primaryLabel = '保存并继续';
```
（保留 `if (isLastPage) ... else if (isAiPage) ... else {primaryLabel = '下一步';}` 结构不变）

行 654：在 `_saveBackendAndContinue()` 调用分支处删除：
```dart
} else if (isBackendPage) {
  _saveBackendAndContinue();
```
（`if (isLastPage) ... else if (isAiPage) ... else` 结构不变）

行 672：把 `if (isBackendPage || isAiPage)` 改为 `if (isAiPage)`。

行 680：`isAiPage ? '稍后配置' : '跳过此步'` 改为统一 `const Text('稍后配置')`（因为只剩 `isAiPage` 一支）。最简改法是去掉三元，直接写 `'稍后配置'`：
```dart
child: const Text('稍后配置'),
```

- [ ] **Step 5: 删除 `_buildBackendConfigPage` 方法**

行 400-488：删除整个方法 `_buildBackendConfigPage` 及其上方行 400 的注释 `/// 构建后端服务配置页（可选）`。

- [ ] **Step 6: 类文档注释同步（行 16-22）**

把：
```dart
/// 1. 欢迎页（APP 定位）
/// 2. 后端服务（**可选**，用于多站点搜索/缓存）
/// 3. 🌟 配置 AI 引擎（关键步骤：填一个 LLM 地址 + Key 即可解锁大部分 AI 能力）
/// 4. 找书方式介绍（浏览器浏览 → 添加小说）
/// 5. 阅读增强亮点（AI 特写 / 插图 / 改写）
/// 6. 完成
```
改为：
```dart
/// 1. 欢迎页（APP 定位）
/// 2. 🌟 配置 AI 引擎（关键步骤：填一个 LLM 地址 + Key 即可解锁大部分 AI 能力）
/// 3. 找书方式介绍（浏览器浏览 → 添加小说）
/// 4. 阅读增强亮点（AI 特写 / 插图 / 改写），含一行进阶功能提示
/// 5. 完成
```
（同时在 Step 7 新增的轻提示上方写一行注释说明「Step 4 提到的进阶功能入口 → 设置页 → 进阶服务 → 后端服务配置」）

- [ ] **Step 7: 在「阅读增强亮点」页加轻提示**

定位方法：行 275-287 `_buildInfoPage(...icon: Icons.auto_awesome, title: 'AI 让阅读更有趣', bullets: [...])`。这是第三个 PageView child。

由于 `_buildInfoPage` 是通用模板（接受 `bullets` 列表），最小侵入方案是新增一个独立的轻提示 widget，插入到该 PageView child 紧后：

在 PageView 的 `children:` 列表中（行 274-287），把：
```dart
// 3 - 阅读增强亮点
_buildInfoPage(
  icon: Icons.auto_awesome,
  iconColor: context.appColors.agentAccent,
  title: 'AI 让阅读更有趣',
  description: '配置好 AI 引擎后，阅读时即可调用这些能力，'
      '为文字补充画面感，或改写不满意的段落。',
  bullets: const [
    'AI 特写：为情节生成沉浸式扩写',
    '场景插图：用文字生成配图',
    '段落改写：一键优化文笔',
    '角色对话：和书中角色直接聊天',
  ],
),
```
改为：
```dart
// 3 - 阅读增强亮点
_buildInfoPage(
  icon: Icons.auto_awesome,
  iconColor: context.appColors.agentAccent,
  title: 'AI 让阅读更有趣',
  description: '配置好 AI 引擎后，阅读时即可调用这些能力，'
      '为文字补充画面感，或改写不满意的段落。',
  bullets: const [
    'AI 特写：为情节生成沉浸式扩写',
    '场景插图：用文字生成配图',
    '段落改写：一键优化文笔',
    '角色对话：和书中角色直接聊天',
  ],
),
const _AdvancedHintBanner(),
```

然后在文件末尾（行 700 的大括号之前）新增私有 widget：
```dart
/// 「阅读增强亮点」页底部的轻提示：一行引导新手知道还有进阶功能入口
///
/// 居中、次级色、不喧宾夺主；路径「设置 → 进阶服务 → 后端服务配置」
/// 与 Task 2 设置页的分组标题、Tile 标题字字对应。
class _AdvancedHintBanner extends StatelessWidget {
  const _AdvancedHintBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 32, left: 32, right: 32),
      child: Text(
        '还有 AI 出图、数据备份等进阶功能，'
        '可在「设置 → 进阶服务」中按需开启。',
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
```

- [ ] **Step 8: 检查 import**

确认行 4-12 的 import 还有没有引用 `apiServiceWrapperProvider` / `LlmConfig` / `ToastUtils`：
- `apiServiceWrapperProvider` 在 `_saveBackendAndContinue` 被引用 → 该方法已删，import 可清理（行 5 `service_providers.dart`）
- `LlmConfig` 在 `_saveAiAndContinue` 仍被引用 → 保留
- `ToastUtils` 在 `_saveAiAndContinue` 的 URL 校验报错被引用 → 保留

**Action**：删除行 5 `import '../../core/providers/service_providers.dart';`（不再使用）。运行 `flutter analyze` 二次确认。

- [ ] **Step 9: 静态分析**

```bash
cd D:/my_space/novel_builder/.claude/worktrees/onboarding-backend-hidden/novel_app
flutter analyze lib/screens/onboarding/onboarding_screen.dart
```

预期：0 error。如果有 unused import，删之。

- [ ] **Step 10: 手动验证（onboarding 5 步流）**

10.1. 启动 app，清掉 SharedPreferences 中 `onboarding_completed`（adb 或开发面板）。
10.2. 验证：
- 顶部进度指示器 5 个点
- 步骤顺序：欢迎 → AI 引擎 → 找书 → 阅读增强亮点（含底部「进阶服务」轻提示）→ 完成
- AI 引擎页主按钮文案「保存并继续」，底部「稍后配置 / 去设置页详细配置」
- 找书 / 阅读增强 / 完成页主按钮文案「下一步」
- 完成页主按钮文案「开始使用」（非 review 模式）
- review 模式（设置页"新手引导"Tile）下：最后一步主按钮文案「完成」

10.3. 截图或录屏 5 步全流程，写一段验证记录贴到 commit message 末尾（`验证: 5 步走通，AI 步骤按钮文案正确`）。

- [ ] **Step 11: Commit**

```bash
cd D:/my_space/novel_builder/.claude/worktrees/onboarding-backend-hidden
git add novel_app/lib/screens/onboarding/onboarding_screen.dart
git -c user.name="yedazhi" -c user.email="yedazhi@users.noreply.github.com" commit -m "$(cat <<'EOF'
refactor(onboarding): 6→5 步删后端配置页，挪到「阅读增强亮点」页一行提示

onboarding 第二步后端配置对新手不友好，且文案引用的多站点搜索/章节缓存
功能已于 2026-07-08 删除。继续把它放在第二步是误导。

删除内容：
- _stepCount 6→5
- _buildBackendConfigPage（约 88 行）+ _saveBackendAndContinue
- _backendHostController / _backendTokenController 字段与 dispose
- _indexBackend 常量 + PageView index 1
- bottom bar 的后端步识别分支
- service_providers.dart import（不再使用）

新增内容：
- 「阅读增强亮点」页底部 _AdvancedHintBanner 一行轻提示
  「还有 AI 出图、数据备份等进阶功能，可在「设置 → 进阶服务」中按需开启」

验证：5 步走通，AI 步骤按钮文案「保存并继续 / 稍后配置」正确。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: 设置页新增「进阶服务」折叠分组 + 移入 3 Tile

**Files:**
- Modify: `novel_app/lib/screens/settings_screen.dart`（`_SettingsSection` 签名 619-626；「数据」分组 231-311 删两 Tile + 改 subtitle；「诊断」分组 314-365 删日志上报 Tile + 改 subtitle；在「新手」/「关于」分组后新增「进阶服务」分组；新增徽章 widget）

**Interfaces:**
- Consumes: Task 1 的文案路径「设置 → 进阶服务 → 后端服务配置」（要字字对齐）
- Produces: `_SettingsSection` 新签名 `{icon, title, accentColor, children, subtitle, initiallyExpanded, badgeLabel}`；新增私有 widget `_AdvancedBadge`

- [ ] **Step 1: 扩展 `_SettingsSection` 签名**

文件 `novel_app/lib/screens/settings_screen.dart`，行 619-626：

把：
```dart
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.children,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final Color accentColor;
  final List<Widget> children;
  final String? subtitle;
```
改为：
```dart
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.children,
    this.subtitle,
    this.initiallyExpanded,
    this.badgeLabel,
  });

  final IconData icon;
  final String title;
  final Color accentColor;
  final List<Widget> children;
  final String? subtitle;

  /// 非 null 时启用折叠；true=默认展开，false=默认折叠。null=不折叠（向后兼容既有 6 个分组）
  final bool? initiallyExpanded;

  /// 非 null 时在标题右侧显示一个小徽章（次级色），用于标记「进阶」分组
  final String? badgeLabel;
```

- [ ] **Step 2: 改造 `_SettingsSection.build` 以支持折叠与徽章**

行 635+ 的 `build` 方法。当前 `return Card(...child: Column(...))` 整体作为 body。

最小侵入方案：当 `initiallyExpanded` 为 null 时，保持现状（不折叠）；当非 null 时，把整个 Card 替换为 `ExpansionTile` 包裹，children 复用现有 ListTile 列表（仍用 Divider 分隔）。

把现有 `build` 内 `return Card(...)` 替换为：

```dart
Widget body = _buildBody(context);

if (initiallyExpanded != null) {
  body = ExpansionTile(
    initiallyExpanded: initiallyExpanded!,
    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
    childrenPadding: EdgeInsets.zero,
    shape: const Border(),
    collapsedShape: const Border(),
    title: Row(
      children: [
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 8),
        Text(title, style: AppTypography.shelfTitle.copyWith(fontSize: 14, color: colorScheme.onSurface)),
        if (badgeLabel != null) ...[
          const SizedBox(width: 6),
          _AdvancedBadge(label: badgeLabel!),
        ],
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle!,
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, letterSpacing: 0.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ],
    ),
    children: [body],
  );
} else {
  body = body;
}

return body;
```

并把原 Card 内部的 Column（含标题 Container + ListTile body）抽成 `_buildBody` 方法返回 Card。

**说明**：这是最大改动，但保持既有 6 个分组（`initiallyExpanded == null`）行为完全不变。

- [ ] **Step 3: 抽出 `_buildBody` 私有方法**

把原 `build` 方法（行 635-... 中间那块从 `final theme = Theme.of(context)` 到 `return Card(...)`）整段剪切到一个新私有方法：

```dart
Widget _buildBody(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  final List<Widget> body = [];
  for (var i = 0; i < children.length; i++) {
    body.add(children[i]);
    if (i != children.length - 1) {
      body.add(Divider(
        height: 0,
        thickness: 0.4,
        indent: 16,
        endIndent: 16,
        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
      ));
    }
  }

  return Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        width: 0.6,
      ),
    ),
    color: colorScheme.surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            border: Border(
              bottom: BorderSide(
                color: accentColor.withValues(alpha: 0.25),
                width: 0.6,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 8),
              Text(title, style: AppTypography.shelfTitle.copyWith(fontSize: 14, color: colorScheme.onSurface)),
              if (badgeLabel != null) ...[
                const SizedBox(width: 6),
                _AdvancedBadge(label: badgeLabel!),
              ],
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ],
          ),
        ),
        ...body,
      ],
    ),
  );
}
```

并在 `build` 中先调 `_buildBody`（不再重复 title 标题行）—— 折叠分支的 ExpansionTile 复用 `_buildBody` 的 Card + body。

**Action**：实测时若 ExpansionTile 包 Card 出现双边框或 padding 异常，回退为在 ExpansionTile.children 里直接放 body（ListTile 列表）而非包 Card。决策原则：保留 `_SettingsSection` 既有视觉一致性，必要时简化。

- [ ] **Step 4: 新增 `_AdvancedBadge` 私有 widget**

在 `_SettingsSection` 类定义**之前**（行 619 之前），新增：

```dart
/// 设置页分组标题旁的次级色小徽章，参考 onboarding "可选" 徽章样式
class _AdvancedBadge extends StatelessWidget {
  const _AdvancedBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.outline.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 删除「数据」分组的后端服务配置 + 数据备份两个 Tile**

行 237-266：删除这两个 ListTile 块（含中间的空行），保留修复数据库/应用日志/LLM 调用日志三个 Tile。

- [ ] **Step 6: 修改「数据」分组 subtitle**

行 235：`subtitle: '后端配置 · 备份 · 日志',` 改为 `subtitle: '数据库 · 应用日志',`

- [ ] **Step 7: 删除「诊断」分组的日志上报 Tile**

行 334-348：删除这个 ListTile 块（含上下空行），保留预加载队列 + 媒体缓存两个 Tile。

- [ ] **Step 8: 修改「诊断」分组 subtitle**

行 318：`subtitle: '队列监控 · 上报配置',` 改为 `subtitle: '队列监控 · 媒体缓存',`

- [ ] **Step 9: 在「关于」分组后新增「进阶服务」折叠分组**

在「关于」分组（行 394-...）的 `_SettingsSection(...)` 块后，「进阶服务」分组前：

> 注意：定位「关于」分组的结束 —— 整个 children 列表的右括号 `],` 与 `);` 之后。

新增：

```dart
// ── 进阶服务组（默认折叠）────────────────────────────────────
_SettingsSection(
  icon: Icons.cloud_outlined,
  title: '进阶服务',
  accentColor: appColors.neutral,
  subtitle: '后端部署 · 数据备份 · 远程日志',
  badgeLabel: '进阶',
  initiallyExpanded: false,
  children: [
    ListTile(
      leading: Icon(Icons.settings_ethernet, color: appColors.neutral),
      title: const Text('后端服务配置'),
      subtitle: const Text('本地部署后端后可解锁云备份、AI 出图'),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BackendSettingsScreen(),
          ),
        );
      },
    ),
    ListTile(
      leading: Icon(Icons.backup_rounded, color: appColors.neutral),
      title: const Text('数据备份'),
      subtitle: Text(_lastBackupTime != null
          ? '上次备份: $_lastBackupTime'
          : '上传/下载小说数据库到自建后端'),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BackupManagementScreen(),
          ),
        ).then((_) => _loadLastBackupTime());
      },
    ),
    ListTile(
      leading: Icon(Icons.cloud_upload_outlined, color: appColors.neutral),
      title: const Text('日志上报'),
      subtitle: const Text('诊断用，向自建后端匿名上报日志'),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LogReportSettingsScreen(),
          ),
        );
      },
    ),
  ],
),
```

注：使用 `appColors.neutral`（项目已有的中性色，与「进阶」语义匹配；与「数据」「诊断」分组的有色 accent 拉开距离）。**也可用 `appColors.textSecondary` / 其他语义色，由实现者在 `appColors` 中挑选最贴近 `outline` 系的中性色**。

- [ ] **Step 10: 静态分析**

```bash
cd D:/my_space/novel_builder/.claude/worktrees/onboarding-backend-hidden/novel_app
flutter analyze lib/screens/settings_screen.dart
```

预期：0 error。

- [ ] **Step 11: 手动验证**

11.1. 启动 app，进入「设置」Tab。
11.2. 验证：
- 「数据」分组剩余 3 个 Tile（修复数据库 / 应用日志 / LLM 调用日志），subtitle `数据库 · 应用日志`
- 「诊断」分组剩余 2 个 Tile（预加载队列 / 媒体缓存），subtitle `队列监控 · 媒体缓存`
- 「进阶服务」分组默认折叠，标题右侧有 `进阶` 小徽章
- 展开「进阶服务」：3 个 Tile 顺序为后端服务配置 / 数据备份 / 日志上报，各自跳转正确
- Tile 内的"上次备份"等状态信息仍正确填充

11.3. 截图验证记录贴 commit message。

- [ ] **Step 12: Commit**

```bash
cd D:/my_space/novel_builder/.claude/worktrees/onboarding-backend-hidden
git add novel_app/lib/screens/settings_screen.dart
git -c user.name="yedazhi" -c user.email="yedazhi@users.noreply.github.com" commit -m "$(cat <<'EOF'
refactor(settings): 新增「进阶服务」折叠分组收纳后端依赖项

把仅依赖后端的 3 个 Tile 移入底部新分组，默认折叠、标题旁有「进阶」小徽章：
- 后端服务配置（原「数据」组）
- 数据备份（原「数据」组）
- 日志上报（原「诊断」组）

留在原位的本地诊断项（修复数据库/应用日志/LLM 调用日志/预加载队列/媒体缓存）：
数据库损坏等场景下用户必须能直达，不被折叠干扰。

实现细节：
- _SettingsSection 加可选参数 initiallyExpanded（null=不折叠，向后兼容既有 6 个分组）
- _SettingsSection 加可选参数 badgeLabel（非 null 时标题旁显示次级色徽章）
- 新增私有 _AdvancedBadge widget，参考 onboarding "可选" 徽章样式
- 「数据」subtitle 改为「数据库 · 应用日志」
- 「诊断」subtitle 改为「队列监控 · 媒体缓存」

验证：进阶服务分组默认折叠；展开后 3 个 Tile 跳转正确；其他分组视觉无变化。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: media_executor 文案改造 + 测试同步

**Files:**
- Modify: `novel_app/lib/services/novel_agent/tool_executor/media_executor.dart`（3 处 catch；新增 2 个常量）
- Modify: `novel_app/test/unit/services/novel_agent/text2img_tools_test.dart`（3 处断言更新）

**Interfaces:**
- Consumes: `ApiServiceWrapper.getHost()` → `Future<String?>`（行 140），用于判定 host 是否为空以选择文案分支
- Produces: 文件内私有常量 `_kBackendUnconfiguredMsg` / `_kBackendUnreachableMsg(Object e)`；三处 catch 改造为调用统一助手 `_buildBackendError(e)`

- [ ] **Step 1: 先加失败测试（test-first）**

`novel_app/test/unit/services/novel_agent/text2img_tools_test.dart`：

文件末尾（行 294 大括号之前），新增 group：

```dart
group('create_images - 进阶功能文案', () {
  test('backend 抛错且 host 未配置时，文案含"进阶功能"和配置路径', () async {
    fakeApi.submitError = Exception('connection refused');
    // 默认 SharedPreferences mock 为空 → getHost() 返回 null

    final json = decode(await executor.execute('create_images', {
      'prompt': 'p',
    }));

    expect(json['error'], 'backend_unavailable');
    final msg = json['message'] as String;
    expect(msg, contains('进阶功能'));
    expect(msg, contains('设置 → 进阶服务 → 后端服务配置'));
    expect(msg, contains('本地部署'));
  });

  test('backend 抛错且 host 已配置时，文案前缀带错误细节 + 同样含进阶提示', () async {
    SharedPreferences.setMockInitialValues({'backend_host': 'http://my-host:3800'});
    fakeApi.submitError = Exception('Connection timed out');

    final json = decode(await executor.execute('create_images', {
      'prompt': 'p',
    }));

    expect(json['error'], 'backend_unavailable');
    final msg = json['message'] as String;
    expect(msg, contains('Connection timed out'));
    expect(msg, contains('进阶功能'));
    expect(msg, contains('设置 → 进阶服务 → 后端服务配置'));
  });
});
```

> 注：第二条用例改了 SharedPreferences mock，需要重 setUp 或每个用例前重置。当前 setUp 在行 95 已 `SharedPreferences.setMockInitialValues({})`。为简化，把第二条用例放回 setUp 之前 —— **更稳妥**：每个 group 前显式重置 SharedPreferences（在 test 内 setMockInitialValues 即可）。

- [ ] **Step 2: 运行测试验证失败**

```bash
cd D:/my_space/novel_builder/.claude/worktrees/onboarding-backend-hidden/novel_app
flutter test test/unit/services/novel_agent/text2img_tools_test.dart
```

预期：新增 2 个测试 FAIL，错误为「文案内不含'进阶功能'」/「不含配置路径」（旧文案是"请告知用户检查后端服务与 ComfyUI 是否正常运行"）。

- [ ] **Step 3: 在 `media_executor.dart` 添加常量与助手方法**

文件 `novel_app/lib/services/novel_agent/tool_executor/media_executor.dart`，类体内（行 20 `class MediaExecutor...` 之后），添加：

```dart
/// 后端 HOST 未配置时的标准错误文案（引导用户去设置）
const String _kBackendUnconfiguredMsg = 'AI 出图是进阶功能，需要本地部署后端服务（含 ComfyUI）。'
    '如已部署，请在「设置 → 进阶服务 → 后端服务配置」填入地址；'
    '未部署可暂时跳过，不影响阅读与 AI 写作。';

/// 后端 HOST 已配置但调用失败时的标准错误文案（前缀带异常细节）
String _kBackendUnreachableMsg(Object e) =>
    '无法连接到后端服务：$e。AI 出图是进阶功能，需要本地部署后端服务（含 ComfyUI）。'
    '请在「设置 → 进阶服务 → 后端服务配置」检查地址，或确认后端与 ComfyUI 已启动。';

/// 三处 catch 共用的错误响应构造：先读 host 决定走哪个分支文案
Future<Map<String, dynamic>> _buildBackendError(Ref ref, Object e) async {
  final host = await ref.read(apiServiceWrapperProvider).getHost();
  final isUnconfigured = host == null || host.isEmpty;
  return {
    'error': 'backend_unavailable',
    'message': isUnconfigured ? _kBackendUnconfiguredMsg : _kBackendUnreachableMsg(e),
  };
}
```

- [ ] **Step 4: 改造 `listText2ImgModels` catch**

行 44-52 的 catch 块：

把：
```dart
} catch (e) {
  LoggerService.instance.e('列出文生图模型失败: $e',
      category: LogCategory.ai,
      tags: ['agent', 'tool', 'list_text2img_models', 'error']);
  return jsonEncode({
    'error': 'backend_unavailable',
    'message': '无法获取文生图模型列表：$e。请告知用户检查后端服务与 ComfyUI 是否正常运行。',
  });
}
```
改为：
```dart
} catch (e) {
  LoggerService.instance.e('列出文生图模型失败: $e',
      category: LogCategory.ai,
      tags: ['agent', 'tool', 'list_text2img_models', 'error']);
  return jsonEncode(await _buildBackendError(ref, e));
}
```

- [ ] **Step 5: 改造 `createImages` catch**

行 118-126 的 catch 块：

把：
```dart
} catch (e) {
  LoggerService.instance.e('提交文生图任务失败: $e',
      category: LogCategory.ai,
      tags: ['agent', 'tool', 'create_images', 'error']);
  return jsonEncode({
    'error': 'backend_unavailable',
    'message': '提交文生图任务失败：$e。请告知用户检查后端服务与 ComfyUI 是否正常运行。',
  });
}
```
改为：
```dart
} catch (e) {
  LoggerService.instance.e('提交文生图任务失败: $e',
      category: LogCategory.ai,
      tags: ['agent', 'tool', 'create_images', 'error']);
  return jsonEncode(await _buildBackendError(ref, e));
}
```

- [ ] **Step 6: 改造 `createImageToVideo` catch**

行 209-217 的 catch 块：

把：
```dart
} catch (e) {
  LoggerService.instance.e('提交图生视频任务失败: $e',
      category: LogCategory.ai,
      tags: ['agent', 'tool', 'create_image_to_video', 'error']);
  return jsonEncode({
    'error': 'backend_unavailable',
    'message': '提交图生视频任务失败：$e。请告知用户检查后端服务与 ComfyUI 是否正常运行。',
  });
}
```
改为：
```dart
} catch (e) {
  LoggerService.instance.e('提交图生视频任务失败: $e',
      category: LogCategory.ai,
      tags: ['agent', 'tool', 'create_image_to_video', 'error']);
  return jsonEncode(await _buildBackendError(ref, e));
}
```

- [ ] **Step 7: 同步测试断言（保留原有契约，新增关键字断言）**

`test/unit/services/novel_agent/text2img_tools_test.dart`：

7.1. 行 145-152 `backend 抛错时返回 backend_unavailable 引导`（listText2ImgModels 测试）：
```dart
test('backend 抛错时返回 backend_unavailable 引导', () async {
  fakeApi.modelsError = Exception('connection refused');

  final json = decode(await executor.execute('list_text2img_models', {}));

  expect(json['error'], 'backend_unavailable');
  expect(json['message'], contains('connection refused'));
});
```
追加一条断言：
```dart
expect(json['message'], contains('进阶功能'));
expect(json['message'], contains('设置 → 进阶服务 → 后端服务配置'));
```

7.2. 行 253-267 `submit 抛错时返回 backend_unavailable`（createImages 测试）：
```dart
expect(json['error'], 'backend_unavailable');
expect(json['message'], contains('ComfyUI offline'));
expect(json.containsKey('success'), false, reason: '失败时不应伪装成功');
```
追加：
```dart
expect(json['message'], contains('进阶功能'));
expect(json['message'], contains('设置 → 进阶服务 → 后端服务配置'));
```

- [ ] **Step 8: 运行测试验证全部通过**

```bash
cd D:/my_space/novel_builder/.claude/worktrees/onboarding-backend-hidden/novel_app
flutter test test/unit/services/novel_agent/text2img_tools_test.dart
```

预期：全部 PASS，包括 Step 1 新增的 2 个 + Step 7 追加的 4 个，共 6 个新增断言；原有 18 个测试不变。

- [ ] **Step 9: 静态分析**

```bash
cd D:/my_space/novel_builder/.claude/worktrees/onboarding-backend-hidden/novel_app
flutter analyze lib/services/novel_agent/tool_executor/media_executor.dart test/unit/services/novel_agent/text2img_tools_test.dart
```

预期：0 error。

- [ ] **Step 10: Commit**

```bash
cd D:/my_space/novel_builder/.claude/worktrees/onboarding-backend-hidden
git add novel_app/lib/services/novel_agent/tool_executor/media_executor.dart \
        novel_app/test/unit/services/novel_agent/text2img_tools_test.dart
git -c user.name="yedazhi" -c user.email="yedazhi@users.noreply.github.com" commit -m "$(cat <<'EOF'
feat(agent): 文生图后端不可用文案点明「进阶功能 / 需本地部署 + 配置路径」

旧文案「请告知用户检查后端服务与 ComfyUI 是否正常运行」含糊，
新手易误以为 app 故障。新文案显式传达：
- 这是进阶功能
- 需要本地部署后端服务（含 ComfyUI）
- 配置路径「设置 → 进阶服务 → 后端服务配置」与 Task 2 字字对应
- 不影响阅读与 AI 写作

按 host 是否配置分两支文案（通过 ApiServiceWrapper.getHost() 判定）：
- 未配置：标准引导文案
- 已配置：前缀带异常细节 + 同样提示去设置页检查

抽出文件内私有常量 + _buildBackendError(ref, e) 助手，三处 catch 复用。
不改 error 字段（'backend_unavailable'），上游协议不变。

测试：
- 新增 2 个 case 覆盖两支文案（未配置 / 已配置）
- 同步 2 个旧 case 追加"进阶功能"与配置路径关键字断言
- 共 18+6 个用例全 PASS

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**1. Spec coverage**（逐节对照）：
- spec 模块 1（onboarding 删后端步 + 加轻提示）→ Task 1 ✓
- spec 模块 2（设置页「进阶服务」折叠分组 + 移入 3 Tile + 留本地诊断项原位 + 两分组 subtitle 同步）→ Task 2 ✓
- spec 模块 3（media_executor 三处 catch 改造 + 按 host 分支 + 路径字字对齐）→ Task 3 ✓
- spec「不动架构 / 不动 LLM / 不动 DB / 不动二级屏内部」→ 三个 Task 均未触及 ✓
- spec 风险 1（onboarding 索引左移）→ Task 1 Step 3 显式列了每个注释行的目标值，Step 4 列了 bottom bar 三处分支 ✓
- spec 风险 2（折叠分组改动 `_SettingsSection`）→ Task 2 Step 1 用 `initiallyExpanded: null` 向后兼容 + Step 2 最小侵入方案 + Step 3 兜底回退 ✓

**2. Placeholder scan**：
- 无 "TBD" / "TODO" / "implement later" / "fill in details"
- 无 "Add appropriate error handling" / "handle edge cases" / "Similar to Task N"
- 所有代码块都是真实可粘贴的 Dart 代码
- 文案、字段名、行号与实际代码锚定（onboarding_screen.dart、settings_screen.dart、media_executor.dart、api_service_wrapper.dart）

**3. Type consistency**：
- `_stepCount` 在 Task 1 改 6→5；PageView children 索引与 _buildBottomBar 的 `isAiPage` 同步左移
- `_indexBackend` 在 Task 1 删，`_indexAi` 改 1
- `_SettingsSection` 签名变更向后兼容：既有 6 个分组调用处全部不传新参数 → 行为不变
- `_AdvancedBadge` / `_AdvancedHintBanner` 都是文件内私有 widget，不跨文件依赖
- `_buildBackendError` 是文件内私有函数，依赖 `apiServiceWrapperProvider.getHost()`（已存在的方法，行 140）
- 测试用例用的 `fakeApi.submitError` / `fakeApi.modelsError` / `SharedPreferences.setMockInitialValues` 都与现有测试基础设施一致

无问题。