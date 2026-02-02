import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/novel.dart';
import '../models/chapter.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../models/scene_illustration.dart';
import '../models/outline.dart';
import '../models/chat_scene.dart';
import '../models/ai_accompaniment_settings.dart';
import '../models/ai_companion_response.dart';
import '../models/bookshelf.dart';
import '../models/search_result.dart';
import 'logger_service.dart';
import '../repositories/novel_repository.dart';
import '../repositories/chapter_repository.dart';
import '../repositories/character_repository.dart';
import '../repositories/character_relation_repository.dart';
import '../repositories/illustration_repository.dart';
import '../repositories/outline_repository.dart';
import '../repositories/chat_scene_repository.dart';
import '../repositories/bookshelf_repository.dart';
import '../core/database/database_connection.dart';
import '../core/interfaces/i_database_connection.dart';

/// 本地数据库服务 - Repository 模式门面类
///
/// ## 架构说明
///
/// DatabaseService 现在作为一个门面类(Facade),将所有数据库操作委托给专门的 Repository 类:
///
/// ### Repository 层
/// - **NovelRepository**: 小说元数据和阅读进度操作
/// - **ChapterRepository**: 章节缓存和章节列表操作
/// - **CharacterRepository**: 角色和角色关系操作
/// - **CharacterRelationRepository**: 人物关系图操作
/// - **IllustrationRepository**: 场景插图操作
/// - **OutlineRepository**: 大纲操作
/// - **ChatSceneRepository**: 聊天场景操作
/// - **BookshelfRepository**: 书架分类操作
///
/// ### DatabaseService 职责
/// - 管理数据库连接和初始化
/// - 提供统一的对外接口(向后兼容)
/// - 协调各个 Repository 的数据库实例
/// - 处理数据库迁移
///
/// @Deprecated 新代码应该直接使用 Repository Providers:
/// - 使用 `ref.watch(novelRepositoryProvider)` 替代 `databaseService.novelRepository`
/// - 使用 `ref.watch(chapterRepositoryProvider)` 替代 `databaseService.chapterRepository`
/// - 使用 `ref.watch(characterRepositoryProvider)` 替代 `databaseService.characterRepository`
///
/// 此类保留用于向后兼容，将在未来版本中移除。
@Deprecated(
    'Use individual Repository Providers instead. See lib/core/providers/database_providers.dart')
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  /// 测试用构造函数 - 使用外部提供的数据库实例
  ///
  /// 这个构造函数仅用于测试,允许注入内存数据库
  /// 避免单例模式导致的测试隔离问题
  factory DatabaseService.forTesting(Database testDatabase) {
    // 设置全局静态数据库实例
    _database = testDatabase;
    final service = DatabaseService._internal();
    // 立即共享数据库给所有 Repository
    service._shareDatabaseWithRepositories();
    return service;
  }

  DatabaseService._internal() {
    // 初始化所有 Repository 实例
    _initRepositories();
  }

  // ==================== Repository 实例 ====================

  late final NovelRepository _novelRepository;
  late final ChapterRepository _chapterRepository;
  late final CharacterRepository _characterRepository;
  late final CharacterRelationRepository _characterRelationRepository;
  late final IllustrationRepository _illustrationRepository;
  late final OutlineRepository _outlineRepository;
  late final ChatSceneRepository _chatSceneRepository;
  late final BookshelfRepository _bookshelfRepository;

  /// 数据库连接实例（用于初始化Repository）
  IDatabaseConnection? _dbConnection;

  /// 初始化所有 Repository 实例
  void _initRepositories() {
    _dbConnection = DatabaseConnection();
    _novelRepository = NovelRepository(dbConnection: _dbConnection!);
    _chapterRepository = ChapterRepository(dbConnection: _dbConnection!);
    _characterRepository = CharacterRepository(dbConnection: _dbConnection!);
    _characterRelationRepository =
        CharacterRelationRepository(dbConnection: _dbConnection!);
    _illustrationRepository =
        IllustrationRepository(dbConnection: _dbConnection!);
    _outlineRepository = OutlineRepository(dbConnection: _dbConnection!);
    _chatSceneRepository = ChatSceneRepository(dbConnection: _dbConnection!);
    _bookshelfRepository = BookshelfRepository(dbConnection: _dbConnection!);
  }

  /// 共享数据库实例给所有 Repository
  /// @Deprecated: 新架构不再使用 setSharedDatabase，Repository 通过构造函数注入 DatabaseConnection
  Future<void> _shareDatabaseWithRepositories() async {
    // 暂时禁用，等待Repository迁移到新架构
    // final db = await database;
    // _novelRepository.setSharedDatabase(db);
    // _chapterRepository.setSharedDatabase(db);
    // _characterRepository.setSharedDatabase(db);
    // _characterRelationRepository.setSharedDatabase(db);
    // _illustrationRepository.setSharedDatabase(db);
    // _outlineRepository.setSharedDatabase(db);
    // _chatSceneRepository.setSharedDatabase(db);
    // _bookshelfRepository.setSharedDatabase(db);
  }

  bool get isWebPlatform => kIsWeb;

  // ==================== Repository Getters ====================

  /// 获取 NovelRepository 实例
  NovelRepository get novelRepository => _novelRepository;

  /// 获取 ChapterRepository 实例
  ChapterRepository get chapterRepository => _chapterRepository;

  /// 获取 CharacterRepository 实例
  CharacterRepository get characterRepository => _characterRepository;

  /// 获取 CharacterRelationRepository 实例
  CharacterRelationRepository get characterRelationRepository =>
      _characterRelationRepository;

  /// 获取 IllustrationRepository 实例
  IllustrationRepository get illustrationRepository => _illustrationRepository;

  /// 获取 OutlineRepository 实例
  OutlineRepository get outlineRepository => _outlineRepository;

  /// 获取 ChatSceneRepository 实例
  ChatSceneRepository get chatSceneRepository => _chatSceneRepository;

  /// 获取 BookshelfRepository 实例
  BookshelfRepository get bookshelfRepository => _bookshelfRepository;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    // 共享数据库实例给所有 Repository
    await _shareDatabaseWithRepositories();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      if (kIsWeb) {
        throw Exception('Database is not supported on web platform');
      }

      final databasePath = await getDatabasesPath();
      final path = join(databasePath, 'novel_reader.db');

      return await openDatabase(
        path,
        version: 21, // 升级到版本21，添加性能索引
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final startTime = DateTime.now();

    try {
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
      if (oldVersion < 15) {
        // 添加章节伴读标记字段
        await db.execute('''
        ALTER TABLE chapter_cache ADD COLUMN ai_accompanied INTEGER DEFAULT 0
      ''');
        LoggerService.instance.i(
          '数据库升级：添加了 chapter_cache.ai_accompanied 字段',
          category: LogCategory.database,
          tags: ['migration', 'schema', 'ai_accompanied'],
        );
      }
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

  // ========== 小说操作 (委托给 NovelRepository) ==========

  /// 添加小说到书架
  Future<int> addToBookshelf(Novel novel) =>
      _novelRepository.addToBookshelf(novel);

  /// 创建自定义小说并添加到书架(别名方法,兼容旧测试)
  Future<int> createCustomNovel(
    String title,
    String author, {
    String? description,
  }) async {
    final novel = Novel(
      title: title,
      author: author,
      url: 'local://custom_novel_${DateTime.now().millisecondsSinceEpoch}',
      coverUrl: null,
      description: description,
      backgroundSetting: null,
    );
    return await addToBookshelf(novel);
  }

  /// 从书架移除小说
  Future<int> removeFromBookshelf(String novelUrl) =>
      _novelRepository.removeFromBookshelf(novelUrl);

  /// 获取书架列表
  Future<List<Novel>> getBookshelf() => _novelRepository.getNovels();

  /// 获取所有小说（语义清晰版本）
  Future<List<Novel>> getNovels() => _novelRepository.getNovels();

  /// 检查小说是否在书架中
  Future<bool> isInBookshelf(String novelUrl) =>
      _novelRepository.isInBookshelf(novelUrl);

  /// 更新最后阅读章节
  Future<int> updateLastReadChapter(String novelUrl, int chapterIndex) =>
      _novelRepository.updateLastReadChapter(novelUrl, chapterIndex);

  /// 更新小说背景设定
  Future<int> updateBackgroundSetting(
          String novelUrl, String? backgroundSetting) =>
      _novelRepository.updateBackgroundSetting(novelUrl, backgroundSetting);

  /// 追加小说背景设定
  ///
  /// 如果当前背景为空,直接设置新内容
  /// 如果当前背景不为空,用双换行符(\n\n)追加新内容
  /// 如果新内容为空或纯空白字符,忽略操作
  ///
  /// 返回值:
  /// - 1: 成功更新
  /// - 0: 小说不存在或内容为空
  Future<int> appendBackgroundSetting(
      String novelUrl, String newBackground) async {
    // 忽略空内容或纯空白字符
    if (newBackground.trim().isEmpty) {
      return 0;
    }

    // 获取当前背景设定
    final currentBackground = await getBackgroundSetting(novelUrl);

    // 如果小说不存在,返回0
    if (currentBackground == null && !await isInBookshelf(novelUrl)) {
      return 0;
    }

    // 追加背景设定
    final updatedBackground =
        currentBackground == null || currentBackground.isEmpty
            ? newBackground
            : '$currentBackground\n\n$newBackground';

    return await updateBackgroundSetting(novelUrl, updatedBackground);
  }

  /// 获取小说背景设定
  Future<String?> getBackgroundSetting(String novelUrl) =>
      _novelRepository.getBackgroundSetting(novelUrl);

  /// 获取上次阅读的章节索引
  Future<int> getLastReadChapter(String novelUrl) =>
      _novelRepository.getLastReadChapter(novelUrl);

  /// 获取小说的AI伴读设置
  Future<AiAccompanimentSettings> getAiAccompanimentSettings(String novelUrl) =>
      _novelRepository.getAiAccompanimentSettings(novelUrl);

  /// 更新小说的AI伴读设置
  Future<int> updateAiAccompanimentSettings(
          String novelUrl, AiAccompanimentSettings settings) =>
      _novelRepository.updateAiAccompanimentSettings(novelUrl, settings);

  // ========== 章节操作 (委托给 ChapterRepository) ==========

  /// 检查章节是否已缓存
  Future<bool> isChapterCached(String chapterUrl) =>
      _chapterRepository.isChapterCached(chapterUrl);

  /// 批量检查缓存状态
  Future<List<String>> filterUncachedChapters(List<String> chapterUrls) =>
      _chapterRepository.filterUncachedChapters(chapterUrls);

  /// 批量查询章节缓存状态
  Future<Map<String, bool>> getChaptersCacheStatus(List<String> chapterUrls) =>
      _chapterRepository.getChaptersCacheStatus(chapterUrls);

  /// 标记章节正在预加载
  void markAsPreloading(String chapterUrl) =>
      _chapterRepository.markAsPreloading(chapterUrl);

  /// 检查章节是否正在预加载
  bool isPreloading(String chapterUrl) =>
      _chapterRepository.isPreloading(chapterUrl);

  /// 清理内存状态
  void clearMemoryState() => _chapterRepository.clearMemoryState();

  /// 缓存章节内容
  Future<int> cacheChapter(String novelUrl, Chapter chapter, String content) =>
      _chapterRepository.cacheChapter(novelUrl, chapter, content);

  /// 更新章节内容
  Future<int> updateChapterContent(String chapterUrl, String content) =>
      _chapterRepository.updateChapterContent(chapterUrl, content);

  /// 删除章节缓存
  Future<int> deleteChapterCache(String chapterUrl) =>
      _chapterRepository.deleteChapterCache(chapterUrl);

  /// 获取缓存的章节内容
  Future<String?> getCachedChapter(String chapterUrl) =>
      _chapterRepository.getCachedChapter(chapterUrl);

  /// 获取章节内容(别名方法,兼容旧代码)
  Future<String?> getChapterContent(String chapterUrl) =>
      getCachedChapter(chapterUrl);

  /// 获取小说的所有缓存章节
  Future<List<Chapter>> getCachedChapters(String novelUrl) =>
      _chapterRepository.getCachedChapters(novelUrl);

  /// 删除小说的所有缓存章节
  Future<int> deleteCachedChapters(String novelUrl) =>
      _chapterRepository.deleteCachedChapters(novelUrl);

  /// 清除单个小说的缓存(别名方法,兼容旧测试)
  Future<void> clearNovelCache(String novelUrl) async {
    await deleteCachedChapters(novelUrl);
  }

  /// 标记章节为已读
  Future<void> markChapterAsRead(String novelUrl, String chapterUrl) =>
      _chapterRepository.markChapterAsRead(novelUrl, chapterUrl);

  /// 获取已缓存的章节数量
  Future<int> getCachedChaptersCount(String novelUrl) =>
      _chapterRepository.getCachedChaptersCount(novelUrl);

  /// 检查章节是否已伴读
  Future<bool> isChapterAccompanied(String novelUrl, String chapterUrl) =>
      _chapterRepository.isChapterAccompanied(novelUrl, chapterUrl);

  /// 标记章节为已伴读
  Future<void> markChapterAsAccompanied(String novelUrl, String chapterUrl) =>
      _chapterRepository.markChapterAsAccompanied(novelUrl, chapterUrl);

  /// 重置章节伴读标记
  Future<void> resetChapterAccompaniedFlag(
          String novelUrl, String chapterUrl) =>
      _chapterRepository.resetChapterAccompaniedFlag(novelUrl, chapterUrl);

  /// 缓存小说章节列表
  Future<void> cacheNovelChapters(String novelUrl, List<Chapter> chapters) =>
      _chapterRepository.cacheNovelChapters(novelUrl, chapters);

  /// 获取缓存的章节列表
  Future<List<Chapter>> getCachedNovelChapters(String novelUrl) =>
      _chapterRepository.getCachedNovelChapters(novelUrl);

  /// 获取章节列表(别名方法,兼容旧测试)
  Future<List<Chapter>> getChapters(String novelUrl) =>
      getCachedNovelChapters(novelUrl);

  /// 更新章节顺序
  ///
  /// 根据提供的章节列表顺序更新数据库中的章节索引
  Future<void> updateChaptersOrder(
      String novelUrl, List<Chapter> chapters) async {
    final db = await database;

    // 使用事务批量更新章节索引
    await db.transaction((txn) async {
      for (var i = 0; i < chapters.length; i++) {
        await txn.update(
          'novel_chapters',
          {'chapterIndex': i},
          where: 'novelUrl = ? AND chapterUrl = ?',
          whereArgs: [novelUrl, chapters[i].url],
        );
      }
    });
  }

  /// 判断是否为本地章节
  static bool isLocalChapter(String chapterUrl) =>
      ChapterRepository.isLocalChapter(chapterUrl);

  /// 创建用户自定义章节
  Future<int> createCustomChapter(String novelUrl, String title, String content,
          [int? index]) =>
      _chapterRepository.createCustomChapter(novelUrl, title, content, index);

  /// 插入用户自定义章节(别名方法,兼容旧测试)
  Future<int> insertUserChapter(String novelUrl, String title, String content,
          [int? index]) =>
      createCustomChapter(novelUrl, title, content, index);

  /// 更新用户创建的章节内容
  Future<void> updateCustomChapter(
          String chapterUrl, String title, String content) =>
      _chapterRepository.updateCustomChapter(chapterUrl, title, content);

  /// 删除用户创建的章节
  Future<void> deleteCustomChapter(String chapterUrl) =>
      _chapterRepository.deleteCustomChapter(chapterUrl);

  /// 删除用户自定义章节(别名方法,兼容旧代码)
  Future<void> deleteUserChapter(String chapterUrl) =>
      deleteCustomChapter(chapterUrl);

  /// 清除所有缓存数据(保留书架数据)
  ///
  /// 清理以下表:
  /// - chapter_cache: 章节内容缓存
  /// - novel_chapters: 章节列表元数据
  ///
  /// 保留以下表:
  /// - bookshelf: 书架数据(小说元数据)
  Future<void> clearAllCache() async {
    final db = await database;

    // 清理章节内容缓存
    await db.delete('chapter_cache');

    // 清理章节列表元数据
    await db.delete('novel_chapters');
  }

  // ========== 角色操作 (委托给 CharacterRepository) ==========

  /// 创建角色
  Future<int> createCharacter(Character character) =>
      _characterRepository.createCharacter(character);

  /// 获取小说的所有角色
  Future<List<Character>> getCharacters(String novelUrl) =>
      _characterRepository.getCharacters(novelUrl);

  /// 根据ID获取角色
  Future<Character?> getCharacter(int id) =>
      _characterRepository.getCharacter(id);

  /// 更新角色
  Future<int> updateCharacter(Character character) =>
      _characterRepository.updateCharacter(character);

  /// 删除角色
  Future<int> deleteCharacter(int id) =>
      _characterRepository.deleteCharacter(id);

  /// 根据名称查找角色
  Future<Character?> findCharacterByName(String novelUrl, String name) =>
      _characterRepository.findCharacterByName(novelUrl, name);

  /// 更新或插入角色
  Future<Character> updateOrInsertCharacter(Character newCharacter) =>
      _characterRepository.updateOrInsertCharacter(newCharacter);

  /// 批量更新角色
  Future<List<Character>> batchUpdateCharacters(
          List<Character> newCharacters) =>
      _characterRepository.batchUpdateCharacters(newCharacters);

  /// 获取小说的所有角色名称
  Future<List<String>> getCharacterNames(String novelUrl) =>
      _characterRepository.getCharacterNames(novelUrl);

  /// 检查角色是否存在
  Future<bool> characterExists(int id) =>
      _characterRepository.characterExists(id);

  /// 根据ID列表获取多个角色
  Future<List<Character>> getCharactersByIds(List<int> ids) =>
      _characterRepository.getCharactersByIds(ids);

  /// 删除小说的所有角色
  Future<int> deleteAllCharacters(String novelUrl) =>
      _characterRepository.deleteAllCharacters(novelUrl);

  /// 更新角色的缓存图片URL
  Future<int> updateCharacterCachedImage(int characterId, String? imageUrl) =>
      _characterRepository.updateCharacterCachedImage(characterId, imageUrl);

  /// 清除角色的缓存图片URL
  Future<int> clearCharacterCachedImage(int characterId) =>
      _characterRepository.clearCharacterCachedImage(characterId);

  /// 批量清除角色的缓存图片URL
  Future<int> clearAllCharacterCachedImages(String novelUrl) =>
      _characterRepository.clearAllCharacterCachedImages(novelUrl);

  /// 获取角色的缓存图片URL
  Future<String?> getCharacterCachedImage(int characterId) =>
      _characterRepository.getCharacterCachedImage(characterId);

  /// 更新角色头像信息
  Future<int> updateCharacterAvatar(
    int characterId, {
    String? imageUrl,
    String? originalFilename,
    String? originalImageUrl,
  }) =>
      _characterRepository.updateCharacterAvatar(
        characterId,
        imageUrl: imageUrl,
        originalFilename: originalFilename,
        originalImageUrl: originalImageUrl,
      );

  /// 检查角色是否有头像缓存
  Future<bool> hasCharacterAvatar(int characterId) =>
      _characterRepository.hasCharacterAvatar(characterId);

  /// 批量更新或插入角色（用于AI伴读）
  Future<int> batchUpdateOrInsertCharacters(
          String novelUrl, List<AICompanionRole> aiRoles) =>
      _characterRepository.batchUpdateOrInsertCharacters(novelUrl, aiRoles);

  // ========== 角色关系操作 (委托给 CharacterRelationRepository) ==========

  /// 创建角色关系
  Future<int> createRelationship(CharacterRelationship relationship) =>
      _characterRelationRepository.createRelationship(relationship);

  /// 获取角色的所有关系
  Future<List<CharacterRelationship>> getRelationships(int characterId) =>
      _characterRelationRepository.getRelationships(characterId);

  /// 获取角色的出度关系
  Future<List<CharacterRelationship>> getOutgoingRelationships(
          int characterId) =>
      _characterRelationRepository.getOutgoingRelationships(characterId);

  /// 获取角色的入度关系
  Future<List<CharacterRelationship>> getIncomingRelationships(
          int characterId) =>
      _characterRelationRepository.getIncomingRelationships(characterId);

  /// 更新角色关系
  Future<int> updateRelationship(CharacterRelationship relationship) =>
      _characterRelationRepository.updateRelationship(relationship);

  /// 删除角色关系
  Future<int> deleteRelationship(int relationshipId) =>
      _characterRelationRepository.deleteRelationship(relationshipId);

  /// 检查关系是否已存在
  Future<bool> relationshipExists(int sourceId, int targetId, String type) =>
      _characterRelationRepository.relationshipExists(sourceId, targetId, type);

  /// 获取角色的关系数量
  Future<int> getRelationshipCount(int characterId) =>
      _characterRelationRepository.getRelationshipCount(characterId);

  /// 获取与某角色相关的所有角色
  Future<List<int>> getRelatedCharacterIds(int characterId) =>
      _characterRelationRepository.getRelatedCharacterIds(characterId);

  /// 获取小说的所有关系
  Future<List<CharacterRelationship>> getAllRelationships(String novelUrl) =>
      _characterRelationRepository.getAllRelationships(novelUrl);

  /// 根据source和target角色ID获取关系
  Future<List<CharacterRelationship>> getRelationshipsByCharacterIds(
          int sourceId, int targetId) =>
      _characterRelationRepository.getRelationshipsByCharacterIds(
          sourceId, targetId);

  /// 批量更新或插入关系（用于AI伴读）
  Future<int> batchUpdateOrInsertRelationships(
          String novelUrl, List<AICompanionRelation> aiRelations) =>
      _characterRelationRepository.batchUpdateOrInsertRelationships(
          novelUrl, aiRelations, _characterRepository.getCharacters);

  // ========== 场景插图操作 (委托给 IllustrationRepository) ==========

  /// 插入场景插图记录
  Future<int> insertSceneIllustration(SceneIllustration illustration) =>
      _illustrationRepository.insertSceneIllustration(illustration);

  /// 更新场景插图状态
  Future<int> updateSceneIllustrationStatus(
    int id,
    String status, {
    List<String>? images,
    String? prompts,
  }) =>
      _illustrationRepository.updateSceneIllustrationStatus(
        id,
        status,
        images: images,
        prompts: prompts,
      );

  /// 删除场景插图记录
  Future<int> deleteSceneIllustration(int id) =>
      _illustrationRepository.deleteSceneIllustration(id);

  /// 删除章节的所有场景插图
  Future<int> deleteSceneIllustrationsByChapter(
          String novelUrl, String chapterId) =>
      _illustrationRepository.deleteSceneIllustrationsByChapter(
          novelUrl, chapterId);

  /// 根据小说和章节获取场景插图列表
  Future<List<SceneIllustration>> getSceneIllustrationsByChapter(
          String novelUrl, String chapterId) =>
      _illustrationRepository.getSceneIllustrationsByChapter(
          novelUrl, chapterId);

  /// 根据taskId获取场景插图
  Future<SceneIllustration?> getSceneIllustrationByTaskId(String taskId) =>
      _illustrationRepository.getSceneIllustrationByTaskId(taskId);

  /// 获取分页的场景插图列表
  Future<Map<String, dynamic>> getSceneIllustrationsPaginated({
    required int page,
    required int limit,
  }) =>
      _illustrationRepository.getSceneIllustrationsPaginated(
          page: page, limit: limit);

  /// 获取所有待处理或正在处理的场景插图
  Future<List<SceneIllustration>> getPendingSceneIllustrations() =>
      _illustrationRepository.getPendingSceneIllustrations();

  /// 批量更新场景插图状态
  Future<int> batchUpdateSceneIllustrations(List<int> ids, String status) =>
      _illustrationRepository.batchUpdateSceneIllustrations(ids, status);

  /// 获取指定小说的插图总数
  Future<int> getIllustrationCount(String novelUrl) =>
      _illustrationRepository.getIllustrationCount(novelUrl);

  /// 获取指定章节的已完成插图数量
  Future<int> getCompletedIllustrationCount(
          String novelUrl, String chapterId) =>
      _illustrationRepository.getCompletedIllustrationCount(
          novelUrl, chapterId);

  /// 检查任务ID是否已存在
  Future<bool> taskExists(String taskId) =>
      _illustrationRepository.taskExists(taskId);

  // ========== 大纲操作 (委托给 OutlineRepository) ==========

  /// 创建或更新大纲
  Future<int> saveOutline(Outline outline) =>
      _outlineRepository.saveOutline(outline);

  /// 根据小说URL获取大纲
  Future<Outline?> getOutlineByNovelUrl(String novelUrl) =>
      _outlineRepository.getOutlineByNovelUrl(novelUrl);

  /// 获取所有大纲
  Future<List<Outline>> getAllOutlines() => _outlineRepository.getAllOutlines();

  /// 删除大纲
  Future<int> deleteOutline(String novelUrl) =>
      _outlineRepository.deleteOutline(novelUrl);

  /// 更新大纲内容
  Future<int> updateOutlineContent(
          String novelUrl, String title, String content) =>
      _outlineRepository.updateOutlineContent(novelUrl, title, content);

  // ========== 聊天场景操作 (委托给 ChatSceneRepository) ==========

  /// 插入新的聊天场景
  Future<int> insertChatScene(ChatScene scene) =>
      _chatSceneRepository.insertChatScene(scene);

  /// 更新聊天场景
  Future<void> updateChatScene(ChatScene scene) =>
      _chatSceneRepository.updateChatScene(scene);

  /// 删除聊天场景
  Future<void> deleteChatScene(int id) =>
      _chatSceneRepository.deleteChatScene(id);

  /// 获取所有聊天场景
  Future<List<ChatScene>> getAllChatScenes() =>
      _chatSceneRepository.getAllChatScenes();

  /// 根据ID获取聊天场景
  Future<ChatScene?> getChatSceneById(int id) =>
      _chatSceneRepository.getChatSceneById(id);

  /// 搜索聊天场景（按标题）
  Future<List<ChatScene>> searchChatScenes(String query) =>
      _chatSceneRepository.searchChatScenes(query);

  // ========== 书架分类操作 (委托给 BookshelfRepository) ==========

  /// 获取所有书架列表
  Future<List<Bookshelf>> getBookshelves() =>
      _bookshelfRepository.getBookshelves();

  /// 创建新书架
  Future<int> createBookshelf(String name) =>
      _bookshelfRepository.createBookshelf(name);

  /// 删除书架
  Future<bool> deleteBookshelf(int bookshelfId) =>
      _bookshelfRepository.deleteBookshelf(bookshelfId);

  /// 获取指定书架中的小说列表
  Future<List<Novel>> getNovelsByBookshelf(int bookshelfId) =>
      _bookshelfRepository.getNovelsByBookshelf(bookshelfId);

  /// 添加小说到指定书架
  Future<void> addNovelToBookshelf(String novelUrl, int bookshelfId) =>
      _bookshelfRepository.addNovelToBookshelf(novelUrl, bookshelfId);

  /// 从指定书架移除小说
  Future<bool> removeNovelFromBookshelf(String novelUrl, int bookshelfId) =>
      _bookshelfRepository.removeNovelFromBookshelf(novelUrl, bookshelfId);

  /// 将小说从一个书架移动到另一个书架
  Future<void> moveNovelToBookshelf(
          String novelUrl, int fromBookshelfId, int toBookshelfId) =>
      _bookshelfRepository.moveNovelToBookshelf(
          novelUrl, fromBookshelfId, toBookshelfId);

  /// 获取小说所属的所有书架
  Future<List<int>> getBookshelvesByNovel(String novelUrl) =>
      _bookshelfRepository.getBookshelvesByNovel(novelUrl);

  /// 获取书架中的小说数量
  Future<int> getNovelCountByBookshelf(int bookshelfId) =>
      _bookshelfRepository.getNovelCountByBookshelf(bookshelfId);

  /// 检查小说是否在指定书架中
  Future<bool> isNovelInBookshelf(String novelUrl, int bookshelfId) =>
      _bookshelfRepository.isNovelInBookshelf(novelUrl, bookshelfId);

  /// 更新书架排序顺序
  Future<void> reorderBookshelves(List<int> bookshelfIds) =>
      _bookshelfRepository.reorderBookshelves(bookshelfIds);

  /// 更新书架信息
  Future<int> updateBookshelf(Bookshelf bookshelf) =>
      _bookshelfRepository.updateBookshelf(bookshelf);

  // ========== 缓存搜索操作 ==========

  /// 在缓存内容中搜索关键字
  Future<List<ChapterSearchResult>> searchInCachedContent(
    String keyword, {
    String? novelUrl,
  }) async {
    // TODO: 实现缓存内容搜索功能
    // 这个方法应该在ChapterRepository中实现
    // 目前返回空列表以避免编译错误
    return [];
  }

  /// 获取已缓存小说列表
  Future<List<CachedNovelInfo>> getCachedNovels() async {
    // TODO: 实现获取已缓存小说列表功能
    // 这个方法应该在ChapterRepository中实现
    // 目前返回空列表以避免编译错误
    return [];
  }
}
