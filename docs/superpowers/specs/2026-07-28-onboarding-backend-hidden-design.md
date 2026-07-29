# 设计：后端服务作为进阶功能隐藏

**日期**: 2026-07-28
**类型**: 产品设计 + 前端 UI 调整
**状态**: 设计已确认，待写实现计划

## 背景与动机

新手首次启动 app 时，onboarding 第 2 步就要求配置后端服务（HOST + TOKEN）。但根 CLAUDE.md 的变更记录显示，**多站点搜索与章节缓存功能已于 2026-07-08 彻底删除**，而后端这两项功能正是 onboarding 用来劝用户配后端的核心理由。

当前事实（经代码调研确认）：

1. **阅读核心路径完全纯本地**：书架 → 章节列表 → 正文 → AI Agent，全程不依赖后端。`bookshelf_screen.dart` / `chapter_list_screen_riverpod.dart` 对 `apiService|backend` 零引用；`reader_content_controller.dart` 注释明确"章节内容提取走 HeadlessWebView + 本地缓存，不依赖后端 API"。
2. **LLM 与后端解耦**：DSL Engine / AI Agent 走 OpenAI 兼容协议直连 LLM，不引用 `apiServiceWrapper` / `backend_host`。LLM 是核心功能。
3. **后端现在真正只剩三件事**：数据备份（`/api/backup/*`）、日志上报（`/api/logs/upload`）、ComfyUI 文生图/图生视频（`/api/text2img/*`、`/api/image-to-video/*`）。
4. **代码层已全部优雅降级**：`apiServiceWrapper.init()`、`ReaderContentController`、`chapter_list_providers`、`media_executor`、`backup_management_screen`、`log_reporter_service` 所有后端调用点都 try/catch 兜底，后端不可达不崩溃、不打断主流程。
5. **onboarding 文案已过期且误导**：`onboarding_screen.dart:453-455` 仍写"后端用于多站点搜索和章节缓存加速"，向新用户承诺一个已不存在的功能。

**核心问题**：在核心阅读/AI 写作路径都不依赖后端的情况下，仍在 onboarding 第二步让新手配置后端，是把一个进阶、可选、需要自建部署的能力，错误地呈现为核心前置步骤，制造了不必要的上手门槛。

## 目标与非目标

### 目标
- 新手「打开 app → 看书 → 用 AI 写作」的主路径完全不被后端概念打扰
- 后端依赖的三项进阶功能（备份 / 日志上报 / ComfyUI 文生图）从 onboarding 与设置页主区域消失，收纳到一个默认折叠的"进阶服务"分组
- 修正过期误导文案
- Agent 文生图工具在后端不可用时，向用户清晰传达"这是进阶功能 / 需本地部署 + 配置路径"，而非含糊的"后端不可用"

### 非目标（YAGNI 边界）
- **不改架构** —— 代码层优雅降级已完备，本次只动 UI 入口、文案、错误提示
- **不动 LLM / DSL Engine 链路**
- **不动书架 / 章节列表 / 阅读器**
- **不动 `ApiServiceWrapper` / `BackupService` / `LogReporterService` 的实现**
- **不动三个二级屏内部**（`BackendSettingsScreen` / `BackupManagementScreen` / `LogReportSettingsScreen`）
- **不引入新依赖、不动 DB schema**

## 设计

### 模块 1：onboarding 去掉后端配置步

**文件**：`lib/screens/onboarding/onboarding_screen.dart`

**当前状态**：6 步向导，步骤索引常量 `_stepCount = 6`（行 42），`_indexBackend = 1`（行 45），`_indexAi = 2`（行 46）。

| 当前步骤 | 索引 | 内容 |
|---|---|---|
| 0 | 欢迎页 | APP 定位 |
| 1 | **后端服务配置** | `_buildBackendConfigPage`（行 401-488），可选，文案过期 |
| 2 | AI 引擎配置 | 关键步骤，解锁 AI |
| 3 | 找书方式介绍 | 浏览器浏览 → 添加小说 |
| 4 | 阅读增强亮点 | AI 特写 / 插图 / 改写 |
| 5 | 完成 | |

**改法**：6 → **5** 步，删除后端配置页。

1. `_stepCount` 由 `6` 改为 `5`。
2. 删除常量 `_indexBackend = 1`（行 45）。
3. 删除方法 `_buildBackendConfigPage`（行 400-488，约 88 行）。
4. 删除方法 `_saveBackendAndContinue`（行 102-130 附近）及其在状态机中的调用分支。
5. 删除字段 `_backendHostController` / `_backendTokenController`（行 49-50）及其 `dispose`（行 63-64）。
6. 删除相关 import（若删除后 `apiServiceWrapperProvider` / `service_providers.dart` 不再被引用，则一并删除 import；保留前需确认无其他引用）。
7. 后续步骤索引同步左移：AI 引擎 = 新步骤 1，找书方式 = 新步骤 2，阅读增强 = 新步骤 3，完成 = 新步骤 4。
8. 同步 PageView 的 `children` 顺序与 `_buildXxxPage` 的索引判断，确保 `_currentPage` 与 `controller.jumpToPage` 一致。

**新增轻提示**（在"阅读增强亮点"页底部加一行）：

> 还有 AI 出图、数据备份等进阶功能，可在「设置 → 进阶服务」中按需开启。

样式：居中、次级色（`colorScheme.onSurfaceVariant`）、`bodySmall` 或 `bodyMedium`，不喧宾夺主。不放在 AI 引擎那一步（避免与"解锁 AI 是核心"的叙事冲突）。

**类文档注释同步**（行 16-22）：把步骤描述从 6 步改为 5 步，删除"后端服务（可选，用于多站点搜索/缓存）"一行。

**兼容性**：
- `onboardingNotifierProvider.onboardingCompleted` 持久化键不变，已完成的用户不受影响。
- 旧用户若配过 backend host 但未完成 onboarding，重新进 onboarding 时后端配置表单被删——但 host/token 独立存在 SharedPreferences，不丢失，仍可在「设置 → 进阶服务 → 后端服务配置」看到。**无数据迁移需求**。

**回归风险点**：
- 步骤索引左移后，PageView `controller.jumpToPage` 的目标值需逐一核对。
- `_saveBackendAndContinue` 删除后，AI 引擎那一步的 `_goToNextPage` 调用要确认仍能正确推进。

### 模块 2：设置页新增"进阶服务"折叠分组

**文件**：`lib/screens/settings_screen.dart`

**当前结构**（按行号）：
- 「数据」分组（行 231-311）：后端服务配置 / 数据备份 / 修复数据库 / 应用日志 / LLM 调用日志
- 「诊断」分组（行 314-365）：预加载队列 / **日志上报** / 媒体缓存
- 「新手」分组（行 368+）：新手引导 ...

**收纳边界**：只把**明确依赖后端**的三项移入新分组：

| 移入项 | 来源分组 | 来源行号 | 新顺序（按"新手最可能用到"） |
|---|---|---|---|
| 后端服务配置 | 数据 | 237-250 | 1 |
| 数据备份 | 数据 | 251-266 | 2 |
| 日志上报 | 诊断 | 334-348 | 3 |

**留在原位的项**（本地诊断，不依赖后端，出问题要随时能找到）：
- 修复数据库（数据分组）—— 数据库损坏时必须直达
- 应用日志（数据分组）
- LLM 调用日志（数据分组）
- 预加载队列（诊断分组）
- 媒体缓存（诊断分组）

**新分组形态**：
- 位置：设置页**最底部**（「新手」分组之后）。
- 标题：`进阶服务`。
- `_SettingsSection` 的 `subtitle`：`后端部署 · 数据备份 · 远程日志`（提示后端依赖性质）。
- 图标 / accentColor：沿用与后端语义贴合的图标（如 `Icons.cloud_outlined`）和已有的中性 accent 色（不抢眼）。
- **默认折叠**：分组标题旁带次级色小徽章 `advanced`（参考 onboarding 已有"可选"徽章样式 `onboarding_screen.dart:425-442`，若可抽为共享组件则复用，否则就地写一个一致的样式）。
- 折叠交互：沿用项目已有的可折叠分组模式（若 `_SettingsSection` 当前不支持折叠，则在该分组外包一层 `ExpansionTile`，或在 `_SettingsSection` 内加可选的 `initiallyExpanded` 参数——**实现时取更小改动的方案**）。
- 展开状态持久化：**YAGNI，不做**。每次进设置页默认折叠；进阶用户点开一次即可用，不强求记忆。

**不改**：
- 三个二级屏内部（`BackendSettingsScreen` / `BackupManagementScreen` / `LogReportSettingsScreen`）。
- 三个 Tile 的导航逻辑与 `_loadLastBackupTime` 等回填逻辑。
- 设置页顶部核心 Tile（LLM / 字体 / 主题 / 阅读设置 / 关于等）。

**「数据」「诊断」两分组的 subtitle 同步**：
- 「数据」分组 subtitle（行 235）当前为`后端配置 · 备份 · 日志`——后端配置和备份移走后改为`数据库 · 应用日志`（保留修复数据库/应用日志/LLM 调用日志的语义）。
- 「诊断」分组 subtitle（行 318）当前为`队列监控 · 上报配置`——日志上报移走后改为`队列监控 · 媒体缓存`。

### 模块 3：Agent 文生图工具的后端提示改造

**文件**：`lib/services/novel_agent/tool_executor/media_executor.dart`

**当前行为**：三处 try/catch 返回 `{error: 'backend_unavailable', message: '...'}`，文案为"请告知用户检查后端服务与 ComfyUI 是否正常运行"，未点明"进阶功能 / 需本地部署"，新手易误以为 app 故障。

| 方法 | 行号 | 当前 message |
|---|---|---|
| `listText2ImgModels` | 48-51 | `无法获取文生图模型列表：$e。请告知用户检查后端服务与 ComfyUI 是否正常运行。` |
| `createImages` | 123 附近 | 类似句式 |
| `createImageToVideo` | 214 附近 | 类似句式 |

**改法**：只改三处 `message` 文案，不改 `error` 字段、不改返回结构、不改调用链。

**文案模板**（按后端状态分两支）：

分支 A —— 后端 HOST 未配置：
> AI 出图是进阶功能，需要本地部署后端服务（含 ComfyUI）。
> 如已部署，请在「设置 → 进阶服务 → 后端服务配置」填入地址；未部署可暂时跳过，不影响阅读与 AI 写作。

分支 B —— 后端已配置但不可达（网络错误 / ComfyUI 未启动）：
> 无法连接到后端服务：$e。AI 出图是进阶功能，需要本地部署后端服务（含 ComfyUI）。
> 请在「设置 → 进阶服务 → 后端服务配置」检查地址，或确认后端与 ComfyUI 已启动。

**实现细节**：
- 分支判定：通过 `apiServiceWrapperProvider` 暴露的 host 是否为空区分（若现有 API 无直接读取 host 的方法，则统一用分支 B 的句式并在 catch 内判 `e` 是否为 host 相关异常——**实现时以现有可读字段为准，避免新增公共方法**）。
- 文案提到「设置 → 进阶服务 → 后端服务配置」路径，与模块 2 的分组标题、Tile 标题**字字对应**，用户照走能找到。
- 三处文案提取为文件内私有常量（如 `_kBackendUnconfiguredMsg` / `_kBackendUnreachableMsg`），避免重复硬编码。

**不改**：
- `error` 字段（`backend_unavailable`），上游 `media_executor` 调用方与 Agent 工具协议不变。
- ComfyUI 健康检查逻辑。
- 成功路径。

## 涉及文件清单

| 文件 | 改动类型 | 说明 |
|---|---|---|
| `lib/screens/onboarding/onboarding_screen.dart` | 删除 + 改文案 | 删后端配置步、状态机、字段、import；类注释同步；阅读增强页加轻提示 |
| `lib/screens/settings_screen.dart` | 移动 Tile + 新增分组 | 3 个 Tile 移入新「进阶服务」折叠分组；两处 subtitle 同步 |
| `lib/services/novel_agent/tool_executor/media_executor.dart` | 改文案 | 3 处 `backend_unavailable` 的 message 按新模板改写，提取常量 |

## 测试策略

遵循项目"功能优先、渐进测试"原则。本次为 UI 入口与文案调整，无逻辑分支变更：

- **onboarding**：手动验证 5 步向导能走完、无 PageView 索引错位；review 模式（设置页"重新查看引导"）也正常。
- **设置页**：手动验证「进阶服务」分组默认折叠、点开看到 3 个 Tile、Tile 跳转正确；「数据」「诊断」剩余 Tile 不受影响。
- **media_executor**：若现有有单测覆盖 `backend_unavailable` 返回结构，需同步断言新文案（grep 测试文件确认）；无则补一个验证 `error` 字段不变的契约测试。
- **回归**：核心阅读路径（书架→章节→正文）手动走一遍，确认无任何后端依赖报错。

## 风险与权衡

- **风险 1：onboarding 步骤索引左移引入跳转 bug**。缓解：逐一核对 `_currentPage` / `jumpToPage`，手动跑完整向导。
- **风险 2：折叠分组改动 `_SettingsSection` 可能影响其他分组**。缓解：取最小侵入方案（优先外层包 `ExpansionTile` 或加可选参数，不改既有分组行为）。
- **权衡：展开状态不持久化**。进阶用户每次需点一下。可接受——进阶用户本就低频，且持久化要新增 SharedPreferences 键，违反 YAGNI。

## 与已有变更记录的关系

本次设计是对根 CLAUDE.md「2026-07-08 移除 backend 搜索与多站点爬虫功能」的**前端收尾**——后端功能早已精简，但前端 onboarding 与设置页的呈现滞后，仍在用旧叙事引导用户。本次让前端呈现追平后端现状。
