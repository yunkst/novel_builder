# GitHub 展示优化 + 文档系统同步现状 · 设计 Spec

**日期**: 2026-07-27
**作者**: yunkst (AI 协助)
**状态**: Draft（待用户复审）

---

## 1. 背景与目标

Novel Builder 仓库在 GitHub 展示层与代码实况之间已积累大量脱节：根 `CLAUDE.md`、子模块 `CLAUDE.md`、README、docs/ 子集等内容停留在「Dify + Scrapling + 9 站爬虫 + v21」叙事，而代码实况是「DSL Engine + Agent Chat + Headless WebView + ComfyUI + PP-OCRv6 + v39」。本次设计目标是：

1. **修展示**：README 与 GitHub Pages 介绍页对外讲同一个故事——项目是什么、谁维护、怎么跑、有什么 API/能力。
2. **修文档**：CLAUDE.md 三件套（根 + `novel_app/` + `backend/`）和 docs/ 子集与现状严格一致。
3. **仓库卫生**：清理占位元信息、Windows 个人机路径、个人邮箱泄露、起手坑（`.env.example` ↔ `docker-compose.yml` 字段不一致、`requirements.txt` 残留已删依赖）这些 GitHub 公开可见的「脏点」。

**明确不做**：不动业务代码、不改 schema/migration、不删 `docs/superpowers/`、不动 CI workflow 结构、不修 `Dockerfile.debug`/`Dockerfile.test`/`Dockerfile.simple` 残留（属构建链修复，单列后续 PR）、不动 dead code（exceptions / ruff.toml）。

---

## 2. 锁定决策汇总

| 项 | 值 | 备注 |
|---|---|---|
| 工作 scope | 展示层 + 仓库卫生 | 业务代码不动 |
| 品牌身份 | `yunkst` | 与 `git remote origin = yunkst/novel_builder` 一致（**覆盖** 初轮「以 LICENSE 为准 yedazhi」决策，因 GitHub 链接改 `yedazhi` 会指向不存在仓库 404） |
| 文档语言 | 仅中文 | 不另开 README.en.md |
| 维护邮箱 | 全部脱敏 | `kfeb4@outlook.com` → 指向 GitHub Issues / Security Advisories |
| 改造方案 | 方案 A：分阶段切片 | P1→P2→P3→P4，四个 commit，独立可回滚 |
| CLAUDE.md 定位 | 与 README 并存 | 两份对外，统一同步到现状 |
| docs/ 处理 | 全量修正过期处 | 保留 `docs/superpowers/` 作决策追溯资产 |
| novelty tab 数 | 3（书架/浏览器/设置） | 文档旧的「4 Tab（生图调试）」是错的 |
| 文档不留 English 镜像 | 是 | 与现有仓库语言一致 |

---

## 3. 范围

### 3.1 ✅ 做

- LICENSE 署名改为 `yunkst`
- SECURITY/CODE_OF_CONDUCT/CONTRIBUTING 中 `kfeb4@outlook.com` → GitHub Issues；`yedazhi/` 链接 → `yunkst/`
- `pubspec.yaml` description / repository / homepage / topics；`pyproject.toml` 同上（不含依赖项）
- `requirements.txt` 删除已不在 pyproject 的依赖
- `docker-compose.yml` Windows 路径变量化 + `.env.example` 字段对齐
- README、CLAUDE.md 三件套、docs/ 子集全量同步现状
- `docs-site/assets/README.md` 占位说明保留，标注素材待补

### 3.2 ❌ 不做

| 项 | 理由 |
|---|---|
| 业务代码（Dart / Python） | scope 之外 |
| 数据库 schema / alembic migration | scope 之外 |
| 依赖项清单 | 只改元信息，不改版本号 |
| `Dockerfile.debug` / `Dockerfile.test` / `Dockerfile.simple` 残留爬虫依赖 | 构建链修复，单列后续 PR |
| `tests/unit/test_crawlers.py.disabled` 删除 | dead code 清理，scope 之外 |
| `backend/openapi.json` 重生成 | 需后端跑一次，含业务链路 |
| `app/exceptions.py` 死类清理 | dead code 清理 |
| `backend/.ruff.toml` 死规则 | lint 配置清理 |
| `.env.example` 中的已不被 Settings 读取字段 | 与 §3.1 部分对齐时**删**：删除 `SECRET_KEY` / `ACCESS_TOKEN_EXPIRE_MINUTES` / `MAX_UPLOAD_SIZE` / `UPLOAD_DIR` / `VIDEO_GENERATION_TIMEOUT` / `LOG_LEVEL` / `HOST` / `PORT` |
| CI workflow 文件结构 | 不动 |
| `docs/superpowers/` | 保留作决策追溯；只在其上层 `docs/README.md` 索引里标注 |

### 3.3 历史 changelog 中的旧字样

**保留不动**——历史 changelog 反映真实变更历史（如「2026-06-11 移除 Dify」「2026-07-08 移除爬虫」「2026-07-15 加 OCR」），替换会丢失事实。仅在「现状描述」段落统一。

---

## 4. 不一致清单速览（详见 2026-07-27 对照扫描）

### 🔴 S 级（仓库首页直接误导 / 构建链断裂）

| # | 项 |
|---|---|
| S1 | LICENSE `yedazhi` vs README badge / GitHub 链接 `yunkst` vs SECURITY 混用 `yedazhi/` |
| S2 | `docker-compose.yml` 主入口 `backend` 用 `Dockerfile.debug`，仍装 playwright，但 pyproject 已删 |
| S3 | `docs/developer-guide.md` & `docs/deployment.md` 写 Scrapling 9 站 / v21 / chapter_cache / redis / prometheus（全删） |
| S4 | `docs/APP功能介绍.md` 写 Dify 配置 / 5 站点 / v21 / 旧版 UI 截图 |
| S5 | `pubspec.yaml` `description: "A new Flutter project."` 默认占位 |
| S6 | `pyproject.toml` Homepage/Repository/Documentation 全 `your-org/novel-builder` 占位 |
| S7 | 根 `requirements.txt` 仍含 playwright/bs4/lxml（pyproject 已删） |

### 🟠 A 级（CLAUDE.md 三件套脱节）

| # | 项 |
|---|---|
| A1 | 根 CLAUDE.md 列 9 API 端点；实际 17 个（漏 models 分块上传 6 端点 + backup delete + /text2img/health 等） |
| A2 | 根 CLAUDE.md 数据库章列出已删 `chapter_cache` 等；漏 `media_items` 等新表 |
| A3 | DB 版本 v38 → 实际 v39；后端版本号三处不一致 pyproject=0.1.0 / FastAPI=0.2.0 / __init__=1.0.0 |
| A5 | `novel_app/CLAUDE.md` 写 16 Screen / 17 Repository / 42+ Service / 44+ Widget / 30+ Provider / 1.3.9+28 / v36（实际 24+/15/48+/50+/40+/2.0.2-preview.1+110/v39） |
| A6 | `novel_app/CLAUDE.md` 列 `core/di/` 但不存在 |
| A7 | `novel_app/CLAUDE.md` 写 4 Tab（书架/生图调试/浏览器/设置）实为 3 Tab（无生图调试） |
| A8 | `novel_app/CLAUDE.md` 写「主启动直接进 HomePage」但实为 onboarding 状态分流 |
| A9 | `novel_app/CLAUDE.md` 列幽灵 Repository `illustration_repository.dart` / `chat_scene_repository.dart` |
| A10 | `docs/README.md` 索引不含 `docs/superpowers/`、`docs/architecture/`、`docs/chapter-fetch-flow.html` |
| A11 | `backend/CLAUDE.md` 宣称「已移除 Playwright」，但 `Dockerfile.debug/test` 仍残留 |

### 🟡 B 级（工程债 / 脏残留，本 spec 仅标注，不在此 PR 处理）

| # | 项 |
|---|---|
| B1 | `backend/openapi.json` 严重过期（全删前爬虫端点） |
| B2-B3 | Dockerfile.test 装 scrapling / Dockerfile.simple 装 bs4 lxml |
| B4 | `tests/unit/test_crawlers.py.disabled` |
| B5 | `app/exceptions.py` 残留 CrawlerError/CacheError |
| B6 | `backend/.ruff.toml` 仍为已删文件配 ignore |
| B7 | alembic env.py autogenerate 漏 import ClientLog |
| B8 | `.env.example` 的 `API_HOST/API_PORT/API_RELOAD/LOG_LEVEL/VIDEO_GENERATION_TIMEOUT` 是 Settings 不读字段 |
| B9 | `novel_app/CLAUDE.md` 列 `novel_context_service.dart` 待二次确认（保留原描述标"以代码为准"） |
| B10 | `kfeb4@outlook.com` 多处泄露（P1 处理） |
| B11 | docs-site 截图/录屏素材全部缺失（P3 仅说明待补） |
| B12 | docker-compose 硬编码 Windows 路径（P1 变量化处理） |
| B13 | `.env.example` ↔ DATABASE_URL 字段对不上（P1 对齐） |
| B14 | docs/README.md "最后更新 2026-06-11"（P3 更新） |

---

## 5. 分阶段执行清单（方案 A）

### 🅿️ P1 · 仓库卫生 + 阻断修复

**Commit**: `chore(repo): 统一品牌署名 yunkst + 元信息填实 + 起手坑对齐`

| 文件 | 改动 |
|---|---|
| `LICENSE` | `Copyright (c) 2025 yedazhi` → `Copyright (c) 2025 yunkst` |
| `README.md` | 所有 GitHub 链接对齐 `yunkst/novel_builder`（多数已经是，仅校验混用） |
| `SECURITY.md` / `CODE_OF_CONDUCT.md` / `CONTRIBUTING.md` | `kfeb4@outlook.com` → "通过 [GitHub Issues](https://github.com/yunkst/novel_builder/issues)（普通）/ [Security advisories](https://github.com/yunkst/novel_builder/security/advisories/new)（漏洞）上报"；`yedazhi/novel_builder` 链接 → `yunkst/novel_builder` |
| `.env.example` | 删 `SECRET_KEY` / `ACCESS_TOKEN_EXPIRE_MINUTES` / `MAX_UPLOAD_SIZE` / `UPLOAD_DIR` / `VIDEO_GENERATION_TIMEOUT` / `LOG_LEVEL` / `HOST` / `PORT`；保留 `NOVEL_API_TOKEN` / `DATABASE_URL` / `POSTGRES_*` / `DEBUG` / `COMFYUI_API_URL` / `COMFYUI_MODELS_DIR` / `CORS_ORIGINS`；加注释「`DATABASE_URL` 字符串内嵌的 `novel_user/novel_pass/novel_db` 必须与下方 POSTGRES_* 一致，否则 Postgres 容器会拒绝连接」 |
| `docker-compose.yml` | 移除硬编码的 `D:/myspace/nov:/app/novel_sync` 与 `D:/Comfyui/.../models:/app/models` 两个 Windows 个人机挂载；删除「`# 添加这行，把本地 backend 目录挂载`」本地调试残留注释；保留 `./backend:/app` 代码热挂载 |
| `docker-compose.override.yml.example`（新建） | 放置 ComfyUI 模型挂载与 novel_sync 挂载的示例配置（用 `${COMFYUI_MODELS_HOST_DIR}` / `${NOVEL_SYNC_HOST_DIR}` 占位），用户按需复制为 `docker-compose.override.yml`（docker-compose 默认会自动 merge override）。默认 clone 起来不依赖任何个人路径 |
| `.gitignore` | 新增 `docker-compose.override.yml`（用户本地覆盖不入库） |
| `requirements.txt` | 删 `beautifulsoup4` / `lxml` / `playwright` / `aiofiles`；顶部注释改为「已废弃，新开发请用 `backend/pyproject.toml`；本文件仅供旧部署脚本兼容，仅含最小核心依赖（不含爬虫相关包）」 |
| `novel_app/pubspec.yaml` | `description: "A new Flutter project."` → `"Novel Builder — AI 原生小说阅读平台前端（书架 / 阅读 / Agent Chat / 角色 / 关系图 / OCR 反爬）"`；新增 `repository: https://github.com/yunkst/novel_builder` / `homepage: https://github.com/yunkst/novel_builder` / `topics: [novel, reading, ai-agent, flutter, comfyui]` |
| `backend/pyproject.toml` | `authors` 改 `{name = "yunkst", email = "noreply@yunkst.github.io"}`（去掉占位）；`Homepage` / `Repository` 改 `https://github.com/yunkst/novel_builder`；`Documentation` 改 `https://github.com/yunkst/novel_builder#readme`；保留 `version = "0.1.0"` 不动 |

**验证**：
- `git grep -nE "yedazhi"` 输出仅限 historical changelog（CLAUDE.md / CHANGELOG.md 历史段）—— 待 P2 决定是否保留
- `git grep -nE "kfeb4@outlook\.com"` → 0
- `git grep -nE "your-org/novel-builder"` → 0
- `pip install -r requirements.txt` 不再拉 playwright

---

### 🅿️ P2 · CLAUDE.md 三件套同步现状

**Commit**: `docs(claude): 同步三件套 CLAUDE.md 到 v39 / 2.0.2 / 17 端点 / 3 Tab` (含 3 子 commit)

**P2.1 根 CLAUDE.md**
| 节 | 改动 |
|---|---|
| Changelog | 顶部加 `2026-07-27: 文档系统同步现状（本次梳理）` |
| 项目愿景 | 改为 "AI 原生小说阅读平台：本地书架 + Headless WebView 章节提取 + DSL Engine / Agent Chat + ComfyUI 文生图/图生视频 + 角色/关系图/大纲 + PP-OCRv6 字体反爬还原" |
| 架构 mermaid | 后端条目加 "ComfyUI 模型分块上传"；前端 AI 集成细化 |
| 数据库设计 | 表清单更新（删 `chapter_cache`/`scene_illustrations`/`cache_tasks`/`chapter_list_cache`/`model_download_tasks`；加 `media_items`/`agent_memory`/`chat_sessions`/`chat_messages`/`prompt_history`/`prompt_tag_categories`/`prompt_tags`/`prompt_tag_history`/`site_scripts`/`chapter_versions`/`bookshelves`/`novel_bookshelves`）；版本 v38 → v39 |
| API 文档 | 17 个端点全列：`/api/models/dirs` + `/api/models/upload/{init, chunk/{upload_id}/{index}, status, complete}` + `DELETE /api/models/upload/{upload_id}` + `DELETE /api/backup/delete/{backup_id}` + `/text2img/health` + `/` + `/health` + `/security-check` |
| 端口表 | 删「移动应用：3154（开发调试）」（不是仓库端口） |
| 新增「已知问题」节 | 标注 openapi.json 过期、Dockerfile 残留、tests disabled、alembic env.py 漏 import ClientLog 等（scope 外，列供后续 PR） |

**P2.2 `novel_app/CLAUDE.md`（改动量最大）**
| 节 | 改动 |
|---|---|
| Changelog | 顶部加 `2026-07-27: 同步到现状` |
| 模块职责 | 加 OCR 还原 / Agent Chat 图片上传 / Subagent / 上下文压缩 / 桌面模式 / Markdown 编辑器 / 书签 / 客户端日志远程上报 / 媒体代理 / 封面 MediaView |
| 应用启动流程 | "底部导航：书架、生图调试、浏览器、设置四个标签页" → "书架、浏览器、设置三个标签页（无'生图调试'独立 Tab）"；"主页 HomePage 底部导航结构" → "首次启动按 onboarding 状态决定进 OnboardingScreen 还是 HomePage" |
| 目录结构图 | 删 `core/di/`；`providers/` 注 "40+ 个文件"；`screens/` 注 "24+ 个"；`services/` 注 "48+ 个"；`widgets/` 注 "50+ 个"；`models/` 注 "25 个" |
| Repository 清单（17→15） | 删 `illustration_repository.dart` / `chat_scene_repository.dart`；其余保留 |
| 数据库设计 | "版本: v36" → "版本: v39"；表清单删 `scene_illustrations`；加新表（见根 P2.1）；`site_scripts` 注 v37 `ocr` / v39 `chapter_list_ocr`+`chapter_content_ocr`；`characters.avatarMediaId` 注 v34；`bookshelf.coverMediaId` 注 v36；`novel_chapters.is_user_inserted` 注 v2 |
| 缓存系统 | "服务端 PostgreSQL 缓存" 段整段删（API `/api/cache/*` 已删） |
| AI 集成 | "DSL Engine（本地 Dify 工作流复刻）" → "DSL Engine（LLM 工作流引擎，已与 Dify 解耦）"；删 `dify_settings_screen.dart` 引用 |
| 版本管理 | "当前版本: 1.3.9+28" → "2.0.2-preview.1+110" |
| 各处数字 | “页面 16 个 Screen”→“24+”、“Repository 17 个”→“15”、“Service 42+”→“48+”、“Widget 44+”→“50+”、“Model 23 个”→“25”、“Provider 30+”→“40+”、“Controller 5 个”→“以代码为准（`lib/controllers/` 下 `reader_content_controller` + `chapter_list/` 子控制器；具体计数在 plan 阶段二次确认）” |
| FAQ | 删 `dify_settings_screen.dart` 提法；Riverpod 答复压缩为一句；"Q: 关于 src 目录结构"等待二次确认（novel_context_service.dart / reader_interaction_controller.dart）保留原描述并标"以代码为准" |
| 最后更新 | 2026-06-29 → 2026-07-27 |
| "文档状态: ✅ 已验证" | 改为 "已同步现状" |

**P2.3 `backend/CLAUDE.md`（基本对，仅小修）**
| 节 | 改动 |
|---|---|
| 已移除项 | 标注 "Dockerfile.debug/test/simple 仍残留 scrapling/playwright 依赖；openapi.json 仍是删除前旧版本" |
| 入口与启动 | 加注 "版本号三处不一致：pyproject=0.1.0 / FastAPI 实例=0.2.0 / `__init__.py`=1.0.0；本模块文档以 FastAPI 实例 0.2.0 为准" |

**验证**：
- `grep -r "v36" novel_app/CLAUDE.md` → 仅历史 changelog
- `grep -r "1.3.9" novel_app/CLAUDE.md` → 仅历史 changelog
- `grep -rE "Scrapling|9 个小说站点" novel_app/CLAUDE.md` → 仅历史 changelog（2026-06-11 / 2026-07-08 段）
- 人工对照 17 端点 / 3 Tab / 24+ screens

---

### 🅿️ P3 · docs/ 全量修正

**Commit**: `docs: 修正 developer-guide/deployment/APP功能介绍/logging-guidelines/索引`

| 文件 | 改动 |
|---|---|
| `docs/README.md` | 「最后更新 2026-06-11」→「2026-07-27」；索引补 `docs/superpowers/`（标注"内部设计决策追溯"）、`docs/architecture/`、`docs/chapter-fetch-flow.html`、`docs/diagrams/` |
| `docs/developer-guide.md` | 「Scrapling 爬虫（9 站点）」→「Headless WebView + 本地 JS 提取脚本」；「database version: v21」→「v39」；删 `chapter_cache`/`cache_tasks` 等已删表；删 WebSocket 推送段；删 Dify 段；技术栈对齐 |
| `docs/deployment.md` | 删 `docker-compose.prod.yml` 含 redis+nginx+prometheus+grafana 段；删 SSL/CDN 段；保留 Docker Compose + Nginx 反代 + 健康检查；环境变量对齐新 `.env.example` |
| `docs/APP功能介绍.md` | 删「Dify 配置」段；「5 个站点」→「前端 Headless WebView 提取，无固定站点，按 site_scripts 表配置」；「SQLite v21」→「v39」；配图说明更新为「截图反映旧版 UI（含搜索/Dify），新版本已移除这些入口，截图待更新」 |
| `docs/logging-guidelines.md` | 删 Dify 时代口吻；保留 LoggerService 4 级 × 8 分类 × 标签；对齐 traceId + 文件回退（按根 CLAUDE.md 2026-07-17 changelog） |
| `docs-site/assets/README.md` | 占位说明保留；加 "demo-*.png/mp4 待补，欢迎 PR 贡献" |

**验证**：
- `grep -rnE "Dify|Scrapling|9 (个|站点)|v21|chapter_cache|redis|prometheus" docs/developer-guide.md docs/deployment.md docs/APP功能介绍.md docs/logging-guidelines.md` → 0
- `docs/README.md` 含 `superpowers/` / `architecture/` / `chapter-fetch-flow` / `diagrams/` 四个索引项

---

### 🅿️ P4 · README 门面重写

**Commit**: `docs(readme): 重写项目门面对齐 AI 原生定位`

| 节 | 改动 |
|---|---|
| 顶部标语 | 「现代化的全栈小说阅读平台 / 提供跨平台的小说搜索、阅读、缓存和AI增强功能」→「AI 原生小说阅读平台 / 本地书架 + Headless WebView 提取 + Agent Chat + ComfyUI 文生图/图生视频 + 字体反爬 OCR 还原」 |
| 功能特性 - 移动应用 | 删「智能搜索：跨 9 个小说站点统一搜索」→「本地书架搜索 + 阅读器内章节内容搜索」；删「Hermes Agent」→「Agent Chat（写作 / 浏览器 / 多角色 / Subagent）」；加「PP-OCRv6 字体反爬还原」「人物关系图」「上下文压缩 + LLM 重试横幅」 |
| 功能特性 - 后端服务 | 删「多站点爬虫」「智能缓存：PostgreSQL + 本地缓存双重策略」「实时通信：WebSocket 进度推送」；改为「ComfyUI 文生图/图生视频」「模型分块上传」「数据库备份上/下/列/删」「客户端日志上报」 |
| 功能特性 - AI 集成 | 「DSL Engine：客户端 Dify 工作流复刻」→「DSL Engine：本地 LLM 工作流引擎（与 Dify 解耦）」；「Hermes Agent」→「Agent Chat + Subagent」 |
| 项目结构图 | `core/` 删「DI」字样；`services/` 改「DSL Engine、Agent、Headless WebView、OCR」；`api/routes/` 改「backup、logs、models」；`assets/` 改「字体、OCR 模型」 |
| 端口映射 | 删「移动应用：3154（开发调试）」 |
| 技术栈 - 后端 | 删 Scrapling / Playwright |
| 快速开始 | `.env` 步骤对齐新 `.env.example`；加「如需挂载 ComfyUI 模型目录，`cp docker-compose.override.yml.example docker-compose.override.yml` 并填入 `COMFYUI_MODELS_HOST_DIR`；不挂载则用 `docker compose cp` 直传」 |
| 文档区 | 索引补 `docs/superpowers/`（标 "AI 决策追溯"） |
| `Made with ❤️ by [yunkst]` | 保留 |
| 徽章 | 保留现有；不加 Codecov/Sonar（仓库无对应 workflow） |

**验证**：
- `grep -nE "9 个小说|Hermes Agent|Dify 工作流复刻|Scrapling|Playwright|3154" README.md` → 0
- GitHub 仓库首页预览

---

## 6. 风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| R1 邮箱脱敏后反馈渠道断裂 | 老用户记不住新入口 | SECURITY.md 顶部显眼给出 GitHub Issues / Security advisories 双入口 |
| R2 docker-compose 个人路径挂载移除后 ComfyUI 模型挂载失效 | 本地出图断 | 抽出 `docker-compose.override.yml.example`，主 compose 不含个人挂载；README 说明「需挂载 ComfyUI 模型目录则 `cp docker-compose.override.yml.example docker-compose.override.yml` 并修改变量；不挂载则用 `docker compose cp` 直传或仅用后端自带模型」 |
| R3 requirements.txt 删 playwright 后旧部署脚本断 | 该文件 CI 依赖 | 文件顶部已有"已废弃"注释；如 grep 发现有 `pip install -r requirements.txt` 硬编码脚本，PR 描述标注 |
| R4 P2 改动量大 review 难 | review 成本 | 拆分 3 子 commit（根/novel_app/backend），便于 review 与回滚 |
| R5 docs-site 与 docs/ 重名混淆 | Pages workflow 误触 | P3/P4 不动 `docs-site/workflow` 文件 |
| R6 历史 changelog 替换丢失事实 | 历史失真 | **不替换**历史段，只在「现状描述」统一 |

## 7. 回滚策略

- 每个 P 阶段 = 1 个 commit（`P2` 拆 3 子 commit），可 `git revert <sha>` 单独回滚
- 全程不碰业务代码，回滚无运行时风险
- P1 若 `pip install` 验证失败 → 立即 revert；P3 若 grep 验证异常 → 立即 revert

## 8. 验证 checklist（每阶段 DoD）

| 阶段 | 验证 | 命令 |
|---|---|---|
| P1 | 邮箱脱敏 | `git grep -nE "kfeb4@outlook\.com"` → 0 |
| P1 | 占位脱敏 | `git grep -nE "your-org/novel-builder"` → 0 |
| P1 | 依赖干净 | `pip install -r requirements.txt --dry-run` 不拉 playwright |
| P1 | 个人路径清零 | `git grep -nE "D:/myspace|D:/Comfyui" docker-compose.yml` → 0 |
| P1 | compose 默认可起 | `docker-compose config` 不报错（默认配置不含个人路径挂载） |
| P2 | 数字对齐 | 人工对照 17 端点 / 3 Tab / 24+ screens / v39 / 2.0.2 |
| P2 | 幽灵模块清理 | `grep -nE "illustration_repository|chat_scene_repository|core/di" novel_app/CLAUDE.md` → 0 |
| P3 | 旧词汇清零 | `grep -rnE "Dify|Scrapling|9 (个|站点)|v21|chapter_cache|redis|prometheus" docs/*.md` → 0 |
| P3 | 索引完整 | `docs/README.md` 含 `superpowers/` / `architecture/` / `chapter-fetch-flow` / `diagrams/` |
| P4 | 旧措辞清零 | `grep -nE "9 个小说|Hermes Agent|Dify 工作流复刻|Scrapling|Playwright|3154" README.md` → 0 |
| P4 | 仓库首页预览 | 人工访问 GitHub 仓库 README 渲染 |

## 9. 提交规范（chinese-commit-conventions）

```
chore(repo): 统一品牌署名 yunkst + 元信息填实 + 起手坑对齐             ← P1 (1 commit)
docs(claude): 同步根 CLAUDE.md 到 v39 / 17 端点 / 3 Tab              ← P2.1
docs(novel-app): 同步 novel_app/CLAUDE.md 到 v39 / 24 screens / 2.0.2 ← P2.2
docs(backend): 标注 backend CLAUDE.md 已知问题                     ← P2.3
docs: 修正 developer-guide/deployment/APP功能介绍/logging-guidelines/索引 ← P3
docs(readme): 重写项目门面对齐 AI 原生定位                            ← P4
```

每个 commit body 列：动机 + 改动要点 + 对应清单项编号（§4 中的 S/A 级）。

## 10. 完成定义（DoD）

1. P1-P4 全部 commit 落地 master
2. §8 全部验证通过
3. GitHub 仓库首页 README 预览正确（无 404 链接、无过期描述、徽章全绿或灰）
4. 本 spec 文件 commit
5. 至少输出一条 project memory 记录「文档系统基线 2026-07-27」

## 11. 决策追溯

| 时点 | 决策 | 推翻/修正了 |
|---|---|---|
| 初轮 | 以 LICENSE 为准，品牌 = yedazhi | 第二轮 `git remote -v` 显示 yunkst 后**修正**为 yunkst（避免 404） |
| 初轮 | 展示层独立清理 | 用户确认加入「仓库卫生」（pubspec/pyproject 占位、requirements.txt、路径变量、邮箱脱敏） |
| 初轮 | 4 Tab（生图调试独立） | 代码实况是 3 Tab（生图调试未独立），文档改为 3 Tab |
| 文档 v36 → v39 | 根 CLAUDE.md v38 → 实际 v39 | 跟上 v39 的 `chapter_list_ocr`+`chapter_content_ocr`（2026-07-17） |
| backend 17 端点 | 根 CLAUDE.md 仅列 9 端点 → 实际 17（含 6 个分块上传） | 补齐 |
| 品牌名 yunkst | — | — |
| 邮箱脱敏 GitHub Issues | 用户确认 | — |
