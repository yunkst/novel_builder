import 'package:flutter/foundation.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:sqflite_common/sqlite_api.dart';
import '../test_bootstrap.dart';

/// TestDatabase - 测试数据库辅助类
///
/// 提供隔离的测试数据库环境，使用内存数据库(:memory:)模式
/// 确保测试之间的完全隔离和快速执行
///
/// 使用示例：
/// ```dart
/// void main() {
///   late TestDatabase testDb;
///
///   setUp(() async {
///     testDb = TestDatabase();
///     await testDb.initialize();
///   });
///
///   test('示例测试', () async {
///     await testDb.runInTransaction((txn) async {
///       // 测试代码
///     });
///   });
/// }
/// ```
class TestDatabase {
  /// 数据库服务实例
  DatabaseService? _databaseService;

  /// 底层数据库实例（用于高级操作）
  Database? _db;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 初始化测试数据库（内存模式）
  ///
  /// 返回 DatabaseService 实例用于测试
  Future<DatabaseService> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️  TestDatabase 已经初始化，跳过重复初始化');
      return _databaseService!;
    }

    // 初始化测试环境
    initDatabaseTests();

    // 创建数据库服务实例（会使用 :memory: 数据库）
    _databaseService = DatabaseService();

    // 获取底层数据库实例
    _db = await _databaseService!.database;

    _isInitialized = true;

    debugPrint('✅ TestDatabase 初始化完成 (:memory: 模式)');
    return _databaseService!;
  }

  /// 获取 DatabaseService 实例
  DatabaseService get databaseService {
    if (!_isInitialized || _databaseService == null) {
      throw StateError('TestDatabase 未初始化，请先调用 initialize()');
    }
    return _databaseService!;
  }

  /// 获取底层数据库实例
  Future<Database> get db async {
    if (!_isInitialized) {
      throw StateError('TestDatabase 未初始化，请先调用 initialize()');
    }
    return _db ?? await _databaseService!.database;
  }

  /// 清理所有测试数据
  ///
  /// 删除所有表中的数据，但保留表结构
  Future<void> cleanup() async {
    if (!_isInitialized) {
      throw StateError('TestDatabase 未初始化');
    }

    final database = await db;

    // 需要清理的表列表
    final tables = [
      'bookshelf',
      'bookshelves',
      'novel_bookshelves',
      'chapter_cache',
      'novel_chapters',
      'characters',
      'scene_illustrations',
      'character_relationships',
      'outlines',
      'chat_scenes',
      'reading_chapter_log',
      'chapter_ai_accompaniment',
    ];

    for (final table in tables) {
      try {
        await database.delete(table);
      } catch (e) {
        // 表不存在或其他错误，忽略
        debugPrint('清理表 $table 时出错: $e');
      }
    }

    debugPrint('✅ TestDatabase 清理完成');
  }

  /// 在事务中执行测试（自动回滚）
  ///
  /// 这对于需要测试数据库操作但不希望保留数据的场景非常有用
  /// 事务会在 callback 执行完成后自动回滚，确保测试隔离
  ///
  /// 使用示例：
  /// ```dart
  /// await testDb.runInTransaction((txn) async {
  ///   await txn.insert('bookshelf', {'url': 'test', 'title': 'Test'});
  ///   // 即使这里抛出异常，事务也会回滚
  /// });
  /// ```
  Future<T> runInTransaction<T>(Future<T> Function(Transaction txn) callback) async {
    if (!_isInitialized) {
      throw StateError('TestDatabase 未初始化');
    }

    final database = await db;

    return database.transaction<T>((txn) async {
      try {
        return await callback(txn);
      } catch (e) {
        // 发生错误时回滚事务
        debugPrint('❌ 事务执行失败，已回滚: $e');
        rethrow;
      }
    });
  }

  /// 验证数据库状态
  ///
  /// 检查指定表中的行数是否符合预期
  /// 如果不符合，测试会失败
  ///
  /// 使用示例：
  /// ```dart
  /// await testDb.expectTableCount('bookshelf', 1); // 期望 bookshelf 表有1行数据
  /// ```
  Future<void> expectTableCount(String table, int expected) async {
    final database = await db;

    try {
      final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM $table',
      );

      final count = Sqflite.firstIntValue(result);
      if (count != expected) {
        throw TestFailure(
          '表 $table 的行数不符合预期\n'
          '期望: $expected\n'
          '实际: $count',
        );
      }

      debugPrint('✅ 表 $table 行数验证通过: $count');
    } catch (e) {
      if (e is TestFailure) {
        rethrow;
      }
      throw TestFailure('验证表 $table 行数时出错: $e');
    }
  }

  /// 检查表中是否存在指定条件的数据
  ///
  /// 使用示例：
  /// ```dart
  /// final exists = await testDb.rowExists(
  ///   'bookshelf',
  ///   where: 'url = ?',
  ///   whereArgs: ['test-url'],
  /// );
  /// expect(exists, isTrue);
  /// ```
  Future<bool> rowExists(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final database = await db;

    try {
      final result = await database.query(
        table,
        where: where,
        whereArgs: whereArgs,
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      debugPrint('检查表 $table 数据存在性时出错: $e');
      return false;
    }
  }

  /// 关闭数据库连接
  ///
  /// 在测试结束时调用，释放资源
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }

    _databaseService = null;
    _isInitialized = false;

    debugPrint('✅ TestDatabase 已关闭');
  }

  /// 重置数据库（删除所有数据并重新初始化）
  ///
  /// 这等同于调用 cleanup()，但更明确地表达了重置的意图
  Future<void> reset() async {
    await cleanup();
  }
}
