import 'package:novel_app/models/bookshelf.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/repositories/bookshelf_repository.dart';
import 'package:sqflite/sqflite.dart';

/// Mock BookshelfRepository
///
/// ## 用途
/// 用于测试环境的 Mock BookshelfRepository，避免真实数据库查询
///
/// ## 核心特性
/// - 不访问真实 SQLite 数据库
/// - 返回测试数据或空数据
/// - 快速、可靠的测试执行
class MockBookshelfRepository implements BookshelfRepository {
  /// Mock 小说列表
  List<Novel> mockNovels = [];

  /// Mock 书架分类列表
  List<Bookshelf> mockBookshelves = [];

  /// Mock 小说-书架关联 (key: novelUrl, value: List<bookshelfId>)
  Map<String, List<int>> mockNovelBookshelves = {};

  @override
  Future<Database> initDatabase() async {
    throw UnimplementedError(
      'MockBookshelfRepository 不支持访问真实数据库。'
      '请使用 mock 数据属性设置测试数据。',
    );
  }

  @override
  bool get isWebPlatform => false;

  @override
  Future<Database> get database async {
    throw UnimplementedError(
      'MockBookshelfRepository 不支持访问真实数据库。'
      '请使用 mock 数据属性设置测试数据。',
    );
  }

  @override
  Future<void> setSharedDatabase(Database database) async {
    // Mock 不需要真实数据库
  }

  @override
  Future<void> dispose() async {
    // Mock 不需要清理
  }

  @override
  Future<List<Bookshelf>> getBookshelves() async => mockBookshelves;

  @override
  Future<List<int>> getBookshelvesByNovel(String novelUrl) async {
    return mockNovelBookshelves[novelUrl] ?? [];
  }

  @override
  Future<int> createBookshelf(String name) async {
    final newId = mockBookshelves.isEmpty
        ? 3
        : mockBookshelves.map((b) => b.id).reduce((a, b) => a > b ? a : b) + 1;
    final bookshelf = Bookshelf(
      id: newId,
      name: name,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      sortOrder: mockBookshelves.length,
    );
    mockBookshelves.add(bookshelf);
    return newId;
  }

  @override
  Future<int> updateBookshelf(Bookshelf bookshelf) async {
    final index = mockBookshelves.indexWhere((b) => b.id == bookshelf.id);
    if (index >= 0) {
      mockBookshelves[index] = bookshelf;
      return 1;
    }
    return 0;
  }

  @override
  Future<bool> deleteBookshelf(int bookshelfId) async {
    if (bookshelfId <= 2) {
      // 系统书架不能删除
      return false;
    }
    mockBookshelves.removeWhere((b) => b.id == bookshelfId);
    return true;
  }

  @override
  Future<List<Novel>> getNovelsByBookshelf(int bookshelfId) async {
    if (bookshelfId == 1) {
      // "全部小说" - 返回所有小说
      return mockNovels;
    } else {
      // 其他书架 - 根据关联关系返回小说
      final novelUrls = mockNovelBookshelves.entries
          .where((entry) => entry.value.contains(bookshelfId))
          .map((entry) => entry.key)
          .toSet();

      return mockNovels
          .where((novel) => novelUrls.contains(novel.url))
          .toList();
    }
  }

  @override
  Future<int> getNovelCountByBookshelf(int bookshelfId) async {
    return (await getNovelsByBookshelf(bookshelfId)).length;
  }

  @override
  Future<void> addNovelToBookshelf(String novelUrl, int bookshelfId) async {
    if (!mockNovelBookshelves.containsKey(novelUrl)) {
      mockNovelBookshelves[novelUrl] = [];
    }
    if (!mockNovelBookshelves[novelUrl]!.contains(bookshelfId)) {
      mockNovelBookshelves[novelUrl]!.add(bookshelfId);
    }
  }

  @override
  Future<bool> removeNovelFromBookshelf(
      String novelUrl, int bookshelfId) async {
    if (mockNovelBookshelves.containsKey(novelUrl)) {
      final removed = mockNovelBookshelves[novelUrl]!.remove(bookshelfId);
      if (mockNovelBookshelves[novelUrl]!.isEmpty) {
        mockNovelBookshelves.remove(novelUrl);
      }
      return removed;
    }
    return false;
  }

  @override
  Future<void> moveNovelToBookshelf(
    String novelUrl,
    int fromBookshelfId,
    int toBookshelfId,
  ) async {
    await removeNovelFromBookshelf(novelUrl, fromBookshelfId);
    await addNovelToBookshelf(novelUrl, toBookshelfId);
  }

  @override
  Future<List<int>> getBookshelfIdsForNovel(String novelUrl) async {
    return mockNovelBookshelves[novelUrl] ?? [];
  }

  @override
  Future<bool> isNovelInBookshelf(String novelUrl, int bookshelfId) async {
    return mockNovelBookshelves[novelUrl]?.contains(bookshelfId) ?? false;
  }

  @override
  Future<Map<int, int>> getBookshelfNovelCount() async {
    final Map<int, int> counts = {};
    for (var bookshelf in mockBookshelves) {
      counts[bookshelf.id] = await getNovelCountByBookshelf(bookshelf.id);
    }
    return counts;
  }

  @override
  Future<void> reorderBookshelves(List<int> bookshelfIds) async {
    // 简单实现：不实际排序
    // 真实实现会更新 sortOrder
  }
}
