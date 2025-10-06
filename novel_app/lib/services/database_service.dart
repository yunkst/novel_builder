import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/novel.dart';
import '../models/chapter.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'novel_reader.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
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
        UNIQUE(novelUrl, chapterUrl)
      )
    ''');
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

  // ========== 章节缓存操作 ==========

  /// 缓存章节内容
  Future<int> cacheChapter(String novelUrl, Chapter chapter, String content) async {
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

  /// 缓存整本小说
  Future<void> cacheWholeNovel(String novelUrl, List<Chapter> chapters, Future<String> Function(String) getContent) async {
    for (var chapter in chapters) {
      final content = await getContent(chapter.url);
      await cacheChapter(novelUrl, chapter, content);
    }
  }

  // ========== 章节列表缓存操作 ==========

  /// 缓存小说章节列表
  Future<void> cacheNovelChapters(String novelUrl, List<Chapter> chapters) async {
    final db = await database;
    final batch = db.batch();

    // 先删除旧的章节列表
    batch.delete(
      'novel_chapters',
      where: 'novelUrl = ?',
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
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 获取缓存的章节列表
  Future<List<Chapter>> getCachedNovelChapters(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'novel_chapters',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
      orderBy: 'chapterIndex ASC',
    );

    return List.generate(maps.length, (i) {
      return Chapter(
        title: maps[i]['title'],
        url: maps[i]['chapterUrl'],
        chapterIndex: maps[i]['chapterIndex'],
      );
    });
  }

  /// 清空所有缓存
  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete('chapter_cache');
    await db.delete('novel_chapters');
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
