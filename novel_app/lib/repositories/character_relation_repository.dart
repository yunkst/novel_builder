import 'package:sqflite/sqflite.dart';
import '../models/character_relationship.dart';
import '../models/ai_companion_response.dart';
import '../services/logger_service.dart';
import '../core/interfaces/repositories/i_character_relation_repository.dart';
import 'base_repository.dart';
import '../models/character.dart';

/// 人物关系数据仓库
///
/// 负责角色关系（CharacterRelationship）的数据库操作
/// 包括关系的创建、查询、更新、删除以及关系图数据管理
class CharacterRelationRepository extends BaseRepository
    implements ICharacterRelationRepository {
  /// 构造函数 - 接受数据库连接实例
  CharacterRelationRepository({required super.dbConnection});

  // ========== 基础CRUD操作 ==========

  /// 创建角色关系
  ///
  /// [relationship] 要创建的关系对象
  /// 返回新插入记录的ID，如果关系已存在则抛出异常
  @override
  Future<int> createRelationship(CharacterRelationship relationship) async {
    try {
      final db = await database;
      final id = await db.insert(
        'character_relationships',
        relationship.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      LoggerService.instance.i(
        '创建关系成功: $id',
        category: LogCategory.character,
        tags: ['relationship', 'create', 'success'],
      );

      return id;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '创建关系失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.character,
        tags: ['relationship', 'create', 'error'],
      );
      rethrow;
    }
  }

  /// 更新角色关系
  ///
  /// [relationship] 要更新的关系对象（必须包含id）
  /// 返回受影响的行数
  @override
  Future<int> updateRelationship(CharacterRelationship relationship) async {
    if (relationship.id == null) {
      throw ArgumentError('关系ID不能为空');
    }

    try {
      final db = await database;
      final count = await db.update(
        'character_relationships',
        relationship.toMap(),
        where: 'id = ?',
        whereArgs: [relationship.id],
      );

      LoggerService.instance.i(
        '更新关系成功: ${relationship.id}',
        category: LogCategory.character,
        tags: ['relationship', 'update', 'success'],
      );

      return count;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '更新关系失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.character,
        tags: ['relationship', 'update', 'error'],
      );
      rethrow;
    }
  }

  /// 删除角色关系
  ///
  /// [relationshipId] 关系ID
  /// 返回受影响的行数
  @override
  Future<int> deleteRelationship(int relationshipId) async {
    try {
      final db = await database;
      final count = await db.delete(
        'character_relationships',
        where: 'id = ?',
        whereArgs: [relationshipId],
      );

      LoggerService.instance.i(
        '删除关系成功: $relationshipId',
        category: LogCategory.character,
        tags: ['relationship', 'delete', 'success'],
      );

      return count;
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '删除关系失败: $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.character,
        tags: ['relationship', 'delete', 'error'],
      );
      rethrow;
    }
  }

  // ========== 关系查询方法 ==========

  /// 获取角色的所有关系（出度 + 入度）
  ///
  /// [characterId] 角色ID
  /// 返回该角色相关的所有关系列表
  @override
  Future<List<CharacterRelationship>> getRelationships(int characterId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM character_relationships
      WHERE source_character_id = ? OR target_character_id = ?
      ORDER BY created_at DESC
    ''', [characterId, characterId]);

    return maps.map((map) => CharacterRelationship.fromMap(map)).toList();
  }

  /// 获取角色的出度关系（Ta → 其他人）
  ///
  /// [characterId] 角色ID
  /// 返回该角色发起的所有关系列表
  @override
  Future<List<CharacterRelationship>> getOutgoingRelationships(
    int characterId,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'character_relationships',
      where: 'source_character_id = ?',
      whereArgs: [characterId],
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => CharacterRelationship.fromMap(map)).toList();
  }

  /// 获取角色的入度关系（其他人 → Ta）
  ///
  /// [characterId] 角色ID
  /// 返回指向该角色的所有关系列表
  @override
  Future<List<CharacterRelationship>> getIncomingRelationships(
    int characterId,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'character_relationships',
      where: 'target_character_id = ?',
      whereArgs: [characterId],
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => CharacterRelationship.fromMap(map)).toList();
  }

  /// 根据源和目标角色ID获取关系
  ///
  /// [sourceId] 源角色ID
  /// [targetId] 目标角色ID
  /// 返回匹配的关系列表
  @override
  Future<List<CharacterRelationship>> getRelationshipsByCharacterIds(
    int sourceId,
    int targetId,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'character_relationships',
      where: 'source_character_id = ? AND target_character_id = ?',
      whereArgs: [sourceId, targetId],
    );

    return maps.map((map) => CharacterRelationship.fromMap(map)).toList();
  }

  /// 获取小说的所有角色关系
  ///
  /// [novelUrl] 小说URL
  /// 返回该小说的所有角色关系
  @override
  Future<List<CharacterRelationship>> getAllRelationships(
      String novelUrl) async {
    if (isWebPlatform) {
      return [];
    }

    final db = await database;

    // 获取小说的所有角色ID
    final List<Map<String, dynamic>> characterMaps = await db.query(
      'characters',
      columns: ['id'],
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
    );

    if (characterMaps.isEmpty) {
      return [];
    }

    final characterIds = characterMaps.map((m) => m['id'] as int).toList();

    // 构建查询条件：source或target在角色ID列表中
    final placeholders = List.filled(characterIds.length, '?').join(',');
    final query = '''
      SELECT * FROM character_relationships
      WHERE source_character_id IN ($placeholders)
         OR target_character_id IN ($placeholders)
      ORDER BY created_at DESC
    ''';

    final args = [...characterIds, ...characterIds];
    final List<Map<String, dynamic>> relationMaps =
        await db.rawQuery(query, args);

    return relationMaps
        .map((map) => CharacterRelationship.fromMap(map))
        .toList();
  }

  // ========== 关系统计和检查 ==========

  /// 检查关系是否已存在
  ///
  /// [sourceId] 源角色ID
  /// [targetId] 目标角色ID
  /// [type] 关系类型
  /// 返回关系是否存在
  @override
  Future<bool> relationshipExists(
    int sourceId,
    int targetId,
    String type,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'character_relationships',
      where:
          'source_character_id = ? AND target_character_id = ? AND relationship_type = ?',
      whereArgs: [sourceId, targetId, type],
      limit: 1,
    );

    return maps.isNotEmpty;
  }

  /// 获取角色的关系数量
  ///
  /// [characterId] 角色ID
  /// 返回该角色的关系总数（出度 + 入度）
  @override
  Future<int> getRelationshipCount(int characterId) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM character_relationships
      WHERE source_character_id = ? OR target_character_id = ?
    ''', [characterId, characterId]);

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取与某角色相关的所有角色（去重）
  ///
  /// [characterId] 角色ID
  /// 返回相关角色的ID列表
  @override
  Future<List<int>> getRelatedCharacterIds(int characterId) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT DISTINCT
        CASE
          WHEN source_character_id = ? THEN target_character_id
          ELSE source_character_id
        END as related_id
      FROM character_relationships
      WHERE source_character_id = ? OR target_character_id = ?
    ''', [characterId, characterId, characterId]);

    return result.map((row) => row['related_id'] as int).toList();
  }

  // ========== AI伴读批量操作 ==========

  /// 批量更新或插入关系（用于AI伴读）
  ///
  /// [novelUrl] 小说URL
  /// [aiRelations] AI返回的关系更新列表
  /// [getCharactersFn] 获取小说所有角色的函数
  /// 返回成功更新的关系数量
  Future<int> batchUpdateOrInsertRelationships(
    String novelUrl,
    List<AICompanionRelation> aiRelations,
    Future<List<Character>> Function(String) getCharactersFn,
  ) async {
    if (isWebPlatform) {
      return 0;
    }

    if (aiRelations.isEmpty) {
      LoggerService.instance.w(
        'AI返回关系列表为空，跳过更新',
        category: LogCategory.ai,
        tags: ['relationship', 'batch', 'empty'],
      );
      return 0;
    }

    // 获取小说的所有角色，建立名称到ID的映射
    final allCharacters = await getCharactersFn(novelUrl);
    final Map<String, int> characterNameToId = {
      for (var c in allCharacters)
        if (c.id != null) c.name: c.id!,
    };

    int successCount = 0;

    for (final aiRelation in aiRelations) {
      try {
        // 查找source和target的角色ID
        final sourceId = characterNameToId[aiRelation.source];
        final targetId = characterNameToId[aiRelation.target];

        if (sourceId == null) {
          LoggerService.instance.w(
            '未找到source角色: ${aiRelation.source}，跳过关系: $aiRelation',
            category: LogCategory.ai,
            tags: ['relationship', 'character_not_found'],
          );
          continue;
        }

        if (targetId == null) {
          LoggerService.instance.w(
            '未找到target角色: ${aiRelation.target}，跳过关系: $aiRelation',
            category: LogCategory.ai,
            tags: ['relationship', 'character_not_found'],
          );
          continue;
        }

        // 查找是否已存在相同source和target的关系
        final existingRelations =
            await getRelationshipsByCharacterIds(sourceId, targetId);

        if (existingRelations.isNotEmpty) {
          // 更新现有关系的type
          final existingRelation = existingRelations.first;
          final updatedRelation = existingRelation.copyWith(
            relationshipType: aiRelation.type,
            updatedAt: DateTime.now(),
          );

          await updateRelationship(updatedRelation);
          successCount++;
          LoggerService.instance.i(
            '更新关系: ${aiRelation.source} -> ${aiRelation.target} (${aiRelation.type})',
            category: LogCategory.ai,
            tags: ['relationship', 'update', 'success'],
          );
        } else {
          // 创建新关系
          final newRelation = CharacterRelationship(
            sourceCharacterId: sourceId,
            targetCharacterId: targetId,
            relationshipType: aiRelation.type,
          );

          await createRelationship(newRelation);
          successCount++;
          LoggerService.instance.i(
            '新增关系: ${aiRelation.source} -> ${aiRelation.target} (${aiRelation.type})',
            category: LogCategory.ai,
            tags: ['relationship', 'create', 'success'],
          );
        }
      } catch (e, stackTrace) {
        LoggerService.instance.e(
          '更新/插入关系失败: ${aiRelation.source} -> ${aiRelation.target} - $e',
          stackTrace: stackTrace.toString(),
          category: LogCategory.ai,
          tags: ['relationship', 'error'],
        );
        // 继续处理其他关系
        continue;
      }
    }

    LoggerService.instance.i(
      '批量更新关系完成: $successCount/${aiRelations.length}',
      category: LogCategory.ai,
      tags: ['relationship', 'batch', 'success'],
    );
    return successCount;
  }
}
