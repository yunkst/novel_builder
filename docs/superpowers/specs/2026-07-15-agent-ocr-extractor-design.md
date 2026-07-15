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

## 3. 架构总览

"OCR 提取器" = "普通提取器 + `ocr: true` 标记"。agent 现场检测到字体反爬时，生成的提取器带上 `ocr` 标记。运行时 `HeadlessWebViewContentService` 看到标记就走 OCR 后处理：对正文里出现的每个 PUA 码点，用 WebView canvas 渲染单字 → Dart `OcrPredictor` 识别 → 直接批量替换。

### 数据流

```
[Agent 现场，一次性]
  WebViewExtractScenario 看到 DOM 含 PUA 码点（U+E000-F8FF）
  → 判定字体反爬
  → save_script(domain, chapter_list_js, chapter_content_js, ocr=true)
  → site_scripts 写入（ocr 标记）

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

1. **数据层**：`site_scripts` 表加 `ocr INTEGER NOT NULL DEFAULT 0` 列 + v37 迁移
2. **模型层**：`SiteScript` 模型加 `ocr` 字段
3. **agent 工具层**：`save_script` 工具 schema 加 `ocr` 可选参数；`WebViewExtractScenario` prompt 加"字体反爬检测"工作原则
4. **OCR 识别**：`OcrPredictor` 改造为"接收 base64 单字图识别"（删除字体加载逻辑）；新增 PUA 检测工具函数
5. **运行时钩子**：`HeadlessWebViewContentService` 加 `_applyOcrPostprocess`；新增通用系统 OCR-JS（带 `{{CODEPOINT}}` / `{{FONT_FAMILY}}` 占位符）

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

- `upsertByDomain` 签名加 `bool ocr = false` 参数（默认 false，向后兼容现有调用）
- `INSERT` / `UPDATE` SQL 加 `ocr` 列
- `getByDomain` 的 SELECT 加 `ocr`，`fromMap` 自动解析
- 新增便利方法（可选）：`setOcr(String id, bool ocr)`

**verified 重置规则**：`upsertByDomain` 在 UPDATE 时已会重置 `verified=0`（现有行为）。加 `ocr` 字段后，**若 ocr 标记变更也应重置 verified**——因为 OCR 提取器的验证逻辑和普通提取器不同。

### 4.4 不新增 pua_mapping 表

甲方案明确砍掉。每章独立 OCR，不缓存，不建映射表。

### 4.5 数据库版本同步

- 前端 SQLite：v36 → v37
- `lib/core/database/database_connection.dart` 的 `version` 改 37
- CLAUDE.md 的"数据库版本"段落同步更新

## 5. agent 工具扩展

### 5.1 save_script schema 加 ocr 参数

`lib/services/novel_agent/scenarios/webview_extract_scenario.dart` 的 `save_script` schema 加可选参数：

```dart
'ocr': {
  'type': 'boolean',
  'description': '该站点是否需要 OCR 后处理（字体反爬）。'
      '判定依据：章节正文 DOM 文本含大量 PUA 码点（U+E000-F8FF），'
      '或 @font-face 引用第三方 CDN 的自定义字体绑定到正文元素。'
      '默认 false。',
}
```

description 里**明确写出判定依据**（PUA 码点范围 + @font-face 特征），这是 agent 自动检测的教学依据。`required` 不加 `ocr`（可选）。

### 5.2 save_script executor 扩展

`_saveScript` executor：

- `ToolArgParser.optionalBool('ocr')` 解析（若 `optionalBool` 方法不存在，在 `tool_executor_helpers.dart` 新增，参考 `nullableString` 范式）
- 未传时默认 false
- 透传给 `upsertByDomain(ocr: ocrFlag)`
- 返回 JSON 回显 `ocr` 字段，让 agent 知道自己设了什么

### 5.3 WebViewExtractScenario system prompt 加工作原则

`buildSystemPrompt()` 加"字体反爬检测"段落：

```
## 字体反爬检测（重要）

提取章节正文时，若发现 DOM 文本含大量 PUA 私用区码点
（U+E000-F8FF，表现为不可读的乱码方块），且页面通过 @font-face
加载自定义字体绑定到正文元素（典型如番茄小说），这是字体反爬。

判定为字体反爬时：
1. chapter_content_js 照常返回 {title, content, font_family}，
   content 保留原始 PUA 文本（不要在 JS 里尝试解码），
   font_family 用 getComputedStyle(正文元素).fontFamily 算出
2. 调用 save_script 时把 ocr 参数设为 true
3. 系统会在运行时自动对正文中出现的 PUA 码点走 OCR 还原，你无需处理解码

不要在 JS 里做 PUA→真字的替换（你拿不到字体映射），交给运行时 OCR。
```

### 5.4 agent 不新增工具

甲方案下 agent **不新增任何工具**——复用现有 `execute_js` / `save_script` / `get_page_info` / `navigate_to`。只改 schema（加参数）+ prompt（加原则）。

### 5.5 OCR 提取器的 chapter_content_js 返回协议扩展

OCR 模式（`ocr=true`）下，`chapter_content_js` 返回的 JSON 在普通提取器协议（`{title, content}`）基础上**多返回 `font_family`**：

```json
{
  "title": "章节标题",
  "content": "含 PUA 的正文文本",
  "font_family": "反爬字体族名（getComputedStyle 算出）"
}
```

agent 在 `chapter_content_js` 里定位正文元素后，顺手 `getComputedStyle(el).fontFamily` 返回。这解决了"不同站点 contentEl 选择器不同"问题——站点特异性完全收敛在 agent 写的 JS 里，系统 OCR-JS 保持通用。

## 6. Headless 提取管线加 OCR 钩子

### 6.1 fetchContent 流程改造

现有 `fetchContent`（`lib/services/headless_webview_content_service.dart:102-277`）流程末尾加一步：

```
fetchContent(url)
  → getByDomain(host) → SiteScript
  → 无脚本 → noScript
  → 加载页面 → callAsyncJavaScript(chapter_content_js) → {title, content, font_family?}
  → content.length < 50 → 失败
  → 【新增】script.needsOcr ? _applyOcrPostprocess(content, fontFamily) : content
  → 返回 ChapterContentResult
```

OCR 后处理在 `fetchContent` 内部，对调用方（`ReaderContentController` / `chapter_history_service` 等）**完全透明**——返回值不变，只是 content 已被还原。

### 6.2 _applyOcrPostprocess 实现

```dart
Future<String> _applyOcrPostprocess(String content, String? fontFamily) async {
  try {
    // 1. 扫描 content，提取本章出现的 PUA 码点（去重）
    final puaCodepoints = <int>{};
    for (final r in content.runes) {
      if (_isPua(r)) puaCodepoints.add(r);
    }
    if (puaCodepoints.isEmpty) return content;

    // 2. 对每个 PUA：WebView canvas 渲染 → OCR 识别
    final puaToChar = <int, String>{};  // 本章临时映射（不持久化）
    final ocr = await ref.read(ocrPredictorProvider.future);
    for (final cp in puaCodepoints) {
      final imageBase64 = await _renderPuaViaCanvas(cp, fontFamily);
      final decoded = await ocr.recognizeImage(imageBase64);
      puaToChar[cp] = decoded;  // 识别失败时 decoded=''，后续留 □
    }

    // 3. 批量替换 content 里的 PUA
    final sb = StringBuffer();
    for (final r in content.runes) {
      if (_isPua(r)) {
        final decoded = puaToChar[r];
        sb.write(decoded != null && decoded.isNotEmpty ? decoded : '□');
      } else {
        sb.writeCharCode(r);
      }
    }
    return sb.toString();
  } catch (e) {
    // OCR 整体失败 → 降级返回原文（不还原，不崩溃）
    logger?.warn('OCR postprocess failed: $e');
    return content;
  }
}

bool _isPua(int cp) =>
    (cp >= 0xE000 && cp <= 0xF8FF) ||
    (cp >= 0xF0000 && cp <= 0xFFFFD) ||
    (cp >= 0x100000 && cp <= 0x10FFFD);
```

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
| OCR 整体失败 | `_applyOcrPostprocess` 任何环节抛异常 | 降级返回原始 PUA 文本，不崩溃；logger.warn；UI 静默 |
| 单个 PUA 识别失败 | OcrPredictor 返回空或非 CJK | 该字符替换为 `□`，不影响其他字符；错误隔离在本字符 |
| agent 缺 font_family | `chapter_content_js` 漏返回字段 | 降级用 `document.body` 的 computed font；warn；不打断 |
| 字体未加载竞态 | fonts.ready 超时 / 字体 404 | toDataURL 返回空白图 → OCR 识别失败 → 该字符 `□`；单字符级 |
| onnx 模型加载失败 | `OcrPredictor.load()` 抛异常 | FutureProvider error 状态；`_applyOcrPostprocess` 降级返回原文；UI 透明 |

## 8. 测试策略

### 8.1 单元测试（test/unit/）

| 测试 | 验证点 |
|---|---|
| `pua_codepoint_test.dart` | `_isPua` 覆盖 U+E000-F8FF / U+F0000-FFFFD / U+100000-10FFFD 三段、边界值、否定情况（正常汉字、ASCII）|
| `ocr_predictor_test.dart` | `recognizeImage(base64)` 输入合法 PNG → 输出字符串；输入空白图 → 输出空/占位 |
| `site_script_repository_test.dart` | `upsertByDomain(ocr: true)` 写入并读回；UPDATE 时 ocr 变更触发 verified=0 |
| `save_script_tool_test.dart` | executor 接受 `ocr` 参数；缺省默认 false；OCR 标记写入 DB |

### 8.2 集成测试（test/integration/）

| 测试 | 验证点 |
|---|---|
| `ocr_postprocess_test.dart` | 真实加载 `OcrPredictor` + 真实 WebView，输入含 PUA 的 content → 还原结果不含 PUA 码点 |
| `headless_webview_content_service_test.dart` | `fetchContent` 路径：script.ocr=true 调用 `_applyOcrPostprocess`；script.ocr=false 不调用 |

### 8.3 端到端验证（手工）

| 场景 | 验证 |
|---|---|
| 番茄真实章节 | 完整提取 → OCR 还原 → 与 biquge55 真值对比（≥ 95% 字符合）|
| agent 现场生成 OCR 提取器 | `WebViewExtractScenario` 跑通：`execute_js` 探测 PUA → `save_script(ocr=true)` → DB 落库 |
| 普通站回归 | `ocr=false` 流程不变，速度不退化 |

### 8.4 回归保护

已有 23 个 agent 工具、`WebViewExtractScenario` 现有 prompt、`HeadlessWebViewContentService` 现有 happy path 都不能破。`save_script` 新增的 `ocr` 参数必须有默认值 false，所有现有调用点不传 `ocr` 行为不变。

## 9. 性能验收

| 指标 | 目标 | 测量方法 |
|---|---|---|
| 单章 OCR 还原时间 | < 90s（甲方案接受 ~45-70s，留 20s 余量给抖动）| 番茄 3-5 章真实章节测平均 |
| 内存峰值 | < 50MB | Android Profiler |
| APK 体积增量 | < 25MB（onnx 21MB + dict 4MB，已存在）| `flutter build apk --analyze-size` |

## 10. 可分阶段里程碑

**Phase 1：底层能力（无 UI）** — 1-2 天
- v37 迁移（`site_scripts.ocr` 列）
- `SiteScript` 模型 + Repository 扩展
- `OcrPredictor` 改造（删除字体加载，新增 `recognizeImage`）
- `ocrPredictorProvider` 注册
- 验收：`flutter analyze` + 单元测试全绿

**Phase 2：运行时钩子** — 1 天
- 系统内置 OCR-JS 字符串（`{{CODEPOINT}}` / `{{FONT_FAMILY}}` 占位符）
- `HeadlessWebViewContentService` 加 `_applyOcrPostprocess` + `_isPua` + `_renderPuaViaCanvas`
- 错误隔离（try-catch 兜底返回原文）
- 验收：手动插 `ocr=true` script → 加载番茄章节 → PUA 被还原

**Phase 3：agent 教学** — 0.5 天
- `save_script` schema 加 `ocr` 参数 + description 教学
- `saveScript` executor 加 `ocr` 解析与透传
- `buildSystemPrompt` 加"字体反爬检测"工作原则
- 验收：手工跑 `WebViewExtractScenario` → agent 现场生成带 `ocr=true` 的提取器

**Phase 4：端到端验证** — 0.5 天
- 真实番茄章节跑通
- 性能 profile + 内存验证
- 与 biquge55 真值对比（≥ 95% 字符合）
- 验收：3 章连续提取无报错，单章 < 90s

**Phase 5：清理与文档** — 0.5 天
- CLAUDE.md 更新（数据库 v37、OCR 提取器说明）
- PoC 入口加注释说明"已被产品化路径替代"
- 验收：CLAUDE.md 同步、内存索引更新

**总计 ~4 天工作量**。

## 11. 关键文件清单

| 类别 | 路径 |
|---|---|
| 数据库迁移 | `lib/core/database/database_migrations.dart`（v37）|
| 数据库版本 | `lib/core/database/database_connection.dart`（version: 37）|
| 模型 | `lib/models/site_script.dart`（加 `ocr`）|
| Repository | `lib/repositories/site_script_repository.dart`（`upsertByDomain` 加 `ocr`）|
| OCR 识别器 | `lib/poc/ocr_predictor.dart`（改造为 `recognizeImage`）|
| Provider | `lib/core/providers/`（新增 `ocrPredictorProvider`）|
| 运行时钩子 | `lib/services/headless_webview_content_service.dart`（`_applyOcrPostprocess`）|
| agent 工具 | `lib/services/novel_agent/scenarios/webview_extract_scenario.dart`（`save_script` schema + executor + prompt）|
| 工具辅助 | `lib/services/novel_agent/tool_executor_helpers.dart`（`optionalBool`，若不存在）|
| 系统内置 JS | 常量字符串（位置待定，建议 `headless_webview_content_service.dart` 内或独立 `lib/services/ocr_render_js.dart`）|
| 模型资源 | `assets/models/inference.onnx` + `assets/models/ppocrv6_dict.txt`（已存在）|
