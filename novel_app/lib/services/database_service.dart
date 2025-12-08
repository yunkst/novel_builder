import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/search_result.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  bool get isWebPlatform => kIsWeb;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw Exception('Database is not supported on web platform');
    }

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'novel_reader.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 创建书架表
    await db.execute('''
      CREATE TABLE bookshelf (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        url TEXT NOT NULL UNIQUE,
        coverUrl TEXT,
        description TEXT,
        backgroundSetting TEXT,
        addedAt INTEGER NOT NULL,
        lastReadChapter INTEGER DEFAULT 0,
        lastReadTime INTEGER
      )
    ''');

    // 创建章节缓存表
    await db.execute('''
      CREATE TABLE chapter_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        novelUrl TEXT NOT NULL,
        chapterUrl TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        chapterIndex INTEGER,
        cachedAt INTEGER NOT NULL
      )
    ''');

    // 创建小说章节列表缓存表
    await db.execute('''
      CREATE TABLE novel_chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        novelUrl TEXT NOT NULL,
        chapterUrl TEXT NOT NULL,
        title TEXT NOT NULL,
        chapterIndex INTEGER,
        isUserInserted INTEGER DEFAULT 0,
        insertedAt INTEGER,
        UNIQUE(novelUrl, chapterUrl)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 添加用户插入章节的标记字段
      await db.execute('''
        ALTER TABLE novel_chapters ADD COLUMN isUserInserted INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE novel_chapters ADD COLUMN insertedAt INTEGER
      ''');
    }
    if (oldVersion < 3) {
      // 添加背景设定字段
      await db.execute('''
        ALTER TABLE bookshelf ADD COLUMN backgroundSetting TEXT
      ''');
    }
  }

  // ========== 书架操作 ==========

  /// 添加小说到书架
  Future<int> addToBookshelf(Novel novel) async {
    final db = await database;
    return await db.insert(
      'bookshelf',
      {
        'title': novel.title,
        'author': novel.author,
        'url': novel.url,
        'coverUrl': novel.coverUrl,
        'description': novel.description,
        'backgroundSetting': novel.backgroundSetting,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 从书架移除小说
  Future<int> removeFromBookshelf(String novelUrl) async {
    final db = await database;
    return await db.delete(
      'bookshelf',
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
  }

  /// 获取书架列表
  Future<List<Novel>> getBookshelf() async {
    if (isWebPlatform) {
      return []; // Web平台不支持数据库，返回空列表
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookshelf',
      orderBy: 'lastReadTime DESC, addedAt DESC',
    );

    return List.generate(maps.length, (i) {
      return Novel(
        title: maps[i]['title'],
        author: maps[i]['author'],
        url: maps[i]['url'],
        coverUrl: maps[i]['coverUrl'],
        description: maps[i]['description'],
        backgroundSetting: maps[i]['backgroundSetting'],
        isInBookshelf: true,
      );
    });
  }

  /// 检查小说是否在书架中
  Future<bool> isInBookshelf(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookshelf',
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
    return maps.isNotEmpty;
  }

  /// 更新最后阅读章节
  Future<int> updateLastReadChapter(String novelUrl, int chapterIndex) async {
    final db = await database;
    return await db.update(
      'bookshelf',
      {
        'lastReadChapter': chapterIndex,
        'lastReadTime': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
  }

  /// 更新小说背景设定
  Future<int> updateBackgroundSetting(
      String novelUrl, String? backgroundSetting) async {
    if (isWebPlatform) {
      return 0; // Web平台什么都不做，返回0
    }

    final db = await database;
    return await db.update(
      'bookshelf',
      {
        'backgroundSetting': backgroundSetting,
      },
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
  }

  /// 获取小说背景设定
  Future<String?> getBackgroundSetting(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookshelf',
      columns: ['backgroundSetting'],
      where: 'url = ?',
      whereArgs: [novelUrl],
    );

    if (maps.isNotEmpty) {
      return maps.first['backgroundSetting'] as String?;
    }
    return null;
  }

  /// 获取上次阅读的章节索引
  Future<int> getLastReadChapter(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookshelf',
      columns: ['lastReadChapter'],
      where: 'url = ?',
      whereArgs: [novelUrl],
    );

    if (maps.isNotEmpty) {
      return maps.first['lastReadChapter'] as int? ?? 0;
    }
    return 0;
  }

  // ========== 章节缓存操作 ==========

  /// 缓存章节内容
  Future<int> cacheChapter(
      String novelUrl, Chapter chapter, String content) async {
    final db = await database;
    return await db.insert(
      'chapter_cache',
      {
        'novelUrl': novelUrl,
        'chapterUrl': chapter.url,
        'title': chapter.title,
        'content': content,
        'chapterIndex': chapter.chapterIndex,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新章节内容
  Future<int> updateChapterContent(String chapterUrl, String content) async {
    final db = await database;
    return await db.update(
      'chapter_cache',
      {
        'content': content,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );
  }

  /// 删除章节缓存
  Future<int> deleteChapterCache(String chapterUrl) async {
    final db = await database;
    return await db.delete(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );
  }

  /// 获取缓存的章节内容
  Future<String?> getCachedChapter(String chapterUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );

    if (maps.isNotEmpty) {
      return maps.first['content'] as String;
    }
    return null;
  }

  /// 检查章节是否已缓存
  Future<bool> isChapterCached(String chapterUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );
    return maps.isNotEmpty;
  }

  /// 获取小说的所有缓存章节
  Future<List<Chapter>> getCachedChapters(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chapter_cache',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
      orderBy: 'chapterIndex ASC',
    );

    return List.generate(maps.length, (i) {
      return Chapter(
        title: maps[i]['title'],
        url: maps[i]['chapterUrl'],
        content: maps[i]['content'],
        isCached: true,
        chapterIndex: maps[i]['chapterIndex'],
      );
    });
  }

  /// 删除小说的所有缓存章节
  Future<int> deleteCachedChapters(String novelUrl) async {
    final db = await database;
    return await db.delete(
      'chapter_cache',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
    );
  }

  /// 清除特定小说的所有缓存（包括章节内容和章节列表）
  Future<void> clearNovelCache(String novelUrl) async {
    final db = await database;
    final batch = db.batch();

    // 删除章节内容缓存
    batch.delete(
      'chapter_cache',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
    );

    // 删除章节列表缓存
    batch.delete(
      'novel_chapters',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
    );

    await batch.commit(noResult: true);
  }

  /// 获取小说缓存统计信息
  Future<Map<String, int>> getNovelCacheStats(String novelUrl) async {
    if (isWebPlatform) {
      return {'cachedChapters': 0, 'totalChapters': 0}; // Web平台返回默认值
    }

    final db = await database;

    // 获取缓存的章节内容数量
    final contentResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chapter_cache WHERE novelUrl = ?',
      [novelUrl],
    );
    final contentCount = contentResult.first['count'] as int;

    // 获取章节列表数量
    final chaptersResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM novel_chapters WHERE novelUrl = ?',
      [novelUrl],
    );
    final chaptersCount = chaptersResult.first['count'] as int;

    return {
      'cachedChapters': contentCount,
      'totalChapters': chaptersCount,
    };
  }

  /// 缓存整本小说
  Future<void> cacheWholeNovel(String novelUrl, List<Chapter> chapters,
      Future<String> Function(String) getContent) async {
    for (var chapter in chapters) {
      // 已缓存则跳过，避免重复网络请求与写入
      final already = await isChapterCached(chapter.url);
      if (already) {
        continue;
      }

      final content = await getContent(chapter.url);
      await cacheChapter(novelUrl, chapter, content);
    }
  }

  // ========== 章节列表缓存操作 ==========

  /// 缓存小说章节列表
  Future<void> cacheNovelChapters(
      String novelUrl, List<Chapter> chapters) async {
    final db = await database;
    final batch = db.batch();

    // 只删除非用户插入的章节
    batch.delete(
      'novel_chapters',
      where: 'novelUrl = ? AND isUserInserted = 0',
      whereArgs: [novelUrl],
    );

    // 插入新的章节列表
    for (var i = 0; i < chapters.length; i++) {
      batch.insert(
        'novel_chapters',
        {
          'novelUrl': novelUrl,
          'chapterUrl': chapters[i].url,
          'title': chapters[i].title,
          'chapterIndex': i,
          'isUserInserted': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);

    // 重新排序章节索引，将用户插入的章节保持在原位置
    await _reorderChapters(novelUrl);
  }

  /// 获取缓存的章节列表
  Future<List<Chapter>> getCachedNovelChapters(String novelUrl) async {
    final db = await database;

    // 使用JOIN查询同时获取章节元数据和内容，确保用户章节包含完整内容
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT
        nc.id, nc.novelUrl, nc.chapterUrl, nc.title,
        nc.chapterIndex, nc.isUserInserted, nc.insertedAt,
        cc.content
      FROM novel_chapters nc
      LEFT JOIN chapter_cache cc ON nc.chapterUrl = cc.chapterUrl
      WHERE nc.novelUrl = ?
      ORDER BY nc.chapterIndex ASC
    ''', [novelUrl]);

    return List.generate(maps.length, (i) {
      return Chapter(
        title: maps[i]['title'],
        url: maps[i]['chapterUrl'],
        content: maps[i]['content'] ?? '', // 直接包含内容，特别对用户章节重要
        isCached: maps[i]['content'] != null,
        chapterIndex: maps[i]['chapterIndex'],
        isUserInserted: maps[i]['isUserInserted'] == 1,
      );
    });
  }

  /// 重新排序章节索引
  Future<void> _reorderChapters(String novelUrl) async {
    final db = await database;
    final chapters = await db.query(
      'novel_chapters',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
      orderBy: 'chapterIndex ASC',
    );

    final batch = db.batch();
    for (var i = 0; i < chapters.length; i++) {
      batch.update(
        'novel_chapters',
        {'chapterIndex': i},
        where: 'id = ?',
        whereArgs: [chapters[i]['id']],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 插入用户章节
  Future<void> insertUserChapter(
      String novelUrl, String title, String content, int insertIndex) async {
    final db = await database;
    final batch = db.batch();

    // 生成唯一的章节URL，统一使用 custom:// 格式
    final chapterUrl = 'custom://chapter/${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;

    // 将插入位置之后的章节索引都加1
    batch.rawUpdate(
      'UPDATE novel_chapters SET chapterIndex = chapterIndex + 1 WHERE novelUrl = ? AND chapterIndex >= ?',
      [novelUrl, insertIndex],
    );

    // 插入新的用户章节
    batch.insert(
      'novel_chapters',
      {
        'novelUrl': novelUrl,
        'chapterUrl': chapterUrl,
        'title': title,
        'chapterIndex': insertIndex,
        'isUserInserted': 1,
        'insertedAt': now,
      },
    );

    // 同时在章节缓存表中添加内容
    batch.insert(
      'chapter_cache',
      {
        'novelUrl': novelUrl,
        'chapterUrl': chapterUrl,
        'title': title,
        'content': content,
        'chapterIndex': insertIndex,
        'cachedAt': now,
      },
    );

    await batch.commit(noResult: true);
  }

  /// 清空所有缓存
  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete('chapter_cache');
    await db.delete('novel_chapters');
  }

  /// 判断是否为本地章节
  static bool isLocalChapter(String chapterUrl) {
    return chapterUrl.startsWith('custom://') ||
           chapterUrl.startsWith('user_chapter_');
  }

  /// 创建用户自定义空小说
  Future<int> createCustomNovel(String title, String author,
      {String? description}) async {
    if (isWebPlatform) {
      throw Exception(
          'Creating custom novels is not supported on web platform');
    }

    final db = await database;
    final customUrl = 'custom://${DateTime.now().millisecondsSinceEpoch}';
    return await db.insert(
      'bookshelf',
      {
        'title': title,
        'author': author,
        'url': customUrl,
        'coverUrl': null,
        'description': description,
        'backgroundSetting': null,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 创建用户自定义章节
  Future<int> createCustomChapter(
      String novelUrl, String title, String content) async {
    final db = await database;

    // 获取当前最大章节索引
    final result = await db.rawQuery(
      'SELECT MAX(chapterIndex) as maxIndex FROM novel_chapters WHERE novelUrl = ?',
      [novelUrl],
    );
    final maxIndex = result.first['maxIndex'] as int? ?? 0;

    // 生成章节URL
    final chapterUrl =
        'custom://chapter/${DateTime.now().millisecondsSinceEpoch}';

    // 插入章节元数据
    await db.insert(
      'novel_chapters',
      {
        'novelUrl': novelUrl,
        'chapterUrl': chapterUrl,
        'title': title,
        'chapterIndex': maxIndex + 1,
        'isUserInserted': 1,
        'insertedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 缓存章节内容
    await db.insert(
      'chapter_cache',
      {
        'novelUrl': novelUrl,
        'chapterUrl': chapterUrl,
        'content': content,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return maxIndex + 1;
  }

  /// 获取用户创建的章节内容
  Future<String?> getCustomChapterContent(String chapterUrl) async {
    final db = await database;
    final result = await db.query(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );
    if (result.isNotEmpty) {
      return result.first['content'] as String?;
    }
    return null;
  }

  /// 更新用户创建的章节内容
  Future<void> updateCustomChapter(
      String chapterUrl, String title, String content) async {
    final db = await database;

    // 更新章节标题
    await db.update(
      'novel_chapters',
      {'title': title},
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );

    // 更新章节内容
    await db.update(
      'chapter_cache',
      {
        'content': content,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );
  }

  /// 删除用户创建的章节
  Future<void> deleteCustomChapter(String chapterUrl) async {
    final db = await database;

    await db.delete(
      'novel_chapters',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );

    await db.delete(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );
  }

  /// 在缓存内容中搜索关键字
  Future<List<ChapterSearchResult>> searchInCachedContent(String keyword,
      {String? novelUrl}) async {
    final db = await database;

    String whereClause = "content LIKE ? OR title LIKE ?";
    List<dynamic> whereArgs = ['%$keyword%', '%$keyword%'];

    if (novelUrl != null && novelUrl.isNotEmpty) {
      whereClause += " AND novelUrl = ?";
      whereArgs.add(novelUrl);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'chapter_cache',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'novelUrl, chapterIndex',
    );

    final List<ChapterSearchResult> results = [];

    for (int i = 0; i < maps.length; i++) {
      final content = maps[i]['content'] ?? '';
      final title = maps[i]['title'] ?? '';

      // 查找所有匹配位置
      final List<MatchPosition> matchPositions =
          _findMatchPositions(content, keyword);

      results.add(ChapterSearchResult(
        novelUrl: maps[i]['novelUrl'] ?? '',
        novelTitle: title, // 使用章节标题作为小说标题（临时解决方案）
        novelAuthor: '未知作者', // 数据库中没有作者信息，需要从书架表获取
        chapterUrl: maps[i]['chapterUrl'] ?? '',
        chapterTitle: title,
        chapterIndex: maps[i]['chapterIndex'] ?? 0,
        content: content,
        searchKeywords: [keyword],
        matchPositions: matchPositions,
        cachedAt:
            DateTime.tryParse(maps[i]['cachedAt'] ?? '') ?? DateTime.now(),
      ));
    }

    return results;
  }

  /// 查找文本中所有匹配的位置
  List<MatchPosition> _findMatchPositions(String text, String keyword) {
    final List<MatchPosition> positions = [];
    final String lowerText = text.toLowerCase();
    final String lowerKeyword = keyword.toLowerCase();

    int index = lowerText.indexOf(lowerKeyword);
    while (index != -1) {
      positions.add(MatchPosition(
        start: index,
        end: index + keyword.length,
        matchedText: text.substring(index, index + keyword.length),
      ));
      index = lowerText.indexOf(lowerKeyword, index + 1);
    }

    return positions;
  }

  /// 获取所有已缓存小说的列表（用于搜索筛选）
  Future<List<CachedNovelInfo>> getCachedNovels() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT
        cc.novelUrl,
        b.title as novelTitle,
        b.author as novelAuthor,
        b.coverUrl,
        b.description,
        COUNT(cc.id) as cachedChapterCount,
        MAX(cc.cachedAt) as lastUpdated
      FROM chapter_cache cc
      LEFT JOIN bookshelf b ON cc.novelUrl = b.url
      GROUP BY cc.novelUrl, b.title, b.author, b.coverUrl, b.description
      ORDER BY b.title
    ''');

    return List.generate(maps.length, (i) {
      return CachedNovelInfo(
        novelUrl: maps[i]['novelUrl'] ?? '',
        novelTitle: maps[i]['novelTitle'] ?? '未知小说',
        novelAuthor: maps[i]['novelAuthor'] ?? '未知作者',
        coverUrl: maps[i]['coverUrl'],
        description: maps[i]['description'],
        chapterCount: maps[i]['cachedChapterCount'] ?? 0,
        lastUpdated:
            DateTime.tryParse(maps[i]['lastUpdated'] ?? '') ?? DateTime.now(),
      );
    });
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  /// 更新小说在书架中的信息
  Future<void> updateNovelInBookshelf(Novel novel) async {
    final db = await database;
    await db.update(
      'bookshelf',
      {
        'title': novel.title,
        'author': novel.author,
        'coverUrl': novel.coverUrl,
        'description': novel.description,
        'lastReadChapterIndex': novel.lastReadChapterIndex ?? 0,
        'readingProgress': novel.readingProgress ?? 0.0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'url = ?',
      whereArgs: [novel.url],
    );
  }

  /// 清理书架缓存（保留阅读进度）
  Future<void> clearBookshelfCache() async {
    final db = await database;
    await db.update(
      'bookshelf',
      {'coverUrl': null, 'description': null},
      where: '1 = 1',
    );
  }

  /// 获取章节数量
  Future<int> getCachedChaptersCount(String novelUrl) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM novel_chapters WHERE novelUrl = ?',
      [novelUrl],
    );
    return result.first['count'] as int;
  }

  /// 根据URL获取章节
  Future<Chapter?> getChapterByUrl(String chapterUrl) async {
    final db = await database;
    final maps = await db.query(
      'novel_chapters',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );

    if (maps.isNotEmpty) {
      final map = maps.first;
      return Chapter(
        title: map['title'] as String,
        url: map['chapterUrl'] as String,
        chapterIndex: map['chapterIndex'] as int?,
        isUserInserted: (map['isUserInserted'] as int?) == 1,
      );
    }
    return null;
  }

  /// 删除用户章节
  Future<void> deleteUserChapter(String chapterUrl) async {
    final db = await database;

    // 先获取要删除章节的信息
    final chapterResult = await db.query(
      'novel_chapters',
      where: 'chapterUrl = ? AND isUserInserted = 1',
      whereArgs: [chapterUrl],
    );

    if (chapterResult.isEmpty) {
      return; // 章节不存在或不是用户章节
    }

    final deletedChapter = chapterResult.first;
    final novelUrl = deletedChapter['novelUrl'] as String;
    final deletedIndex = deletedChapter['chapterIndex'] as int;

    final batch = db.batch();

    // 删除章节元数据
    batch.delete(
      'novel_chapters',
      where: 'chapterUrl = ? AND isUserInserted = 1',
      whereArgs: [chapterUrl],
    );

    // 删除章节内容
    batch.delete(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );

    await batch.commit(noResult: true);

    // 重新排序章节索引：将删除位置之后的章节索引都减1
    await db.rawUpdate(
      'UPDATE novel_chapters SET chapterIndex = chapterIndex - 1 WHERE novelUrl = ? AND chapterIndex > ?',
      [novelUrl, deletedIndex],
    );

    // 同时更新章节缓存表中的索引
    await db.rawUpdate(
      'UPDATE chapter_cache SET chapterIndex = chapterIndex - 1 WHERE novelUrl = ? AND chapterIndex > ?',
      [novelUrl, deletedIndex],
    );
  }

  /// 更新阅读进度
  Future<void> updateReadingProgress(String novelUrl, int chapterIndex, double progress) async {
    final db = await database;
    await db.update(
      'bookshelf',
      {
        'lastReadChapterIndex': chapterIndex,
        'readingProgress': progress,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
  }
}
