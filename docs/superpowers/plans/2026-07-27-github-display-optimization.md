# GitHub 展示优化 + 文档系统同步现状 · 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Novel Builder 仓库展示层与代码实况对齐：统一品牌为 `yunkst`、邮箱脱敏、元信息填实、CLAUDE.md 三件套同步到 v39 / 2.0.2 / 17 端点 / 3 Tab / 24+ screens、docs/ 过期处全量修正、README 重写门面对齐 AI 原生定位。四个独立 commit，可单独回滚。

**Architecture:** 方案 A · 分阶段切片（P1→P2→P3→P4），每个 commit 单一职责。每阶段自身含 DoD 与 grep 验证，不依赖后续阶段。

**Tech Stack:** 仓库级操作（Markdown / YAML / TOML / shell 脚本 / .gitignore / docker-compose）—— 不动 Dart / Python 业务代码。验证手段：`git grep`、`pip install --dry-run`、`docker compose config`。

---

## Global Constraints

- **scope**: 仅展示层 + 仓库卫生。不动 `novel_app/lib/`、`backend/app/`、`backend/alembic/versions/`（**任何**业务代码）。
- **品牌身份**: `yunkst`（与 `git remote origin = yunkst/novel_builder` 一致；推过初轮 yedazhi 决策因 404 风险修正）。
- **文档语言**: 仅中文。不开 README.en.md。
- **历史 changelog**: 不替换历史段（仅统一"现状描述"段落）。
- **commit 规范**: `chinese-commit-conventions` —— type 英文（feat/fix/docs/chore/refactor/...），scope 中文，subject 中文动宾短语，不超过 50 字符。
- **git author**: 默认（依 `git config user.*`）。
- **不在本计划范围**: Dockerfile.debug/test/simple 残留、openapi.json 重生成、app/exceptions.py dead class、.ruff.toml 死规则、tests/unit/test_crawlers.py.disabled、业务代码、schema、migration、CI workflow 结构、依赖项（仅改元信息）。
- **验证手段**: 全部 grep 类，无需构建。**例外**: P1 用 `pip install --dry-run` 与 `docker compose config` 验证。
- **回滚粒度**: 每个 Task 一个 commit，可 `git revert <sha>` 单独回滚。

---

## 文件结构地图（前置 Lockdown）

### Modify
| 文件 | 负责 |
|---|---|
| `LICENSE` | 署名 yedazhi → yunkst |
| `README.md` | P4 门面重写 |
| `CONTRIBUTING.md` / `SECURITY.md` / `CODE_OF_CONDUCT.md` | 邮箱脱敏 + 链接对齐 |
| `.env.example` | 字段对齐 P1（删 dead 字段 + 注释约束）|
| `docker-compose.yml` | 移除硬编码 Windows 个人挂载 |
| `requirements.txt` | 删 playwright/bs4/lxml/aiofiles |
| `novel_app/pubspec.yaml` | description/repository/homepage/topics |
| `backend/pyproject.toml` | authors/[project.urls] |
| `.gitignore` | 加 `docker-compose.override.yml` |
| `CLAUDE.md`（根） | P2.1 同步现状 |
| `novel_app/CLAUDE.md` | P2.2 同步现状 |
| `backend/CLAUDE.md` | P2.3 标注已知问题 |
| `docs/README.md` | P3 索引补全 |
| `docs/developer-guide.md` | P3 修正（删 Scrapling/9 站/v21）|
| `docs/deployment.md` | P3 修正（删 redis/nginx/prometheus）|
| `docs/APP功能介绍.md` | P3 修正（删 Dify/5 站/v21）|
| `docs/logging-guidelines.md` | P3 修正（删 Dify 口吻）|
| `docs-site/assets/README.md` | P3 加待补标注 |

### Create
| 文件 | 负责 |
|---|---|
| `docker-compose.override.yml.example` | ComfyUI 模型 + novel_sync 挂载示例 |
| `docs/superpowers/specs/2026-07-27-github-display-optimization-design.md` | 已存在（commit 2c998f9）|
| `docs/superpowers/plans/2026-07-27-github-display-optimization.md` | 本计划自身 |

### Don't Touch
`novel_app/lib/**/*.dart`、`backend/app/**/*.py`、`backend/alembic/versions/**`、`*.workflows.yaml`、`Dockerfile*`、`backend/openapi.json`、`backend/.ruff.toml`、`backend/tests/unit/test_crawlers.py.disabled`、`backend/app/exceptions.py`（含 dead CrawlerError）

---

## Task 1: P1 · 仓库卫生与阻断修复

**Files:**
- Modify: `LICENSE`
- Modify: `README.md`
- Modify: `SECURITY.md` / `CODE_OF_CONDUCT.md` / `CONTRIBUTING.md`
- Modify: `.env.example`
- Modify: `docker-compose.yml`
- Modify: `requirements.txt`
- Modify: `novel_app/pubspec.yaml`
- Modify: `backend/pyproject.toml`
- Modify: `.gitignore`
- Create: `docker-compose.override.yml.example`

**Goal:** 阻断误链 / 阻断占位元信息 / 阻断个人路径硬编码 / 阻断邮箱泄露。

**Depends on:** 无（第一个做）。

**Produces:** 一个 `chore(repo):` commit，可单独回滚。

---

- [ ] **Step 1: 阅读 5 个修改文件的当前内容确认改动锚点**

读取（用于精确 Edit）：
- `LICENSE`（确认 `Copyright (c) 2025 yedazhi` 字样）
- `.env.example` 全文（确认要删字段的位置）
- `docker-compose.yml` 全文（确认两处 `D:/...` 行的位置）
- `requirements.txt` 全文（确认 4 行 playwright/bs4/lxml/aiofiles 的位置）
- `novel_app/pubspec.yaml` 当前 description 行
- `backend/pyproject.toml` 当前 authors 行
- `CONTRIBUTING.md` / `SECURITY.md` / `CODE_OF_CONDUCT.md` 全文（grep `kfeb4@outlook.com` 与 `yedazhi/novel_builder`）
- `README.md` 全文（确认需不需要动）
- `.gitignore`（看是否已有 `docker-compose.override.yml` 条目；如有跳过添加）

如已读过（在前置探索阶段），可跳过本步。

- [ ] **Step 2: 改 LICENSE 署名**

将 `Copyright (c) 2025 yedazhi` 改为 `Copyright (c) 2025 yunkst`。
- 文件: `LICENSE`
- 用 Edit 工具，old_string = `Copyright (c) 2025 yedazhi`，new_string = `Copyright (c) 2025 yunkst`。

- [ ] **Step 3: 改 community 三件套邮箱 + 链接对齐**

对 `CONTRIBUTING.md` / `SECURITY.md` / `CODE_OF_CONDUCT.md` 三文件分别执行：

**邮箱替换**（出现 `kfeb4@outlook.com` 处）：
- old = `kfeb4@outlook.com`
- new = `[GitHub Issues](https://github.com/yunkst/novel_builder/issues/new/choose)` / 或 SECURITY.md 用 `[Security Advisories](https://github.com/yunkst/novel_builder/security/advisories/new)`

**链接替换**（出现 `yedazhi/novel_builder` 处）：
- old = `yedazhi/novel_builder`
- new = `yunkst/novel_builder`

执行方式：
- 先 `git grep -nE "kfeb4@outlook\.com|yedazhi/novel_builder" CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md` 列出所有命中
- 对每一处精确 Edit 替换
- 最后用同一 grep 复核：应输出 0 行

- [ ] **Step 4: 改 `.env.example`**

**删除字段**（这些 Settings 类不读取的 dead vars）：
- `SECRET_KEY=...` 整行 + 上方 `# JWT 密钥（用于会话管理）` 注释 + `# 访问令牌过期时间（分钟）` + `ACCESS_TOKEN_EXPIRE_MINUTES=30`
- `# CORS 允许的源` 注释保留（此项 Settings 读取）；下方的 `CORS_ORIGINS=["http://localhost:3000", "http://localhost:3154"]` 保留但调整：把 `localhost:3000` 去掉（该项目无 3000 用法），保留 `http://localhost:3154`；同时移除方括号外的双引号使其合法（Settings 类读取为 JSON 列表）
- `# 最大上传大小（字节）` + `MAX_UPLOAD_SIZE=10485760` + `# 上传目录` + `UPLOAD_DIR=./uploads` 整段删
- `# 视频生成超时时间（秒）` + `VIDEO_GENERATION_TIMEOUT=600` 整段删
- `# 日志级别（DEBUG, INFO, WARNING, ERROR）` + `LOG_LEVEL=INFO` 整段删
- `# 服务器端口` + `HOST=0.0.0.0` + `PORT=8000` 整段删

**保留字段**：
- `NOVEL_API_TOKEN` / `DATABASE_URL` / `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` / `DEBUG` / `COMFYUI_API_URL` / `COMFYUI_MODELS_DIR` / `CORS_ORIGINS`（已调整为 `["http://localhost:3154"]`）

**新增注释**（`DATABASE_URL` 行下方）：
```bash
# 注意：DATABASE_URL 字符串内嵌的 novel_user / novel_pass / novel_db 必须与下方
# POSTGRES_USER / POSTGRES_PASSWORD / POSTGRES_DB 三项一致，否则 Postgres 容器会
# 拒绝连接。
```

执行：用 Edit 工具按上述逐处替换。验证：`git grep -nE "SECRET_KEY|ACCESS_TOKEN_EXPIRE|MAX_UPLOAD_SIZE|UPLOAD_DIR|VIDEO_GENERATION_TIMEOUT|LOG_LEVEL|^HOST=|^PORT=" .env.example` 应输出 0 行。

- [ ] **Step 5: 改 `docker-compose.yml` 移除 Windows 个人机挂载**

原文（约 line 14-16）：
```yaml
      # 小说同步目录映射
      - D:/myspace/nov:/app/novel_sync
      # ComfyUI 模型目录挂载
      - D:/Comfyui/ComfyUI_windows_portable/ComfyUI/models:/app/models
```
以及 line 11：
```yaml
      # 添加这行，把本地 backend 目录挂载到容器中
      - ./backend:/app
```

替换为：
```yaml
      # 本地 backend 源码热挂载（开发时改代码即时生效）
      - ./backend:/app
      # ComfyUI 模型目录与 novel_sync 同步目录为个人机可选配置，
      # 默认不挂载。需要时新建 docker-compose.override.yml.example 同名 override，
      # 参考 docs/docker-compose.override.yml.example（如有创建）。
```

执行 Edit 替换。第 14-16 行整段删除。

验证：`git grep -nE "D:/myspace|D:/Comfyui" docker-compose.yml` → 0 行。

- [ ] **Step 6: 新建 `docker-compose.override.yml.example`**

文件内容：
```yaml
# Docker Compose override 示例
# 使用方法：
#   1. 复制本文件为 docker-compose.override.yml
#      cp docker-compose.override.yml.example docker-compose.override.yml
#   2. 修改下方变量为你的实际本机路径
#   3. docker-compose up -d 会自动合并 override
#
# 注意：docker-compose.override.yml 在 .gitignore 中，不会入库。

services:
  backend:
    volumes:
      # ComfyUI 模型目录（容器内路径固定为 /app/models）
      # Windows 示例：D:/Comfyui/ComfyUI_windows_portable/ComfyUI/models
      # Linux 示例：/home/yourname/comfyui/models
      - "${COMFYUI_MODELS_HOST_DIR}:/app/models"
      # 小说同步目录
      - "${NOVEL_SYNC_HOST_DIR}:/app/novel_sync"
```

写入 `docker-compose.override.yml.example`。

- [ ] **Step 7: 改 `.gitignore` 加 override**

如 `.gitignore` 中不含 `docker-compose.override.yml`，追加一行 `docker-compose.override.yml`（带前导换行）。

执行：先 `grep -n "docker-compose.override" .gitignore`；如无，Edit 在文件末尾追加。

- [ ] **Step 8: 改 `requirements.txt` 删爬虫依赖**

原文（line 9-24）：
```
beautifulsoup4>=4.12.0
lxml>=4.9.0
```
及 line 20：
```
aiofiles>=23.0.0
```
及 line 24：
```
playwright>=1.55.0
```

**操作**：删除这 4 行。同时改顶部注释：
- 旧： `# This file is maintained for compatibility with old deployment scripts\n# For new development, please use backend/pyproject.toml`
- 新：
```
# This file is maintained for compatibility with old deployment scripts.
# For new development, please use backend/pyproject.toml.
# Scraper-related packages (playwright / beautifulsoup4 / lxml) and aiofiles
# have been removed because the backend no longer hosts crawlers (see
# docs/superpowers/specs/2026-07-27-github-display-optimization-design.md
# §3.1 / §5 P1).

```
（注意：保留 fastapi / uvicorn / requests / pydantic / python-multipart / sqlalchemy / psycopg2-binary / alembic / packaging / pytest / ruff。）

执行：Edit 替换。验证：`pip install -r requirements.txt --dry-run` 退码 0 且输出不含 playwright（如需安装 dry-run 支持，可加 `--dry-run` 标记；许多 pip 版本支持，如不支持则用 `pip install --dry-run --report -`）。

- [ ] **Step 9: 改 `novel_app/pubspec.yaml` 元信息**

精确替换：
- old = `description: "A new Flutter project."`
- new = `description: "Novel Builder — AI 原生小说阅读平台前端（书架 / 阅读 / Agent Chat / 角色 / 关系图 / OCR 反爬）"`

在 `version: 2.0.2-preview.1+110` 行下方**新增**：
```yaml
repository: https://github.com/yunkst/novel_builder
homepage: https://github.com/yunkst/novel_builder
```

找到 flutter section 起点（`flutter:` 行附近），在 `uses-material-design: true` 下方**新增**：
```yaml
  # Pub topics（帮助 pub.dev/IDE 侧栏聚合分类，不影响功能）
  # 注：pubspec 没有顶层 topics 键，这些标签通过 repository URL 暴露
```

（实际上 pubspec 没有顶层 topics 字段。改为在 description 中已含关键词即可。删除此段。）

实际操作：**只改 description + 加 repository/homepage 两行**。不要乱加不存在的字段。

执行两次 Edit。

- [ ] **Step 10: 改 `backend/pyproject.toml` 元信息**

精确替换：
- old = `{name = "Novel Builder Team", email = "team@novelbuilder.com"}`
- new = `{name = "yunkst", email = "noreply@yunkst.github.io"}`

精确替换：
- old = `Homepage = "https://github.com/your-org/novel-builder"`
- new = `Homepage = "https://github.com/yunkst/novel_builder"`

精确替换：
- old = `Repository = "https://github.com/your-org/novel-builder"`
- new = `Repository = "https://github.com/yunkst/novel_builder"`

精确替换：
- old = `Documentation = "https://novel-builder.readthedocs.io"`
- new = `Documentation = "https://github.com/yunkst/novel_builder#readme"`

执行四次 Edit。

- [ ] **Step 11: README 暂不动（留给 P4）**

P4 会重写 README。在 P1 不改 README 任何字符，避免重复 PR 评审。

- [ ] **Step 12: 跑 P1 全部验证（spec §8 校验）**

执行：
```bash
git grep -nE "kfeb4@outlook\.com" .
git grep -nE "your-org/novel-builder"
git grep -nE "D:/myspace|D:/Comfyui" docker-compose.yml
git grep -nE "yedazhi" .
```
预期：
- 前 3 个：0 行（注：`yedazhi` 仍可能在 CLAUDE.md 历史段中存在，P2 再处理）
- `yedazhi` 仅限 `LICENSE` 自身、P4 完成后 README.md 会带 yunkst，根 CLAUDE.md 历史段会保留——P1 不动这些

附加验证：
```bash
docker compose config 2>&1 | head -20
```
预期：无报错（默认配置不含个人挂载）。

- [ ] **Step 13: Commit P1**

```bash
git add -A
git status --short
git commit -m "$(cat <<'EOF'
chore(仓库整理): 阻断修复：品牌 yunkst / 邮箱脱敏 / 元信息 / 个人路径

- LICENSE 署名改为 yunkst（与 git remote owner 一致）
- SECURITY/CODE_OF_CONDUCT/CONTRIBUTING 中 kfeb4@outlook.com → GitHub
  Issues / Security Advisories；yedazhi/ 链接 → yunkst/
- .env.example 删 dead 字段（SECRET_KEY/MAX_UPLOAD/HOST/PORT 等），
  新增 DATABASE_URL 一致性注释
- docker-compose.yml 移除硬编码 Windows 个人挂载；新增
  docker-compose.override.yml.example 与 .gitignore 条目
- requirements.txt 删 playwright/bs4/lxml/aiofiles，注释指向 spec
- pubspec.yaml description 与 repository/homepage 填实
- backend/pyproject.toml authors 占位换为 yunkst，URL 占位换为实际仓库

影响范围：仓库元信息与 compose，零业务代码改动
EOF
)"
```

用 `git log --oneline -1` 确认 commit 落地。

---

## Task 2: P2.1 · 同步根 CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`（根）

**Goal:** 把根 CLAUDE.md 的项目愿景、数据库章、API 端点表、技术栈、端口表、新增"已知问题"节 对齐到现状。

**Depends on:** Task 1（确保 yedazhi 链接不再出现在 git grep 内）

**Produces:** 一个 `docs(claude):` 子 commit。

---

- [ ] **Step 1: Read 根 CLAUDE.md 全文（约 294 行）确认改动锚点**

`Read CLAUDE.md`。在以下位置精确 Edit：

- [ ] **Step 2: 更新顶部 Changelog**

在 Changelog 列表顶部插入：
```markdown
- **2026-07-27**: **文档系统同步现状**。见 `docs/superpowers/specs/2026-07-27-github-display-optimization-design.md` + `docs/superpowers/plans/2026-07-27-github-display-optimization.md`。
```

old_string = Changelog 第一行 `**2026-07-18**: **LLM 重试 UI 展示**...` 之前一行（空行也行）。

- [ ] **Step 3: 更新项目愿景段**

old:
```
**项目愿景**

Novel Builder 是一个现代化的全栈小说阅读平台，采用微服务架构，提供跨平台的小说搜索、阅读、缓存和AI增强功能。平台整合多个小说站点资源，通过统一的API接口为用户提供无缝的阅读体验。
```

new:
```
**项目愿景**

Novel Builder 是一个 **AI 原生小说阅读平台**。前端 Flutter 离线优先（本地书架 + Headless WebView 章节提取 + PP-OCRv6 字体反爬还原），AI 层由 DSL Engine + Agent Chat + Subagent 驱动，后端 FastAPI 仅承担 ComfyUI 文生图/图生视频、AI 结果轮询、客户端备份、客户端日志上报 等轻量职责。
```

- [ ] **Step 4: 更新架构总览 mermaid 中后端标签**

后端 `O["AI文生图/图生视频API"]` 段旁加 "ComfyUI 模型分块上传"。

old:
```
    H --> O["AI文生图/图生视频API"];
    H --> P["备份/日志API"];
    H --> Q["模型管理API"];
```

new:
```
    H --> O["AI文生图/图生视频API"];
    H --> P["备份/日志API"];
    H --> Q["ComfyUI 模型分块上传 API"];
```

- [ ] **Step 5: 更新后端核心功能段**

定位 `### 🌐 后端服务功能` 段。old:
```
- **AI 文生图 / 图生视频**: ComfyUI 任务提交与结果轮询，支持负向提示词
- **ComfyUI 客户端**: 工作流占位符替换、模型目录浏览、分块上传
- **数据备份**: 客户端数据库备份文件上传、列表、下载
- **客户端日志上报**: 接收并持久化客户端日志
- **实时API**: RESTful API with OpenAPI文档
- **数据同步**: 备份导入/导出
```

new:
```
- **ComfyUI 文生图 / 图生视频**: 任务提交与结果轮询，支持负向提示词
- **ComfyUI 模型分块上传**: 分块 init / chunk / status / complete / cancel 五段式
- **客户端数据库备份**: 上传 / 列表 / 下载 / 删除（4 端点）
- **客户端日志上报**: 批量 1–50 条/次持久化
- **ComfyUI 健康检查**: `/text2img/health`（注意：无 `/api` 前缀，与业务前缀不一致）
```

- [ ] **Step 6: 删"已移除"小节里现已无意义的注释**

定位 `> 注：多站点爬虫、搜索/章节接口、章节缓存已移除（前端改用 headless WebView + 本地 JS 提取脚本 + 本地书架搜索，2026-07-08）。`

保留这一行（事实陈述）。

- [ ] **Step 7: 更新数据库设计段**

定位 `### 主要表结构`。整个表清单段（约 line 100-130 范围）old:
```
- **bookshelf**: 小说元数据（历史命名，含阅读进度）
- **chapter_cache**: 章节内容缓存（前端 SQLite 本地缓存）
...（含已删的 chapter_cache / scene_illustrations 等）
- **site_scripts**: 站点提取脚本（v37 加 ocr 列，标识字体反爬 OCR 提取器）
...（含 text2img_task / image_to_video_task / client_logs）
```

new:
```
- **bookshelf**: 小说元数据（历史命名，含阅读进度，v36 加 coverMediaId 走 MediaView 渲染封面）
- **bookshelves / novel_bookshelves**: 多书架分类（v16）
- **novel_chapters**: 章节列表元数据（v2 `is_user_inserted`，v11 `read_at`，v18 `is_accompanied`）
- **chapter_cache**: 章节内容缓存（前端 SQLite 本地；用户插入章节保护）
- **chapter_versions**: 章节历史版本（v30，AI 编辑/重写留档）
- **characters / character_relationships**: 角色与关系图（v34 `avatar_media_id`，v35 first_appearance_chapter，关系区间模型 v35）
- **scene_illustrations**: ~~v34 已删，由 media_items 统一承载~~
- **media_items**: 统一媒体代理（v34；mediaId / kind / source / local_only）
- **outlines**: 大纲（v9）
- **chat_sessions / chat_messages**: Agent Chat 会话与消息（v31-32）
- **prompt_tags / prompt_tag_categories / prompt_history / prompt_tag_history**: 写作标签库（v22-28）
- **agent_memory**: Agent 经验记忆（v27）
- **llm_configs**: LLM 配置 CRUD（v29）
- **site_scripts**: 站点提取脚本（v25+；v37 加 ocr 列；v39 加 `chapter_list_ocr` 与 `chapter_content_ocr` 两列，番茄场景互不覆盖）
- **text2img_task**: ComfyUI 文生图任务（prompt_id=task_id；v2026-07-10 加 negative_prompt）
- **image_to_video_task**: ComfyUI 图生视频任务
- **client_logs**: 客户端日志（后端 PostgreSQL）

**已移除**（2026-07-08 by `20260708_drop_cache_tables`）：`novel_cache_tasks`、`novel_chapters_cache`、`chapter_list_cache`、`model_download_tasks`（v38 删）。
```

（注：上"已移除"行重复出现于多处，可保留事实陈述，只修主清单段。）

- [ ] **Step 8: 更新"数据库版本"小节**

old:
```
- **前端SQLite**: v38 (novel_reader.db) — v37→v38 删除 `model_download_tasks` 表（2026-07-17）
```

new:
```
- **前端SQLite**: v39 (novel_reader.db) — v38→v39 加 `chapter_list_ocr` + `chapter_content_ocr` 两列（2026-07-17 site_scripts 拆 OCR 列）
```

- [ ] **Step 9: 补齐 API 端点表（17 端点全列）**

定位 `### 主要端点` 段。old:
```
- `POST /api/text2img/generate`: 提交文生图任务（支持 negative_prompt 负向提示词），返回 task_id
- `GET /api/text2img/image/{task_id}`: 按 task_id 取文生图结果（202 pending / 200 png / 404 失败）
- `POST /api/image-to-video/generate`: 上传图片+提示词，提交图生视频任务，返回 task_id
- `GET /api/image-to-video/video/{task_id}`: 按 task_id 取视频结果（202 pending / 200 mp4 / 404 失败）
- `GET /api/models`: 获取可用文生图/图生视频模型列表
- `POST /api/backup/upload`: 上传数据库备份文件
- `GET /api/backup/list`: 列出已上传备份
- `GET /api/backup/download/{backup_id}`: 下载备份文件
- `POST /api/logs/upload`: 上报客户端日志
```

new:
```
**AI 接口**（ComfyUI 任务）：
- `POST /api/text2img/generate` - 提交文生图任务（含 negative_prompt）
- `GET  /api/text2img/image/{task_id}` - 按 task_id 取文生图结果（202 / 200 png / 404）
- `GET  /text2img/health` - ComfyUI 健康检查（**注意**：无 `/api` 前缀）
- `POST /api/image-to-video/generate` - 上传图片 + prompt，提交图生视频任务
- `GET  /api/image-to-video/video/{task_id}` - 按 task_id 取视频结果（202 / 200 mp4 / 404）

**ComfyUI 模型管理**：
- `GET  /api/models` - 列出 T2I / I2V 工作流
- `GET  /api/models/dirs` - 列出 ComfyUI 模型一级子目录（容器内）
- `POST /api/models/upload/init` - 初始化模型分块上传任务
- `POST /api/models/upload/{upload_id}/chunk/{index}` - 上传单个分块
- `GET  /api/models/upload/{upload_id}/status` - 查询分块上传进度
- `POST /api/models/upload/{upload_id}/complete` - 合并分块到最终路径
- `DELETE /api/models/upload/{upload_id}` - 取消并清理分块临时目录

**备份接口**：
- `POST   /api/backup/upload` - 上传 .db/.zip 备份
- `GET    /api/backup/list` - 列出已上传备份
- `GET    /api/backup/download/{backup_id:path}` - 下载备份
- `DELETE /api/backup/delete/{backup_id:path}` - 删除备份

**日志接口**：
- `POST /api/logs/upload` - 批量上报客户端日志（1-50 条/次）

**杂项**：
- `GET /` - 服务信息 + 端点清单
- `GET /health` - 服务自身健康检查
- `GET /security-check` - 安全配置自检（仅 DEBUG）
```

- [ ] **Step 10: 更新端口表**

定位 `### 端口映射` 段。old:
```
- **后端API**: 3800 → 8000 (FastAPI)
- **调试端口**: 6678 → 5678 (debugpy)
- **数据库**: 5432 (PostgreSQL，仅容器内部，不对宿主机暴露)
- **ComfyUI**: 8188 (宿主机本地，文生图后端)
```

new:
```
- **后端 API**: 3800 → 8000 (FastAPI)
- **debugpy**: 6678 → 5678 (Dockerfile.debug)
- **PostgreSQL**: 5432 (Docker 内部，不对宿主机暴露)
- **ComfyUI**: 8188 (宿主机本地，文生图后端 —— 通过 `host.docker.internal` 引用)
```

- [ ] **Step 11: 新增"已知问题"节（scope 之外的工程债）**

定位文末 `## 故障排除` 节之前插入：
```markdown
## 已知问题（不在本次 PR 范围）

下列问题已识别但属"展示层 + 仓库卫生"scope 之外，需后续 PR 处理：

- `backend/openapi.json` 严重过期：仍记录 2026-07-08 删除前的爬虫/缓存端点（10039 字节），不含任何现行端点。前端若依赖其做客户端生成会全错。**修复方式**：重生成后端运行后 `python -m openapi-spec-validator` 并重新导出。
- `backend/Dockerfile.debug` 仍 `playwright install chromium`：因 `pyproject.toml` 已删 playwright，镜像构建会失败。**修复方式**：删除 Dockerfile.debug 的 playwright 段，或新建 Dockerfile.dev 取代。
- `backend/Dockerfile.test` 仍装 `scrapling[fetchers]` 与 `scrapling[core]`、`backend/Dockerfile.simple` 装 `beautifulsoup4 lxml`。**修复方式**：删除这两个文件或合并。
- `backend/tests/unit/test_crawlers.py.disabled` 仍在仓库。**修复方式**：删除。
- `backend/app/exceptions.py` 残留 `CrawlerError` / `ParseError` / `CacheError` 死类。**修复方式**：删除。
- `backend/.ruff.toml` 仍为 `*_crawler.py` / `scene_illustration_service.py` / `role_card_service.py` / `search_service.py` 配 per-file ignore，对应文件已不存在。**修复方式**：删除这些 per-file override 段。
- `backend/alembic/env.py` autogenerate 仅 `import Text2ImgTask, ImageToVideoTask`，漏 `import ClientLog`。**修复方式**：补 import。
- 后端版本号三处不一致：pyproject=`0.1.0` / FastAPI 实例=`0.2.0` / `__init__.py`=`1.0.0`。**修复方式**：统一到单一版本来源。
- `novel_app/CLAUDE.md` 列 `novel_context_service.dart` 待二次确认（plan 阶段）。
```

- [ ] **Step 12: 跑 P2.1 验证**

```bash
git grep -nE "9 个小说站点|chapter_cache 表" CLAUDE.md
grep -nE "已删.*scene_illustration" CLAUDE.md
```
预期：scene_illustrations 已删在事实陈述中保留；"9 个小说站点" 仅出现于历史 changelog 段（2026-07-08 已移除）。

人工 diff 检查：db v39 / 17 端点 / `已知问题` 节存在。

- [ ] **Step 13: Commit P2.1**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(claude): 同步根 CLAUDE.md 到 v39 / 17 端点 / 3 Tab / 已知问题

- 顶部 Changelog 加 2026-07-27 条目
- 项目愿景改为"AI 原生小说阅读平台"
- 架构 mermaid 后端加 ComfyUI 分块上传
- 后端核心功能段重写
- 数据库清单同步（含 v34 media_items / v37-39 site_scripts 等）
- 数据库版本 v38 → v39
- API 端点表补齐 17 个（含 /api/models/{dirs,upload/*} 7 个 + backup/delete + /text2img/health + /、/health、/security-check）
- 端口表文案统一
- 新增"已知问题"节列出 scope 之外的工程债

影响范围：根 CLAUDE.md，零业务代码改动
EOF
)"
```

---

## Task 3: P2.2 · 同步 novel_app/CLAUDE.md

**Files:**
- Modify: `novel_app/CLAUDE.md`

**Goal:** 把 `novel_app/CLAUDE.md` 从过期版（v36 / 1.3.9+28 / 16 screens / 17 repos / 42+ services / 44+ widgets / 30+ providers / 23 models / 5 controllers / 4 Tab / core/di/ / illustration_repository 等幽灵模块）同步到现状（v39 / 2.0.2-preview.1+110 / 24+ screens / 15 repos / 48+ services / 50+ widgets / 40+ providers / 25 models / controllers 标注"以代码为准" / 3 Tab / 删除 core/di/ / 删除 illustration_repository, chat_scene_repository）。

**Depends on:** Task 2

---

- [ ] **Step 1: Read novel_app/CLAUDE.md 全文（约 580 行）确认改动锚点**

`Read novel_app/CLAUDE.md`。然后按以下顺序 Edit。

- [ ] **Step 2: 顶部 Changelog 加 2026-07-27**

old = 第一行历史段 `**2026-07-18**: **LLM 重试 UI 展示**...` 之前插入：
```markdown
- **2026-07-27**: **文档同步现状**。App 版本 2.0.2-preview.1+110，DB v39，3 Tab，Repository 15 个，Screen 24+，Service 48+，Widget 50+，Provider 40+，Model 25。详见 `docs/superpowers/specs/2026-07-27-github-display-optimization-design.md`。

```

- [ ] **Step 3: 重写"应用启动流程"段**

old:
```
### 应用启动流程
1. **初始化Flutter绑定**: `WidgetsFlutterBinding.ensureInitialized()`
2. **API服务初始化**: `ApiServiceWrapper().init()`
3. **Provider容器初始化**: `ProviderContainer` 创建 Riverpod 容器
4. **Material3主题设置**: 默认暗色主题
5. **底部导航**: 书架、生图调试、浏览器、设置四个标签页
```

new:
```
### 应用启动流程
1. **初始化Flutter绑定**: `WidgetsFlutterBinding.ensureInitialized()`
2. **API服务初始化**: `ApiServiceWrapper().init()`
3. **Provider容器初始化**: `UncontrolledProviderScope` 创建 Riverpod 容器
4. **Material3主题设置**: 默认暗色主题
5. **Onboarding 状态分支**: `_AppRoot` 检查 `onboardingNotifierProvider.onboardingCompleted`；首次启动进入 `OnboardingScreen`，完成后进入 `HomePage`（后续可从设置复看 onboarding）
6. **底部导航**（HomePage）: **3 个 Tab** —— 书架（`BookshelfScreen`）/ 浏览器（`WebViewBrowserScreen`）/ 设置（`SettingsScreen`）。**注意**：不存在独立的"生图调试"Tab，相关入口在书架内或通过 debug 屏幕访问。
```

- [ ] **Step 4: 删 `core/di/` 引用**

定位节内 `core/di/ - 依赖注入（API服务Provider）`。old:
```
- `core/` - 核心架构组件
  - `di/` - 依赖注入（API服务Provider）
  - `database/` - 数据库连接和初始化
  - `interfaces/` - 接口定义（IDatabaseConnection等）
  - `providers/` - Riverpod状态管理Providers（30+个文件）
    - `service_providers.dart` - 服务层Provider
    - `database_providers.dart` - 数据库连接 + 全部 Repository Provider（统一入口）
    - `bookshelf_providers.dart` - 书架状态Provider
    - `chapter_list_providers.dart` - 章节列表状态Provider
    - `services/` - 各类服务Provider
```

new:
```
- `core/` - 核心架构组件
  - `database/` - 数据库连接与迁移（v1→v39，inline 在 `database_migrations.dart`）
  - `interfaces/` - 接口定义（IDatabaseConnection、I*Repository）
  - `providers/` - Riverpod 状态管理 Providers（40+ 个文件，含 `.g.dart` 派生）
    - `services/` - 服务层 Provider 分类（AI service / core / database / network）
    - `*_providers.dart` - 各业务域 Provider（bookshelf / chapter_list / chapter_search / character / chat_session / agent_chat / agent_scenario / ocr / onboarding / reader_* / relationship_graph / prompt_tag 等）
    - `database_providers.dart` - 数据库连接 + Repository Provider 统一入口
```

- [ ] **Step 5: Repository 清单从 17 → 15（删幽灵）**

定位 `lib/repositories/` 子目录列表。找到：
```
- `illustration_repository.dart` - 插图Repository
- `chat_scene_repository.dart` - 聊天场景Repository
```
old:
```
- `prompt_history_repository.dart` - 提示词历史数据访问
- `prompt_tag_repository.dart` - 提示词标签数据访问
- `prompt_tag_category_repository.dart` - 标签分类数据访问
- `prompt_tag_history_repository.dart` - 标签历史数据访问
- `agent_memory_repository.dart` - Agent记忆数据访问
- `novel_export_repository.dart` - 小说导出数据访问
- `site_script_repository.dart` - 站点脚本数据访问
```

new（删除 `illustration_repository` / `chat_scene_repository` 两行 + `novel_export_repository`（agent 报告未提及）；视实际 grep 调整）:
```
- `prompt_history_repository.dart` - 提示词历史数据访问
- `prompt_tag_repository.dart` - 提示词标签数据访问
- `prompt_tag_category_repository.dart` - 标签分类数据访问
- `prompt_tag_history_repository.dart` - 标签历史数据访问
- `agent_memory_repository.dart` - Agent 经验记忆数据访问
- `site_script_repository.dart` - 站点脚本数据访问
```

**注**：上表行如与实际代码不一致（agent 报告 `prompt_history_repository` 也未必存在），以 `git grep -l "Repository" novel_app/lib/repositories/` 输出为准修订。**实际 grep 是本步骤的前置动作**：

```bash
ls novel_app/lib/repositories/
```
剔除 `base_repository.dart`，剩下列出的 Repository 类名。spec 列了 15 个：base_repository / agent_memory / bookshelf / chapter / chapter_version / character / character_relation / llm_config / novel / outline / prompt_tag / prompt_tag_category / site_script + 据上下文还有 `chat_session`/`prompt_history`/`prompt_tag_history`。**以实际 ls 出的 .dart 文件为准**。

- [ ] **Step 6: 删除 "ScenesIllustration" "ChatScene" "Illustration" Repository 提及（删幽灵）**

Search `novel_app/CLAUDE.md`：
```bash
git grep -nE "illustration_repository|chat_scene_repository|SectionIllustration|SceneIllustration" novel_app/CLAUDE.md
```
删除任何提到这些幽灵 module 的行（保留"已删除"事实陈述如 agent 报告所列的"Dify 残留清理"那段）。

- [ ] **Step 7: 更新数据库"版本: v36 → v39"**

定位 line 234 附近 "**类型**: SQLite / **版本**: v36"。old:
```
- **类型**: SQLite
- **版本**: v36
```

new:
```
- **类型**: SQLite
- **版本**: v39
- **迁移工具**: inline `_migrateToVersion(int oldVersion, int newVersion)` 在 `lib/core/database/database_migrations.dart`
```

- [ ] **Step 8: 数据库表清单同步**

定位 "#### 物理表列表" 段。old 含 10 条（bookshelf / bookshelves / novel_bookshelves / chapter_cache / novel_chapters / characters / character_relationships / scene_illustrations / outlines / chat_scenes）。

new 替换整个列表为：
```
1. **bookshelf** (小说表，v1+ ; v3 `background_setting` ; v36 `coverMediaId`)
2. **bookshelves** (书架分类，v16)
3. **novel_bookshelves** (小说-书架多对多，v16)
4. **chapter_cache** (章节内容缓存，v1+ ; v18 `isAccompanied`)
5. **novel_chapters** (章节列表元数据，v1+ ; v2 `is_user_inserted` ; v11 `read_at` ; v18 `is_accompanied`)
6. **characters** (角色表，v1+ ; v5 `face_prompts` ; v6 `cached_image_url` ; v12 `aliases` ; v34 `avatar_media_id` ; v35 `first_appearance_chapter`)
7. **character_relationships** (角色关系，v13+ ; v35 区间模型重建)
8. **outlines** (大纲，v9)
9. **chat_scenes** (聊天场景，v10 — 与 chat_sessions 不同)
10. **chat_sessions** (Agent Chat 会话，v31 ; 含 `scenarioId` / `currentNovelId`)
11. **chat_messages** (Agent Chat 消息，v31-32 ; 含 `toolCallsJson` / `toolCallId` / `agentMsgIndex`)
12. **media_items** (统一媒体代理，v34 ; mediaId / kind / source / local_only)
13. **prompt_history** (提示词历史，v22 ; v26 `tag_group_ids`)
14. **prompt_tag_categories** (标签分类，v23)
15. **prompt_tags** (标签，v23 ; v24 约束重建 ; v28 `reason`)
16. **agent_memory** (Agent 经验记忆，v27)
17. **prompt_tag_history** (标签变更历史，v28)
18. **llm_configs** (LLM 配置 CRUD，v29)
19. **chapter_versions** (章节版本历史，v30 ; AI 编辑/重写留档)
20. **site_scripts** (站点提取脚本，v25+ ; v37 `ocr` ; v39 加 `chapter_list_ocr` + `chapter_content_ocr` 两列)

**已删除**：
- `scene_illustrations`（v34 删除，由 `media_items` 替代）
- `model_download_tasks`（v38 删除，webview 不再下载模型）
- 后端 `novel_cache_tasks`/`novel_chapters_cache`/`chapter_list_cache`（2026-07-08 由后端迁移删除，前端不再相关）
```

- [ ] **Step 9: 缓存系统段重写**

定位 "### 缓存系统" 段。old:
```
### 章节内容缓存

**本地SQLite**:
- 表：`chapter_cache`, `novel_chapters`
- Repository: `ChapterRepository`
- 特性：支持用户插入章节保护

**服务端PostgreSQL**:
- API: `POST /api/cache/create`
- 查询: `GET /api/cache/status/{task_id}`
```

new:
```
### 章节内容缓存

**本地SQLite**:
- 表：`chapter_cache` / `novel_chapters`
- Repository: `ChapterRepository`
- 特性：用户插入章节保护（`is_user_inserted`）、`is_accompanied` 标记是否带 AI 特写

**后端兜底已移除**（2026-07-08）：`/api/cache/*` 等服务端口已删除，前端不再依赖服务端缓存。如需重新跨设备同步，使用备份（`lib/services/backup_service.dart`）+ 后端 `/api/backup/upload|list|download` 链路。
```

- [ ] **Step 10: DSL Engine 段去掉"Dify 复刻"措辞**

定位 "### DSL Engine（本地 Dify 工作流复刻）" 标题与小节。old:
```
#### DSL Engine（本地 Dify 工作流复刻）

**核心组件** (`lib/services/dsl_engine/`):
- `llm_provider.dart` - OpenAI 兼容的 LLM 调用（含 ChatMessage 模型）

**说明**: DSL Engine 已大幅精简，仅保留 LLM 调用核心；结构化工作流能力迁移至 AI Agent（`lib/services/novel_agent/`）。

**用途**:
- 创意写作（段落重写、全文重写）
- 章节/背景摘要生成
- 场景插图提示词生成

**配置** (设置 → AI 配置):
- LLM API URL（OpenAI 兼容地址）
- LLM API Key
- 默认模型（可选）
```

new:
```
#### DSL Engine（本地 LLM 工作流引擎）

**核心组件** (`lib/services/dsl_engine/`):
- `llm_provider.dart` / `llm_provider_client.dart` / `llm_provider_config.dart` / `llm_provider_core.dart` / `llm_provider_sse.dart` - OpenAI 兼容的 LLM 调用
- `retry_signals.dart` - LLM 重试 UI 信号（2026-07-18 重构）

**说明**: DSL Engine 已与 Dify 完全解耦（2026-06-09 移除 Dify 云端依赖，2026-06-29 清理 Dify 残留）。当前仅保留 LLM 调用核心；结构化工作流能力迁移至 AI Agent（`lib/services/novel_agent/`）。

**用途**:
- 创意写作（段落重写、全文重写）
- 章节/背景摘要生成
- 场景插图提示词生成
- 统一错误重试（`withRetry` / `RetrySignals`）

**配置** (设置 → AI 配置):
- LLM API URL（OpenAI 兼容地址）
- LLM API Key
- 默认模型（可选）
```

- [ ] **Step 11: 版本管理段 v → 2.0.2-preview.1+110**

定位 "**当前版本**: 1.3.9+28"。old = `**当前版本**: 1.3.9+28`。
new = `**当前版本**: 2.0.2-preview.1+110`。

- [ ] **Step 12: 全局计数修正**

执行以下 Edit 替换：
- `"页面 16 个 Screen"` → `"页面 24+ 个 Screen"`
- `"数据访问层（17个Repository类）"` → `"数据访问层（15 个 Repository 类）"`
- `"业务服务层（42+个文件）"` → `"业务服务层（48+ 个文件）"`
- `"完整页面界面（16个Screen）"` → `"完整页面（24+ 个 Screen）"`
- `"可复用UI组件（44+个Widget）"` → `"可复用 UI 组件（50+ 个 Widget）"`
- `"对话框组件（1个对话框）"` → 保留
- `"数据模型（23个Model类）"` → `"数据模型（25 个 Model 类）"`
- `"工具类（13个工具类）"` → 保留
- `"Riverpod状态管理Providers（30+个文件）"` → `"Riverpod 状态管理 Providers（40+ 个文件，含派生）"`
- `"控制器层（5个文件）"` → `"控制器层（`lib/controllers/` 下 reader_content + chapter_list/ 子控制器；具体计数以代码为准）"`

- [ ] **Step 13: FAQ 段清理 dify_settings_screen 提及**

搜索 `git grep -n "dify_settings_screen" novel_app/CLAUDE.md`，删除命中行（保留 git grep 0 行）。

- [ ] **Step 14: 末尾"最后更新" + "文档状态"**

定位文末 `**最后更新**: 2026-06-29` 与 `**文档状态**: ✅ 已验证`。
- old_last = `**最后更新**: 2026-06-29`
- new_last = `**最后更新**: 2026-07-27`
- old_status = `**文档状态**: ✅ 已验证`
- new_status = `**文档状态**: 🔄 已同步现状（2026-07-27 文档系统梳理）`

- [ ] **Step 15: 跑 P2.2 验证**

```bash
git grep -nE "v36|1\.3\.9|16 个 Screen|17 个 Repository|42\+ 个文件|44\+ 个 Widget|30\+ 个文件|core/di/|illustration_repository|chat_scene_repository|dify_settings_screen|Dify 工作流复刻" novel_app/CLAUDE.md
```
预期：仅 changelog 历史段（2026-06-29 之前）可命中 `dify_settings_screen`，其他全部 0 命中。

也可接受命中（事实陈述段）：
- "Dify Facade" 在历史已删除相关说明段
- "scene_illustrations 已删除"在新表清单注释段

人工 diff 检查：
- DB v39 在数据库段
- 2.0.2-preview.1+110 在版本段
- 15 个 Repository 列出
- 24+ screens / 48+ services / 50+ widgets / 40+ providers / 25 models

- [ ] **Step 16: Commit P2.2**

```bash
git add novel_app/CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(novel_app): 同步 novel_app/CLAUDE.md 到 v39 / 2.0.2 / 24+ screens / 15 repos

- Changelog 顶部加 2026-07-27
- 应用启动流程改 3 Tab（删"生图调试"）+ onboarding 状态分支
- 删 core/di/（实际不存在）；providers 注释更新到 40+
- Repository 清单删 illustration_repository / chat_scene_repository（幽灵 module）
- 数据库版本 v36 → v39；表清单与迁移版本号完整对齐
- chapter_cache 段去"服务端 PostgreSQL 缓存"（2026-07-08 已删）
- DSL Engine 去"Dify 复刻"措辞，标 2026-06-09 已彻底解耦
- 全局计数：Screen 16→24+/Repo 17→15/Service 42+→48+/Widget 44+→50+/Model 23→25/Provider 30+→40+
- Controller 计数标"以代码为准"
- 末尾"最后更新 2026-06-29"→2026-07-27；"已验证"→"已同步现状"

影响范围：novel_app/CLAUDE.md，零业务代码改动
EOF
)"
```

---

## Task 4: P2.3 · 标注 backend CLAUDE.md 已知问题

**Files:**
- Modify: `backend/CLAUDE.md`

**Goal:** 在 backend CLAUDE.md 加注三处已知问题（Dockerfile 残留 / openapi.json 过期 / 版本号三处不一致），保留已有内容（基本是对的）。

**Depends on:** Task 3

---

- [ ] **Step 1: Read backend/CLAUDE.md 全文（约 340 行）**

`Read backend/CLAUDE.md`。本任务改动量最小。

- [ ] **Step 2: 更新"入口与启动"中的版本号**

定位 "### 入口与启动"。old:
```
- **版本**: 0.2.0
- **端口**: 8000（Docker 映射 3800）
```

new:
```
- **版本**: 0.2.0（FastAPI 实例；详见§版本号不一致说明）
- **端口**: 8000（Docker 映射 3800）

> **版本号不一致说明**（scope 之外，待后续 PR）：仓库存在三处 Python 版本号，分别为 `pyproject.toml` 的 `0.1.0` / `app/main.py` 的 FastAPI `version="0.2.0"` / `app/__init__.py` 的 `__version__="1.0.0"`。本模块文档以 FastAPI 实例 `0.2.0` 为基准；建议统一到单一来源（如 `app.__version__` 单点 + hatch dynamic version）。
```

- [ ] **Step 3: Docker 部署段加注残留**

定位 `### Docker 部署`。old:
```
### Docker 部署

- 基础镜像: Python 3.11-slim（多阶段构建）
- 健康检查: `/health` 端点
- 已移除 Playwright / Scrapling 系统库与浏览器安装，镜像显著瘦身
```

new:
```
### Docker 部署

- 基础镜像: Python 3.11-slim（多阶段构建，`backend/Dockerfile`）
- 健康检查: `/health` 端点
- 已移除 Playwright / Scrapling 系统库与浏览器安装，镜像显著瘦身（**仅对生产 `Dockerfile` 属实**）

> **Dockerfile 残留提醒**（scope 之外）：`backend/Dockerfile.debug` 仍 `python -m playwright install chromium`，`backend/Dockerfile.test` 仍装 `scrapling[fetchers]` 与 `scrapling[core]`，`backend/Dockerfile.simple` 仍装 `beautifulsoup4 lxml`。根 `docker-compose.yml` 当前引用的就是 `Dockerfile.debug`，构建会失败。修复方式见根 CLAUDE.md「已知问题」节。
```

- [ ] **Step 4: 跑 P2.3 验证**

人工 diff 检查：
- 入口段多出"版本号不一致说明"块
- Docker 部署段多出"Dockerfile 残留提醒"块

```bash
git diff backend/CLAUDE.md | head -60
```

- [ ] **Step 5: Commit P2.3**

```bash
git add backend/CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(backend): 标注 backend CLAUDE.md 已知问题（版本号 / Dockerfile 残留）

- 入口段加"版本号不一致说明"（pyproject 0.1.0 / FastAPI 0.2.0 / __init__ 1.0.0）
- Docker 部署段加"Dockerfile 残留提醒"（debug/test/simple 三文件含 dead 依赖）
- 本文档以 FastAPI 实例 0.2.0 为基准；其余内容基本与现状一致，未做大规模重写

影响范围：backend/CLAUDE.md，零业务代码改动
EOF
)"
```

---

## Task 5: P3 · docs/ 全量修正

**Files:**
- Modify: `docs/README.md`
- Modify: `docs/developer-guide.md`
- Modify: `docs/deployment.md`
- Modify: `docs/APP功能介绍.md`
- Modify: `docs/logging-guidelines.md`
- Modify: `docs/user-guide.md`
- Modify: `docs-site/assets/README.md`

**Goal:** 修正 docs/ 过期处；docs/README.md 补 superpowers/architecture/chapter-fetch-flow/diagrams 索引；邮箱脱敏（修复 Task 1 残留：`docs/README.md:94` / `docs/deployment.md:533` / `docs/user-guide.md:216` 三处 `kfeb4@outlook.com`），确保全局 V1 `kfeb4 → 0` 通过。

**Depends on:** Task 4

---

- [ ] **Step 1: 定位过期关键词**

```bash
git grep -nE "Dify|Scrapling|9 (个|站点)|v21|chapter_cache|redis|prometheus|grafana" docs/developer-guide.md docs/deployment.md docs/APP功能介绍.md docs/logging-guidelines.md docs/README.md
```
记下每一处的章节上下文，准备逐段改写。

- [ ] **Step 2: 改 `docs/README.md` 索引**

old（仅示例，需 Read 当前文档确认完整结构）。定位 `最后更新: 2026-06-11`，改为 `最后更新: 2026-07-27`。

在索引列表中**新增**：
```
- [superpowers/](superpowers/) - 内部设计与实施计划（决策追溯，非展示文档）
- [architecture/](architecture/) - 浏览器/章节提取架构
- [chapter-fetch-flow.html](chapter-fetch-flow.html) - 章节获取流程图
```

如有 `diagrams/` 也加（agent 报告有 `docs/diagrams/`，但 docs/README.md 当前是否已索引？先 Read 确认）。

**邮箱脱敏**（修复 Task 1 残留，确保全局 V1 `kfeb4 → 0` 通过）：
- old = `kfeb4@outlook.com`（docs/README.md 邮件支持章节，约 line 94）
- new = `[GitHub Issues](https://github.com/yunkst/novel_builder/issues/new/choose)`

- [ ] **Step 3: 改 `docs/developer-guide.md` 关键词扫描**

Read 全文。逐段 Edit：

| 旧 | 新 |
|---|---|
| "Scrapling 爬虫（9 站点）" | "Headless WebView + 本地 JS 提取脚本（前端 `lib/services/headless_webview_*.dart`）" |
| "数据库 v21" | "数据库 v39" |
| "chapter_cache / cache_tasks" | "chapter_cache（前端本地唯一缓存；后端 `/api/cache/*` 2026-07-08 已删）" |
| "WebSocket 推送" | 整段删除（无推送机制）|
| "Dify" | 整段删除 / 改为 "DSL Engine（与 Dify 解耦）+ Agent Chat" |
| "Playwright" | 删除 |
| 技术栈表：删 "Scrapling / Playwright / OpenCC" 行 |

- [ ] **Step 4: 改 `docs/deployment.md`**

| 旧 | 新 |
|---|---|
| "docker-compose.prod.yml 含 redis+nginx+prometheus+grafana" | "本仓库仅 `docker-compose.yml`（后端 + postgres）；生产化（Nginx 反代、HTTPS、备份）见各运维团队规范" |
| "SSL/CDN/Redis 缓存策略" 段 | 整段删或缩到"Nginx 反代 + HTTPS 自行配置" |
| 环境变量段对齐新 `.env.example` | 删 `SECRET_KEY` / `MAX_UPLOAD_SIZE` / `UPLOAD_DIR` / `VIDEO_GENERATION_TIMEOUT` / `LOG_LEVEL` / `HOST` / `PORT`；保留核心 8 项 |

**邮箱脱敏**：
- old = `kfeb4@outlook.com`（line 533 邮件支持章节）
- new = `[GitHub Issues](https://github.com/yunkst/novel_builder/issues/new/choose)`

- [ ] **Step 5: 改 `docs/APP功能介绍.md`**

| 旧 | 新 |
|---|---|
| "Dify 配置" 段 | 整段删除 / 改为 "DSL Engine 配置" |
| "5 个站点爬虫（shukuge / ddxsmf / wdscw / wfxs / biquge543）" | "前端 Headless WebView 提取 + 本地站点脚本（`site_scripts` 表配置，OCR 还原由 PP-OCRv6 处理）；不依赖固定站点" |
| "SQLite v21" | "SQLite v39" |
| 配图说明：图反映含"搜索"/"Dify 配置" 的 UI | "截图反映旧版 UI（含已移除的搜索/Dify 配置入口），新版本 UI 已简化，截图待重生成" |

- [ ] **Step 6: 改 `docs/logging-guidelines.md`**

Read 全文。删 Dify 时代术语（如 "Dify 工作流日志"）。保留 LoggerService 4 级 × 8 分类 × 标签规范。在末尾或开头加注："自 2026-07-17 traceId + 文件回退重构，详见根 CLAUDE.md Changelog 对应条目。"

- [ ] **Step 6a: 改 `docs/user-guide.md` 邮箱脱敏**

**邮箱脱敏**（line 216 联系维护者章节）：
- old = `kfeb4@outlook.com`
- new = `[GitHub Issues](https://github.com/yunkst/novel_builder/issues/new/choose)`

如该文件还存在 `Dify` / `Scrapling` / `9 站点` / `v21` 等过期关键词，一并清理（与 Step 3-Step 6 同口径）。

- [ ] **Step 7: 改 `docs-site/assets/README.md`**

Read 现有内容。在末尾追加一行：
```
> 注意：本目录下占位素材（demo-*.png/mp4）目前全部为空，欢迎 PR 贡献截图或录屏。仓库 README 暂不依赖它们。
```

- [ ] **Step 8: 跑 P3 验证**

```bash
git grep -nE "Dify|Scrapling|9 (个|站点)|v21|chapter_cache|redis|prometheus|grafana" docs/developer-guide.md docs/deployment.md docs/APP功能介绍.md docs/logging-guidelines.md
```
预期：仅历史性提及（"Dify 残留" 在 changelog 段），其他 0 命中。

如 `docs/README.md` 索引含 `superpowers/` / `architecture/` / `chapter-fetch-flow` 三个新项：
```bash
grep -nE "superpowers|architecture|chapter-fetch-flow" docs/README.md
```
预期：每个至少 1 命中。

- [ ] **Step 9: Commit P3**

```bash
git add -A
git status --short
git commit -m "$(cat <<'EOF'
docs(手册): 修正 docs/ 中 Scrapling/Dify/9 站/v21 等过期关键词

- developer-guide.md: 改"Scrapling 爬虫 9 站" → Headless WebView；DB v21 → v39；删 Dify/Playwright/WebSocket 段；技术栈对齐
- deployment.md: 删 docker-compose.prod 含 redis+nginx+prometheus 段；环境变量对齐新 .env.example
- APP功能介绍.md: 删 Dify 配置段 / 5 站爬虫段；SQLite v21 → v39；配图说明标"待重生成"
- logging-guidelines.md: 删 Dify 时代术语；加 2026-07-17 traceId 重构注
- docs/README.md: 索引补 superpowers/architecture/chapter-fetch-flow；更新日期
- docs-site/assets/README.md: 标注截图/录屏待补

影响范围：docs/ 子集，零业务代码改动
EOF
)"
```

---

## Task 6: P4 · README 门面重写

**Files:**
- Modify: `README.md`

**Goal:** README 改为「AI 原生小说阅读平台」叙事，对齐 v39 / 17 端点 / 3 Tab / 24+ screens 等现状。

**Depends on:** Task 5

---

- [ ] **Step 1: Read README.md 全文**

`Read README.md`。本任务的整段替换量较大，建议分段 Edit 而非整篇 Write。

- [ ] **Step 2: 顶部中心标语**

定位 `<div align="center">` 段。old:
```
![Novel Builder](https://img.shields.io/badge/Novel-Builder-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Flutter](https://img.shields.io/badge/flutter-3.0+-blue.svg)
![Python](https://img.shields.io/badge/python-3.11+-blue.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-red.svg)
![CI](https://github.com/yunkst/novel_builder/actions/workflows/flutter-ci.yml/badge.svg)

**现代化的全栈小说阅读平台**

提供跨平台的小说搜索、阅读、缓存和AI增强功能
```

new:
```
![Novel Builder](https://img.shields.io/badge/Novel-Builder-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Flutter](https://img.shields.io/badge/flutter-3.0+-blue.svg)
![Python](https://img.shields.io/badge/python-3.11+-blue.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.104+-red.svg)
![CI](https://github.com/yunkst/novel_builder/actions/workflows/flutter-ci.yml/badge.svg)

**AI 原生小说阅读平台**

本地书架 + Headless WebView 章节提取 + Agent Chat + ComfyUI 文生图/图生视频 + 字体反爬 OCR 还原
```

- [ ] **Step 3: "📱 跨平台移动应用" 功能特性**

old:
```
### 📱 跨平台移动应用
- **Flutter 构建**：支持 Android、iOS、Windows
- **Material Design 3**：现代化 UI 设计
- **离线阅读**：本地 SQLite 缓存
- **智能搜索**：跨 9 个小说站点统一搜索
- **AI 增强**：DSL Engine 本地工作流 + Hermes Agent 智能对话
```

new:
```
### 📱 Flutter 移动应用（Flutter 3.0+，App 版本 2.0.2-preview.1+110）
- **离线优先**：本地 SQLite（v39）做唯一权威存储
- **Headless WebView 章节提取**：前端 JS 提取脚本（`site_scripts` 表），不依赖服务端爬虫
- **PP-OCRv6 字体反爬还原**：番茄小说等 PUA 编码正文可读
- **本地搜索**：章节内容全文搜索（`chapter_search_service.dart`）
- **AI 增强**：DSL Engine + Agent Chat + Subagent + 上下文压缩 + LLM 重试横幅
```

- [ ] **Step 4: "🌐 强大的后端服务" 功能特性**

old:
```
### 🌐 强大的后端服务
- **FastAPI 驱动**：高性能异步 API
- **多站点爬虫**：支持 9 个小说站点（7 个活跃 + 2 个禁用）
- **智能缓存**：PostgreSQL + 本地缓存双重策略
- **实时通信**：WebSocket 进度推送
- **Docker 部署**：一键容器化部署
```

new:
```
### 🌐 FastAPI 后端（17 个端点）
- **AI 接口**：ComfyUI 文生图 / 图生视频（提交 + 单接口轮询；支持 negative_prompt）
- **模型管理**：列出工作流 + 模型目录浏览 + 模型分块上传（init/chunk/status/complete/cancel）
- **数据库备份**：客户端 .db 上传/列表/下载/删除
- **客户端日志**：批量 1–50 条/次持久化
- **Docker 部署**：docker-compose 一键启动后端 + PostgreSQL（容器内不暴露）
```

- [ ] **Step 5: "🤖 AI 集成功能" 段**

old:
```
### 🤖 AI 集成功能
- **DSL Engine**：客户端 Dify 工作流复刻，支持结构化信息提取、创意写作等
- **Hermes Agent**：基于 OpenAI 兼容 API 的智能对话助手
- **场景插图**：AI 生成的场景插图功能（ComfyUI 后端）
- **角色卡提取**：智能识别和分析章节角色
```

new:
```
### 🤖 AI 集成（DSL Engine + Agent Chat + ComfyUI）
- **DSL Engine**：本地 LLM 工作流引擎（OpenAI 兼容 API；2026-06-09 已与 Dify 完全解耦）
- **Agent Chat**：写作 / 浏览器 / 多角色场景 + Subagent + 上下文压缩（`novel_agent/`）
- **ComfyUI 文生图 / 图生视频**：场景插图 + 角色配图，`create_images` / `create_image_to_video` 工具
- **角色卡管理**：智能识别 + 人物关系图（`flutter_force_directed_graph`）
```

- [ ] **Step 6: 端口映射段**

old:
```
### 端口映射
- **移动应用**：3154 (开发调试)
- **后端API**：3800 → 8000 (FastAPI)
- **数据库**：5432 (PostgreSQL)
- **API文档**：http://localhost:3800/docs
```

new:
```
### 端口映射
- **后端 API**：3800 → 8000（FastAPI）
- **debugpy**：6678 → 5678（Dockerfile.debug；生产部署不需要）
- **PostgreSQL**：5432（仅 Docker 容器内部，不对宿主机暴露）
- **ComfyUI**：8188（宿主机本地，文生图后端，通过 `host.docker.internal` 引用）
- **API 文档（Swagger UI）**：http://localhost:3800/docs

> 移动应用不使用固定端口，由 `flutter run` 决定。
```

- [ ] **Step 7: "🛠️ 技术栈" 后端段**

old:
```
### 后端技术
- **FastAPI**：Python Web框架
- **PostgreSQL**：主数据库
- **SQLAlchemy**：ORM框架
- **Scrapling**：现代网页爬虫库
- **Playwright**：高级网页自动化
```

new:
```
### 后端技术
- **FastAPI**：Python Web 框架（17 端点；alembic head `20260708_drop_cache_tables`）
- **SQLAlchemy + Alembic**：ORM + 迁移（head = `20260708_drop_cache_tables`）
- **PostgreSQL 15**（生产）/**SQLite**（本地 dev 默认）：通过 `DATABASE_URL` 切换
- **ComfyUI 客户端**：工作流占位符递归替换 + HTTP 提交 / 轮询
```

（注：删 Scrapling / Playwright 行）

- [ ] **Step 8: "🏗️ 项目结构" 段**

old:
```
├── 📱 novel_app/          # Flutter 移动应用
│   ├── lib/               # 应用源代码
│   │   ├── core/          # 核心基础设施（DI、数据库、Provider）
│   │   ├── screens/       # 页面组件
│   │   ├── widgets/       # 可复用组件
│   │   ├── services/      # 业务服务（DSL Engine、爬虫适配等）
│   │   ├── repositories/  # 数据仓库层
│   │   ├── models/        # 数据模型
│   │   └── utils/         # 工具函数
│   ├── android/           # Android 平台配置
│   ├── ios/               # iOS 平台配置
│   ├── assets/            # 静态资源（DSL 工作流定义）
│   └── CLAUDE.md          # 模块文档
├── 🌐 backend/            # Python 后端服务
│   ├── app/               # API 源代码
│   │   ├── api/routes/    # API 路由（备份、Hermes、同步、日志）
│   │   ├── services/      # 业务服务（爬虫、缓存、AI客户端）
│   │   └── models/        # 数据模型
│   ├── tests/             # 测试文件
│   ├── alembic/           # 数据库迁移
│   └── CLAUDE.md          # 模块文档
├── 📚 docs/               # 项目文档
├── 🐳 docker-compose.yml  # Docker 编排文件
├── 📄 README.md           # 项目说明
├── 📜 LICENSE             # 开源许可证
└── 🤝 CONTRIBUTING.md     # 贡献指南
```

new:
```
├── 📱 novel_app/          # Flutter 移动应用（v39 SQLite，24+ screens，48+ services）
│   ├── lib/               # 应用源代码
│   │   ├── core/          # 核心基础设施（database + interfaces + providers）
│   │   ├── screens/       # 页面组件（24+）
│   │   ├── widgets/       # 可复用组件（50+，含 agent_chat/reader/character 等）
│   │   ├── services/      # 业务服务（DSL Engine / Agent / Headless WebView / OCR 等）
│   │   ├── repositories/  # 数据仓库层（15 个 Repository）
│   │   ├── models/        # 数据模型（25 个 Model）
│   │   └── utils/         # 工具函数
│   ├── android/           # Android 平台配置
│   ├── ios/               # iOS 平台配置
│   ├── assets/            # 字体（Noto SC）+ OCR 模型（inference.onnx + dict）
│   └── CLAUDE.md          # 模块文档
├── 🌐 backend/            # Python FastAPI 后端（17 端点）
│   ├── app/               # API 源代码
│   │   ├── api/routes/    # API 路由（backup / logs / models）
│   │   ├── services/      # 业务服务（comfyui_client / text2img / image_to_video）
│   │   └── models/        # ORM 模型（text2img_task / image_to_video_task / client_logs）
│   ├── tests/             # 测试文件
│   ├── alembic/           # 数据库迁移（head = 20260708_drop_cache_tables）
│   └── CLAUDE.md          # 模块文档
├── 📚 docs/               # 项目文档（含 user-guide / deployment / APP功能介绍 / superpowers/ 等）
├── 🐳 docker-compose.yml  # Docker 编排（后端 + PostgreSQL；个人挂载见 override）
├── 📄 README.md           # 项目说明
├── 📜 LICENSE             # MIT 许可证
└── 🤝 CONTRIBUTING.md     # 贡献指南
```

- [ ] **Step 9: "📖 文档" 段**

old:
```
### 用户文档
- [使用指南](docs/user-guide.md)
- [功能介绍](docs/APP功能介绍.md)

### 开发者文档
- [开发者指南](docs/developer-guide.md)
- [API 文档](http://localhost:3800/docs)
- [部署指南](docs/deployment.md)
- [Flutter 模块](novel_app/CLAUDE.md)
- [后端模块](backend/CLAUDE.md)
- [日志指南](docs/logging-guidelines.md)

### 文档索引
- [文档中心](docs/README.md)
```

new:
```
### 用户文档
- [使用指南](docs/user-guide.md)
- [功能介绍](docs/APP功能介绍.md)（截图反映旧版 UI，待重生成）

### 开发者文档
- [开发者指南](docs/developer-guide.md)
- [部署指南](docs/deployment.md)
- [后端 API 文档（Swagger UI）](http://localhost:3800/docs)
- [Flutter 模块](novel_app/CLAUDE.md)（模块 CLAUDE.md）
- [后端模块](backend/CLAUDE.md)
- [日志指南](docs/logging-guidelines.md)
- [内部决策追溯](docs/superpowers/)（AI 上下文，不对外展示）

### 文档索引
- [文档中心](docs/README.md)
```

- [ ] **Step 10: "🚀 快速开始" docker-compose 段**

定位 clone 后步骤。old:
```
git clone https://github.com/yunkst/novel_builder.git
cd novel_builder

# 配置环境变量
cp .env.example .env
# 编辑 .env 文件，设置必要的环境变量

# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps
```

new:
```
git clone https://github.com/yunkst/novel_builder.git
cd novel_builder

# 配置环境变量
cp .env.example .env
# 编辑 .env，至少设置 NOVEL_API_TOKEN

# 启动所有服务（默认不含个人机挂载）
docker compose up -d

# 查看服务状态
docker compose ps

# 可选：挂载本机 ComfyUI 模型目录 / novel_sync 目录
# cp docker-compose.override.yml.example docker-compose.override.yml
# 编辑 .env 填入 COMFYUI_MODELS_HOST_DIR / NOVEL_SYNC_HOST_DIR，或直接在 override 里硬编码
```

- [ ] **Step 11: "📞 联系我们" 段**

保留 `https://github.com/yunkst/novel_builder/issues` 与 `discussions`。无需改字。

- [ ] **Step 12: 末尾 "Made with ❤️ by [yunkst]"**

保留，不动。

- [ ] **Step 13: 跑 P4 验证**

```bash
git grep -nE "9 个小说|Hermes Agent|Dify 工作流复刻|Scrapling|Playwright|3154|跨 9 个小说站点统一搜索" README.md
```
预期：0 行（"Hermes Agent" / "Scrapling" / "Playwright" 在事实陈述段如有也需改）。

人工预览：把 README.md 在浏览器打开（VS Code 预览即可）核对：
- 顶部中心标语反映 AI 原生
- 端口表 4 项（API / debugpy / Postgres / ComfyUI）+ 备注
- 文档区有 superpowers/ 索引
- 快速开始有 override.example 提示

- [ ] **Step 14: Commit P4**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs(readme): 重写门面，对齐 AI 原生叙事 / v39 / 17 端点 / 3 Tab

- 顶部中心标语改"AI 原生小说阅读平台"
- 移动应用段：删"跨 9 个小说站点统一搜索"、删"Hermes Agent"；加 PP-OCRv6 / 上下文压缩 / LLM 重试横幅
- 后端服务段：删"9 站爬虫 / WebSocket"；改为 17 端点（文生图/图生视频/模型分块上传/备份/日志）
- AI 集成段：DSL Engine 去"客户端 Dify 工作流复刻"；加 Agent Chat + Subagent
- 端口映射：删"移动应用：3154"；debugpy / Postgres / ComfyUI 全列
- 技术栈 - 后端：删 Scrapling / Playwright 行；技术栈对齐 v39 Alembic head
- 项目结构图：core 删 DI；services/列 DSL Engine/Agent/Headless WebView/OCR；api/routes 列 backup/logs/models；assets 列字体/OCR 模型
- 文档区加 superpowers/ 索引（标"AI 上下文决策追溯"）
- 快速开始加 docker-compose.override.yml.example 使用提示

影响范围：README.md，零业务代码改动
EOF
)"
```

---

## 全局验证（DoD · 全任务完成后）

- [ ] **V1**: `git grep -nE "kfeb4@outlook\.com"` → 0 行
- [ ] **V2**: `git grep -nE "your-org/novel-builder"` → 0 行
- [ ] **V3**: `git grep -nE "D:/myspace|D:/Comfyui" docker-compose.yml` → 0 行
- [ ] **V4**: `pip install -r requirements.txt --dry-run` 不拉 playwright
- [ ] **V5**: `docker compose config` 不报错
- [ ] **V6**: `docs/` 子集 grep `Dify|Scrapling|9 (个|站点)|v21|chapter_cache|redis|prometheus` 仅历史段命中（事实陈述）
- [ ] **V7**: `docs/README.md` 含 `superpowers/` / `architecture/` / `chapter-fetch-flow` 索引
- [ ] **V8**: `README.md` 含"AI 原生小说阅读平台" + "Agent Chat" + 端口表 4 项
- [ ] **V9**: 四个 commit 全部落在 master（含 `chore(repo):` / `docs(claude):` + `docs(novel-app):` + `docs(backend):` + `docs:` + `docs(readme):`），共 6 个 commit（P2 拆 3 子 commit）
- [ ] **V10**: `git log --oneline master -6` 显示 6 条新 commit
- [ ] **V11**: `LICENSE` 署名 `Copyright (c) 2025 yunkst`

## Spec Coverage 自查

| Spec 章节 | 对应 Task |
|---|---|
| §3.1 LICENSE 改 yunkst | Task 1 Step 2 |
| §3.1 community 邮箱 + 链接 | Task 1 Step 3 |
| §3.1 .env.example 删 dead | Task 1 Step 4 |
| §3.1 docker-compose 移除个人路径 + override 创建 | Task 1 Step 5-7 |
| §3.1 requirements.txt 删 playwright/bs4 | Task 1 Step 8 |
| §3.1 pubspec metadata | Task 1 Step 9 |
| §3.1 pyproject metadata | Task 1 Step 10 |
| §4 / S5/S6/A1/A2/A3 P2.1 根 CLAUDE.md | Task 2 |
| §4 / A5~A9 P2.2 novel_app CLAUDE.md | Task 3 |
| §4 / A3/A11 P2.3 backend CLAUDE.md | Task 4 |
| §5 P3 docs/ 全量 | Task 5 |
| §5 P4 README 重写 | Task 6 |
| §8 全部 grep 验证 | Task 1-6 每任务末尾 + 全局 V1-V11 |
| §9 提交规范 6 个 commit | Task 1, 2, 3, 4, 5, 6 各 1 个 commit |
