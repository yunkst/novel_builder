/// 站点提取脚本 Repository
///
/// 提供 site_scripts 表的 CRUD 操作。
/// 遵循项目 Repository 模式，继承 BaseRepository。
library;

import '../models/site_script.dart';
import '../services/logger_service.dart';
import 'base_repository.dart';

class SiteScriptRepository extends BaseRepository {
  SiteScriptRepository({required super.dbConnection});

  /// 查询所有脚本（按最后使用时间倒序）
  Future<List<SiteScript>> getAll({int limit = 50}) async {
    try {
      final db = await database;
      final results = await db.query(
        'site_scripts',
        orderBy: 'last_used_at DESC',
        limit: limit,
      );
      return results.map(SiteScript.fromMap).toList();
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '查询所有脚本失败 - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['site_script', 'get_all', 'failed'],
      );
      rethrow;
    }
  }

  /// 按 domain 查询
  Future<SiteScript?> getByDomain(String domain) async {
    try {
      final db = await database;
      final results = await db.query(
        'site_scripts',
        where: 'domain = ?',
        whereArgs: [domain],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return SiteScript.fromMap(results.first);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '按域名查询脚本失败: domain=$domain - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['site_script', 'get_by_domain', 'failed'],
      );
      rethrow;
    }
  }

  /// 按 ID 查询
  Future<SiteScript?> getById(String id) async {
    try {
      final db = await database;
      final results = await db.query(
        'site_scripts',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return SiteScript.fromMap(results.first);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '按ID查询脚本失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['site_script', 'get_by_id', 'failed'],
      );
      rethrow;
    }
  }

  /// 删除脚本
  Future<void> delete(String id) async {
    try {
      final db = await database;
      await db.delete('site_scripts', where: 'id = ?', whereArgs: [id]);
      LoggerService.instance.i(
        '删除脚本: id=$id',
        category: LogCategory.database,
        tags: ['site_script', 'delete', 'success'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除脚本失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['site_script', 'delete', 'failed'],
      );
      rethrow;
    }
  }

  /// 按 domain 删除
  Future<void> deleteByDomain(String domain) async {
    try {
      final db = await database;
      await db.delete('site_scripts', where: 'domain = ?', whereArgs: [domain]);
      LoggerService.instance.i(
        '删除域名所有脚本: domain=$domain',
        category: LogCategory.database,
        tags: ['site_script', 'delete_by_domain', 'success'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除域名脚本失败: domain=$domain - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['site_script', 'delete_by_domain', 'failed'],
      );
      rethrow;
    }
  }

  /// 更新 verified 状态
  ///
  /// 重要事件：setVerified(false) 意味着脚本被自动禁用
  Future<void> setVerified(String id, bool verified) async {
    try {
      final db = await database;
      await db.update(
        'site_scripts',
        {'verified': verified ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      LoggerService.instance.w(
        '脚本 verified 状态变更: id=$id verified=$verified',
        category: LogCategory.database,
        tags: ['site_script', 'set_verified'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '更新脚本 verified 状态失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['site_script', 'set_verified', 'failed'],
      );
      rethrow;
    }
  }

  /// 更新 use_count 和 last_used_at（标记已使用）
  Future<void> markUsed(String id) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.rawUpdate(
        'UPDATE site_scripts SET use_count = use_count + 1, last_used_at = ? WHERE id = ?',
        [now, id],
      );
      LoggerService.instance.d(
        '脚本标记已用: id=$id',
        category: LogCategory.cache,
        tags: ['site_script', 'mark_used'],
      );
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '标记脚本已用失败: id=$id - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['site_script', 'mark_used', 'failed'],
      );
      rethrow;
    }
  }
}
