import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;
import '../models/character_relationship.dart';
import '../services/logger_service.dart';
import 'base_repository.dart';

/// 人物关系数据仓库
///
/// 负责角色关系（CharacterRelationship）的数据库操作
/// 包括关系的创建、查询、更新、删除以及关系图数据管理
class CharacterRelationRepository extends BaseRepository {
  Database? _sharedDatabase;

  @override
  Future<Database> initDatabase() async {
    if (_sharedDatabase != null) return _sharedDatabase!;
    if (isWebPlatform) {
      throw Exception('Database is not supported on web platform');
    }

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'novel_reader.db');

    _sharedDatabase = await openDatabase(
      path,
      version: 21,
    );

    return _sharedDatabase!;
  }

  // ========== 基础CRUD操作 ==========

  /// 创建角色关系
  ///
  /// [relationship] 要创建的关系对象
  /// 返回新插入记录的ID，如果关系已存在则抛出异常
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
}
