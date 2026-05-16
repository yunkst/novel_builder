import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../interfaces/i_database_connection.dart';
import '../../services/logger_service.dart';
import 'database_migrations.dart';

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
/// - 迁移逻辑委托给 DatabaseMigrations，保持单一数据源
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
        version: DatabaseMigrations.currentVersion,
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
  /// 新安装时调用：创建 v1 基础表，然后通过 DatabaseMigrations 逐步升级到最新版本。
  /// 这样新安装用户的数据库状态与升级用户完全一致。
  Future<void> _onCreate(Database db, int version) async {
    try {
      await DatabaseMigrations.createV1Tables(db);
      await DatabaseMigrations.upgrade(db, 1, version);

      LoggerService.instance.i(
        '数据库初始化成功，已升级到版本 $version',
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
  /// 委托给 DatabaseMigrations 执行实际迁移逻辑
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      await DatabaseMigrations.upgrade(db, oldVersion, newVersion);
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

  /// 修复数据库：重新执行所有迁移，补全缺失的表/列/索引
  ///
  /// 非破坏性操作，不会删除现有数据。
  /// 适用于数据库损坏、缺少表或列的修复场景。
  Future<void> repairDatabase() async {
    final db = await database;
    await DatabaseMigrations.repair(db);
    LoggerService.instance.i(
      '数据库修复完成',
      category: LogCategory.database,
      tags: ['database', 'repair', 'success'],
    );
  }
}
