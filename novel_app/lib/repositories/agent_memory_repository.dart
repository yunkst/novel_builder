/// Agent 场景经验记忆 Repository
///
/// 管理 agent_memory 表的 CRUD 操作。
/// 每个场景（writing / webview_extract）的记忆通过 scenario_id 隔离。
library;

import 'base_repository.dart';

class AgentMemoryRepository extends BaseRepository {
  AgentMemoryRepository({required super.dbConnection});

  /// 获取指定场景的所有记忆内容（按创建时间排序）
  Future<List<String>> getAllByScenario(String scenarioId) async {
    final db = await database;
    final results = await db.query(
      'agent_memory',
      columns: ['content'],
      where: 'scenario_id = ?',
      whereArgs: [scenarioId],
      orderBy: 'created_at ASC',
    );
    return results.map((r) => r['content'] as String).toList();
  }

  /// 获取指定场景的所有记忆（含 id，供 patch_memory 报错时返回）
  Future<List<Map<String, dynamic>>> getAllWithId(String scenarioId) async {
    final db = await database;
    return await db.query(
      'agent_memory',
      where: 'scenario_id = ?',
      whereArgs: [scenarioId],
      orderBy: 'created_at ASC',
    );
  }

  /// 添加一条记忆
  Future<int> addMemory(String scenarioId, String content) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.insert('agent_memory', {
      'scenario_id': scenarioId,
      'content': content,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// 更新记忆内容（同时更新 updated_at）
  Future<int> updateMemory(int id, String newContent) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      'agent_memory',
      {'content': newContent, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除记忆
  Future<int> deleteMemory(int id) async {
    final db = await database;
    return await db.delete(
      'agent_memory',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 精确匹配查找记忆（按 content 完全匹配）
  Future<Map<String, dynamic>?> findByContent(
    String scenarioId,
    String oldText,
  ) async {
    final db = await database;
    final results = await db.query(
      'agent_memory',
      where: 'scenario_id = ? AND content = ?',
      whereArgs: [scenarioId, oldText],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 获取指定场景的记忆总数
  Future<int> countByScenario(String scenarioId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM agent_memory WHERE scenario_id = ?',
      [scenarioId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }
}
