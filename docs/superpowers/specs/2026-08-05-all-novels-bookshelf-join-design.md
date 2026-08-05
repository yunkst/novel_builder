# 全部小说书架"加入书架"语义修复 设计

- **日期**: 2026-08-05
- **状态**: 设计已确认，待用户复核 spec
- **相关代码**:
  - `novel_app/lib/repositories/bookshelf_repository.dart` (`moveNovelToBookshelf`, `:361`)
  - `novel_app/lib/screens/bookshelf_screen.dart` (`_showNovelMenu`, `:403`；`_showBookshelfSelectionDialog`, `:276`；`_moveNovelToBookshelf`, `:352`；`_copyNovelToBookshelf`, `:378`)
  - `novel_app/lib/core/providers/bookshelf_mutation_provider.dart` (`moveToBookshelf`, `:88`；`copyToBookshelf`, `:105`)
- **背景**:
  - 书架写入收口 Notifier 重构（2026-07-28）已将所有书架写路径收敛到 `BookshelfMutationNotifier`，但未处理"全部小说"虚拟书架下的语义冲突。
  - 用户反馈：「全部小说 这个书架比较诡异，然后从 全部小说 这个书架移动图书会直接失败」。

## 1. 问题诊断

### 1.1 "全部小说"是虚拟书架

`bookshelfNovelsProvider`（`bookshelf_providers.dart:68`）经 `BookshelfRepository.getNovelsByBookshelf`（`bookshelf_repository.dart:207`）查询：

- `bookshelfId == 1`（"全部小说"）：直接 `db.query('bookshelf', orderBy: 'lastReadTime DESC, addedAt DESC')` —— 查所有小说元数据行，**不读 `novel_bookshelves` 关联表**。
- 其他书架：`INNER JOIN novel_bookshelves` 按关联表过滤。

因此：一本书只要在 `bookshelf` 表里有一行（即"加入书架"过），就**永远**出现在"全部小说"中。它没有 `bookshelf_id=1` 的关联行可以被删除。

### 1.2 移动失败的直接原因

`BookshelfRepository.moveNovelToBookshelf`（`bookshelf_repository.dart:361-396`）：

```dart
if (fromBookshelfId == 1 || toBookshelfId == 1) {
  throw ArgumentError('不能从/到"全部小说"书架移动小说');  // ← 硬编码失败
}
```

UI 在"全部小说"书架下仍渲染"移动到书架"菜单项（`bookshelf_screen.dart:436-444`），用户点击后 `_moveNovelToBookshelf`（`:352`）传入 `currentBookshelfId = 1`，Repository 抛 `ArgumentError`，`_moveNovelToBookshelf` 的 catch 块（`:365-374`）弹"移动失败"。

**这不是偶发 bug，是设计冲突**：UI 给了入口，Repository 拒绝执行。

### 1.3 语义冗余

`moveNovelToBookshelf` 的语义是"关联表 add(to) + remove(from)"。但在"全部小说"（虚拟书架）下：

- **remove(from=1)**：`removeNovelFromBookshelf(_, 1)` 本就返回 `false`（`:319-326`，日志 warning "不能从全部小说书架移除小说"），是 no-op。
- **add(to)**：正常往目标书架加关联。

所以在"全部小说"下，"移动"和"复制"的实际效果**完全相同**——都只是"往目标书架加关联，书仍留在全部小说"。当前 UI 给了两个名义不同的入口，但"移动"那条路是死的。

## 2. 设计目标

1. **修复失败**：在"全部小说"书架下，"加入目标书架"操作不再抛错、不再弹"失败"。
2. **语义诚实**：虚拟书架下 UI 不再用"移动"这个词误导用户以为书会离开当前列表。
3. **最小改动**：不重构"全部小说"为真实书架（避免破坏"全部小说=所有书的并集"语义），不新增 Notifier 方法，不影响其他 add 路径（章节页 toggleBookshelf / 浏览器 FAB / Agent create_novel）。

## 3. 方案

采用**方案 A**：Repository 层放宽 `fromBookshelfId==1` 特例为 add-only；UI 层在"全部小说"下把"移动/复制"合并为单一"加入书架"入口。

### 3.1 Repository 层：`moveNovelToBookshelf` 放宽 from=1

**文件**：`bookshelf_repository.dart:361`

**现状**：
```dart
if (fromBookshelfId == 1 || toBookshelfId == 1) {
  throw ArgumentError('不能从/到"全部小说"书架移动小说');
}
if (fromBookshelfId == toBookshelfId) { ... return; }
await addNovelToBookshelf(novelUrl, toBookshelfId);
final removed = await removeNovelFromBookshelf(novelUrl, fromBookshelfId);
```

**改后**：
```dart
// to=1（往虚拟书架"移入"）无意义：UI 选择对话框已过滤 id=1，保留为防御性断言。
if (toBookshelfId == 1) {
  throw ArgumentError('不能移动到"全部小说"虚拟书架');
}
// from=1（从虚拟书架"移出"）：虚拟书架无关联可删，降级为 add-only。
// 书仍留在"全部小说"（它本来就在 bookshelf 表里），等价于"加入目标书架"。
if (fromBookshelfId == toBookshelfId) { ... return; }
await addNovelToBookshelf(novelUrl, toBookshelfId);
if (fromBookshelfId != 1) {
  await removeNovelFromBookshelf(novelUrl, fromBookshelfId);
}
```

**关键点**：
- `from=1` 不再抛错，降级为只 add、跳过 remove。这与 `removeNovelFromBookshelf(_, 1)` 本就是 no-op 的事实一致，只是把"提前抛错"改成"自然跳过"。
- `to=1` 仍抛 `ArgumentError`，作为防御性断言（UI 不应让用户选到 id=1，但 Repository 不依赖 UI 正确性）。
- `from == to` 早 return 维持不变。
- 日志：成功路径补一条 info，说明 from=1 时为 add-only（便于排查）。

### 3.2 Notifier 层：不变

`BookshelfMutationNotifier.moveToBookshelf`（`bookshelf_mutation_provider.dart:88`）签名和行为**不变**。它仍是"移动/加入"的统一收口，内部 `_wrap` 照常写库 + invalidate `bookshelfNovelsProvider`。UI 在"全部小说"下调用它时传 `fromBookshelfId=1`，Repository 自动降级为 add-only。

### 3.3 UI 层：菜单合并为"加入书架"

**文件**：`bookshelf_screen.dart`

**`_showNovelMenu`（`:403`）**：根据当前书架 ID 动态渲染菜单项。

- `currentBookshelfId == 1`（"全部小说"）：用单条"加入书架" ListTile（图标 `Icons.bookmark_add_outlined`）替换"移动到书架"+"复制到书架"两条；`onTap` → `_showBookshelfSelectionDialog(novel, 'join')`。
- 其他书架：保持现状，"移动到书架" + "复制到书架"两条不变。

**`_showBookshelfSelectionDialog`（`:276`）**：新增 `mode == 'join'` 分支。

- 标题文案：`mode == 'join'` 时显示"加入书架"。
- 选择目标书架后的动作：`mode == 'join'` 走 `_copyNovelToBookshelf`（与 `'copy'` 等价，因为虚拟书架下"加入"= 只 add 关联）。
- `availableBookshelves` 过滤逻辑（`:288-290`，过滤当前书架 + id=1）不变。在"全部小说"下 `currentBookshelfId=1` 被过滤，目标候选都是真实书架，符合预期。

**为什么 `join` 复用 `copy` 而非 `move`**：
- `copyToBookshelf`（`bookshelf_mutation_provider.dart:105`）= 只 `addNovelToBookshelf`，不删原关联。
- `moveToBookshelf` 经 §3.1 改造后，from=1 时也是 add-only，二者在"全部小说"下行为等价。
- 但 `copyToBookshelf` 签名更简单（不需要 fromBookshelfId），且语义明确（"加入"就是"复制到"）。UI 在 join 分支直接调 `copyToBookshelf`，绕过 `moveToBookshelf` 的 from/to 特例判断，更直接。

> 注：§3.1 改造 `moveNovelToBookshelf` 仍保留，是为了让 Notifier 的 `moveToBookshelf` 在未来其他调用方（如有）传 from=1 时也能正确降级，不依赖 UI 走 copy 分支。两层防御。

## 4. 不在范围

- 不重构"全部小说"为真实书架（方案 C）：会让"全部小说=所有书的并集"语义被破坏（删一本书的 id=1 关联后它在"全部小说"消失，但 `bookshelf` 表行还在，产生新诡异）。
- 不新增 Notifier 方法（`moveToBookshelf` / `copyToBookshelf` 已够用）。
- 不改 `addNovel`（浏览器 FAB / Agent create_novel）、`toggleBookshelf`（章节页）、`removeNovel`（从书架移除）等路径。
- 不改 `bookshelfNovelsProvider` 的查询逻辑（虚拟书架仍直接查 `bookshelf` 表）。
- 不处理 Explore agent 报告的其他诡异点（`createNovel` 死代码、`setNovelCover` 绕过 Notifier、`updateLastReadChapter` 仍暴露在公共接口、`bookshelfCacheStatsProvider` 不被 invalidate、命名歧义等）——这些是独立的"代码卫生"问题，不在本次"全部小说移动失败"修复范围。

## 5. 测试策略

### 5.1 Repository 单测（`moveNovelToBookshelf` id=1 边界）

复用现有 Repository 测试基建（内存 SQLite + `sqflite_common_ffi`）。

- `from=1, to=2`：不抛错；`novel_bookshelves` 多一行 `(novel_url, 2)`；`bookshelf` 表小说行不动。
- `from=2, to=1`：仍抛 `ArgumentError`（防御性断言不被破坏）。
- `from=2, to=3`：回归，正常 add+remove。
- `from=2, to=2`：回归，早 return，无副作用。

### 5.2 Notifier 单测

复用现有 `BookshelfMutationNotifier` 测试模式（fake writer / fake association writer）。

- `moveToBookshelf(novelUrl, 1, 2)`：透传到 association writer，成功后 invalidate `bookshelfNovelsProvider`。
- `copyToBookshelf(novelUrl, 2)`：回归（join 分支走它）。

### 5.3 Widget 测试（`_showNovelMenu`）

- `currentBookshelfId == 1`：pump 菜单，断言出现"加入书架"、不出现"移动到书架"/"复制到书架"。
- `currentBookshelfId == 2`：pump 菜单，断言"移动到书架"+"复制到书架"都在（回归）。

### 5.4 手动验证（交付前）

1. "全部小说" → 书菜单 → "加入书架" → 选目标书架 → Toast"已加入"；切到目标书架能看到；回"全部小说"书仍在。
2. 普通书架 → "移动到书架" → 选目标 → Toast"已移动"；原书架消失、目标书架出现（回归）。
3. "全部小说" → "从书架移除" → 书从 `bookshelf` 表整行删除，所有书架都看不到（回归，走 `removeNovel` 不受影响）。

## 6. 错误处理

- Repository 失败仍由 `_wrap` 兜底：异常上抛、不 invalidate（避免半真半假 UI）。
- UI 的 `_moveNovelToBookshelf` / `_copyNovelToBookshelf` catch 块照常弹错。
- `from=1` 不再产生"移动失败"这个假错误（核心修复点）。

## 7. 影响面

| 文件 | 改动类型 | 风险 |
|---|---|---|
| `bookshelf_repository.dart` | 放宽 `moveNovelToBookshelf` from=1 特例 | 低：from=1 之前必抛错，现在降级为 add-only，无现有调用方依赖那个抛错 |
| `bookshelf_screen.dart` (`_showNovelMenu`) | 菜单条件渲染 | 低：仅"全部小说"下菜单项变化，其他书架不变 |
| `bookshelf_screen.dart` (`_showBookshelfSelectionDialog`) | 新增 `mode='join'` 分支 | 低：复用 copy 逻辑，仅标题文案不同 |
| `bookshelf_mutation_provider.dart` | 不变 | 无 |

无 DB schema 变更，无迁移。
