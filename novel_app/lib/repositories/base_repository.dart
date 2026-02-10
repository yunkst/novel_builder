import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/interfaces/i_database_connection.dart';

/// Repository基础类
///
/// 提供数据库访问的通用功能和状态管理
/// 通过依赖注入接受IDatabaseConnection实例
abstract class BaseRepository {
  final IDatabaseConnection _dbConnection;

  /// 构造函数 - 接受数据库连接实例
  BaseRepository({required IDatabaseConnection dbConnection})
      : _dbConnection = dbConnection;

  /// 获取数据库实例（从IDatabaseConnection获取）
  Future<Database> get database => _dbConnection.database;

  /// Web平台检查
  bool get isWebPlatform => kIsWeb;
}
