# 书架增删写入收口 Notifier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 根治"书架写入后不刷新"的架构缺陷——所有改书架数据的写路径收口到 `BookshelfMutationNotifier`,接口瘦身后编译期阻止绕过。

**Architecture:** 接口瘦身(`INovelRepository` / `IBookshelfRepository` 移除书架写方法)→ 内部 `IBookshelfWriter` / `IBookshelfAssociationWriter` 暴露给 Notifier → Notifier 内部 `_wrap` 统一"写 + invalidate"。所有调用点迁移到 Notifier。

**Tech Stack:** Flutter / Dart 3 / Riverpod 2(`@riverpod` codegen)/ `@riverpod` 注解生成的 Notifier。

## Global Constraints

- **不动**: 读方法、`updateLastReadChapter` / `updateBackgroundSetting` / `updateCoverMediaIdById` / `createBookshelf` / `deleteBookshelf` / `updateBookshelf`(这些不属于本 bug 的 `bookshelfNovelsProvider` 刷新面)
- **失效目标**: 只 `ref.invalidate(bookshelfNovelsProvider)`,`bookshelfCacheStatsProvider` 自动级联
- **失败不 invalidate**: `_wrap` 内异常向上抛,不 invalidate(避免半真半假)
- **编译期强制**: 写方法从 `INovelRepository` / `IBookshelfRepository` 移除后,任何残留的 `ref.read(novelRepositoryProvider).addToBookshelf(...)` 会**编译失败**——这是设计的强制力
- **当前 worktree 分支**: `worktree-bookshelf-mutation`(实施期由 dispatcher 建)
- **代码生成**: 改完 `.dart` 后必须跑 `dart run build_runner build --delete-conflicting-outputs` 重新生成 `.g.dart`

## 关键设计决策(实现者必读)

**为什么用两个内部接口而非一个**:
- `IBookshelfWriter` 暴露 `NovelRepository` 的 5 个写方法
- `IBookshelfAssociationWriter` 暴露 `BookshelfRepository` 的 3 个关联表写方法
- 不合并是因为它们来自两个不同的 Repository,合并会污染类型边界。Notifier 内部用两个 getter 各取所需。

**为什么 `bookshelfWriterProvider` 要 cast**:
- `novelRepositoryProvider` 返回 `INovelRepository`(瘦身后无写方法)
- 实现 `NovelRepository implements INovelRepository, IBookshelfWriter`,所以 `ref.watch(novelRepositoryProvider) as NovelRepository` 能拿到写能力
- cast 写法:`ref.watch(novelRepositoryProvider) as dynamic as IBookshelfWriter` 或直接 `as NovelRepository`(实现类)

**为什么 Notifier 不持状态**:
- 是写操作聚合,不是状态机。`build()` 返回 void,方法都是 `Future<T>`
- 状态由 `bookshelfNovelsProvider`(读侧)持有,Notifier 只负责"写完让它失效"

---

## File Structure

| 文件 | 类型 | 职责 |
|---|---|---|
| `lib/core/interfaces/repositories/i_novel_repository.dart` | 改 | 移除 5 个写方法 |
| `lib/repositories/novel_repository.dart` | 改 | 加 `abstract interface class IBookshelfWriter`;createNovel 保留 |
| `lib/core/interfaces/repositories/i_bookshelf_repository.dart` | 改 | 移除 3 个写方法 |
| `lib/repositories/bookshelf_repository.dart` | 改 | 加 `abstract interface class IBookshelfAssociationWriter` |
| `lib/core/providers/database_providers.dart` | 改 | 加 `bookshelfWriterProvider` + `bookshelfAssociationWriterProvider` |
| `lib/core/providers/bookshelf_mutation_provider.dart` | **新建** | `BookshelfMutationNotifier` |
| `test/unit/core/providers/bookshelf_mutation_provider_test.dart` | **新建** | Notifier 单测 |
| `lib/core/providers/chapter_list_providers.dart` | 改 | toggleBookshelf 改调 Notifier |
| `lib/screens/bookshelf_screen.dart` | 改 | 5 处改调 Notifier + 删 invalidate |
| `lib/services/novel_agent/tool_executor/novel_navigation_executor.dart` | 改 | createNovel/addNovel 改调 Notifier |
| `lib/services/novel_agent/tool_executor.dart` | 改 | 调用点透传 |
| `lib/widgets/webview_add_novel_button.dart` | 改 | addNovel 改调 Notifier |

---

## Task 1:接口瘦身 + 内部 Writer 接口(TDD,基座)

**Files:**
- Modify: `lib/core/interfaces/repositories/i_novel_repository.dart`
- Modify: `lib/repositories/novel_repository.dart`
- Modify: `lib/core/interfaces/repositories/i_bookshelf_repository.dart`
- Modify: `lib/repositories/bookshelf_repository.dart`

**Interfaces:**
- Consumes: 现有 Repository 实现(签名不变)
- Produces: `IBookshelfWriter`(5 方法)+ `IBookshelfAssociationWriter`(3 方法),供 Task 3 的 Provider 和 Task 4 的 Notifier 用

**实现要点:**
- `INovelRepository` 删 5 个写方法声明(addToBookshelf / removeFromBookshelf / updateTitle / updateCoverMediaIdByUrl / createNovel)
- `NovelRepository` 加 `abstract interface class IBookshelfWriter {...}` 同文件,`NovelRepository implements INovelRepository, IBookshelfWriter`(实现保留)
- `IBookshelfRepository` 删 3 个写方法(addNovelToBookshelf / removeNovelFromBookshelf / moveNovelToBookshelf)
- `BookshelfRepository` 加 `abstract interface class IBookshelfAssociationWriter {...}`,`BookshelfRepository implements IBookshelfRepository, IBookshelfAssociationWriter`

**注意**: 本 Task 改完后**会编译失败**(其他文件还在调接口已移除的写方法)——这是预期的,Task 4/5 迁移完调用点后才绿。所以本 Task 不要求 `flutter analyze` 全绿,只要求**这两个文件自身**无新错误。

- [ ] **Step 1: 读现状确认行号**

Read `lib/core/interfaces/repositories/i_novel_repository.dart` 全文,确认 5 个写方法的精确行号。同样 Read `lib/repositories/novel_repository.dart` 的类声明行 + 5 个写方法实现行。对 `i_bookshelf_repository.dart` + `bookshelf_repository.dart` 同样。

- [ ] **Step 2: 瘦身 `INovelRepository`**

从 `lib/core/interfaces/repositories/i_novel_repository.dart` 删除这 5 个声明(连同 doc comment):
```dart
Future<int> addToBookshelf(Novel novel);
Future<int> removeFromBookshelf(String novelUrl);
Future<int> updateTitle(String novelUrl, String newTitle);
Future<int> updateCoverMediaIdByUrl(String novelUrl, String? mediaId);
Future<Novel> createNovel({...});
```
保留所有读方法 + `updateLastReadChapter` / `updateBackgroundSetting` / `updateCoverMediaIdById` / `updateBackgroundSettingById` 等。

- [ ] **Step 3: 加 `IBookshelfWriter` 到 `novel_repository.dart`**

在 `lib/repositories/novel_repository.dart` 加:
```dart
/// 书架写操作能力接口(NovelRepository 实现,不导出)。
///
/// 仅 [BookshelfMutationNotifier] 通过 bookshelfWriterProvider 持有此类型引用。
/// 设计意图: 写方法从 INovelRepository 移除后,普通调用方拿不到这些方法,
/// 编译期阻止"直接写库忘 invalidate"。
abstract interface class IBookshelfWriter {
  Future<int> addToBookshelf(Novel novel);
  Future<int> removeFromBookshelf(String novelUrl);
  Future<int> updateTitle(String novelUrl, String newTitle);
  Future<int> updateCoverMediaIdByUrl(String novelUrl, String? mediaId);
  Future<Novel> createNovel({
    required String title,
    required String author,
    String? coverUrl,
    String? description,
    String? backgroundSetting,
  });
}
```
改类声明:
```dart
class NovelRepository extends BaseRepository
    implements INovelRepository, IBookshelfWriter {
```
(5 个写方法实现保留,签名不变)

- [ ] **Step 4: 瘦身 `IBookshelfRepository`**

从 `lib/core/interfaces/repositories/i_bookshelf_repository.dart` 删 3 个写方法声明:
```dart
Future<void> addNovelToBookshelf(String novelUrl, int bookshelfId);
Future<bool> removeNovelFromBookshelf(String novelUrl, int bookshelfId);
Future<void> moveNovelToBookshelf(String novelUrl, int fromBookshelfId, int toBookshelfId);
```

- [ ] **Step 5: 加 `IBookshelfAssociationWriter` 到 `bookshelf_repository.dart`**

在 `lib/repositories/bookshelf_repository.dart` 加:
```dart
/// 书架关联表写操作能力接口(BookshelfRepository 实现,不导出)。
abstract interface class IBookshelfAssociationWriter {
  Future<void> addNovelToBookshelf(String novelUrl, int bookshelfId);
  Future<bool> removeNovelFromBookshelf(String novelUrl, int bookshelfId);
  Future<void> moveNovelToBookshelf(
      String novelUrl, int fromBookshelfId, int toBookshelfId);
}
```
改类声明:
```dart
class BookshelfRepository extends BaseRepository
    implements IBookshelfRepository, IBookshelfAssociationWriter {
```

- [ ] **Step 6: 确认两文件自身无新错误**

Run: `cd novel_app && flutter analyze lib/repositories/novel_repository.dart lib/repositories/bookshelf_repository.dart lib/core/interfaces/repositories/i_novel_repository.dart lib/core/interfaces/repositories/i_bookshelf_repository.dart`

Expected: 这 4 个文件**自身**无新错误(注:`flutter analyze` 整项目此刻会因调用点未迁移而报错,这是预期,不在本 Step 范围)。

- [ ] **Step 7: Commit**

```bash
git add lib/core/interfaces/repositories/i_novel_repository.dart \
        lib/repositories/novel_repository.dart \
        lib/core/interfaces/repositories/i_bookshelf_repository.dart \
        lib/repositories/bookshelf_repository.dart
git commit -m "refactor(bookshelf): 接口瘦身 - 写方法移出 INovelRepository/IBookshelfRepository

引入内部 IBookshelfWriter(5 方法)+ IBookshelfAssociationWriter(3 方法)
供 BookshelfMutationNotifier 用;编译期阻止绕过 Notifier 直接写。
调用点迁移在后续 Task(此时全项目 analyze 会报错,预期)。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2:Writer Provider(database_providers)

**Files:**
- Modify: `lib/core/providers/database_providers.dart`

**Interfaces:**
- Consumes: Task 1 的 `IBookshelfWriter` / `IBookshelfAssociationWriter`
- Produces: `bookshelfWriterProvider` + `bookshelfAssociationWriterProvider`,供 Task 4 Notifier 用

- [ ] **Step 1: 读现状确认 import 与位置**

Read `lib/core/providers/database_providers.dart` 的 import 区 + `novelRepositoryProvider` 定义行(约 40-50)+ `bookshelfRepositoryProvider`(约 114-118)。

- [ ] **Step 2: 加 import**

确保文件 import 了 `IBookshelfWriter` / `IBookshelfAssociationWriter`(它们在 repository 实现文件里定义,import `novel_repository.dart` / `bookshelf_repository.dart` 即可——检查是否已 import)。

- [ ] **Step 3: 加两个 Provider**

在 `database_providers.dart` 适当位置(novelRepositoryProvider 之后)加:
```dart
/// 书架写操作 Provider(仅 [BookshelfMutationNotifier] 用)。
///
/// 通过 cast 拿到 [NovelRepository] 的 IBookshelfWriter 能力。
/// 普通调用方应使用 [bookshelfMutationProvider] 走收口路径。
@riverpod
IBookshelfWriter bookshelfWriter(Ref ref) {
  return ref.watch(novelRepositoryProvider) as NovelRepository;
}

/// 书架关联表写操作 Provider(仅 [BookshelfMutationNotifier] 用)。
@riverpod
IBookshelfAssociationWriter bookshelfAssociationWriter(Ref ref) {
  return ref.watch(bookshelfRepositoryProvider) as BookshelfRepository;
}
```

- [ ] **Step 4: 代码生成**

Run: `cd novel_app && dart run build_runner build --delete-conflicting-outputs`
Expected: 生成 `database_providers.g.dart` 含两个新 Provider,无错误。

- [ ] **Step 5: Commit**

```bash
git add lib/core/providers/database_providers.dart lib/core/providers/database_providers.g.dart
git commit -m "feat(bookshelf): 加 bookshelfWriter/AssociationWriter Provider

为 BookshelfMutationNotifier 提供 IBookshelfWriter /
IBookshelfAssociationWriter 入口;通过 cast NovelRepository /
BookshelfRepository 暴露写能力。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3:BookshelfMutationNotifier + 单测(TDD)

**Files:**
- Create: `lib/core/providers/bookshelf_mutation_provider.dart`
- Create: `test/unit/core/providers/bookshelf_mutation_provider_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `IBookshelfWriter` / `IBookshelfAssociationWriter`、Task 2 的两个 Provider、现有 `novelRepositoryProvider`(isInBookshelf)、`bookshelfNovelsProvider`(invalidate 目标)
- Produces: `BookshelfMutationNotifier` + `bookshelfMutationProvider`(8 方法:addNovel/removeNovel/toggleBookshelf/updateTitle/updateCoverMediaId/removeCoverMediaId/moveToBookshelf/createNovel)

- [ ] **Step 1: 写失败测试**

Create `test/unit/core/providers/bookshelf_mutation_provider_test.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:novel_app/core/providers/bookshelf_mutation_provider.dart';
import 'package:novel_app/core/providers/bookshelf_providers.dart';
import 'package:novel_app/core/providers/database_providers.dart';
import 'package:novel_app/core/interfaces/repositories/i_novel_repository.dart';
import 'package:novel_app/models/novel.dart';
// 也可能需要 mock IBookshelfWriter / IBookshelfAssociationWriter,见下

class _MockNovelRepo extends Mock implements INovelRepository {}
// 注:IBookshelfWriter / IBookshelfAssociationWriter 是 abstract interface class,
// mock 实现: 让 mock 类同时 implements 多接口,或单独 mock。实现期按实际定。

void main() {
  late ProviderContainer container;

  setUp(() {
    // override novelRepositoryProvider / bookshelfWriterProvider / bookshelfAssociationWriterProvider
    // 注入 mock。setup 细节实现期定。
  });

  test('addNovel 调 writer.addToBookshelf + invalidate bookshelfNovelsProvider', () async {
    // 调 container.read(bookshelfMutationProvider).addNovel(novel)
    // verify writer.addToBookshelf called once
    // verify bookshelfNovelsProvider 被 invalidate(可通过监听其状态变化判断)
  });

  // 其余 7 方法同模式
  // toggleBookshelf 双分支(add/remove)各测
  // _wrap 失败不 invalidate:writer 抛异常 → expect throws + no invalidate
}
```

> 测试细节(invalidate 验证手段)在实现期按 Riverpod 测试惯例补全:用 `ProviderContainer` + `listener` 监听 `bookshelfNovelsProvider.future`,或在 mock writer 抛异常时验证它没被重新拉取。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/unit/core/providers/bookshelf_mutation_provider_test.dart`
Expected: FAIL(类未定义)。

- [ ] **Step 3: 实现 Notifier**

Create `lib/core/providers/bookshelf_mutation_provider.dart`(见 spec §3.4 完整代码)。

- [ ] **Step 4: 代码生成 + 跑测试**

```bash
cd novel_app
dart run build_runner build --delete-conflicting-outputs
flutter test test/unit/core/providers/bookshelf_mutation_provider_test.dart
```
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/core/providers/bookshelf_mutation_provider.dart \
        lib/core/providers/bookshelf_mutation_provider.g.dart \
        test/unit/core/providers/bookshelf_mutation_provider_test.dart
git commit -m "feat(bookshelf): BookshelfMutationNotifier 收口所有书架写

8 个方法(addNovel/removeNovel/toggleBookshelf/updateTitle/
updateCoverMediaId/removeCoverMediaId/moveToBookshelf/createNovel)
经 _wrap 统一'写库 + invalidate(bookshelfNovelsProvider)';
失败不 invalidate(避免半真半假)。
单测覆盖每个方法的 repo 调用 + invalidate + 失败分支。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4:迁移 chapter_list_providers + bookshelf_screen 调用点

**Files:**
- Modify: `lib/core/providers/chapter_list_providers.dart`(行 400, 402)
- Modify: `lib/screens/bookshelf_screen.dart`(行 51, 79, 134, 167, 362 + 删 invalidate 56/84/135/168/367)

**Interfaces:**
- Consumes: Task 3 的 `bookshelfMutationProvider`
- Produces: 调用点全部经 Notifier

- [ ] **Step 1: 迁移 `chapter_list_providers.dart` toggleBookshelf**

Read `lib/core/providers/chapter_list_providers.dart:396-410`,把:
```dart
final novelRepository = ref.read(novelRepositoryProvider);
// ...
if (...) await novelRepository.removeFromBookshelf(novel.url);
else await novelRepository.addToBookshelf(novel);
```
改为:
```dart
await ref.read(bookshelfMutationProvider).toggleBookshelf(novel);
```
(toggleBookshelf 内部封装了 isInBookshelf 判断 + add/remove + invalidate,调用方逻辑简化)

import 加 `bookshelf_mutation_provider.dart`。

- [ ] **Step 2: 迁移 `bookshelf_screen.dart` 5 处**

逐行迁移(精确行号实现期再核对):
- 行 51 `removeFromBookshelf` → `ref.read(bookshelfMutationProvider).removeNovel(novel.url)`
- 行 79 `updateTitle` → `ref.read(bookshelfMutationProvider).updateTitle(...)`
- 行 134 `updateCoverMediaIdByUrl(..., mediaId)` → `ref.read(bookshelfMutationProvider).updateCoverMediaId(..., mediaId)`
- 行 167 `updateCoverMediaIdByUrl(..., null)` → `ref.read(bookshelfMutationProvider).removeCoverMediaId(...)`
- 行 362 `bookshelfRepository.moveNovelToBookshelf(...)` → `ref.read(bookshelfMutationProvider).moveToBookshelf(novel.url, currentBookshelfId, toBookshelfId)`

import 加 `bookshelf_mutation_provider.dart`。

- [ ] **Step 3: 删除 `bookshelf_screen.dart` 内多余的 invalidate**

迁移后,这些行(在 56/84/135/168/367 附近)的 `ref.invalidate(bookshelfNovelsProvider)` 可删——Notifier 内部已统一失效。**先 grep 确认这些 invalidate 紧邻刚迁移的写调用**(即同 try 块、确实是为该写服务的),再删。行 580(下拉刷新)的 invalidate **保留**(那是独立的刷新操作,不经过 Notifier)。

- [ ] **Step 4: analyze + 跑相关测试**

```bash
cd novel_app
flutter analyze lib/core/providers/chapter_list_providers.dart lib/screens/bookshelf_screen.dart
flutter test test/unit/
```
Expected: analyze 无新错误;测试通过(若有现成测试)。

- [ ] **Step 5: Commit**

```bash
git add lib/core/providers/chapter_list_providers.dart lib/screens/bookshelf_screen.dart
git commit -m "refactor(bookshelf): chapter_list/bookshelf_screen 写调用迁移到 Notifier

toggleBookshelf / removeNovel / updateTitle / updateCoverMediaId /
moveToBookshelf 全部改调 bookshelfMutationProvider;删除屏内多余的
invalidate(Notifier 已统一失效)。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5:迁移 Agent 工具 + 浏览器 FAB 调用点

**Files:**
- Modify: `lib/services/novel_agent/tool_executor/novel_navigation_executor.dart:85`
- Modify: `lib/services/novel_agent/tool_executor.dart:91`
- Modify: `lib/widgets/webview_add_novel_button.dart:251`

**Interfaces:**
- Consumes: Task 3 的 `bookshelfMutationProvider`

- [ ] **Step 1: 迁移 `novel_navigation_executor.dart`**

Read 行 80-90 上下文。把 `final id = await novelRepository.addToBookshelf(novel);` 改为:
```dart
await ref.read(bookshelfMutationProvider).addNovel(novel);
// 注:addNovel 不返回 id;若调用方需要 id,Notifier.addNovel 也应返回 Future<int>(实现期决定)
```
**注意**: `addToBookshelf` 返回 `Future<int>`(插入的 id),Agent 工具可能用到这个 id。若需要,Notifier.addNovel 改为 `Future<int>` 返回 writer 的返回值(spec 里是 `Future<void>`,实施期按需调整签名)。

确认 `novel_navigation_executor` 持有 `Ref`(能 `ref.read`)。如果不持有,需要从外层传入或改方法签名——实现期按现有代码定。

- [ ] **Step 2: 迁移 `tool_executor.dart:91`**

Read 上下文。`_novelNav.createNovel(args)` → `ref.read(bookshelfMutationProvider).createNovel(...)`(透传 args)。同样确认 Ref 可用性。

- [ ] **Step 3: 迁移 `webview_add_novel_button.dart:251`**

`await novelRepo.addToBookshelf(Novel(...))` → `await ref.read(bookshelfMutationProvider).addNovel(Novel(...))`。该 widget 已用 `ref.read`(行 210 `ref.read(novelRepositoryProvider)`),所以 ref 可用。

- [ ] **Step 4: analyze 全项目 + 跑全套相关测试**

```bash
cd novel_app
flutter analyze
flutter test test/unit/services/novel_agent/ test/unit/core/providers/ test/unit/screens/
```
Expected: analyze 全绿(此时所有调用点都迁移完,Task 1 的接口瘦身不再报错);测试通过。

- [ ] **Step 5: Commit**

```bash
git add lib/services/novel_agent/tool_executor/novel_navigation_executor.dart \
        lib/services/novel_agent/tool_executor.dart \
        lib/widgets/webview_add_novel_button.dart
git commit -m "refactor(bookshelf): Agent 工具 + 浏览器 FAB 迁移到 Notifier

novel_navigation_executor.addNovel / tool_executor.createNovel /
webview_add_novel_button.addNovel 全部改调 bookshelfMutationProvider。
修复浏览器添加小说后书架不刷新的根因(同类 Agent createNovel 一起修)。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6:整项目绿 + 手动验证 + 收尾

**Files:** 无(验证 + 文档)

- [ ] **Step 1: 全项目 analyze + 全套测试**

```bash
cd novel_app
flutter analyze
flutter test
```
Expected: analyze 无 error(可能有 info 级 pre-existing,忽略);测试除已知 pre-existing widget test 失败外全绿。

- [ ] **Step 2: 手动端到端验证(真机/模拟器)**

1. `flutter run` 启动
2. 浏览器 Tab 打开一个有 chapter_list_js 的站点 → WebViewAddNovelFab 出现 → 点添加
3. **立即切到书架 Tab**(不切书架分类)→ 看到新增小说 ✅(本次修复目标)
4. 章节页"加入/移出书架" → 立即切书架 → 状态正确
5. (可选)Agent createNovel 工具跑一次 → 书架可见

- [ ] **Step 3: 更新 CLAUDE.md changelog**

在根 `CLAUDE.md` `## 变更记录` 顶部加(日期 2026-07-28):
```markdown
- **2026-07-28**: **书架写入收口 Notifier 重构(根治刷新 bug)**。`BookshelfMutationNotifier` 收口所有改书架数据的写路径(addNovel/removeNovel/toggleBookshelf/updateTitle/updateCoverMediaId/removeCoverMediaId/moveToBookshelf/createNovel),内部 `_wrap` 统一"写库 + invalidate(bookshelfNovelsProvider)"。接口瘦身:`INovelRepository` 移除 5 个写方法、`IBookshelfRepository` 移除 3 个写方法,新增内部 `IBookshelfWriter`/`IBookshelfAssociationWriter` 仅 Notifier 通过 `bookshelfWriterProvider`/`bookshelfAssociationWriterProvider` 持有 → **编译期阻止绕过 Notifier 直接写库**。迁移 6 个调用点(浏览器 FAB/Agent createNovel/章节页 toggleBookshelf/书架页 5 处)。根治"浏览器添加小说后书架不刷新"根因。详见 spec + plan。
```

- [ ] **Step 4: Commit**

```bash
cd ..
git add CLAUDE.md
git commit -m "docs: CLAUDE.md changelog 记录书架写入收口 Notifier 重构

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Self-Review(已执行)

**1. Spec coverage:**
- §2 架构(收口 Notifier + 接口瘦身)→ Task 1-5 ✓
- §3.1 接口瘦身(5+3 方法)→ Task 1 ✓
- §3.2-3.3 内部接口 + Writer Provider → Task 1-2 ✓
- §3.4 Notifier → Task 3 ✓
- §3.5 调用点迁移(10 处)→ Task 4(2+5)+ Task 5(3)= 10 ✓
- §3.6 删多余 invalidate → Task 4 Step 3 ✓
- §4 测试 → Task 3 单测 + Task 6 回归 ✓
- §5 风险 → Task 5 Step 1 注:addNovel 返回值 id 处理 ✓

**2. Placeholder scan:** Task 5 Step 1 提到"addNovel 若需返回 id 则改签名"——这是真实不确定性(取决于 Agent 工具是否用 id),实现期 Step 1 Read 后定。其他无占位符。

**3. Type consistency:**
- `IBookshelfWriter` 在 Task 1 定义 → Task 2 Provider 返回它 → Task 3 Notifier `_writer` getter 持它 ✓
- `bookshelfMutationProvider` 在 Task 3 定义 → Task 4/5 调用方 `ref.read(bookshelfMutationProvider)` ✓
- 方法名:addNovel/removeNovel/toggleBookshelf/updateTitle/updateCoverMediaId/removeCoverMediaId/moveToBookshelf/createNovel 在 Task 3 定义、Task 4/5 调用一致 ✓

**4. 依赖排序:** Task 1(接口)→ Task 2(Provider)→ Task 3(Notifier)→ Task 4/5(调用点)→ Task 6(验证)。每 Task 输出是下 Task 输入 ✓

**5. 已知 pre-existing:** 整项目 analyze 时 Task 1 后会临时报错(调用点未迁移),Task 5 完成后转绿——这是设计的强制力表现,plan 已在每个 Task 标注 ✓

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-28-bookshelf-mutation-notifier.md`. 推荐用 subagent-driven-development 执行(6 个 Task 相对独立,逐 Task 派 implementer + reviewer)。
