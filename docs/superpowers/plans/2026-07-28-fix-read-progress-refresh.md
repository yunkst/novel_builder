# 修复阅读进度不刷新 bug Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复"用户阅读完返回书架,看不到阅读进度及时更新"的同类架构 bug——把 `updateLastReadChapter` 写库收口到 `BookshelfMutationNotifier`,内部 `_wrap` 统一"写库 + invalidate(bookshelfNovelsProvider)"。

**Architecture:** 现有 `BookshelfMutationNotifier`(`worktree-bookshelf-mutation` 已合并)加 1 个新方法 `updateReadProgress(String novelUrl, int chapterIndex)`,内部走 `_wrap(() => _writer.updateLastReadChapter(...))`。`ReaderContentController.updateReadingProgress` 改调 Notifier 而不是直接调 `_novelRepository.updateLastReadChapter`。顺手补 2 个单测(成功 + 失败不 invalidate)。

**Tech Stack:** Flutter / Dart / Riverpod 2(`@riverpod` codegen)。

## Global Constraints

- **不在本书架 mutation Notifier scope 范围外改动**: 本 Task 只加 1 个方法 + 改 1 个调用点 + 补 2 个单测
- **不动 ChapterRepository / ChapterList 域**(markChapterAsRead 等同类 bug 已记 memory 独立 issue)
- **`updateLastReadChapter` 在 `INovelRepository` 接口保留**(refactor 时就保留,不需重新瘦身)
- **调用方式必须 `.notifier`**(build 返回 void,`ref.read(bookshelfMutationProvider.notifier).xxx(...)`)
- **失败不 invalidate**(沿用现有 `_wrap` 语义)
- **代码生成**: 改完 Notifier 后跑 `dart run build_runner build --delete-conflicting-outputs`
- **worktree 分支**: `worktree-fix-read-progress-refresh`

## 关键设计决策

**为什么 Notifier 方法叫 `updateReadProgress` 而不叫 `updateLastReadChapter`**:
- `BookshelfMutationNotifier` 上现有方法都用动词+名词(`addNovel`/`updateTitle`/`updateCoverMediaId`),而非 Repository 内部名(`addToBookshelf`/`updateLastReadChapter`)。保持对外 API 风格一致。
- "ReadProgress" 比 "LastReadChapter" 更面向 UI 语义——Agent / 业务侧叫"进度",内部实现细节叫什么不暴露。

**为什么 Notifier 内部仍调 `_writer.updateLastReadChapter`**:
- Repository 层方法名是历史约定,不改。Notifier 改名只是为了对外 API 一致。
- `_writer` 是 `IBookshelfWriter` 类型,已有 `updateLastReadChapter` 方法(因为 refactor 时保留在 `INovelRepository` 没移走——正好)。

---

## File Structure

| 文件 | 类型 | 职责 |
|---|---|---|
| `novel_app/lib/core/providers/bookshelf_mutation_provider.dart` | 改 | 新增 `updateReadProgress` 方法 + dartdoc 更新 |
| `novel_app/test/unit/core/providers/bookshelf_mutation_provider_test.dart` | 改 | 补 2 个单测(成功 + 失败) |
| `novel_app/lib/controllers/reader_content_controller.dart` | 改 | 行 211 直接 Repository 调 → 改调 Notifier |

---

## Task 1:Notifier 加 updateReadProgress + 单测(TDD)

**Files:**
- Modify: `novel_app/lib/core/providers/bookshelf_mutation_provider.dart`
- Modify: `novel_app/test/unit/core/providers/bookshelf_mutation_provider_test.dart`

**Interfaces:**
- Consumes: 现有 `BookshelfMutationNotifier` + `IBookshelfWriter.updateLastReadChapter`(已在 Task 1 完成的接口瘦身里保留)
- Produces: `Future<void> updateReadProgress(String novelUrl, int chapterIndex)` 公共方法

- [ ] **Step 1: 写失败测试**

Read `novel_app/test/unit/core/providers/bookshelf_mutation_provider_test.dart`,参照 moveBookshelf 成功/失败测试模板(行 426-456 附近),在文件末尾追加 2 个新测试:

```dart
  test('updateReadProgress 调 writer.updateLastReadChapter + invalidate', () async {
    final before = novelsReloadCount;
    await container.read(bookshelfMutationProvider.notifier).updateReadProgress(
          'https://x.com/n1',
          42,
        );
    expect(fakeWriter.lastProgressUpdate, ('https://x.com/n1', 42));
    expect(novelsReloadCount, greaterThan(before));
  });

  test('updateReadProgress writer 抛异常 → 上抛 + 不 invalidate', () async {
    fakeWriter.progressUpdateThrowOnce = StateError('progress write fail');
    final before = novelsReloadCount;
    await expectLater(
      container.read(bookshelfMutationProvider.notifier).updateReadProgress('u', 1),
      throwsA(isA<StateError>()),
    );
    expect(novelsReloadCount, equals(before));
  });
```

注意:
- `_FakeBookshelfWriter`(test 文件内手写)需要加 `lastProgressUpdate` 字段 + `progressUpdateThrowOnce` 槽。Read `_FakeBookshelfWriter` 实现确认现有字段,按同样模式加。
- 测试前 `container` 用现有 setUp(应当已存在)。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/unit/core/providers/bookshelf_mutation_provider_test.dart`
Expected: FAIL(`updateReadProgress` 未定义 / fake 字段不存在)。

- [ ] **Step 3: 改 `_FakeBookshelfWriter` 加新字段**

在测试文件内的 `_FakeBookshelfWriter` 类(位置按 grep 找)追加:

```dart
  /// 测试用:记录 updateReadProgress 调用的参数
  (String, int)? lastProgressUpdate;
  
  /// 测试用:首次 updateLastReadChapter 抛此异常(一次后置 null)
  Object? progressUpdateThrowOnce;
```

并在其 `updateLastReadChapter` 方法实现里加上:
```dart
  @override
  Future<int> updateLastReadChapter(String novelUrl, int chapterIndex) async {
    lastProgressUpdate = (novelUrl, chapterIndex);
    final err = progressUpdateThrowOnce;
    if (err != null) {
      progressUpdateThrowOnce = null;
      throw err;
    }
    return 0; // 模拟成功插入 0 行(语义不重要,测试只关心是否调用 + invalidate)
  }
```

(对照现有 `addToBookshelf` 的 fake 实现写,模仿其 throwOnce / lastAddedNovel 模式。)

- [ ] **Step 4: Notifier 加 `updateReadProgress` 方法**

在 `bookshelf_mutation_provider.dart` 类内(在 `updateTitle` 之后或合适位置)加:

```dart
/// 更新小说最后阅读章节(阅读进度)。
///
/// 阅读器每次加载章节时调用。改 bookshelf 表的 lastReadChapter / lastReadTime,
/// 影响书架页进度条 + 排序(`getNovelsByBookshelf` 按 lastReadTime DESC)。
Future<void> updateReadProgress(String novelUrl, int chapterIndex) =>
    _wrap(() => _writer.updateLastReadChapter(novelUrl, chapterIndex));
```

并在类 dartdoc 顶部"8 方法"列表更新为"10 方法"(add/updateReadProgress)。

- [ ] **Step 5: 跑测试确认通过**

Run: `flutter test test/unit/core/providers/bookshelf_mutation_provider_test.dart`
Expected: PASS(20 个用例:原 18 + 新 2)。

- [ ] **Step 6: Commit**

```bash
cd /d/my_space/novel_builder/.claude/worktrees/fix-read-progress-refresh/novel_app
cd ../..
git add novel_app/lib/core/providers/bookshelf_mutation_provider.dart \
        novel_app/test/unit/core/providers/bookshelf_mutation_provider_test.dart
git commit -m "feat(bookshelf): Notifier 加 updateReadProgress + 2 单测

阅读器每次加载章节调,改 bookshelf.lastReadChapter/Time。
经 _wrap 统一写库 + invalidate(bookshelfNovelsProvider),修复
'阅读完返回书架看不到进度更新'同类 bug。
配合 commit 后续调 reader_content_controller:211 走 Notifier。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2:ReaderContentController 改调 Notifier

**Files:**
- Modify: `novel_app/lib/controllers/reader_content_controller.dart`

**Interfaces:**
- Consumes: `BookshelfMutationNotifier.updateReadProgress`
- Produces: 行 211 `_novelRepository.updateLastReadChapter(...)` → `ref.read(bookshelfMutationProvider.notifier).updateReadProgress(...)`

- [ ] **Step 1: 改 ReaderContentController.updateReadingProgress**

Read `novel_app/lib/controllers/reader_content_controller.dart:208-220`(整个 `updateReadingProgress` 方法)。

行 211 `_novelRepository.updateLastReadChapter(novelUrl, chapterIndex);` 改为:
```dart
await ref.read(bookshelfMutationProvider.notifier).updateReadProgress(
  novelUrl,
  chapterIndex,
);
```

注意:
- `ref` 必须可用——ReaderContentController 是 Provider? Riverpod StateNotifier? 如果它**没有** ref 字段,需要从构造函数注入(`_ref` 或 `Ref`)。Read 构造函数 + 类声明确认。
- 如果当前没有 ref,可能需要把 `ref.read(bookshelfMutationProvider.notifier)` 提到方法签名外部传入,或者改成 ReaderContentController 持有 Ref。这是实现期要小心的点——brief 没有把握的精确信息,实施期 Read 决定具体接法。

- [ ] **Step 2: analyze + 测试**

```bash
cd novel_app
flutter analyze lib/controllers/reader_content_controller.dart
flutter test test/unit/controllers/reader_content_controller_test.dart 2>&1 | tail -2 || true
```
Expected: analyze 干净(若有测试,无回归)。

- [ ] **Step 3: 手动端到端验证(如果环境允许)**

启动 App → 打开书架 → 进入阅读器 → 阅读几章 → 返回书架 → 进度条应反映新章节(以前会卡在旧进度)。

- [ ] **Step 4: Commit**

```bash
cd ..
git add novel_app/lib/controllers/reader_content_controller.dart
git commit -m "fix(reader): updateReadingProgress 改调 BookshelfMutationNotifier

原直接调 _novelRepository.updateLastReadChapter,绕过 Notifier,
书架返回后看不到进度更新。改走 Notifier 走 _wrap 自动 invalidate。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3:CLAUDE.md changelog + 收尾

**Files:**
- Modify: `CLAUDE.md`(根)

- [ ] **Step 1: 整项目 analyze + 测试**

```bash
cd novel_app
flutter analyze 2>&1 | tail -3
flutter test test/unit/ 2>&1 | tail -2
```
Expected: 0 error;1417+ 单测全过(原 1415 + 2 新)。

- [ ] **Step 2: 更新 CLAUDE.md changelog**

在根 `CLAUDE.md` `## 变更记录` 顶部(2026-07-28 书架收口那条之后)加:
```markdown
- **2026-07-28**: **修复阅读进度不刷新 bug**。`BookshelfMutationNotifier` 增 `updateReadProgress(String novelUrl, int chapterIndex)`,内部 `_wrap` 统一"写库 + invalidate(bookshelfNovelsProvider)"。`ReaderContentController.updateReadingProgress` 改调 Notifier 而不是直接调 `NovelRepository.updateLastReadChapter`。修复"阅读完返回书架看不到进度更新"——书架页进度条 + 排序(`getNovelsByBookshelf` 按 lastReadTime DESC)同步受影响。补 2 个 Notifier 单测。markChapterAsRead(章节列表已读高亮同类 bug)记录独立 issue 待后续重构。详见 spec + plan。
```

- [ ] **Step 3: Commit + push worktree 分支(不 push)**

```bash
cd ..
git add CLAUDE.md
git commit -m "docs: CLAUDE.md changelog 记录阅读进度刷新 bug 修复

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Self-Review(已执行)

**1. Spec coverage:**
- §"Goal": ✅ Task 1+2 闭环
- §"Architecture": Notifier 加 1 方法 + 调用点改,✅
- §"Global Constraints": 全部已纳入各 Task 约束
- §"File Structure": 3 文件,✅

**2. Placeholder scan:** Task 2 Step 1 标注 "Read 构造函数 + 类声明确认"——这是合理的不确定点,ReaderContentController 是否有 ref 需要实施期确认。其他步骤无占位符。

**3. Type consistency:**
- `updateReadProgress(String, int)` 在 Notifier 定义、调用方使用、单测 mock 一致 ✓
- `_FakeBookshelfWriter` 新字段与现有 throwOnce 模式一致 ✓

**4. Scope 边界:**
- 严格 3 文件改动 ✓
- 不动 ChapterRepository / ChapterList(memory 已记独立 issue)✓
- 不动 INovelRepository 接口(refactor 时保留)✓

**5. 已知风险:** Task 2 Step 1 `ref` 可用性是真实不确定点——实施期 Read 决定。这是 spec 显式标注的非 trivial 决策点,不是 placeholder。