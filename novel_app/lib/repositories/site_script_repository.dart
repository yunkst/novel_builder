/// 站点提取脚本 Repository
///
/// 提供 site_scripts 表的 CRUD 操作。
/// 遵循项目 Repository 模式，继承 BaseRepository。
library;

import '../models/site_script.dart';
import 'base_repository.dart';

class SiteScriptRepository extends BaseRepository {
  SiteScriptRepository({required super.dbConnection});

  /// 查询所有脚本（按最后使用时间倒序）
  Future<List<SiteScript>> getAll({int limit = 50}) async {
    final db = await database;
    final results = await db.query(
      'site_scripts',
      orderBy: 'last_used_at DESC',
      limit: limit,
    );
    return results.map(SiteScript.fromMap).toList();
  }

  /// 按 domain 查询
  Future<SiteScript?> getByDomain(String domain) async {
    final db = await database;
    final results = await db.query(
      'site_scripts',
      where: 'domain = ?',
      whereArgs: [domain],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SiteScript.fromMap(results.first);
  }

  /// 按 ID 查询
  Future<SiteScript?> getById(String id) async {
    final db = await database;
    final results = await db.query(
      'site_scripts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SiteScript.fromMap(results.first);
  }

  /// 删除脚本
  Future<void> delete(String id) async {
    final db = await database;
    await db.delete('site_scripts', where: 'id = ?', whereArgs: [id]);
  }

  /// 按 domain 删除
  Future<void> deleteByDomain(String domain) async {
    final db = await database;
    await db.delete('site_scripts', where: 'domain = ?', whereArgs: [domain]);
  }

  /// 更新 verified 状态
  Future<void> setVerified(String id, bool verified) async {
    final db = await database;
    await db.update(
      'site_scripts',
      {'verified': verified ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 更新 use_count 和 last_used_at（标记已使用）
  Future<void> markUsed(String id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.rawUpdate(
      'UPDATE site_scripts SET use_count = use_count + 1, last_used_at = ? WHERE id = ?',
      [now, id],
    );
  }
}
