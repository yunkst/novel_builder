import '../../../models/character_relationship.dart';

/// 人物关系数据仓库接口
///
/// 负责角色关系（CharacterRelationship）的数据库操作，包括关系的创建、
/// 查询、更新、删除以及关系图数据管理
abstract class ICharacterRelationRepository {
  // ========== 基础CRUD操作 ==========

  /// 创建角色关系
  ///
  /// [relationship] 要创建的关系对象
  /// 返回新插入记录的ID，如果关系已存在则抛出异常
  Future<int> createRelationship(CharacterRelationship relationship);

  /// 更新角色关系
  ///
  /// [relationship] 要更新的关系对象（必须包含id）
  /// 返回受影响的行数
  Future<int> updateRelationship(CharacterRelationship relationship);

  /// 删除角色关系
  ///
  /// [relationshipId] 关系ID
  /// 返回受影响的行数
  Future<int> deleteRelationship(int relationshipId);

  // ========== 关系查询方法 ==========

  /// 获取角色的所有关系（出度 + 入度）
  ///
  /// [characterId] 角色ID
  /// 返回该角色相关的所有关系列表
  Future<List<CharacterRelationship>> getRelationships(int characterId);

  /// 获取角色的出度关系（Ta → 其他人）
  ///
  /// [characterId] 角色ID
  /// 返回该角色发起的所有关系列表
  Future<List<CharacterRelationship>> getOutgoingRelationships(int characterId);

  /// 获取角色的入度关系（其他人 → Ta）
  ///
  /// [characterId] 角色ID
  /// 返回指向该角色的所有关系列表
  Future<List<CharacterRelationship>> getIncomingRelationships(int characterId);

  /// 根据源和目标角色ID获取关系
  ///
  /// [sourceId] 源角色ID
  /// [targetId] 目标角色ID
  /// 返回匹配的关系列表
  Future<List<CharacterRelationship>> getRelationshipsByCharacterIds(
      int sourceId, int targetId);

  /// 获取小说的所有角色关系
  ///
  /// [novelUrl] 小说URL
  /// 返回该小说的所有角色关系
  Future<List<CharacterRelationship>> getAllRelationships(String novelUrl);

  // ========== 关系统计和检查 ==========

  /// 检查关系是否已存在
  ///
  /// [sourceId] 源角色ID
  /// [targetId] 目标角色ID
  /// [type] 关系类型
  /// 返回关系是否存在
  Future<bool> relationshipExists(int sourceId, int targetId, String type);

  /// 获取角色的关系数量
  ///
  /// [characterId] 角色ID
  /// 返回该角色的关系总数（出度 + 入度）
  Future<int> getRelationshipCount(int characterId);

  /// 获取与某角色相关的所有角色（去重）
  ///
  /// [characterId] 角色ID
  /// 返回相关角色的ID列表
  Future<List<int>> getRelatedCharacterIds(int characterId);
}
