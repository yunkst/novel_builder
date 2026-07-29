# README & 落地页推广化重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `README.md` + `docs-site/index.html` 重构为面向中文小说读者的推广页，技术内容折叠或外迁，文末有 star 引导。文档清理（4 文件删除 + 5 处断链修复）已在 commit `1505f8a` 完成，本计划不再覆盖。

**Architecture:** 按"段"原子提交，每段 README 段落一个 task，落地页微调单独一个 task，最后整体验收。所有内容已在 brainstorming 中与用户逐段确认。

**Tech Stack:** Markdown（README）、HTML/CSS（落地页）。无新依赖。

## Global Constraints

从 spec 沿用的项目级约束，每条要求所有 task 隐式遵循：

- **应用名双名**：主名「随心阅读」（README H1、落地页 H1）+ 副名 Novel Builder（H2 副标、落地页 title 副名）
- **Hero 三按钮**（等权重并排）：⬇️ 下载 APK · 🌐 在线介绍 · ⭐ 给个 Star
- **不夸大能力**：每一项功能必须已基于真实代码核对；夸大项（5s Live Photo / 独立角色聊天 / 字体反爬重复）已删
- **不重拍截图**：纯文字 + emoji + 现有 CSS mockup，不依赖新截图
- **代码引用**：折叠块里 `xx.dart:行号` 引用必须是真实行号；commit 前 grep 复核
- **「越用越懂你」措辞**：正文用情感化（"它记得"），折叠块诚实补充（`agent_memory` 是可手改的经验笔记，非自动学习你行为的推荐算法）
- **原子提交**：每段一个 commit，commit message 用 conventional 中文规范（type(scope): 中文动宾）
- **「面向开发者」整段 `<details>` 折叠**：默认收起，内含技术栈 / 构建命令 / 文档链接 / 贡献入口
- **三段核心卖点（读/改/写）的正文 bullets 严格用「用户视角」**：不出现工具名 / 类名；技术细节折叠到 `<details>` 给开发者审阅真实性

---

## 文件结构总览

**修改文件**（按 task 顺序）：

| 文件 | 修改内容 | 归属 task |
|---|---|---|
| `README.md` | 完全重写（推广化，七段骨架） | Task 1-6 |
| `docs-site/index.html` | 4 处微调（title / Hero H1 / Hero CTA / nav / footer 链接） | Task 7 |

**已 commit 不再改**（前置任务）：
- 删除：`docs/user-guide.md` / `docs/APP功能介绍.md` / `docs/chapter-fetch-flow.html` / `docs/architecture/react-agent-web-extract.html`
- 断链修复：`CONTRIBUTING.md` / `docs/README.md` / `docs/developer-guide.md` / `docs-site/index.html` footer 链接

---

### Task 1: README Hero 段（应用名 + slogan + 三按钮 + 副标）

**Files:**
- Modify: `README.md:1-20`（完全替换原首屏段）
- 涉及：清空原 README 全部内容（除 LICENSE 引用等少数保留项），写入新 Hero

**说明:** Hero 是 README 第一印象，独立一个 task 保证原子性。

- [ ] **Step 1: 用以下内容完整替换 `README.md`（首次写入，后续 task 在此基础上追加）**

完整 `README.md` 内容（本次只写 Hero 段 + 段落分割占位，后续 task 替换占位）：

```markdown
<div align="center">

# 随心阅读
### Novel Builder · AI 原生小说阅读平台

**读喜欢的 · 改不爽的 · 写自己的**

[⬇️ 下载 APK](https://github.com/yunkst/novel_builder/releases/latest)  ·  [🌐 在线介绍](https://yunkst.github.io/novel_builder/)  ·  [⭐ 给个 Star](https://github.com/yunkst/novel_builder)

本地书架 · 任意网站阅读 · 离线缓存 · AI 改写 · AI 创作

</div>

---

<!-- ===== Task 2-6 段落占位（后续 task 逐段替换） ===== -->

---

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。
```

- [ ] **Step 2: 检查文件首屏渲染**

打开 `README.md`，确认：
- 标题「随心阅读」居中、字号最大
- 副标「Novel Builder · AI 原生小说阅读平台」次之
- 三按钮横排，emoji + 文字清晰
- 分隔线下方有占位注释

- [ ] **Step 3: 提交**

```bash
git add README.md
git commit -m "feat(readme): 重写 Hero 段为主名「随心阅读」+ 副名 Novel Builder + 三按钮"
```

预期：`README.md` 单独一行 commit，diff 主要在原 README 的首屏段。

---

### Task 2: README「📖 读」段

**Files:**
- Modify: `README.md` Hero 段分隔线下方（替换占位注释）

**Interfaces:**
- 上游：Task 1 已写好 Hero 与分隔线
- 下游：Task 3-6 在本段后追加其余段落

- [ ] **Step 1: 在 Hero 分隔线下方追加「读」段**

将 README.md 中 `<!-- ===== Task 2-6 段落占位（后续 task 逐段替换） ===== -->` 这一行整段替换为：

```markdown
## 📖 读 · APP 里就能逛任意小说站

打开 APP 就有一个**内置浏览器**。用它打开任意小说站，翻到目录页，右下角会浮出「加入书架」按钮——点一下就进书架了。

- 🌍 **任意站点都能加**：第一次访问某个站时，**AI 现场帮你生成提取脚本**（你要做的只是等一下、确认预览），之后这个站就一劳永逸——下次直接用，不用再生成
- 📖 **干净的正文**：从原页提取正文文本，正文里那些弹窗广告、"请下载 APP 继续"、推广链接，通通没有
- 💾 **看过的章节自动存本地**：断网、飞机上、地铁里，照样翻回去重读；还会偷偷预加载下一章，翻页时不卡
- 🔤 **字体反爬也能读**（番茄这类把字做成乱码的站）：端侧 OCR 自动把乱码还原成正常汉字，不用你管
- 🔎 **书内找东西**：在已缓存章节里搜关键词，按上下文定位；也能让 AI 帮你搜"某个道具第一次出现在第几章"

<details>
<summary>🔧 技术细节（给开发者审阅真实性）</summary>

- **加书流程**：内置浏览器打开站点 → 目录页 FAB 浮出（条件 = 当前 URL 是 http(s)）→ 该域名有 `chapter_list_js` 脚本则直接执行；**无脚本则走 webview_extract 场景 agent 现场生成脚本**（`save_script` 工具），生成后落库，下次复用（`webview_add_novel_button.dart` + `webview_extract_scenario.dart`）
- **正文提取**：`HeadlessWebViewContentService.fetchContent`，前台 high 优先级可抢占后台 low 预加载，HeadlessInAppWebView 单例 + 互斥锁
- **预加载**：`PreloadService` 当前章渲染后入队后续章，FIFO + 30s/任务速率限制，命中缓存 reset
- **OCR 还原**：`site_scripts.chapter_content_ocr` 列标 true → `OcrRestoreService.restorePuaInText` → 端侧 PP-OCRv6（onnxruntime）把 PUA 码点渲染成图再识别
- **搜索双入口**：UI 走 `chapter_search_screen.dart`（已缓存章节全文）；Agent 走 `search_in_chapters` 工具（返回 ~80 字上下文片段）
- **用户章节保护**：`is_user_inserted=1` 章节不被自动更新覆盖

</details>

<!-- ===== Task 3-6 段落占位 ===== -->
```

- [ ] **Step 2: 检查文件渲染**

确认 README.md：
- 「读」段标题清晰
- 5 条 bullets + 1 条 `<details>` 折叠块
- 分隔线与 Hero 段延续

- [ ] **Step 3: 提交**

```bash
git add README.md
git commit -m "feat(readme): 新增「读」段（任意站点+干净正文+离线+OCR+搜索）"
```

---

### Task 3: README「✏️ 改」段

**Files:**
- Modify: `README.md`「读」段后的占位注释

- [ ] **Step 1: 在「读」段后追加「改」段**

将 README.md 中 `<!-- ===== Task 3-6 段落占位 ===== -->` 这一行替换为：

```markdown
## ✏️ 改 · 不爽的剧情，改成你想要的

读到意难平、崩人设、烂尾——不用忍，让 AI 帮你改：

- ✍️ **补全作者没写的细节**：原文一笔带过的打斗、留白的心理活动、没展开的支线——让 AI 帮你写出来接进去
- 📖 **续写烂尾 / 太监文**：作者弃坑了？AI 按现有设定续写后续剧情
- 🆕 **插入自己喜欢的情节**：在某章后插入新章节，AI 按你的脑洞写正文（比如"在这里加一段主角和女二的对手戏"）
- 🔀 **改原著设定 / 走向**：让结局变开放式、让反派洗白、让主角走另一条路——AI 按你的新设定重写整章
- 🎯 **小修小补也省 token**：改个错别字、调一段对话、润色一句描写——AI 直接动你指的那一句，其他一字不改
- 🏷️ **风格标签**：`赛博朋克` `暗黑` 这种标签自由组合，每章套用对应风格写
- 📚 **改了不满意能回滚**：每次 AI 重写都留一份历史版本，不喜欢就退回去

<details>
<summary>🔧 技术细节</summary>

- **补全/续写**：本质是 `create_chapter`（任意位置插入新章节）或 `rewrite_chapter`（AI 按指令重写整章，原文作为上下文）
- **改设定/走向**：`rewrite_chapter` + 修改要求（`agent_tools.dart:333`），AI 注入人物卡 + 写作标签重生成
- **插入情节**：`create_chapter` 指定 position + instruction，AI 写正文插入（`agent_tools.dart:240`）
- **小修小补**：`update_chapter_content` 精确字符串替换（old→new），不调 LLM，多处匹配未设 `replaceAll` 会报 `ambiguous_match`（`agent_tools.dart:290`）
- **风格标签**：`prompt_tags` / `prompt_tag_categories` 表，每章按 `tagNames` 随机抽一条 prompt 拼入
- **版本留档**：`chapter_versions` 表（v30），每次重写存历史版本可回滚

</details>

<!-- ===== Task 4-6 段落占位 ===== -->
```

- [ ] **Step 2: 提交**

```bash
git add README.md
git commit -m "feat(readme): 新增「改」段（补细节/续烂尾/插情节/改设定/小修/标签/回滚）"
```

---

### Task 4: README「🖋️ 写」段

**Files:**
- Modify: `README.md`「改」段后的占位注释

- [ ] **Step 1: 在「改」段后追加「写」段**

将 README.md 中 `<!-- ===== Task 4-6 段落占位 ===== -->` 这一行替换为：

```markdown
## 🖋️ 写 · 从 0 创作一本自己的小说

读完别人的故事，想写自己的——不用懂写作技巧，AI 全程陪你。

**怎么开始（三步）：**

1. 💬 **跟 AI 说一句**："帮我写一本赛博朋克悬疑，主角是个失忆黑客"——AI 会帮你建好书、定世界观、列出角色
2. 📋 **先定骨架**：AI 帮你写全书大纲和章节细纲，故事不散、节奏有人帮你把控
3. 🎬 **逐章生成**：每章说一句你这章想写什么（"主角在酒馆遇到神秘老人，获得关键线索"），AI 结合人物设定 + 你定的风格写出整章正文

**AI 是真"陪写"，不是模板填空：**

- 🎭 **人设不漂**：每个角色的外貌、性格、背景独立建档，写章节时按角色注入上下文，前后一致
- 🎨 **风格随你定**：`赛博朋克` `暗黑` `轻松日常` 这些标签自由组合，每章套用；还能自定义「AI 作家设定」（比如"参考烽火戏诸侯的文风"）
- 🧠 **越用越懂你**：你改过的地方、强调过的偏好，AI 会沉淀下来（可随时改、可清空），换次会话也不用重新交代——它记得你
- 🖼️ **顺手配图**：按场景描述生成封面或插图，文字+画面一起出（需后端 ComfyUI）
- 📚 **全部本地、永远属于你**：你的书、章节、角色都存在本地，导出备份随你带走

> 不知道第一句怎么起？直接问 AI："我想写一本 XX 题材的小说，但不知道从哪开始"——它会帮你出点子、定大纲、起人名。

<details>
<summary>🔧 技术细节</summary>

- **创作引导机制**：AI 在 system prompt 里被设定为「Novel Builder 的小说写作助手」+ 「专业的小说写作助手，只输出小说正文」（`agent_system_prompt.dart:31` / `chapter_write_executor.dart:549`）；工作原则第 4 条指令 AI 在用户说"新建一本小说"时直接 `create_novel`（`agent_system_prompt.dart:42-43`）
- `create_novel`：建空白书并自动切为当前工作小说（`agent_tools.dart:132`）
- `create_chapter`：position + instruction + `characterNames` + `tagNames` → 调 LLM 生成正文插入（`agent_tools.dart:240`）；前一章正文作为衔接上下文注入（`chapter_write_executor.dart:90`）
- `write_outline` / `update_outline` / `get_outline`：大纲 CRUD（`agent_tools.dart:625+`）
- 人物卡：`characters` 表（v35 `first_appearance_chapter` / v34 `avatar_media_id`），写章节按 `characterNames` 注入
- 风格：`prompt_tags` / `prompt_tag_categories` 表 + 用户自定义 `ai_writer_prompt`（SharedPreferences `ai_writer_prompt`，`chapter_write_executor.dart:400`）
- `agent_memory` 表（v27）：跨会话持久化写作偏好，`WritingScenario.getMemories()` 回灌；`patch_memory` 可增改——**可手改的经验笔记**，非自动学习你行为的推荐算法
- 生图：`create_images` / `create_image_to_video` → 后端 ComfyUI（`agent_tools.dart:838+`）
- 本地存储：`bookshelf` / `novel_chapters` / `chapter_cache` 表，`backup_service.dart` 可导出

</details>

<!-- ===== Task 5-6 段落占位 ===== -->
```

- [ ] **Step 2: 提交**

```bash
git add README.md
git commit -m "feat(readme): 新增「写」段（三步开始+陪写特性+agent_memory 诚实措辞）"
```

---

### Task 5: README「🧩 还能做这些」+「🎬 视频区」

**Files:**
- Modify: `README.md`「写」段后的占位注释

- [ ] **Step 1: 在「写」段后追加「还能做这些」+ 视频区**

将 README.md 中 `<!-- ===== Task 5-6 段落占位 ===== -->` 这一行替换为：

```markdown
## 🧩 还能做这些

除了读/改/写三大核心，还有些顺手就能用的能力：

| 能力 | 说明 |
|---|---|
| 👥 **角色卡 & 关系图** | 手动建/AI 帮你建角色卡（姓名/外貌/性格/背景），人物关系用力导向图可视化 |
| 🎨 **场景配图 & 动态图** | 按段落描述生成插图，或把静态图变成动态视频（需后端 ComfyUI） |
| 💬 **让 AI 扮演角色** | 在 Agent Chat 里说"扮演 XX 角色跟我聊"，AI 按角色设定和你对话 |
| 📔 **多书架分类** | 「我的收藏」「玄幻」「待看」随便分，一本书可属于多个书架 |
| 🌗 **阅读风主题** | 护眼纸张色 + 衬线字体，长时间看也不累；亮/暗/跟随系统三档 |
| 📤 **本地备份导出** | 书架、进度、章节、角色全在本地 SQLite，随时导出备份带走 |

<details>
<summary>🔧 技术细节</summary>

- 角色卡：`characters` 表 v35（`first_appearance_chapter`）+ `character_list/detail/edit_screen.dart`；AI 创建角色走 `create_character` / `update_character` 工具（`agent_tools.dart:481-537`）
- 关系图：`character_relationships` 表（v35 区间模型）+ `relationship_graph_screen.dart` + `flutter_force_directed_graph`
- 场景配图 & 动态图：`create_images`（文生图）+ `create_image_to_video`（图生视频，依赖后端 ComfyUI）+ `media_proxy.dart` 媒体代理 + `media_cache_screen.dart`
- AI 扮演角色：Agent Chat 调用 + 角色设定 prompt（由用户在角色卡里编辑）注入
- 多书架：`bookshelves` / `novel_bookshelves` 多对多表（v16）
- 主题：阅读风令牌 paper/ink/赭石/金，`app_colors.dart`
- 备份：`backup_service.dart` 导出本地 SQLite → 后端 `/api/backup/*`（4 端点）

</details>

## 🎬 正在录制介绍视频

第一次见这个 APP 长什么样？看视频比看文档更快。

📺 **B 站长视频正在录制中**，预计月底上线。  
想第一时间收到提醒？给项目点个 ⭐ 或 Watch 这个仓库就行。

> 录好后这里会替换成视频封面 + 链接。

<!-- ===== Task 6 占位 ===== -->
```

- [ ] **Step 2: 提交**

```bash
git add README.md
git commit -m "feat(readme): 新增「还能做这些」表格 + 「正在录制介绍视频」区"
```

---

### Task 6: README「🔧 面向开发者」（折叠）+ 文末 Star CTA

**Files:**
- Modify: `README.md` 视频区后的占位注释 + Task 1 占位注释

- [ ] **Step 1: 在视频区后追加「面向开发者」折叠区 + 文末 Star CTA；同时清理 Task 1 的占位注释**

将 README.md 中 `<!-- ===== Task 6 占位 ===== -->` 这一行替换为：

```markdown
## 🔧 面向开发者

<details>
<summary>点开看技术栈与构建</summary>

**技术栈**

- 前端：Flutter 3.0+ / Dart / Riverpod / SQLite (v39) / Material 3
- AI 层：OpenAI 兼容 LLM + Agent Chat（多 Subagent 协作）+ 端侧 PP-OCRv6 (onnxruntime)
- 章节：Headless WebView + 本地 JS 提取脚本（`site_scripts` 表）
- 后端（可选）：FastAPI + ComfyUI（文生图/图生视频）+ 备份/日志上报

**源码运行**

\`\`\`bash
git clone https://github.com/yunkst/novel_builder.git
cd novel_builder/novel_app
flutter pub get
flutter run
\`\`\`

> App 默认离线可用，本地书架/阅读/Agent Chat/角色卡均无需后端。后端只在需要 AI 生图/备份/日志时才启动。

**深入文档**

- [开发者指南](docs/developer-guide.md) · [部署指南](docs/deployment.md) · [前端模块](novel_app/CLAUDE.md) · [后端模块](backend/CLAUDE.md)

**贡献**

欢迎提 Issue / PR，详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

</details>

---

<div align="center">

**觉得这个 APP 有用？给个 ⭐ 支持一下独立开发 🙏**

</div>
```

- [ ] **Step 2: 清理 Task 1 的占位注释（已替换为正式内容）**

README.md 中应已无 `<!-- ===== Task 2-6 段落占位 -->` 这类注释（前面 5 个 task 已逐段替换）。如果还有残留，手动删除。

- [ ] **Step 3: README 全文渲染检查**

打开 README.md，从头到尾通读：
- Hero 段（三按钮可见、slogan 居中）
- 📖 读 / ✏️ 改 / 🖋️ 写 三段连贯，每段 5-7 条 bullets + 1 个折叠块
- 🧩 还能做这些（6 行表格）
- 🎬 正在录制介绍视频
- 🔧 面向开发者（默认折叠）
- 文末 Star CTA
- 许可证

如发现占位注释残留或顺序错乱，修复后重读。

- [ ] **Step 4: 提交**

```bash
git add README.md
git commit -m "feat(readme): 新增「面向开发者」折叠区 + 文末 Star 引导"
```

---

### Task 7: 落地页 docs-site/index.html 4 处微调

**Files:**
- Modify: `docs-site/index.html`（title / Hero H1 / Hero CTA / nav-links / footer 链接 — 共 5 处）

**Interfaces:**
- 已在 Task 1 完成 Hero 段 README 写作；本 task 让落地页与 README 同步

- [ ] **Step 1: 修改 `<title>`（第 7 行）**

旧：
```html
<title>Novel Builder · AI 原生小说阅读平台</title>
```

新：
```html
<title>随心阅读 · Novel Builder · AI 原生小说阅读平台</title>
```

- [ ] **Step 2: 修改 Hero H1 + 副名**

定位 Hero 区的 h1（搜索 `h1.title`，附近应有 `<em>` 强调字）。如果现有 H1 是 "Novel Builder"，改为：
```html
<h1 class="title">随心阅读 <em style="font-size:0.5em;color:var(--ink-soft);font-weight:600">Novel Builder</em></h1>
```

如果现有 H1 已经是 "Novel Builder"，改为：
```html
<h1 class="title">随心阅读</h1>
<p class="lead-subname">Novel Builder</p>
```

（具体写法以现有 HTML 结构为准，确保新增元素继承浅色阅读风）

- [ ] **Step 3: 在 Hero CTA 行追加 ⭐ Star 按钮**

定位 Hero 区的 `.cta-row`（含「下载 / 在线介绍」按钮的 div）。在最后一个按钮后追加：

```html
<a class="btn btn-gh" href="https://github.com/yunkst/novel_builder" target="_blank" rel="noopener" aria-label="GitHub Star">
  ⭐ Star
</a>
```

- [ ] **Step 4: 在顶栏 nav-links 追加 ⭐ Star 入口**

定位 `<div class="nav-links">` 内最末 `<a>` 后追加：
```html
<a href="https://github.com/yunkst/novel_builder" target="_blank" rel="noopener">⭐ Star</a>
```

- [ ] **Step 5: footer「使用指南」链接已修复**

commit `1505f8a` 已把 `docs/user-guide.md` 改为 `README.md`。Step 1 不再重复。

- [ ] **Step 6: 落地页本地预览**

用浏览器打开 `docs-site/index.html`，确认：
- title 显示三层主副名
- Hero H1 主名「随心阅读」可见
- Hero CTA 行 3 个按钮（下载/在线介绍/Star）并排
- 顶栏含 ⭐ Star 入口
- 浅色阅读风风格未变

- [ ] **Step 7: 提交**

```bash
git add docs-site/index.html
git commit -m "feat(landing): 同步应用名双名策略 + Hero 加 Star 按钮 + nav 加 Star"
```

---

### Task 8: 最终验收

**Files:** 无新增修改，纯验收

- [ ] **Step 1: 全局断链验证**

```bash
git grep -nE "user-guide\.md|APP功能介绍\.md|chapter-fetch-flow\.html|react-agent-web-extract\.html"
```

预期输出：仅 `docs/superpowers/specs/2026-07-28-readme-promotion-redesign-design.md` 命中（spec 内的引用说明），以及可能的 `docs/superpowers/plans/` 历史引用。**对外展示文档全部清零**。

- [ ] **Step 2: README 渲染检查**

把 README.md 推送到一个临时分支（如 `promotion-preview`），在 GitHub 上目视检查：
- Hero 段三按钮可点击
- 三段卖点 bullets 显示正常
- 折叠块可展开/收起
- 表格「还能做这些」6 行
- 视频区文案
- 面向开发者默认折叠
- 文末 Star CTA 居中

如有问题，针对性修复并 amend 对应 commit。

- [ ] **Step 3: 落地页本地检查**

浏览器打开 `docs-site/index.html`：
- title 三层主副名
- Hero H1 + 副名 + 3 按钮 + Star
- 顶栏 + footer 链接无误
- 浅色阅读风风格保持

- [ ] **Step 4: 与用户复审**

回到对话，向用户报告 6 个 commit（Task 1-6 README + Task 7 落地页 + 之前的 commit 1505f8a 清理），询问是否需要推送或进一步调整。