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

  /// 按 domain 去重保存：已存在则 UPDATE，不存在则 INSERT
  ///
  /// UPDATE 时保留 id / created_at / use_count，重置 verified=0，
  /// 更新脚本内容和 last_used_at。
  /// 返回 (id, isInsert) —— isInsert=true 表示首次插入。
  Future<({String id, bool isInsert})> upsertByDomain({
    required String domain,
    required String chapterListJs,
    required String chapterContentJs,
    String urlPattern = '',
    String sampleUrl = '',
    bool ocr = false, // v37 新增，默认 false 向后兼容
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final existing = await db.query(
        'site_scripts',
        where: 'domain = ?',
        whereArgs: [domain],
        orderBy: 'last_used_at DESC',
      );

      if (existing.isNotEmpty) {
        // UPDATE：保留 id / created_at / use_count，重置 verified
        final row = existing.first;
        await db.update(
          'site_scripts',
          {
            'chapter_list_js': chapterListJs,
            'chapter_content_js': chapterContentJs,
            'url_pattern': urlPattern,
            'sample_url': sampleUrl,
            'last_used_at': now,
            'verified': 0, // 脚本内容变了，需要重新验证
            'ocr': ocr ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );

        // 清理同 domain 的历史重复记录（保留第一条，删除其余）
        if (existing.length > 1) {
          final keepId = row['id'] as String;
          final deleted = await db.delete(
            'site_scripts',
            where: 'domain = ? AND id != ?',
            whereArgs: [domain, keepId],
          );
          LoggerService.instance.i(
            '清理同域名重复脚本: domain=$domain, deleted=$deleted',
            category: LogCategory.database,
            tags: ['site_script', 'upsert', 'cleanup'],
          );
        }

        LoggerService.instance.i(
          '更新域名脚本 (upsert): domain=$domain id=${row['id']}',
          category: LogCategory.database,
          tags: ['site_script', 'upsert', 'update'],
        );
        return (id: row['id'] as String, isInsert: false);
      }

      // INSERT：首次保存
      final id = now.toString();
      await db.insert('site_scripts', {
        'id': id,
        'domain': domain,
        'url_pattern': urlPattern,
        'chapter_list_js': chapterListJs,
        'chapter_content_js': chapterContentJs,
        'sample_url': sampleUrl,
        'created_at': now,
        'last_used_at': now,
        'use_count': 0,
        'verified': 0,
        'ocr': ocr ? 1 : 0,
      });
      LoggerService.instance.i(
        '新增域名脚本 (upsert): domain=$domain id=$id',
        category: LogCategory.database,
        tags: ['site_script', 'upsert', 'insert'],
      );
      return (id: id, isInsert: true);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        'upsert 脚本失败: domain=$domain - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['site_script', 'upsert', 'failed'],
      );
      rethrow;
    }
  }

  /// 增量更新某域名某类型脚本（save_script 分次保存用）。
  ///
  /// - [scriptType] 为 `'chapter_list'` 或 `'chapter_content'`，决定更新哪列。
  /// - 同时更新 [ocr] 列（保证两次保存的 ocr 标记一致）。
  /// - 若 domain 不存在 → 返回 (success=false, reason='domain_not_found')，不自动
  ///   create（避免半截提取器：list 存了 content 没存）。
  /// - 更新后 verified 重置为 0（脚本内容变了需重新验证）。
  /// - url_pattern 不写（save_script 不再产出该字段，DB 列保留历史值不动）。
  Future<({bool success, String? id, String? reason})> updateScriptPart({
    required String domain,
    required String scriptType,
    required String scriptJs,
    required bool ocr,
  }) async {
    try {
      final db = await database;
      final existing = await db.query(
        'site_scripts',
        where: 'domain = ?',
        whereArgs: [domain],
        orderBy: 'last_used_at DESC',
        limit: 1,
      );
      if (existing.isEmpty) {
        return (success: false, id: null, reason: 'domain_not_found');
      }
      final id = existing.first['id'] as String;
      final column = scriptType == 'chapter_list'
          ? 'chapter_list_js'
          : 'chapter_content_js';
      await db.update(
        'site_scripts',
        {
          column: scriptJs,
          'ocr': ocr ? 1 : 0,
          'last_used_at': DateTime.now().millisecondsSinceEpoch,
          'verified': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      LoggerService.instance.i(
        'updateScriptPart: domain=$domain type=$scriptType ocr=$ocr id=$id',
        category: LogCategory.database,
        tags: ['site_script', 'update_part'],
      );
      return (success: true, id: id, reason: null);
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        'updateScriptPart 失败: domain=$domain - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.database,
        tags: ['site_script', 'update_part', 'failed'],
      );
      rethrow;
    }
  }
}
