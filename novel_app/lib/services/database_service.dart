import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/search_result.dart';
import '../models/character.dart';
import '../models/scene_illustration.dart';
import '../core/di/api_service_provider.dart';

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
      version: 8,
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

    // 创建人物表
    await db.execute('''
      CREATE TABLE characters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        novelUrl TEXT NOT NULL,
        name TEXT NOT NULL,
        age INTEGER,
        gender TEXT,
        occupation TEXT,
        personality TEXT,
        bodyType TEXT,
        clothingStyle TEXT,
        appearanceFeatures TEXT,
        backgroundStory TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER,
        UNIQUE(novelUrl, name)
      )
    ''');

    // 创建场景插图表
    await db.execute('''
      CREATE TABLE scene_illustrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        novel_url TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        task_id TEXT NOT NULL UNIQUE,
        content TEXT NOT NULL,
        roles TEXT NOT NULL,
        image_count INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        images TEXT DEFAULT '',
        prompts TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT
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
    if (oldVersion < 4) {
      // 创建人物表
      await db.execute('''
        CREATE TABLE characters (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          novelUrl TEXT NOT NULL,
          name TEXT NOT NULL,
          age INTEGER,
          gender TEXT,
          occupation TEXT,
          personality TEXT,
          bodyType TEXT,
          clothingStyle TEXT,
          appearanceFeatures TEXT,
          backgroundStory TEXT,
          facePrompts TEXT,
          bodyPrompts TEXT,
          cachedImageUrl TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER,
          UNIQUE(novelUrl, name)
        )
      ''');
    }
    if (oldVersion < 5) {
      // 添加提示词字段
      await db.execute('''
        ALTER TABLE characters ADD COLUMN facePrompts TEXT
      ''');
      await db.execute('''
        ALTER TABLE characters ADD COLUMN bodyPrompts TEXT
      ''');
    }
    if (oldVersion < 6) {
      // 添加缓存图片URL字段
      await db.execute('''
        ALTER TABLE characters ADD COLUMN cachedImageUrl TEXT
      ''');
    }
    if (oldVersion < 7) {
      // 创建场景插图表
      await db.execute('''
        CREATE TABLE scene_illustrations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          novel_url TEXT NOT NULL,
          chapter_id TEXT NOT NULL,
          task_id TEXT NOT NULL UNIQUE,
          content TEXT NOT NULL,
          roles TEXT NOT NULL,
          image_count INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          images TEXT DEFAULT '',
          prompts TEXT,
          created_at TEXT NOT NULL,
          completed_at TEXT
        )
      ''');
    }
    if (oldVersion < 8) {
      // 检查是否已经有旧版本的 scene_illustrations 表（没有 task_id 字段）
      final tableInfo = await db.rawQuery("PRAGMA table_info(scene_illustrations)");
      final hasTaskId = tableInfo.any((column) => column['name'] == 'task_id');

      if (!hasTaskId) {
        // 备份现有数据（如果有的话）
        // 注意：这里备份了数据但没有使用，因为表结构已改变
        await db.query('scene_illustrations');

        // 删除旧表
        await db.execute('DROP TABLE IF EXISTS scene_illustrations');

        // 创建新表
        await db.execute('''
          CREATE TABLE scene_illustrations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            novel_url TEXT NOT NULL,
            chapter_id TEXT NOT NULL,
            task_id TEXT NOT NULL UNIQUE,
            content TEXT NOT NULL,
            roles TEXT NOT NULL,
            image_count INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            images TEXT DEFAULT '',
            prompts TEXT,
            created_at TEXT NOT NULL,
            completed_at TEXT
          )
        ''');

        debugPrint('数据库升级：重新创建了 scene_illustrations 表，添加了 task_id 字段');
      }
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
  ///
  /// 索引系统说明：
  /// - 使用0-based索引系统，与网络章节保持一致
  /// - 空数据库时创建的第一章：chapterIndex = 0
  /// - 显示时使用 chapterIndex + 1 来呈现用户友好的章节号
  Future<int> createCustomChapter(
      String novelUrl, String title, String content) async {
    final db = await database;

    // 获取当前最大章节索引
    // 注意：使用0-based索引系统，空数据库时默认值为0
    final result = await db.rawQuery(
      'SELECT MAX(chapterIndex) as maxIndex FROM novel_chapters WHERE novelUrl = ?',
      [novelUrl],
    );
    final maxIndex = result.first['maxIndex'] as int? ?? 0;

    // 生成章节URL
    final chapterUrl =
        'custom://chapter/${DateTime.now().millisecondsSinceEpoch}';

    // 插入章节元数据（使用0-based索引）
    await db.insert(
      'novel_chapters',
      {
        'novelUrl': novelUrl,
        'chapterUrl': chapterUrl,
        'title': title,
        'chapterIndex': maxIndex, // 0-based索引，与网络章节一致
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
        'chapterIndex': maxIndex,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return maxIndex;
  }

  /// 更新章节顺序
  Future<void> updateChaptersOrder(String novelUrl, List<Chapter> chapters) async {
    final db = await database;
    final batch = db.batch();

    // 批量更新所有章节的索引
    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      batch.update(
        'novel_chapters',
        {'chapterIndex': i},
        where: 'novelUrl = ? AND chapterUrl = ?',
        whereArgs: [novelUrl, chapter.url],
      );

      // 同时更新章节缓存表中的索引
      batch.update(
        'chapter_cache',
        {'chapterIndex': i},
        where: 'novelUrl = ? AND chapterUrl = ?',
        whereArgs: [novelUrl, chapter.url],
      );
    }

    await batch.commit(noResult: true);
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

    String whereClause = "(content LIKE ? OR title LIKE ?)";
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
        novelUrl: maps[i]['novelUrl']?.toString() ?? '',
        novelTitle: title, // 使用章节标题作为小说标题（临时解决方案）
        novelAuthor: '未知作者', // 数据库中没有作者信息，需要从书架表获取
        chapterUrl: maps[i]['chapterUrl']?.toString() ?? '',
        chapterTitle: title,
        chapterIndex: int.tryParse(maps[i]['chapterIndex']?.toString() ?? '0') ?? 0,
        content: content,
        searchKeywords: [keyword],
        matchPositions: matchPositions,
        cachedAt:
            DateTime.tryParse(maps[i]['cachedAt']?.toString() ?? '') ?? DateTime.now(),
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

  // ========== 人物卡操作 ==========

  /// 创建人物卡
  Future<int> createCharacter(Character character) async {
    final db = await database;
    return await db.insert(
      'characters',
      character.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取小说的所有人物卡
  Future<List<Character>> getCharacters(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
      orderBy: 'createdAt ASC',
    );

    return List.generate(maps.length, (i) {
      return Character.fromMap(maps[i]);
    });
  }

  /// 根据ID获取人物卡
  Future<Character?> getCharacter(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Character.fromMap(maps.first);
    }
    return null;
  }

  /// 更新人物卡
  Future<int> updateCharacter(Character character) async {
    final db = await database;
    final updatedCharacter = character.copyWith(
      updatedAt: DateTime.now(),
    );

    return await db.update(
      'characters',
      updatedCharacter.toMap(),
      where: 'id = ?',
      whereArgs: [character.id],
    );
  }

  /// 删除人物卡
  Future<int> deleteCharacter(int id) async {
    final db = await database;
    return await db.delete(
      'characters',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据名称查找人物卡
  Future<Character?> findCharacterByName(String novelUrl, String name) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      where: 'novelUrl = ? AND name = ?',
      whereArgs: [novelUrl, name],
    );

    if (maps.isNotEmpty) {
      return Character.fromMap(maps.first);
    }
    return null;
  }

  /// 更新或插入角色（去重逻辑）
  /// 如果角色已存在（按novelUrl和name匹配），则更新现有角色
  /// 如果角色不存在，则创建新角色
  Future<Character> updateOrInsertCharacter(Character newCharacter) async {
    final db = await database;

    // 查找是否已存在同名角色
    final existingCharacter = await findCharacterByName(
      newCharacter.novelUrl,
      newCharacter.name,
    );

    if (existingCharacter != null) {
      // 更新现有角色，保留原有ID和创建时间
      final updatedCharacter = existingCharacter.copyWith(
        age: newCharacter.age,
        gender: newCharacter.gender,
        occupation: newCharacter.occupation,
        personality: newCharacter.personality,
        bodyType: newCharacter.bodyType,
        clothingStyle: newCharacter.clothingStyle,
        appearanceFeatures: newCharacter.appearanceFeatures,
        backgroundStory: newCharacter.backgroundStory,
        updatedAt: DateTime.now(),
      );

      await db.update(
        'characters',
        updatedCharacter.toMap(),
        where: 'id = ?',
        whereArgs: [existingCharacter.id],
      );

      debugPrint('更新角色: ${newCharacter.name} (ID: ${existingCharacter.id})');
      return updatedCharacter;
    } else {
      // 创建新角色
      final id = await db.insert(
        'characters',
        newCharacter.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('创建新角色: ${newCharacter.name} (ID: $id)');
      return newCharacter.copyWith(id: id);
    }
  }

  /// 批量更新角色
  /// 接受新角色列表，对每个角色执行去重更新逻辑
  Future<List<Character>> batchUpdateCharacters(List<Character> newCharacters) async {
    final updatedCharacters = <Character>[];

    for (final character in newCharacters) {
      try {
        final updatedCharacter = await updateOrInsertCharacter(character);
        updatedCharacters.add(updatedCharacter);
      } catch (e) {
        debugPrint('批量更新角色失败: ${character.name}, 错误: $e');
        // 继续处理其他角色，不中断整个批量操作
        continue;
      }
    }

    debugPrint('批量更新完成，成功更新 ${updatedCharacters.length}/${newCharacters.length} 个角色');
    return updatedCharacters;
  }

  /// 获取小说的所有角色名称
  Future<List<String>> getCharacterNames(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      columns: ['name'],
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
      orderBy: 'name ASC',
    );

    return maps.map((map) => map['name'] as String).toList();
  }

  /// 检查人物卡是否存在
  Future<bool> characterExists(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      where: 'id = ?',
      whereArgs: [id],
    );

    return maps.isNotEmpty;
  }

  /// 根据ID列表获取多个人物卡
  Future<List<Character>> getCharactersByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'createdAt ASC',
    );

    return List.generate(maps.length, (i) {
      return Character.fromMap(maps[i]);
    });
  }

  /// 删除小说的所有人物卡
  Future<int> deleteAllCharacters(String novelUrl) async {
    final db = await database;
    return await db.delete(
      'characters',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
    );
  }

  // ========== 角色图集缓存管理功能 ==========

  /// 更新角色的缓存图片URL
  Future<int> updateCharacterCachedImage(int characterId, String? imageUrl) async {
    final db = await database;
    return await db.update(
      'characters',
      {
        'cachedImageUrl': imageUrl,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [characterId],
    );
  }

  /// 清除角色的缓存图片URL
  Future<int> clearCharacterCachedImage(int characterId) async {
    final db = await database;
    return await db.update(
      'characters',
      {
        'cachedImageUrl': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [characterId],
    );
  }

  /// 批量清除角色的缓存图片URL
  Future<int> clearAllCharacterCachedImages(String novelUrl) async {
    final db = await database;
    return await db.update(
      'characters',
      {
        'cachedImageUrl': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
    );
  }

  // ========== 角色上下文提取功能 ==========

  /// 获取小说的所有章节（按索引排序）
  Future<List<Chapter>> getChapters(String novelUrl) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'novel_chapters',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
      orderBy: 'chapterIndex ASC',
    );

    return List.generate(maps.length, (i) {
      return Chapter(
        title: maps[i]['title'] ?? '',
        url: maps[i]['chapterUrl'] ?? '',
        chapterIndex: maps[i]['chapterIndex'] ?? 0,
      );
    });
  }

  /// 获取章节内容
  Future<String> getChapterContent(String chapterUrl) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );

    if (maps.isNotEmpty) {
      return maps.first['content'] ?? '';
    }

    // 如果本地缓存没有，尝试从API获取
    try {
      final apiService = ApiServiceProvider.instance;
      final content = await apiService.getChapterContent(chapterUrl);
      return content;
    } catch (e) {
      debugPrint('获取章节内容失败: $e');
      return '';
    }
  }

  /// 仅从本地缓存获取章节内容（不调用API）
  Future<String> getCachedChapterContent(String chapterUrl) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );

    if (maps.isNotEmpty) {
      return maps.first['content'] ?? '';
    }

    return ''; // 本地缓存没有时直接返回空字符串
  }

  // ========== 角色头像获取功能 ==========

  /// 获取角色的缓存图片URL
  /// [characterId] 角色ID
  /// 返回头像缓存路径，如果没有设置则返回null
  Future<String?> getCharacterCachedImage(int characterId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      columns: ['cachedImageUrl'],
      where: 'id = ?',
      whereArgs: [characterId],
      limit: 1,
    );

    if (maps.isNotEmpty && maps.first['cachedImageUrl'] != null) {
      return maps.first['cachedImageUrl'] as String?;
    }

    return null;
  }

  /// 更新角色头像信息（扩展方法，支持更多元数据）
  /// [characterId] 角色ID
  /// [imageUrl] 头像URL/路径
  /// [originalFilename] 原始图集文件名
  /// [originalImageUrl] 原始图片URL
  Future<int> updateCharacterAvatar(
    int characterId, {
    String? imageUrl,
    String? originalFilename,
    String? originalImageUrl,
  }) async {
    final db = await database;

    final Map<String, dynamic> updateData = {
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    if (imageUrl != null) {
      updateData['cachedImageUrl'] = imageUrl;
    } else {
      updateData['cachedImageUrl'] = null;
    }

    return await db.update(
      'characters',
      updateData,
      where: 'id = ?',
      whereArgs: [characterId],
    );
  }

  /// 检查角色是否有头像缓存
  /// [characterId] 角色ID
  /// 返回是否有头像缓存
  Future<bool> hasCharacterAvatar(int characterId) async {
    final cachedUrl = await getCharacterCachedImage(characterId);
    return cachedUrl != null && cachedUrl.isNotEmpty;
  }

  // ========== 场景插图操作 ==========

  /// 插入场景插图记录
  Future<int> insertSceneIllustration(SceneIllustration illustration) async {
    final db = await database;
    return await db.insert('scene_illustrations', illustration.toMap());
  }

  /// 更新场景插图状态
  Future<int> updateSceneIllustrationStatus(int id, String status, {List<String>? images, String? prompts}) async {
    final db = await database;
    final Map<String, dynamic> updateData = {
      'status': status,
      'completed_at': status == 'completed' ? DateTime.now().toIso8601String() : null,
    };

    if (images != null) {
      updateData['images'] = images.join(',');
    }

    if (prompts != null) {
      updateData['prompts'] = prompts;
    }

    return await db.update(
      'scene_illustrations',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据小说和章节获取场景插图列表（新版本推荐）
  Future<List<SceneIllustration>> getSceneIllustrationsByChapter(String novelUrl, String chapterId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scene_illustrations',
      where: 'novel_url = ? AND chapter_id = ?',
      whereArgs: [novelUrl, chapterId],
      orderBy: 'created_at ASC', // 不再使用 paragraph_index 排序
    );

    return List.generate(maps.length, (i) {
      return SceneIllustration.fromMap(maps[i]);
    });
  }

  /// 根据 taskId 获取场景插图（新版本推荐）
  Future<SceneIllustration?> getSceneIllustrationByTaskId(String taskId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scene_illustrations',
      where: 'task_id = ?',
      whereArgs: [taskId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return SceneIllustration.fromMap(maps.first);
    }
    return null;
  }

  // 删除了 getSceneIllustrationByParagraph 方法，不再使用 paragraph_index

  /// 获取分页的场景插图列表
  Future<List<SceneIllustration>> getSceneIllustrationsPaginated({
    required int page,
    required int limit,
  }) async {
    final db = await database;
    final offset = (page - 1) * limit;

    final List<Map<String, dynamic>> maps = await db.query(
      'scene_illustrations',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) {
      return SceneIllustration.fromMap(maps[i]);
    });
  }

  /// 删除场景插图记录
  Future<int> deleteSceneIllustration(int id) async {
    final db = await database;
    return await db.delete(
      'scene_illustrations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除章节的所有场景插图
  Future<int> deleteSceneIllustrationsByChapter(String novelUrl, String chapterId) async {
    final db = await database;
    return await db.delete(
      'scene_illustrations',
      where: 'novel_url = ? AND chapter_id = ?',
      whereArgs: [novelUrl, chapterId],
    );
  }

  /// 获取所有待处理或正在处理的场景插图
  Future<List<SceneIllustration>> getPendingSceneIllustrations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scene_illustrations',
      where: 'status IN (?, ?)',
      whereArgs: ['pending', 'processing'],
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) {
      return SceneIllustration.fromMap(maps[i]);
    });
  }

  /// 批量更新场景插图状态
  Future<int> batchUpdateSceneIllustrations(List<int> ids, String status) async {
    final db = await database;
    int count = 0;

    for (final id in ids) {
      count += await db.update(
        'scene_illustrations',
        {
          'status': status,
          'completed_at': status == 'completed' ? DateTime.now().toIso8601String() : null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    return count;
  }
}
