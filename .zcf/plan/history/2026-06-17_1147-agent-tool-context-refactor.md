# Agent 工具上下文驱动重构

**创建时间**: 2026-06-17 11:47:14
**状态**: 已批准，开始执行

## 目标

将 Agent Tools 从"全局 ID 直传"重构为"上下文驱动"：
- AI 通过 `select_novel` 切换当前小说
- 所有读写工具隐式作用于当前小说
- 章节操作用 `position`（顺序号）替代 `chapterId`（数据库主键）

## 设计决策

- **Q1 小说切换**: C — 提供 `select_novel` 工具，AI 主动切换
- **Q2 序号语义**: B — `list_chapters` 返回的 `position`（连续 1-based）
- **Q3 兼容策略**: A — 完全替换，移除旧 ID 接口

## 执行步骤

### 步骤 1: 扩展 AgentScenarioContext
- 文件: `lib/services/novel_agent/agent_scenario.dart`
- 新增 `currentNovelId` + `currentNovelTitle`

### 步骤 2: 重构 AgentTools 工具定义
- 文件: `lib/services/novel_agent/agent_tools.dart`
- 新增 `select_novel`
- 移除所有工具的 `novelId` 参数
- `chapterId` 改名为 `position`

### 步骤 3: 重构 ToolExecutor
- 文件: `lib/services/novel_agent/tool_executor.dart`
- 新增 `_resolveCurrentNovelUrl` 辅助方法
- 新增 `_resolveChapterUrl(position)` 辅助方法
- 所有工具改从上下文读取当前小说
- 新增 `select_novel` 实现

### 步骤 4: 扩展 WritingScenario
- 文件: `lib/services/novel_agent/scenarios/writing_scenario.dart`
- 工具列表新增 `select_novel`
- `buildSystemPrompt` 注入当前小说信息

### 步骤 5: 新增 currentNovelProvider
- 文件: `lib/core/providers/current_novel_provider.dart`（新建）
- `CurrentNovel` 数据类
- `currentNovelProvider` StateProvider

### 步骤 6: 扩展 HermesChatState/Notifier
- 文件: `lib/core/providers/hermes_providers.dart`
- `HermesChatState` 新增 `currentNovel` 字段
- `selectNovel` 方法
- `_buildScenarioContext` 注入当前小说

### 步骤 7: UI 展示当前小说
- 文件: `lib/widgets/hermes/hermes_chat_dialog.dart`
- 在头部下方显示当前小说 chip
- 点击触发切换对话框

### 步骤 8: 新增小说选择对话框
- 文件: `lib/widgets/hermes/hermes_novel_picker_dialog.dart`（新建）
- 列出所有小说供选择

### 步骤 9: 验证
- 运行 `flutter analyze`
- 运行相关测试

## 风险点

1. 现有 system prompt 中对 `chapterId` 的引用需要同步修改
2. `position` 计算依赖 `getCachedNovelChapters` 按 `chapterIndex` 排序
3. `search_in_chapters` 返回的章节标识需统一为 `position`

## 验收标准

- 所有旧 `chapterId`/`novelId` 参数已移除
- AI 工具调用能正确通过 `position` 操作章节
- 切换小说后，新操作作用于新小说
- UI 头部展示当前小说
