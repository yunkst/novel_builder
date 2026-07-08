# 上下文式 Agent 启动器（Contextual Agent Launcher）设计

> 状态：设计稿（待 review）
> 日期：2026-07-08
> 作者：brainstorming 会话产出
> 关联模块：`novel_app`（纯前端，不涉及后端爬虫）

## 1. 背景与目标

App 中存在一类需求：**某些按钮点击后，把上下文信息提供给 ReAct agent，由 agent 结合场景信息创建一次全新对话，输入框直接预填相关背景信息，用户可直接发送（或自动发送）让 agent 工作。**

目前这类需求没有通用基础设施，只有"用户手动点悬浮按钮发起对话"一条触发路径。本设计提供一个**通用启动器**，把"按钮点击"转化为"一次准备好上下文的 agent 对话"，并以两个场景作为调用方：

- **信息提取**：用户浏览小说网站时点"添加到书架"，常规脚本提取失败 -> 触发 agent 对话修复/生成提取脚本。
- **添加章节**（仅契约）：用户在目录页点"添加章节"，上下文配好后输入框预填"在第 X 章后添加新章"，用户编辑要求后发送。

本 spec 的实现边界为：**启动器核心 + 信息提取接入完整实现 + 添加章节接入契约**。

## 2. 现状摸底

基于代码探索，现有架构已覆盖通用启动器所需的大部分拼图，**真正缺的只有"编程式触发 + 上下文注入 + 草稿预填"这一层**。

### 2.1 已有能力（复用）

| 能力 | 现状 | 位置 |
|---|---|---|
| ReAct Agent 循环 | `AgentLoop`，Function Calling 驱动，maxRounds=50 | `novel_app/lib/services/novel_agent/agent_loop.dart` |
| 场景抽象 | `AgentScenario` 接口，已有 `WritingScenario` / `WebViewExtractScenario` | `novel_app/lib/services/novel_agent/agent_scenario.dart` |
| 场景按 Tab 自动切换 | 进浏览器 Tab 切 `webviewExtract`，其他切 `writing` | `novel_app/lib/main.dart:273-276, 342-348` |
| Headless 后台提取 | `HeadlessWebViewPool` 排他占用，`webview_extract` 默认 headless | `novel_app/lib/core/providers/scenario_session.dart:980`、`novel_app/lib/services/headless_webview_pool.dart` |
| 跨页面任务进度订阅 | `extractionTaskProvider`（idle/analyzing/executing/saving/done/error） | `novel_app/lib/core/providers/extraction_task_providers.dart` |
| 提取场景与工具集 | `WebViewExtractScenario`，9 工具：`get_page_info`/`execute_js`/`navigate_to`/`get_current_url`/`save_script`/`get_cached_script`/`inspect_script`/`get_script_logs`/`list_cached_scripts` | `novel_app/lib/services/novel_agent/scenarios/webview_extract_scenario.dart` |
| 脚本存储 | `site_scripts` 表（纯前端 SQLite），按 domain 存两段 JS（`chapter_list_js` + `chapter_content_js`），每域名一条 | `novel_app/lib/core/database/database_migrations.dart:526-544`、`novel_app/lib/repositories/site_script_repository.dart` |
| 悬浮按钮 + 对话框 | `AgentFloatingShell` + `AgentFloatingButton` + `AgentChatDialog` | `novel_app/lib/main.dart:354`、`novel_app/lib/widgets/agent_chat/` |
| DOM 启发式 pageType | `_inferPageTypeJs`（链接密度/段落），仅 agent 路径用 | `webview_extract_scenario.dart:1532-1568` |
| 会话/消息持久化 | v32 统一历史模型，`ChatSession` / `ChatMessageRecord` | `novel_app/lib/models/chat_session.dart`、`novel_app/lib/models/chat_message_record.dart` |

### 2.2 缺口

1. **无编程式触发**：`AgentFloatingButton._showChatDialog` 是私有方法，外部按钮无法调用"打开对话框 + 切场景 + 注入上下文 + 预填草稿"。
2. **FAB 编排不完整**：`WebViewAddNovelFab._handleAddNovel`（`novel_app/lib/widgets/webview_add_novel_button.dart:76`）只有"有脚本 -> 执行"一条路；脚本失败只 toast，无脚本时 FAB 不显示，无法触发 agent。
3. **FAB 不识别目录页**：`webviewHasAddNovelButtonProvider`（`novel_app/lib/core/providers/webview_add_novel_providers.dart:57-63`）只判域名是否有 `chapterListJs`，`urlPattern` 字段未使用，DOM 启发式未接入 FAB。
4. **无"引导用户去目录页"能力**：FAB 在非目录页点击只 toast"未提取到章节"。

## 3. 目标与范围

### 3.1 做

- 通用启动器 `ContextualAgentLauncher`：按钮点击 -> 注入上下文 -> 新建对话 -> 预填草稿 -> `autoSend` / `draftOnly`。
- 信息提取接入（完整）：FAB 三分支编排 + 失败/无脚本降级触发启动器 + agent 跑完存脚本（用户重试入库）。
- 添加章节接入（契约 only）：给出 `AgentLaunchRequest` 草案，完整实现留后续 spec。

### 3.2 不做（YAGNI）

- 字段扩展（保持 `title` + `chapters`，不补 author/简介/封面）。
- 添加章节的完整实现（`WritingScenario` 章节插入工具、目录页按钮）。
- 后端爬虫链路改动（纯前端）。
- 正文脚本独立触发路径（正文脚本由 agent 在同一次会话跳转验证生成）。
- 自动入库衔接（agent 跑完只存脚本，入库由用户手动重试 FAB）。

## 4. 整体架构

```
任意按钮点击
   │
   ▼
ContextualAgentLauncher.launch(AgentLaunchRequest)
   │
   ├─ 1. 创建全新 ChatSession（指定 scenarioId）
   ├─ 2. 构造 AgentScenarioContext，注入 request.context
   ├─ 3. 编程式展开 AgentChatDialog（复用，不新建组件）
   ├─ 4. 预填 draftMessage 到输入框
   └─ 5. mode==autoSend -> 自动 NovelAgentService.sendMessage 发送
        mode==draftOnly -> 停在预填态等用户编辑后手动发送

两个调用方：
  • WebViewAddNovelFab（失败降级）  -> launch(webview_extract, autoSend)
  • 目录页"添加章节"按钮（后续）    -> launch(writing, draftOnly)
```

职责分离原则：**agent 只管生成/修复脚本并存库；FAB 只管用现有脚本入库。两者靠 `site_scripts` 表解耦。**

## 5. 核心组件：`ContextualAgentLauncher`

### 5.1 API

```dart
enum LaunchMode { autoSend, draftOnly }

class AgentLaunchRequest {
  final String scenarioId;            // 'webview_extract' / 'writing'
  final Map<String, dynamic> context; // 场景上下文（URL/novel/失败原因/旧脚本…）
  final String draftMessage;          // 预填到输入框的草稿
  final LaunchMode mode;
  final String? title;                // 会话标题（可选）
}

class ContextualAgentLauncher {
  /// 防重入：若该 scenarioId 已有 agent 在跑，聚焦展开现有对话框并提示，
  /// 不新建会话、不 cancel 正在跑的 agent。
  Future<void> launch(AgentLaunchRequest request);
}
```

### 5.2 `launch()` 行为

1. **防重入检查**：若该 `scenarioId` 当前已有 agent 运行中，改为聚焦展开现有 `AgentChatDialog` 并 toast"上一次仍在进行中"，直接返回。
2. **创建全新会话**：通过 `ScenarioSession` 新建 `ChatSession`（指定 `scenarioId`），落库。不复用当前场景已有会话（避免污染历史）。
3. **构造并注入上下文**：构造 `AgentScenarioContext`，把 `request.context` 注入（对 `webview_extract`：`currentUrl`/`domain`/旧脚本/失败原因等）。由 `AgentScenarioFactory.build` 据此构造场景实例（headless 模式自动启用）。
4. **编程式展开对话框**：调用从 `AgentFloatingButton._showChatDialog` 抽出的可复用展开函数（见 5.3），展开 `AgentChatDialog`。
5. **预填草稿**：通过 `AgentChatDialog` 新增的 `setInputPrefill(String)` 入口把 `draftMessage` 填入输入框。
6. **按 mode 收尾**：
   - `autoSend` -> 调 `NovelAgentService.sendMessage(draftMessage)`。草稿作为**可见的首条 user message** 进入对话（可回滚，复用 `agent_message_bubble.dart` 回滚按钮）。
   - `draftOnly` -> 停在预填态，等用户编辑后手动点发送。

### 5.3 现有组件改造点

| 步骤 | 现状 | 改造 |
|---|---|---|
| 创建新会话+切场景 | `ScenarioSession` 已支持按 scenarioId 管理，切 sessionId 会 cancel 老 agent | 新增"以指定 context 创建全新 ChatSession"的工厂方法 |
| 编程式展开对话框 | `AgentFloatingButton._showChatDialog` 私有 | 抽成可复用展开函数（或 Launcher 直接驱动 `AgentFloatingShell` 状态） |
| 预填草稿 | `AgentChatDialog` 输入框是内部 controller | 暴露 `setInputPrefill(String)` 入口 |
| autoSend 发送 | `NovelAgentService.sendMessage` 已是 UI 入口 | Launcher 直接调，传 draftMessage |

### 5.4 关键抉择

- **会话策略 = 全新**：每次 launch 新建 `ChatSession`，不复用当前场景已有会话。
- **草稿在 autoSend 下可见**：作为首条 user message 进入对话（可回滚），不作隐藏系统上下文。
- **关闭对话框 ≠ cancel agent**：agent 继续后台跑（headless），符合 `extractionTaskProvider`"对话框关闭也能看进度"的设计意图。

## 6. 接入场景 A：信息提取（完整）

### 6.1 FAB 三分支编排

改造 `novel_app/lib/widgets/webview_add_novel_button.dart` 的 `_handleAddNovel`：

```
点击 FAB（可见性改造：无脚本时也显示）
   │
   ├─ 域名有脚本？
   │   ├─ 有 -> 执行 chapterListJs（快速路径，现状逻辑）
   │   │      ├─ 拿到有效 chapters -> 入库 + 跳转（现状）
   │   │      └─ 拿不到（报错/空/格式错）-> 降级 launch(autoSend)
   │   └─ 无 -> 降级 launch(autoSend)
```

**FAB 可见性改造**：`webviewHasAddNovelButtonProvider`（`webview_add_novel_providers.dart:57-63`）改为"当前在 http(s) 页面即显示"，不再以"域名有脚本"为前提。无脚本时点击直接走降级。

### 6.2 降级时的 `AgentLaunchRequest`

- `scenarioId`：`webview_extract`
- `context`：`{currentUrl, domain, oldScript?: chapterListJs, failureReason}`
- `draftMessage`（按失败类型生成）：
  - 无脚本：`"当前站点(${domain})还没有提取脚本。请为目录页 ${url} 编写目录提取脚本和正文提取脚本。"`
  - 脚本报错：`"现有目录提取脚本执行失败：${error}。请修复。"`
  - 脚本空结果：`"现有脚本未提取到章节。请先用 get_page_info 确认当前是否为目录页：若不是，请引导用户前往目录页；若是，请修复脚本。"`
- `mode`：`autoSend`

### 6.3 agent 内部分流（目录页判断，全交 agent）

注入的 context + 现有 system prompt 引导 agent：

1. `get_page_info` 判断页面类型。
2. **非目录页** -> agent 在对话框发文字引导用户前往目录页（不强行提取、不存脚本）。
3. **是目录页** -> 生成/修复 `chapter_list_js`，`execute_js` 验证 -> `navigate_to` 第一章正文页看 DOM -> 生成验证 `chapter_content_js` -> 导航回目录页 -> `save_script`（两段都验证通过才存）。

全程 headless（`HeadlessWebViewPool`），不打扰用户当前浏览页。

### 6.4 agent 跑完衔接入库（用户重试）

- agent 跑完 -> `save_script` 存库 -> 对话框提示"脚本已就绪，请重新点击添加到书架"。
- **不自动入库**。用户重新点 FAB -> 因脚本已存，走快速路径执行入库 + 跳转章节列表。
- 职责解耦：agent 只写 `site_scripts`，FAB 只读 `site_scripts` 入库。

### 6.5 进度展示

复用 `extractionTaskProvider`（agent 执行工具时已更新 phase），对话框内 + 任意页面都能看进度。

## 7. 接入场景 B：添加章节（契约 only）

本次只给出启动器调用契约，完整实现（`WritingScenario` 章节插入工具、目录页按钮、草稿模板）留后续 spec。

```dart
ContextualAgentLauncher().launch(AgentLaunchRequest(
  scenarioId: ScenarioIds.writing,
  context: {
    'novelId': <当前小说 id>,
    'novelTitle': <书名>,
    'afterPosition': <在第几章后插入>,
    'afterChapterTitle': <参考章标题>,
  },
  draftMessage: '请在第 ${afterPosition} 章《${afterChapterTitle}》之后添加新的一章。'
                 '请补充新章节的标题与内容要求：',
  mode: LaunchMode.draftOnly,
));
```

后续 spec 需补：`WritingScenario` 的 `add_chapter_after_position` 工具、目录页"添加章节"按钮、章节位置定位逻辑。

## 8. 数据流（时序）

```
用户点 FAB（无脚本或脚本失败）
  │
  ▼
FAB 构造 AgentLaunchRequest(autoSend)
  │
  ▼
ContextualAgentLauncher.launch()
  ├─ 防重入检查（同 scenarioId 在跑则聚焦现有对话框，返回）
  ├─ 新建 ChatSession(webview_extract)
  ├─ 注入 context（URL/domain/旧脚本/失败原因）
  ├─ 展开 AgentChatDialog
  ├─ 预填 draftMessage
  └─ autoSend -> NovelAgentService.sendMessage(draftMessage)
        │
        ▼
      AgentLoop（headless）
        ├─ get_page_info 判断页面类型
        ├─ 非目录页 -> 对话框发引导文字 -> 结束（不存脚本）
        └─ 是目录页 -> 生成验证 chapter_list_js
              ├─ navigate_to 第一章 -> 生成验证 chapter_content_js
              ├─ 导航回目录页
              └─ save_script 存库
        │
        ▼
      AgentDoneEvent -> 对话框提示"脚本已就绪，请重新点添加到书架"
        │
        ▼
用户重试 FAB -> 脚本已存 -> 快速路径执行 -> 入库 + 跳转章节列表
```

## 9. 错误处理与边界

- **agent 修不好/超时**：`AgentLoop` maxRounds=50 兜底自动总结结束；脚本未存 -> 对话框提示"未能生成可用脚本，请稍后重试或换站点"。
- **LLM 配置缺失/网络失败**：autoSend 发送即失败 -> 对话框显示错误（现有 `AgentErrorEvent`），草稿仍在输入框，用户可手动重发。
- **用户关闭对话框**：agent 继续后台跑（headless），任意页面通过 `extractionTaskProvider` 看进度，脚本存库后 `phase=done`。不 cancel。
- **并发/重入**：`launch()` 防重入（见 5.2 步骤 1）。
- **HeadlessWebViewPool 排他**：agent 跑提取时占用池中一个 controller；本次仅 FAB 一个触发源，冲突概率低，沿用池现有排队语义。
- **用户在非目录页**：agent `get_page_info` 判定非目录页 -> 对话框发引导文字，不提取、不存脚本；用户去目录页后重试 FAB。

## 10. 测试策略

- **启动器单测**：`launch()` 各 mode 行为（新建会话/切场景/预填/autoSend 发送/draftOnly 停留/防重入）。
- **FAB 编排单测**：三分支判定（有脚本成功 / 有脚本失败降级 / 无脚本降级）+ 可见性（无脚本也显示）。
- **降级 request 构造单测**：`draftMessage` 按失败类型（无脚本/报错/空结果）正确生成。
- **agent 分流集成测试**：mock headless webview，验证 目录页->生成两段脚本 / 非目录页->引导 / 脚本坏->修复。
- **复用现有**：`WebViewJsExecutor`、`SiteScriptRepository` 已有测试不重测。

## 11. 不在范围（YAGNI）

- 字段扩展（author/简介/封面）。
- 添加章节完整实现（仅给 launch 契约）。
- 后端爬虫链路改动。
- 正文脚本独立触发路径。
- 自动入库衔接（用户手动重试）。

## 12. 关键决策记录

| # | 决策点 | 选择 |
|---|---|---|
| 1 | 对话框形态 | 复用现有可聊天 `AgentChatDialog`，agent 自动发起执行，用户可中途插话 |
| 2 | 目录页判断 | 全部交给 agent（FAB 不预判，agent 用 `get_page_info` 自判） |
| 3 | 编排结构 | 三分支 + 职责分离：有脚本走快速路径；失败/无脚本触发 agent；agent 只管脚本，入库交回 FAB |
| 4 | 失败降级 | 统一降级：快速路径拿不到有效 chapters 即降级 agent，agent 内部分流 |
| 5 | 提取范围 | 目录页 + 正文一起：agent 一次会话生成两段脚本 |
| 6 | 正文脚本生成 | agent 主动跳转验证（headless 模式，不打扰用户） |
| 7 | 字段范围 | 保持 `title` + `chapters`，不扩展 |
| 8 | 触发模式 | 信息提取 `autoSend`；添加章节 `draftOnly`；启动器支持两种 |
| 9 | spec 边界 | 启动器核心 + 信息提取完整 + 添加章节契约 only |
| 10 | 衔接入库 | 用户自己重试（agent 只存脚本，不自动入库） |
| 11 | autoSend 草稿 | 作为可见首条 user message（可回滚） |
