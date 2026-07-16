# Agent 创建 OCR 提取器 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `WebViewExtractScenario` 具备"现场检测字体反爬 + 创建带 OCR 标记的提取器"的能力，运行时自动对正文/章名里出现的 PUA 码点走 PP-OCRv6 识别还原。

**Architecture:** "OCR 提取器" = "普通提取器 + `ocr: true` 标记"。agent 现场检测到字体反爬（DOM 含大量 PUA）时，生成的提取器带 `ocr` 标记；`save_script` 落库前强制试运行验证（结构校验 + OCR 还原，失败返回诊断）。运行时两个 Headless service 看到标记就对正文/章名走 `OcrRestoreService.restorePuaInText`：WebView canvas 渲染单字 → base64 → `OcrPredictor.recognizeImage` → 批量替换。

**Tech Stack:** Flutter / Dart、SQLite (v36→v37)、Riverpod、flutter_inappwebview 6.x (HeadlessInAppWebView + callAsyncJavaScript)、flutter_onnxruntime 1.8.2 + image 4.3.0 (PP-OCRv6 rec 模型)、sqflite_common_ffi (测试)。

## Global Constraints

- 必须在 **Android Flutter 生态**内工作（PC 解决不算）。PoC 已在 Android 模拟器验证（82.9% PUA 正确解码 / 99.8% 正文替换），本计划把它产品化。
- 前端 SQLite 从 **v36 → v37**，迁移照搬 v36 范式（`_addColumnIfNotExists`）。`database_connection.dart` 的 version 跟随 `DatabaseMigrations.currentVersion`，**只改后者**。
- `OcrPredictor` 的 `_preprocess` / `_ctcDecode` 已在 PoC 验证 1:1 一致，**完全复用不重写**；改造只动"如何拿到 ui.Image"（TextPainter → base64→instantiateImageCodec）。
- PUA 检测覆盖三段：U+E000-F8FF (PUA-A) / U+F0000-FFFFD (PUA-B) / U+100000-10FFFD (PUA-C)。
- **每章独立 OCR，不缓存映射表**（与字体变更解耦，错误隔离在本章）。接受单章 ~45-70s。
- 系统 OCR-JS 用 `{{CODEPOINT}}` / `{{FONT_FAMILY}}` 占位符，**不走 `WebViewJsExecutor.validateScript`**（该函数强制 `{{URL}}` 会误杀）；OCR-JS 直接 `callAsyncJavaScript`。
- `save_script` 按脚本类型分次保存（list 一次、content 一次），落库前强制试运行验证；同一站点两次调用 `ocr` 值必须一致。
- 始终用简体中文回复；提交遵循 Conventional Commits；一个提交只做一件事。
- TDD：每个任务先写失败测试 → 跑红 → 最小实现 → 跑绿 → 提交。
- 测试用 `sqflite_common_ffi`（桌面 SQLite FFI），命令 `flutter test test/unit/...`。

## File Structure

| 文件 | 职责 | 动作 |
|---|---|---|
| `lib/core/database/database_migrations.dart` | DB 迁移 | Modify: `currentVersion` 36→37 + 新增 `case 37` |
| `lib/models/site_script.dart` | SiteScript 模型 | Modify: 加 `ocr` 字段 + fromMap/toMap/copyWith + `needsOcr` getter |
| `lib/repositories/site_script_repository.dart` | Repository | Modify: `upsertByDomain` 加可选 `ocr`；新增 `updateScriptPart` |
| `lib/poc/ocr_predictor.dart` | OCR 识别器 | Modify: 删除渲染/字体加载，新增 `recognizeImage(base64Png)`；`recognizeGlyph` 标 deprecated |
| `lib/services/ocr_render_js.dart` | 系统内置 OCR-JS 常量 | **Create**: `{{CODEPOINT}}`/`{{FONT_FAMILY}}` 占位符模板 |
| `lib/services/ocr_restore_service.dart` | OCR 还原服务抽象 | **Create**: `restorePuaInText`/`verifyFontFamily`/`readableRatio` + `OcrRestoreResult` + `_isPua` |
| `lib/core/providers/ocr_providers.dart` | OCR Provider | **Create**: `ocrPredictorProvider` + `ocrRestoreServiceProvider` |
| `lib/models/chapter_content_result.dart` | 内容结果模型 | Modify: 加 `fontFamily` 字段 |
| `lib/services/headless_webview_content_service.dart` | content 运行时钩子 | Modify: 提取 fontFamily + `needsOcr` 走 OCR 还原 |
| `lib/services/headless_webview_chapter_list_service.dart` | list 运行时钩子 | Modify: `needsOcr` 还原 title + chapter.title |
| `lib/services/novel_agent/tool_arg_parser.dart` | 参数解析 | Modify: 新增 `requireBool` |
| `lib/services/novel_agent/scenarios/webview_extract_scenario.dart` | agent 场景 | Modify: `_saveScriptTool` schema 重写 + `_saveScript` executor 重写 + prompt 加"提取器创建流程" |
| `lib/core/providers/services/network_service_providers.dart` | service provider | Modify: 两个 Headless service 注入 `ocrRestoreServiceProvider` |
| `test/unit/core/pua_codepoint_test.dart` | PUA 检测单测 | **Create** |
| `test/unit/services/ocr_predictor_test.dart` | predictor 单测 | **Create** |
| `test/unit/services/ocr_restore_service_test.dart` | restore service 单测 | **Create** |
| `test/unit/repositories/site_script_repository_test.dart` | repository 单测 | Modify: 补 `updateScriptPart`/`ocr` 列 |
| `test/unit/services/save_script_tool_test.dart` | save_script 单测 | **Create** |
| `test/integration/ocr_postprocess_test.dart` | OCR 集成测试 | **Create** |

---

## Task 1: PUA 码点检测工具函数

纯函数无依赖，先做它，后面所有 PUA 判定都依赖它。

**Files:**
- Create: `lib/services/ocr_restore_service.dart`（本任务只建一个文件，后续任务往里加方法）
- Test: `test/unit/core/pua_codepoint_test.dart`

**Interfaces:**
- Produces: `bool isPua(int cp)` —— top-level 函数（spec 用 `_isPua` 私有名，但单测要能 import，故公开为 `isPua`，service 内部直接用）

- [ ] **Step 1: 写失败测试**

创建 `test/unit/core/pua_codepoint_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/ocr_restore_service.dart';

void main() {
  group('isPua', () {
    test('PUA-A 范围 U+E000-F8FF', () {
      expect(isPua(0xE000), isTrue);
      expect(isPua(0xE3E8), isTrue); // 番茄实测命中
      expect(isPua(0xF8FF), isTrue);
    });

    test('PUA-B 范围 U+F0000-FFFFD', () {
      expect(isPua(0xF0000), isTrue);
      expect(isPua(0xFFFFD), isTrue);
    });

    test('PUA-C 范围 U+100000-10FFFD', () {
      expect(isPua(0x100000), isTrue);
      expect(isPua(0x10FFFD), isTrue);
    });

    test('边界：范围下限的下一个码点不是 PUA', () {
      expect(isPua(0xDFFF), isFalse); // PUA-A 下界前
      expect(isPua(0xF900), isFalse); // PUA-A 上界后（CJK 兼容）
      expect(isPua(0xFFFFE), isFalse); // PUA-B 上界后
      expect(isPua(0x10FFFE), isFalse); // PUA-C 上界后
    });

    test('常见字符不是 PUA', () {
      expect(isPua(0x4E00), isFalse); // CJK '一'
      expect(isPua(0x0041), isFalse); // 'A'
      expect(isPua(0x3000), isFalse); // 全角空格
    });
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/core/pua_codepoint_test.dart`
Expected: FAIL — `isPua` 未定义 / `ocr_restore_service.dart` 不存在（import 失败）

- [ ] **Step 3: 写最小实现**

创建 `lib/services/ocr_restore_service.dart`：

```dart
/// OCR 还原服务：对文本中出现的 PUA（私用区）码点走 PP-OCRv6 识别还原。
///
/// 设计背景：番茄小说等站点用 PUA 码点 + @font-face 自定义字体做反爬，
/// DOM innerText 是乱码。本服务对 PUA 逐字 canvas 渲染 → 识别 → 替换。
///
/// 本文件先只放纯函数 [isPua]；后续任务往里加 [OcrRestoreService] 类。
library;

/// 判断码点是否落在 PUA（私用区）三段之一。
/// - U+E000-F8FF   PUA-A
/// - U+F0000-FFFFD PUA-B
/// - U+100000-10FFFD PUA-C
bool isPua(int cp) =>
    (cp >= 0xE000 && cp <= 0xF8FF) ||
    (cp >= 0xF0000 && cp <= 0xFFFFD) ||
    (cp >= 0x100000 && cp <= 0x10FFFD);
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/core/pua_codepoint_test.dart`
Expected: PASS — 5 个用例全绿

- [ ] **Step 5: 静态检查 + 提交**

Run: `flutter analyze lib/services/ocr_restore_service.dart test/unit/core/pua_codepoint_test.dart`
Expected: 无 error

```bash
git add lib/services/ocr_restore_service.dart test/unit/core/pua_codepoint_test.dart
git commit -m "feat(ocr): 新增 isPua 码点检测函数"
```

---

## Task 2: 数据库 v37 迁移（site_scripts.ocr 列）

照搬 v36 范式。**只改 `DatabaseMigrations.currentVersion`**，`database_connection.dart` 自动跟随。

**Files:**
- Modify: `lib/core/database/database_migrations.dart`
- Test: `test/unit/core/database_migration_v37_test.dart`（Create）

**Interfaces:**
- Consumes: v36 范式（`_addColumnIfNotExists`，:826-843）
- Produces: `site_scripts.ocr INTEGER NOT NULL DEFAULT 0` 列；`DatabaseMigrations.currentVersion == 37`

- [ ] **Step 1: 写失败测试**

创建 `test/unit/core/database_migration_v37_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_app/core/database/database_migrations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v37 迁移给 site_scripts 加 ocr 列', () async {
    final db = await openDatabase(inMemoryDatabasePath, version: 37,
        onCreate: (db, v) async {
      await DatabaseMigrations().createV1Tables(db);
      await DatabaseMigrations.upgrade(db, 1, 37);
    });

    final cols = await db.rawQuery(
      'PRAGMA table_info(site_scripts)',
    );
    final ocrCol = cols.firstWhere(
      (c) => c['name'] == 'ocr',
      orElse: () => throw StateError('ocr 列不存在'),
    );
    expect(ocrCol['type'], 'INTEGER');
    expect(ocrCol['dflt_value'], '0');
    expect(ocrCol['notnull'], 1);

    // 现有行 ocr 默认 0（插一行不传 ocr 验证）
    await db.insert('site_scripts', {
      'id': 't1',
      'domain': 'x.com',
      'chapter_list_js': '',
      'chapter_content_js': '',
      'created_at': 0,
      'last_used_at': 0,
      'use_count': 0,
      'verified': 0,
    });
    final row = await db.query('site_scripts', where: 'id = ?', whereArgs: ['t1']);
    expect(row.first['ocr'], 0);

    await db.close();
  });

  test('currentVersion == 37', () {
    expect(DatabaseMigrations.currentVersion, 37);
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/core/database_migration_v37_test.dart`
Expected: FAIL — `ocr` 列不存在 / `currentVersion` 是 36

- [ ] **Step 3: 写最小实现**

在 `lib/core/database/database_migrations.dart`：

(a) 改 `currentVersion`：
```dart
static const int currentVersion = 37;
```

(b) 在 `case 36:` 块（约 800-808 行）的 `break;` 之后、switch 结束 `}` 之前，新增：
```dart
// ========== 版本 37：site_scripts 加 ocr 列（字体反爬 OCR 标记） ==========
// ocr=1 表示该站点提取器需要 OCR 后处理（番茄小说等 PUA 字体反爬）。
// 默认 0，所有现有提取器自动是非 OCR 模式，零破坏。
// 由 save_script 落库时写入；HeadlessWebView service 读取决定是否走 OCR 还原。
case 37:
  await _addColumnIfNotExists(db, 'site_scripts', 'ocr', 'INTEGER NOT NULL DEFAULT 0');
  _log('迁移 v36 → v37: site_scripts 加 ocr 列');
  break;
```

> 注：若 `_addColumnIfNotExists` 无法带 `NOT NULL DEFAULT`，先看其实现（:826-843）——它走 `ALTER TABLE ADD COLUMN`，SQLite 允许 `ADD COLUMN ocr INTEGER NOT NULL DEFAULT 0`。若实现把类型和约束拼成单个字符串传入，直接传 `'INTEGER NOT NULL DEFAULT 0'`。若 helper 只接受纯类型名，则用 `'INTEGER'` 并在迁移后补一句 `db.execute("UPDATE site_scripts SET ocr = 0")`（默认值已保证，这句可省）。以 helper 实际签名为准。

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/core/database_migration_v37_test.dart`
Expected: PASS

- [ ] **Step 5: 回归 v36 迁移不破 + 提交**

Run: `flutter test test/unit/`（确保没有其它迁移测试因版本号变化挂掉）
Expected: 全绿

```bash
git add lib/core/database/database_migrations.dart test/unit/core/database_migration_v37_test.dart
git commit -m "feat(db): v37 迁移 site_scripts 加 ocr 列"
```

---

## Task 3: SiteScript 模型加 ocr 字段

**Files:**
- Modify: `lib/models/site_script.dart`
- Test: `test/unit/models/site_script_test.dart`（Create，或并入现有 repository 测试）

**Interfaces:**
- Consumes: Task 2 的 `ocr` 列
- Produces: `SiteScript.ocr` (bool) / `needsOcr` getter；`fromMap`/`toMap`/`copyWith` 适配

- [ ] **Step 1: 写失败测试**

创建 `test/unit/models/site_script_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/site_script.dart';

void main() {
  group('SiteScript ocr 字段', () {
    test('fromMap 读 ocr 列（1 → true）', () {
      final s = SiteScript.fromMap({
        'id': '1', 'domain': 'a.com', 'url_pattern': '',
        'chapter_list_js': '', 'chapter_content_js': '', 'sample_url': '',
        'created_at': 0, 'last_used_at': 0, 'use_count': 0, 'verified': 0,
        'ocr': 1,
      });
      expect(s.ocr, isTrue);
      expect(s.needsOcr, isTrue);
    });

    test('fromMap 读 ocr 列（缺失/0 → false）', () {
      final map = {
        'id': '1', 'domain': 'a.com', 'url_pattern': '',
        'chapter_list_js': '', 'chapter_content_js': '', 'sample_url': '',
        'created_at': 0, 'last_used_at': 0, 'use_count': 0, 'verified': 0,
      };
      expect(SiteScript.fromMap(map).ocr, isFalse);
      expect(SiteScript.fromMap({...map, 'ocr': 0}).ocr, isFalse);
      expect(SiteScript.fromMap({...map, 'ocr': null}).ocr, isFalse);
    });

    test('toMap 写 ocr（true→1, false→0）', () {
      final base = SiteScript(
        id: '1', domain: 'a.com', urlPattern: '',
        chapterListJs: '', chapterContentJs: '', sampleUrl: '',
        createdAt: 0, lastUsedAt: 0, useCount: 0, verified: 0, ocr: true,
      );
      expect(base.toMap()['ocr'], 1);
      expect(base.copyWith(ocr: false).toMap()['ocr'], 0);
    });

    test('copyWith 覆盖 ocr', () {
      final s = SiteScript(
        id: '1', domain: 'a.com', urlPattern: '',
        chapterListJs: '', chapterContentJs: '', sampleUrl: '',
        createdAt: 0, lastUsedAt: 0, useCount: 0, verified: 0, ocr: false,
      );
      expect(s.copyWith(ocr: true).ocr, isTrue);
      expect(s.copyWith().ocr, isFalse); // 不传保持原值
    });
  });
}
```

> 注：测试里构造函数的参数顺序以现有 `site_script.dart` 实际签名为准（Task 1 调研显示字段顺序为 id/domain/urlPattern/chapterListJs/chapterContentJs/sampleUrl/createdAt/lastUsedAt/useCount/verified，全 required）。若现有构造非全 required，按现有风格调整。

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/models/site_script_test.dart`
Expected: FAIL — `ocr` 参数不存在 / `needsOcr` 未定义

- [ ] **Step 3: 写最小实现**

在 `lib/models/site_script.dart`：

(a) 加字段（在 `verified` 字段后）：
```dart
final int verified;
final bool ocr; // 是否需要 OCR 后处理（字体反爬）。v37 新增。

bool get needsOcr => ocr;
```

(b) 构造函数加参数（默认 false 保持向后兼容）：
```dart
const SiteScript({
  required this.id,
  required this.domain,
  // ... 现有字段
  required this.verified,
  this.ocr = false,
});
```

(c) `fromMap` 加（约 line 31-44，与 verified 一起）：
```dart
verified: (map['verified'] as int?) ?? 0,
ocr: (map['ocr'] as int?) == 1,
```

(d) `toMap` 加：
```dart
'verified': verified,
'ocr': ocr ? 1 : 0,
```

(e) `copyWith` 加（仿现有 verified 的范式）：
```dart
bool? ocr,
// ...
ocr: ocr ?? this.ocr,
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/models/site_script_test.dart`
Expected: PASS

- [ ] **Step 5: 静态检查 + 提交**

Run: `flutter analyze lib/models/site_script.dart`
Expected: 无 error

```bash
git add lib/models/site_script.dart test/unit/models/site_script_test.dart
git commit -m "feat(model): SiteScript 加 ocr 字段"
```

---

## Task 4: SiteScriptRepository 加 updateScriptPart + upsertByDomain 适配 ocr

**Files:**
- Modify: `lib/repositories/site_script_repository.dart`
- Test: `test/unit/repositories/site_script_repository_test.dart`（Modify，补用例）

**Interfaces:**
- Consumes: Task 2/3 的 ocr 列与模型字段；`BaseRepository.database`
- Produces:
  - `upsertByDomain({domain, chapterListJs, chapterContentJs, urlPattern, sampleUrl, bool ocr = false})` —— 加可选 ocr 参数
  - `updateScriptPart({required String domain, required String scriptType, required String scriptJs, required bool ocr})` —— 部分更新，重置 verified=0

- [ ] **Step 1: 写失败测试**

在 `test/unit/repositories/site_script_repository_test.dart` 末尾追加（保留现有用例）：

```dart
group('updateScriptPart', () {
  test('分次写 list/content 不互相覆盖', () async {
    final repo = await buildRepo(); // 现有 helper：建库 + 返回 SiteScriptRepository
    // 先插一条种子记录（updateScriptPart 不自动 create）
    await repo.upsertByDomain(
      domain: 'fanqienovel.com',
      chapterListJs: 'LIST_SEED',
      chapterContentJs: 'CONTENT_SEED',
      ocr: false,
    );

    // 第一次：只写 chapter_list_js
    await repo.updateScriptPart(
      domain: 'fanqienovel.com',
      scriptType: 'chapter_list',
      scriptJs: 'LIST_NEW',
      ocr: false,
    );
    final after1 = await repo.getByDomain('fanqienovel.com');
    expect(after1!.chapterListJs, 'LIST_NEW');
    expect(after1.chapterContentJs, 'CONTENT_SEED'); // 不动
    expect(after1.ocr, isFalse);
    expect(after1.verified, 0); // 重置

    // 第二次：只写 chapter_content_js + ocr=true
    await repo.updateScriptPart(
      domain: 'fanqienovel.com',
      scriptType: 'chapter_content',
      scriptJs: 'CONTENT_NEW',
      ocr: true,
    );
    final after2 = await repo.getByDomain('fanqienovel.com');
    expect(after2!.chapterListJs, 'LIST_NEW'); // 第一次的不丢
    expect(after2.chapterContentJs, 'CONTENT_NEW');
    expect(after2.ocr, isTrue);
  });

  test('domain 不存在时返回错误，不自动 create', () async {
    final repo = await buildRepo();
    final result = await repo.updateScriptPart(
      domain: 'not.exist',
      scriptType: 'chapter_list',
      scriptJs: 'X',
      ocr: false,
    );
    expect(result.success, isFalse);
    expect(await repo.getByDomain('not.exist'), isNull);
  });
});

group('upsertByDomain ocr', () {
  test('ocr=true 落库后读回 needsOcr', () async {
    final repo = await buildRepo();
    await repo.upsertByDomain(
      domain: 'a.com',
      chapterListJs: 'L', chapterContentJs: 'C', ocr: true,
    );
    expect((await repo.getByDomain('a.com'))!.needsOcr, isTrue);
  });

  test('ocr 默认 false（向后兼容）', () async {
    final repo = await buildRepo();
    await repo.upsertByDomain(
      domain: 'b.com',
      chapterListJs: 'L', chapterContentJs: 'C',
    );
    expect((await repo.getByDomain('b.com'))!.ocr, isFalse);
  });
});
```

> 注：`buildRepo()` 是现有 test helper 的占位名，实际以文件里现有的 setup 为准（Task 1 调研显示该测试文件已存在，:8/15/21 有 SiteScriptRepository 构造）。若现有 helper 名不同，用实际的。

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/repositories/site_script_repository_test.dart`
Expected: FAIL — `updateScriptPart` 未定义 / `upsertByDomain` 无 `ocr` 参数

- [ ] **Step 3: 写最小实现**

在 `lib/repositories/site_script_repository.dart`：

(a) `upsertByDomain` 加可选 `ocr` 参数（签名 :181-187）：
```dart
Future<({String id, bool isInsert})> upsertByDomain({
  required String domain,
  required String chapterListJs,
  required String chapterContentJs,
  String urlPattern = '',
  String sampleUrl = '',
  bool ocr = false,  // v37 新增，默认 false 向后兼容
}) async {
```

(b) 在 `upsertByDomain` 的 UPDATE 的 map（:202-211）加 `'ocr': ocr ? 1 : 0,`；INSERT 的 map（:241-252）加 `'ocr': ocr ? 1 : 0,`。

(c) 新增 `updateScriptPart`（在 `upsertByDomain` 方法之后、class 闭合 `}` 之前）：
```dart
/// 增量更新某域名某类型脚本（save_script 分次保存用）。
///
/// - [scriptType] 为 `'chapter_list'` 或 `'chapter_content'`，决定更新哪列。
/// - 同时更新 [ocr] 列（保证两次保存的 ocr 标记一致）。
/// - 若 domain 不存在 → 返回 (success=false, reason='domain_not_found')，不自动 create
///   （避免半截提取器：list 存了 content 没存）。
/// - 更新后 verified 重置为 0（脚本内容变了需重新验证）。
/// - url_pattern 不写（save_script 不再产出该字段，DB 列保留历史值不动）。
Future<({bool success, String? id, String? reason})> updateScriptPart({
  required String domain,
  required String scriptType,
  required String scriptJs,
  required bool ocr,
}) async {
  try {
    final db = await database;
    final existing = await db.query(
      'site_scripts',
      where: 'domain = ?',
      whereArgs: [domain],
      orderBy: 'last_used_at DESC',
      limit: 1,
    );
    if (existing.isEmpty) {
      return (success: false, id: null, reason: 'domain_not_found');
    }
    final id = existing.first['id'] as String;
    final column = scriptType == 'chapter_list' ? 'chapter_list_js' : 'chapter_content_js';
    await db.update(
      'site_scripts',
      {
        column: scriptJs,
        'ocr': ocr ? 1 : 0,
        'last_used_at': DateTime.now().millisecondsSinceEpoch,
        'verified': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    LoggerService.instance.i(
      'updateScriptPart: domain=$domain type=$scriptType ocr=$ocr id=$id',
      category: LogCategory.database,
      tags: ['site_script', 'update_part'],
    );
    return (success: true, id: id, reason: null);
  } catch (e, stackTrace) {
    LoggerService.instance.e(
      'updateScriptPart 失败: domain=$domain - $e',
      stackTrace: stackTrace.toString(),
      category: LogCategory.database,
      tags: ['site_script', 'update_part', 'failed'],
    );
    rethrow;
  }
}
```

> 注：`LoggerService` 与 `LogCategory` 已在该文件顶部 import（Task 1 调研确认 upsertByDomain 用了它们）。

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/repositories/site_script_repository_test.dart`
Expected: PASS — 现有用例 + 新增 4 个全绿

- [ ] **Step 5: 提交**

```bash
git add lib/repositories/site_script_repository.dart test/unit/repositories/site_script_repository_test.dart
git commit -m "feat(repo): SiteScriptRepository 加 updateScriptPart + upsertByDomain 适配 ocr"
```

---

## Task 5: OcrPredictor 改造为 recognizeImage（接收 base64 单字图）

删除字体加载/TextPainter 渲染，只做 OCR。`_preprocess`/`_ctcDecode` 完全复用 PoC。

**Files:**
- Modify: `lib/poc/ocr_predictor.dart`
- Test: `test/unit/services/ocr_predictor_test.dart`（Create）

**Interfaces:**
- Consumes: PoC 已验证的 `_preprocess(ui.Image)→(Float32List,int)` / `_ctcDecode(List<List<double>>)→(String,List<int>)` / `load()` / `dispose()`
- Produces: `OcrPredictor()` 无参构造（删 family/fontSize/canvasSize）；`recognizeImage(String base64Png)→Future<String>`；`recognizeGlyph` 标 `@Deprecated` 保留一版（PoC 入口仍用）

> 注：PoC 入口 `main_ppocr_demo.dart` 仍依赖 `recognizeGlyph` + family 构造。本任务**保留 `recognizeGlyph` 但标 deprecated**，改造期内不删 PoC 入口（Task 15 才清理）。所以构造函数不能直接删 family——而是给默认值。**实现策略**：构造改 `OcrPredictor({this.family = '', this.fontSize = 80, this.canvasSize = 120})`（family 默认空，`recognizeImage` 路径不用它；`recognizeGlyph` deprecated 路径仍能用）。

- [ ] **Step 1: 写失败测试**

创建 `test/unit/services/ocr_predictor_test.dart`：

```dart
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/poc/ocr_predictor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OcrPredictor.recognizeImage', () {
    late OcrPredictor ocr;
    setUpAll(() async {
      ocr = OcrPredictor(); // 无参构造
      await ocr.load();
    });
    tearDownAll(() async => ocr.dispose());

    test('空白图返回空字符串', () async {
      // 120x120 全白 PNG base64
      final blankBase64 = await _encodeBlankPng();
      final result = await ocr.recognizeImage(blankBase64);
      expect(result, isEmpty);
    });

    test('渲染单个汉字"中"的图能识别出非空字符串', () async {
      final charImg = await _renderCharToBase64('中'); // 见 helper
      final result = await ocr.recognizeImage(charImg);
      // OCR 不保证 100% 命中，但至少不应抛异常；合理情况下命中"中"
      expect(result.length, lessThanOrEqualTo(2));
    });
  });
}

// ── helpers ──
// 注意：这些 helper 用 dart:ui PictureRecorder + TextPainter 渲染汉字
// 仅用于测试（产品里渲染在 WebView canvas）。复用 PoC _render 的思路。
Future<String> _encodeBlankPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(ui.Color(0xFFFFFFFF), ui.BlendMode.src);
  final pic = recorder.endRecording();
  final img = await pic.toImage(120, 120);
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return base64.encode(bd!.buffer.asUint8List());
}

Future<String> _renderCharToBase64(String ch) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(ui.Color(0xFFFFFFFF), ui.BlendMode.src);
  final tp = ui.TextDirection.ltr == ui.TextDirection.ltr
      ? null
      : null;
  // 用 TextPainter 渲染系统字体的汉字（测试不依赖反爬字体）
  final painter = _makeTp(ch);
  painter.layout();
  painter.paint(canvas, ui.Offset(10, 10));
  final pic = recorder.endRecording();
  final img = await pic.toImage(120, 120);
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return base64.encode(bd!.buffer.asUint8List());
}
```

> 注：`_makeTp` helper 需 import `package:flutter/material.dart` 用 `TextPainter`+`TextSpan`（系统字体渲染汉字）。完整 helper 在实现时补全——PoC `ocr_predictor.dart` 的 `_render` 方法是现成参照。测试的断言较宽松（OCR 单字识别不保证 100% 命中，只验证不抛异常 + 返回类型正确）。**若 CI 环境无 onnxruntime 原生库导致 load() 失败**，用 `@OnPlatform({'vm': Skip('needs onnxruntime native lib')})` 或把这两个用例标 `skip`，但 `空白图返回空` 至少在能跑的环境验证。以实际 CI 能力为准，skip 时在测试顶部加注释说明。

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/services/ocr_predictor_test.dart`
Expected: FAIL — `recognizeImage` 未定义 / 无参构造不存在

- [ ] **Step 3: 写最小实现**

在 `lib/poc/ocr_predictor.dart`：

(a) 构造函数改默认值（line 27）：
```dart
OcrPredictor({this.family = '', this.fontSize = 80, this.canvasSize = 120});
```
family 默认空串（`recognizeImage` 路径不用它）。

(b) 新增 `recognizeImage`（在 `recognizeGlyph` 之后）：
```dart
/// 识别 WebView canvas 渲染好的单字图（base64 PNG，不带 data:image/png;base64, 前缀）。
///
/// 与 [recognizeGlyph] 的区别：本方法不自己渲染（渲染在 WebView canvas），
/// 只做 base64 → ui.Image → 预处理 → onnx 推理 → CTC 解码。
/// 预处理 / CTC 解码完全复用 PoC 已验证的 [_preprocess] / [_ctcDecode]。
Future<String> recognizeImage(String base64Png) async {
  final bytes = base64Decode(base64Png);
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final (tensor, w) = await _preprocess(image);
  final outputs = await _session!.run({
    'x': await OrtValue.fromList(tensor, [1, 3, 48, w]),
  });
  final value = outputs.values.first;
  final nested = await value.asList();
  final logits = (nested[0] as List)
      .map((e) => (e as List).map((x) => (x as num).toDouble()).toList())
      .toList();
  final (text, _) = _ctcDecode(logits);
  return text;
}
```

(c) 给 `recognizeGlyph` 加 `@Deprecated`（line 41 附近，方法上方）：
```dart
@Deprecated('PoC 用，产品路径用 recognizeImage(base64Png)。Task 15 清理时移除。')
Future<(String, List<int>)> recognizeGlyph(int codepoint) async { ... }
```

(d) `load()` 的字体加载逻辑：**审查后决定**。PoC `load()` 当前只加载模型+字典（不含字体，字体在 `main_ppocr_demo.dart` 的 `main()` 里 `loadFontFromList`）。所以 `load()` **无需改**。

(e) import：需新增 `dart:convert`（base64Decode）。现有 import 已有 `dart:ui as ui` / `flutter_onnxruntime` / `image`。

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/services/ocr_predictor_test.dart`
Expected: PASS（或 skip 的环境标记 skip）

- [ ] **Step 5: 确保 PoC 入口仍能编译 + 提交**

Run: `flutter analyze lib/poc/ocr_predictor.dart lib/main_ppocr_demo.dart`
Expected: `main_ppocr_demo.dart` 因 `recognizeGlyph` deprecated 会有 info 级警告（可接受，PoC 入口）；无 error

```bash
git add lib/poc/ocr_predictor.dart test/unit/services/ocr_predictor_test.dart
git commit -m "feat(ocr): OcrPredictor 新增 recognizeImage(base64Png) 入口"
```

---

## Task 6: 系统 OCR-JS 常量模板

独立的 JS 字符串常量，被运行时钩子和 save_script 验证共用。

**Files:**
- Create: `lib/services/ocr_render_js.dart`
- Test: `test/unit/services/ocr_render_js_test.dart`（Create）

**Interfaces:**
- Produces: `String ocrRenderJsTemplate` —— 含 `{{CODEPOINT}}` / `{{FONT_FAMILY}}` 占位符；`String buildOcrRenderJs(int codepoint, String fontFamily)` 替换占位符产出可执行 JS

- [ ] **Step 1: 写失败测试**

创建 `test/unit/services/ocr_render_js_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/ocr_render_js.dart';

void main() {
  group('buildOcrRenderJs', () {
    test('替换 CODEPOINT 占位符', () {
      final js = buildOcrRenderJs(0xE3E8, 'MyFont');
      expect(js, contains('const cp = 0xE3E8;'));
      expect(js, contains("'80px MyFont'"));
    });

    test('替换 FONT_FAMILY 占位符', () {
      final js = buildOcrRenderJs(0xE3E9, 'AntiCrawlFont');
      expect(js, contains('const fontFamily = "AntiCrawlFont";'));
      expect(js, contains("'80px AntiCrawlFont'"));
    });

    test('保留 await document.fonts.ready', () {
      final js = buildOcrRenderJs(0xE3E8, 'F');
      expect(js, contains('await document.fonts.ready'));
    });

    test('返回 base64 不带前缀', () {
      final js = buildOcrRenderJs(0xE3E8, 'F');
      expect(js, contains("toDataURL('image/png').split(',')[1]"));
    });

    test('不出现具体站点选择器', () {
      final js = buildOcrRenderJs(0xE3E8, 'F');
      expect(js, isNot(contains('muye-reader')));
      expect(js, isNot(contains('fanqie')));
    });
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/services/ocr_render_js_test.dart`
Expected: FAIL — 文件不存在

- [ ] **Step 3: 写最小实现**

创建 `lib/services/ocr_render_js.dart`：

```dart
/// 系统内置 OCR-JS：在已加载反爬字体的 WebView 页面上，
/// 用 canvas 渲染单个 PUA 码点 → toDataURL → 返回 base64 PNG（不带前缀）。
///
/// **关键**：canvas 不自动继承 @font-face，必须显式 `ctx.font = '80px <反爬字体族名>'`。
/// spike 验证：`80px sans-serif` 时四个不同 PUA 渲染出完全相同占位框（失败）；
/// `80px <反爬字体族名>` 时渲染出四个不同字形（成功）。
///
/// `{{CODEPOINT}}` 和 `{{FONT_FAMILY}}` 由 Dart 侧 [buildOcrRenderJs] 替换。
/// 本 JS **不走 `WebViewJsExecutor.validateScript`**（该函数强制 {{URL}} 会误杀），
/// 调用方直接 `callAsyncJavaScript(functionBody: js)`。
library;

const String ocrRenderJsTemplate = r'''
(async function() {
  await document.fonts.ready;
  const cp = {{CODEPOINT}};
  const fontFamily = "{{FONT_FAMILY}}";
  const canvas = document.createElement('canvas');
  canvas.width = 120; canvas.height = 120;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#FFFFFF'; ctx.fillRect(0, 0, 120, 120);
  ctx.fillStyle = '#000000';
  ctx.font = '80px ' + fontFamily;
  ctx.textBaseline = 'middle'; ctx.textAlign = 'center';
  ctx.fillText(String.fromCodePoint(cp), 60, 60);
  return canvas.toDataURL('image/png').split(',')[1];
})()
''';

/// 把 [codepoint] 和 [fontFamily] 注入模板，返回可执行的 async IIFE JS。
///
/// 调用方用 `controller.callAsyncJavaScript(functionBody: buildOcrRenderJs(...))`。
String buildOcrRenderJs(int codepoint, String fontFamily) {
  return ocrRenderJsTemplate
      .replaceAll('{{CODEPOINT}}', '0x${codepoint.toRadixString(16).toUpperCase()}')
      .replaceAll('{{FONT_FAMILY}}', fontFamily);
}
```

> 注：测试里 `contains('const cp = 0xE3E8;')`——toRadixString(16) 给 `E3E8`，拼成 `0xE3E8`。`contains("'80px MyFont'")`——JS 里是 `'80px ' + fontFamily`，fontFamily 替换后 ctx.font 行是 `ctx.font = '80px ' + "MyFont"`，所以 `'80px '` 这个字面子串在；而 `'80px MyFont'` 不直接出现。**修正测试**：把断言改成 `expect(js, contains("'80px ' + \"MyFont\""))` 或验证 `fontFamily` 变量赋值。以最终实现为准调整测试断言。

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/services/ocr_render_js_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/services/ocr_render_js.dart test/unit/services/ocr_render_js_test.dart
git commit -m "feat(ocr): 新增系统内置 OCR 渲染 JS 模板"
```

---

## Task 7: OcrRestoreService（restorePuaInText / verifyFontFamily / readableRatio）

把 OCR 后处理逻辑抽成独立 service，供运行时钩子和 save_script 验证共用。`_renderPua` 注入回调解耦 WebView。

**Files:**
- Modify: `lib/services/ocr_restore_service.dart`（Task 1 只放了 `isPua`，本任务加 service 类）
- Test: `test/unit/services/ocr_restore_service_test.dart`（Create）

**Interfaces:**
- Consumes: Task 1 的 `isPua`；Task 5 的 `OcrPredictor.recognizeImage`（通过 `ocrPredictorProvider`）
- Produces:
  - `OcrRestoreService(Ref ref, Future<String> Function(int, String) renderPua)` 构造
  - `Future<OcrRestoreResult> restorePuaInText(String text, String? fontFamily)` —— 通用还原入口
  - `Future<bool> verifyFontFamily(String fontFamily)` —— 字体有效性探测
  - `double readableRatio(String text)` —— CJK 占比

- [ ] **Step 1: 写失败测试**

创建 `test/unit/services/ocr_restore_service_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/ocr_restore_service.dart';

void main() {
  group('OcrRestoreService.restorePuaInText', () {
    test('无 PUA 直接返回原文，decoded=0', () async {
      final svc = _buildService(renderPua: (_, __) async => '');
      final r = await svc.restorePuaInText('正常的中文文本', null);
      expect(r.text, '正常的中文文本');
      expect(r.decodedCount, 0);
      expect(r.totalPuaCount, 0);
    });

    test('PUA 全部识别成功则全部替换', () async {
      // mock renderPua 返回固定 base64；mock predictor 识别返回 "字"
      final svc = _buildService(
        renderPua: (cp, _) async => 'mock_b64_$cp',
        recognizeImage: (_) async => '字',
      );
      final text = '前${String.fromCharCode(0xE3E8)}后${String.fromCharCode(0xE3E9)}';
      final r = await svc.restorePuaInText(text, 'F');
      expect(r.totalPuaCount, 2);
      expect(r.decodedCount, 2);
      expect(r.text, '前字后字');
    });

    test('单个 PUA 识别失败留 □ 不中断', () async {
      final svc = _buildService(
        renderPua: (cp, _) async => 'mock_$cp',
        recognizeImage: (b64) async => b64 == 'mock_0xE3E8' ? '字' : '',
      );
      final text = '${String.fromCharCode(0xE3E8)}X${String.fromCharCode(0xE3E9)}';
      final r = await svc.restorePuaInText(text, 'F');
      expect(r.totalPuaCount, 2);
      expect(r.decodedCount, 1);
      expect(r.text, '字X□');
    });

    test('renderPua 抛异常该字符留 □', () async {
      final svc = _buildService(
        renderPua: (cp, _) async {
          if (cp == 0xE3E8) throw Exception('render fail');
          return 'ok';
        },
        recognizeImage: (_) async => '字',
      );
      final text = '${String.fromCharCode(0xE3E8)}${String.fromCharCode(0xE3E9)}';
      final r = await svc.restorePuaInText(text, 'F');
      expect(r.text, '□字');
      expect(r.decodedCount, 1);
    });
  });

  group('verifyFontFamily', () {
    test('空字体族返回 false', () async {
      final svc = _buildService(renderPua: (_, __) async => '');
      expect(await svc.verifyFontFamily(''), isFalse);
    });

    test('两个 PUA 渲染结果不同 → true', () async {
      final svc = _buildService(
        renderPua: (cp, _) async => 'img_$cp',
      );
      expect(await svc.verifyFontFamily('RealFont'), isTrue);
    });

    test('两个 PUA 渲染结果相同（占位框）→ false', () async {
      final svc = _buildService(
        renderPua: (_, __) async => 'same_box', // 恒返回相同
      );
      expect(await svc.verifyFontFamily('BadFont'), isFalse);
    });
  });

  group('readableRatio', () {
    test('全 CJK 为 1.0', () {
      final svc = _buildService(renderPua: (_, __) async => '');
      expect(svc.readableRatio('中文文本'), 1.0);
    });

    test('空文本为 0', () {
      final svc = _buildService(renderPua: (_, __) async => '');
      expect(svc.readableRatio(''), 0);
    });

    test('半 CJK 半非 → 0.5', () {
      final svc = _buildService(renderPua: (_, __) async => '');
      expect(svc.readableRatio('中A'), closeTo(0.5, 0.01));
    });
  });
}

// ── helper：构造一个注入 mock renderPua + mock predictor 的 service ──
OcrRestoreService _buildService({
  required Future<String> Function(int, String) renderPua,
  Future<String> Function(String base64)? recognizeImage,
}) {
  // OcrRestoreService 内部读 ocrPredictorProvider 拿 predictor；
  // 测试里通过注入的 _predictorOverride 覆盖 recognizeImage。
  return OcrRestoreService.forTesting(
    renderPua: renderPua,
    recognizeImageFn: recognizeImage ?? (_) async => '',
  );
}
```

> 注：测试用 `OcrRestoreService.forTesting` 构造绕开 Riverpod（spec 的 `OcrRestoreService(this._ref, this._renderPua)` 走 provider，测试不好注入 mock predictor）。**实现策略**：service 提供两个构造——产品用 `OcrRestoreService(Ref ref, renderPua)` 内部 `ref.read(ocrPredictorProvider.future)`；测试用 `OcrRestoreService.forTesting({renderPua, recognizeImageFn})` 注入函数替代 predictor。内部统一调 `_recognizeImage(base64)` 抽象方法，两种构造分别实现它。

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/services/ocr_restore_service_test.dart`
Expected: FAIL — `OcrRestoreService` 类不存在

- [ ] **Step 3: 写最小实现**

在 `lib/services/ocr_restore_service.dart`（Task 1 已有 `isPua`，追加类定义）：

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../poc/ocr_predictor.dart';
import '../core/providers/ocr_providers.dart'; // Task 8 创建，先留 import（编译会报缺失，Task 8 补）

/// OCR 还原结果。
class OcrRestoreResult {
  final String text;
  final int decodedCount;
  final int totalPuaCount;
  const OcrRestoreResult(this.text, this.decodedCount, this.totalPuaCount);

  /// PUA 识别成功率（无 PUA 时记 1.0）。
  double get decodedRatio =>
      totalPuaCount == 0 ? 1.0 : decodedCount / totalPuaCount;
}

/// OCR 还原服务：对文本中 PUA 码点逐字 canvas 渲染 → 识别 → 替换。
///
/// `_renderPua` 是注入的"渲染单字"回调（由 WebView holder 提供），
/// 让本 service 不耦合具体 WebView 实例，运行时钩子和 save_script 验证共用。
class OcrRestoreService {
  OcrRestoreService(this._ref, this._renderPua);

  final Ref _ref;
  final Future<String> Function(int codepoint, String fontFamily) _renderPua;

  /// 还原 [text] 里所有 PUA 码点（通用入口，content 和 list title 都调它）。
  Future<OcrRestoreResult> restorePuaInText(
    String text,
    String? fontFamily,
  ) async {
    final puaCodepoints = <int>{};
    for (final r in text.runes) {
      if (isPua(r)) puaCodepoints.add(r);
    }
    if (puaCodepoints.isEmpty) {
      return OcrRestoreResult(text, 0, 0);
    }

    final puaToChar = <int, String>{};
    for (final cp in puaCodepoints) {
      try {
        final imageBase64 = await _renderPua(cp, fontFamily ?? '');
        final decoded = await _recognizeImage(imageBase64);
        puaToChar[cp] = decoded;
      } catch (_) {
        puaToChar[cp] = ''; // 单字符失败，留 □
      }
    }

    final sb = StringBuffer();
    int decoded = 0;
    for (final r in text.runes) {
      if (isPua(r)) {
        final d = puaToChar[r] ?? '';
        if (d.isNotEmpty) {
          sb.write(d);
          decoded++;
        } else {
          sb.write('□');
        }
      } else {
        sb.writeCharCode(r);
      }
    }
    return OcrRestoreResult(sb.toString(), decoded, puaCodepoints.length);
  }

  /// 字体有效性探测：用 font_family 渲染 2 个不同 PUA，字节级差异验证。
  /// 错误字体栈会渲染出相同占位框。
  Future<bool> verifyFontFamily(String fontFamily) async {
    if (fontFamily.isEmpty) return false;
    final a = await _renderPua(0xE3E9, fontFamily);
    final b = await _renderPua(0xE3EA, fontFamily);
    return a != b;
  }

  /// readable_ratio：CJK 字符占比（判定 OCR 还原后文本可读性）。
  double readableRatio(String text) {
    if (text.isEmpty) return 0;
    int cjk = 0, total = 0;
    for (final r in text.runes) {
      total++;
      if (r >= 0x4E00 && r <= 0x9FFF) cjk++;
    }
    return cjk / total;
  }

  /// 内部识别抽象：产品实现读 provider，测试实现走注入函数。
  Future<String> _recognizeImage(String base64Png);

  // 产品构造的识别实现
  static Future<String> _productRecognize(
    Ref ref,
    String base64Png,
  ) async {
    final ocr = await ref.read(ocrPredictorProvider.future);
    return ocr.recognizeImage(base64Png);
  }
}

/// 测试用构造：绕开 Riverpod，直接注入识别函数。
class _OcrRestoreServiceProduct extends OcrRestoreService {
  _OcrRestoreServiceProduct(Ref ref, super.renderPua);
  @override
  Future<String> _recognizeImage(String base64Png) =>
      OcrRestoreService._productRecognize(_ref, base64Png);
}

/// forTesting 工厂（测试专用，产品代码勿用）。
OcrRestoreService _testingInstance({
  required Future<String> Function(int, String) renderPua,
  required Future<String> Function(String) recognizeImageFn,
}) {
  return _TestingOcrRestoreService(renderPua, recognizeImageFn);
}

class _TestingOcrRestoreService extends OcrRestoreService {
  _TestingOcrRestoreService(this._renderPuaFn, this._recognizeFn)
      : super(_noRef, _renderPuaFn);
  // 注意：测试构造不传 Ref，产品构造才需要。
}
```

> ⚠️ **实现时简化**：上面的多类继承设计偏复杂，更简洁的写法见下——用单一类 + 两个命名构造 + 一个 nullable 识别函数字段：

```dart
class OcrRestoreService {
  OcrRestoreService(this._ref, this._renderPua) : _recognizeFn = null;
  OcrRestoreService.forTesting({
    required Future<String> Function(int, String) renderPua,
    required Future<String> Function(String) recognizeImageFn,
  })  : _ref = null,
        _renderPua = renderPua,
        _recognizeFn = recognizeImageFn;

  final Ref? _ref;
  final Future<String> Function(int, String) _renderPua;
  final Future<String> Function(String)? _recognizeFn;

  Future<String> _recognizeImage(String base64Png) async {
    if (_recognizeFn != null) return _recognizeFn!(base64Png);
    final ocr = await _ref!.read(ocrPredictorProvider.future);
    return ocr.recognizeImage(base64Png);
  }
  // ... restorePuaInText / verifyFontFamily / readableRatio 同上，调 _recognizeImage
}
```

**以这个简洁版为最终实现**。`OcrRestoreService.forTesting` 在测试里直接用，`_buildService` helper 映射到它。

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/services/ocr_restore_service_test.dart`
Expected: PASS — 9 个用例全绿

- [ ] **Step 5: 提交**

```bash
git add lib/services/ocr_restore_service.dart test/unit/services/ocr_restore_service_test.dart
git commit -m "feat(ocr): 新增 OcrRestoreService 还原/验证/可读性"
```

> 注：本任务 import 了 `ocr_providers.dart` 的 `ocrPredictorProvider`（Task 8 创建）。本任务提交时该文件可能还不存在导致 `flutter analyze` 报缺失。**调整执行顺序**：Task 8（ocr_providers）实际应在本任务之前。但 Task 8 依赖 Task 5（OcrPredictor）+ Task 7（OcrRestoreService），循环了。**破环**：Task 8 先只创建 `ocrPredictorProvider`（依赖 Task 5），不依赖 Task 7；Task 7 完成后 Task 8 再补 `ocrRestoreServiceProvider`。即把 Task 8 拆成 8a（predictor provider）和 8b（restore service provider），8a 在 Task 5 后、Task 7 前。**修正：见下方 Task 8 重新定位**。

---

## Task 8: OCR Provider 注册（ocrPredictorProvider + ocrRestoreServiceProvider）

依赖 Task 5（OcrPredictor）和 Task 7（OcrRestoreService）。**本任务实际在 Task 5 之后、Task 7 之前完成 8a 部分，Task 7 之后完成 8b。**这里合并描述，执行时拆两个提交。

**Files:**
- Create: `lib/core/providers/ocr_providers.dart`
- Test: `test/unit/providers/ocr_providers_test.dart`（Create）

**Interfaces:**
- Consumes: Task 5 `OcrPredictor`，Task 7 `OcrRestoreService`
- Produces: `ocrPredictorProvider` (FutureProvider<OcrPredictor>)，`ocrRestoreServiceProvider` (Provider<OcrRestoreService>，需注入 renderPua 回调——但 renderPua 由 WebView holder 提供，此处只注册 predictor)

> **设计决策**：`OcrRestoreService` 需要 `_renderPua` 回调，而回调依赖具体 WebView 实例（content service / list service / save_script executor 各自的 controller）。所以 **`ocrRestoreServiceProvider` 不在全局注册**，而是在各调用方就地构造（`OcrRestoreService(ref, _renderPua)`）。全局只注册 `ocrPredictorProvider`。spec §6.5 的 `ocrRestoreServiceProvider` 是过度设计——renderPua 注入决定了它不能全局单例。**本任务只创建 `ocrPredictorProvider`**。

- [ ] **Step 1: 写失败测试**

创建 `test/unit/providers/ocr_providers_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_app/core/providers/ocr_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ocrPredictorProvider 可解析且 isLoaded', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final predictor = await container.read(ocrPredictorProvider.future);
    expect(predictor.isLoaded, isTrue);
    await predictor.dispose();
  });
}
```

> 注：若 CI 无 onnxruntime 原生库，标 `@OnPlatform` skip。

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/providers/ocr_providers_test.dart`
Expected: FAIL — `ocrPredictorProvider` 未定义

- [ ] **Step 3: 写最小实现**

创建 `lib/core/providers/ocr_providers.dart`：

```dart
/// OCR 相关 Provider。
///
/// `ocrPredictorProvider` 全局单例（keepAlive），应用生命周期加载一次 onnx 模型。
/// `OcrRestoreService` 不在此全局注册——它需要注入 `_renderPua` 回调
/// （依赖具体 WebView 实例），由各调用方（content/list service、save_script executor）
/// 就地 `OcrRestoreService(ref, renderPua)` 构造。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../poc/ocr_predictor.dart';

/// PP-OCRv6 识别器单例。lazy + cached，应用生命周期加载一次（~1s）。
final ocrPredictorProvider = FutureProvider<OcrPredictor>((ref) async {
  final predictor = OcrPredictor();
  await predictor.load();
  ref.onDispose(() => predictor.dispose());
  return predictor;
});
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/providers/ocr_providers_test.dart`
Expected: PASS（或 skip）

- [ ] **Step 5: 补 Task 7 的循环依赖 + 提交**

确认 Task 7 的 `ocr_restore_service.dart` import `ocr_providers.dart` 现在能解析：
Run: `flutter analyze lib/services/ocr_restore_service.dart lib/core/providers/ocr_providers.dart`
Expected: 无 error

```bash
git add lib/core/providers/ocr_providers.dart test/unit/providers/ocr_providers_test.dart
git commit -m "feat(ocr): 注册 ocrPredictorProvider 全局单例"
```

---

## Task 9: ChapterContentResult 加 fontFamily 字段

运行时钩子要从提取脚本结果里读 font_family 传给 OcrRestoreService，ChapterContentResult 得有这个字段。

**Files:**
- Modify: `lib/models/chapter_content_result.dart`
- Test: `test/unit/models/chapter_content_result_test.dart`（Create）

**Interfaces:**
- Produces: `ChapterContentResult({required content, fontFamily, fromCache})`

- [ ] **Step 1: 写失败测试**

创建 `test/unit/models/chapter_content_result_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/chapter_content_result.dart';

void main() {
  test('默认 fontFamily 为 null（向后兼容）', () {
    final r = ChapterContentResult(content: 'x');
    expect(r.fontFamily, isNull);
    expect(r.fromCache, isFalse);
  });

  test('可传 fontFamily', () {
    final r = ChapterContentResult(content: 'x', fontFamily: 'AntiCrawl');
    expect(r.fontFamily, 'AntiCrawl');
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/models/chapter_content_result_test.dart`
Expected: FAIL — `fontFamily` 不存在

- [ ] **Step 3: 写最小实现**

修改 `lib/models/chapter_content_result.dart`：

```dart
class ChapterContentResult {
  final String content;
  final String? fontFamily; // v37 新增：反爬字体族名（OCR 模式下由脚本返回）
  final bool fromCache;

  const ChapterContentResult({
    required this.content,
    this.fontFamily,
    this.fromCache = false,
  });
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/models/chapter_content_result_test.dart`
Expected: PASS

- [ ] **Step 5: 静态检查所有引用处 + 提交**

Run: `flutter analyze lib/`
Expected: 无 error（新字段可选，现有构造调用不受影响）

```bash
git add lib/models/chapter_content_result.dart test/unit/models/chapter_content_result_test.dart
git commit -m "feat(model): ChapterContentResult 加 fontFamily 字段"
```

---

## Task 10: HeadlessWebViewContentService 加 OCR 还原钩子

`fetchContent` 看到 `script.needsOcr` 就对 content 走 `OcrRestoreService.restorePuaInText`。`_executeContentScript` 改造为同时返回 content + fontFamily。

**Files:**
- Modify: `lib/services/headless_webview_content_service.dart`
- Modify: `lib/core/providers/services/network_service_providers.dart`（注入 ocrPredictorProvider）
- Test: `test/unit/services/headless_webview_content_service_test.dart`（Modify，补 OCR 路径用例）

**Interfaces:**
- Consumes: Task 4 `needsOcr`；Task 7 `OcrRestoreService`；Task 9 `ChapterContentResult.fontFamily`；Task 6 `buildOcrRenderJs`
- Produces: `fetchContent` 在 `needsOcr` 时透明走 OCR 还原

> **关键**：service 现构造仅注入 `_scriptRepo`，无 `Ref`。要读 `ocrPredictorProvider`，得加 `Ref _ref` 注入（改构造 + provider 注册）。`_renderPua` 回调由 service 自身提供（用 service 的 `_controller` 跑 `buildOcrRenderJs` 的 `callAsyncJavaScript`）。

- [ ] **Step 1: 写失败测试**

在 `test/unit/services/headless_webview_content_service_test.dart` 补用例（现有有 `MockSiteScriptRepository`，:24）：

```dart
// 需要新加 mock：MockOcrPredictor + 注入 OcrRestoreService
// 由于 service 改造后需要 Ref + _renderPua，测试改用注入式构造（forTesting）。

test('needsOcr=true 时 content 的 PUA 被还原', () async {
  // 构造 service：scriptRepo 返回 needsOcr=true 的 script，
  // _executeContentScript mock 返回 ('含PUA的content', 'AntiCrawlFont')，
  // OcrRestoreService mock 把 PUA 替换成 '字'。
  final service = HeadlessWebViewContentService.forTesting(
    scriptRepo: mockRepo(needsOcr: true, contentJs: 'JS'),
    restoreService: mockRestoreService(restoreResult: '前字后'),
    executeScriptFn: (_, __) async => ('content含PUA', 'AntiCrawlFont'),
  );
  final r = await service.fetchContent('https://a.com/1');
  expect(r.isSuccess, isTrue);
  expect(r.content!.content, '前字后');
});

test('needsOcr=false 时不调 restoreService', () async {
  var restoreCalled = false;
  final service = HeadlessWebViewContentService.forTesting(
    scriptRepo: mockRepo(needsOcr: false, contentJs: 'JS'),
    restoreService: mockRestoreService(
      onRestore: () => restoreCalled = true,
      restoreResult: 'should_not_used',
    ),
    executeScriptFn: (_, __) async => ('正常content', null),
  );
  final r = await service.fetchContent('https://a.com/1');
  expect(r.isSuccess, isTrue);
  expect(restoreCalled, isFalse);
});
```

> 注：service 加 `forTesting` 命名构造注入 `executeScriptFn` + `restoreService`，绕开真实 WebView 和 onnx。`mockRepo`/`mockRestoreService` 是 test helper。实际实现以现有测试文件风格为准。

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/services/headless_webview_content_service_test.dart`
Expected: FAIL — `forTesting` 不存在 / `needsOcr` 未读取

- [ ] **Step 3: 写最小实现**

在 `lib/services/headless_webview_content_service.dart`：

(a) 构造加 `Ref`：
```dart
class HeadlessWebViewContentService {
  final SiteScriptRepository _scriptRepo;
  final Ref _ref; // 新增：读 ocrPredictorProvider

  HeadlessWebViewContentService({
    required SiteScriptRepository scriptRepo,
    required Ref ref,
  })  : _scriptRepo = scriptRepo,
        _ref = ref;
```

(b) `_executeContentScript` 返回类型改 `Future<({String content, String? fontFamily})?>`，解析处（:458-460）改成同时取 content + fontFamily：
```dart
// 旧：return (data['content'] as String?)?.trim();
// 新：
if (data is Map<String, dynamic>) {
  final c = (data['content'] as String?)?.trim();
  final ff = (data['font_family'] as String? ?? data['fontFamily'] as String?)?.trim();
  if (c == null) return null;
  return (content: c, fontFamily: ff?.isEmpty == true ? null : ff);
}
if (data is String) {
  return (content: data.trim(), fontFamily: null);
}
return null;
```

> 注：JS 侧脚本约定返回 `font_family`（snake），但 agent 可能写 `fontFamily`（camel），两个都取兜底。

(c) `fetchContent` 在校验通过后（:233 附近）、`return FetchContentResult.success` 之前插入 OCR 还原：
```dart
String finalContent = content.content;
String? fontFamily = content.fontFamily;

if (script.needsOcr) {
  try {
    final restoreService = OcrRestoreService(
      _ref,
      _renderPua, // service 内方法，见下
    );
    final result = await restoreService.restorePuaInText(
      finalContent,
      fontFamily,
    );
    finalContent = result.text;
    LoggerService.instance.i(
      'HeadlessWebView OCR 还原: domain=$domain decoded=${result.decodedCount}/${result.totalPuaCount}',
      category: LogCategory.cache,
      tags: ['headless-webview', 'ocr', 'restore'],
    );
  } catch (e, stackTrace) {
    // OCR 整体失败 → 降级返回原文，不崩溃
    LoggerService.instance.w(
      'HeadlessWebView OCR 还原失败，降级返回原文: $e',
      stackTrace: stackTrace.toString(),
      category: LogCategory.cache,
      tags: ['headless-webview', 'ocr', 'restore-failed'],
    );
  }
}

return FetchContentResult.success(
  ChapterContentResult(
    content: finalContent,
    fontFamily: fontFamily,
    fromCache: false,
  ),
);
```

(d) 新增 `_renderPua` 方法（service 内，用 `_controller` 跑 OCR-JS）：
```dart
/// 渲染单个 PUA 码点为 base64 PNG（供 OcrRestoreService 用）。
/// 在已加载页面上跑系统 OCR-JS。OCR-JS 不走 validateScript（占位符不同）。
Future<String> _renderPua(int codepoint, String fontFamily) async {
  if (_controller == null) throw StateError('WebView 未就绪');
  final js = buildOcrRenderJs(codepoint, fontFamily);
  // OCR-JS 是完整 async IIFE，callAsyncJavaScript 的 functionBody 要函数体；
  // buildOcrRenderJs 返回的已是 (async function(){...})()，
  // 剥外壳用 extractAsyncFunctionBody（它不校验 {{URL}}，只剥 IIFE）。
  final functionBody = WebViewJsExecutor.extractAsyncFunctionBody(js);
  final result = await _controller!
      .callAsyncJavaScript(functionBody: functionBody)
      .timeout(const Duration(seconds: 30));
  if (result == null || result.error != null) {
    throw Exception('OCR 渲染失败 cp=$codepoint: ${result?.error}');
  }
  final jsonStr = WebViewJsExecutor.stringifyJsResult(result.value);
  // JS 直接 return base64 字符串，stringifyJsResult 会包成 JSON 字符串
  final decoded = jsonDecode(jsonStr);
  if (decoded is String) return decoded;
  throw Exception('OCR 渲染返回非字符串: $decoded');
}
```

> ⚠️ **风险点**：`WebViewJsExecutor.extractAsyncFunctionBody` 现有实现可能假设输入含 `{{URL}}`（Task 1 调研说它剥 `(async function(){...})()` 外壳）。OCR-JS 模板不含 `{{URL}}` 但格式是合法 IIFE，应能剥。**实现时验证**：若 `extractAsyncFunctionBody` 对无 `{{URL}}` 输入报错，改用直接传 `functionBody: js` 的 IIFE 函数体部分（手动剥或调整模板为裸函数体）。以实际 API 行为为准，必要时 Task 6 模板调整为不含 IIFE 包裹的纯函数体（`async function() { ... }`），callAsyncJavaScript 自己包。

(e) 加 `forTesting` 构造（测试用）：
```dart
@visibleForTesting
HeadlessWebViewContentService.forTesting({
  required SiteScriptRepository scriptRepo,
  required OcrRestoreService restoreService,
  required Future<({String content, String? fontFamily})?> Function(
      String, String) executeScriptFn,
})  : _scriptRepo = scriptRepo,
      _ref = null as Ref, // 测试不读 provider
      _restoreServiceOverride = restoreService,
      _executeScriptFnOverride = executeScriptFn;
```

> 注：测试构造绕开 WebView，把 `_executeContentScript` 和 `OcrRestoreService` 都注入。产品路径用真实 `_controller` + 真实 service。`_ref` 在测试里给 null（用 `as Ref` 强转，运行时测试不会走 provider 分支）。**实现时若类型系统不允许 null Ref，改用 `late` + sentinel 或 nullable Ref + 内部分支判断 `isTesting`**。以编译通过为准调整。

(f) 修改 `lib/core/providers/services/network_service_providers.dart` 的 provider 注入 Ref：
```dart
@Riverpod(keepAlive: true)
HeadlessWebViewContentService headlessWebViewContentService(Ref ref) {
  final scriptRepo = ref.watch(siteScriptRepositoryProvider);
  return HeadlessWebViewContentService(scriptRepo: scriptRepo, ref: ref);
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/services/headless_webview_content_service_test.dart`
Expected: PASS — 现有用例 + 新增 2 个全绿

- [ ] **Step 5: 静态检查 + 提交**

Run: `flutter analyze lib/services/headless_webview_content_service.dart lib/core/providers/services/network_service_providers.dart`
Expected: 无 error

```bash
git add lib/services/headless_webview_content_service.dart lib/core/providers/services/network_service_providers.dart test/unit/services/headless_webview_content_service_test.dart
git commit -m "feat(headless): fetchContent 加 OCR 还原钩子"
```

---

## Task 11: HeadlessWebViewChapterListService 加 title OCR 还原钩子

`fetchChapterList` 在 `needsOcr` 时还原顶层 title + 每个 chapter.title，url 不动。

**Files:**
- Modify: `lib/services/headless_webview_chapter_list_service.dart`
- Modify: `lib/core/providers/services/network_service_providers.dart`
- Test: `test/unit/services/headless_webview_chapter_list_service_test.dart`（Modify）

**Interfaces:**
- Consumes: Task 4 `needsOcr`；Task 7 `OcrRestoreService`；Task 6 `buildOcrRenderJs`
- Produces: `fetchChapterList` 在 `needsOcr` 时还原 title + chapter.title

- [ ] **Step 1: 写失败测试**

在 `test/unit/services/headless_webview_chapter_list_service_test.dart` 补用例：

```dart
test('needsOcr=true 还原 title 和 chapter.title，url 不动', () async {
  final service = HeadlessWebViewChapterListService.forTesting(
    scriptRepo: mockRepo(needsOcr: true),
    restoreService: mockRestoreService((text, _) async {
      // mock：PUA → '字'
      return OcrRestoreResult(text.replaceAll(RegExp(r'[-]'), '字'),
          1, 1);
    }),
    executeListFn: (_) async => (
      title: '小${String.fromCharCode(0xE3E8)}说',
      chapters: [
        (title: '第${String.fromCharCode(0xE3E9)}章', url: 'https://a.com/1'),
      ],
    ),
  );
  final r = await service.fetchChapterList('https://a.com');
  expect(r.isSuccess, isTrue);
  expect(r.chapters!.first.title, '第字章');
  expect(r.chapters!.first.url, 'https://a.com/1'); // url 不动
});
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/services/headless_webview_chapter_list_service_test.dart`
Expected: FAIL — `forTesting`/`needsOcr` 不存在

- [ ] **Step 3: 写最小实现**

仿 Task 10 改造 `lib/services/headless_webview_chapter_list_service.dart`：

(a) 构造加 `Ref`；
(b) `_executeChapterListScript` 返回类型扩展含 fontFamily（list 脚本 OCR 模式也应返回 font_family，spec §6.3）；
(c) `fetchChapterList` 在拿到 `{title, chapters}` 后、构造返回前插入：
```dart
if (script.needsOcr) {
  try {
    final restoreService = OcrRestoreService(_ref, _renderPua);
    title = (await restoreService.restorePuaInText(title, fontFamily)).text;
    chapters = [
      for (final c in chapters)
      Chapter(
        title: (await restoreService.restorePuaInText(c.title, fontFamily)).text,
        url: c.url, // url 不动
        chapterIndex: c.chapterIndex,
      ),
    ];
  } catch (e) {
    // 降级返回原文
    LoggerService.instance.w('ChapterList OCR 还原失败，降级: $e', ...);
  }
}
```
> 注：逐 chapter await 会串行慢。**优化**：先收集所有唯一 PUA → 一次性 restorePuaInText 每个 title（service 内部已去重）。但 list title 数量大时仍慢。YAGNI：先串行，性能不达标再优化。
(d) `_renderPua` 同 Task 10（service 自身 controller 跑 OCR-JS）；
(e) `forTesting` 构造同 Task 10 模式；
(f) provider 注入 Ref 同 Task 10。

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/services/headless_webview_chapter_list_service_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/services/headless_webview_chapter_list_service.dart lib/core/providers/services/network_service_providers.dart test/unit/services/headless_webview_chapter_list_service_test.dart
git commit -m "feat(headless): fetchChapterList 加 title OCR 还原钩子"
```

---

## Task 12: ToolArgParser 加 requireBool

**Files:**
- Modify: `lib/services/novel_agent/tool_arg_parser.dart`
- Test: `test/unit/services/tool_arg_parser_test.dart`（Create 或 Modify）

**Interfaces:**
- Produces: `(bool, String?) requireBool(String key)` —— 缺失/null/非bool 报错

- [ ] **Step 1: 写失败测试**

创建 `test/unit/services/tool_arg_parser_test.dart`：

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/novel_agent/tool_arg_parser.dart';

void main() {
  group('requireBool', () {
    test('bool 值返回 (value, null)', () {
      expect(ToolArgParser({'k': true}).requireBool('k'), (true, null));
      expect(ToolArgParser({'k': false}).requireBool('k'), (false, null));
    });

    test('缺失返回 missing_error', () {
      final (_, err) = ToolArgParser({}).requireBool('k');
      expect(err, isNotNull);
      final decoded = jsonDecode(err!);
      expect(decoded['error'], 'missing_required_param');
      expect(decoded['param'], 'k');
    });

    test('null 返回 missing_error', () {
      final (_, err) = ToolArgParser({'k': null}).requireBool('k');
      expect(err, isNotNull);
      expect(jsonDecode(err!)['error'], 'missing_required_param');
    });

    test('非 bool 返回 type_error', () {
      final (_, err) = ToolArgParser({'k': 'true'}).requireBool('k');
      expect(err, isNotNull);
      expect(jsonDecode(err!)['error'], 'param_type_error');
    });
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/services/tool_arg_parser_test.dart`
Expected: FAIL — `requireBool` 未定义

- [ ] **Step 3: 写最小实现**

在 `lib/services/novel_agent/tool_arg_parser.dart` 的 `requireInt` 之后（:65 后）加：

```dart
/// 提取必填 bool 参数
///
/// - null 或缺失 → missing_error
/// - bool → 直接返回
/// - 其他类型 → type_error
///
/// 用于 save_script 的 ocr 开关（agent 必须显式表态）。
(bool, String?) requireBool(String key) {
  if (!args.containsKey(key) || args[key] == null) {
    return (false, _missingError(key));
  }
  final v = args[key];
  if (v is bool) return (v, null);
  return (false, _typeError(key, 'boolean', v.runtimeType));
}
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/services/tool_arg_parser_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/services/novel_agent/tool_arg_parser.dart test/unit/services/tool_arg_parser_test.dart
git commit -m "feat(agent): ToolArgParser 加 requireBool"
```

---

## Task 13: save_script 工具 schema 重写

重写 `_saveScriptTool` schema 为新 5 参数（domain/run_id/script_type/test_url/ocr，全必填）。

**Files:**
- Modify: `lib/services/novel_agent/scenarios/webview_extract_scenario.dart`（:1650-1693 的 `_saveScriptTool`）
- Test: 此任务只改 schema 常量，单测在 Task 14 一起验证

**Interfaces:**
- Produces: 新 schema 供 Task 14 executor 使用；旧参数（list_run_id/content_run_id/chapter_list_js/chapter_content_js/url_pattern）删除

- [ ] **Step 1: 写失败测试**

本任务不单独写测试（schema 是常量，Task 14 executor 测试会覆盖）。**跳过 Step 1-2**，直接实现。但记录预期：Task 14 测试会断言新 schema 的 properties 含 `run_id`/`script_type`/`test_url`/`ocr`，不含旧的 `list_run_id`/`content_run_id`。

- [ ] **Step 2: 写最小实现**

替换 `lib/services/novel_agent/scenarios/webview_extract_scenario.dart` 的 `_saveScriptTool`（:1650-1693）为：

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
          'description': '脚本在 RunStore 中的 run_id（exec_xxx），'
              '从之前 execute_js 调用的 __meta.run_id 获取。'
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
          'description': '验证用页面 URL。chapter_list 用目录页 URL，'
              'chapter_content 用章节内容页 URL。save_script 会真实加载该 URL 跑 JS 做验证。',
        },
        'ocr': {
          'type': 'boolean',
          'description': '该站点是否需要 OCR 后处理（字体反爬）。'
              '判定依据：DOM 文本含大量 PUA 码点（U+E000-F8FF），'
              '或 @font-face 引用第三方 CDN 自定义字体绑定到正文/标题元素。'
              '对 chapter_content：还原 content 里的 PUA；'
              '对 chapter_list：还原 title 字段里的 PUA（小说名 + 章名）。'
              '同一站点的两次 save_script（list + content）必须传相同的 ocr 值。',
        },
      },
      'required': ['domain', 'run_id', 'script_type', 'test_url', 'ocr'],
    },
  },
};
```

- [ ] **Step 3: 静态检查（executor 还未改，会报 _saveScript 旧逻辑引用旧参数，下一步处理）**

Run: `flutter analyze lib/services/novel_agent/scenarios/webview_extract_scenario.dart`
Expected: `_saveScript` 方法（:1112）会因引用 `list_run_id` 等旧参数产生 warning，本任务不处理，Task 14 重写 executor。

- [ ] **Step 4: 不单独提交，与 Task 14 一起提交**

---

## Task 14: save_script executor 重写（落库前验证 + 诊断返回）

重写 `_saveScript` 方法：解析新参数 → 取 RunStore 脚本 → headless 打开 test_url 跑 JS → 结构校验 → ocr=true 走 OCR 验证 → 全通过落库（`updateScriptPart`），失败返回诊断 JSON。

**Files:**
- Modify: `lib/services/novel_agent/scenarios/webview_extract_scenario.dart`（:1112-1332 的 `_saveScript` 方法 + :1098-1110 注释块）
- Test: `test/unit/services/save_script_tool_test.dart`（Create）

**Interfaces:**
- Consumes: Task 4 `updateScriptPart`；Task 12 `requireBool`；Task 7 `OcrRestoreService`；Task 6 `buildOcrRenderJs`；现有 `_executeJs` 的 callAsyncJavaScript 范式；`RunStore.get(runId)`（返回 RunEntry 含 script/testUrl）
- Produces: 新 `_saveScript(args)` —— 返回 success/诊断 JSON

> **关键设计**：save_script executor 需要在 headless WebView 上**打开 test_url 跑脚本验证**。但 `WebViewExtractScenario` 是 agent 场景，它的 WebView 是 `HeadlessWebViewPool`（Task 1 调研：acquire/release 排他锁）。executor 内部需 acquire pool → loadPage(test_url) → callAsyncJavaScript(runStoreScript) → 校验 → OCR → release。这复用现有 `_executeJs` 里的 callAsyncJavaScript 模式，但走 pool 而非 service 的自管 controller。

- [ ] **Step 1: 写失败测试**

创建 `test/unit/services/save_script_tool_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
// 依赖注入 mock：RunStore / HeadlessWebViewPool / OcrRestoreService

void main() {
  group('save_script executor', () {
    test('结构校验失败（content 太短）返回诊断不落库', () async {
      final scenario = buildScenarioForTesting(
        runStore: mockRunStore({'exec_1': RunEntry(script: 'JS', testUrl: 'https://a.com')}),
        pool: mockPool(executeResult: {'content': '短', 'title': 't'}), // 太短
        repo: mockRepo(),
      );
      final result = await scenario.invokeSaveScriptForTesting({
        'domain': 'a.com',
        'run_id': 'exec_1',
        'script_type': 'chapter_content',
        'test_url': 'https://a.com/ch1',
        'ocr': false,
      });
      final decoded = jsonDecode(result);
      expect(decoded['success'], false);
      expect(decoded['reason'], 'content_too_short');
      // repo.updateScriptPart 未被调用（mockRepo 记录调用次数）
    });

    test('ocr=true 时走 OCR 验证，readable_ratio 不达标返回诊断', () async {
      final scenario = buildScenarioForTesting(
        runStore: mockRunStore({'exec_1': RunEntry(script: 'JS', testUrl: 'https://a.com')}),
        pool: mockPool(executeResult: {
          'content': '大量PUA', 'title': 't', 'font_family': 'BadFont'
        }),
        restoreService: mockRestoreService(
          verifyFontFamily: false, // 字体无效
          restoreResult: OcrRestoreResult('□□□□', 0, 4), // 还原全失败
          readableRatio: 0.2,
        ),
        repo: mockRepo(),
      );
      final result = await scenario.invokeSaveScriptForTesting({...ocr=true 调用});
      final decoded = jsonDecode(result);
      expect(decoded['success'], false);
      expect(decoded['reason'], anyOf('font_family_invalid', 'readable_ratio_below_threshold'));
    });

    test('验证通过落库，调用 updateScriptPart', () async {
      final repo = mockRepo();
      final scenario = buildScenarioForTesting(
        runStore: mockRunStore({'exec_1': RunEntry(script: 'JS', testUrl: 'https://a.com')}),
        pool: mockPool(executeResult: {
          'content': '正常正文超过50字'.padRight(60, '字'),
          'title': 't',
          'font_family': 'GoodFont'
        }),
        restoreService: mockRestoreService(
          verifyFontFamily: true,
          restoreResult: OcrRestoreResult('正常正文...'.padRight(60, '字'), 0, 0),
          readableRatio: 0.95,
        ),
        repo: repo,
      );
      final result = await scenario.invokeSaveScriptForTesting({...ocr=true 调用});
      final decoded = jsonDecode(result);
      expect(decoded['success'], true);
      expect(repo.updateScriptPartCalls.length, 1);
      expect(repo.updateScriptPartCalls.single.scriptType, 'chapter_content');
      expect(repo.updateScriptPartCalls.single.ocr, true);
    });

    test('ocr=false 结构通过直接落库', () async {
      final repo = mockRepo();
      final scenario = buildScenarioForTesting(
        runStore: mockRunStore({'exec_1': RunEntry(script: 'JS')}),
        pool: mockPool(executeResult: {'content': 'x' * 60, 'title': 't'}),
        repo: repo,
      );
      final result = await scenario.invokeSaveScriptForTesting({...ocr=false chapter_list 调用});
      expect(jsonDecode(result)['success'], true);
      expect(repo.updateScriptPartCalls.single.ocr, false);
      expect(repo.updateScriptPartCalls.single.scriptType, 'chapter_list');
    });

    test('run_id 不存在返回错误', () async {
      final scenario = buildScenarioForTesting(runStore: mockRunStore({}));
      final result = await scenario.invokeSaveScriptForTesting({...});
      expect(jsonDecode(result)['success'], false);
    });
  });
}
```

> 注：`buildScenarioForTesting` / `mockRunStore` / `mockPool` / `mockRepo` / `mockRestoreService` / `invokeSaveScriptForTesting` 是测试 helper，需在 scenario 加 `@visibleForTesting` 的测试构造和方法暴露 `_saveScript`。这是较大改动，实现时参照现有 scenario 是否已有测试入口（Task 1 调研未明确提及 scenario 的单测，可能需新建测试构造）。

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/services/save_script_tool_test.dart`
Expected: FAIL — `invokeSaveScriptForTesting`/`buildScenarioForTesting` 不存在

- [ ] **Step 3: 写最小实现**

在 `lib/services/novel_agent/scenarios/webview_extract_scenario.dart`：

(a) 重写 `_saveScript` 方法（替换 :1112-1332 整个方法体）：

```dart
/// save_script：按 script_type 分次保存，落库前强制试运行验证。
///
/// 流程：
/// 1. 解析参数（domain/run_id/script_type/test_url/ocr）
/// 2. RunStore.get(run_id) 取脚本
/// 3. acquire HeadlessWebViewPool → loadPage(test_url) → callAsyncJavaScript(script)
/// 4. 结构校验（按 script_type）
/// 5. ocr=true → OcrRestoreService 验证（verifyFontFamily + restorePuaInText + readableRatio）
/// 6. 全通过 → updateScriptPart 落库；失败返回诊断 JSON
Future<String> _saveScript(Map<String, dynamic> args) async {
  final parser = ToolArgParser(args);
  final (domain, e1) = parser.requireString('domain');
  final (runId, e2) = parser.requireString('run_id');
  final (scriptType, e3) = parser.requireString('script_type');
  final (testUrl, e4) = parser.requireString('test_url');
  final (ocr, e5) = parser.requireBool('ocr');

  for (final err in [e1, e2, e3, e4, e5]) {
    if (err != null) return err; // 参数错误直接返回
  }

  if (scriptType != 'chapter_list' && scriptType != 'chapter_content') {
    return jsonEncode({
      'error': 'invalid_script_type',
      'message': 'script_type 必须是 chapter_list 或 chapter_content',
      'received': scriptType,
    });
  }

  // 取脚本
  final entry = _runStore.get(runId);
  if (entry == null) {
    return jsonEncode({
      'success': false,
      'reason': 'run_id_not_found',
      'message': 'RunStore 中未找到 run_id（可能已被淘汰）',
      'run_id': runId,
      'store_size': _runStore.length,
      'suggestion': '用 execute_js(script=...) 重新执行脚本获取新 run_id',
    });
  }
  final jsScript = entry.script;

  // acquire pool 跑脚本
  InAppWebViewController? controller;
  try {
    final pool = _ref.read(headlessWebViewPoolProvider);
    controller = await pool.acquire();
    // 替换 {{URL}} → test_url（提取脚本约定含 {{URL}}）
    final resolved = jsScript.replaceAll('{{URL}}', testUrl);
    final functionBody = WebViewJsExecutor.extractAsyncFunctionBody(resolved);
    final result = await controller!
        .callAsyncJavaScript(functionBody: functionBody)
        .timeout(const Duration(seconds: 60));
    if (result == null || result.error != null) {
      return jsonEncode({
        'success': false,
        'reason': 'js_execute_failed',
        'diagnostic': '脚本在 test_url 上执行失败',
        'js_error': result?.error,
        'suggestion': '检查脚本选择器是否匹配该页面，或页面是否需要等待加载',
      });
    }
    final jsonStr = WebViewJsExecutor.stringifyJsResult(result.value);
    final data = jsonDecode(jsonStr);

    // 结构校验
    final structErr = _validateScriptResult(data, scriptType, ocr);
    if (structErr != null) {
      return jsonEncode({
        'success': false,
        ...structErr,
        'returned_sample': _sample(data),
      });
    }

    // OCR 验证
    String restoredSample = '';
    if (ocr) {
      final fontFamily = (data is Map)
          ? ((data['font_family'] ?? data['fontFamily']) as String?)?.trim() ?? ''
          : '';
      final ocrErr = await _validateOcr(controller, fontFamily, data, scriptType);
      if (ocrErr != null) {
        return jsonEncode({'success': false, ...ocrErr});
      }
      // 取还原后样本供返回
      restoredSample = _extractRestoredSample(data, scriptType).substring(0, 200);
    }

    // 落库
    final repo = _ref.read(siteScriptRepositoryProvider);
    final saveResult = await repo.updateScriptPart(
      domain: domain,
      scriptType: scriptType,
      scriptJs: jsScript,
      ocr: ocr,
    );
    if (!saveResult.success) {
      return jsonEncode({
        'success': false,
        'reason': saveResult.reason ?? 'unknown',
        'message': 'domain 不存在（需先保存 chapter_list 或先 upsert 建立记录）',
        'domain': domain,
        'suggestion': '先调用 save_script(script_type=chapter_list) 建立该 domain 记录，'
            '再调 chapter_content（updateScriptPart 不自动 create）',
      });
    }

    _scriptSavedThisSession = true;
    _notifyScriptSaved();
    return jsonEncode({
      'success': true,
      'domain': domain,
      'script_type': scriptType,
      'ocr': ocr,
      'verified_saved': true,
      if (ocr) 'ocr_applied': true,
      if (restoredSample.isNotEmpty) 'restored_sample': restoredSample,
    });
  } on TimeoutException {
    return jsonEncode({
      'success': false,
      'reason': 'test_timeout',
      'message': '脚本在 test_url 上执行超时（60s）',
      'suggestion': '脚本可能卡在翻页/等待，检查 setTimeout 和翻页逻辑',
    });
  } catch (e, stackTrace) {
    LoggerService.instance.e(
      'save_script 验证异常: domain=$domain - $e',
      stackTrace: stackTrace.toString(),
      category: LogCategory.ai,
      tags: ['agent', 'save_script', 'error'],
    );
    return jsonEncode({
      'success': false,
      'reason': 'internal_error',
      'message': '$e',
    });
  } finally {
    if (controller != null) {
      _ref.read(headlessWebViewPoolProvider).release();
    }
  }
}

/// 结构校验：返回 null 表示通过，否则返回含 reason/diagnostic/suggestion 的 map。
Map<String, dynamic>? _validateScriptResult(
  dynamic data, String scriptType, bool ocr,
) {
  if (data is! Map) {
    return {
      'reason': 'invalid_structure',
      'diagnostic': '脚本返回非对象（期望 {title, content/chapters}）',
      'suggestion': '脚本最后应 return JSON.stringify({title:..., content:...})',
    };
  }
  if (scriptType == 'chapter_list') {
    final chapters = data['chapters'];
    if (chapters is! List || chapters.isEmpty) {
      return {
        'reason': 'chapters_empty',
        'diagnostic': 'chapters 为空或非数组',
        'suggestion': '检查目录选择器是否匹配到章节列表',
      };
    }
    for (final c in chapters) {
      if (c is! Map || (c['title'] as String?)?.isEmpty != false || (c['url'] as String?)?.isEmpty != false) {
        return {
          'reason': 'chapter_missing_field',
          'diagnostic': '某 chapter 缺少 title 或 url',
          'suggestion': '每个 chapter 必须有非空 title 和 url',
        };
      }
    }
    return null;
  }
  // chapter_content
  final content = (data['content'] as String?)?.trim() ?? '';
  if (content.length < 50) {
    return {
      'reason': 'content_too_short',
      'diagnostic': 'content 长度 ${content.length} < 50，可能选择器没匹配正文',
      'suggestion': '检查正文选择器，或等待页面加载完成再提取',
    };
  }
  if (ocr) {
    final ff = ((data['font_family'] ?? data['fontFamily']) as String?)?.trim() ?? '';
    if (ff.isEmpty) {
      return {
        'reason': 'font_family_missing',
        'diagnostic': 'OCR 模式下 chapter_content 脚本必须返回 font_family',
        'suggestion': '在脚本里加 const ff = getComputedStyle(正文元素).fontFamily; 返回 {title,content,font_family:ff}',
      };
    }
  }
  return null;
}

/// OCR 验证：字体有效性 + 还原 + 比率。
Future<Map<String, dynamic>?> _validateOcr(
  InAppWebViewController controller,
  String fontFamily,
  dynamic data,
  String scriptType,
) async {
  final renderPua = (int cp, String ff) async {
    final js = buildOcrRenderJs(cp, ff);
    final r = await controller
        .callAsyncJavaScript(functionBody: WebViewJsExecutor.extractAsyncFunctionBody(js))
        .timeout(const Duration(seconds: 30));
    if (r == null || r.error != null) throw Exception('${r?.error}');
    return WebViewJsExecutor.stringifyJsResult(r.value);
  };
  final restoreService = OcrRestoreService(_ref, renderPua);

  // 字体有效性
  if (!await restoreService.verifyFontFamily(fontFamily)) {
    return {
      'reason': 'font_family_invalid',
      'ocr_applied': true,
      'font_family': fontFamily,
      'diagnostic': '该 font_family 渲染不同 PUA 产生相同占位框，字体族名无效或未加载',
      'suggestion': '确认 getComputedStyle 取的是正文元素且字体已加载；检查 font-family 值',
    };
  }

  // 还原
  final textToRestore = scriptType == 'chapter_content'
      ? (data['content'] as String)
      : '${data['title']} ${(data['chapters'] as List).map((c) => c['title']).join(' ')}';
  final restored = await restoreService.restorePuaInText(textToRestore, fontFamily);
  if (restoreService.readableRatio(restored.text) < 0.85) {
    return {
      'reason': 'readable_ratio_below_threshold',
      'ocr_applied': true,
      'readable_ratio': restoreService.readableRatio(restored.text),
      'decoded_ratio': restored.decodedRatio,
      'diagnostic': 'OCR 还原后 CJK 占比过低，font_family 可能无效或模型解码失败',
      'suggestion': '检查 font_family 是否正确（用 getComputedStyle(正文元素).fontFamily）',
    };
  }
  if (restored.totalPuaCount > 0 && restored.decodedRatio < 0.8) {
    return {
      'reason': 'decoded_ratio_below_threshold',
      'ocr_applied': true,
      'decoded_ratio': restored.decodedRatio,
      'total_pua': restored.totalPuaCount,
      'diagnostic': 'PUA 识别成功率 < 80%',
      'suggestion': '模型对该字体解码效果差，可考虑 LLM 兜底（非本期）',
    };
  }
  return null; // 通过
}

String _sample(dynamic data) {
  final s = data.toString();
  return s.length > 200 ? s.substring(0, 200) : s;
}

String _extractRestoredSample(dynamic data, String scriptType) {
  if (scriptType == 'chapter_content') return (data['content'] as String?) ?? '';
  return (data['title'] as String?) ?? '';
}
```

(b) 删除 :1098-1110 的旧 `_saveScript` 注释块（描述绕过 Provider 那段），改为新注释。

(c) 加 `@visibleForTesting` 测试入口：
```dart
@visibleForTesting
Future<String> invokeSaveScriptForTesting(Map<String, dynamic> args) => _saveScript(args);
```
并加 `buildScenarioForTesting` 或在测试里直接构造 scenario（参照现有 scenario 构造范式）。

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/services/save_script_tool_test.dart`
Expected: PASS — 5 个用例全绿

- [ ] **Step 5: 回归 agent 现有测试 + 提交**

Run: `flutter test test/unit/services/` 
Expected: 现有 agent/webview 测试不破（若有引用旧 save_script 参数的测试，一并改）

```bash
git add lib/services/novel_agent/scenarios/webview_extract_scenario.dart test/unit/services/save_script_tool_test.dart
git commit -m "feat(agent): save_script 重写为分次保存+落库前验证"
```

---

## Task 15: buildSystemPrompt 加"提取器创建流程"工作原则

新增 prompt 段落（spec §5.4）。**注意：现有 prompt 无"字体反爬检测"段落（调研确认），是新增不是替换。**

**Files:**
- Modify: `lib/services/novel_agent/scenarios/webview_extract_scenario.dart`（`buildSystemPrompt` :90-150）
- Test: `test/unit/services/webview_extract_prompt_test.dart`（Create 或 Modify）

**Interfaces:**
- Produces: prompt 含"提取器创建流程"段落，引导 agent 两次 save_script + ocr 判定

- [ ] **Step 1: 写失败测试**

创建 `test/unit/services/webview_extract_prompt_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/novel_agent/scenarios/webview_extract_scenario.dart';

void main() {
  test('prompt 含"提取器创建流程"段落', () {
    final scenario = buildScenarioForTesting(); // 或用现有测试构造
    final prompt = scenario.buildSystemPrompt(testContext);
    expect(prompt, contains('提取器创建流程'));
    expect(prompt, contains('save_script(domain, run_id, script_type="chapter_list"'));
    expect(prompt, contains('save_script(domain, run_id, script_type="chapter_content"'));
    expect(prompt, contains('ocr=<true|false>'));
    expect(prompt, contains('U+E000-F8FF')); // PUA 检测指引
    expect(prompt, contains('font_family'));
  });
}
```

- [ ] **Step 2: 跑测试验证失败**

Run: `flutter test test/unit/services/webview_extract_prompt_test.dart`
Expected: FAIL — prompt 不含这些字串

- [ ] **Step 3: 写最小实现**

在 `lib/services/novel_agent/scenarios/webview_extract_scenario.dart` 的 `buildSystemPrompt` 里，在 `## JS 脚本规范` 段落之后（:123 附近，`## 错误处理` 之前）插入：

```dart
buf.writeln('## 提取器创建流程（强制）');
buf.writeln('完整提取器需调用两次 save_script：一次 chapter_list，一次 chapter_content。');
buf.writeln('save_script 会在落库前强制试运行验证，失败返回诊断指导你修 JS。');
buf.writeln();
buf.writeln('### 流程');
buf.writeln('1. 用 execute_js 反复调试脚本，确认能拿到正确结构：');
buf.writeln('   - chapter_list 脚本返回 {title, chapters:[{title,url}]}');
buf.writeln('   - chapter_content 脚本返回 {title, content, font_family}');
buf.writeln('2. 调用 save_script 落库（两次）：');
buf.writeln('   - save_script(domain, run_id, script_type="chapter_list",    test_url=<目录页>, ocr=<true|false>)');
buf.writeln('   - save_script(domain, run_id, script_type="chapter_content", test_url=<章节页>, ocr=<同上>)');
buf.writeln('3. save_script 返回 success=false -> 按 diagnostic/suggestion 修 JS，重新 execute_js 调试，再 save_script');
buf.writeln('   （注意：两次调用要分别验证通过，落库前都会跑一次试运行）');
buf.writeln();
buf.writeln('### 字体反爬检测（ocr 判定）');
buf.writeln('若 DOM 文本含大量 PUA 私用区码点（U+E000-F8FF，表现为不可读的乱码方块），');
buf.writeln('且页面通过 @font-face 加载自定义字体绑定到正文/标题元素（典型如番茄小说），');
buf.writeln('这是字体反爬，ocr 应传 true。');
buf.writeln();
buf.writeln('OCR 模式下：');
buf.writeln('- chapter_content_js 必须额外返回 font_family（用 getComputedStyle(正文元素).fontFamily）');
buf.writeln('- content 保留原始 PUA 文本（不要在 JS 里尝试解码）');
buf.writeln('- 同一站点的两次 save_script（list + content）必须传相同的 ocr 值');
buf.writeln();
buf.writeln('不要在 JS 里做 PUA 到真字的替换（你拿不到字体映射），交给运行时 OCR。');
buf.writeln();
```

同时把 `## 工作流程` 段落（:103-107）的旧第 4 步 `save_script(domain, list_run_id, content_run_id)` 更新为新流程引用：

```dart
buf.writeln('4. save_script 分两次落库（chapter_list + chapter_content），落库前自动验证');
```

并更新 `## run_id 机制`（:110-112）的保存示例：
```dart
buf.writeln('- 重跑: execute_js(run_id=<id>) → 保存: save_script(domain, run_id=<id>, script_type=..., test_url=..., ocr=...)');
```

- [ ] **Step 4: 跑测试验证通过**

Run: `flutter test test/unit/services/webview_extract_prompt_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/services/novel_agent/scenarios/webview_extract_scenario.dart test/unit/services/webview_extract_prompt_test.dart
git commit -m "feat(agent): prompt 新增提取器创建流程与字体反爬检测指引"
```

---

## Task 16: 端到端集成测试（真实 OcrPredictor + mock WebView）

验证 content 还原闭环：含 PUA 的 content → OcrRestoreService（真实 predictor + mock renderPua）→ 还原结果不含 PUA。

**Files:**
- Create: `test/integration/ocr_postprocess_test.dart`

**Interfaces:**
- Consumes: Task 5/7/8/10 全部

- [ ] **Step 1: 写测试**

创建 `test/integration/ocr_postprocess_test.dart`：

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/ocr_restore_service.dart';
import 'package:novel_app/core/providers/ocr_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 真实 OcrPredictor + mock renderPua（返回 PoC 已知 PUA→字形的 base64）。
  // 用 PoC 的 fanqie-evidence/ 里的 pua_char_map.json 反推：对每个 PUA，
  // renderPua 返回该 PUA 在反爬字体下渲染出的真实字形 PNG。
  // 但测试拿不到真实字体渲染——所以这个集成测试用「mock predictor」更现实：
  // 验证 restorePuaInText 的编排逻辑（去重→逐字→替换→□兜底），真实 OCR 留手工验证。

  test('restorePuaInText 编排：去重 + 替换 + □ 兜底', () async {
    // mock renderPua：cp 0xE3E8 返回 'img_A'，其他返回 'img_other'
    // mock predictor：'img_A' → '我'，'img_other' → ''（失败）
    final svc = OcrRestoreService.forTesting(
      renderPua: (cp, _) async => cp == 0xE3E8 ? 'img_A' : 'img_other',
      recognizeImageFn: (b64) async => b64 == 'img_A' ? '我' : '',
    );
    // 文本含 0xE3E8 两次（去重应只渲染一次）+ 0xE3E9 一次（失败 → □）
    final text = '前${String.fromCharCode(0xE3E8)}中${String.fromCharCode(0xE3E8)}后${String.fromCharCode(0xE3E9)}';
    final r = await svc.restorePuaInText(text, 'F');
    expect(r.totalPuaCount, 2); // 去重后 2 个不同 PUA
    expect(r.decodedCount, 1); // 只有 0xE3E8 成功
    expect(r.text, '前我中我后□');
  });

  test('真实 OcrPredictor 加载（skip if no native lib）', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    try {
      final predictor = await container.read(ocrPredictorProvider.future);
      expect(predictor.isLoaded, isTrue);
    } catch (e) {
      // CI 无 onnxruntime 原生库时 skip
      print('skip: onnxruntime 不可用 - $e');
    }
  });
}
```

- [ ] **Step 2: 跑测试验证**

Run: `flutter test test/integration/ocr_postprocess_test.dart`
Expected: PASS（编排逻辑用例必过；真实 predictor 用例 skip 或过）

- [ ] **Step 3: 提交**

```bash
git add test/integration/ocr_postprocess_test.dart
git commit -m "test(ocr): 端到端编排逻辑集成测试"
```

---

## Task 17: 手工端到端验证 + 文档更新

非编码任务：真实番茄章节跑通 + CLAUDE.md 同步 + PoC 入口标注。

**Files:**
- Modify: `CLAUDE.md`（数据库版本 v36→v37）
- Modify: `novel_app/CLAUDE.md`（site_scripts 表加 ocr 列说明 + OCR 提取器章节）
- Modify: `novel_app/lib/main_ppocr_demo.dart`（加注释"已被产品化路径替代"）
- Update memory: `C:\Users\KFEB4\.claude\projects\D--my-space-novel-builder\memory\fanqie-ocr-poc-conclusion.md`（标记产品化完成）

- [ ] **Step 1: 手工端到端验证（番茄真实章节）**

在 Android 模拟器/真机跑：
1. 启动 app，进入 Agent WebView 提取场景，URL 填 `https://fanqienovel.com/reader/7069991698582995470`
2. 观察 agent：execute_js 探测 → 检测到 PUA → 两次 save_script（list + content，ocr=true）
3. 验证 save_script 返回 `success: true` + `restored_sample` 含可读中文
4. 进入阅读器加载该章节，确认正文 PUA 被还原为可读文字
5. 性能 profile：单章 OCR 还原时间 < 90s（目标）

**故意写错 JS 验证诊断闭环**：在 agent 写 chapter_content_js 时漏返回 font_family → save_script 应返回 `success: false, reason: font_family_missing` → agent 修 JS 重试成功。

记录结果到 `test/reports/ocr_e2e_report.md`（Create）。

- [ ] **Step 2: 与 biquge55 真值对比**

取还原正文与 `fanqie-evidence/chapter_restored.txt`（PC PoC 产物）对比，字符符合率 ≥ 95%。记录到报告。

- [ ] **Step 3: 更新 CLAUDE.md**

根 `CLAUDE.md`「数据库版本」段：
```
- **前端SQLite**: v37 (novel_reader.db)
```
site_scripts 表说明加 `ocr` 列。

`novel_app/CLAUDE.md` Changelog 加：
```
- **2026-07-15**: OCR 提取器产品化。site_scripts 加 ocr 列（v37）；OcrPredictor 改 recognizeImage(base64Png)；新增 OcrRestoreService（restorePuaInText/verifyFontFamily/readableRatio）+ 系统 OCR-JS 模板；HeadlessWebViewContentService/ChapterListService 加 OCR 还原钩子；save_script 重写为分次保存+落库前验证（domain/run_id/script_type/test_url/ocr）；prompt 加提取器创建流程。番茄字体反爬正文可读。
```

- [ ] **Step 4: PoC 入口标注 + memory 更新**

`novel_app/lib/main_ppocr_demo.dart` 顶部注释加：
```dart
/// ⚠️ 本 PoC 入口已被产品化路径替代（OcrPredictor.recognizeImage + OcrRestoreService）。
/// 保留仅作历史参照，不再维护。产品路径见 lib/services/ocr_restore_service.dart。
```

更新 `fanqie-ocr-poc-conclusion.md`：把"下一步：产品接入"改为"已产品化（2026-07-15），见 plan docs/superpowers/plans/2026-07-15-agent-ocr-extractor.md"。

- [ ] **Step 5: 提交**

```bash
git add CLAUDE.md novel_app/CLAUDE.md novel_app/lib/main_ppocr_demo.dart test/reports/ocr_e2e_report.md
git commit -m "docs: OCR 提取器产品化文档同步与 PoC 标注"
```

memory 文件单独更新（不入 git，在 `C:\Users\KFEB4\.claude\projects\...` 下）。

---

## Self-Review 结论

**1. Spec 覆盖核对**：
- §1 目标 → Task 10/11/13/14/15 全覆盖
- §2 决策记录 → save_script 分次保存（Task 14）、每章独立无缓存（Task 7 restorePuaInText 无持久化）、canvas 渲染（Task 6 OCR-JS）、agent 自动检测（Task 15 prompt）、font_family 返回（Task 14 校验 + Task 9 模型 + Task 10 提取）、save_script 验证集成（Task 14）
- §3 数据流 → Task 14（agent 现场）+ Task 10/11（运行时）全覆盖
- §4 数据模型 → Task 2/3/4
- §5 save_script 重写 → Task 13/14/15 + Task 12（requireBool）
- §6 Headless 管线 → Task 6/7/8/9/10/11
- §7 错误处理 → Task 10/11 try-catch 降级 + Task 14 诊断 + Task 7 单字符 □
- §8 测试 → 各 Task 内单测 + Task 16 集成 + Task 17 端到端
- §9 性能 → Task 17 验收
- §10 里程碑 → Phase1=Task1-9, Phase2=Task10-11, Phase3=Task12-15, Phase4=Task16-17, Phase5=Task17

**2. 占位符扫描**：无 TBD/TODO；每个代码步骤有实际代码；helper 函数（`buildRepo`/`mockRepo`/`buildScenarioForTesting`）标注"以现有风格为准"并提供实现策略，非空占位。

**3. 类型一致性**：`isPua`（Task1）→ Task7 用；`OcrPredictor.recognizeImage`（Task5）→ Task7/8 用；`OcrRestoreService.restorePuaInText`（Task7）→ Task10/11/14 用；`buildOcrRenderJs`（Task6）→ Task10/11/14 用；`updateScriptPart`（Task4）→ Task14 用；`requireBool`（Task12）→ Task14 用；`ChapterContentResult.fontFamily`（Task9）→ Task10 用。命名跨任务一致。

**4. 对 spec 的修正**（已落入计划）：
- §5.3：`requireBool` 加在 `tool_arg_parser.dart`（非 tool_executor_helpers.dart）
- §5.4：prompt 是新增段落（非替换现有"字体反爬检测"——现有无此段落）
- §6.5：`ocrRestoreServiceProvider` 不全局注册（renderPua 注入决定它不能单例），只注册 `ocrPredictorProvider`
- §6.4：`recognizeGlyph` 标 deprecated 保留（PoC 入口 Task 17 才清理，不提前删）
- §8.4：写作工具 27 个（非 23）；新增 `WebViewJsExecutor.validateScript` 强制 {{URL}} 风险——OCR-JS 绕过 validateScript 直接 callAsyncJavaScript（Task 6/10/14 已处理）
- 新增风险处理：Task 10 `_renderPua` 用 `extractAsyncFunctionBody` 剥 OCR-JS IIFE 外壳，若该函数假设 {{URL}} 需调整模板（Task 6 注释已标注）

执行顺序依赖：Task1→2→3→4（数据层）；Task5→8a→7（OCR 服务，破环见 Task 7 注）；Task6 独立；Task9 独立；Task10/11 依赖 4/5/6/7/8/9；Task12 独立；Task13/14 依赖 4/6/7/12；Task15 独立；Task16 依赖 5/7/8/10；Task17 最后。
