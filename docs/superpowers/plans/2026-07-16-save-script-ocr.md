# save_script 超时与 ocr 防滥用实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `save_script` 在慢加载/重脚本站点的超时余量更充足；同时让 `ocr=true` 参数只能用于真实存在 PUA 字体反爬特征的站点，避免 agent 误传；并在 Agent 对话框移除已废弃的快捷输入。

**Architecture:** 三处独立小改，全部位于 `novel_app` 模块：(1) 调整 `webview_extract_scenario.dart` 的两处超时常量与一处 `.timeout()`；(2) 在 `validateAndPersistScript` 的 ocr=true 分支加入 PUA 码点存在性校验 + 收紧 `_saveScriptTool` 的 schema description；(3) 删除 `agent_scenario.dart` 中 webviewExtract 场景唯一的快捷输入。TDD 流程：先扩展单测覆盖新行为（含原"全验证通过"用例需要改造为含 PUA 文本），再改实现，最后回归。

**Tech Stack:** Dart / Flutter；`mockito`（已用于 `save_script_tool_test.dart`）；`save_script` 静态入口 `WebViewExtractScenario.validateAndPersistScript`。

## Global Constraints

- 所有改动位于 `D:\my_space\novel_builder\novel_app\` 下，不改 backend。
- 不改 `_saveScript` 的方法签名或 `_saveScriptTool` schema 的 `properties` 形状，只允许修改 `description` 文案与 `required` 列表保持不变（`ocr` 仍 required boolean）。
- 不新增运行时依赖。
- 不拆 `_pageLoadTimeout` 这个常量（它本就是有意共享给 navigate_to / _ensureHeadlessPageLoaded / _waitControllerForUrl 的，超时延长受益范围故意放宽到三者）。
- 所有 commit 使用 chinese-commit-conventions 风格：`type(scope): 中文摘要`，Co-Authored-By Claude。
- 单测文件改动一律用 `flutter test` 跑：
  `cd D:\my_space\novel_builder\novel_app && flutter test test/unit/services/save_script_tool_test.dart`
- spec 设计文档路径：`docs/superpowers/specs/2026-07-16-save-script-ocr-design.md`（避免冲突引用）。

---

## File Structure

| 文件 | 性质 | 职责 |
|---|---|---|
| `novel_app/lib/services/novel_agent/scenarios/webview_extract_scenario.dart` | 修改 | 调整 `_pageLoadTimeout` 常量、`_saveScript` 内 `.timeout()` 与错误文案；`validateAndPersistScript` 加 PUA 存在性前置校验；`_saveScriptTool.ocr.description` 改硬性文案。 |
| `novel_app/lib/services/novel_agent/agent_scenario.dart` | 修改 | 删除 `ScenarioQuickPrompts._webviewExtract` 列表里唯一的快捷输入项。 |
| `novel_app/test/unit/services/save_script_tool_test.dart` | 修改 | 现有"全部验证通过"用例改为含 PUA 文本；新增 `ocr=true 但无 PUA` → `ocr_no_pua` 用例、PUA 在 list title 里识别用例、PUA 仅 ≥1 个即放行用例、ocr=false 路径不被新校验影响回归用例。 |

---

### Task 1: 删除 Agent 对话框的快捷输入「为这个网站生成提取脚本」

**Files:**
- Modify: `novel_app/lib/services/novel_agent/agent_scenario.dart:355-361`

**Interfaces:**
- Consumes: 无（叶节点，纯删除）。
- Produces: `ScenarioQuickPrompts._webviewExtract` 变为空列表；`forScenario(ScenarioIds.webviewExtract)` 返回空列表；UI 层 `if (quickPrompts.isNotEmpty)` 自动不渲染 chip 行。

- [ ] **Step 1: 删除 `_webviewExtract` 列表中唯一的快捷输入项**

把 `novel_app/lib/services/novel_agent/agent_scenario.dart` 第 355-361 行从：

```dart
static const _webviewExtract = <ScenarioQuickPrompt>[
  ScenarioQuickPrompt(
    label: '为这个网站生成提取脚本',
    text: '请为当前网站编写可复用的提取脚本：先用 get_page_info 探测页面结构，'
        '再生成目录提取脚本和内容提取脚本，测试通过后用 save_script 保存到本地数据库。',
  ),
];
```

改为：

```dart
static const _webviewExtract = <ScenarioQuickPrompt>[];
```

（保留 `_webviewExtract` 这个常量名、`<ScenarioQuickPrompt>[]` 类型注解、`forScenario` switch 分支不动 — 都是为了其它场景未来加快捷词时零改动。）

- [ ] **Step 2: 运行单测 + analyze**

```bash
cd D:\my_space\novel_builder\novel_app && flutter analyze lib/services/novel_agent/agent_scenario.dart
```

期望：无 diagnostics。

```bash
cd D:\my_space\novel_builder\novel_app && flutter test test/unit/widgets/agent_chat_dialog_draft_test.dart
```

期望：现有 chip 行渲染相关测试全过（它们不应依赖这一条具体 chip）。

- [ ] **Step 3: 提交**

```bash
cd D:\my_space\novel_builder && git add novel_app/lib/services/novel_agent/agent_scenario.dart && git commit -m "feat(agent): 移除 webviewExtract 快捷输入

为这个网站生成提取脚本快捷输入已不再推荐使用，删除该项后
chip 行自然消失（forScenario 返回空列表），不影响其他场景。"
```

---

### Task 2: 调整 save_script 三处超时（脚本验证 60→120s、页面加载 30→60s、文案同步）

**Files:**
- Modify: `novel_app/lib/services/novel_agent/scenarios/webview_extract_scenario.dart:505`（常量）
- Modify: `novel_app/lib/services/novel_agent/scenarios/webview_extract_scenario.dart:1202-1204`（`.timeout()`）
- Modify: `novel_app/lib/services/novel_agent/scenarios/webview_extract_scenario.dart:1245`（`test_timeout` 文案）

**Interfaces:**
- Consumes: 无（纯常数 + 字面量改动）。
- Produces: `_pageLoadTimeout` 由 30s 提升到 60s（影响 `_navigateTo` / `_ensureHeadlessPageLoaded` / `_waitControllerForUrl` 三处，硬超时门槛更宽容）；`_saveScript` 内 `callAsyncJavaScript(...).timeout(...)` 由 60s 提升到 120s；超时错误返回 JSON `message` 字段同步写为「120s」。

- [ ] **Step 1: 修改常量**

定位到 `novel_app/lib/services/novel_agent/scenarios/webview_extract_scenario.dart` 第 505 行：

```dart
static const _pageLoadTimeout = Duration(seconds: 30);
```

改为：

```dart
static const _pageLoadTimeout = Duration(seconds: 60);
```

- [ ] **Step 2: 修改脚本验证超时**

定位到 `_saveScript` 方法内的：

```dart
final result = await controller
    .callAsyncJavaScript(functionBody: functionBody)
    .timeout(const Duration(seconds: 60));
```

改为：

```dart
final result = await controller
    .callAsyncJavaScript(functionBody: functionBody)
    .timeout(const Duration(seconds: 120));
```

- [ ] **Step 3: 修改 `test_timeout` 错误文案**

定位到同一方法靠下方的 TimeoutException 处理分支：

```dart
return jsonEncode({
  'success': false,
  'reason': 'test_timeout',
  'message': '脚本在 test_url 上执行超时（60s）',
  'suggestion': '脚本可能卡在翻页/等待，检查 setTimeout 和翻页逻辑',
});
```

将 `message` 改为：

```dart
'message': '脚本在 test_url 上执行超时（120s）',
```

（`suggestion` 与 `reason` 不动。）

- [ ] **Step 4: 运行 analyze 与相关单测**

```bash
cd D:\my_space\novel_builder\novel_app && flutter analyze lib/services/novel_agent/scenarios/webview_extract_scenario.dart
```

期望：无新增 diagnostics（仅限本次改动文件）。

```bash
cd D:\my_space\novel_builder\novel_app && flutter test test/unit/services/save_script_tool_test.dart
```

期望：所有现存用例仍通过（TDD：本次任务不引入行为变化，只是把数值改大）。

```bash
cd D:\my_space\novel_builder\novel_app && flutter test test/unit/services/webview_extract_headless_test.dart
```

期望：所有现存用例仍通过。

- [ ] **Step 5: 提交**

```bash
cd D:\my_space\novel_builder && git add novel_app/lib/services/novel_agent/scenarios/webview_extract_scenario.dart && git commit -m "feat(agent): save_script 超时延长

- 脚本验证执行 60s → 120s（_saveScript 内 callAsyncJavaScript.timeout）
- 页面加载等待常量 _pageLoadTimeout 30s → 60s（顺带放宽 navigate_to）
- test_timeout 错误文案同步改为 120s
- OCR 单码点渲染 30s 不变"
```

---

### Task 3: ocr 防滥用 - 测试先行（先改测试，再改实现）

**Files:**
- Modify: `novel_app/test/unit/services/save_script_tool_test.dart`

**Interfaces:**
- Consumes: `WebViewExtractScenario.validateAndPersistScript`（已存在，签名不变）。
- Produces:
  - 新增三个测试用例断言：
    1. `ocr=true` 且文本无 PUA → 返回 `success=false, reason='ocr_no_pua'`，不调 `repo.updateScriptPart`，且**不会**调 `restoreService.verifyFontFamily`（提前拒绝，连模型都不进）。
    2. `ocr=true` 且 `chapter_list` 文本无 PUA（无论 content/title/章节名拼接）→ 同上拒绝。验证扫描范围覆盖 list 的 title + chapters[].title。
    3. `ocr=true` 且文本含 ≥1 个 PUA（但 PUA 占比远低于 50%）→ 放行进 OCR 验证流程，不被 ocr_no_pua 拦截。
  - **改造**现有「全部验证通过」用例：让 `contentResult()` 默认 content 包含 PUA 码点（否则会被新闸拒绝）。建议：把 `longContent` 追加一个 ``（PRIVATE USE AREA 的一个 PUA 码点），保证默认值下能通过。
  - 现有「ocr=true 字体无效」「ocr=true readable_ratio 不达标」用例**已被新前置校验吞掉**：因为它们的 content 不含 PUA，新加的校验会先拒。新位置预期返回 `reason='ocr_no_pua'` 而非原先的 `font_family_invalid` / `readable_ratio_below_threshold`。测试需要更新断言。
  - 现有「ocr=false 路径」用例不变，仍走原结构校验。
  - 现有「全部验证通过」用例：因 content 改成含 PUA，`goodRestore()` 默认行为返回 `OcrRestoreResult(text, text.length, 0)`（即未识别任何 PUA 码点）。这会让后续 `_validateOcr` 步骤走到 `restored.totalPuaCount == 0` 分支（已有逻辑：跳 decoded_ratio 检查），但 readableRatio 取决于返回内容里 CJK 占比。要让它通过，需要让 `restorePuaInText` 的 mock 行为把 PUA 替换成 CJK 字符，并返 readableRatio=1.0。

- [ ] **Step 1: 重写 `contentResult` 默认 content（含 PUA）**

把 `novel_app/test/unit/services/save_script_tool_test.dart` 第 31-46 行改为：

```dart
/// 72 字正文 + 1 个 PUA 码点（U+E000）。预生成以避免在 const default 参数中使用字符串乘法。
/// 注意：保留 PUA 码点用于满足 ocr 防滥用闸（ocr_no_pua），不替换。
const longContent = '正常正文文字正常正文文字正常正文文字正常正文文字'
    '正常正文文字正常正文文字正常正文文字正常正文文字'
    '正常正文文字正常正文文字正常正文文字正常正文文字'
    '\u{E000}';

/// 构造一个 chapter_content 用的合法 jsResult（含 content + font_family）
Map<String, dynamic> contentResult({
  String content = longContent,
  String fontFamily = 'GoodFont',
  String title = '第一章',
}) =>
    {
      'content': content,
      'title': title,
      'font_family': fontFamily,
    };
```

理由：现有 `longContent` 是纯 CJK，没有 PUA。直接加一个 PUA 码点让默认数据通过新校验。

- [ ] **Step 2: 升级 `goodRestore()` mock — 让 OCR 阶段放行**

定位到 `goodRestore()`（第 57-69 行附近），改为：

```dart
/// 构造一个验证通过的 OcrRestoreService mock
MockOcrRestoreService goodRestore() {
  final svc = MockOcrRestoreService();
  when(svc.verifyFontFamily(any)).thenAnswer((_) async => true);
  // restorePuaInText：把 PUA 替换为 CJK（模拟成功还原），可读率 1.0
  when(svc.restorePuaInText(any, any))
      .thenAnswer((inv) async {
    final t = inv.positionalArguments[0] as String;
    final cleaned = t.replaceAll('\u{E000}', '字'); // PUA 占位转成一个常用字
    return OcrRestoreResult(cleaned, cleaned.length, 1);
  });
  when(svc.readableRatio(any)).thenReturn(1.0);
  return svc;
}
```

理由：默认 `contentResult().content` 含 ``，进入 OCR 阶段后 `_validateOcr` 会先 `verifyFontFamily`（mock true），再 `restorePuaInText` 把 PUA 替换成「字」并标 `totalPuaCount=1, decodedCount=1`，最后 `readableRatio(cleaned)`=1.0（mock）→ 全通过，进入落库。

- [ ] **Step 3: 新增「ocr=true 但无 PUA → ocr_no_pua」用例**

在第一个 `group('validateAndPersistScript - OCR 验证', ...)`（第 161 行起）里新增用例：

```dart
test('ocr=true chapter_content 文本无 PUA → ocr_no_pua，不调 verifyFontFamily 也落库', () async {
  final repo = MockSiteScriptRepository();
  final svc = MockOcrRestoreService();
  // verifyFontFamily 故意抛错也不应被调
  when(svc.verifyFontFamily(any)).thenAnswer((_) async => false);

  final result = await WebViewExtractScenario.validateAndPersistScript(
    domain: 'a.com',
    scriptType: 'chapter_content',
    ocr: true,
    scriptJs: 'js',
    jsResult: contentResult(content: '没有PUA的纯正常正文没有PUA的纯正常正文没有PUA的纯正常正文没有PUA的纯正常正文没有PUA的纯正常正文没有PUA的纯正常正文没有PUA的纯正常正文没有PUA的纯正常正文'),
    repo: repo,
    restoreService: svc,
  );

  expect(result['success'], false);
  expect(result['reason'], 'ocr_no_pua');
  verifyNever(svc.verifyFontFamily(any));
  verifyNever(repo.updateScriptPart(
    domain: anyNamed('domain'),
    scriptType: anyNamed('scriptType'),
    scriptJs: anyNamed('scriptJs'),
    ocr: anyNamed('ocr'),
  ));
});

test('ocr=true chapter_list 所有 title 无 PUA → ocr_no_pua', () async {
  final repo = MockSiteScriptRepository();
  final result = await WebViewExtractScenario.validateAndPersistScript(
    domain: 'a.com',
    scriptType: 'chapter_list',
    ocr: true,
    scriptJs: 'js',
    jsResult: {
      'title': '书名',
      'chapters': [
        {'title': '第一章 起始', 'url': 'https://a.com/c1'},
        {'title': '第二章 发展', 'url': 'https://a.com/c2'},
      ],
    },
    repo: repo,
    restoreService: MockOcrRestoreService(),
  );

  expect(result['success'], false);
  expect(result['reason'], 'ocr_no_pua');
});

test('ocr=true chapter_list 标题含 1 个 PUA → 通过闸（不返回 ocr_no_pua）', () async {
  final repo = MockSiteScriptRepository();
  when(repo.updateScriptPart(
    domain: anyNamed('domain'),
    scriptType: anyNamed('scriptType'),
    scriptJs: anyNamed('scriptJs'),
    ocr: anyNamed('ocr'),
  )).thenAnswer((_) async => (success: true, id: 'site_list_pua', reason: null));

  final result = await WebViewExtractScenario.validateAndPersistScript(
    domain: 'a.com',
    scriptType: 'chapter_list',
    ocr: true,
    scriptJs: 'js',
    jsResult: {
      'title': '书名\u{E001}',
      'chapters': [
        {'title': '第一章 起始', 'url': 'https://a.com/c1'},
      ],
    },
    repo: repo,
    restoreService: goodRestore(),
  );

  expect(result['success'], true);
  expect(result['reason'], isNot('ocr_no_pua'));
});
```

- [ ] **Step 4: 更新已存在 OCR 失败用例的断言（被前置校验吞掉）**

定位第 161 行 group 下的两个用例「ocr=true 字体无效 → font_family_invalid」「ocr=true readable_ratio<0.85」：

它们的 `jsResult: contentResult()` 默认含 `\u{E000}`（已升级为 Step 1），因此新前置校验**不会**拦截，所以原断言仍正确——**不需改动**。

但有一个**关键回归点**：现测试文件里第 186-212 行的「readable_ratio 不达标」用例，断言 `restorePuaInText` 返回 `OcrRestoreResult('□□□□', 0, 4)`（4 个 PUA 码点全部 OCR 失败）。这条用例的 jsResult 用的是默认 `contentResult()`，内含 1 个 `\u{E000}`。新前置校验扫描 → 1 个 PUA ≥ 1 → **放行**，进入 OCR 阶段。原断言 reason='readable_ratio_below_threshold' 仍成立。

确认后**保留原有断言**。

- [ ] **Step 5: 运行测试，验证新用例失败（因为实现尚未加 ocr_no_pua）**

```bash
cd D:\my_space\novel_builder\novel_app && flutter test test/unit/services/save_script_tool_test.dart
```

期望：
- 「ocr=true chapter_content 文本无 PUA → ocr_no_pua」**FAIL**（reason 还是验证步骤里的 font_family_missing/其它，与 ocr_no_pua 不匹配）。
- 「ocr=true chapter_list 所有 title 无 PUA → ocr_no_pua」**FAIL**。
- 「ocr=true chapter_list 标题含 1 个 PUA → 通过闸」如实现尚未改，可能因 OCR 阶段 default `goodRestore()` mock 行为改变而 FAIL（这是允许的）。
- 原「全部验证通过」用例可能因 mock 行为调整 FAIL——OK。

- [ ] **Step 6: 提交**

```bash
cd D:\my_space\novel_builder && git add novel_app/test/unit/services/save_script_tool_test.dart && git commit -m "test(save_script): 加 ocr_no_pua 防滥用用例 + 调整 mock 通过 PUA 文本"
```

---

### Task 4: ocr 防滥用 - 实现 PUA 存在性前置校验

**Files:**
- Modify: `novel_app/lib/services/novel_agent/scenarios/webview_extract_scenario.dart:1336-1398`（`validateAndPersistScript` 中 ocr=true 分支）

**Interfaces:**
- Consumes: `WebViewExtractScenario.validateAndPersistScript` 入参（jsResult / scriptType / ocr）。
- Produces:
  - 新增私有静态方法 `_containsPrivateUseArea(String text) → bool`：用 `text.runes.any((r) => r >= 0xE000 && r <= 0xF8FF)` 扫描 ≥1 个 PUA 码点即返回 true。避免在源码中嵌入 PUA 字符或依赖 RegExp 的 Unicode 转义行为。
  - 新增私有静态方法 `_extractOcrTargetText(dynamic jsResult, String scriptType) → String`：按 script_type 拼出待扫描文本。
  - 在 `validateAndPersistScript` 的 `if (ocr) { ... }` 分支最前面（即 `if (restoreService == null) {...}` 之前）插入前置扫描：

    ```dart
    final targetText = _extractOcrTargetText(jsResult, scriptType);
    if (!_containsPrivateUseArea(targetText)) {
      return {
        'success': false,
        'reason': 'ocr_no_pua',
        'diagnostic': 'ocr=true 但脚本返回文本中未检测到 PUA 码点（U+E000-F8FF），不符合字体反爬判定条件',
        'suggestion': '请重新确认该站点是否真的有字体反爬。若确认无 PUA，调用 save_script 时传 ocr=false；若应该有 PUA 但检测失败，请检查脚本是否正确返回了带 PUA 的原始文本（不要在 JS 里替换）',
      };
    }
    ```

- [ ] **Step 1: 添加 `_containsPrivateUseArea` 与 `_extractOcrTargetText` 静态私有方法**

在 `webview_extract_scenario.dart` 的 `_sample` 静态方法（第 1525 行附近）**之前**新增：

```dart
/// 检查文本中是否含 PUA 私用区码点（U+E000..U+F8FF）。阈值 ≥1 即视为存在字体反爬特征。
///
/// 用 text.runes 逐码点比较，避免在源码字面量里嵌入 PUA 字符（OCR 测试不友好），
/// 也避免 RegExp 字符类对 Unicode 转义的解析行为差异。
static bool _containsPrivateUseArea(String text) {
  return text.runes.any((r) => r >= 0xE000 && r <= 0xF8FF);
}

/// 从 jsResult 提取 OCR 模式需要扫描 PUA 的目标文本。
///
/// - chapter_content: 直接取 content
/// - chapter_list: 拼接 title + 所有 chapters[].title（小说名 + 章名里也可能含 PUA）
static String _extractOcrTargetText(dynamic jsResult, String scriptType) {
  if (jsResult is! Map) return '';
  if (scriptType == 'chapter_content') {
    return ((jsResult['content'] as String?) ?? '');
  }
  final title = (jsResult['title'] as String?) ?? '';
  final chapters = jsResult['chapters'];
  final chapterTitles = chapters is List
      ? chapters
          .where((c) => c is Map)
          .map((c) => (c['title'] as String?) ?? '')
          .join(' ')
      : '';
  return '$title $chapterTitles';
}
```

- [ ] **Step 2: 在 `validateAndPersistScript` 的 ocr=true 分支插入前置校验**

定位到 `validateAndPersistScript` 内：

```dart
// 2. OCR 验证（ocr=true 时强制走）
if (ocr) {
  if (restoreService == null) {
    return {
      'success': false,
      'reason': 'restore_service_missing',
      'diagnostic': 'ocr=true 但 restoreService 未注入（实现错误）',
    };
  }
  final fontFamily = _extractFontFamily(jsResult);
  ...
}
```

把 `if (ocr) {` 这一段改为：

```dart
// 2. OCR 验证（ocr=true 时强制走）
if (ocr) {
  // 2.0 前置闸：ocr=true 必须见到 PUA 码点，否则直接拒绝（避免 agent 误传 true 走无谓 OCR 流程）
  final ocrTargetText = _extractOcrTargetText(jsResult, scriptType);
  if (!_containsPrivateUseArea(ocrTargetText)) {
    return {
      'success': false,
      'reason': 'ocr_no_pua',
      'ocr_applied': true,
      'diagnostic': 'ocr=true 但脚本返回文本中未检测到 PUA 码点（U+E000-F8FF），不符合字体反爬判定条件',
      'suggestion': '请重新确认该站点是否真的有字体反爬。若确认无 PUA，调用 save_script 时传 ocr=false；'
          '若应该有 PUA 但检测失败，请检查脚本是否正确返回了带 PUA 的原始文本（不要在 JS 里替换）',
    };
  }

  if (restoreService == null) {
    return {
      'success': false,
      'reason': 'restore_service_missing',
      'diagnostic': 'ocr=true 但 restoreService 未注入（实现错误）',
    };
  }
  final fontFamily = _extractFontFamily(jsResult);
  ...
}
```

- [ ] **Step 3: 收紧 `_saveScriptTool` 中 ocr 的 description**

定位到 `_saveScriptTool` 的 `'ocr': {...}` 块（第 1879-1887 行附近），把 `description` 字段从：

```dart
'description': '该站点是否需要 OCR 后处理（字体反爬）。'
    '判定依据：DOM 文本含大量 PUA 码点（U+E000-F8FF），'
    '或 @font-face 引用第三方 CDN 自定义字体绑定到正文/标题元素。'
    '对 chapter_content：还原 content 里的 PUA；'
    '对 chapter_list：还原 title 字段里的 PUA（小说名 + 章名）。'
    '同一站点的两次 save_script（list + content）必须传相同的 ocr 值。',
```

改为：

```dart
'description': '该站点是否需要 OCR 后处理（字体反爬）的硬性开关。\n'
    '传 true 的充要条件：脚本返回的文本中出现 PUA 私用区码点（U+E000–F8FF，页面表现是乱码方块）。\n'
    '若页面文本正常可读，必须传 false。\n'
    '传 true 时，save_script 会先扫描文本中是否存在 PUA 码点；若无则直接拒绝落库并返回 reason=ocr_no_pua。\n'
    '判定方法：在脚本探测阶段留意 execute_js 返回值里是否含 PUA 或乱码方块；可用 JS 码点扫描 console.log([...text].some(c => c >= 0xE000 && c <= 0xF8FF))。\n'
    '对 chapter_content：还原 content 里的 PUA；'
    '对 chapter_list：还原 title 字段里的 PUA（小说名 + 章名）。'
    '同一站点的两次 save_script（list + content）必须传相同的 ocr 值。',
```

- [ ] **Step 4: 运行测试**

```bash
cd D:\my_space\novel_builder\novel_app && flutter test test/unit/services/save_script_tool_test.dart
```

期望：所有用例通过。

- [ ] **Step 5: analyze + commit**

```bash
cd D:\my_space\novel_builder\novel_app && flutter analyze lib/services/novel_agent/scenarios/webview_extract_scenario.dart
```

期望：无新增 diagnostics。

```bash
cd D:\my_space\novel_builder && git add novel_app/lib/services/novel_agent/scenarios/webview_extract_scenario.dart && git commit -m "feat(agent): save_script 加 ocr_no_pua 前置校验避免误传

- 入口加 PUA 存在性扫描，零个 → 拒绝落库（reason=ocr_no_pua）
- 扫描范围 chapter_content/content 与 chapter_list/title+chapters[].title
- 收紧 _saveScriptTool.ocr.description：说明传 true 会被校验、给 JS 码点扫描示例"
```

---

### Task 5: 最终回归检查

**Files:**
- Modify: 无
- Read-only verify

**Interfaces:**
- Consumes: 上面四项任务的产出。
- Produces: 验证全部改动协同工作，不破坏其它测试。

- [ ] **Step 1: 运行 webview_extract 相关全部测试**

```bash
cd D:\my_space\novel_builder\novel_app && flutter test test/unit/services/save_script_tool_test.dart test/unit/services/webview_extract_headless_test.dart test/unit/services/webview_extract_prompt_test.dart test/unit/widgets/agent_chat_dialog_draft_test.dart
```

期望：全部通过。

- [ ] **Step 2: 运行 novel_agent 子树测试**

```bash
cd D:\my_space\novel_builder\novel_app && flutter test test/unit/services/novel_agent/
```

期望：全部通过（agent_loop_retry / subagent_runner / 等）。如有 ocr / save_script 以外相关的失败，回报后由 reviewer 判断。

- [ ] **Step 3: 全局 analyze**

```bash
cd D:\my_space\novel_builder\novel_app && flutter analyze
```

期望：无新增 diagnostics。

---

## Plan Self-Review

- **Spec coverage check**：
  - spec §1 超时调整 → Task 2 ✅
  - spec §2.1 PUA 存在性校验 → Task 4（实现）+ Task 3（测试先行）✅
  - spec §2.2 description 收紧 → Task 4 step 3 ✅
  - spec §3 删除快捷输入 → Task 1 ✅
  - spec 验收标准 1/2/3/4/5 → 都被对应 Task 覆盖，且 Task 5 做最终回归 ✅

- **Placeholder scan**：无 "TBD" / 无 "implement later" / 无 "Similar to Task N" / 每处代码改动都给了具体代码片段。

- **Type consistency**：
  - `validateAndPersistScript` 签名未变（OcrRestoreService? 仍是可选）；新增静态方法均为 `static` 私有，与同类风格一致。
  - Task 3 的 mock 改动（`OcrRestoreResult(cleaned, cleaned.length, 1)` 第二第三参）与 `OcrRestoreResult(this.text, this.decodedCount, this.totalPuaCount)` 完全匹配。

- **风险点**：
  - Task 3 中改 `longContent` 默认值（加 PUA 码点）会**反向影响**「font_family_missing」那个用例：原用例 jsResult 是 `{content: longContent, title: '第一章'}` 故意不写 font_family。新值下前置 PUA 校验会看到 1 个 PUA → 放行 → 进入 OCR 校验 → 因缺 font_family 仍返回 `font_family_missing`。原断言仍成立，不需要改。已在 Task 3 Step 4 注释。
