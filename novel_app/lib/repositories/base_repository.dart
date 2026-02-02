import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Repository基础类
///
/// 提供数据库访问的通用功能和状态管理
abstract class BaseRepository {
  Database? _database;

  /// 设置共享的数据库实例（由 DatabaseService 调用）
  void setSharedDatabase(Database database) {
    _database = database;
  }

  /// 获取数据库实例（由子类实现）
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  /// 初始化数据库（由子类实现）
  Future<Database> initDatabase();

  /// Web平台检查
  bool get isWebPlatform => kIsWeb;

  /// 清理资源
  Future<void> dispose() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
