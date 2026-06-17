import 'package:sqflite/sqflite.dart';
import '../../services/logger_service.dart';

/// 数据库迁移逻辑单例
///
/// 职责：
/// - 提供 v1 基础表创建逻辑
/// - 提供 v1 → v21 完整迁移逻辑
/// - 两个逻辑均由 DatabaseConnection 和 TestDatabaseSetup 共享调用
///
/// 设计原则：单一数据源，避免迁移逻辑重复维护
class DatabaseMigrations {
  /// 当前数据库版本
  static const int currentVersion = 27;

  /// ========== v1 基础表创建 ==========
  /// 新安装时调用，与 _onUpgrade(1) 共同构建完整数据库

  /// 创建 v1 基础表
  ///
  /// 仅创建最早版本的核心字段，不含后续迁移添加的字段。
  /// 创建完成后会调用 [upgradeFromV1] 将数据库升级到最新版本。
  static Future<void> createV1Tables(Database db) async {
    // 小说表（v1，包含完整字段）
    // lastReadChapter/lastReadTime 用于阅读进度追踪
    // aiAccompanimentEnabled/aiInfoNotificationEnabled 用于AI伴读设置
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

    // 章节缓存表（v1，最小字段集）
    // isAccompanied 字段在 v18 迁移中添加
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

    // 小说章节列表缓存表（v1，最小字段集）
    // isUserInserted/insertedAt 在 v2 添加
    // isAccompanied/readAt 在 v18 添加
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

    // 人物表（v1，无扩展字段）
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
      UNIQUE(novelUrl, name)
    )
  ''');

    // 场景插图表（v1，有 task_id）
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

    // 索引（v1）
    await db.execute('''
    CREATE INDEX idx_chapter_cache_chapter_url ON chapter_cache(chapterUrl)
  ''');
    await db.execute('''
    CREATE INDEX idx_chapter_cache_novel_url ON chapter_cache(novelUrl)
  ''');
    await db.execute('''
    CREATE INDEX idx_novel_chapters_novel_url ON novel_chapters(novelUrl)
  ''');

    _log('v1 基础表创建完成');
  }

  /// ========== 数据库升级逻辑 ==========
  /// 从指定版本升级到 [toVersion]

  /// 执行数据库升级
  ///
  /// 核心方法：执行从 [fromVersion] 到 [toVersion] 的所有迁移。
  /// 入口：
  /// - 新安装：fromVersion=1
  /// - 版本升级：由 sqflite 的 onUpgrade 回调传入
  static Future<void> upgrade(
      Database db, int fromVersion, int toVersion) async {
    final startTime = DateTime.now();

    // 执行每个版本的迁移
    for (int version = fromVersion + 1; version <= toVersion; version++) {
      await _migrateToVersion(db, version);
    }

    final duration = DateTime.now().difference(startTime);
    _log('数据库升级成功: v$fromVersion → v$toVersion, 耗时${duration.inMilliseconds}ms');
  }

  /// 升级到指定版本
  ///
  /// 每个版本一个迁移块，版本号对应数据库 schema 版本。
  /// 迁移使用 `IF NOT EXISTS` / `IF NOT EXISTS` 等安全写法，
  /// 确保在已有表/字段时不报错。
  static Future<void> _migrateToVersion(Database db, int version) async {
    switch (version) {
      // ========== 版本 2：用户插入章节标记 ==========
      case 2:
        await _addColumnIfNotExists(
            db, 'novel_chapters', 'isUserInserted', 'INTEGER DEFAULT 0');
        await _addColumnIfNotExists(
            db, 'novel_chapters', 'insertedAt', 'INTEGER');
        break;

      // ========== 版本 3：背景设定字段（v1 已包含，此迁移安全跳过）==========
      case 3:
        await _addColumnIfNotExists(
            db, 'bookshelf', 'backgroundSetting', 'TEXT');
        break;

      // ========== 版本 4：人物表（重建，带完整字段） ==========
      case 4:
        await db.execute('''
        CREATE TABLE IF NOT EXISTS characters (
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
        // Bug fix: IF NOT EXISTS 不会给 v1 已存在的 characters 表加 updatedAt
        // 必须用 ALTER TABLE 显式补列（已有表走 _addColumnIfNotExists 分支）
        await _addColumnIfNotExists(db, 'characters', 'updatedAt', 'INTEGER');
        break;

      // ========== 版本 5：提示词字段 ==========
      case 5:
        await _addColumnIfNotExists(
            db, 'characters', 'facePrompts', 'TEXT');
        await _addColumnIfNotExists(
            db, 'characters', 'bodyPrompts', 'TEXT');
        break;

      // ========== 版本 6：缓存图片URL ==========
      case 6:
        await _addColumnIfNotExists(
            db, 'characters', 'cachedImageUrl', 'TEXT');
        break;

      // ========== 版本 7：场景插图表 ==========
      case 7:
        await db.execute('''
        CREATE TABLE IF NOT EXISTS scene_illustrations (
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
        break;

      // ========== 版本 8：修复场景插图表（添加 task_id） ==========
      case 8:
        final tableInfo =
            await db.rawQuery("PRAGMA table_info(scene_illustrations)");
        final hasTaskId =
            tableInfo.any((column) => column['name'] == 'task_id');

        if (!hasTaskId) {
          await db.query('scene_illustrations');
          await db.execute('DROP TABLE IF EXISTS scene_illustrations');
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
          _log('数据库 v8: 重新创建 scene_illustrations 表，添加 task_id 字段');
        }
        break;

      // ========== 版本 9：大纲表 ==========
      case 9:
        await db.execute('''
        CREATE TABLE IF NOT EXISTS outlines (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          novel_url TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
        break;

      // ========== 版本 10：聊天场景表 ==========
      case 10:
        await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_scenes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER
        )
      ''');
        await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_chat_scenes_title ON chat_scenes(title)
      ''');
        break;

      // ========== 版本 11：章节已读时间戳 ==========
      case 11:
        await _addColumnIfNotExists(
            db, 'novel_chapters', 'readAt', 'INTEGER');
        break;

      // ========== 版本 12：角色别名字段 ==========
      case 12:
        await _addColumnIfNotExists(
            db, 'characters', 'aliases', "TEXT DEFAULT '[]'");
        break;

      // ========== 版本 13：角色关系表 ==========
      case 13:
        await db.execute('''
        CREATE TABLE IF NOT EXISTS character_relationships (
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
        await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_relationships_source ON character_relationships(source_character_id)
      ''');
        await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_relationships_target ON character_relationships(target_character_id)
      ''');
        break;

      // ========== 版本 14：AI伴读设置 ==========
      case 14:
        await _addColumnIfNotExists(
            db, 'bookshelf', 'aiAccompanimentEnabled', 'INTEGER DEFAULT 0');
        await _addColumnIfNotExists(
            db, 'bookshelf', 'aiInfoNotificationEnabled', 'INTEGER DEFAULT 0');
        break;

      // ========== 版本 15：章节伴读标记 ==========
      case 15:
        await _addColumnIfNotExists(
            db, 'chapter_cache', 'ai_accompanied', 'INTEGER DEFAULT 0');
        break;

      // ========== 版本 16：多书架功能 ==========
      case 16:
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
        await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_novel_bookshelf_url ON novel_bookshelves(novel_url)
      ''');
        await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_bookshelf_id ON novel_bookshelves(bookshelf_id)
      ''');
        await db.execute('''
        INSERT OR IGNORE INTO bookshelves (id, name, created_at, sort_order, is_system)
        VALUES
          (1, '全部小说', strftime('%s', 'now'), 0, 1),
          (2, '我的收藏', strftime('%s', 'now'), 1, 1)
      ''');
        // 仅在 novel_bookshelves 为空时迁移现有书籍到"我的收藏"
        // 避免重复执行时覆盖用户手动移除的关联
        final existingLinks = await db.rawQuery(
            'SELECT COUNT(*) as count FROM novel_bookshelves');
        final linkCount = existingLinks.first['count'] as int? ?? 0;
        if (linkCount == 0) {
          await db.execute('''
          INSERT OR IGNORE INTO novel_bookshelves (novel_url, bookshelf_id, created_at)
          SELECT url, 2, strftime('%s', 'now')
          FROM bookshelf
          WHERE url IS NOT NULL
        ''');
        }
        break;

      // ========== 版本 17：修复人物表字段 ==========
      case 17:
        await _addColumnIfNotExists(
            db, 'characters', 'facePrompts', 'TEXT');
        await _addColumnIfNotExists(
            db, 'characters', 'bodyPrompts', 'TEXT');
        await _addColumnIfNotExists(
            db, 'characters', 'cachedImageUrl', 'TEXT');
        break;

      // ========== 版本 18：AI伴读标记字段标准化 ==========
      case 18:
        await _addColumnIfNotExists(
            db, 'chapter_cache', 'isAccompanied', 'INTEGER DEFAULT 0');
        await _addColumnIfNotExists(
            db, 'novel_chapters', 'isAccompanied', 'INTEGER DEFAULT 0');
        break;

      // ========== 版本 19：字段重命名 ai_accompanied → isAccompanied ==========
      case 19:
        await _renameColumnIfExists(
          db,
          'chapter_cache',
          'ai_accompanied',
          'isAccompanied',
          'INTEGER DEFAULT 0',
        );
        await _renameColumnIfExists(
          db,
          'novel_chapters',
          'ai_accompanied',
          'isAccompanied',
          'INTEGER DEFAULT 0',
        );
        break;

      // ========== 版本 20：novels 视图 ==========
      case 20:
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
        break;

      // ========== 版本 21：性能优化索引 ==========
      case 21:
        await _createIndexIfNotExists(
            db, 'idx_chapter_cache_chapter_url', 'chapter_cache', 'chapterUrl');
        await _createIndexIfNotExists(
            db, 'idx_chapter_cache_novel_url', 'chapter_cache', 'novelUrl');
        await _createIndexIfNotExists(
            db, 'idx_novel_chapters_novel_url', 'novel_chapters', 'novelUrl');
        await _createIndexIfNotExists(
            db, 'idx_novel_chapters_chapter_url', 'novel_chapters', 'chapterUrl');
        break;

      // ========== 版本 22：用户提示词历史记录表 ==========
      case 22:
        await db.execute('''
        CREATE TABLE IF NOT EXISTS prompt_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          prompt_text TEXT NOT NULL UNIQUE,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          tag_group_ids TEXT
        )
      ''');
        await _createIndexIfNotExists(
            db, 'idx_prompt_history_updated_at', 'prompt_history', 'updated_at');
        break;

      // ========== 版本 23：提示词标签分类 + 标签表 ==========
      case 23:
        await db.execute('''
        CREATE TABLE IF NOT EXISTS prompt_tag_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
        await db.execute('''
        CREATE TABLE IF NOT EXISTS prompt_tags (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          prompt_text TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
        await _createIndexIfNotExists(
            db, 'idx_prompt_tags_category_id', 'prompt_tags', 'category_id');
        break;

      // ========== 版本 24：移除 prompt_tags 的 UNIQUE(category_id, name) 约束 ==========
      case 24:
        // SQLite 不支持直接删除约束，需要重建表
        await db.execute('''
        CREATE TABLE prompt_tags_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          prompt_text TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
        await db.execute('''
        INSERT INTO prompt_tags_new (id, category_id, name, prompt_text, sort_order, created_at, updated_at)
        SELECT id, category_id, name, prompt_text, sort_order, created_at, updated_at
        FROM prompt_tags
      ''');
        await db.execute('DROP TABLE prompt_tags');
        await db.execute('ALTER TABLE prompt_tags_new RENAME TO prompt_tags');
        await _createIndexIfNotExists(
            db, 'idx_prompt_tags_category_id', 'prompt_tags', 'category_id');
        break;

      // ========== 版本 25：站点提取脚本表 ==========
      case 25:
        await db.execute('''
        CREATE TABLE IF NOT EXISTS site_scripts (
          id TEXT PRIMARY KEY,
          domain TEXT NOT NULL,
          url_pattern TEXT NOT NULL DEFAULT '',
          chapter_list_js TEXT NOT NULL,
          chapter_content_js TEXT NOT NULL,
          sample_url TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL,
          last_used_at INTEGER NOT NULL,
          use_count INTEGER NOT NULL DEFAULT 0,
          verified INTEGER NOT NULL DEFAULT 0
        )
      ''');
        await _createIndexIfNotExists(
            db, 'idx_site_scripts_domain', 'site_scripts', 'domain');
        break;

      // ========== 版本 26：prompt_history 关联标签快照 ==========
      case 26:
        await _addColumnIfNotExists(
            db, 'prompt_history', 'tag_group_ids', 'TEXT');
        _log('迁移 v25 → v26: 添加 prompt_history.tag_group_ids 列');
        break;

      // ========== 版本 27：Agent 场景经验记忆表 ==========
      case 27:
        await db.execute('''
        CREATE TABLE IF NOT EXISTS agent_memory (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          scenario_id TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
        await _createIndexIfNotExists(
            db, 'idx_agent_memory_scenario', 'agent_memory', 'scenario_id');
        _log('迁移 v26 → v27: 创建 agent_memory 表');
        break;
    }
  }

  // ========== 辅助方法 ==========

  /// 修复数据库：重新执行 v1→v21 所有迁移
  ///
  /// 非破坏性操作，仅补全缺失的表/列/索引，不会删除现有数据。
  /// 适用于数据库损坏、缺少表或列的修复场景。
  /// 因为所有迁移都是幂等的，可以安全地重复执行。
  static Future<void> repair(Database db) async {
    _log('开始数据库修复（检查并补全缺失的表/列/索引）...');
    await upgrade(db, 1, currentVersion);
    _log('数据库修复完成');
  }

  /// 安全添加列（如果不存在）
  static Future<void> _addColumnIfNotExists(
      Database db, String table, String column, String type) async {
    final columns = await db.rawQuery("PRAGMA table_info($table)");
    final hasColumn = columns.any((c) => c['name'] == column);
    if (!hasColumn) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  /// 安全创建索引（如果不存在）
  static Future<void> _createIndexIfNotExists(
      Database db, String indexName, String table, String column) async {
    final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE '$indexName'");
    if (indexes.isEmpty) {
      await db.execute(
          'CREATE INDEX $indexName ON $table($column)');
    }
  }

  /// 安全重命名字段（如果旧字段存在且新字段不存在）
  ///
  /// SQLite 不支持直接重命名列，使用重建表的方式实现。
  static Future<void> _renameColumnIfExists(
    Database db,
    String table,
    String oldColumn,
    String newColumn,
    String newColumnType,
  ) async {
    // 检查旧字段是否存在，新字段是否不存在
    final tableInfo = await db.rawQuery("PRAGMA table_info($table)");
    final hasOldColumn = tableInfo.any((c) => c['name'] == oldColumn);
    final hasNewColumn = tableInfo.any((c) => c['name'] == newColumn);

    if (hasOldColumn && !hasNewColumn) {
      // 获取当前表的完整列名列表
      final columns = tableInfo.map((c) => c['name'] as String).toList();

      // 构建新列名列表（替换旧列为新列）
      final newColumns = columns.map((col) {
        if (col == oldColumn) return '$newColumn $newColumnType';
        return col;
      }).toList();

      // 重建表
      final columnList = columns.join(', ');
      final newColumnList = newColumns.join(', ');

      await db.execute('''
        CREATE TABLE ${table}_new (
          $newColumnList
        )
      ''');

      await db.execute('''
        INSERT INTO ${table}_new ($columnList)
        SELECT * FROM $table
      ''');

      await db.execute('DROP TABLE $table');
      await db.execute('ALTER TABLE ${table}_new RENAME TO $table');

      _log('数据库迁移: 重命名 $table.$oldColumn → $newColumn');
    }
  }

  /// 记录日志（统一使用 LoggerService）
  static void _log(String message) {
    try {
      LoggerService.instance.i(
        message,
        category: LogCategory.database,
        tags: ['migration'],
      );
    } catch (_) {
      // LoggerService 未初始化时静默忽略
    }
  }
}
