import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqflite.dart';

/// 测试数据库设置工具
///
/// 提供内存数据库创建和初始化功能，用于集成测试
///
/// 使用场景：
/// - Repository集成测试
/// - 数据库迁移测试
/// - SQL逻辑验证测试
///
/// 优点：
/// - 速度快：内存数据库比文件数据库快10-100倍
/// - 隔离性好：每个测试创建独立的数据库实例
/// - 自动清理：测试结束自动释放内存
/// - 真实性：使用真实SQLite引擎执行SQL
class TestDatabaseSetup {
  static bool _initialized = false;

  /// 初始化测试数据库工厂
  ///
  /// 必须在使用前调用一次
  static void init() {
    if (!_initialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _initialized = true;
    }
  }

  /// 创建内存数据库并初始化表结构
  ///
  /// 返回一个已初始化的内存数据库实例，包含所有必需的表和索引
  ///
  /// 使用示例：
  /// ```dart
  /// setUp(() async {
  ///   final db = await TestDatabaseSetup.createInMemoryDatabase();
  ///   final connection = DatabaseConnection.forTesting(db);
  ///   repository = BookshelfRepository(dbConnection: connection);
  /// });
  /// ```
  static Future<Database> createInMemoryDatabase() async {
    // 确保databaseFactory已初始化
    init();

    final db = await openDatabase(
      ':memory:', // 内存数据库，不写磁盘
      version: 21,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      singleInstance: false, // 允许多个实例，用于测试隔离
    );

    return db;
  }

  /// 数据库创建回调
  ///
  /// 复用 DatabaseConnection 中的建表SQL
  /// 确保测试数据库结构与生产环境一致
  static Future<void> _onCreate(Database db, int version) async {
    try {
      // 创建小说表 (bookshelf表)
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
        cachedAt INTEGER NOT NULL,
        isAccompanied INTEGER DEFAULT 0
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
        isAccompanied INTEGER DEFAULT 0,
        readAt INTEGER,
        UNIQUE(novelUrl, chapterUrl)
      )
    ''');

      // ========== 性能优化索引 ==========

      // chapter_cache 表索引
      await db.execute('''
      CREATE INDEX idx_chapter_cache_chapter_url ON chapter_cache(chapterUrl)
    ''');
      await db.execute('''
      CREATE INDEX idx_chapter_cache_novel_url ON chapter_cache(novelUrl)
    ''');

      // novel_chapters 表索引
      await db.execute('''
      CREATE INDEX idx_novel_chapters_novel_url ON novel_chapters(novelUrl)
    ''');
      await db.execute('''
      CREATE INDEX idx_novel_chapters_chapter_url ON novel_chapters(chapterUrl)
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
        facePrompts TEXT,
        bodyPrompts TEXT,
        cachedImageUrl TEXT,
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

      // 创建 novels 视图作为 bookshelf 表的语义别名
      await db.execute('''
        CREATE VIEW IF NOT EXISTS novels AS
        SELECT
          id,
          title,
          author,
          url,
          coverUrl,
          description,
          backgroundSetting,
          addedAt,
          lastReadChapter,
          lastReadTime,
          aiAccompanimentEnabled,
          aiInfoNotificationEnabled
        FROM bookshelf
      ''');

      // 创建书架表 (bookshelves)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bookshelves (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          sort_order INTEGER DEFAULT 0,
          icon TEXT DEFAULT 'book',
          color INTEGER DEFAULT 0xFF2196F3,
          is_system INTEGER DEFAULT 0
        )
      ''');

      // 创建小说-书架关联表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS novel_bookshelves (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          novel_url TEXT NOT NULL,
          bookshelf_id INTEGER NOT NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          FOREIGN KEY (novel_url) REFERENCES bookshelf(url) ON DELETE CASCADE,
          FOREIGN KEY (bookshelf_id) REFERENCES bookshelves(id) ON DELETE CASCADE,
          UNIQUE(novel_url, bookshelf_id)
        )
      ''');

      // 创建索引
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_novel_bookshelf_url ON novel_bookshelves(novel_url)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_bookshelf_id ON novel_bookshelves(bookshelf_id)
      ''');

      // 插入系统书架
      await db.execute('''
        INSERT OR IGNORE INTO bookshelves (id, name, created_at, sort_order, is_system)
        VALUES
          (1, '全部小说', strftime('%s', 'now'), 0, 1),
          (2, '我的收藏', strftime('%s', 'now'), 1, 1)
      ''');

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
    } catch (e, stackTrace) {
      // 测试环境中不使用Logger，直接抛出异常
      throw Exception('测试数据库创建失败: $e\n$stackTrace');
    }
  }

  /// 数据库升级回调（空实现）
  ///
  /// 测试环境总是创建最新版本的数据库，不需要升级逻辑
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 测试环境直接创建最新版本，不需要升级
    // 如果需要测试升级逻辑，应该创建专门的迁移测试
  }

  /// 清空所有表数据（保留表结构）
  ///
  /// 用于测试间的数据清理，但不重新创建数据库
  ///
  /// 使用示例：
  /// ```dart
  /// tearDown(() async {
  ///   await TestDatabaseSetup.clearAllTables(db);
  ///   await db.close();
  /// });
  /// ```
  static Future<void> clearAllTables(Database db) async {
    await db.delete('bookshelf');
    await db.delete('chapter_cache');
    await db.delete('novel_chapters');
    await db.delete('characters');
    await db.delete('scene_illustrations');
    await db.delete('bookshelves');
    await db.delete('novel_bookshelves');
    await db.delete('character_relationships');
    await db.delete('outlines');
    await db.delete('chat_scenes');
  }

  /// 统计表中的记录数（用于调试）
  ///
  /// 返回每个表的记录数量，方便验证测试数据
  static Future<Map<String, int>> getTableStats(Database db) async {
    final tables = [
      'bookshelf',
      'chapter_cache',
      'novel_chapters',
      'characters',
      'scene_illustrations',
      'bookshelves',
      'novel_bookshelves',
      'character_relationships',
      'outlines',
      'chat_scenes',
    ];

    final stats = <String, int>{};
    for (final table in tables) {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
      stats[table] = result.first['count'] as int? ?? 0;
    }

    return stats;
  }
}
