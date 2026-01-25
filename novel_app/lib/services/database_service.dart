import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/search_result.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../models/scene_illustration.dart';
import '../models/outline.dart';
import '../models/chat_scene.dart';
import '../models/ai_accompaniment_settings.dart';
import '../models/ai_companion_response.dart';
import '../core/di/api_service_provider.dart';
import 'invalid_markup_cleaner.dart';
import 'logger_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  /// 内存状态跟踪：已确认缓存的章节URL
  final Set<String> _cachedInMemory = <String>{};

  /// 内存状态跟踪：正在预加载的章节URL
  final Set<String> _preloading = <String>{};

  /// 内存缓存最大容量（防止无限增长）
  static const int _maxMemoryCacheSize = 1000;

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
      version: 14,
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
        lastReadTime INTEGER,
        aiAccompanimentEnabled INTEGER DEFAULT 0,
        aiInfoNotificationEnabled INTEGER DEFAULT 0
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
        aliases TEXT DEFAULT '[]',
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
      final tableInfo =
          await db.rawQuery("PRAGMA table_info(scene_illustrations)");
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

        LoggerService.instance.i(
          '数据库升级：重新创建了 scene_illustrations 表，添加了 task_id 字段',
          category: LogCategory.database,
          tags: ['migration', 'schema', 'task_id'],
        );
      }
    }
    if (oldVersion < 9) {
      // 创建大纲表
      await db.execute('''
        CREATE TABLE outlines (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          novel_url TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      LoggerService.instance.i(
        '数据库升级：创建了 outlines 表',
        category: LogCategory.database,
        tags: ['migration', 'schema', 'outlines'],
      );
    }
    if (oldVersion < 10) {
      // 创建聊天场景表
      await db.execute('''
        CREATE TABLE chat_scenes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER
        )
      ''');
      // 创建标题索引，便于搜索
      await db.execute('''
        CREATE INDEX idx_chat_scenes_title ON chat_scenes(title)
      ''');
      LoggerService.instance.i(
        '数据库升级：创建了 chat_scenes 表和索引',
        category: LogCategory.database,
        tags: ['migration', 'schema', 'chat_scenes'],
      );
    }
    if (oldVersion < 11) {
      // 添加章节已读时间戳字段
      await db.execute('''
        ALTER TABLE novel_chapters ADD COLUMN readAt INTEGER
      ''');
      LoggerService.instance.i(
          '数据库升级：添加了 novel_chapters.readAt 字段',
          category: LogCategory.database,
          tags: ['migration', 'schema', 'readAt'],
        );
    }
    if (oldVersion < 12) {
      // 添加角色别名字段
      await db.execute('''
        ALTER TABLE characters ADD COLUMN aliases TEXT DEFAULT '[]'
      ''');
      LoggerService.instance.i(
          '数据库升级：添加了 characters.aliases 字段',
          category: LogCategory.database,
          tags: ['migration', 'schema', 'aliases'],
        );
    }
    if (oldVersion < 13) {
      // 创建角色关系表
      await db.execute('''
        CREATE TABLE character_relationships (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source_character_id INTEGER NOT NULL,
          target_character_id INTEGER NOT NULL,
          relationship_type TEXT NOT NULL,
          description TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER,
          FOREIGN KEY (source_character_id) REFERENCES characters(id) ON DELETE CASCADE,
          FOREIGN KEY (target_character_id) REFERENCES characters(id) ON DELETE CASCADE,
          UNIQUE(source_character_id, target_character_id, relationship_type)
        )
      ''');

      // 创建索引以优化查询性能
      await db.execute('''
        CREATE INDEX idx_relationships_source ON character_relationships(source_character_id)
      ''');
      await db.execute('''
        CREATE INDEX idx_relationships_target ON character_relationships(target_character_id)
      ''');

      LoggerService.instance.i(
          '数据库升级：创建了 character_relationships 表和索引',
          category: LogCategory.database,
          tags: ['migration', 'schema', 'relationships'],
        );
    }
    if (oldVersion < 14) {
      // 添加AI伴读设置字段
      await db.execute('''
        ALTER TABLE bookshelf ADD COLUMN aiAccompanimentEnabled INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE bookshelf ADD COLUMN aiInfoNotificationEnabled INTEGER DEFAULT 0
      ''');
      LoggerService.instance.i(
          '数据库升级：添加了AI伴读设置字段',
          category: LogCategory.database,
          tags: ['migration', 'schema', 'ai_accompaniment'],
        );
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
      {'backgroundSetting': backgroundSetting},
      where: 'url = ?',
      whereArgs: [novelUrl],
    );
  }

  /// 获取小说的AI伴读设置
  Future<AiAccompanimentSettings> getAiAccompanimentSettings(
      String novelUrl) async {
    if (isWebPlatform) {
      return const AiAccompanimentSettings(); // Web平台返回默认值
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookshelf',
      columns: ['aiAccompanimentEnabled', 'aiInfoNotificationEnabled'],
      where: 'url = ?',
      whereArgs: [novelUrl],
    );

    if (maps.isEmpty) {
      return const AiAccompanimentSettings(); // 返回默认值
    }

    return AiAccompanimentSettings(
      autoEnabled: (maps[0]['aiAccompanimentEnabled'] as int) == 1,
      infoNotificationEnabled:
          (maps[0]['aiInfoNotificationEnabled'] as int) == 1,
    );
  }

  /// 更新小说的AI伴读设置
  Future<int> updateAiAccompanimentSettings(
      String novelUrl, AiAccompanimentSettings settings) async {
    if (isWebPlatform) {
      return 0; // Web平台什么都不做，返回0
    }

    final db = await database;
    return await db.update(
      'bookshelf',
      {
        'aiAccompanimentEnabled': settings.autoEnabled ? 1 : 0,
        'aiInfoNotificationEnabled': settings.infoNotificationEnabled ? 1 : 0,
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

  /// 添加到内存缓存（带容量限制）
  void _addCachedInMemory(String chapterUrl) {
    if (_cachedInMemory.length >= _maxMemoryCacheSize) {
      // 简单策略：清空所有缓存
      // 更好的策略是使用LRU，但这里为了简洁使用清空策略
      _cachedInMemory.clear();
      LoggerService.instance.i(
          '内存缓存已满，已清空 ($_maxMemoryCacheSize条)',
          category: LogCategory.cache,
          tags: ['memory', 'cleanup'],
        );
    }
    _cachedInMemory.add(chapterUrl);
  }

  /// 检查章节是否已缓存（内存优先）
  ///
  /// 先检查内存状态，如果内存中没有则查询数据库
  /// 查询成功后会更新内存状态以提高后续查询性能
  Future<bool> isChapterCached(String chapterUrl) async {
    // 先检查内存缓存
    if (_cachedInMemory.contains(chapterUrl)) {
      return true;
    }

    // 再检查数据库
    final content = await getCachedChapter(chapterUrl);
    if (content != null && content.isNotEmpty) {
      _addCachedInMemory(chapterUrl);
      return true;
    }

    return false;
  }

  /// 批量检查缓存状态，返回未缓存的章节URL列表
  ///
  /// [chapterUrls] 章节URL列表
  /// 返回未缓存的章节URL列表
  Future<List<String>> filterUncachedChapters(List<String> chapterUrls) async {
    final uncached = <String>[];

    for (final url in chapterUrls) {
      if (!await isChapterCached(url)) {
        uncached.add(url);
      }
    }

    return uncached;
  }

  /// 标记章节正在预加载
  ///
  /// 用于防止重复预加载同一章节
  void markAsPreloading(String chapterUrl) {
    _preloading.add(chapterUrl);
  }

  /// 检查章节是否正在预加载
  bool isPreloading(String chapterUrl) {
    return _preloading.contains(chapterUrl);
  }

  /// 清理内存状态
  ///
  /// App启动或需要重置状态时调用
  void clearMemoryState() {
    _cachedInMemory.clear();
    _preloading.clear();
    LoggerService.instance.i(
          'DatabaseService内存状态已清理',
          category: LogCategory.database,
          tags: ['memory', 'cleanup'],
        );
  }

  /// 缓存章节内容
  Future<int> cacheChapter(
      String novelUrl, Chapter chapter, String content) async {
    final db = await database;
    final result = await db.insert(
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

    // 更新内存状态
    _addCachedInMemory(chapter.url);
    _preloading.remove(chapter.url);

    return result;
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
  ///
  /// 自动清理无效的媒体标记（插图、视频等）
  Future<String?> getCachedChapter(String chapterUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chapter_cache',
      where: 'chapterUrl = ?',
      whereArgs: [chapterUrl],
    );

    if (maps.isNotEmpty) {
      final content = maps.first['content'] as String;

      // 自动清理无效的媒体标记
      final cleanedContent = await InvalidMarkupCleaner()
          .cleanAndUpdateChapter(chapterUrl, content);

      return cleanedContent;
    }
    return null;
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
  /// 使用 UPSERT 方式，保留已读状态（readAt）
  Future<void> cacheNovelChapters(
      String novelUrl, List<Chapter> chapters) async {
    final db = await database;

    // 使用 UPSERT 保留已读状态
    // ON CONFLICT DO UPDATE 只更新指定字段，保留 readAt
    for (var i = 0; i < chapters.length; i++) {
      await db.rawInsert('''
        INSERT INTO novel_chapters (novelUrl, chapterUrl, title, chapterIndex, isUserInserted)
        VALUES (?, ?, ?, ?, 0)
        ON CONFLICT(novelUrl, chapterUrl) DO UPDATE SET
          title = excluded.title,
          chapterIndex = excluded.chapterIndex
      ''', [novelUrl, chapters[i].url, chapters[i].title, i]);
    }

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
        nc.chapterIndex, nc.isUserInserted, nc.insertedAt, nc.readAt,
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
        readAt: maps[i]['readAt'] as int?,
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
    final chapterUrl =
        'custom://chapter/${DateTime.now().millisecondsSinceEpoch}';
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
    final maxIndex = result.isNotEmpty
        ? (result.first['maxIndex'] as int? ?? 0)
        : 0;

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
  Future<void> updateChaptersOrder(
      String novelUrl, List<Chapter> chapters) async {
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

    // 使用 JOIN 查询从 novel_chapters 表获取正确的标题和索引
    String sql = '''
      SELECT
        cc.novelUrl,
        cc.chapterUrl,
        nc.title,
        cc.content,
        nc.chapterIndex,
        cc.cachedAt
      FROM chapter_cache cc
      INNER JOIN novel_chapters nc ON cc.chapterUrl = nc.chapterUrl
      WHERE (cc.content LIKE ? OR nc.title LIKE ?)
    ''';

    List<dynamic> whereArgs = ['%$keyword%', '%$keyword%'];

    if (novelUrl != null && novelUrl.isNotEmpty) {
      sql += ' AND cc.novelUrl = ?';
      whereArgs.add(novelUrl);
    }

    sql += ' ORDER BY cc.novelUrl, nc.chapterIndex';

    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, whereArgs);

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
        chapterIndex:
            int.tryParse(maps[i]['chapterIndex']?.toString() ?? '0') ?? 0,
        content: content,
        searchKeywords: [keyword],
        matchPositions: matchPositions,
        cachedAt: DateTime.tryParse(maps[i]['cachedAt']?.toString() ?? '') ??
            DateTime.now(),
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
    if (result.isEmpty) return 0;
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
        readAt: map['readAt'] as int?,
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
  Future<void> updateReadingProgress(
      String novelUrl, int chapterIndex, double progress) async {
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

      LoggerService.instance.i(
          '更新角色: ${newCharacter.name} (ID: ${existingCharacter.id})',
          category: LogCategory.character,
          tags: ['update', 'success'],
        );
      return updatedCharacter;
    } else {
      // 创建新角色
      final id = await db.insert(
        'characters',
        newCharacter.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      LoggerService.instance.i(
          '创建新角色: ${newCharacter.name} (ID: $id)',
          category: LogCategory.character,
          tags: ['create', 'success'],
        );
      return newCharacter.copyWith(id: id);
    }
  }

  /// 批量更新角色
  /// 接受新角色列表，对每个角色执行去重更新逻辑
  Future<List<Character>> batchUpdateCharacters(
      List<Character> newCharacters) async {
    final updatedCharacters = <Character>[];

    for (final character in newCharacters) {
      try {
        final updatedCharacter = await updateOrInsertCharacter(character);
        updatedCharacters.add(updatedCharacter);
      } catch (e) {
        LoggerService.instance.e(
          '批量更新角色失败: ${character.name}, 错误: $e',
          category: LogCategory.character,
          tags: ['batch', 'error'],
        );
        // 继续处理其他角色，不中断整个批量操作
        continue;
      }
    }

    LoggerService.instance.i(
      '批量更新完成，成功更新 ${updatedCharacters.length}/${newCharacters.length} 个角色',
      category: LogCategory.character,
      tags: ['batch', 'update'],
    );
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
  Future<int> updateCharacterCachedImage(
      int characterId, String? imageUrl) async {
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
        readAt: maps[i]['readAt'] as int?,
      );
    });
  }

  /// 标记章节为已读
  Future<void> markChapterAsRead(String novelUrl, String chapterUrl) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'novel_chapters',
      {'readAt': now},
      where: 'novelUrl = ? AND chapterUrl = ?',
      whereArgs: [novelUrl, chapterUrl],
    );

    LoggerService.instance.i(
          '章节已标记为已读: $chapterUrl',
          category: LogCategory.database,
          tags: ['chapter', 'read', 'success'],
        );
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
      LoggerService.instance.e(
          '获取章节内容失败: $e',
          category: LogCategory.database,
          tags: ['chapter', 'content', 'error'],
        );
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

  // ========== 角色关系操作 ==========

  /// 创建角色关系
  /// [relationship] 要创建的关系对象
  /// 返回新插入记录的ID，如果关系已存在则抛出异常
  Future<int> createRelationship(CharacterRelationship relationship) async {
    final db = await database;

    try {
      final id = await db.insert(
        'character_relationships',
        relationship.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      LoggerService.instance.i(
          '创建关系成功: $id',
          category: LogCategory.character,
          tags: ['relationship', 'create', 'success'],
        );
      return id;
    } catch (e) {
      LoggerService.instance.e(
          '创建关系失败: $e',
          category: LogCategory.character,
          tags: ['relationship', 'create', 'error'],
        );
      rethrow;
    }
  }

  /// 获取角色的所有关系（出度 + 入度）
  /// [characterId] 角色ID
  /// 返回该角色相关的所有关系列表
  Future<List<CharacterRelationship>> getRelationships(int characterId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM character_relationships
      WHERE source_character_id = ? OR target_character_id = ?
      ORDER BY created_at DESC
    ''', [characterId, characterId]);

    return maps.map((map) => CharacterRelationship.fromMap(map)).toList();
  }

  /// 获取角色的出度关系（Ta → 其他人）
  /// [characterId] 角色ID
  /// 返回该角色发起的所有关系列表
  Future<List<CharacterRelationship>> getOutgoingRelationships(
      int characterId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'character_relationships',
      where: 'source_character_id = ?',
      whereArgs: [characterId],
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => CharacterRelationship.fromMap(map)).toList();
  }

  /// 获取角色的入度关系（其他人 → Ta）
  /// [characterId] 角色ID
  /// 返回指向该角色的所有关系列表
  Future<List<CharacterRelationship>> getIncomingRelationships(
      int characterId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'character_relationships',
      where: 'target_character_id = ?',
      whereArgs: [characterId],
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => CharacterRelationship.fromMap(map)).toList();
  }

  /// 更新角色关系
  /// [relationship] 要更新的关系对象（必须包含id）
  /// 返回受影响的行数
  Future<int> updateRelationship(CharacterRelationship relationship) async {
    if (relationship.id == null) {
      throw ArgumentError('关系ID不能为空');
    }

    final db = await database;

    try {
      final count = await db.update(
        'character_relationships',
        relationship.toMap(),
        where: 'id = ?',
        whereArgs: [relationship.id],
      );
      LoggerService.instance.i(
        '更新关系成功: ${relationship.id}',
        category: LogCategory.character,
        tags: ['relationship', 'update', 'success'],
      );
      return count;
    } catch (e) {
      LoggerService.instance.e(
          '更新关系失败: $e',
          category: LogCategory.character,
          tags: ['relationship', 'update', 'error'],
        );
      rethrow;
    }
  }

  /// 删除角色关系
  /// [relationshipId] 关系ID
  /// 返回受影响的行数
  Future<int> deleteRelationship(int relationshipId) async {
    final db = await database;

    try {
      final count = await db.delete(
        'character_relationships',
        where: 'id = ?',
        whereArgs: [relationshipId],
      );
      LoggerService.instance.i(
          '删除关系成功: $relationshipId',
          category: LogCategory.character,
          tags: ['relationship', 'delete', 'success'],
        );
      return count;
    } catch (e) {
      LoggerService.instance.e(
          '删除关系失败: $e',
          category: LogCategory.character,
          tags: ['relationship', 'delete', 'error'],
        );
      rethrow;
    }
  }

  /// 检查关系是否已存在
  /// [sourceId] 源角色ID
  /// [targetId] 目标角色ID
  /// [type] 关系类型
  /// 返回关系是否存在
  Future<bool> relationshipExists(
      int sourceId, int targetId, String type) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'character_relationships',
      where: 'source_character_id = ? AND target_character_id = ? AND relationship_type = ?',
      whereArgs: [sourceId, targetId, type],
      limit: 1,
    );

    return maps.isNotEmpty;
  }

  /// 获取角色的关系数量
  /// [characterId] 角色ID
  /// 返回该角色的关系总数（出度 + 入度）
  Future<int> getRelationshipCount(int characterId) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM character_relationships
      WHERE source_character_id = ? OR target_character_id = ?
    ''', [characterId, characterId]);

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取与某角色相关的所有角色（去重）
  /// [characterId] 角色ID
  /// 返回相关角色的ID列表
  Future<List<int>> getRelatedCharacterIds(int characterId) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT DISTINCT
        CASE
          WHEN source_character_id = ? THEN target_character_id
          ELSE source_character_id
        END as related_id
      FROM character_relationships
      WHERE source_character_id = ? OR target_character_id = ?
    ''', [characterId, characterId, characterId]);

    return result.map((row) => row['related_id'] as int).toList();
  }

  // ========== 场景插图操作 ==========

  /// 插入场景插图记录
  Future<int> insertSceneIllustration(SceneIllustration illustration) async {
    final db = await database;
    return await db.insert('scene_illustrations', illustration.toMap());
  }

  /// 更新场景插图状态
  Future<int> updateSceneIllustrationStatus(int id, String status,
      {List<String>? images, String? prompts}) async {
    final db = await database;
    final Map<String, dynamic> updateData = {
      'status': status,
      'completed_at':
          status == 'completed' ? DateTime.now().toIso8601String() : null,
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
  Future<List<SceneIllustration>> getSceneIllustrationsByChapter(
      String novelUrl, String chapterId) async {
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

  /// 获取分页的场景插图列表（带总数）
  Future<Map<String, dynamic>> getSceneIllustrationsPaginated({
    required int page,
    required int limit,
  }) async {
    final db = await database;
    final offset = page * limit; // page从0开始

    // 查询总数
    final List<Map<String, dynamic>> countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM scene_illustrations',
    );
    final int total = countResult.first['count'] as int;
    final int totalPages = (total / limit).ceil();

    // 查询当前页数据
    final List<Map<String, dynamic>> maps = await db.query(
      'scene_illustrations',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    final List<SceneIllustration> items = List.generate(maps.length, (i) {
      return SceneIllustration.fromMap(maps[i]);
    });

    return {
      'items': items,
      'total': total,
      'totalPages': totalPages,
    };
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
  Future<int> deleteSceneIllustrationsByChapter(
      String novelUrl, String chapterId) async {
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
  Future<int> batchUpdateSceneIllustrations(
      List<int> ids, String status) async {
    final db = await database;
    int count = 0;

    for (final id in ids) {
      count += await db.update(
        'scene_illustrations',
        {
          'status': status,
          'completed_at':
              status == 'completed' ? DateTime.now().toIso8601String() : null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    return count;
  }

  // ========== 大纲操作 ==========

  /// 创建或更新大纲
  /// 如果小说URL已存在大纲则更新，否则创建新的
  Future<int> saveOutline(Outline outline) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 检查是否已存在该小说的大纲
    final existing = await getOutlineByNovelUrl(outline.novelUrl);

    if (existing != null) {
      // 更新现有大纲
      return await db.update(
        'outlines',
        {
          'title': outline.title,
          'content': outline.content,
          'updated_at': now,
        },
        where: 'novel_url = ?',
        whereArgs: [outline.novelUrl],
      );
    } else {
      // 创建新大纲
      return await db.insert(
        'outlines',
        {
          'novel_url': outline.novelUrl,
          'title': outline.title,
          'content': outline.content,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// 根据小说URL获取大纲
  Future<Outline?> getOutlineByNovelUrl(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'outlines',
      where: 'novel_url = ?',
      whereArgs: [novelUrl],
    );

    if (maps.isNotEmpty) {
      return Outline.fromMap(maps.first);
    }
    return null;
  }

  /// 获取所有大纲
  Future<List<Outline>> getAllOutlines() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'outlines',
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) {
      return Outline.fromMap(maps[i]);
    });
  }

  /// 删除大纲
  Future<int> deleteOutline(String novelUrl) async {
    final db = await database;
    return await db.delete(
      'outlines',
      where: 'novel_url = ?',
      whereArgs: [novelUrl],
    );
  }

  /// 更新大纲内容
  Future<int> updateOutlineContent(
      String novelUrl, String title, String content) async {
    final db = await database;
    return await db.update(
      'outlines',
      {
        'title': title,
        'content': content,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'novel_url = ?',
      whereArgs: [novelUrl],
    );
  }

  // ========== 聊天场景操作 ==========

  /// 插入聊天场景
  Future<int> insertChatScene(ChatScene scene) async {
    final db = await database;
    return await db.insert('chat_scenes', scene.toMap());
  }

  /// 更新聊天场景
  Future<void> updateChatScene(ChatScene scene) async {
    final db = await database;
    await db.update(
      'chat_scenes',
      scene.toMap(),
      where: 'id = ?',
      whereArgs: [scene.id],
    );
  }

  /// 删除聊天场景
  Future<void> deleteChatScene(int id) async {
    final db = await database;
    await db.delete(
      'chat_scenes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取所有聊天场景
  Future<List<ChatScene>> getAllChatScenes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_scenes',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => ChatScene.fromMap(maps[i]));
  }

  /// 根据ID获取聊天场景
  Future<ChatScene?> getChatSceneById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_scenes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ChatScene.fromMap(maps.first);
  }

  /// 搜索聊天场景（按标题）
  Future<List<ChatScene>> searchChatScenes(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_scenes',
      where: 'title LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => ChatScene.fromMap(maps[i]));
  }

  // ============================================================================
  // AI伴读功能相关方法
  // ============================================================================

  /// 追加背景设定
  ///
  /// [novelUrl] 小说URL
  /// [newBackground] 新增的背景设定，将追加到现有背景设定之后
  Future<int> appendBackgroundSetting(
    String novelUrl,
    String newBackground,
  ) async {
    if (isWebPlatform) {
      return 0; // Web平台什么都不做，返回0
    }

    if (newBackground.trim().isEmpty) {
      LoggerService.instance.w(
          '新增背景设定为空，跳过更新',
          category: LogCategory.ai,
          tags: ['background', 'validation'],
        );
      return 0;
    }

    final db = await database;

    // 获取现有背景设定
    final List<Map<String, dynamic>> maps = await db.query(
      'bookshelf',
      columns: ['backgroundSetting'],
      where: 'url = ?',
      whereArgs: [novelUrl],
      limit: 1,
    );

    if (maps.isEmpty) {
      LoggerService.instance.w(
          '未找到小说: $novelUrl',
          category: LogCategory.database,
          tags: ['novel', 'not_found'],
        );
      return 0;
    }

    final existingBackground = maps.first['backgroundSetting'] as String?;
    final updatedBackground = existingBackground == null || existingBackground.isEmpty
        ? newBackground
        : '$existingBackground\n\n$newBackground';

    // 更新背景设定
    final count = await db.update(
      'bookshelf',
      {'backgroundSetting': updatedBackground},
      where: 'url = ?',
      whereArgs: [novelUrl],
    );

    LoggerService.instance.i(
          '背景设定追加成功: $novelUrl (新增 ${newBackground.length} 字符)',
          category: LogCategory.ai,
          tags: ['background', 'update', 'success'],
        );
    return count;
  }

  /// 批量更新或插入角色（用于AI伴读）
  ///
  /// [novelUrl] 小说URL
  /// [aiRoles] AI返回的角色更新列表
  /// 返回成功更新的角色数量
  Future<int> batchUpdateOrInsertCharacters(
    String novelUrl,
    List<AICompanionRole> aiRoles,
  ) async {
    if (isWebPlatform) {
      return 0;
    }

    if (aiRoles.isEmpty) {
      LoggerService.instance.w(
          'AI返回角色列表为空，跳过更新',
          category: LogCategory.ai,
          tags: ['character', 'batch', 'empty'],
        );
      return 0;
    }

    int successCount = 0;

    for (final aiRole in aiRoles) {
      try {
        // 查找是否已存在同名角色
        final existingCharacter = await findCharacterByName(
          novelUrl,
          aiRole.name,
        );

        if (existingCharacter != null) {
          // 更新现有角色，保留原有ID和创建时间
          final updatedCharacter = existingCharacter.copyWith(
            gender: (aiRole.gender != null && aiRole.gender!.isNotEmpty) ? aiRole.gender : null,
            age: aiRole.age,
            occupation: (aiRole.occupation != null && aiRole.occupation!.isNotEmpty) ? aiRole.occupation : null,
            personality: (aiRole.personality != null && aiRole.personality!.isNotEmpty) ? aiRole.personality : null,
            bodyType: (aiRole.bodyType != null && aiRole.bodyType!.isNotEmpty) ? aiRole.bodyType : null,
            clothingStyle: (aiRole.clothingStyle != null && aiRole.clothingStyle!.isNotEmpty) ? aiRole.clothingStyle : null,
            appearanceFeatures: (aiRole.appearanceFeatures != null && aiRole.appearanceFeatures!.isNotEmpty) ? aiRole.appearanceFeatures : null,
            backgroundStory: (aiRole.backgroundStory != null && aiRole.backgroundStory!.isNotEmpty) ? aiRole.backgroundStory : null,
            updatedAt: DateTime.now(),
          );

          await updateCharacter(updatedCharacter);
          successCount++;
          LoggerService.instance.i(
            '更新角色: ${aiRole.name}',
            category: LogCategory.ai,
            tags: ['character', 'update', 'success'],
          );
        } else {
          // 创建新角色
          final newCharacter = Character(
            novelUrl: novelUrl,
            name: aiRole.name,
            gender: (aiRole.gender != null && aiRole.gender!.isNotEmpty) ? aiRole.gender : null,
            age: aiRole.age,
            occupation: (aiRole.occupation != null && aiRole.occupation!.isNotEmpty) ? aiRole.occupation : null,
            personality: (aiRole.personality != null && aiRole.personality!.isNotEmpty) ? aiRole.personality : null,
            bodyType: (aiRole.bodyType != null && aiRole.bodyType!.isNotEmpty) ? aiRole.bodyType : null,
            clothingStyle: (aiRole.clothingStyle != null && aiRole.clothingStyle!.isNotEmpty) ? aiRole.clothingStyle : null,
            appearanceFeatures: (aiRole.appearanceFeatures != null && aiRole.appearanceFeatures!.isNotEmpty) ? aiRole.appearanceFeatures : null,
            backgroundStory: (aiRole.backgroundStory != null && aiRole.backgroundStory!.isNotEmpty) ? aiRole.backgroundStory : null,
          );

          await createCharacter(newCharacter);
          successCount++;
          LoggerService.instance.i(
            '新增角色: ${aiRole.name}',
            category: LogCategory.ai,
            tags: ['character', 'create', 'success'],
          );
        }
      } catch (e) {
        LoggerService.instance.e(
          '更新/插入角色失败: ${aiRole.name}, 错误: $e',
          category: LogCategory.ai,
          tags: ['character', 'error'],
        );
        // 继续处理其他角色
        continue;
      }
    }

    LoggerService.instance.i(
      '批量更新角色完成: $successCount/${aiRoles.length}',
      category: LogCategory.ai,
      tags: ['character', 'batch', 'success'],
    );
    return successCount;
  }

  /// 批量更新或插入关系（用于AI伴读）
  ///
  /// [novelUrl] 小说URL
  /// [aiRelations] AI返回的关系更新列表
  /// 返回成功更新的关系数量
  Future<int> batchUpdateOrInsertRelationships(
    String novelUrl,
    List<AICompanionRelation> aiRelations,
  ) async {
    if (isWebPlatform) {
      return 0;
    }

    if (aiRelations.isEmpty) {
      LoggerService.instance.w(
          'AI返回关系列表为空，跳过更新',
          category: LogCategory.ai,
          tags: ['relationship', 'batch', 'empty'],
        );
      return 0;
    }

    // 获取小说的所有角色，建立名称到ID的映射
    final allCharacters = await getCharacters(novelUrl);
    final Map<String, int> characterNameToId = {
      for (var c in allCharacters) if (c.id != null) c.name: c.id!,
    };

    int successCount = 0;

    for (final aiRelation in aiRelations) {
      try {
        // 查找source和target的角色ID
        final sourceId = characterNameToId[aiRelation.source];
        final targetId = characterNameToId[aiRelation.target];

        if (sourceId == null) {
          LoggerService.instance.w(
          '未找到source角色: ${aiRelation.source}，跳过关系: $aiRelation',
          category: LogCategory.ai,
          tags: ['relationship', 'character_not_found'],
        );
          continue;
        }

        if (targetId == null) {
          LoggerService.instance.w(
          '未找到target角色: ${aiRelation.target}，跳过关系: $aiRelation',
          category: LogCategory.ai,
          tags: ['relationship', 'character_not_found'],
        );
          continue;
        }

        // 查找是否已存在相同source和target的关系
        final existingRelations = await _getRelationshipsByCharacterIds(sourceId, targetId);

        if (existingRelations.isNotEmpty) {
          // 更新现有关系的type
          final existingRelation = existingRelations.first;
          final updatedRelation = existingRelation.copyWith(
            relationshipType: aiRelation.type,
            updatedAt: DateTime.now(),
          );

          await updateRelationship(updatedRelation);
          successCount++;
          LoggerService.instance.i(
          '更新关系: ${aiRelation.source} -> ${aiRelation.target} (${aiRelation.type})',
          category: LogCategory.ai,
          tags: ['relationship', 'update', 'success'],
        );
        } else {
          // 创建新关系
          final newRelation = CharacterRelationship(
            sourceCharacterId: sourceId,
            targetCharacterId: targetId,
            relationshipType: aiRelation.type,
          );

          await createRelationship(newRelation);
          successCount++;
          LoggerService.instance.i(
          '新增关系: ${aiRelation.source} -> ${aiRelation.target} (${aiRelation.type})',
          category: LogCategory.ai,
          tags: ['relationship', 'create', 'success'],
        );
        }
      } catch (e) {
        LoggerService.instance.e(
          '更新/插入关系失败: $aiRelation, 错误: $e',
          category: LogCategory.ai,
          tags: ['relationship', 'error'],
        );
        // 继续处理其他关系
        continue;
      }
    }

    LoggerService.instance.i(
      '批量更新关系完成: $successCount/${aiRelations.length}',
      category: LogCategory.ai,
      tags: ['relationship', 'batch', 'success'],
    );
    return successCount;
  }

  /// 获取小说的所有关系
  ///
  /// [novelUrl] 小说URL
  /// 返回该小说的所有角色关系
  Future<List<CharacterRelationship>> getAllRelationships(String novelUrl) async {
    if (isWebPlatform) {
      return [];
    }

    final db = await database;

    // 获取小说的所有角色ID
    final List<Map<String, dynamic>> characterMaps = await db.query(
      'characters',
      columns: ['id'],
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
    );

    if (characterMaps.isEmpty) {
      return [];
    }

    final characterIds = characterMaps.map((m) => m['id'] as int).toList();

    // 构建查询条件：source或target在角色ID列表中
    final placeholders = List.filled(characterIds.length, '?').join(',');
    final query = '''
      SELECT * FROM character_relationships
      WHERE source_character_id IN ($placeholders)
         OR target_character_id IN ($placeholders)
      ORDER BY created_at DESC
    ''';

    final args = [...characterIds, ...characterIds];
    final List<Map<String, dynamic>> relationMaps = await db.rawQuery(query, args);

    return relationMaps.map((map) => CharacterRelationship.fromMap(map)).toList();
  }

  /// 根据source和target角色ID获取关系
  ///
  /// [sourceId] 源角色ID
  /// [targetId] 目标角色ID
  /// 返回匹配的关系列表
  Future<List<CharacterRelationship>> _getRelationshipsByCharacterIds(
    int sourceId,
    int targetId,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'character_relationships',
      where: 'source_character_id = ? AND target_character_id = ?',
      whereArgs: [sourceId, targetId],
    );

    return maps.map((map) => CharacterRelationship.fromMap(map)).toList();
  }
}
