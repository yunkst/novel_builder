# 小说封面媒体化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让写作场景 Agent 能用 AI 生成的图片或视频作为小说封面，展示在书架上（镜像角色头像 `avatarMediaId` 模式）。

**Architecture:** 给 `bookshelf` 表加 `coverMediaId TEXT` 列（v36 迁移）；新增 `set_novel_cover` Agent 工具把 `mediaId` 写入该列；`NovelCover` widget 命中 `coverMediaId` 时走 `MediaView(boxFit: cover)` 渲染，否则保持现有程序化绘制。复用现有 `MediaProxy` / `MediaView` / `create_images` / `create_image_to_video`，零基础设施改动。

**Tech Stack:** Flutter 3、Dart、sqflite（v36 迁移）、Riverpod、OpenAI Function Calling。

## Global Constraints

- **媒体展示约束**：所有走 `MediaView` 的封面渲染必须传 `boxFit: BoxFit.cover`（保持原比例，裁掉超出容器的部分），严禁 `BoxFit.fill`（变形）和默认 `BoxFit.contain`（留黑边）。与角色头像 `AvatarMedia` 一致。
- **AI 封面不叠加**：`coverMediaId` 命中时只渲染媒体本身，不画书名、不画程序化装饰（书脊高光/内框/印章）。
- **DB 版本**：当前 `DatabaseMigrations.currentVersion = 35`，本计划新增 **v36**（v35 已被 character_relationships 占用）。
- **字段保留**：`bookshelf.coverUrl` 列与 `Novel.coverUrl` 字段保留不动（历史遗留），仅新增 `coverMediaId`。
- **上下文协议**：`set_novel_cover` 不接收 `novelId` 参数，从 `AgentScenarioContext.currentNovelId` 隐式取目标小说（与 `update_background_setting` 一致）。
- **错误协议**：失败返回 `jsonEncode(guidanceError(code, message, suggestedTool: ...))`，引导 LLM 自助修复。
- **刷新机制**：执行器内不 `ref.invalidate`（与 `create_novel` / `update_background_setting` 一致）；靠 `bookshelfNovelsProvider` 的 `AutoDispose` + 用户切回书架时重新查询生效。
- **测试约束**：`coverMediaId` 命中的 `MediaView` 渲染分支依赖真实 IO，widget test 脆弱，仅测纯逻辑分支（参照 `avatar_media_test.dart` 注释约定）。
- **路径基准**：所有路径相对仓库根 `D:\my_space\novel_builder\`，Flutter 工程在 `novel_app\`。测试运行目录为 `novel_app\`。

---

## File Structure

| 文件 | 责任 | 改动类型 |
|------|------|---------|
| `novel_app\lib\core\database\database_migrations.dart` | v36 迁移加 `bookshelf.coverMediaId` 列 + `currentVersion` 35→36 | Modify |
| `novel_app\lib\models\novel.dart` | Novel 加 `coverMediaId` 字段 + 序列化 | Modify |
| `novel_app\lib\core\interfaces\repositories\i_novel_repository.dart` | 接口加 `updateCoverMediaIdById` | Modify |
| `novel_app\lib\repositories\novel_repository.dart` | 实现 `updateCoverMediaIdById` | Modify |
| `novel_app\lib\repositories\bookshelf_repository.dart` | `getNovelsByBookshelf` 映射 `coverMediaId` | Modify |
| `novel_app\lib\services\novel_agent\agent_tools.dart` | 新增 `_setNovelCover` schema + 入 allTools | Modify |
| `novel_app\lib\services\novel_agent\tool_executor.dart` | switch 加 `set_novel_cover` case | Modify |
| `novel_app\lib\services\novel_agent\tool_executor\novel_navigation_executor.dart` | 新增 `setNovelCover` 方法 | Modify |
| `novel_app\lib\services\novel_agent\agent_system_prompt.dart` | 工作原则加封面条目 | Modify |
| `novel_app\lib\widgets\novel\novel_cover.dart` | build 顶部加 `coverMediaId` 分支 | Modify |
| `novel_app\test\unit\repositories\novel_repository_cover_test.dart` | `updateCoverMediaIdById` 单测（真实 ffi DB） | Create |
| `novel_app\test\unit\services\novel_agent\set_novel_cover_test.dart` | `set_novel_cover` 工具执行器单测 | Create |
| `novel_app\test\unit\widgets\novel_cover_test.dart` | `NovelCover` 纯逻辑分支单测 | Create |

**零改动**：`MediaProxy` / `MediaStore` / `MediaView` / `media_items` / `ApiServiceWrapper` / 后端 / `AvatarMedia` / `bookshelf_screen.dart`。

---

## Task 1: 数据库 v36 迁移 — `bookshelf.coverMediaId` 列

**Files:**
- Modify: `novel_app\lib\core\database\database_migrations.dart`（line 14 `currentVersion`；line 740-799 `case 34/35` 之后的 switch 收尾）

**Interfaces:**
- Produces: `bookshelf` 表新增 `coverMediaId TEXT` 列；`currentVersion` 升至 36。后续任务的 model/repository 依赖此列存在。

- [ ] **Step 1: 写失败测试（迁移后列存在 + TestDatabaseSetup 不崩）**

Create `novel_app\test\unit\repositories\database_v36_cover_media_id_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqflite.dart';

import '../../../helpers/test_database_setup.dart' as test_db;

/// v36 迁移验证：bookshelf 表必须有 coverMediaId 列。
/// TestDatabaseSetup.createInMemoryDatabase 会跑 createV1Tables + upgrade(1, currentVersion)，
/// 故只要 currentVersion 升到 36 且 case 36 执行 ALTER，此处即通过。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUp(() async {
    db = await test_db.TestDatabaseSetup.createInMemoryDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  test('bookshelf 表包含 coverMediaId 列', () async {
    final columns = await db.rawQuery('PRAGMA table_info(bookshelf)');
    final names = columns.map((c) => c['name'] as String).toSet();

    expect(names, contains('coverMediaId'));
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:
```bash
cd novel_app && flutter test test/unit/repositories/database_v36_cover_media_id_test.dart
```
Expected: FAIL — `Expected: contains 'coverMediaId'`（列尚未添加）。

- [ ] **Step 3: 升版本号**

Edit `novel_app\lib\core\database\database_migrations.dart` line 14:

```dart
  static const int currentVersion = 36;
```

- [ ] **Step 4: 加 v36 迁移 case**

在 `_migrateToVersion` 的 switch 中，`case 35:` 的 `break;`（约 line 798）之后、switch 闭合 `}`（line 799）之前，插入：

```dart
      // ========== 版本 36：小说封面媒体化 ==========
      // bookshelf 加 coverMediaId 列（小说封面迁移到 mediaId 体系）：
      //   - 存 create_images / create_image_to_video 返回的 mediaId
      //   - 由 set_novel_cover 工具写入，NovelCover 命中时走 MediaView 渲染
      // 旧 coverUrl 列保留不动（历史遗留，2026-07-08 爬虫移除后基本为 null）。
      case 36:
        await _addColumnIfNotExists(db, 'bookshelf', 'coverMediaId', 'TEXT');
        _log('迁移 v35 → v36: bookshelf 加 coverMediaId 列');
        break;
```

- [ ] **Step 5: 运行测试，确认通过**

Run:
```bash
cd novel_app && flutter test test/unit/repositories/database_v36_cover_media_id_test.dart
```
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
cd novel_app && git add lib/core/database/database_migrations.dart test/unit/repositories/database_v36_cover_media_id_test.dart && git commit -m "feat(db): v36 迁移 bookshelf 加 coverMediaId 列"
```

---

## Task 2: Novel 模型加 `coverMediaId` 字段

**Files:**
- Modify: `novel_app\lib\models\novel.dart`
- Test: `novel_app\test\unit\models\novel_cover_media_id_test.dart`（Create）

**Interfaces:**
- Consumes: Task 1 的 `coverMediaId` 列
- Produces: `Novel.coverMediaId` 字段（`String?`），序列化键 `'coverMediaId'`，`copyWith` 参数名 `coverMediaId`。后续 repository / executor / widget 依赖此字段名。

- [ ] **Step 1: 写失败测试（toMap/fromMap/copyWith 含 coverMediaId）**

Create `novel_app\test\unit\models\novel_cover_media_id_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/novel.dart';

void main() {
  group('Novel.coverMediaId', () {
    test('toMap 含 coverMediaId 键', () {
      final novel = Novel(
        title: '测试',
        author: '作者',
        url: 'custom://x',
        coverMediaId: 'media-abc',
      );
      expect(novel.toMap()['coverMediaId'], 'media-abc');
    });

    test('fromMap 读出 coverMediaId', () {
      final novel = Novel.fromMap({
        'id': 1,
        'title': '测试',
        'author': '作者',
        'url': 'custom://x',
        'coverMediaId': 'media-xyz',
      });
      expect(novel.coverMediaId, 'media-xyz');
    });

    test('fromMap 缺 coverMediaId 时为 null（兼容旧行）', () {
      final novel = Novel.fromMap({
        'id': 1,
        'title': '测试',
        'author': '作者',
        'url': 'custom://x',
      });
      expect(novel.coverMediaId, isNull);
    });

    test('copyWith 覆盖 coverMediaId', () {
      final novel = Novel(
        title: '测试',
        author: '作者',
        url: 'custom://x',
        coverMediaId: 'old',
      );
      expect(novel.copyWith(coverMediaId: 'new').coverMediaId, 'new');
    });
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:
```bash
cd novel_app && flutter test test/unit/models/novel_cover_media_id_test.dart
```
Expected: FAIL — 编译错误（`coverMediaId` 命名参数不存在）。

- [ ] **Step 3: 字段声明**

Edit `novel_app\lib\models\novel.dart`，在 line 22（`backgroundSetting` 字段）后新增：

```dart
  /// 封面媒体资源 ID（图像/视频），经 MediaView 渲染。
  /// 由 set_novel_cover 工具写入；为 null 时 NovelCover 走程序化占位。
  /// 旧 coverUrl 字段保留兼容，但新代码优先使用本字段。
  final String? coverMediaId;
```

- [ ] **Step 4: 构造函数加参数**

Edit `novel_app\lib\models\novel.dart`，在构造函数 `backgroundSetting,`（约 line 38）后加 `coverMediaId,`：

```dart
    this.backgroundSetting,
    this.coverMediaId,
    this.lastReadChapterIndex,
```

- [ ] **Step 5: toMap 加键**

Edit `toMap()`（约 line 56），在 `'backgroundSetting': backgroundSetting,` 后加：

```dart
      'coverMediaId': coverMediaId,
```

- [ ] **Step 6: fromMap 读字段**

Edit `fromMap()`（约 line 74），在 `backgroundSetting: map['backgroundSetting'] as String?,` 后加：

```dart
      coverMediaId: map['coverMediaId'] as String?,
```

- [ ] **Step 7: copyWith 加参数**

Edit `copyWith()`，在参数列表 `String? backgroundSetting,`（约 line 88）后加 `String? coverMediaId,`，在函数体 `backgroundSetting: backgroundSetting ?? this.backgroundSetting,`（约 line 100）后加：

```dart
      coverMediaId: coverMediaId ?? this.coverMediaId,
```

- [ ] **Step 8: 运行测试，确认通过**

Run:
```bash
cd novel_app && flutter test test/unit/models/novel_cover_media_id_test.dart
```
Expected: PASS（4 个测试全过）。

- [ ] **Step 9: 提交**

```bash
cd novel_app && git add lib/models/novel.dart test/unit/models/novel_cover_media_id_test.dart && git commit -m "feat(model): Novel 加 coverMediaId 字段"
```

---

## Task 3: Repository — `updateCoverMediaIdById`

**Files:**
- Modify: `novel_app\lib\core\interfaces\repositories\i_novel_repository.dart`
- Modify: `novel_app\lib\repositories\novel_repository.dart`
- Test: `novel_app\test\unit\repositories\novel_repository_cover_test.dart`（Create）

**Interfaces:**
- Consumes: Task 1 的 `coverMediaId` 列
- Produces: `INovelRepository.updateCoverMediaIdById(int id, String? mediaId) → Future<int>`（返回受影响行数；id 不存在返回 0）。Task 5 的 executor 依赖此签名。

- [ ] **Step 1: 写失败测试（真实 ffi DB 写入/清空/不存在）**

Create `novel_app\test\unit\repositories\novel_repository_cover_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqflite.dart';

import 'package:novel_app/repositories/novel_repository.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/core/database/database_connection.dart';
import '../../../helpers/test_database_setup.dart' as test_db;

/// updateCoverMediaIdById 集成测试（真实内存 SQLite，跑完整迁移）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late NovelRepository repo;

  setUp(() async {
    db = await test_db.TestDatabaseSetup.createInMemoryDatabase();
    repo = NovelRepository(dbConnection: DatabaseConnection.forTesting(db));
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedNovel(String url) async {
    final id = await repo.addToBookshelf(Novel(
      title: '测试小说',
      author: '作者',
      url: url,
    ));
    return id;
  }

  test('写入 mediaId 后可读回', () async {
    final id = await seedNovel('custom://n1');
    final affected = await repo.updateCoverMediaIdById(id, 'media-1');
    expect(affected, 1);

    final novel = await repo.getNovelById(id);
    expect(novel?.coverMediaId, 'media-1');
  });

  test('传入 null 清空封面', () async {
    final id = await seedNovel('custom://n2');
    await repo.updateCoverMediaIdById(id, 'media-2');
    await repo.updateCoverMediaIdById(id, null);

    final novel = await repo.getNovelById(id);
    expect(novel?.coverMediaId, isNull);
  });

  test('不存在的 id 返回 0', () async {
    final affected = await repo.updateCoverMediaIdById(99999, 'media-x');
    expect(affected, 0);
  });
}
```

> 注：`getNovelById` 读出 `coverMediaId` 依赖 Task 2 的 model 改动 + 该 repository 方法是否用 `Novel.fromMap`。实现时若 `getNovelById` 手动映射未含 `coverMediaId`，本任务 Step 8 顺带补上（见 Step 8 说明）。

- [ ] **Step 2: 运行测试，确认失败**

Run:
```bash
cd novel_app && flutter test test/unit/repositories/novel_repository_cover_test.dart
```
Expected: FAIL — 编译错误（`updateCoverMediaIdById` 方法不存在）。

- [ ] **Step 3: 接口声明**

Edit `novel_app\lib\core\interfaces\repositories\i_novel_repository.dart`，在 `updateBackgroundSettingById`（约 line 106）后、闭合 `}`（line 107）前新增：

```dart
  /// 根据 ID 更新小说封面媒体 ID
  ///
  /// [id] bookshelf.id
  /// [mediaId] 媒体资源 ID（来自 create_images / create_image_to_video），
  ///   传 null 表示清空封面（回到程序化占位）
  /// 返回受影响的行数，ID 不存在则返回 0
  Future<int> updateCoverMediaIdById(int id, String? mediaId);
```

- [ ] **Step 4: 实现**

Edit `novel_app\lib\repositories\novel_repository.dart`，在 `updateBackgroundSettingById`（约 line 369-373）后、类闭合 `}`（line 374）前新增。注意 `bookshelf` 表无 `updatedAt` 列，仅更新目标列：

```dart
  /// 根据 ID 更新小说封面媒体 ID
  @override
  Future<int> updateCoverMediaIdById(int id, String? mediaId) async {
    if (isWebPlatform) {
      return 0;
    }

    try {
      final db = await database;
      return await db.update(
        'bookshelf',
        {'coverMediaId': mediaId},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '更新封面失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['novel', 'cover', 'failed'],
      );
      rethrow;
    }
  }
```

- [ ] **Step 5: 运行测试，确认通过**

Run:
```bash
cd novel_app && flutter test test/unit/repositories/novel_repository_cover_test.dart
```
Expected: "不存在的 id 返回 0" 和 "传入 null 清空封面" 通过；"写入 mediaId 后可读回" **FAIL**（`getNovelById` 手动映射 `Novel(...)`，未含 `coverMediaId`，见 Step 6 修复）。

- [ ] **Step 6: 补 getNovelById 的 coverMediaId 映射**

`getNovelById`（`novel_repository.dart:340-350`）是手动构造 `Novel(...)`，未映射 `coverMediaId`。在 `backgroundSetting: maps.first['backgroundSetting'] as String?,`（line 348）后加一行：

```dart
      coverMediaId: maps.first['coverMediaId'] as String?,
```

- [ ] **Step 7: 运行测试，确认通过**

Run:
```bash
cd novel_app && flutter test test/unit/repositories/novel_repository_cover_test.dart
```
Expected: PASS（3 个测试全过）。

- [ ] **Step 8: 运行全量 repository 测试，确认无回归**

Run:
```bash
cd novel_app && flutter test test/unit/repositories/
```
Expected: 既有测试全过 + 新增 3 个测试通过。

- [ ] **Step 9: 提交**

```bash
cd novel_app && git add lib/core/interfaces/repositories/i_novel_repository.dart lib/repositories/novel_repository.dart test/unit/repositories/novel_repository_cover_test.dart && git commit -m "feat(repo): NovelRepository 加 updateCoverMediaIdById + getNovelById 映射 coverMediaId"
```

---

## Task 4: BookshelfRepository 映射 `coverMediaId`

**Files:**
- Modify: `novel_app\lib\repositories\bookshelf_repository.dart`（`getNovelsByBookshelf` 约 line 208-242 两处 Novel 构造）

**Interfaces:**
- Consumes: Task 2 的 `Novel.coverMediaId`
- Produces: `bookshelfNovelsProvider` 返回的 Novel 列表携带 `coverMediaId`，供 `NovelCover` 渲染。

- [ ] **Step 1: 写失败测试（getNovelsByBookshelf 返回带 coverMediaId 的 Novel）**

Create `novel_app\test\unit\repositories\bookshelf_repository_cover_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqflite.dart';

import 'package:novel_app/models/novel.dart';
import 'package:novel_app/repositories/novel_repository.dart';
import 'package:novel_app/repositories/bookshelf_repository.dart';
import 'package:novel_app/core/database/database_connection.dart';
import '../../../helpers/test_database_setup.dart' as test_db;

/// getNovelsByBookshelf 应携带 coverMediaId（NovelCover 渲染依赖）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late BookshelfRepository bookshelfRepo;
  late NovelRepository novelRepo;

  setUp(() async {
    db = await test_db.TestDatabaseSetup.createInMemoryDatabase();
    bookshelfRepo =
        BookshelfRepository(dbConnection: DatabaseConnection.forTesting(db));
    novelRepo =
        NovelRepository(dbConnection: DatabaseConnection.forTesting(db));
  });

  tearDown(() async {
    await db.close();
  });

  test('全部小说书架(id=1)返回的 Novel 带 coverMediaId', () async {
    final id = await novelRepo.addToBookshelf(
      Novel(title: '书1', author: '作者', url: 'custom://b1'),
    );
    await novelRepo.updateCoverMediaIdById(id, 'cover-media-1');

    final novels = await bookshelfRepo.getNovelsByBookshelf(1);
    final target = novels.firstWhere((n) => n.url == 'custom://b1');

    expect(target.coverMediaId, 'cover-media-1');
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:
```bash
cd novel_app && flutter test test/unit/repositories/bookshelf_repository_cover_test.dart
```
Expected: FAIL — `Expected: 'cover-media-1'` 但实际为 `null`（getNovelsByBookshelf 未映射）。

- [ ] **Step 3: 第一处映射补字段（全部小说分支，约 line 209-218）**

Edit `novel_app\lib\repositories\bookshelf_repository.dart`，在 `getNovelsByBookshelf` 的第一处 `Novel(...)` 构造（`backgroundSetting: maps[i]['backgroundSetting'],` 后）加：

```dart
          coverUrl: maps[i]['coverUrl'],
          coverMediaId: maps[i]['coverMediaId'],
          description: maps[i]['description'],
```

即把 `coverUrl: maps[i]['coverUrl'],`（line 213）的下一行插入 `coverMediaId: maps[i]['coverMediaId'],`。

- [ ] **Step 4: 第二处映射补字段（JOIN 分支，约 line 232-241）**

在同一方法的第二处 `Novel(...)` 构造（`coverUrl: maps[i]['coverUrl'],` 在 line 236）后加：

```dart
          coverUrl: maps[i]['coverUrl'],
          coverMediaId: maps[i]['coverMediaId'],
          description: maps[i]['description'],
```

（JOIN 用 `SELECT b.*`，`coverMediaId` 已在结果集中。）

- [ ] **Step 5: 运行测试，确认通过**

Run:
```bash
cd novel_app && flutter test test/unit/repositories/bookshelf_repository_cover_test.dart
```
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
cd novel_app && git add lib/repositories/bookshelf_repository.dart test/unit/repositories/bookshelf_repository_cover_test.dart && git commit -m "feat(repo): getNovelsByBookshelf 映射 coverMediaId"
```

---

## Task 5: Agent 工具 schema — `set_novel_cover`

**Files:**
- Modify: `novel_app\lib\services\novel_agent\agent_tools.dart`（allTools 列表 line 21-54 + 新增 schema 常量）

**Interfaces:**
- Consumes: 无（仅 schema 声明）
- Produces: 工具名 `'set_novel_cover'`，参数 `mediaId`（`['string','null']`）。Task 6 的 executor 与 Task 7 的测试依赖此工具名。

- [ ] **Step 1: 写失败测试（schema 存在且字段正确）**

Create `novel_app\test\unit\services\novel_agent\set_novel_cover_schema_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/novel_agent/agent_tools.dart';

void main() {
  test('AgentTools.allTools 含 set_novel_cover', () {
    final names = AgentTools.allTools
        .map((t) => (t['function'] as Map<String, dynamic>)['name'] as String)
        .toSet();

    expect(names, contains('set_novel_cover'));
  });

  test('set_novel_cover 参数为 mediaId（string|null），required', () {
    final tool = AgentTools.allTools.firstWhere(
      (t) => (t['function'] as Map<String, dynamic>)['name'] == 'set_novel_cover',
    );
    final params =
        (tool['function'] as Map<String, dynamic>)['parameters'] as Map<String, dynamic>;
    final mediaId = (params['properties'] as Map<String, dynamic>)['mediaId']
        as Map<String, dynamic>;

    expect(params['required'], contains('mediaId'));
    expect(mediaId['type'], ['string', 'null']);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:
```bash
cd novel_app && flutter test test/unit/services/novel_agent/set_novel_cover_schema_test.dart
```
Expected: FAIL — `set_novel_cover` 未在 allTools 中。

- [ ] **Step 3: 加 schema 常量**

Edit `novel_app\lib\services\novel_agent\agent_tools.dart`，在 `_updateBackgroundSetting`（约 line 544 闭合 `};`）后新增：

```dart
  static const _setNovelCover = {
    'type': 'function',
    'function': {
      'name': 'set_novel_cover',
      'description': '设置当前小说的封面。先用 create_images（图片）或 '
          'create_image_to_video（视频）生成媒体拿到 mediaId，再把 mediaId 传到这里。'
          '封面接受图片或视频，展示时保持原比例裁剪（不拉伸变形），不会叠加书名文字。'
          '如需清空封面回到默认占位图，mediaId 传 null。',
      'parameters': {
        'type': 'object',
        'properties': {
          'mediaId': {
            'type': ['string', 'null'],
            'description': '由 create_images / create_image_to_video 返回的 mediaId；'
                '传 null 表示清空封面',
          },
        },
        'required': ['mediaId'],
      },
    },
  };
```

- [ ] **Step 4: 注册到 allTools**

Edit allTools 列表（line 21-54），在"设定 / 大纲"分组后（`_getOutline,` 约 line 44 之后）插入新分组与工具：

```dart
    // ===== 设定 / 大纲 =====
    _updateBackgroundSetting,
    _updateOutline,
    _writeOutline,
    _getOutline,
    // ===== 小说封面 =====
    _setNovelCover,
    // ===== 提示标签 =====
```

- [ ] **Step 5: 运行测试，确认通过**

Run:
```bash
cd novel_app && flutter test test/unit/services/novel_agent/set_novel_cover_schema_test.dart
```
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
cd novel_app && git add lib/services/novel_agent/agent_tools.dart test/unit/services/novel_agent/set_novel_cover_schema_test.dart && git commit -m "feat(agent): 新增 set_novel_cover 工具 schema"
```

---

## Task 6: 工具执行器 — `NovelNavigationExecutor.setNovelCover` + 分发

**Files:**
- Modify: `novel_app\lib\services\novel_agent\tool_executor\novel_navigation_executor.dart`
- Modify: `novel_app\lib\services\novel_agent\tool_executor.dart`（switch line 89-157）

**Interfaces:**
- Consumes: Task 3 的 `updateCoverMediaIdById`；`ToolArgParser.nullableString`；`ToolExecutorHelpers.resolveCurrentNovelUrl` + `guidanceError`；`AgentScenarioContext.currentNovelId`
- Produces: `executor.execute('set_novel_cover', args, scenarioContext: ctx)` 返回 JSON：成功 `{'success':true,'novelId':int,'coverMediaId':String?,'cleared':bool}`，失败 `guidanceError` map。

- [ ] **Step 1: 写失败测试（成功路径 + 无当前小说 + 清空）**

Create `novel_app\test\unit\services\novel_agent\set_novel_cover_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqflite.dart';

import 'package:novel_app/core/database/database_connection.dart';
import 'package:novel_app/core/providers/database_providers.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/repositories/novel_repository.dart';
import 'package:novel_app/services/novel_agent/agent_scenario.dart';
import 'package:novel_app/services/novel_agent/tool_executor.dart';
import '../../../helpers/test_database_setup.dart' as test_db;

/// set_novel_cover 工具执行器测试。
/// 复用 text2img_tools_test 的 ProviderContainer + 真实内存 DB 模式。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final toolExecutorProvider =
      Provider<ToolExecutor>((ref) => ToolExecutor(ref));

  late ProviderContainer container;
  late ToolExecutor executor;
  late Database db;
  late NovelRepository novelRepo;
  late int novelId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await test_db.TestDatabaseSetup.createInMemoryDatabase();
    container = ProviderContainer(overrides: [
      databaseConnectionProvider
          .overrideWithValue(DatabaseConnection.forTesting(db)),
    ]);
    executor = container.read(toolExecutorProvider);
    novelRepo = container.read(novelRepositoryProvider);
    novelId = await novelRepo.addToBookshelf(
      Novel(title: '封面测试书', author: '作者', url: 'custom://cover-test'),
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Map<String, dynamic> decode(String raw) =>
      jsonDecode(raw) as Map<String, dynamic>;

  test('成功设置封面 mediaId', () async {
    final ctx = AgentScenarioContext(currentNovelId: novelId);
    final json = decode(await executor.execute(
      'set_novel_cover',
      {'mediaId': 'cover-1'},
      scenarioContext: ctx,
    ));

    expect(json['success'], true);
    expect(json['coverMediaId'], 'cover-1');
    expect(json['cleared'], false);

    final novel = await novelRepo.getNovelById(novelId);
    expect(novel?.coverMediaId, 'cover-1');
  });

  test('mediaId 传 null 清空封面', () async {
    await novelRepo.updateCoverMediaIdById(novelId, 'pre-existing');
    final ctx = AgentScenarioContext(currentNovelId: novelId);

    final json = decode(await executor.execute(
      'set_novel_cover',
      {'mediaId': null},
      scenarioContext: ctx,
    ));

    expect(json['success'], true);
    expect(json['cleared'], true);
    final novel = await novelRepo.getNovelById(novelId);
    expect(novel?.coverMediaId, isNull);
  });

  test('无当前小说返回 no_current_novel 引导', () async {
    final json = decode(await executor.execute(
      'set_novel_cover',
      {'mediaId': 'cover-1'},
      scenarioContext: const AgentScenarioContext(),
    ));

    expect(json['error'], 'no_current_novel');
    expect(json['suggested_tool'], 'list_novels');
  });

  test('未传 scenarioContext 同样返回 no_current_novel', () async {
    final json = decode(await executor.execute(
      'set_novel_cover',
      {'mediaId': 'cover-1'},
    ));

    expect(json['error'], 'no_current_novel');
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:
```bash
cd novel_app && flutter test test/unit/services/novel_agent/set_novel_cover_test.dart
```
Expected: FAIL — `unknown_tool`（switch 未分发 `set_novel_cover`）。

- [ ] **Step 3: 实现执行器方法**

Edit `novel_app\lib\services\novel_agent\tool_executor\novel_navigation_executor.dart`，在 `createNovel` 方法（约 line 91 闭合 `}`）后、类闭合 `}`（line 92）前新增。注意 `NovelNavigationExecutor with ToolExecutorHelpers` 已提供 `resolveCurrentNovelUrl` / `guidanceError`：

```dart
  /// 设置当前小说封面（set_novel_cover 工具）
  ///
  /// 从场景上下文取 currentNovelId，写 bookshelf.coverMediaId。
  /// mediaId 为 null 表示清空封面。与 update_background_setting 同构：
  /// 先 resolveCurrentNovelUrl 校验小说存在，再用 currentNovelId 写库。
  Future<String> setNovelCover(
    Map<String, dynamic> args,
    AgentScenarioContext? ctx,
  ) async {
    final parser = ToolArgParser(args);
    final (mediaId, mediaIdErr) = parser.nullableString('mediaId');
    if (mediaIdErr != null) return mediaIdErr;

    final novelResolve = await resolveCurrentNovelUrl(ctx);
    if (novelResolve.errorJson != null) {
      return jsonEncode(novelResolve.errorJson);
    }
    final currentNovelId = ctx?.currentNovelId;
    if (currentNovelId == null) {
      return jsonEncode(guidanceError(
        'no_current_novel',
        '尚未选择当前小说。请先调用 list_novels 再用 select_novel 选定目标。',
        suggestedTool: 'list_novels',
      ));
    }

    final repo = ref.read(novelRepositoryProvider);
    final affected = await repo.updateCoverMediaIdById(currentNovelId, mediaId);
    if (affected == 0) {
      return jsonEncode(guidanceError(
        'novel_not_found',
        '当前小说不存在。',
        suggestedTool: 'list_novels',
      ));
    }

    LoggerService.instance.i('设置封面: novelId=$currentNovelId, mediaId=$mediaId',
        category: LogCategory.ai, tags: ['agent', 'tool', 'set_novel_cover']);
    return jsonEncode({
      'success': true,
      'novelId': currentNovelId,
      'coverMediaId': mediaId,
      'cleared': mediaId == null,
    });
  }
```

> 需确认 import：`agent_scenario.dart`（提供 `AgentScenarioContext`）已在文件顶部 import 链中。若未 import，在文件头部加 `import '../agent_scenario.dart';`。`ToolArgParser` / `ToolExecutorHelpers` / `novelRepositoryProvider` / `LoggerService` / `dart:convert` 均已 import。

- [ ] **Step 4: switch 分发**

Edit `novel_app\lib\services\novel_agent\tool_executor.dart`，在"设定 / 大纲"分组 case 之后（`case 'get_outline':` 约 line 132-133 后）、"提示标签"分组前插入：

```dart
        case 'get_outline':
          return await _outline.getOutline(args, scenarioContext);
        // ===== 小说封面 =====
        case 'set_novel_cover':
          return await _novelNav.setNovelCover(args, scenarioContext);
        // ===== 提示标签 =====
```

`_novelNav`（NovelNavigationExecutor）已在 line 41 懒创建，无需新增。

- [ ] **Step 5: 运行测试，确认通过**

Run:
```bash
cd novel_app && flutter test test/unit/services/novel_agent/set_novel_cover_test.dart
```
Expected: PASS（4 个测试全过）。

- [ ] **Step 6: 运行全量 agent 工具测试，确认无回归**

Run:
```bash
cd novel_app && flutter test test/unit/services/novel_agent/
```
Expected: 既有测试全过 + 新增通过。

- [ ] **Step 7: 提交**

```bash
cd novel_app && git add lib/services/novel_agent/tool_executor/novel_navigation_executor.dart lib/services/novel_agent/tool_executor.dart test/unit/services/novel_agent/set_novel_cover_test.dart && git commit -m "feat(agent): set_novel_cover 执行器 + 分发"
```

---

## Task 7: System Prompt 加封面工作原则

**Files:**
- Modify: `novel_app\lib\services\novel_agent\agent_system_prompt.dart`（工作原则 line 35-45）
- Modify: `novel_app\test\unit\services\novel_agent\agent_system_prompt_test.dart`（追加断言）

**Interfaces:**
- Consumes: Task 5 的 `set_novel_cover` 工具
- Produces: system prompt 含封面使用指引，LLM 知道何时调 `set_novel_cover`。

- [ ] **Step 1: 读现有 prompt 测试确认风格**

Run:
```bash
cd novel_app && grep -n "set_novel_cover\|update_background_setting\|工作原则" test/unit/services/novel_agent/agent_system_prompt_test.dart
```

若无现有原则断言，本任务新增一条断言即可。

- [ ] **Step 2: 写失败测试（prompt 提及封面工具）**

在 `agent_system_prompt_test.dart` 末尾 `}`（main 闭合）前追加（若无 group 则直接加 test）：

```dart
  test('system prompt 提及 set_novel_cover 封面工具', () {
    final prompt = AgentSystemPrompt.build();

    expect(prompt, contains('set_novel_cover'));
    expect(prompt, contains('封面'));
  });
```

> 若文件 import 缺 `AgentSystemPrompt`，确认顶部有 `import 'package:novel_app/services/novel_agent/agent_system_prompt.dart';`。

- [ ] **Step 3: 运行测试，确认失败**

Run:
```bash
cd novel_app && flutter test test/unit/services/novel_agent/agent_system_prompt_test.dart
```
Expected: FAIL — prompt 不含 `set_novel_cover`。

- [ ] **Step 4: 加工作原则条目**

Edit `novel_app\lib\services\novel_agent\agent_system_prompt.dart`，在 line 43（`'（只需 title，可选 description），系统会自动切换为当前工作小说。');`）后、line 44（`buffer.writeln('5. 修改操作完成后向用户汇报。');`）前插入封面条目，并把原第 5 条顺延为第 6 条：

```dart
    buffer.writeln('5. 修改小说封面：先用 create_images（图片）或 '
        'create_image_to_video（视频）生成媒体，从返回结果里选最合适的一张，'
        '把它的 mediaId 传给 set_novel_cover。封面接受图片或视频，'
        '封面图本身不需要包含书名文字（书名会在书架标题区独立展示）。'
        '如需恢复默认占位封面，调 set_novel_cover 时 mediaId 传 null。');
    buffer.writeln('6. 修改操作完成后向用户汇报。');
```

（原 line 44 的 `5.` 改为 `6.`。）

- [ ] **Step 5: 运行测试，确认通过**

Run:
```bash
cd novel_app && flutter test test/unit/services/novel_agent/agent_system_prompt_test.dart
```
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
cd novel_app && git add lib/services/novel_agent/agent_system_prompt.dart test/unit/services/novel_agent/agent_system_prompt_test.dart && git commit -m "feat(agent): system prompt 加封面修改工作原则"
```

---

## Task 8: NovelCover widget — `coverMediaId` 命中走 MediaView

**Files:**
- Modify: `novel_app\lib\widgets\novel\novel_cover.dart`（build 方法 line 49-86 + import）
- Test: `novel_app\test\unit\widgets\novel_cover_test.dart`（Create）

**Interfaces:**
- Consumes: Task 2 的 `Novel.coverMediaId`；`MediaView` widget
- Produces: `NovelCover` 在 `coverMediaId` 非空时渲染 `MediaView(boxFit: cover)`，纯图无叠加；为空时走原程序化绘制。

**关键约束**：
- AI 封面命中只渲染媒体，不画书名/书脊/内框/印章（"在读"点在父 `_NovelCard`，本任务不动）
- 必须传 `boxFit: BoxFit.cover`（Global Constraints）
- `MediaView` 渲染分支依赖真实 IO（mediaProxyProvider + Image/Video 初始化），widget test 脆弱，**仅测"命中走 MediaView / 未命中走程序化"的分支选择**（参照 `avatar_media_test.dart` 注释约定），不测实际渲染像素

- [ ] **Step 1: 写失败测试（分支选择）**

Create `novel_app\test\unit\widgets\novel_cover_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_app/models/novel.dart';
import 'package:novel_app/widgets/novel/novel_cover.dart';

/// NovelCover 分支选择测试。
///
/// AI 封面命中（coverMediaId 非空）→ 渲染 MediaView（ConsumerStatefulWidget，
/// 依赖 mediaProxyProvider + IO），端到端渲染脆弱，仅验证"命中即出现 MediaView
/// 而非程序化 CustomPaint"这一分支选择（参照 avatar_media_test 约定）。
/// 未命中 → 走 _ProgrammaticCoverPainter（CustomPaint）。
void main() {
  testWidgets('coverMediaId 为空 → 程序化封面（含 CustomPaint）', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: NovelCover(
              novel: Novel(title: '测试', author: '作者', url: 'custom://x'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('coverMediaId 非空 → 命中 MediaView（不再走程序化文字）',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 160,
              child: NovelCover(
                novel: Novel(
                  title: '测试',
                  author: '作者',
                  url: 'custom://x',
                  coverMediaId: 'media-fake',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // MediaView 是异步 resolve，pump 几帧让 ConsumerStatefulWidget 挂载
    await tester.pump();

    // 命中分支不应渲染程序化封面的标题文字 CustomPainter（_ProgrammaticCoverPainter）
    final coverMediaPainters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((c) => c.painter?.runtimeType.toString() == '_ProgrammaticCoverPainter');
    expect(coverMediaPainters, isEmpty,
        reason: 'coverMediaId 命中时不应渲染 _ProgrammaticCoverPainter');
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:
```bash
cd novel_app && flutter test test/unit/widgets/novel_cover_test.dart
```
Expected: 第二个测试 FAIL — 命中分支仍渲染 `_ProgrammaticCoverPainter`（当前 coverMediaId 不被识别）。

- [ ] **Step 3: 加 import**

Edit `novel_app\lib\widgets\novel\novel_cover.dart`，在 `import '../../models/novel.dart';`（line 14）后加：

```dart
import '../media/media_view.dart';
```

- [ ] **Step 4: build 顶部加 coverMediaId 短路分支**

Edit `build` 方法（line 49-50 之间，即 `Widget build(BuildContext context) {` 之后、`final width = widget.width;` 之前）插入分支。完整改后的 build 开头：

```dart
  @override
  Widget build(BuildContext context) {
    // AI 封面命中：走 MediaView 渲染（图片/视频），纯图不叠加任何程序化装饰。
    // boxFit=cover 保证保持原比例裁切，不拉伸变形（与 AvatarMedia 一致）。
    // 加载/失败/pending 由 MediaView 自带状态机承担，NovelCover 不再自管 fallback。
    final coverMediaId = widget.novel.coverMediaId;
    if (coverMediaId != null && coverMediaId.isNotEmpty) {
      final width = widget.width;
      final height = width * 4 / 3;
      return SizedBox(
        width: width,
        height: height,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 14,
                offset: Offset(-2, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: MediaView(
              mediaId: coverMediaId,
              boxFit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    final width = widget.width;
    final height = width * 4 / 3;

    final content = _hasCoverUrl
```

（后续 `_hasCoverUrl ? Image.network(...) : CustomPaint(...)` 等原逻辑完全不动。）

- [ ] **Step 5: 运行测试，确认通过**

Run:
```bash
cd novel_app && flutter test test/unit/widgets/novel_cover_test.dart
```
Expected: PASS（2 个测试全过）。

- [ ] **Step 6: 静态分析确认无未使用 import / 类型错误**

Run:
```bash
cd novel_app && flutter analyze lib/widgets/novel/novel_cover.dart
```
Expected: No issues found。

- [ ] **Step 7: 提交**

```bash
cd novel_app && git add lib/widgets/novel/novel_cover.dart test/unit/widgets/novel_cover_test.dart && git commit -m "feat(ui): NovelCover 命中 coverMediaId 走 MediaView(boxFit cover)"
```

---

## Task 9: 全量回归 + 文档同步

**Files:**
- Verify: 全测试套件
- Modify: `CLAUDE.md`（DB 版本号、changelog）

- [ ] **Step 1: 全量单元测试**

Run:
```bash
cd novel_app && flutter test
```
Expected: 全部通过（含本计划 7 个新增测试文件）。

- [ ] **Step 2: 静态分析**

Run:
```bash
cd novel_app && flutter analyze
```
Expected: 无新增 error/warning（与改动前持平）。

- [ ] **Step 3: 同步根 CLAUDE.md 数据库版本**

Edit `D:\my_space\novel_builder\CLAUDE.md`，找到"数据库版本"小节，把前端 SQLite 版本从 `v33` 改为 `v36`，并在"变更记录"加一行：

```
- **2026-07-10**: 小说封面媒体化。bookshelf 加 coverMediaId 列（v36），新增 set_novel_cover 工具，NovelCover 命中走 MediaView（图/视频，BoxFit.cover 不拉伸）。镜像角色头像 avatarMediaId 模式。
```

- [ ] **Step 4: 同步 novel_app/CLAUDE.md（如有版本/字段引用）**

Run:
```bash
grep -n "v21\|coverUrl\|currentVersion" novel_app/CLAUDE.md
```
若 `Novel` 模型文档列出字段，补 `coverMediaId`。若数据库版本写 `v21`，更新为 `v36`。

- [ ] **Step 5: 提交文档**

```bash
git add CLAUDE.md novel_app/CLAUDE.md && git commit -m "docs: 同步封面媒体化(v36 coverMediaId + set_novel_cover) 至 CLAUDE.md"
```

---

## Self-Review 结果

**1. Spec 覆盖**：规格第 2 节决策（字段/工具/媒体范围/触发/prompt/不拉伸）→ Task 1-8 全覆盖；第 3 节不拉伸约束 → Task 8 Step 4 + Global Constraints；第 4 节数据流刷新 → Global Constraints 说明 AutoDispose 机制；第 5-7 节数据/UI/工具 → Task 1-8；第 10 节测试 → 每个 Task 内 TDD。

**2. 占位符扫描**：无 TBD/TODO；测试代码完整可运行；实现代码完整。Task 3 Step 6-7、Task 7 Step 1 的"读现有代码确认"是有具体 grep/Read 指令的核查步骤，非占位。

**3. 类型一致性**：`coverMediaId`（String?）、`updateCoverMediaIdById(int id, String? mediaId) → Future<int>`、`setNovelCover(args, ctx) → Future<String>`、工具名 `set_novel_cover`、参数 `mediaId` 在所有 Task 一致。

**4. 已知执行时核查点**（非占位，是合理的代码确认）：
- Task 6 Step 3 注：`agent_scenario.dart` import 是否需补
- Task 7 Step 1：现有 prompt 测试风格
