# README & 落地页推广化重构设计

**日期**: 2026-07-28
**状态**: 已确认（待 spec review）
**分支**: master
**目标产物**: `README.md` + `docs-site/index.html`

---

## 1. 背景与目标

当前根 `README.md` 第一句就是「Flutter 离线优先的小说阅读 App…后端只承担…」技术腔，技术栈/项目结构占大量篇幅（26 screens、75 services 等数字对普通读者无意义）。落地页 `docs-site/index.html` 已有较精致的浅色阅读风设计，但：

1. **README 与落地页应用名不统一**：README 叫「随心阅读」，落地页叫「Novel Builder」，推广时会让读者困惑。
2. **README 不像给读者的**：技术文档味重，没有按用户视角描述能力，三大核心卖点（任意站阅读 / 改剧情 / 从 0 创作）淹没在技术段里。
3. **无 star 引导入口**：用户用完即走，无转化路径。
4. **B 站视频即将上线**：没有预留视频位，会导致后期改 README 时再缝。
5. **静态介绍页面（docs/APP功能介绍.md / user-guide.md / chapter-fetch-flow.html / react-agent-web-extract.html）已严重过期**：截图是旧版 UI、还写 TTS/代理/已删后端接口，误导任何看代码的下游（本文档下游实施会直接删这 4 个文件，并清理断链）。

**目标**：把 README 与落地页重构成面向目标用户（中文小说读者）的推广页，技术内容大幅折叠或外迁，文末有 star 引导。

**非目标**：
- 不重写 `docs/developer-guide.md` / `deployment.md` 等开发/部署文档（已与代码基本对齐）
- 不动 APP 内 onboarding（in-APP star 引导见已存在的 `2026-07-28-github-star-prompt-design.md`）
- 不重拍截图（按用户确认：本次纯文字 + emoji + 现有 CSS mockup，不依赖新截图）

---

## 2. 设计要点

### 2.1 README 骨架（七段）

```text
Hero（slogan + 副名 + 三按钮）
├─ 📖 读 · APP 里就能逛任意小说站
├─ ✏️ 改 · 不爽的剧情，改成你想要的
├─ 🖋️ 写 · 从 0 创作一本自己的小说
├─ 🧩 还能做这些
├─ 🎬 正在录制介绍视频
└─ 🔧 面向开发者（折叠）
```

**段落顺序理由**：核心三卖点放在最前（用户最关心），「还能做这些」是补充，「视频区」是新内容承接 star/watch 引导，「开发者区」折叠收尾照顾开源贡献者。

### 2.2 Hero 三按钮（等权重）

| 按钮 | 链接 | 措辞 |
|---|---|---|
| ⬇️ 下载 APK | GitHub Releases 最新版 | `[⬇️ 下载 APK](#下载)` |
| 🌐 在线介绍 | `https://yunkst.github.io/novel_builder/` | `[🌐 在线介绍](https://yunkst.github.io/novel_builder/)` |
| ⭐ 给个 Star | `https://github.com/yunkst/novel_builder` | `[⭐ 给个 Star](https://github.com/yunkst/novel_builder)` |

### 2.3 应用名（双名策略）

- **主名**：随心阅读（README H1 + 落地页 H1）
- **副名**：Novel Builder（H2 副标 + 落地页 title 副名）
- **品牌签名（落地页）**：AI 原生小说阅读平台

### 2.4 三大核心卖点撰写策略

| 段 | 用户视角 bullets | 技术细节 |
|---|---|---|
| 读 | 5 条用户动机（任意站点、干净正文、离线、字体反爬、书内搜索） | `<details>` 折叠：FAB 流程、Headless WebView fetchContent、PreloadService、OcrRestoreService、UI/Agent 双搜索入口、用户章节保护 |
| 改 | 6 条用户场景（补全细节、续烂尾、插情节、改设定、小修小补、风格标签）+ 版本回滚兜底 | `<details>` 折叠：工具对应关系（`update_chapter_content` / `rewrite_chapter` / `create_chapter`） |
| 写 | 「三步开始」+ 6 条陪写特性 + 引导提示 | `<details>` 折叠：system prompt 引导机制、工具清单、人物卡/大纲/标签对应表 |

**核心策略**：正文 bullets 严格使用「用户能做什么」「场景是什么」「结果是什么」，不出现工具名/类名；技术细节折叠到 `<details>`，给开发者/审阅者验证真实性用。

### 2.5 「还能做这些」（6 项，表格形式，已核代码真实）

| 能力 | 真实依据（代码位置） |
|---|---|
| 角色卡 & 关系图 | `character_list/detail/edit_screen.dart` + `relationship_graph_screen.dart` |
| 场景配图 & 动态图 | `create_images` / `create_image_to_video` + 后端 ComfyUI |
| 让 AI 扮演角色 | Agent Chat 调用 + 角色设定 prompt 注入 |
| 多书架分类 | `bookshelves` / `novel_bookshelves` 多对多表（v16） |
| 阅读风主题 | `app_colors.dart` 阅读风令牌 |
| 本地备份导出 | `backup_service.dart` + 后端 `/api/backup/*` |

**已删除（避免夸大）**：
- ❌ "5s Live Photo 动态插图"具体描述（工具定义未明确时长）
- ❌ "和角色聊天"独立产品功能（已被 Agent Chat + AI 扮演角色替代）
- ❌ "字体反爬还原"重复（「读」段已覆盖）

### 2.6 视频区（🎬 正在录制介绍视频）

```markdown
## 🎬 正在录制介绍视频

第一次见这个 APP 长什么样？看视频比看文档更快。

📺 **B 站长视频正在录制中**，预计月底上线。  
想第一时间收到提醒？给项目点个 ⭐ 或 Watch 这个仓库就行。

> 录好后这里会替换成视频封面 + 链接。
```

**作用**：占位 + star/watch 引导合并。文末另有一段 star 引导（情感性 CTA），形成功能性+情感性双 CTA。

### 2.7 面向开发者区（全折叠）

整个区域用 `<details>` 包住，默认折叠。内部包含：
- 技术栈（Flutter / Dart / Riverpod / SQLite v39 / PP-OCRv6 / Headless WebView / OpenAI 兼容 LLM）
- 源码运行命令
- 文档链接（[开发者指南](docs/developer-guide.md) / [部署指南](docs/deployment.md) / [前端模块](novel_app/CLAUDE.md) / [后端模块](backend/CLAUDE.md)）
- [CONTRIBUTING.md](CONTRIBUTING.md) 入口

### 2.8 落地页（docs-site/index.html）同步调整

| 项 | 改动 |
|---|---|
| `<title>` | 改为 `随心阅读 · Novel Builder · AI 原生小说阅读平台`（三层：主+副+修饰） |
| Hero H1 | 主名 `随心阅读` + 副 `Novel Builder`（小字） |
| Hero CTA 行 | 在原 2 个按钮后追加 `⭐ Star` 按钮（GitHub 链接） |
| 顶栏 nav-links | 追加 ⭐ Star 入口（GitHub 链接） |
| 文档链接 footer | "使用指南" 链接从 `docs/user-guide.md` 改为 `README.md`（已删 user-guide） |
| 视频位 | Hero mockup 下方预留 `<section>` 占位，未来录制后替换 |
| 风格 | 保留浅色阅读风（纸张/书卷赭石），不动 |

---

## 3. 删除/清理项（与本次强耦合）

| 文件 | 操作 | 原因 |
|---|---|---|
| `docs/user-guide.md` | 删除 | 写 TTS/代理/已删后端接口，含 `kfeb4@outlook.com` 邮箱 |
| `docs/APP功能介绍.md` | 删除 | 截图全是旧版 UI（含已删的搜索/Dify 配置入口） |
| `docs/chapter-fetch-flow.html` | 删除 | 含已删后端 `/api/cache/*` 兜底链路（2026-07-08 后端删除） |
| `docs/architecture/react-agent-web-extract.html` | 删除 | DB 标 v21（已过期到 v39），含旧 6 工具（已扩展） |
| `docs/README.md` | 重写 | 删除上述 4 个索引项，保留 superpowers / plans / 开发者指南 / 部署 / 日志 |

**断链修复**（删除文件后被牵连）：
- `README.md` 第 179-180 行：移除对 user-guide.md / APP功能介绍.md 的引用
- `docs/developer-guide.md` 第 270 行：移除对 chapter-fetch-flow.html / react-agent-web-extract.html 的引用
- `docs/developer-guide.md` 第 563 行：移除对 user-guide.md 的引用
- `docs-site/index.html` 第 621 行：使用指南链接改指 `README.md`
- `CONTRIBUTING.md` 第 221 行：用户指南说明改指根 README

**保留项**（决策追溯资产，不删）：
- `docs/plans/2025-01-25-logger-service-enhancement.md`
- `docs/plans/2026-01-26-enhanced-relationship-graph-design.md`
- `docs/superpowers/`（设计文档与实施计划，引用未删的 plans/）

---

## 4. 实施约束

1. **不重拍截图**：按用户确认，纯文字 + emoji + 现有 CSS mockup
2. **代码引用要可核**：折叠块里的 `agent_tools.dart:333` 这种引用必须是真实存在的行号（实施前需 `grep` 一次复核行号漂移）
3. **不夸大能力**：每一项能力必须是真实落地，未落地的（如"5s Live Photo"）不写
4. **「越用越懂你」措辞**：正文用情感化（"它记得"），折叠块诚实补充机制（`agent_memory` 可手改，非自动学习算法）

---

## 5. 不在本次范围（已知问题清单）

- 落地页（docs-site）当前 697 行单文件，所有改动内联修改，未来可拆为多文件但不动
- 落地页 CSS mockup 不替换为真实截图（用户已确认）
- 不实现 README 自动化构建（文档生成器、Markdown lint）
- 不动 backend/openapi.json 过期问题（CLAUDE.md 已知问题清单）

---

## 6. 验收

- `README.md` 在 GitHub 渲染下：Hero 可见、三卖点文字+折叠存在、视频区可见、Star 引导在文末
- `docs-site/index.html` 本地打开：title 含主副名三层、Hero 三按钮含 ⭐ Star、文档 footer 不指向已删文件
- `git grep -nE "user-guide\.md|APP功能介绍\.md|chapter-fetch-flow\.html|react-agent-web-extract\.html"` → 仅 `docs/superpowers/` 下历史引用命中，对外展示文档全部清零
- 四大删除文件已 `git rm`