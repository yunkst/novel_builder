# Agent 创建 OCR 提取器 — 设计文档

- 日期：2026-07-15
- 状态：设计已确认，待写实现计划
- 相关：番茄 PUA 字体反爬解码 PoC（`fanqie-evidence/`、`novel_app/lib/poc/ocr_predictor.dart`，已验证 82.9% PUA 正确解码 / 99.8% 正文替换）

## 1. 背景与目标

Novel Builder 的章节内容提取依赖 `site_scripts` 表里的 JS 提取脚本，由 `WebViewExtractScenario`（LLM ReAct Agent）现场生成。当前提取器只能处理 DOM/innerText 提取，遇到**字体反爬站点**（如番茄小说：正文高频字被替换为 PUA 私用区码点 U+E000-F8FF，靠 `@font-face` 自定义字体渲染成真字，DOM `innerText` 是乱码）则失效。

PoC 已验证 PP-OCRv6 rec 模型能稳定识别孤立 PUA 单字图（在 Android 模拟器上复现 PC 的 82.9% 准确率，1:1 一致）。

**目标**：让 `WebViewExtractScenario` 具备"现场检测字体反爬 + 创建带 OCR 标记的提取器"的能力，运行时自动对正文中出现的 PUA 码点走 OCR 还原。

**非目标（YAGNI）**：
- 不做字体文件提取/传输（字体全程待在 WebView 内）
- 不做跨章节缓存表（每章独立 OCR，与字体变更彻底解耦）
- 不做 PP-OCRv6 det 模型（用 rec-only 单字图，绕过 det）
- 不做 iOS / Windows 实现（PoC 在 Android 跑通，其他平台待真要再做）
- 不做 LLM 兜底、整页截图 OCR
- 不做 OCR 提取器独立 UI 面板（复用 `site_script_panel`）

## 2. 决策记录（brainstorming 结论）

| 维度 | 决定 | 理由 |
|---|---|---|
| 触发场景 | 浏览器内现场生成（`WebViewExtractScenario`） | agent 能看到一手 DOM/字体，判断最准 |
| OCR 成本摊销 | 每章独立 OCR，不缓存 | 与字体变更彻底解耦，错误隔离在本章；接受每章 ~45-70s |
| OCR 图源 | WebView canvas 渲染单字 → toDataURL → Dart | WebView 已加载反爬字体，不重复劳动；字体不外传 |
| 反爬检测 | agent 自动检测（DOM 含大量 PUA / @font-face） | 冷启动也能工作 |
| 提取器模型 | 同一种提取器 + `ocr` 布尔标记 | 不新增工具，最小侵入 |
| 字体族获取 | agent 的 `chapter_content_js` 返回 `font_family` 字段 | 解决"contentEl 不通用"问题，系统 OCR-JS 保持通用 |
| save_script 验证集成 | 落库前在 save_script 内部强制试运行验证；按 script_type 分次保存（list/content 各一次）；OCR 对 list 和 content 都生效（list 还原 title 字段 PUA） | agent 无法盲写；失败返回诊断指导修 JS；分次保存避免双脚本混合 |

## 3. 架构总览

"OCR 提取器" = "普通提取器 + `ocr: true` 标记"。agent 现场检测到字体反爬时，生成的提取器带上 `ocr` 标记。运行时 `HeadlessWebViewContentService` 看到标记就走 OCR 后处理：对正文里出现的每个 PUA 码点，用 WebView canvas 渲染单字 → Dart `OcrPredictor` 识别 → 直接批量替换。

### 数据流

```
[Agent 现场，一次性]
  WebViewExtractScenario 看到 DOM 含 PUA 码点（U+E000-F8FF）
  → 判定字体反爬
  → save_script(domain, run_id, script_type=chapter_content, test_url, ocr=true)
  → 验证通过 -> 落库（site_scripts 写入 ocr 标记 + content 脚本）

[运行时，每章提取]
  1. HeadlessWebViewContentService 用 agent 的 JS 提取章节
     → 拿到 {title, content, font_family}（content 含 PUA，font_family 来自 agent 的 getComputedStyle）
  2. 扫描 content，找出本章出现的 PUA 码点（去重，~150-250 个）
  3. 对每个 PUA：
     WebView: canvas 渲染该 PUA（用 font_family 字体栈，已 await document.fonts.ready）→ toDataURL base64 → Dart
     OcrPredictor.recognizeImage(base64Png) → 真字
  4. 直接批量替换 content 里的 PUA → 还原正文（不写映射表，错误隔离在本章）
```

### 改动点清单

1. **数据层**：`site_scripts` 表加 `ocr INTEGER NOT NULL DEFAULT 0` 列 + v37 迁移（`url_pattern` 列保留但 save_script 不再写入）
2. **模型层**：`SiteScript` 模型加 `ocr` 字段
3. **agent 工具层**：`save_script` 工具**完全重写**——新参数（domain/run_id/script_type/test_url/ocr）+ 落库前强制试运行验证；`WebViewExtractScenario` prompt 加"提取器创建流程"工作原则
4. **Repository**：新增 `updateScriptPart(domain, scriptType, js, ocr)` 增量更新方法（不动 `upsertByDomain`）
5. **OCR 识别**：`OcrPredictor` 改造为"接收 base64 单字图识别"（删除字体加载逻辑）；新增 PUA 检测工具函数
6. **OCR 服务抽象**：新增 `OcrRestoreService.restorePuaInText(text, fontFamily)` 通用方法，content 还原和 list title 还原共用；save_script 验证和运行时钩子共用
7. **运行时钩子**：`HeadlessWebViewContentService` 加 content OCR 还原（内部调 `OcrRestoreService`）；`HeadlessWebViewChapterListService` 同样加 title OCR 还原；新增通用系统 OCR-JS（带 `{{CODEPOINT}}` / `{{FONT_FAMILY}}` 占位符）

## 4. 数据模型与 site_scripts 扩展

### 4.1 迁移（v36 → v37）

```sql
ALTER TABLE site_scripts ADD COLUMN ocr INTEGER NOT NULL DEFAULT 0;
```

- 类型 `INTEGER`，0/1 语义（SQLite 无原生 bool）
- 默认 0，所有现有提取器自动是非 OCR 模式，零破坏
- 位置：`lib/core/database/database_migrations.dart` 的 `_onUpgrade`（v37 分支）+ `_onCreate`（全新建库路径同步加该列）
- 参考 v36 加 `coverMediaId` 的范式

### 4.2 SiteScript 模型

`lib/models/site_script.dart` 加字段：

```dart
final bool ocr;              // 是否需要 OCR 后处理（字体反爬）
bool get needsOcr => ocr;    // 语义别名
```

- `fromMap`：`ocr: (map['ocr'] as int?) == 1`
- `toMap`：`'ocr': ocr ? 1 : 0`
- `copyWith`：加 `bool? ocr` 参数

### 4.3 SiteScriptRepository

`lib/repositories/site_script_repository.dart`：

- 保留现有 `upsertByDomain`（用于其它可能的入口），加可选 `bool ocr = false` 参数（默认 false，向后兼容现有调用）
- 新增 `updateScriptPart({required String domain, required String scriptType, required String scriptJs, required bool ocr})` 方法：
  - `scriptType` 为 `"chapter_list"` 或 `"chapter_content"`
  - 根据 type 决定更新 `chapter_list_js` 或 `chapter_content_js` 列
  - 同时更新 `ocr` 列（确保两次保存的 ocr 标记一致）
  - 若 domain 不存在 → 直接返回错误（不自动 create，避免半截提取器）
  - 更新后 verified 重置为 0（保持现有行为）
- `getByDomain` 的 SELECT 加 `ocr`，`fromMap` 自动解析
- 新增便利方法（可选）：`setOcr(String id, bool ocr)`

**verified 重置规则**：每次 `updateScriptPart` 调用都重置 `verified=0`（现有行为）。agent 完整存完 list + content 两个脚本后，依赖运行时 headless 提取成功或失败来更新 verified 标记。

**`url_pattern` 字段处理**：DB 列保留（不删列），但 `updateScriptPart` 不再写入该字段。后续若需要 url_pattern 匹配逻辑，再额外扩展。

**save_script 两次保存的协作**：agent 流程是
```
save_script(domain, run_id, chapter_list, test_url, ocr=false)  → 第一次，写入 chapter_list_js
save_script(domain, run_id, chapter_content, test_url, ocr=true) → 第二次，写入 chapter_content_js + ocr=1
```
第二次保存时，第一次的 chapter_list_js 必须保留——这就是 `updateScriptPart` 只更新部分列的原因。

### 4.4 不新增 pua_mapping 表

甲方案明确砍掉。每章独立 OCR，不缓存，不建映射表。

### 4.5 数据库版本同步

- 前端 SQLite：v36 → v37
- `lib/core/database/database_connection.dart` 的 `version` 改 37
- CLAUDE.md 的"数据库版本"段落同步更新

## 5. agent 工具扩展：save_script 完全重写

原 `save_script` 同时保存 list + content 两个脚本、不做任何验证。新版**完全重写**：按 script_type 分次保存，每次落库前强制试运行验证，失败返回诊断指导 agent 修 JS。

### 5.1 save_script 新 schema

```dart
static const _saveScriptTool = {
  'type': 'function',
  'function': {
    'name': 'save_script',
    'description': '保存提取脚本到本地数据库（按脚本类型分次保存，落库前强制试运行验证）。'
        '工作流程：headless WebView 打开 test_url -> 运行 run_id 指向的 JS -> '
        '校验结果结构 -> 若 ocr=true 走 OCR 还原 -> 全部通过才落库。'
        '验证失败时返回诊断信息指导你修改 JS，不落库。'
        '完整提取器需调用两次：一次 script_type=chapter_list，一次 script_type=chapter_content。',
    'parameters': {
      'type': 'object',
      'properties': {
        'domain': {
          'type': 'string',
          'description': '网站域名',
        },
        'run_id': {
          'type': 'string',
          'description': '脚本在 RunStore 中的 run_id（exec_xxx），从之前 execute_js 调用的 __meta.run_id 获取。'
              '必须是你已测试通过的脚本，save_script 会用它做落库前验证。',
        },
        'script_type': {
          'type': 'string',
          'enum': ['chapter_list', 'chapter_content'],
          'description': '保存的脚本类型。chapter_list 返回 {title, chapters:[{title,url}]}；'
              'chapter_content 返回 {title, content, font_family}（OCR 模式需 font_family）。',
        },
        'test_url': {
          'type': 'string',
          'description': '验证用页面 URL。chapter_list 用目录页 URL，chapter_content 用章节内容页 URL。'
              'save_script 会真实加载该 URL 跑 JS 做验证。',
        },
        'ocr': {
          'type': 'boolean',
          'description': '该站点是否需要 OCR 后处理（字体反爬）。'
              '判定依据：DOM 文本含大量 PUA 码点（U+E000-F8FF），'
              '或 @font-face 引用第三方 CDN 自定义字体绑定到正文/标题元素。'
              '对 chapter_content：还原 content 里的 PUA；对 chapter_list：还原 title 字段里的 PUA（小说名 + 章名）。'
              '同一站点的两次 save_script（list + content）必须传相同的 ocr 值。',
        },
      },
      'required': ['domain', 'run_id', 'script_type', 'test_url', 'ocr'],
    },
  },
};
```

**关键变化**：
- 删除旧参数：`list_run_id` / `content_run_id` / `chapter_list_js` / `chapter_content_js` / `url_pattern`
- 新增：`run_id`（统一）/ `script_type` / `test_url` / `ocr`
- 所有参数必填（含 `ocr`）--agent 必须显式表态

### 5.2 save_script executor 工作流程

```
save_script(args, ctx):
  1. 解析参数（domain, run_id, script_type, test_url, ocr）
  2. 从 RunStore 取 run_id 指向的 JS 脚本字符串
  3. HeadlessWebView 打开 test_url，等待加载完成（含 await document.fonts.ready）
  4. callAsyncJavaScript(js, URL 替换) → 拿到原始结果
  5. 结构校验（按 script_type）：
     - chapter_list: 必须是 {title, chapters: [{title, url}]}
       * chapters 非空
       * 每个 chapter 有非空 title 和 url
     - chapter_content: 必须是 {title, content, [font_family]}
       * content.length >= 50
       * content 不全是空白/占位文本
       * 若 ocr=true: font_family 必须非空
  6. 校验失败 → 返回诊断 JSON（不落库）：
     {success: false, reason, diagnostic, returned_sample, suggestion}
  7. 校验通过：
     a. ocr=false → updateScriptPart(domain, script_type, js, ocr=false) 落库，返回成功
     b. ocr=true → 走 OCR 验证：
        * 字体有效性探测：用 font_family canvas 渲染 2 个不同 PUA，字节级差异验证
        * OCR 还原：
          - chapter_content: 还原 content 里的 PUA
          - chapter_list: 还原 title + 每个 chapter.title 里的 PUA（URL 不动）
        * 检查 readable_ratio >= 0.85（CJK 占比）、decoded_ratio >= 0.8（PUA 识别成功率）
        * 失败 → 返回 OCR 诊断 JSON（不落库）
        * 成功 → updateScriptPart(domain, script_type, js, ocr=true) 落库
                  返回 {success: true, restored_sample: 前 200 字, ...}
```

**验证失败返回示例**（结构错）：
```json
{
  "success": false,
  "reason": "content_too_short",
  "diagnostic": "JS 返回的 content 长度仅 12 字符，可能选择器没匹配到正文元素",
  "returned_sample": "加载中...",
  "suggestion": "检查 .muye-reader-content 选择器是否正确，或等待页面加载完成再提取"
}
```

**验证失败返回示例**（OCR 失败）：
```json
{
  "success": false,
  "reason": "readable_ratio_below_threshold",
  "ocr_applied": true,
  "readable_ratio": 0.45,
  "decoded_ratio": 0.78,
  "diagnostic": "OCR 还原后 CJK 占比仅 45%，可能是 font_family 无效或 OCR 模型对该字体解码失败",
  "suggestion": "检查 chapter_content_js 是否正确返回 font_family（用 getComputedStyle(正文元素).fontFamily）"
}
```

**验证成功返回示例**：
```json
{
  "success": true,
  "domain": "fanqienovel.com",
  "script_type": "chapter_content",
  "ocr": true,
  "verified_saved": true,
  "ocr_applied": true,
  "decoded_ratio": 0.92,
  "readable_ratio": 0.96,
  "restored_sample": ""我……是谁？"轰隆--苍白的雷光闪过..."
}
```

### 5.3 ToolArgParser 辅助方法

`save_script` 用到 `requiredBool`（ocr 必填）。实现计划任务第一步：
- `grep -r "requiredBool\|optionalBool" lib/services/novel_agent/` 确认是否存在
- 不存在 -> 在 `tool_executor_helpers.dart` 新增（参考 `requireString` / `nullableString` 范式）

### 5.4 WebViewExtractScenario system prompt 加工作原则

`buildSystemPrompt()` 加"提取器创建流程"段落（替换原"字体反爬检测"段落）：

```
## 提取器创建流程（强制）

完整提取器需调用两次 save_script：一次 chapter_list，一次 chapter_content。
save_script 会在落库前强制试运行验证，失败返回诊断指导你修 JS。

### 流程

1. 用 execute_js 反复调试脚本，确认能拿到正确结构：
   - chapter_list 脚本返回 {title, chapters:[{title,url}]}
   - chapter_content 脚本返回 {title, content, font_family}
2. 调用 save_script(domain, run_id, script_type, test_url, ocr) 落库
3. save_script 返回 success=false -> 按 diagnostic/suggestion 修 JS，重新 execute_js 调试，再 save_script

### 字体反爬检测（ocr 判定）

若 DOM 文本含大量 PUA 私用区码点（U+E000-F8FF，表现为不可读的乱码方块），
且页面通过 @font-face 加载自定义字体绑定到正文/标题元素（典型如番茄小说），
这是字体反爬，ocr 应传 true。

OCR 模式下：
- chapter_content_js 必须额外返回 font_family（用 getComputedStyle(正文元素).fontFamily）
- content 保留原始 PUA 文本（不要在 JS 里尝试解码）
- 同一站点的两次 save_script（list + content）必须传相同的 ocr 值

不要在 JS 里做 PUA 到真字的替换（你拿不到字体映射），交给运行时 OCR。
```

### 5.5 agent 不新增工具

agent **不新增任何工具**--复用现有 `execute_js` / `save_script`（重写）/ `get_page_info` / `navigate_to`。`save_script` 的验证逻辑在 executor 内部，对 agent 体现为"调用即验证，失败给诊断"。

### 5.6 提取器返回协议

**chapter_content_js 返回**（OCR 模式需 font_family）：
```json
{ "title": "章节标题", "content": "含 PUA 的正文文本", "font_family": "反爬字体族名" }
```

**chapter_list_js 返回**（OCR 模式 title 可能含 PUA，由运行时 OCR 还原）：
```json
{
  "title": "小说名（可能含 PUA）",
  "chapters": [
    { "title": "章名（可能含 PUA）", "url": "章节URL（不含PUA）" }
  ]
}
```

agent 在 JS 里定位正文元素后，顺手 `getComputedStyle(el).fontFamily` 返回 font_family。站点特异性完全收敛在 agent 写的 JS 里，系统 OCR-JS 保持通用。
## 6. Headless 提取管线加 OCR 钩子

### 6.1 OcrRestoreService 抽象（content 和 list title 共用）

OCR 后处理逻辑从 `HeadlessWebViewContentService` 私有方法抽成独立 service，供三处共用：
- `HeadlessWebViewContentService` 运行时还原 content
- `HeadlessWebViewChapterListService` 运行时还原 title（小说名 + 章名）
- `save_script` executor 落库前验证

```dart
class OcrRestoreService {
  OcrRestoreService(this._ref, this._renderPua);

  final Ref _ref;
  /// 注入的"渲染单字"回调（由 WebView holder 提供，解耦 service 与具体 WebView 实例）
  final Future<String> Function(int codepoint, String fontFamily) _renderPua;

  /// 还原 text 里所有 PUA 码点（通用入口，content 和 list title 都调它）。
  /// 返回 (restoredText, decodedCount, totalPuaCount)。
  Future<OcrRestoreResult> restorePuaInText(String text, String? fontFamily) async {
    final puaCodepoints = <int>{};
    for (final r in text.runes) {
      if (_isPua(r)) puaCodepoints.add(r);
    }
    if (puaCodepoints.isEmpty) return OcrRestoreResult(text, 0, 0);

    final ocr = await _ref.read(ocrPredictorProvider.future);
    final puaToChar = <int, String>{};
    for (final cp in puaCodepoints) {
      try {
        final imageBase64 = await _renderPua(cp, fontFamily ?? '');
        final decoded = await ocr.recognizeImage(imageBase64);
        puaToChar[cp] = decoded;
      } catch (_) {
        puaToChar[cp] = '';  // 单字符失败，留 □
      }
    }

    final sb = StringBuffer();
    int decoded = 0;
    for (final r in text.runes) {
      if (_isPua(r)) {
        final d = puaToChar[r] ?? '';
        if (d.isNotEmpty) { sb.write(d); decoded++; }
        else { sb.write('□'); }
      } else {
        sb.writeCharCode(r);
      }
    }
    return OcrRestoreResult(sb.toString(), decoded, puaCodepoints.length);
  }

  /// 字体有效性探测：用 font_family 渲染 2 个不同 PUA，字节级差异验证。
  /// spike 验证：错误字体栈会渲染出相同占位框。
  Future<bool> verifyFontFamily(String fontFamily) async {
    if (fontFamily.isEmpty) return false;
    final a = await _renderPua(0xE3E9, fontFamily);
    final b = await _renderPua(0xE3EA, fontFamily);
    return a != b;
  }

  /// readable_ratio：CJK 字符占比（用于判定 OCR 还原后文本可读性）。
  double readableRatio(String text) {
    if (text.isEmpty) return 0;
    int cjk = 0, total = 0;
    for (final r in text.runes) {
      total++;
      if (r >= 0x4E00 && r <= 0x9FFF) cjk++;
    }
    return cjk / total;
  }
}

class OcrRestoreResult {
  final String text; final int decodedCount; final int totalPuaCount;
  OcrRestoreResult(this.text, this.decodedCount, this.totalPuaCount);
  double get decodedRatio => totalPuaCount == 0 ? 1.0 : decodedCount / totalPuaCount;
}

bool _isPua(int cp) =>
    (cp >= 0xE000 && cp <= 0xF8FF) ||
    (cp >= 0xF0000 && cp <= 0xFFFFD) ||
    (cp >= 0x100000 && cp <= 0x10FFFD);
```

**关键设计点**：
- `_renderPua` 是注入的回调--`OcrRestoreService` 不持有 WebView 实例，由调用方（service 或 save_script executor）提供"渲染单字"能力。这让 service 可被运行时钩子和验证工具复用，不耦合具体 WebView。
- `restorePuaInText` 是通用入口：content 走它，list 的 title 走它，save_script 验证也走它。
- `verifyFontFamily` + `readableRatio` 是验证专用方法，运行时钩子不调。
- 错误粒度单字符级：单 PUA 渲染/识别失败留 `□`，不中断整体。

### 6.2 fetchContent 运行时钩子（content 还原）

现有 `fetchContent`（`lib/services/headless_webview_content_service.dart`）流程末尾加一步：

```
fetchContent(url)
  -> getByDomain(host) -> SiteScript
  -> 无脚本 -> noScript
  -> 加载页面 -> callAsyncJavaScript(chapter_content_js) -> {title, content, font_family?}
  -> content.length < 50 -> 失败
  -> 【新增】script.needsOcr ? _ocrRestore.restorePuaInText(content, fontFamily) : content
  -> 返回 ChapterContentResult
```

OCR 后处理在 `fetchContent` 内部，对调用方完全透明。`_renderPua` 回调由 `HeadlessWebViewContentService` 提供（调系统内置 OCR-JS，见 §6.4）。

### 6.3 fetchChapterList 运行时钩子（title 还原）

`HeadlessWebViewChapterListService.fetchChapterList` 同样在 `script.needsOcr` 时对返回结构做 OCR 还原：

```
fetchChapterList(novelUrl)
  -> getByDomain(host) -> SiteScript
  -> 加载页面 -> callAsyncJavaScript(chapter_list_js) -> {title, chapters:[{title,url}]}
  -> 【新增】script.needsOcr:
       对顶层 title 调 restorePuaInText -> 还原小说名
       对每个 chapter.title 调 restorePuaInText -> 还原章名
       chapter.url 不动（URL 不含 PUA）
  -> 返回还原后的 {title, chapters}
```

list 的 font_family 怎么拿？--`chapter_list_js` 在 OCR 模式下也应返回 `font_family`（和 content 协议一致，agent 写 JS 时对目录页正文元素 getComputedStyle）。若漏返回，降级用 `document.body` 的 computed font。
### 6.3 系统内置 OCR-JS（通用）

```javascript
(async function() {
  await document.fonts.ready;  // 等字体加载完，避免竞态
  const cp = {{CODEPOINT}};
  const fontFamily = {{FONT_FAMILY}};   // 来自提取器返回
  const canvas = document.createElement('canvas');
  canvas.width = 120; canvas.height = 120;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#FFFFFF'; ctx.fillRect(0, 0, 120, 120);
  ctx.fillStyle = '#000000';
  ctx.font = '80px ' + fontFamily;   // 用探测到的字体栈（含反爬字体族名）
  ctx.textBaseline = 'middle'; ctx.textAlign = 'center';
  ctx.fillText(String.fromCodePoint(cp), 60, 60);
  return canvas.toDataURL('image/png').split(',')[1];  // base64，不带前缀
})()
```

**关键设计点**：
- `ctx.font = '80px ' + fontFamily` —— 必须显式指定含反爬字体族名的字体栈。spike 验证：`80px sans-serif` 时四个不同 PUA 渲染出完全相同的占位框（失败）；`80px <反爬字体族名>` 时渲染出不同字形（成功）。
- `await document.fonts.ready` —— 必须等字体加载完，否则 canvas 拿不到 glyph。
- **不出现任何具体站点选择器**——`{{CODEPOINT}}` 和 `{{FONT_FAMILY}}` 由 Dart 侧 replaceAll 注入。

### 6.4 OcrPredictor 改造

PoC 的 `OcrPredictor.recognizeGlyph(cp)` 内部做两件事：渲染（TextPainter + loadFontFromList）+ OCR。改造后**只做 OCR**：

```dart
class OcrPredictor {
  // 删除：family / fontSize / canvasSize / _render / 字体加载
  // 保留：_session / _vocab / load() / _preprocess / _ctcDecode

  /// 识别 WebView canvas 渲染好的单字图（base64 PNG）。
  Future<String> recognizeImage(String base64Png) async {
    final bytes = base64Decode(base64Png);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final (tensor, w) = await _preprocess(image);  // 复用 PoC 预处理
    final outputs = await _session!.run({'x': await OrtValue.fromList(tensor, [1, 3, 48, w])});
    // ... 复用 PoC CTC 解码
    return text;
  }
}
```

- 删除 `_render`（TextPainter 渲染）—— 渲染职责移交 WebView canvas
- 删除 `load()` 里的字体加载 —— 不再需要字体
- `recognizeGlyph(cp)` 改造为 `recognizeImage(base64Png)` —— 输入从码点变成图
- `_preprocess` / `_ctcDecode` 完全复用 PoC（已验证 82.9%）
- `recognizeImage` 内部**完整复用 `poc/ocr_predictor.dart` 现有的 `_preprocess` 和 `_ctcDecode` 私有方法**——只需把"如何拿到 ui.Image"从"TextPainter 渲染"改成"base64 → instantiateImageCodec"，其余 onnx 推理 + tensor 预处理 + CTC 解码逻辑完全照搬，不重写不重构
- 实现计划任务要明确：`_preprocess` / `_ctcDecode` 在 Phase 1 保留原签名，PoC 期间对外 API 仍在（`recognizeGlyph` 标 deprecated）；Phase 2 OCR 钩子接入时移除 deprecated API

### 6.5 ocrPredictorProvider 注册

`lib/core/providers/` 下新增：

```dart
final ocrPredictorProvider = FutureProvider<OcrPredictor>((ref) async {
  final predictor = OcrPredictor();
  await predictor.load();  // 加载 onnx 模型 + 字典（~1s，一次性）
  ref.onDispose(() => predictor.dispose());
  return predictor;
});
```

模型加载 lazy + cached，应用生命周期加载一次。`HeadlessWebViewContentService` 通过已注入的 `Ref` 拿到。

### 6.6 canvas 字体继承风险（已验证消除）

spike 在真实番茄章节（`fanqienovel.com/reader/7069991698582995470`）验证：
- `80px sans-serif`：U+E3E9/E3EA/E3EB/E3EC 四个不同 PUA 渲染出**完全相同**的占位框（失败）
- `80px <反爬字体族名>`：四个 PUA 渲染出**四个不同字形**（成功）
- `getComputedStyle(.muye-reader-content).fontFamily` 能拿到反爬字体族名 `DNMrHsV173Pd4pgy`

结论：canvas 不自动继承 `@font-face`，必须显式指定字体族名；通过 agent 返回 `font_family` 解决。风险已消除。

## 7. 错误处理（分层隔离）

| 错误层级 | 触发 | 处理 |
|---|---|---|
| OCR 整体失败 | `OcrRestoreService.restorePuaInText` 抛异常 | 调用方 try-catch 降级返回原始文本，不崩溃；logger.warn；UI 静默 |
| 单个 PUA 识别失败 | OcrPredictor 返回空或非 CJK | 该字符替换为 `□`，不影响其他字符；错误隔离在本字符 |
| agent 缺 font_family | content/list 脚本漏返回字段 | 降级用 `document.body` 的 computed font；warn；不打断 |
| 字体未加载竞态 | fonts.ready 超时 / 字体 404 | toDataURL 返回空白图 -> OCR 识别失败 -> 该字符 `□`；单字符级 |
| onnx 模型加载失败 | `OcrPredictor.load()` 抛异常 | FutureProvider error 状态；调用方降级返回原文；UI 透明 |
| save_script 验证失败 | 结构校验或 OCR 验证不通过 | 拒绝落库，返回诊断 JSON 指导 agent 修 JS（见 §5.2）|

## 8. 测试策略

### 8.1 单元测试（test/unit/）

| 测试 | 验证点 |
|---|---|
| `pua_codepoint_test.dart` | `_isPua` 覆盖 U+E000-F8FF / U+F0000-FFFFD / U+100000-10FFFD 三段、边界值、否定情况 |
| `ocr_predictor_test.dart` | `recognizeImage(base64)` 输入合法 PNG -> 输出字符串；输入空白图 -> 输出空/占位 |
| `ocr_restore_service_test.dart` | `restorePuaInText` 注入 mock `_renderPua` + mock predictor，验证替换逻辑、decoded_ratio/readable_ratio 计算；`verifyFontFamily` 字节级差异判定 |
| `site_script_repository_test.dart` | `updateScriptPart` 分次写 list/content 不互相覆盖；UPDATE 重置 verified=0；ocr 列读写 |
| `save_script_tool_test.dart` | executor 参数校验；结构校验失败返回诊断不落库；OCR 验证失败返回诊断不落库；验证通过才落库 |

### 8.2 集成测试（test/integration/）

| 测试 | 验证点 |
|---|---|
| `ocr_postprocess_test.dart` | 真实加载 OcrPredictor + 真实 WebView，输入含 PUA 的 content -> 还原结果不含 PUA |
| `headless_webview_content_service_test.dart` | `fetchContent` 路径：script.ocr=true 调 OcrRestoreService；ocr=false 不调 |
| `headless_webview_chapter_list_service_test.dart` | `fetchChapterList`：ocr=true 还原 title + chapter.title，url 不动 |

### 8.3 端到端验证（手工）

| 场景 | 验证 |
|---|---|
| 番茄真实章节 | 完整提取 -> OCR 还原 -> 与 biquge55 真值对比（>= 95% 字符合）|
| agent 现场生成 OCR 提取器 | `WebViewExtractScenario` 跑通：execute_js 探测 PUA -> save_script 两次（list+content）-> 落库前验证通过 |
| agent 验证失败闭环 | 故意写错 JS -> save_script 返回诊断 -> agent 修 JS 重试成功 |
| 普通站回归 | ocr=false 流程不变，速度不退化 |

### 8.4 回归保护

已有 23 个 agent 工具、`WebViewExtractScenario` 现有 happy path、两个 Headless service 现有流程都不能破。`save_script` 重写后，`list_run_id`/`content_run_id` 旧参数移除--所有引用 `save_script` 的地方（仅 `WebViewExtractScenario` 自身）同步更新。

## 9. 性能验收

| 指标 | 目标 | 测量方法 |
|---|---|---|
| 单章 OCR 还原时间 | < 90s（甲方案接受 ~45-70s，留 20s 余量给抖动）| 番茄 3-5 章真实章节测平均 |
| save_script 验证时间 | list 验证 < 15s；content 验证 < 90s（含 OCR）| 番茄目录页 + 章节页各测一次 |
| 内存峰值 | < 50MB | Android Profiler |
| APK 体积增量 | < 25MB（onnx 21MB + dict 4MB，已存在）| `flutter build apk --analyze-size` |

## 10. 可分阶段里程碑

**Phase 1：底层能力（无 UI）** -- 1-2 天
- v37 迁移（`site_scripts.ocr` 列）
- `SiteScript` 模型 + Repository（含新增 `updateScriptPart`）扩展
- `OcrPredictor` 改造（删除字体加载，新增 `recognizeImage`）
- `ocrPredictorProvider` 注册
- 验收：`flutter analyze` + 单元测试全绿

**Phase 2：OCR 服务抽象** -- 1 天
- 新建 `OcrRestoreService`（`restorePuaInText` / `verifyFontFamily` / `readableRatio`）
- 系统内置 OCR-JS 字符串（`{{CODEPOINT}}` / `{{FONT_FAMILY}}` 占位符）
- `HeadlessWebViewContentService` 加 content 还原钩子（调 OcrRestoreService）
- `HeadlessWebViewChapterListService` 加 title 还原钩子（调 OcrRestoreService）
- 错误隔离（try-catch 兜底返回原文）
- 验收：手动插 `ocr=true` script -> 加载番茄章节 -> content PUA 被还原；加载目录页 -> 章名 PUA 被还原

**Phase 3：save_script 重写 + agent 教学** -- 1 天
- `save_script` 新 schema（domain/run_id/script_type/test_url/ocr）
- `saveScript` executor 落库前验证流程（结构校验 + OCR 验证 + 诊断返回）
- `ToolArgParser.requiredBool`（若不存在则新增）
- `buildSystemPrompt` 加"提取器创建流程"工作原则
- 验收：手工跑 `WebViewExtractScenario` -> agent 现场生成 OCR 提取器（两次 save_script）；故意写错 JS 验证诊断闭环

**Phase 4：端到端验证** -- 0.5 天
- 真实番茄章节跑通（content + list 都还原）
- 性能 profile + 内存验证
- 与 biquge55 真值对比（>= 95% 字符合）
- 验收：3 章连续提取无报错，单章 < 90s

**Phase 5：清理与文档** -- 0.5 天
- CLAUDE.md 更新（数据库 v37、OCR 提取器说明）
- PoC 入口加注释说明"已被产品化路径替代"
- 验收：CLAUDE.md 同步、内存索引更新

**总计 ~4.5 天工作量**。

## 11. 关键文件清单

| 类别 | 路径 |
|---|---|
| 数据库迁移 | `lib/core/database/database_migrations.dart`（v37）|
| 数据库版本 | `lib/core/database/database_connection.dart`（version: 37）|
| 模型 | `lib/models/site_script.dart`（加 `ocr`）|
| Repository | `lib/repositories/site_script_repository.dart`（新增 `updateScriptPart` + `upsertByDomain` 加 `ocr`）|
| OCR 识别器 | `lib/poc/ocr_predictor.dart`（改造为 `recognizeImage`）|
| OCR 服务 | `lib/services/ocr_restore_service.dart`（**新建**：`restorePuaInText` / `verifyFontFamily` / `readableRatio`）|
| Provider | `lib/core/providers/`（新增 `ocrPredictorProvider` + `ocrRestoreServiceProvider`）|
| 运行时钩子 | `lib/services/headless_webview_content_service.dart`（content 还原）、`lib/services/headless_webview_chapter_list_service.dart`（title 还原）|
| agent 工具 | `lib/services/novel_agent/scenarios/webview_extract_scenario.dart`（save_script schema + executor 验证流程 + prompt）|
| 工具辅助 | `lib/services/novel_agent/tool_executor_helpers.dart`（`requiredBool`，若不存在）|
| 系统内置 JS | 常量字符串（建议独立 `lib/services/ocr_render_js.dart` 或 service 内）|
| 模型资源 | `assets/models/inference.onnx` + `assets/models/ppocrv6_dict.txt`（已存在）|