import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../interfaces/i_database_connection.dart';
import '../../services/logger_service.dart';

/// 数据库连接管理类
///
/// 职责：
/// - 管理数据库连接的初始化和生命周期
/// - 处理数据库版本升级和迁移
/// - 提供单例模式的数据库实例访问
///
/// 架构说明：
/// - 实现 IDatabaseConnection 接口
/// - 单例模式，确保全局只有一个数据库连接实例
/// - 惰性初始化，首次访问时才创建数据库连接
class DatabaseConnection implements IDatabaseConnection {
  // ==================== 单例模式 ====================

  static DatabaseConnection? _instance;
  static Database? _database;

  /// 私有构造函数，防止外部直接创建实例
  DatabaseConnection._internal();

  /// 工厂构造函数，返回单例实例
  factory DatabaseConnection() {
    _instance ??= DatabaseConnection._internal();
    return _instance!;
  }

  /// 测试用构造函数 - 使用外部提供的数据库实例
  ///
  /// 这个构造函数仅用于测试，允许注入内存数据库
  /// 避免单例模式导致的测试隔离问题
  factory DatabaseConnection.forTesting(Database testDatabase) {
    // 设置全局静态数据库实例
    _database = testDatabase;
    final connection = DatabaseConnection._internal();
    return connection;
  }

  // ==================== IDatabaseConnection 接口实现 ====================

  @override
  bool get isInitialized => _database != null;

  @override
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  @override
  Future<void> initialize() async {
    await database; // 触发初始化
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // ==================== 数据库初始化 ====================

  /// 检查是否为Web平台
  bool get isWebPlatform => kIsWeb;

  /// 初始化数据库连接
  Future<Database> _initDatabase() async {
    try {
      if (kIsWeb) {
        throw Exception('Database is not supported on web platform');
      }

      final databasePath = await getDatabasesPath();
      final path = join(databasePath, 'novel_reader.db');

      return await openDatabase(
        path,
        version: 21, // 当前数据库版本
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '数据库初始化失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['database', 'init', 'failed'],
      );
      rethrow;
    }
  }

  /// 数据库创建回调
  ///
  /// 当数据库首次创建时调用，负责创建所有表结构
  Future<void> _onCreate(Database db, int version) async {
    try {
      // 创建小说表
      //
      // 注意：表名为 bookshelf 是历史遗留原因，实际存储的是小说(Novel)数据
      // 为避免与 Bookshelf 模型（书架分类功能）混淆，我们创建了 novels 视图作为别名
      //
      // 表结构说明:
      // - bookshelf 表: 物理表，存储小说元数据和阅读进度
      // - novels 视图: 逻辑视图，提供更清晰的语义
      // - Bookshelf 模型: 书架分类功能（id, name, icon, color）
      //
      // 建议新代码优先使用 novels 视图，保持语义清晰
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
      // 这些索引可以显著提升查询性能，特别是在章节列表加载时

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
      //
      // 命名说明：
      // - bookshelf 表：物理表，存储小说元数据（历史遗留命名）
      // - novels 视图：逻辑视图，提供更清晰的语义
      // - Bookshelf 模型：书架分类功能（id, name, icon, color）
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

      LoggerService.instance.i(
        '数据库初始化成功，版本 $version',
        category: LogCategory.database,
        tags: ['database', 'create', 'success'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '数据库创建失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['database', 'create', 'failed'],
      );
      rethrow;
    }
  }

  /// 数据库升级回调
  ///
  /// 处理数据库版本升级，支持从旧版本平滑升级到新版本
  /// 支持的升级路径：v2 → v21
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final startTime = DateTime.now();

    try {
      // ========== 版本 2：用户插入章节标记 ==========
      if (oldVersion < 2) {
        await db.execute('''
        ALTER TABLE novel_chapters ADD COLUMN isUserInserted INTEGER DEFAULT 0
      ''');
        await db.execute('''
        ALTER TABLE novel_chapters ADD COLUMN insertedAt INTEGER
      ''');
      }

      // ========== 版本 3：背景设定字段 ==========
      if (oldVersion < 3) {
        await db.execute('''
        ALTER TABLE bookshelf ADD COLUMN backgroundSetting TEXT
      ''');
      }

      // ========== 版本 4：人物表 ==========
      if (oldVersion < 4) {
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

      // ========== 版本 5：提示词字段 ==========
      if (oldVersion < 5) {
        await db.execute('''
        ALTER TABLE characters ADD COLUMN facePrompts TEXT
      ''');
        await db.execute('''
        ALTER TABLE characters ADD COLUMN bodyPrompts TEXT
      ''');
      }

      // ========== 版本 6：缓存图片URL ==========
      if (oldVersion < 6) {
        await db.execute('''
        ALTER TABLE characters ADD COLUMN cachedImageUrl TEXT
      ''');
      }

      // ========== 版本 7：场景插图表 ==========
      if (oldVersion < 7) {
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

      // ========== 版本 8：修复场景插图表 ==========
      if (oldVersion < 8) {
        // 检查是否已经有旧版本的 scene_illustrations 表（没有 task_id 字段）
        final tableInfo =
            await db.rawQuery("PRAGMA table_info(scene_illustrations)");
        final hasTaskId =
            tableInfo.any((column) => column['name'] == 'task_id');

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

      // ========== 版本 9：大纲表 ==========
      if (oldVersion < 9) {
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

      // ========== 版本 10：聊天场景表 ==========
      if (oldVersion < 10) {
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

      // ========== 版本 11：章节已读时间戳 ==========
      if (oldVersion < 11) {
        await db.execute('''
        ALTER TABLE novel_chapters ADD COLUMN readAt INTEGER
      ''');
        LoggerService.instance.i(
          '数据库升级：添加了 novel_chapters.readAt 字段',
          category: LogCategory.database,
          tags: ['migration', 'schema', 'readAt'],
        );
      }

      // ========== 版本 12：角色别名字段 ==========
      if (oldVersion < 12) {
        await db.execute('''
        ALTER TABLE characters ADD COLUMN aliases TEXT DEFAULT '[]'
      ''');
        LoggerService.instance.i(
          '数据库升级：添加了 characters.aliases 字段',
          category: LogCategory.database,
          tags: ['migration', 'schema', 'aliases'],
        );
      }

      // ========== 版本 13：角色关系表 ==========
      if (oldVersion < 13) {
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

      // ========== 版本 14：AI伴读设置 ==========
      if (oldVersion < 14) {
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

      // ========== 版本 15：章节伴读标记 ==========
      if (oldVersion < 15) {
        await db.execute('''
        ALTER TABLE chapter_cache ADD COLUMN ai_accompanied INTEGER DEFAULT 0
      ''');
        LoggerService.instance.i(
          '数据库升级：添加了 chapter_cache.ai_accompanied 字段',
          category: LogCategory.database,
          tags: ['migration', 'schema', 'ai_accompanied'],
        );
      }

      // ========== 版本 16：多书架功能 ==========
      if (oldVersion < 16) {
        // 创建书架表
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

        // 数据迁移：将现有书籍关联到"我的收藏"书架
        await db.execute('''
        INSERT OR IGNORE INTO novel_bookshelves (novel_url, bookshelf_id, created_at)
        SELECT url, 2, strftime('%s', 'now')
        FROM bookshelf
        WHERE url IS NOT NULL
      ''');

        LoggerService.instance.i(
          '数据库升级：创建了多书架功能相关表（bookshelves, novel_bookshelves）',
          category: LogCategory.database,
          tags: ['migration', 'schema', 'multi_bookshelf'],
        );
      }

      // ========== 版本 17：修复人物表字段 ==========
      if (oldVersion < 17) {
        // 添加缺失的人物提示词字段（修复_onCreate中的遗漏）
        // 检查字段是否已存在
        final tableInfo = await db.rawQuery("PRAGMA table_info(characters)");
        final hasFacePrompts =
            tableInfo.any((column) => column['name'] == 'facePrompts');

        if (!hasFacePrompts) {
          await db
              .execute('ALTER TABLE characters ADD COLUMN facePrompts TEXT');
          await db
              .execute('ALTER TABLE characters ADD COLUMN bodyPrompts TEXT');
          await db
              .execute('ALTER TABLE characters ADD COLUMN cachedImageUrl TEXT');

          LoggerService.instance.i(
            '数据库升级：添加了缺失的characters表字段（facePrompts, bodyPrompts, cachedImageUrl）',
            category: LogCategory.database,
            tags: ['migration', 'schema', 'characters_fix'],
          );
        }
      }

      // ========== 版本 18：AI伴读标记字段标准化 ==========
      if (oldVersion < 18) {
        // 添加AI伴读标记字段到chapter_cache表（如果还没有）
        final chapterCacheInfo =
            await db.rawQuery("PRAGMA table_info(chapter_cache)");
        final chapterCacheHasIsAccompanied =
            chapterCacheInfo.any((column) => column['name'] == 'isAccompanied');

        if (!chapterCacheHasIsAccompanied) {
          await db.execute(
              'ALTER TABLE chapter_cache ADD COLUMN isAccompanied INTEGER DEFAULT 0');

          LoggerService.instance.i(
            '数据库升级：添加了chapter_cache.isAccompanied字段',
            category: LogCategory.database,
            tags: ['migration', 'schema', 'ai_accompaniment'],
          );
        }

        // 添加AI伴读标记字段到novel_chapters表（如果还没有）
        final novelChaptersInfo =
            await db.rawQuery("PRAGMA table_info(novel_chapters)");
        final novelChaptersHasIsAccompanied = novelChaptersInfo
            .any((column) => column['name'] == 'isAccompanied');

        if (!novelChaptersHasIsAccompanied) {
          await db.execute(
              'ALTER TABLE novel_chapters ADD COLUMN isAccompanied INTEGER DEFAULT 0');

          LoggerService.instance.i(
            '数据库升级：添加了novel_chapters.isAccompanied字段',
            category: LogCategory.database,
            tags: ['migration', 'schema', 'ai_accompaniment'],
          );
        }
      }

      // ========== 版本 19：字段重命名 ==========
      if (oldVersion < 19) {
        // 重命名字段：ai_accompanied -> isAccompanied（如果存在旧字段名）
        final chapterCacheInfo =
            await db.rawQuery("PRAGMA table_info(chapter_cache)");
        final hasOldAiAccompanied = chapterCacheInfo
            .any((column) => column['name'] == 'ai_accompanied');
        final hasNewIsAccompanied =
            chapterCacheInfo.any((column) => column['name'] == 'isAccompanied');

        if (hasOldAiAccompanied && !hasNewIsAccompanied) {
          // SQLite 不支持直接重命名列，需要重建表
          await db.execute('''
          CREATE TABLE chapter_cache_new (
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

          await db.execute('''
          INSERT INTO chapter_cache_new (id, novelUrl, chapterUrl, title, content, chapterIndex, cachedAt, isAccompanied)
          SELECT id, novelUrl, chapterUrl, title, content, chapterIndex, cachedAt, ai_accompanied
          FROM chapter_cache
        ''');

          await db.execute('DROP TABLE chapter_cache');
          await db
              .execute('ALTER TABLE chapter_cache_new RENAME TO chapter_cache');

          LoggerService.instance.i(
            '数据库升级：重命名 chapter_cache.ai_accompanied 为 isAccompanied',
            category: LogCategory.database,
            tags: ['migration', 'schema', 'ai_accompaniment'],
          );
        }

        // 同样处理 novel_chapters 表
        final novelChaptersInfo =
            await db.rawQuery("PRAGMA table_info(novel_chapters)");
        final hasOldAiAccompanied2 = novelChaptersInfo
            .any((column) => column['name'] == 'ai_accompanied');
        final hasNewIsAccompanied2 = novelChaptersInfo
            .any((column) => column['name'] == 'isAccompanied');

        if (hasOldAiAccompanied2 && !hasNewIsAccompanied2) {
          await db.execute('''
          CREATE TABLE novel_chapters_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            novelUrl TEXT NOT NULL,
            chapterUrl TEXT NOT NULL,
            title TEXT NOT NULL,
            chapterIndex INTEGER,
            isUserInserted INTEGER DEFAULT 0,
            insertedAt INTEGER,
            isAccompanied INTEGER DEFAULT 0,
            UNIQUE(novelUrl, chapterUrl)
          )
        ''');

          await db.execute('''
          INSERT INTO novel_chapters_new (id, novelUrl, chapterUrl, title, chapterIndex, isUserInserted, insertedAt, isAccompanied)
          SELECT id, novelUrl, chapterUrl, title, chapterIndex, isUserInserted, insertedAt, ai_accompanied
          FROM novel_chapters
        ''');

          await db.execute('DROP TABLE novel_chapters');
          await db.execute(
              'ALTER TABLE novel_chapters_new RENAME TO novel_chapters');

          LoggerService.instance.i(
            '数据库升级：重命名 novel_chapters.ai_accompanied 为 isAccompanied',
            category: LogCategory.database,
            tags: ['migration', 'schema', 'ai_accompaniment'],
          );
        }
      }

      // ========== 版本 20：novels 视图 ==========
      if (oldVersion < 20) {
        // 创建 novels 视图作为 bookshelf 表的语义别名
        //
        // 命名说明：
        // - bookshelf 表：物理表，存储小说元数据（历史遗留命名）
        // - novels 视图：逻辑视图，提供更清晰的语义
        // - Bookshelf 模型：书架分类功能（id, name, icon, color）
        //
        // 创建视图后，新代码优先使用 novels 视图进行查询，保持语义清晰
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

        LoggerService.instance.i(
          '数据库升级：创建了 novels 视图作为 bookshelf 表的语义别名',
          category: LogCategory.database,
          tags: ['migration', 'schema', 'novels_view'],
        );
      }

      // ========== 版本 21：性能优化索引 ==========
      if (oldVersion < 21) {
        // 添加性能优化索引
        // 检查索引是否已存在（避免重复创建）
        final indexes = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'");

        final indexNames = indexes.map((row) => row['name'] as String).toSet();

        // chapter_cache 表索引
        if (!indexNames.contains('idx_chapter_cache_chapter_url')) {
          await db.execute('''
          CREATE INDEX idx_chapter_cache_chapter_url ON chapter_cache(chapterUrl)
        ''');
          LoggerService.instance.i(
            '数据库升级：创建了 chapter_cache.chapterUrl 索引',
            category: LogCategory.database,
            tags: ['migration', 'schema', 'performance_index'],
          );
        }

        if (!indexNames.contains('idx_chapter_cache_novel_url')) {
          await db.execute('''
          CREATE INDEX idx_chapter_cache_novel_url ON chapter_cache(novelUrl)
        ''');
          LoggerService.instance.i(
            '数据库升级：创建了 chapter_cache.novelUrl 索引',
            category: LogCategory.database,
            tags: ['migration', 'schema', 'performance_index'],
          );
        }

        // novel_chapters 表索引
        if (!indexNames.contains('idx_novel_chapters_novel_url')) {
          await db.execute('''
          CREATE INDEX idx_novel_chapters_novel_url ON novel_chapters(novelUrl)
        ''');
          LoggerService.instance.i(
            '数据库升级：创建了 novel_chapters.novelUrl 索引',
            category: LogCategory.database,
            tags: ['migration', 'schema', 'performance_index'],
          );
        }

        if (!indexNames.contains('idx_novel_chapters_chapter_url')) {
          await db.execute('''
          CREATE INDEX idx_novel_chapters_chapter_url ON novel_chapters(chapterUrl)
        ''');
          LoggerService.instance.i(
            '数据库升级：创建了 novel_chapters.chapterUrl 索引',
            category: LogCategory.database,
            tags: ['migration', 'schema', 'performance_index'],
          );
        }
      }

      final duration = DateTime.now().difference(startTime);
      LoggerService.instance.i(
        '✅ 数据库升级成功: v$oldVersion → v$newVersion, 耗时${duration.inMilliseconds}ms',
        category: LogCategory.database,
        tags: ['database', 'upgrade', 'success'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '❌ 数据库升级失败: v$oldVersion → v$newVersion: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['database', 'upgrade', 'failed'],
      );
      rethrow;
    }
  }
}
