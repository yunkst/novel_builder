# Agent Chat 晨读书馆风重做 · 设计 spec

- **日期**: 2026-07-27
- **状态**: 设计已与用户对齐（方向 + mockup 定稿），待 spec 审阅
- **关联 mockup**: `docs/mockups/agent-chat-reading-style.html`（亮/暗可切换）
- **触发**: 用户反馈「目前的 AI agent 窗口 UI 设计得不好看，要从头思考如何设计 UI」

---

## 1. 背景与问题

当前 `widgets/agent_chat/agent_chat_dialog.dart`（1230 行）是把多个独立设计的横条堆出来的视觉债。基于只读审计（15 条问题），核心痛点：

1. **顶部品牌色叠加**：Header 用 `LinearGradient(agentBrandStart→agentBrandEnd)` + `boxShadow`（`agent_chat_dialog.dart:197-207`），紧接着 `_buildWebViewInfoBar`/`_buildCurrentNovelBar` 又画一条 `agentAccent@0.06` 底色条（`:466` / `:733`）。`agentAccent == agentBrandStart`（同色两名，`app_colors.dart:153` vs `:155`），导致 Indigo 渐变 → Indigo 浅条背靠背，顶部品牌饱和度翻倍。
2. **5 条手写 status bar 共用模板不同色**：`_buildErrorBar`/`_buildStopBar`/`_buildSupplementBar`/`_buildWebViewInfoBar`/`_buildCurrentNovelBar` 结构同构（Container + 平铺染色 + 小图标 + 小字），却用 3 种 alpha（0.06/0.08/0.1）、2 种 padding（v6/v8）、2 种主色（agentAccent/error）。运行态最多同时堆 5 条。
3. **emoji 当图标**：`PopupMenuItem` 用 `Text(s.icon)`（`agent_chat_dialog.dart:272-273`），`s.icon` 是 `ScenarioInfo.icon` 字符串字面量（`agent_scenario_factory.dart:75,80`，"✍️"/"🔍"）；`AgentScenarioConfigDialog:68` 标题、`compaction_marker_card.dart:65` 同样用 emoji `Text`。无法随主题着色/缩放。
4. **两种 ActionChip 样式**：`_buildContextTag`（`:702-714`）用默认 M3 ActionChip，`_buildQuickPrompts`（`:990-999`）用 `backgroundColor:agentAccent@0.08 + side:agentAccent@0.2` 的自定义 ActionChip，同一界面两种外观。
5. **RetryBanner 绕过主题**：`retry_banner.dart:60-63` 硬编码 `Colors.orange.shade700`/`Colors.blue.shade700`，不来自 `AppColors`，暗色下与暖纸调冲突。
6. **散乱字号**：单界面混 `fontSize: 11/12/13/14/16/18` 原始 int + `AppTypography.chapterTitle/novelTitle/metaItalic` + `theme.textTheme.bodyMedium`，无统一字阶。
7. **硬编码颜色**：jump-to-bottom FAB 图标 `Colors.white`（`:407`，其余品牌圆都用 `agentOnBrand`）；附件关闭钮 `Colors.black54`/`Colors.white`（`:881-488`）。
8. **不复用全局原语**：`_buildEmptyState`（`:542-573`）手写 Center+Column，不复用项目已有的 `EmptyStateView`（`widgets/empty_states/empty_state_view.dart`）；jump-to-bottom 手写 `Material(circle)` 不用 `FloatingActionButton.small`。
9. **Header 6 按钮尾对齐无分组**：5 个 `IconButton` + 1 个 `PopupMenuButton` 混排，间距不均，无语义分组分隔。

**根因**：`AgentChatDialog` 一个文件承担了 Header / 5 种状态条 / 消息流 / 空状态 / 输入栏 / 历史入口，每块独立演进，无统一设计语言入口。底层令牌（`AppColors` 晨读/暗夜书馆 + `AppTypography` serif/sans）**已存在但未渗透到本界面**（见 memory `novel-app-reading-style-plan.md`，Agent 对话在 Phase 2-B 批「未接入令牌」清单里）。

---

## 2. 目标与非目标

### 目标
- 把 Agent Chat 接入「晨读书馆（亮）/ 暗夜书馆（暗）」设计语言，与阅读器、书架、GitHub Pages 介绍页同源。
- 拆分 1230 行巨石为聚焦组件，每块单一职责、可独立测试。
- 5 条 status bar 合并为「同一时刻最多 1 条」的统一状态条。
- emoji 图标全部替换为可主题化的 SVG icon set。
- 清理重复/同色主题 token（`agentAccent==agentBrandStart`、`errorAccent==error`）；冷调遗留 token（`chatRoleBubble`/`chatUserBubble`/`chatUserBubbleBorder`）标记为后续清理，本次不启用。

### 非目标（明确不动）
- **不动** `AgentLoop` / `ScenarioSession` / `AgentChatState` / `AgentChatSegment` sealed 类 / Riverpod providers / DB schema / 事件协议。
- **不改**切场景的核心行为（切场景=切到目标 scenario 的最近 session，历史不丢，见 §9）。
- **不做**「合并两个 scenario 为一个自动判断的 agent」（已与用户确认否决，工具集零重叠、prompt 角色冲突）。
- **不做** Agent Chat 之外页面的令牌渗透（属 reading-style-plan Phase 2 其他批次）。

---

## 3. 设计方向（已定稿）

**晨读书馆** —— 纸卷气质：纸张颗粒纹理、暖白纸底、墨色 serif 正文、琥珀为唯一强调色、细墨线分隔。

色板（取自 `app_colors.dart`，亮/暗各一套，组件只用语义变量名）：

| 语义 | 亮（晨读） | 暗（暗夜） | 来源 token |
|---|---|---|---|
| 纸底 | `#FFFDF8` | `#241F16` | `paper` |
| 墨字 | `#2B2620` | `#E8DCC4` | `ink` |
| 次级墨 | `#6B6358` | `#B5A482` | `inkSoft` |
| 提示墨 | `#9C8A6E`* | `#7A6B52` | `chatHintText`（*亮色补） |
| 琥珀 | `#B8843A` | `#D9A05B` | 亮 `chatButtonPrimary`/暗 `chatButtonPrimary`（已不同值） |
| 错误 | `#B23A2E` | `#D9685A` | `error` |
| 分隔线 | `#E5DDCC` | `#3A3128` | `divider` |

> 注：暗色琥珀比亮色明度高，是 design system 既定（深底需更高明度才显眼），组件不写 if(dark)。

字体（取自 `app_typography.dart`）：
- 场景标题 / assistant 正文 / 空状态标题 → serif（`NotoSerifSC`），用 `AppTypography.novelTitle` / `bodyProse` 的 `copyWith` 派生。
- 上下文行 / 按钮 / chip / 工具名 / 输入文字 → sans（`NotoSansSC`，`theme.textTheme` 默认）。
- 工具函数名 / URL / 时间戳 → monospace（`JetBrains Mono` 或 `ui-monospace`）。

---

## 4. 架构与边界

```
┌─────────────────────────────────────────────────────────┐
│  不动层（保留）                                          │
│  AgentLoop · ScenarioSession · AgentChatState ·          │
│  AgentChatSegment sealed · Riverpod providers · DB ·     │
│  事件协议 · ScenarioIds                                  │
└────────────────────────┬────────────────────────────────┘
                         │ 只通过现有 provider 读状态
                         ▼
┌─────────────────────────────────────────────────────────┐
│  重写层（本次范围） widgets/agent_chat/                  │
│  agent_chat_dialog.dart      → 瘦 shell（组装 + 全屏）   │
│  agent_chat_header.dart      → 新建                      │
│  agent_status_strip.dart     → 新建（合并 5 bar）        │
│  agent_chat_messages.dart    → 新建（列表+空态+FAB）     │
│  agent_chat_composer.dart    → 新建（chips+input+发送）  │
│  agent_icons.dart            → 新建（SVG icon set）      │
│  agent_message_bubble.dart   → 小改（气泡配色 + serif）  │
│  compaction_marker_card.dart → 小改（emoji→SVG）         │
│  retry_banner.dart           → 小改（去 raw orange/blue）│
│  agent_scenario_config_dialog.dart → 小改（emoji→SVG）   │
└─────────────────────────────────────────────────────────┘
```

`agent_chat_dialog.dart` 目标 < 300 行，只负责：Dialog 容器、全屏切换、按 `chatState.scenarioId` 装配 Header/StatusStrip/Messages/Composer、订阅 `agentEventsProvider` 触发压缩 SnackBar（保留现有逻辑）。

---

## 5. 文件拆分计划

| 文件 | 动作 | 职责 | 目标 LOC |
|---|---|---|---|
| `agent_chat_dialog.dart` | 重写（瘦身） | Dialog shell + fullscreen + 组装子组件 + SnackBar 订阅 | <300 |
| `agent_chat_header.dart` | **新建** | 场景徽标 + serif 标题 + 上下文行 + 3 按钮 + 场景菜单（切换/配置/统计） | ~180 |
| `agent_status_strip.dart` | **新建** | `selectStatus()` 纯函数 + 单条状态条渲染（error/retry/supplement 3 选 1） | ~160 |
| `agent_chat_messages.dart` | **新建** | ListView + 空状态（EmptyStateView）+ jump-to-bottom（FAB.small） | ~200 |
| `agent_chat_composer.dart` | **新建** | chips（ScenarioQuickPrompts）+ TextField + attach + send 双模按钮 | ~220 |
| `agent_icons.dart` | **新建** | 集中 SVG icon（quill/book/clock/dots/close/send/plus/layers/edit/arrow/link/wand/sun/moon），替换所有 emoji + 部分 IconData | ~150 |
| `agent_message_bubble.dart` | 改 | user 气泡→`chatButtonPrimary@0.10` wash +`chatButtonPrimary@0.20` 描边；assistant→`paper` 底+`divider` 描边+serif 正文（`bodyProse.copyWith(fontSize:13,height:1.65)`）；用户气泡不再误用 `agentAccent`（`:103`）；冷调 `chatRoleBubble`/`chatUserBubble` 不启用 | - |
| `compaction_marker_card.dart` | 改 | `Text('🗂')`（`:65`）→ SVG `layers` icon | - |
| `retry_banner.dart` | 改 | `Colors.orange/blue`（`:60-63`）→ `AppColors.warning`/`error`；保留倒计时与 `RetrySignals` 订阅契约 | - |
| `agent_scenario_config_dialog.dart` | 改 | 标题 emoji（`:68`）→ SVG icon | - |

`media_gallery_card.dart` / `chapter_rewrite_entry_card.dart` / `subagent_tool_card.dart` / `chat_history_sheet.dart` / `chat_history_list_item.dart` / `agent_novel_picker_dialog.dart` 本次**不动**（已较干净或属历史 sheet 范畴），仅当其内含 emoji/硬编码色时顺带替换 icon。

**`agent_floating_button.dart` 延后**：仍用 `LinearGradient(agentBrandStart→End)`（`agent_floating_button.dart:77-86`）。本次**不改 FAB**——它独立悬浮于全屏，不属于 AgentChatDialog 内部，且改色需联动书架/浏览器等调用页的视觉一致性。**延后到 reading-style Phase 3（通用组件精修批次）**。本 spec 不在范围内，仅记录此视觉债。

---

## 6. 组件设计

### 6.1 Header（`agent_chat_header.dart`）

替代当前 `_buildHeader`（`:192-327`）+ `_buildWebViewInfoBar`（`:417-517`）+ `_buildCurrentNovelBar`（`:724-788`）三块。

```
┌────────────────────────────────────────────────────┐
│ [quill] 写作助手                  🕐  ⋯  ✕        │  ← paper 底 + 1px ink 分隔
│ 阅读《某某》· 第 23 章                              │  ← 上下文行（writing）
└────────────────────────────────────────────────────┘
```

- **去** `LinearGradient` + `boxShadow`。改 `color: appColors.paper` + 底部 `Border(bottom, color: appColors.divider)`。
- **场景徽标**：28×28 圆角小方块，`amberWash` 底 + `amberWash-2` 描边 + quill SVG（amber-deep）。替换 `Icons.auto_awesome`（`:216`）与 emoji `ScenarioInfo.icon`。
- **标题**：`AppTypography.novelTitle.copyWith(fontSize:16)`，serif，墨色。来源 `chatState.scenarioDisplayName`。
- **上下文行**（替代两个独立 bar）：
  - `writing`：`chatState.currentNovel != null` → "阅读《{title}》" + 若 `readingContextProvider.hasContext` → "· {displayLabel}"；`== null` → "尚未选择小说"（整行可点 → 开 `AgentNovelPickerDialog`）。
  - `webviewExtract`：`webviewCurrentUrlProvider` 取 URL，monospace + 截断（`maxLines:1, ellipsis`），可点跳浏览器。
  - **工具调用统计**（当前 `_buildWebViewInfoBar` 的 chips：page_info count/execute_js ok-fail/saved/cache hit）**直接删除**--对用户无意义，不保留到任何位置（不进菜单、不进 sheet）。
- **上下文行交互**：writing 场景下整行可点（替代当前 `_buildCurrentNovelBar` 末尾的「切换」`TextButton.icon`，`:775-784`），点击开 `AgentNovelPickerDialog` 并调 `session.selectNovel`；未选小说时整行用 `chatHintText` 灰字提示「点击选择小说」，仍可点。webview 场景下整行可点跳浏览器。点击区域为整行（增大热区），不单独渲染按钮，避免行内多元素拥挤。
- **3 按钮**（替代当前 6 按钮）：
  - 历史（clock SVG）→ `_showHistorySheet()`
  - 场景菜单（⋯ PopupMenuButton）：含「切换场景」（子项带能力说明）+「场景配置」+「全屏切换」
  - 关闭（×）→ 关 Dialog
  - 全屏切换（fullscreen/fullscreen_exit）**移到 ⋯ 菜单**（降权，非常用）。
  - 新建会话（add_comment）**移到会话历史 sheet 顶部**（与历史入口同处，沿用 `startNewSession`）。
- 按钮配色：墨色 `IconButton`（`appColors.inkSoft`，hover→`ink`），不再 `agentOnBrandMuted`（white70）。

### 6.2 StatusStrip（`agent_status_strip.dart`）

合并 5 bar 为「同一时刻最多 1 条」。**位置：消息流顶部**（不再底部堆叠）。

**优先级纯函数**（可单测）：

```dart
enum AgentStatusKind { error, retry, supplement }

@immutable
class AgentStatus {
  final AgentStatusKind kind;
  final String message;        // 主文案
  final String? detail;        // 次行（HTTP 码/类别/计数）
  final Duration? countdown;   // retry 倒计时（由 RetryState 推算）
  const AgentStatus(this.kind, this.message, {this.detail, this.countdown});
}

/// 优先级：error > retry > supplement。isLoading 普通态返回 null（靠消息流流式光标）。
AgentStatus? selectStatus({
  required AgentChatState chatState,
  required RetryState? retry,
}) {
  if (chatState.error != null && !chatState.isLoading) {
    // error 无次行 detail；若 error 命中 LlmConfigService.notConfiguredMessage，
    // strip 渲染层附「去设置」动作（沿用现有 _buildErrorBar 逻辑）
    return AgentStatus(AgentStatusKind.error, chatState.error!);
  }
  if (retry != null) {
    // 字段映射以 retry_signals.dart 的 RetryState 实际定义为准：
    // 进度（attempt/maxAttempts）+ categorizeRetryError 给的类别 + Timer.periodic 推算的倒计时。
    // 下方 retryDetail()/retryRemaining() 为薄适配函数，不在此硬编字段名。
    return AgentStatus(AgentStatusKind.retry, '网络波动 · 正在重试',
        detail: retryDetail(retry), countdown: retryRemaining(retry));
  }
  if (chatState.isLoading && chatState.supplementaryCount > 0) {
    return AgentStatus(AgentStatusKind.supplement, '已补充 ${chatState.supplementaryCount} 条',
        detail: '将在下一轮处理');
  }
  return null; // idle / running-normal
}
```

- **配色**：error → `error` wash + 砖红左边线；retry/supplement → `amberWash` + 琥珀左边线。统一 padding（`h:11, v:8`）、圆角 8、左边线 3px。retry 用 `RetryBanner` 既有的 `Timer.periodic` 倒计时。
- **retry 两层**（传输层/回合层）：统一琥珀 wash，**靠文字标「传输层/回合层」区分**，不再用橙/蓝双色（消除 `Colors.orange/blue`）。
- **CompactionMarker 不进 strip**：它是消息流内的「事件标记」（带 KV 落库、重启可见），保留在 `agent_chat_messages.dart` 的列表里，渲染走现有 `CompactionMarkerCard`。

### 6.3 Messages（`agent_chat_messages.dart`）

替代 `_buildMessageList`（`:329-389`）+ `_buildEmptyState`（`:542-573`）+ `_buildJumpToBottomButton`（`:392-412`）。

- **空状态**：复用 `EmptyStateView`，但需两处扩展（向后兼容）：
  1. **`Widget? iconWidget` 可选参数**（签名当前只收 `IconData`，`:21`）：传则渲染印章式 quill SVG widget，不传走原 `Icon(icon)` 逻辑。
  2. **`TextStyle? titleStyle` 可选参数**（当前 title 写死 `theme.textTheme.headlineSmall?.copyWith(fontWeight:bold)`，`:52-55`，无法用 serif）：传则覆盖，不传走原逻辑。
  agent 空状态传 `iconWidget` + `titleStyle: AppTypography.novelTitle.copyWith(fontSize:17)`，subtitle 走原 bodyMedium。全局其他空状态不传这两参，零影响。
- **jump-to-bottom**：`FloatingActionButton.small`（M3），`backgroundColor: appColors.agentAccent`、`foregroundolor: appColors.agentOnBrand`，替换手写 `Material(circle)` + 硬编码 `Colors.white`（`:407`）。
- **气泡**（在 `agent_message_bubble.dart` 改）：
  - user：`chatButtonPrimary@0.10` wash 底 + `chatButtonPrimary@0.20` 描边 + 右上小圆角（`borderTopRightRadius:5`）。**删除**当前 `:103` 误用的 `agentAccent` 着色。**不用** `chatUserBubble`（绿黄冷调，与琥珀主题冲突）。
  - assistant：`paper` 底 + `divider` 描边（1px）+ `avatarShadow` + 左上小圆角 + 小 quill 头像 + **serif 正文**（`bodyProse.copyWith(fontSize:13, height:1.65)`）。流式光标保留（amber 闪烁竖条）。**不用** `chatRoleBubble`（冷蓝 `#DCE6F0`，与暖纸冲突）。
- **工具卡**：虚线 `divider` 描边 + `paper-deep` 表头 + monospace 工具名 + "✓ done" + 结果 + 琥珀 CTA（"查看章节 →"）。复用现有 `AgentToolCallCard`，仅调配色。

### 6.4 Composer（`agent_chat_composer.dart`）

替代 `_buildInputBar`（`:831-938`）+ `_buildQuickPrompts`（`:979-1003`）+ `_AgentInputTrailingButton`（`:1115-1212`）。

- 顶部 1px `divider`，`paper` 底。
- **chips**：统一一种 `ActionChip` 样式（消除当前两种）—— `paper-soft` 底 + `divider` 描边，hover→`amberWash` 底 + amber-deep 字；avatar 用 SVG icon（wand/book），不用 emoji。来源 `ScenarioQuickPrompts.forScenario(scenarioId)`。
- **input**：`chatInputBackground` 填充 + 圆角 14 + `divider` 描边；focus 时 `amberWash` 光晕（`boxShadow` 3px）。占位用 `chatHintText`。
- **附件预览**：关闭钮改 `inkSoft`（去 `Colors.black54`）， Positioned 收进预览框内（去半悬空圆点感）。
- **双模按钮**（attach/send）：保留 `AnimatedSwitcher`。attach → 墨色 `IconButton`（`chatInputBackground` 底 + `inkSoft`）；send → 琥珀圆角方块（`agentAccent` 底 + `agentOnBrand` icon，elevation 2）。supplementary 态 send 降饱和（`agentAccent@0.5`）保留。

---

## 7. 主题 token 清理

在 `app_colors.dart`（不破坏亮/暗两套 const）：

1. **合并同色两名**：`agentAccent` 与 `agentBrandStart` 同值。保留 `agentAccent` 作语义名，`agentBrandStart/agentEnd` 仅 FAB 渐变用（`agent_floating_button.dart`）。Header 不再用渐变 → Header 内对 `agentBrandStart/End` 的引用清零。
2. **`errorAccent` == `error`**：删除 `errorAccent`，调用点（若有）改 `error`。
3. **chat palette 分流**：暖调 token（`chatInputBackground`/`chatPrimaryText`/`chatHintText`/`chatDivider`/`chatButtonPrimary`）本次**启用**（输入框/正文/提示/分隔线/send 按钮，色值与晨读书馆同源）。冷调遗留 token（`chatRoleBubble` 亮`#DCE6F0`/`chatUserBubble` 亮`#E0E8CF`/`chatUserBubbleBorder`/`chatButtonDisabled`）是早期 Dify 时代配色，**与琥珀暖纸主题冲突，本次不启用**，标记为后续清理（独立 commit 删除或重定义）。
4. **`agentOnBrandMuted`（white70）**：Header 不再用品牌渐变后，此 token 在 agent_chat 的引用清零（其他场景 FAB 仍用，保留 token）。
5. **硬编码色替换**：`Colors.white` → `agentOnBrand`；`Colors.black54` → `inkSoft`/`chatHintText`；`Colors.orange.shade700`/`Colors.blue.shade700` → `warning`/`info`。

> 清理在独立 commit（§10 commit ①），保证可单独 revert。

---

## 8. 暗色策略

- 组件**只读语义 token**（`appColors.paper`/`ink`/`amber`/`divider`/...），**不写** `if(THEME.dark)`。
- 亮/暗值已在 `AppColors.light`/`dark` 两个 const 里定义（`app_colors.dart:152`/`:198`），通过 `ThemeExtension` 自动切换。
- 验证清单：amber 亮 `#B8843A`/暗 `#D9A05B`；paper 亮 `#FFFDF8`/暗 `#241F16`；error 亮 `#B23A2E`/暗 `#D9685A`。
- 颗粒纹理：Flutter 端用 `CustomPaint` + `feTurbulence` 等价（或低开销的预生成 noise PNG 叠加 `BlendMode.multiply` 亮 / `BlendMode.screen` 暗），mockup 已验证视觉。

---

## 9. 切场景行为（透明化，不改行为）

当前行为（`agent_chat_dialog.dart:252-264` + `scenario_sessions_provider.dart:50-97`）：切场景 = `currentAgentScenarioProvider = newId` + `currentChatSessionIdProvider = null` + 懒建/复用目标 session；**历史不丢**（每 scenarioId 独立 ScenarioSession，LRU 8/空闲 1h）。

**本次不改此行为**（不丢数据、不引入新 bug），但做透明化：

- 切场景后，若目标 scenario 的最近 session 非空，Header 上下文行自然体现「续接上次」（writing 显示当前小说、webview 显示当前 URL）。
- 切场景动作收进 ⋯ 菜单，菜单项标注能力说明（"网页提取 · 写 JS 脚本自动抓书" / "写作助手 · 编辑章节·生图·人物卡"），消除当前「swap_horiz 图标 + 场景名」的认知负担。
- 新建会话入口在会话历史 sheet 顶部（与历史同处），沿用 `ScenarioSessionsNotifier.startNewSession`。

---

## 10. 迁移路径（分 commit，每步可独立 revert）

1. **token 清理 + icon set**：`app_colors.dart` 合并同色 token + 启用 chat palette；新建 `agent_icons.dart`。`flutter analyze` 0 issue。
2. **Header**：新建 `agent_chat_header.dart`，dialog 接入；删除 `_buildWebViewInfoBar`/`_buildCurrentNovelBar`。
3. **StatusStrip**：新建 `agent_status_strip.dart` + `selectStatus` 纯函数；dialog 接入；删除 `_buildErrorBar`/`_buildStopBar`/`_buildSupplementBar`；**改 `retry_banner.dart` 配色**（去 `Colors.orange/blue`→`warning`/`error`，与 strip 琥珀/砖红统一，本步一起做避免临时不一致）。
4. **Messages**：新建 `agent_chat_messages.dart`；扩展 `EmptyStateView.iconWidget`；jump-to-bottom 改 FAB.small；改 `agent_message_bubble.dart` 气泡配色 + serif。
5. **Composer**：新建 `agent_chat_composer.dart`；统一 chip 样式。
6. **dialog 收尾**：`agent_chat_dialog.dart` 瘦身到 shell；接入 `agent_scenario_config_dialog.dart`/`compaction_marker_card.dart` 的 emoji→SVG。
7. **目视验证**：亮/暗各跑一遍 5 状态（空/正常/运行/重试/压缩），截图比对 mockup。

每步：`flutter analyze` + 相关单测 + 目视。

---

## 11. 测试策略

现 `test/**/*agent*` **零命中**（无既有 agent_chat 测试），本次新建：

- **`selectStatus` 单测**（`test/unit/services/novel_agent/status_strip_test.dart`）：优先级矩阵—— error 压 retry、retry 压 supplement、isLoading 普通态返 null、各字段映射正确。≥ 8 用例。
- **token 契约单测**：断言 `AppColors.light`/`dark` 的 `paper/ink/inkSoft/amber/error/chatButtonPrimary/chatInputBackground/chatPrimaryText/chatHintText/chatDivider` 均非 null 且亮暗不同值（防回归）。冷调遗留 token 不纳入断言（待清理）。
- **widget 测试**：
  - Header：writing/webview 两场景上下文行渲染、场景菜单弹出、未选小说可点开 picker。
  - StatusStrip：3 种 kind 各渲染一次 + null 时不渲染。
  - Messages：空状态用 `EmptyStateView`（含 iconWidget）、FAB.small 存在。
  - Composer：chips 来自 `ScenarioQuickPrompts`、输入有文本时 send 高亮、attach/send 切换。
- **回归**：`agent_message_bubble` / `compaction_marker_card` / `retry_banner` 既有的渲染契约（若有则改断言；本次新估无既有，新建基础渲染测试）。

遵循项目「功能优先 + 渐进测试 + 维护可控」原则（根 CLAUDE.md 测试策略）。

---

## 12. 风险与回退

| 风险 | 缓解 |
|---|---|
| 拆文件导致 import 洞 / Riverpod ref 传递错 | 每步 analyze + 目视；dialog shell 最后收口 |
| `EmptyStateView.iconWidget` 扩展影响其他空状态 | 可选参数 + 向后兼容；其他调用点零改动（不传即原逻辑） |
| 暗色颗粒纹理性能（CustomPaint 高频重绘） | 用预生成 noise PNG（asset）+ 单次绘制，不用每帧 turbulence |
| 清理 token 误伤 FAB 渐变 | `agentBrandStart/End` 保留，仅 Header 引用清零；commit ① 独立可 revert |
| 切场景透明化被误读为改行为 | §9 明确「不改 sessionId=null 逻辑」；不动 `scenario_sessions_provider` |

---

## 13. 参考令牌表（组件→token 映射速查）

| 组件部位 | token（亮 / 暗） |
|---|---|
| Header 底 | `paper` |
| Header 分隔线 | `divider` |
| 场景徽标底/描边/icon | `chatButtonPrimary@0.1` wash / 同@0.2 / `chatButtonPrimary` |
| 标题字 | `AppTypography.novelTitle.copyWith(fontSize:16)` + `ink` |
| 上下文行字 | `inkSoft`（sans） |
| StatusStrip error 底/线/字 | `error@0.08` / `error` / `error` |
| StatusStrip retry/supp 底/线 | `chatButtonPrimary@0.1` / `chatButtonPrimary` |
| user 气泡底/描边/字 | `chatButtonPrimary@0.10` / `chatButtonPrimary@0.20` / `chatPrimaryText` |
| assistant 气泡底/描边/字 | `paper` / `divider` / `chatPrimaryText`（serif） |
| send 按钮底/icon | `chatButtonPrimary` / `agentOnBrand` |
| 输入框底/占位/描边 | `chatInputBackground` / `chatHintText` / `divider` |
| FAB.small 底/icon | `agentAccent` / `agentOnBrand` |
| 工具卡表头底 | 复用 `chatDivider`（亮 `#DCCFB3` / 暗 `#3A3128`，已是 paper 深一档语义），**不新增 token** |

> **token 决策（最终，不留待 plan）**：mockup 里的 `paper-soft`/`paper-deep` 派生色，落地时**不新增 `AppColors` 字段**——assistant 气泡用 `paper`+`divider` 描边分层，工具卡表头用既有 `chatDivider`，composer chip 底用 `chatInputBackground`。即「纸面分层」全部复用现有暖调 chat palette token，零新增、零启用冷调遗留。
