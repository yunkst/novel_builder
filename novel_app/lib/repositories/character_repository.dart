// ignore: unused_import
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import '../models/character.dart';
import '../models/character_relationship.dart';
import '../models/ai_companion_response.dart';
import 'base_repository.dart';
import '../services/logger_service.dart';

/// 角色仓库类
///
/// 负责角色和角色关系的数据访问操作，包括：
/// - 角色的CRUD操作
/// - 角色搜索和查询
/// - 角色图片管理
/// - 角色关系的CRUD操作
/// - 批量更新操作（用于AI伴读）
class CharacterRepository extends BaseRepository {
  @override
  Future<Database> initDatabase() async {
    // 数据库由 DatabaseService 统一管理
    throw UnimplementedError('CharacterRepository 依赖 DatabaseService 管理数据库实例');
  }

  // ========== 角色CRUD操作 ==========

  /// 创建角色
  ///
  /// [character] 要创建的角色对象
  /// 返回新插入记录的ID
  Future<int> createCharacter(Character character) async {
    final db = await database;
    return await db.insert(
      'characters',
      character.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取小说的所有角色
  ///
  /// [novelUrl] 小说URL
  /// 返回按创建时间升序排列的角色列表
  Future<List<Character>> getCharacters(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
      orderBy: 'createdAt ASC',
    );

    return List.generate(maps.length, (i) {
      return Character.fromMap(maps[i]);
    });
  }

  /// 根据ID获取角色
  ///
  /// [id] 角色ID
  /// 返回角色对象，如果不存在则返回null
  Future<Character?> getCharacter(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Character.fromMap(maps.first);
    }
    return null;
  }

  /// 更新角色
  ///
  /// [character] 要更新的角色对象（必须包含id）
  /// 返回受影响的行数
  Future<int> updateCharacter(Character character) async {
    final db = await database;
    final updatedCharacter = character.copyWith(
      updatedAt: DateTime.now(),
    );

    return await db.update(
      'characters',
      updatedCharacter.toMap(),
      where: 'id = ?',
      whereArgs: [character.id],
    );
  }

  /// 删除角色
  ///
  /// [id] 角色ID
  /// 返回受影响的行数
  Future<int> deleteCharacter(int id) async {
    final db = await database;
    return await db.delete(
      'characters',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 根据名称查找角色
  ///
  /// [novelUrl] 小说URL
  /// [name] 角色名称
  /// 返回角色对象，如果不存在则返回null
  Future<Character?> findCharacterByName(String novelUrl, String name) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      where: 'novelUrl = ? AND name = ?',
      whereArgs: [novelUrl, name],
    );

    if (maps.isNotEmpty) {
      return Character.fromMap(maps.first);
    }
    return null;
  }

  /// 更新或插入角色（去重逻辑）
  ///
  /// 如果角色已存在（按novelUrl和name匹配），则更新现有角色
  /// 如果角色不存在，则创建新角色
  ///
  /// [newCharacter] 要更新或插入的角色
  /// 返回操作后的角色对象
  Future<Character> updateOrInsertCharacter(Character newCharacter) async {
    try {
      final db = await database;

      // 查找是否已存在同名角色
      final existingCharacter = await findCharacterByName(
        newCharacter.novelUrl,
        newCharacter.name,
      );

      if (existingCharacter != null) {
        // 更新现有角色，保留原有ID和创建时间
        final updatedCharacter = existingCharacter.copyWith(
          age: newCharacter.age,
          gender: newCharacter.gender,
          occupation: newCharacter.occupation,
          personality: newCharacter.personality,
          bodyType: newCharacter.bodyType,
          clothingStyle: newCharacter.clothingStyle,
          appearanceFeatures: newCharacter.appearanceFeatures,
          backgroundStory: newCharacter.backgroundStory,
          updatedAt: DateTime.now(),
        );

        await db.update(
          'characters',
          updatedCharacter.toMap(),
          where: 'id = ?',
          whereArgs: [existingCharacter.id],
        );

        LoggerService.instance.i(
          '更新角色: ${newCharacter.name} (ID: ${existingCharacter.id})',
          category: LogCategory.character,
          tags: ['update', 'success'],
        );
        return updatedCharacter;
      } else {
        // 创建新角色
        final id = await db.insert(
          'characters',
          newCharacter.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        LoggerService.instance.i(
          '创建新角色: ${newCharacter.name} (ID: $id)',
          category: LogCategory.character,
          tags: ['create', 'success'],
        );
        return newCharacter.copyWith(id: id);
      }
    } catch (e, stackTrace) {
      LoggerService.instance.e(
        '更新或插入角色失败: ${newCharacter.name} - $e',
        stackTrace: stackTrace.toString(),
        category: LogCategory.character,
        tags: ['character', 'update_or_insert', 'failed'],
      );
      rethrow;
    }
  }

  /// 批量更新角色
  ///
  /// 接受新角色列表，对每个角色执行去重更新逻辑
  ///
  /// [newCharacters] 要更新的角色列表
  /// 返回成功更新的角色列表
  Future<List<Character>> batchUpdateCharacters(
      List<Character> newCharacters) async {
    final updatedCharacters = <Character>[];

    for (final character in newCharacters) {
      try {
        final updatedCharacter = await updateOrInsertCharacter(character);
        updatedCharacters.add(updatedCharacter);
      } catch (e, stackTrace) {
        LoggerService.instance.e(
          '批量更新角色失败: ${character.name} - $e',
          stackTrace: stackTrace.toString(),
          category: LogCategory.character,
          tags: ['batch', 'error'],
        );
        // 继续处理其他角色，不中断整个批量操作
        continue;
      }
    }

    LoggerService.instance.i(
      '批量更新完成，成功更新 ${updatedCharacters.length}/${newCharacters.length} 个角色',
      category: LogCategory.character,
      tags: ['batch', 'update'],
    );
    return updatedCharacters;
  }

  /// 获取小说的所有角色名称
  ///
  /// [novelUrl] 小说URL
  /// 返回按名称字母顺序排列的角色名称列表
  Future<List<String>> getCharacterNames(String novelUrl) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      columns: ['name'],
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
      orderBy: 'name ASC',
    );

    return maps.map((map) => map['name'] as String).toList();
  }

  /// 检查角色是否存在
  ///
  /// [id] 角色ID
  /// 返回角色是否存在
  Future<bool> characterExists(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      where: 'id = ?',
      whereArgs: [id],
    );

    return maps.isNotEmpty;
  }

  /// 根据ID列表获取多个角色
  ///
  /// [ids] 角色ID列表
  /// 返回按创建时间升序排列的角色列表，如果ID列表为空则返回空列表
  Future<List<Character>> getCharactersByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'createdAt ASC',
    );

    return List.generate(maps.length, (i) {
      return Character.fromMap(maps[i]);
    });
  }

  /// 删除小说的所有角色
  ///
  /// [novelUrl] 小说URL
  /// 返回受影响的行数
  Future<int> deleteAllCharacters(String novelUrl) async {
    final db = await database;
    return await db.delete(
      'characters',
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
    );
  }

  // ========== 角色图片管理 ==========

  /// 更新角色的缓存图片URL
  ///
  /// [characterId] 角色ID
  /// [imageUrl] 缓存图片URL
  /// 返回受影响的行数
  Future<int> updateCharacterCachedImage(
      int characterId, String? imageUrl) async {
    final db = await database;
    return await db.update(
      'characters',
      {
        'cachedImageUrl': imageUrl,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [characterId],
    );
  }

  /// 清除角色的缓存图片URL
  ///
  /// [characterId] 角色ID
  /// 返回受影响的行数
  Future<int> clearCharacterCachedImage(int characterId) async {
    final db = await database;
    return await db.update(
      'characters',
      {
        'cachedImageUrl': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [characterId],
    );
  }

  /// 批量清除角色的缓存图片URL
  ///
  /// [novelUrl] 小说URL
  /// 返回受影响的行数
  Future<int> clearAllCharacterCachedImages(String novelUrl) async {
    final db = await database;
    return await db.update(
      'characters',
      {
        'cachedImageUrl': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'novelUrl = ?',
      whereArgs: [novelUrl],
    );
  }

  /// 获取角色的缓存图片URL
  ///
  /// [characterId] 角色ID
  /// 返回头像缓存路径，如果没有设置则返回null
  Future<String?> getCharacterCachedImage(int characterId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'characters',
      columns: ['cachedImageUrl'],
      where: 'id = ?',
      whereArgs: [characterId],
      limit: 1,
    );

    if (maps.isNotEmpty && maps.first['cachedImageUrl'] != null) {
      return maps.first['cachedImageUrl'] as String?;
    }

    return null;
  }

  /// 更新角色头像信息（扩展方法，支持更多元数据）
  ///
  /// [characterId] 角色ID
  /// [imageUrl] 头像URL/路径
  /// [originalFilename] 原始图集文件名（未使用）
  /// [originalImageUrl] 原始图片URL（未使用）
  /// 返回受影响的行数
  Future<int> updateCharacterAvatar(
    int characterId, {
    String? imageUrl,
    String? originalFilename,
    String? originalImageUrl,
  }) async {
    final db = await database;

    final Map<String, dynamic> updateData = {
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    if (imageUrl != null) {
      updateData['cachedImageUrl'] = imageUrl;
    } else {
      updateData['cachedImageUrl'] = null;
    }

    return await db.update(
      'characters',
      updateData,
      where: 'id = ?',
      whereArgs: [characterId],
    );
  }

  /// 检查角色是否有头像缓存
  ///
  /// [characterId] 角色ID
  /// 返回是否有头像缓存
  Future<bool> hasCharacterAvatar(int characterId) async {
    final cachedUrl = await getCharacterCachedImage(characterId);
    return cachedUrl != null && cachedUrl.isNotEmpty;
  }

  // ========== 角色关系CRUD操作 ==========

  /// 创建角色关系
  ///
  /// [relationship] 要创建的关系对象
  /// 返回新插入记录的ID，如果关系已存在则抛出异常
  Future<int> createRelationship(CharacterRelationship relationship) async {
    final db = await database;

    try {
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
      int characterId) async {
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
      int characterId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'character_relationships',
      where: 'target_character_id = ?',
      whereArgs: [characterId],
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => CharacterRelationship.fromMap(map)).toList();
  }

  /// 更新角色关系
  ///
  /// [relationship] 要更新的关系对象（必须包含id）
  /// 返回受影响的行数
  Future<int> updateRelationship(CharacterRelationship relationship) async {
    if (relationship.id == null) {
      throw ArgumentError('关系ID不能为空');
    }

    final db = await database;

    try {
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
    final db = await database;

    try {
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

  /// 检查关系是否已存在
  ///
  /// [sourceId] 源角色ID
  /// [targetId] 目标角色ID
  /// [type] 关系类型
  /// 返回关系是否存在
  Future<bool> relationshipExists(
      int sourceId, int targetId, String type) async {
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

  /// 获取小说的所有关系
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

  /// 根据source和target角色ID获取关系
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

  // ========== AI伴读批量操作 ==========

  /// 批量更新或插入角色（用于AI伴读）
  ///
  /// [novelUrl] 小说URL
  /// [aiRoles] AI返回的角色更新列表
  /// 返回成功更新的角色数量
  Future<int> batchUpdateOrInsertCharacters(
    String novelUrl,
    List<AICompanionRole> aiRoles,
  ) async {
    if (isWebPlatform) {
      return 0;
    }

    if (aiRoles.isEmpty) {
      LoggerService.instance.w(
        'AI返回角色列表为空，跳过更新',
        category: LogCategory.ai,
        tags: ['character', 'batch', 'empty'],
      );
      return 0;
    }

    int successCount = 0;

    for (final aiRole in aiRoles) {
      try {
        // 查找是否已存在同名角色
        final existingCharacter = await findCharacterByName(
          novelUrl,
          aiRole.name,
        );

        if (existingCharacter != null) {
          // 更新现有角色，保留原有ID和创建时间
          final updatedCharacter = existingCharacter.copyWith(
            gender: (aiRole.gender != null && aiRole.gender!.isNotEmpty)
                ? aiRole.gender
                : null,
            age: aiRole.age,
            occupation:
                (aiRole.occupation != null && aiRole.occupation!.isNotEmpty)
                    ? aiRole.occupation
                    : null,
            personality:
                (aiRole.personality != null && aiRole.personality!.isNotEmpty)
                    ? aiRole.personality
                    : null,
            bodyType: (aiRole.bodyType != null && aiRole.bodyType!.isNotEmpty)
                ? aiRole.bodyType
                : null,
            clothingStyle: (aiRole.clothingStyle != null &&
                    aiRole.clothingStyle!.isNotEmpty)
                ? aiRole.clothingStyle
                : null,
            appearanceFeatures: (aiRole.appearanceFeatures != null &&
                    aiRole.appearanceFeatures!.isNotEmpty)
                ? aiRole.appearanceFeatures
                : null,
            backgroundStory: (aiRole.backgroundStory != null &&
                    aiRole.backgroundStory!.isNotEmpty)
                ? aiRole.backgroundStory
                : null,
            updatedAt: DateTime.now(),
          );

          await updateCharacter(updatedCharacter);
          successCount++;
          LoggerService.instance.i(
            '更新角色: ${aiRole.name}',
            category: LogCategory.ai,
            tags: ['character', 'update', 'success'],
          );
        } else {
          // 创建新角色
          final newCharacter = Character(
            novelUrl: novelUrl,
            name: aiRole.name,
            gender: (aiRole.gender != null && aiRole.gender!.isNotEmpty)
                ? aiRole.gender
                : null,
            age: aiRole.age,
            occupation:
                (aiRole.occupation != null && aiRole.occupation!.isNotEmpty)
                    ? aiRole.occupation
                    : null,
            personality:
                (aiRole.personality != null && aiRole.personality!.isNotEmpty)
                    ? aiRole.personality
                    : null,
            bodyType: (aiRole.bodyType != null && aiRole.bodyType!.isNotEmpty)
                ? aiRole.bodyType
                : null,
            clothingStyle: (aiRole.clothingStyle != null &&
                    aiRole.clothingStyle!.isNotEmpty)
                ? aiRole.clothingStyle
                : null,
            appearanceFeatures: (aiRole.appearanceFeatures != null &&
                    aiRole.appearanceFeatures!.isNotEmpty)
                ? aiRole.appearanceFeatures
                : null,
            backgroundStory: (aiRole.backgroundStory != null &&
                    aiRole.backgroundStory!.isNotEmpty)
                ? aiRole.backgroundStory
                : null,
          );

          await createCharacter(newCharacter);
          successCount++;
          LoggerService.instance.i(
            '新增角色: ${aiRole.name}',
            category: LogCategory.ai,
            tags: ['character', 'create', 'success'],
          );
        }
      } catch (e, stackTrace) {
        LoggerService.instance.e(
          '更新/插入角色失败: ${aiRole.name} - $e',
          stackTrace: stackTrace.toString(),
          category: LogCategory.ai,
          tags: ['character', 'error'],
        );
        // 继续处理其他角色
        continue;
      }
    }

    LoggerService.instance.i(
      '批量更新角色完成: $successCount/${aiRoles.length}',
      category: LogCategory.ai,
      tags: ['character', 'batch', 'success'],
    );
    return successCount;
  }

  /// 批量更新或插入关系（用于AI伴读）
  ///
  /// [novelUrl] 小说URL
  /// [aiRelations] AI返回的关系更新列表
  /// 返回成功更新的关系数量
  Future<int> batchUpdateOrInsertRelationships(
    String novelUrl,
    List<AICompanionRelation> aiRelations,
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
    final allCharacters = await getCharacters(novelUrl);
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
