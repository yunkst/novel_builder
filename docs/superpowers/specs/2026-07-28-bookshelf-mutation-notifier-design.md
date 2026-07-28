# 书架增删写入收口重构 Design

- **日期**: 2026-07-28
- **目标**: 根治"浏览器添加小说后书架不刷新"的同类架构缺陷——所有改 `bookshelf` 表的写入路径强制收口到 `BookshelfMutationNotifier`,编译期阻止绕过。

## 1. 背景与根因

### 1.1 症状
浏览器添加小说后立即切到书架 Tab,看不到新增小说,需切换书架分类或重新进 Tab 才能看到。

### 1.2 根因(系统性-debugging Phase 1 + 2 确认)
架构缺陷:**写入路径(Repository)与缓存失效(Riverpod provider)是两条独立的人肉链路,没有自动绑定**。`IndexedStack` 保留书架页 state,`bookshelfNovelsProvider` 是有内置缓存的 FutureProvider,只有显式 `ref.invalidate` 才能刷。

调查发现 **3 处遗漏**(`WebViewAddNovelFab` 添加、`Agent create_novel` 工具、章节页 `toggleBookshelf`),全是同一个错:**写完 SQLite 忘了 invalidate**。对照书架页内 5 处成功操作都显式 invalidate,跨页面/跨组件路径就漏。

### 1.3 当前架构
```
调用方 ──► NovelRepository.addToBookshelf() 写 SQLite
                                              │
bookshelfNovelsProvider (FutureProvider) ◄────┴─ ref.invalidate(...)
   └─ bookshelfCacheStatsProvider 依赖上面,自动级联
```

**问题**: `ref.invalidate(...)` 是约定的"写完记得加",没强制力,任何新增路径都会再漏。

## 2. 设计:D-1(接口瘦身 + 收口 Notifier + 编译期强制)

### 2.1 核心思路
- 写方法从 `INovelRepository` 接口移除,挪到**只给 Notifier 用的桥接 provider**
- 编译期:`ref.read<INovelRepository>(...)` 返回接口,无法调写方法(接口里没这些);只有 Notifier 通过"具体类 provider"才能写
- Notifier 内部统一收口"写 + invalidate",**调用方再也不会忘记**

### 2.2 架构图
```
所有"会改 bookshelf 表"的调用点
  ├─ WebViewAddNovelFab                ┐
  │   Agent createNovel 工具           │
  │   章节页 toggleBookshelf           │──► BookshelfMutationNotifier
  │   书架页 remove/updateCover/...    │      addNovel / removeNovel /
  │   章节页 remove (如果存在)         │      toggleBookshelf / updateCover /
  │   (未来新增路径只需调它)           ┘      updateTitle / moveToBookshelf /
                                          createNovel
                                             │
                                             ├─ ref.read(novelRepositoryWriterProvider)
                                             │     .xxx()   // 写 SQLite(具体类,接口不可见)
                                             └─ ref.invalidate(bookshelfNovelsProvider)
                                                   └─ bookshelfCacheStatsProvider 自动级联
```

### 2.3 改动总览

| 文件 | 类型 | 改动 |
|---|---|---|
| `lib/core/interfaces/repositories/i_novel_repository.dart` | 改 | 从接口移除 5 个写方法(addToBookshelf / removeFromBookshelf / updateTitle / updateCoverMediaIdByUrl / createNovel) |
| `lib/repositories/novel_repository.dart` | 改 | 新增 `abstract interface class IBookshelfWriter`(内部,不导出);具体方法签名不变;createNovel 复合方法保留(挪到 Notifier 内包装) |
| `lib/core/interfaces/repositories/i_bookshelf_repository.dart` | 改 | 从接口移除 3 个写方法(addNovelToBookshelf / removeNovelFromBookshelf / moveNovelToBookshelf) |
| `lib/repositories/bookshelf_repository.dart` | 改 | 新增 `abstract interface class IBookshelfAssociationWriter`(内部);具体方法签名不变 |
| `lib/core/providers/database_providers.dart` | 改 | 新增 `bookshelfWriterProvider`(`IBookshelfWriter`)+ `bookshelfAssociationWriterProvider`(`IBookshelfAssociationWriter`) |
| `lib/core/providers/bookshelf_mutation_provider.dart` | **新建** | `BookshelfMutationNotifier`(`@riverpod`),收口所有书架写 |
| `lib/core/providers/chapter_list_providers.dart:396-410` | 改 | `toggleBookshelf()` 改调 `ref.read(bookshelfMutationProvider).toggleBookshelf(novel)` |
| `lib/screens/bookshelf_screen.dart` (5 处) | 改 | 移除/改名/封面/移动 全部改调 `bookshelfMutationProvider` |
| `lib/services/novel_agent/tool_executor/novel_navigation_executor.dart:85` | 改 | `addToBookshelf` → `bookshelfMutationProvider.addNovel` |
| `lib/services/novel_agent/tool_executor.dart:91` | 改 | `_novelNav.createNovel` → `bookshelfMutationProvider.createNovel` |
| `lib/widgets/webview_add_novel_button.dart:251` | 改 | `addToBookshelf` → `bookshelfMutationProvider.addNovel` |
| `novel_app/test/unit/core/providers/bookshelf_mutation_provider_test.dart` | **新建** | Notifier 单测:每个方法 = repo 调用 + invalidate |

**共 10 个文件**(1 新建 Notifier + 1 新建测试 + 8 改)。

**范围外**:`IBookshelfRepository` 的 `createBookshelf` / `deleteBookshelf`(改 `bookshelves` 表,通过 `_loadBookshelves()` widget 方法刷新,不依赖 provider invalidate),本次不动。

## 3. 详细设计

### 3.1 接口瘦身(`INovelRepository` + `IBookshelfRepository`)

**`INovelRepository` 移除**(5 个,挪到 `IBookshelfWriter`):
```dart
Future<int> addToBookshelf(Novel novel);
Future<int> removeFromBookshelf(String novelUrl);
Future<int> updateTitle(String novelUrl, String newTitle);
Future<int> updateCoverMediaIdByUrl(String novelUrl, String? mediaId);
Future<Novel> createNovel({...});
```

**`IBookshelfRepository` 移除**(3 个,挪到 `IBookshelfAssociationWriter`):
```dart
Future<void> addNovelToBookshelf(String novelUrl, int bookshelfId);
Future<bool> removeNovelFromBookshelf(String novelUrl, int bookshelfId);
Future<void> moveNovelToBookshelf(String novelUrl, int fromBookshelfId, int toBookshelfId);
```

**保留**(`INovelRepository`):
- 所有读方法(`getNovelByUrl` / `getNovelsByBookshelf` / `getBackgroundSetting` / `isInBookshelf` 等)
- `updateLastReadChapter` / `updateBackgroundSetting` / `updateCoverMediaIdById`(非书架 UI 刷新相关)
- `getNovelById` / `getNovelUrlById`(读)

**保留**(`IBookshelfRepository`):
- 所有读方法(`getBookshelves` / `getNovelsByBookshelf` / `getBookshelvesByNovel` / `getNovelCountByBookshelf` / `isNovelInBookshelf`)
- `createBookshelf` / `deleteBookshelf` / `updateBookshelf`(书架分类的 CRUD,通过 `_loadBookshelves()` 刷新,不依赖 provider invalidate,本次不动)

### 3.2 `IBookshelfWriter` 内部接口

定义在 `novel_repository.dart` 文件内,**不导出**(不在 `lib/core/interfaces/` 下)。外部只能通过 `bookshelfWriterProvider` 拿到具体类型引用,无法用接口外类型持有它(等于隐形)。

```dart
// novel_repository.dart
abstract interface class IBookshelfWriter {
  Future<int> addToBookshelf(Novel novel);
  Future<int> removeFromBookshelf(String novelUrl);
  Future<int> updateTitle(String novelUrl, String newTitle);
  Future<int> updateCoverMediaIdByUrl(String novelUrl, String? mediaId);
  Future<int> moveToBookshelf(String novelUrl, int bookshelfId);
  Future<Novel> createNovel({required String title, required String author,
      String? coverUrl, String? description, String? backgroundSetting});
}

class NovelRepository extends BaseRepository
    implements INovelRepository, IBookshelfWriter {
  // 实现上述方法(签名不变,仅失去接口外露)
}
```

**为什么 internal interface**:
- `abstract interface class`(Dart 3.0+)即使放在 public 文件里,**调用方得 `import` 该文件才能用类型**——增加一层获取成本
- 但更关键的:`bookshelfWriterProvider` 才是"分发口",调用方即使 import 了 `novel_repository.dart` 也得通过 provider 才能拿到实例
- 内部组合:Notifier 写代码时 `ref.read(bookshelfWriterProvider)` 拿到 `IBookshelfWriter` 类型,只能调这 6 个方法

**为什么不直接私有(`_` 前缀)**:
- 私有是 library 粒度,Notifier 不在同 library,无法调
- `abstract interface class` internal 模式相当于"按类型导出但限定方法集",Dart 里最接近 friend 关键字的方案

### 3.3 新 Provider:`bookshelfWriterProvider`

```dart
// database_providers.dart(添加,不替换现有 novelRepositoryProvider)
@riverpod
IBookshelfWriter bookshelfWriter(Ref ref) {
  final repo = ref.watch(novelRepositoryProvider) as NovelRepository;
  return repo;  // NovelRepository implements IBookshelfWriter
}
```

**注意 cast**: `ref.watch(novelRepositoryProvider)` 返回 `INovelRepository`,实际实现 `NovelRepository implements IBookshelfWriter`,所以可以安全 cast 到 `IBookshelfWriter` 暴露写方法。

### 3.4 `BookshelfMutationNotifier`(新建)

```dart
// bookshelf_mutation_provider.dart
@riverpod
class BookshelfMutation extends _$BookshelfMutation {
  @override
  void build() {}

  IBookshelfWriter get _writer => ref.read(bookshelfWriterProvider);

  // ===== 收口方法 =====

  Future<void> addNovel(Novel novel) =>
      _wrap(() => _writer.addToBookshelf(novel));

  Future<void> removeNovel(String novelUrl) =>
      _wrap(() => _writer.removeFromBookshelf(novelUrl));

  Future<void> toggleBookshelf(Novel novel) async {
    final writer = _writer;
    if (await _isInBookshelf(novel.url)) {
      await _wrap(() => writer.removeFromBookshelf(novel.url));
    } else {
      await _wrap(() => writer.addToBookshelf(novel));
    }
  }

  Future<void> updateTitle(String novelUrl, String newTitle) =>
      _wrap(() => _writer.updateTitle(novelUrl, newTitle));

  Future<void> updateCoverMediaId(String novelUrl, String? mediaId) =>
      _wrap(() => _writer.updateCoverMediaIdByUrl(novelUrl, mediaId));

  Future<void> removeCoverMediaId(String novelUrl) =>
      _wrap(() => _writer.updateCoverMediaIdByUrl(novelUrl, null));

  Future<void> moveToBookshelf(String novelUrl, int fromBookshelfId, int toBookshelfId) =>
      _wrap(() => _associationWriter.moveNovelToBookshelf(novelUrl, fromBookshelfId, toBookshelfId));

  Future<Novel> createNovel({
    required String title,
    required String author,
    String? coverUrl,
    String? description,
    String? backgroundSetting,
  }) =>
      _wrap<Novel>(() => _writer.createNovel(
            title: title,
            author: author,
            coverUrl: coverUrl,
            description: description,
            backgroundSetting: backgroundSetting,
          ));

  // ===== 内部 =====

  IBookshelfWriter get _writer => ref.read(bookshelfWriterProvider);
  IBookshelfAssociationWriter get _associationWriter => ref.read(bookshelfAssociationWriterProvider);

  Future<bool> _isInBookshelf(String novelUrl) async {
    return ref.read(novelRepositoryProvider).isInBookshelf(novelUrl);
  }

  /// 统一收口:写库 + invalidate。失败不 invalidate(避免半真半假)。
  Future<T> _wrap<T>(Future<T> Function() op) async {
    final result = await op();
    ref.invalidate(bookshelfNovelsProvider);
    return result;
  }
}
```

**设计要点**:
- **不持状态**(`build()` 返回 void)——是写操作聚合,不是状态机
- **`_wrap` 统一收口**——所有写方法都走它;失败不 invalidate(不刷出半真半假)
- **`toggleBookshelf` 内分支也走 `_wrap`**——避免任何路径绕开 invalidate
- **`removeCoverMediaId` 是 `updateCoverMediaIdByUrl(_, null)` 的 convenience**——保留 shelf_screen 的对称风格

### 3.5 调用点迁移表

| 文件:行 | 旧 | 新 |
|---|---|---|
| `chapter_list_providers.dart:400` | `novelRepository.removeFromBookshelf(novel.url)` | `ref.read(bookshelfMutationProvider).removeNovel(novel.url)` |
| `chapter_list_providers.dart:402` | `novelRepository.addToBookshelf(novel)` | `ref.read(bookshelfMutationProvider).addNovel(novel)` |
| `bookshelf_screen.dart:51` | `novelRepository.removeFromBookshelf(novel.url)` | `ref.read(bookshelfMutationProvider).removeNovel(novel.url)` |
| `bookshelf_screen.dart:79` | `novelRepository.updateTitle(...)` | `ref.read(bookshelfMutationProvider).updateTitle(...)` |
| `bookshelf_screen.dart:134` | `novelRepository.updateCoverMediaIdByUrl(..., mediaId)` | `ref.read(bookshelfMutationProvider).updateCoverMediaId(..., mediaId)` |
| `bookshelf_screen.dart:167` | `novelRepository.updateCoverMediaIdByUrl(..., null)` | `ref.read(bookshelfMutationProvider).removeCoverMediaId(...)` |
| `bookshelf_screen.dart:362` | `bookshelfRepository.moveNovelToBookshelf(novel.url, currentBookshelfId, toBookshelfId)` | `ref.read(bookshelfMutationProvider).moveToBookshelf(novel.url, currentBookshelfId, toBookshelfId)` |
| `novel_navigation_executor.dart:85` | `novelRepository.addToBookshelf(novel)` | `ref.read(bookshelfMutationProvider).addNovel(novel)` |
| `tool_executor.dart:91` | `_novelNav.createNovel(args)` | `ref.read(bookshelfMutationProvider).createNovel(...)`(调用方透传 args) |
| `webview_add_novel_button.dart:251` | `novelRepo.addToBookshelf(Novel(...))` | `ref.read(bookshelfMutationProvider).addNovel(Novel(...))` |

精确行号在 plan 实施期 Step 1 再次核对(防止代码漂移)。

### 3.6 `bookshelf_screen.dart` 内现有 invalidate 删除

迁移后,shelf_screen.dart 内所有 `ref.invalidate(bookshelfNovelsProvider)`(5 处:51/84/135/168/367 行附近)都可**删除**——Notifer 内部已统一失效。但删除要核实:是否所有屏内操作都走 Notifier,没有绕过的(plan Step 2 验证)。

## 4. 测试

### 4.1 Notifier 单测(新建)

`test/unit/core/providers/bookshelf_mutation_provider_test.dart`:

- 每个公共方法(7 个: addNovel / removeNovel / toggleBookshelf / updateTitle / updateCoverMediaId / removeCoverMediaId / moveToBookshelf / createNovel)测试:
  - 成功 → `_writer` 对应方法被调一次 + `bookshelfNovelsProvider` 被 invalidate 一次
  - 失败(`_writer` 抛异常) → **不** invalidate(避免半真半假);异常向上抛
- `toggleBookshelf` 双分支:isInBookshelf=true → removeNovel / false → addNovel,各自走 `_wrap` → invalidate

### 4.2 回归测试(已有)

- bookshelf_screen / chapter_list / webview / novel_navigation_executor 的现有测试若有,继续通过(行为不变)
- 端到端手动验证:浏览器添加小说 → 立即切书架 Tab → 看到新增

## 5. 风险与缓解

| 风险 | 缓解 |
|---|---|
| 接口瘦身后,`ref.read<INovelRepository>` 的调用方调写方法会编译失败 | 编译器**逼**着迁移到 Notifier——这正是设计的强制力;plan 实施期逐步改 |
| `bookshelfWriterProvider` 把 `INovelRepository` cast 到具体类,如果实现换成 Mock 不实现 `IBookshelfWriter` 会崩溃 | 测试场景需要 mock 同时实现两个接口;主路径无影响 |
| Notifier `_wrap` 失败不 invalidate,失败时 UI 可能短暂显示旧数据 | 写操作失败概率低,且抛出后调用方一般会报错弹 Toast——可接受;后续可加重试 |
| `moveToBookshelf` 接口方法签名确认 | plan Step 1 先读 Repository 现有签名,精确迁移 |

## 6. 范围外

- 不动 `updateLastReadChapter` / `updateBackgroundSetting` / `updateCoverMediaIdById` 等非书架写
- 不重构 `INovelRepository` 全部结构(只移除写方法)
- 不引入新数据库层(`sqflite` 变更通知等)

## 7. 实施后效果

- ✅ 浏览器添加小说 → 立即切书架 → 看到(根因消除)
- ✅ Agent `createNovel` 工具 → 书架刷新(同类 bug 一并修)
- ✅ 章节页 toggleBookshelf → 书架刷新(同类 bug 一并修)
- ✅ 未来新增路径: 调用方写 `ref.read(bookshelfMutationProvider).xxx()`,**没有"忘 invalidate"的可能**
- ✅ 编译期保证: 任何绕过 Notifier 直接调 `addToBookshelf` 的代码都会编译失败(`INovelRepository` 没这方法)