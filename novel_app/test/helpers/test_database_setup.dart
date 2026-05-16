import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqflite.dart';
import 'package:novel_app/core/database/database_migrations.dart';

/// 测试数据库设置工具
///
/// 提供内存数据库创建和初始化功能，用于集成测试。
/// 复用 DatabaseMigrations 的迁移逻辑，确保测试数据库结构与生产环境完全一致。
class TestDatabaseSetup {
  static bool _initialized = false;

  /// 初始化测试数据库工厂
  static void init() {
    if (!_initialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _initialized = true;
    }
  }

  /// 创建内存数据库并初始化表结构
  ///
  /// 复用 DatabaseMigrations 的迁移逻辑：
  /// 1. 调用 DatabaseMigrations.createV1Tables(db) 创建 v1 基础表
  /// 2. 调用 DatabaseMigrations.upgrade(db, 1, 21) 执行所有迁移
  /// 确保测试环境与生产环境的数据库结构完全一致。
  static Future<Database> createInMemoryDatabase() async {
    init();

    final db = await openDatabase(
      ':memory:',
      version: DatabaseMigrations.currentVersion,
      singleInstance: false,
    );

    await DatabaseMigrations.createV1Tables(db);
    await DatabaseMigrations.upgrade(db, 1, DatabaseMigrations.currentVersion);

    return db;
  }

  /// 清空所有表数据（保留表结构）
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
      final result =
          await db.rawQuery('SELECT COUNT(*) as count FROM $table');
      stats[table] = result.first['count'] as int? ?? 0;
    }

    return stats;
  }

  /// 验证数据库结构是否完整
  ///
  /// 返回所有缺失的表名列表，如果为空则表示结构完整
  static Future<List<String>> validateSchema(Database db) async {
    final expectedTables = [
      'bookshelf',
      'chapter_cache',
      'novel_chapters',
      'characters',
      'scene_illustrations',
      'outlines',
      'chat_scenes',
      'character_relationships',
      'bookshelves',
      'novel_bookshelves',
    ];

    final existingTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'");
    final existingTableNames =
        existingTables.map((r) => r['name'] as String).toSet();

    return expectedTables
        .where((table) => !existingTableNames.contains(table))
        .toList();
  }
}