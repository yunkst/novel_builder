# 全部小说书架"加入书架"语义修复 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复"全部小说"虚拟书架下的"移动图书失败"硬错误，并把 UI 中冗余的"移动/复制"两条菜单合并为单一"加入书架"入口。

**Architecture:** Repository 层放宽 `moveNovelToBookshelf` 在 `from=1` 时的特例（从抛错改为 add-only）；UI 层在 `currentBookshelfId==1` 时把"移动/复制"两条菜单合并为"加入书架"，内部走 `copyToBookshelf`。`BookshelfMutationNotifier` 不变，仍是统一收口。

**Tech Stack:** Flutter / Dart / Riverpod / SQLite (sqflite + sqflite_common_ffi 测试) / Dart Test

## Global Constraints

- 仓库根目录: `D:\my_space\novel_builder`
- Flutter 模块: `novel_app/`
- 所有 Flutter 命令从 `novel_app/` 目录执行
- 测试基建: `sqflite_common_ffi` (Repository 测试) + 手写 fake writer (Notifier 测试) + Widget 测试
- 提交规范遵循根 `CLAUDE.md` 中的中文 commit 规范
- 不新增依赖,不动 `pubspec.yaml`
- 不改 DB schema,不动 `database_migrations.dart`
- Riverpod 代码生成:任何 `@riverpod` 注解变更需 `dart run build_runner build --delete-conflicting-outputs`

---

## Task 1: Repository 层 — `moveNovelToBookshelf` 放宽 `from=1` 特例

**Files:**
- Modify: `novel_app/lib/repositories/bookshelf_repository.dart:361-396` (`moveNovelToBookshelf` 方法体)
- Test: `novel_app/test/unit/repositories/bookshelf_repository_move_all_novels_test.dart` (新建)

**Interfaces:**
- Consumes: `BookshelfRepository.moveNovelToBookshelf(String novelUrl, int fromBookshelfId, int toBookshelfId)` 签名不变
- Produces:
  - `from=1, to>=2`: 不抛错,只调 `addNovelToBookshelf(to)`,跳过 `removeNovelFromBookshelf(from)`;返回 `Future<void>`
  - `from>=2, to=1`: 仍抛 `ArgumentError('不能移动到"全部小说"虚拟书架')` (防御性断言)
  - `from>=2, to>=2`: 行为不变 (回归)
  - `from == to`: 早 return 不变 (回归)

- [ ] **Step 1: 写失败测试 — from=1 to=2 成功(不抛错)**

创建 `novel_app/test/unit/repositories/bookshelf_repository_move_all_novels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_reader/core/database/database_connection.dart';
import 'package:novel_reader/repositories/bookshelf_repository.dart';
import 'package:novel_reader/repositories/novel_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late BookshelfRepository repo;
  late NovelRepository novelRepo;
  late Database db;

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE bookshelf (url TEXT PRIMARY KEY, title TEXT, author TEXT, coverUrl TEXT, coverMediaId TEXT, description TEXT, background_setting TEXT, lastReadChapter INTEGER, lastReadTime INTEGER, addedAt INTEGER)');
      await db.execute('CREATE TABLE bookshelves (id INTEGER PRIMARY KEY, name TEXT, icon TEXT, color TEXT, sort_order INTEGER, is_system INTEGER)');
      await db.execute('CREATE TABLE novel_bookshelves (novel_url TEXT, bookshelf_id INTEGER, created_at INTEGER, PRIMARY KEY (novel_url, bookshelf_id))');
      await db.execute("INSERT INTO bookshelves (id, name, is_system) VALUES (1, '全部小说', 1), (2, '玄幻', 0)");
    });
    final conn = _FakeConnection(db);
    repo = BookshelfRepository(databaseConnection: conn);
    novelRepo = NovelRepository(databaseConnection: conn);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> _seedNovel() async {
    await db.insert('bookshelf', {
      'url': 'https://example.com/novel/1',
      'title': '测试书',
      'author': '作者',
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  test('move from 全部小说(1) to 玄幻(2) 不抛错且关联表加一行', () async {
    await _seedNovel();
    // 初始: novel_bookshelves 应为空(id=1 是虚拟书架,不写关联)
    final before = await db.query('novel_bookshelves');
    expect(before, isEmpty);

    // from=1 不再抛错
    await repo.moveNovelToBookshelf('https://example.com/novel/1', 1, 2);

    // 关联表应有一行 (novel_url, 2)
    final after = await db.query('novel_bookshelves');
    expect(after, hasLength(1));
    expect(after.first['novel_url'], 'https://example.com/novel/1');
    expect(after.first['bookshelf_id'], 2);

    // bookshelf 表小说行不动
    final novel = await db.query('bookshelf', where: 'url = ?', whereArgs: ['https://example.com/novel/1']);
    expect(novel, hasLength(1));
  });
}

class _FakeConnection implements DatabaseConnection {
  _FakeConnection(this._db);
  final Database _db;
  @override
  Future<Database> get database async => _db;
}
```

> 注:`DatabaseConnection` 实际是类(class),不是接口。如果当前实现不是 interface,把 `_FakeConnection` 改成继承 `DatabaseConnection` 并 override `database` getter(查看 `lib/core/database/database_connection.dart` 实际签名)。若构造函数要求 token,适配之。

- [ ] **Step 2: 跑测试,确认失败(期望抛 ArgumentError)**

```bash
cd novel_app && flutter test test/unit/repositories/bookshelf_repository_move_all_novels_test.dart
```

Expected: FAIL — `ArgumentError: 不能从/到"全部小说"书架移动小说` (来自现有代码 `:370-372`)

- [ ] **Step 3: 改 Repository 实现**

`novel_app/lib/repositories/bookshelf_repository.dart` 第 361-396 行,把:

```dart
if (fromBookshelfId == 1 || toBookshelfId == 1) {
  throw ArgumentError('不能从/到"全部小说"书架移动小说');
}

if (fromBookshelfId == toBookshelfId) {
  LoggerService.instance.w('原书架和目标书架相同，无需移动', ...);
  return;
}

// 先添加到目标书架
await addNovelToBookshelf(novelUrl, toBookshelfId);

// 再从原书架移除
final removed = await removeNovelFromBookshelf(novelUrl, fromBookshelfId);
```

改成:

```dart
// to=1 是虚拟书架"全部小说",无关联可加;UI 选择对话框已过滤 id=1,
// 保留此断言作为防御性兜底,防止未来其他调用方误用。
if (toBookshelfId == 1) {
  throw ArgumentError('不能移动到"全部小说"虚拟书架');
}

if (fromBookshelfId == toBookshelfId) {
  LoggerService.instance.w('原书架和目标书架相同，无需移动', ...);
  return;
}

// 先添加到目标书架
await addNovelToBookshelf(novelUrl, toBookshelfId);

// from=1 是虚拟书架"全部小说",无关联可删(removeNovelFromBookshelf(_, 1) 本就 no-op),
// 跳过以避免无意义的 warning 日志。等价于"加入目标书架,书仍留在全部小说"。
if (fromBookshelfId != 1) {
  final removed = await removeNovelFromBookshelf(novelUrl, fromBookshelfId);

  if (removed) {
    LoggerService.instance.i('移动小说: $novelUrl 从书架 $fromBookshelfId 到书架 $toBookshelfId', ...);
  } else {
    LoggerService.instance.i('加入小说: $novelUrl 到书架 $toBookshelfId (来源:虚拟书架 $fromBookshelfId)', ...);
  }
} else {
  LoggerService.instance.i('加入小说: $novelUrl 到书架 $toBookshelfId (来源:虚拟书架 全部小说)', ...);
}
```

- [ ] **Step 4: 跑测试,确认通过**

```bash
cd novel_app && flutter test test/unit/repositories/bookshelf_repository_move_all_novels_test.dart
```

Expected: PASS

- [ ] **Step 5: 补充 to=1 仍抛错的测试用例**

在同一个测试文件 `bookshelf_repository_move_all_novels_test.dart` 中加:

```dart
test('move to 全部小说(1) 仍抛 ArgumentError(防御性断言)', () async {
  await _seedNovel();
  // 先把小说加到书架 2
  await repo.addNovelToBookshelf('https://example.com/novel/1', 2);

  expect(
    () => repo.moveNovelToBookshelf('https://example.com/novel/1', 2, 1),
    throwsA(isA<ArgumentError>()),
  );
});
```

跑测试确认仍通过。

- [ ] **Step 6: 补充 from>=2 to>=2 回归用例**

在同一个文件中加:

```dart
test('move from 玄幻(2) to 都市(3) 回归正常 add+remove', () async {
  await db.insert('bookshelves', {'id': 3, 'name': '都市', 'is_system': 0});
  await _seedNovel();
  await repo.addNovelToBookshelf('https://example.com/novel/1', 2);

  await repo.moveNovelToBookshelf('https://example.com/novel/1', 2, 3);

  final rows = await db.query('novel_bookshelves', where: 'novel_url = ?', whereArgs: ['https://example.com/novel/1']);
  expect(rows, hasLength(1));
  expect(rows.first['bookshelf_id'], 3);
});

test('move from == to 早 return 无副作用', () async {
  await _seedNovel();
  await repo.addNovelToBookshelf('https://example.com/novel/1', 2);

  await repo.moveNovelToBookshelf('https://example.com/novel/1', 2, 2);

  final rows = await db.query('novel_bookshelves', where: 'novel_url = ?', whereArgs: ['https://example.com/novel/1']);
  expect(rows, hasLength(1));
  expect(rows.first['bookshelf_id'], 2);
});
```

跑测试,确认全部通过。

- [ ] **Step 7: Commit**

```bash
git add novel_app/lib/repositories/bookshelf_repository.dart novel_app/test/unit/repositories/bookshelf_repository_move_all_novels_test.dart
git commit -m "fix(bookshelf): moveNovelToBookshelf 允许 from=全部小说(降级 add-only)"
```

---

## Task 2: Notifier 层 — 验证 `moveToBookshelf` 在 from=1 时透传成功

**Files:**
- Test: `novel_app/test/unit/providers/bookshelf_mutation_move_all_novels_test.dart` (新建)

**Interfaces:**
- Consumes: `BookshelfMutationNotifier.moveToBookshelf(String novelUrl, int fromBookshelfId, int toBookshelfId)` 签名不变(来自 `bookshelf_mutation_provider.dart:88`)
- Produces: 透传到 `IBookshelfAssociationWriter.moveNovelToBookshelf`,成功后 `ref.invalidate(bookshelfNovelsProvider)`

> Task 1 已在 Repository 层实现 from=1 降级。本任务不修改 Notifier,只补一个 Notifier 单测确认 Notifier 透传+invalidate 在 from=1 时行为正确。

- [ ] **Step 1: 写失败测试**

查看现有 Notifier 测试文件结构(很可能是 `novel_app/test/unit/providers/bookshelf_mutation_provider_test.dart`),参照其 fake writer 模式。在新文件 `novel_app/test/unit/providers/bookshelf_mutation_move_all_novels_test.dart` 写:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/core/providers/bookshelf_mutation_provider.dart';
import 'package:novel_reader/core/providers/bookshelf_providers.dart';
import 'package:novel_reader/core/interfaces/repositories/i_bookshelf_repository.dart';
import 'package:novel_reader/repositories/bookshelf_repository.dart';
import 'package:novel_reader/repositories/novel_repository.dart';

void main() {
  test('moveToBookshelf from=1 to=2 透传成功 + invalidate', () async {
    final fakeAssoc = _FakeAssociationWriter();
    final container = ProviderContainer(overrides: [
      bookshelfAssociationWriterProvider.overrideWithValue(fakeAssoc),
      // bookshelfWriterProvider 需 override,允许返回 dummy
      bookshelfWriterProvider.overrideWithValue(_FakeWriter()),
      novelRepositoryProvider.overrideWithValue(_FakeNovelRepo()),
      bookshelfRepositoryProvider.overrideWithValue(_FakeBookshelfRepo()),
    ]);
    addTearDown(container.dispose);

    // 订阅 invalidate 信号
    var invalidated = false;
    container.listen(bookshelfNovelsProvider, (_, __) {}, fireImmediately: true);

    await container.read(bookshelfMutationProvider.notifier)
        .moveToBookshelf('https://example.com/novel/1', 1, 2);

    expect(fakeAssoc.lastCall, ('https://example.com/novel/1', 1, 2));
  });
}

// ---- Fakes ----

class _FakeWriter implements IBookshelfWriter {
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeAssociationWriter implements IBookshelfAssociationWriter {
  (String, int, int)? lastCall;
  @override
  Future<void> moveNovelToBookshelf(String novelUrl, int fromId, int toId) async {
    lastCall = (novelUrl, fromId, toId);
  }
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeNovelRepo implements NovelRepository {
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeBookshelfRepo implements BookshelfRepository {
  @override noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
```

> 注:实际 `IBookshelfWriter` / `IBookshelfAssociationWriter` 接口签名以 `lib/core/interfaces/repositories/` 为准。需 noSuchMethod 转发的 fake 写法视现有测试模式调整。

- [ ] **Step 2: 跑测试,确认通过(因为 Notifier 本身没改)**

```bash
cd novel_app && flutter test test/unit/providers/bookshelf_mutation_move_all_novels_test.dart
```

Expected: PASS

如果失败:大概率是 Provider override / 接口签名/类型不匹配。按错误信息调整 fake 类。

- [ ] **Step 3: Commit**

```bash
git add novel_app/test/unit/providers/bookshelf_mutation_move_all_novels_test.dart
git commit -m "test(bookshelf): Notifier 透传 from=1 移动 + invalidate 单测"
```

---

## Task 3: UI 层 — `_showNovelMenu` 在 `currentBookshelfId==1` 时合并为"加入书架"

**Files:**
- Modify: `novel_app/lib/screens/bookshelf_screen.dart:402-484` (`_showNovelMenu` 方法体)
- Modify: `novel_app/lib/screens/bookshelf_screen.dart:276-349` (`_showBookshelfSelectionDialog` 方法体,新增 `mode='join'` 分支)
- Test: `novel_app/test/unit/screens/bookshelf_screen_all_novels_menu_test.dart` (新建)

**Interfaces:**
- Consumes: `currentBookshelfIdProvider` (来自 `bookshelf_providers.dart`)
- Produces:
  - `currentBookshelfId == 1`: 菜单只渲染一条 `Icons.bookmark_add_outlined` 的"加入书架" ListTile
  - `currentBookshelfId != 1`: 保持原"移动到书架"+"复制到书架"两条
  - `_showBookshelfSelectionDialog` 新增 `mode='join'` 分支: 标题"加入书架",选完目标书架走 `_copyNovelToBookshelf`

- [ ] **Step 1: 写失败 Widget 测试 — 全部小说书架下只显示"加入书架"**

创建 `novel_app/test/unit/screens/bookshelf_screen_all_novels_menu_test.dart`,先按现有测试基建查看 `bookshelf_screen` 的 widget 测试模式(可能用 mocktail / 手动 fake Provider)。参照 `test/unit/screens/` 下任意现有 widget 测试。

测试骨架(具体 widget pump 方式按现有测试调整):

```dart
testWidgets('currentBookshelfId==1 时,菜单只显示"加入书架"', (tester) async {
  final container = ProviderContainer(overrides: [
    currentBookshelfIdProvider.overrideWithValue(1),
    // 其余 provider override 为 fake,提供最小数据集(至少一本 Novel)
  ]);
  addTearDown(container.dispose);

  // pump BookshelfScreen,找到任一 NovelCard,触发长按/菜单按钮(按现有 UI 触发方式)
  // 断言: 找到 '加入书架' Text, 找不到 '移动到书架' Text, 找不到 '复制到书架' Text
});
```

具体 pump + tap 步骤按 `bookshelf_screen.dart` 现有 `_showNovelMenu` 触发方式(长按 / IconButton 点击)写,先让测试能跑起来。

- [ ] **Step 2: 跑测试,确认失败**

```bash
cd novel_app && flutter test test/unit/screens/bookshelf_screen_all_novels_menu_test.dart
```

Expected: FAIL — 当前菜单在全部小说下仍有"移动到书架"和"复制到书架"。

- [ ] **Step 3: 改 `_showBookshelfSelectionDialog` 增加 `mode='join'` 分支**

`novel_app/lib/screens/bookshelf_screen.dart` 第 276-349 行,在 `final selectedBookshelf = await showDialog<Bookshelf>` 之前加:

```dart
// "加入书架"(全部小说书架下的合并入口)与"复制到书架"语义等价,
// 仅标题文案不同。
final isJoin = mode == 'join';
final isMove = mode == 'move';
```

把 dialog 的 `title: Row` 改成:

```dart
title: Row(
  children: [
    Icon(
      isMove ? Icons.drive_file_move_outline : Icons.bookmark_add_outlined,
      color: Theme.of(context).colorScheme.primary,
    ),
    const SizedBox(width: 8),
    Text(mode == 'move' ? '移动到书架' : (isJoin ? '加入书架' : '复制到书架')),
  ],
),
```

把选完目标后的调用改成:

```dart
if (selectedBookshelf != null && mounted) {
  if (isMove) {
    await _moveNovelToBookshelf(novel, selectedBookshelf.id);
  } else {
    // 'join' 和 'copy' 都走 copyToBookshelf:add-only,不影响原书架归属
    await _copyNovelToBookshelf(novel, selectedBookshelf.id);
  }
}
```

- [ ] **Step 4: 改 `_showNovelMenu` 在 `currentBookshelfId==1` 时只渲染"加入书架"**

`bookshelf_screen.dart` 第 403 行起,函数顶部先读 `currentBookshelfId`:

```dart
void _showNovelMenu(Novel novel) {
  final currentBookshelfId = ref.read(currentBookshelfIdProvider);
  final isAllNovelsBookshelf = currentBookshelfId == 1;
  // ...
  showModalBottomSheet(
    // ...
    builder: (sheetCtx) {
      // ...
      children: [
        // 书名 Padding (不变)
        // ... 编辑书名 (不变) ...
        if (isAllNovelsBookshelf) ...[
          ListTile(
            leading: Icon(Icons.bookmark_add_outlined, color: colors.warning),
            title: const Text('加入书架'),
            onTap: () {
              Navigator.pop(sheetCtx);
              _showBookshelfSelectionDialog(novel, 'join');
            },
          ),
        ] else ...[
          // 原"移动到书架" + "复制到书架" 两条 ListTile,完全不变
        ],
        // 设置封面 (不变)
        // 删除封面 (不变)
        // 从书架移除 (不变)
        // SizedBox(height: 8) (不变)
      ],
    ),
  );
}
```

具体写法:把第 436-452 行的两条 ListTile 用 `if (isAllNovelsBookshelf)` / `else` 拆分,全部小说下只渲染单条"加入书架"。`_showBookshelfSelectionDialog` 已支持 `mode='join'`(Step 3)。

- [ ] **Step 5: 跑测试,确认通过**

```bash
cd novel_app && flutter test test/unit/screens/bookshelf_screen_all_novels_menu_test.dart
```

Expected: PASS

- [ ] **Step 6: 跑全部分析 + 现有测试无回归**

```bash
cd novel_app && flutter analyze lib/screens/bookshelf_screen.dart
cd novel_app && flutter test test/unit/screens/
```

Expected: 无新增警告;现有 widget 测试无失败。

- [ ] **Step 7: Commit**

```bash
git add novel_app/lib/screens/bookshelf_screen.dart novel_app/test/unit/screens/bookshelf_screen_all_novels_menu_test.dart
git commit -m "fix(bookshelf): 全部小说书架菜单合并为'加入书架'"
```

---

## Task 4: 端到端手动验证 + 文档同步

**Files:**
- Modify: `novel_app/CLAUDE.md` 顶部 Changelog 加一条 (符合 CLAUDE.md 规范)
- Modify: `novel_app/lib/repositories/bookshelf_repository.dart:361` 上方 dartdoc(说明 from=1 降级语义)

**Interfaces:** 无。

- [ ] **Step 1: 手动验证 — 全部小说书架下"加入书架"流程**

启动 app(或 `flutter run -d <device>`),在书架 tab 切到"全部小说":
1. 长按任一本书 → 菜单出现"加入书架"(只有一条,无"移动"/"复制")
2. 点"加入书架" → 弹出选择对话框,标题"加入书架",候选只有非全部小说的真实书架
3. 选"玄幻" → Toast 出现"已复制到目标书架"(复用 copy 分支的 Toast 文案,可接受)
4. 切到"玄幻"书架 → 这本书出现
5. 切回"全部小说" → 这本书仍在(验证书未离开全部小说)

Expected: 全部通过。

- [ ] **Step 2: 手动验证 — 普通书架"移动到书架"回归**

切到"玄幻"书架:
1. 长按一本书 → 菜单出现"移动到书架"+"复制到书架"两条
2. 点"移动到书架" → 选"都市" → Toast"已移动到目标书架"
3. 玄幻书架消失这本书,都市书架出现

Expected: 通过,无回归。

- [ ] **Step 3: 手动验证 — 全部小说"从书架移除"回归**

回到"全部小说",长按任一本书:
1. 菜单底部仍显示"从书架移除"
2. 点击 → 确认弹窗 → 确认 → 书从所有书架消失

Expected: 通过,无回归(走 `removeNovel` 不受影响)。

- [ ] **Step 4: 同步 dartdoc**

`bookshelf_repository.dart` 第 361 行的 dartdoc 加一句:

```dart
/// 将小说从一个书架移动到另一个书架
///
/// [novelUrl] 小说URL
/// [fromBookshelfId] 原书架ID
/// [toBookshelfId] 目标书架ID
///
/// 限制:
/// - toBookshelfId 不能为 1 (虚拟书架"全部小说",抛 ArgumentError)
/// - fromBookshelfId == 1 时降级为 add-only:跳过 remove,
///   等价于"加入目标书架,书仍留在全部小说"
/// - 源书架和目标书架相同时无操作
///
/// Web平台抛出UnsupportedError异常
```

- [ ] **Step 5: 同步 CLAUDE.md Changelog**

在 `novel_app/CLAUDE.md` 顶部"## 变更记录 (Changelog)"列表最上方加:

```markdown
- **2026-08-05**: **修复"全部小说"书架移动图书失败 + 合并冗余菜单**。`BookshelfRepository.moveNovelToBookshelf` 在 `from=1`(虚拟书架"全部小说")时从抛 `ArgumentError` 改为 add-only 降级;`BookshelfScreen._showNovelMenu` 在 `currentBookshelfId==1` 时把"移动到书架"和"复制到书架"两条菜单合并为单一"加入书架"入口(走 `copyToBookshelf`,UI 文案诚实表达"书仍留在全部小说")。`_showBookshelfSelectionDialog` 新增 `mode='join'` 分支。详见 spec `docs/superpowers/specs/2026-08-05-all-novels-bookshelf-join-design.md` + 本计划。
```

> 注:Changelog 实际格式以 `novel_app/CLAUDE.md` 当前风格为准;日期格式 `YYYY-MM-DD` + 粗体标题 + 句号结尾,描述"什么 + 为什么 + 关键文件路径"。

- [ ] **Step 6: 最终检查**

```bash
cd novel_app && flutter analyze
cd novel_app && flutter test
```

Expected: 0 error,0 警告(允许 info);所有测试通过。

- [ ] **Step 7: Commit**

```bash
git add novel_app/CLAUDE.md novel_app/lib/repositories/bookshelf_repository.dart
git commit -m "docs(bookshelf): dartdoc + Changelog 同步'加入书架'修复"
```

---

## 自审结果(写在 plan 完成后回顾 spec)

1. **Spec 覆盖**:
   - §1 诊断:不需任务,在 plan/CLAUDE.md 注释里已说明。
   - §2 目标:贯穿 4 个 task。
   - §3.1 Repository `from=1` 降级:Task 1 完整覆盖(Step 3 实现 + Step 5/6 边界回归)。
   - §3.2 Notifier 不变:Task 2 验证透传+invalidate 不变。
   - §3.3 UI 合并菜单 + `mode='join'`:Task 3 Step 3 + Step 4 覆盖。
   - §4 不在范围:贯穿,无任务为其他诡异点服务。
   - §5 测试:Task 1/2/3 各带测试 + Task 4 手动验证。
   - §6 错误处理:Repository `to=1` 仍抛错由 Task 1 Step 5 覆盖;_wrap 不 invalidate 由 Notifier 测试隐含覆盖。
   - §7 影响面:Task 1/3 文件改动与 spec 表一致。
   - 无遗漏。

2. **占位符扫描**:无 TBD/TODO/"fill in details",所有 Step 有具体代码或具体命令。

3. **类型一致性**:
   - `moveNovelToBookshelf(String, int, int)` 签名贯穿 Task 1/2 一致。
   - `IBookshelfAssociationWriter.moveNovelToBookshelf` 签名在 Task 2 fake 中一致。
   - `currentBookshelfIdProvider` 在 Task 3 中用法一致。
   - `_showBookshelfSelectionDialog(Novel, String mode)` 增加 `mode='join'` 取值,贯穿 Task 3 一致。

无冲突。