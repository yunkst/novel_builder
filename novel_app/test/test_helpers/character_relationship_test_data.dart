import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';
import 'package:novel_app/models/relation_type.dart';

/// 角色关系测试数据工厂
///
/// 提供可复用的测试数据生成方法,适配 CharacterRelationship v2(区间模型)。
class CharacterRelationshipTestData {
  /// 创建测试用 Character
  static Character createTestCharacter({
    int? id,
    String name = '测试角色',
    String novelUrl = 'test_novel',
    String? gender,
    int? age,
    int? firstAppearanceChapter,
  }) {
    return Character(
      id: id ?? 1,
      novelUrl: novelUrl,
      name: name,
      gender: gender ?? '男',
      age: age ?? 20,
      occupation: '测试职业',
      personality: '测试性格',
      firstAppearanceChapter: firstAppearanceChapter,
    );
  }

  /// 创建测试用 CharacterRelationship(v2 区间模型)
  static CharacterRelationship createTestRelationship({
    int? id,
    int sourceId = 1,
    int targetId = 2,
    RelationType relationType = RelationType.masterDisciple,
    int strength = 3,
    int startChapter = 0,
    int? endChapter,
    String? description,
    String novelUrl = 'test_novel',
    DateTime? createdAt,
  }) {
    return CharacterRelationship(
      id: id,
      sourceCharacterId: sourceId,
      targetCharacterId: targetId,
      relationType: relationType,
      strength: strength,
      startChapter: startChapter,
      endChapter: endChapter,
      description: description,
      novelUrl: novelUrl,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// 创建测试用关系列表
  static List<CharacterRelationship> createTestRelationshipList({
    int count = 5,
    int startId = 1,
  }) {
    return List.generate(
      count,
      (index) => CharacterRelationship(
        id: startId + index,
        sourceCharacterId: 1,
        targetCharacterId: 2 + index,
        relationType: RelationType.friend,
        startChapter: index,
        description: '测试关系描述${index + 1}',
        novelUrl: 'test_novel',
        createdAt: DateTime.now().subtract(Duration(days: index)),
      ),
    );
  }

  /// 创建角色映射表
  static Map<int, Character> createCharacterMap({int count = 5}) {
    return {
      for (int i = 1; i <= count; i++)
        i: createTestCharacter(
          id: i,
          name: '角色$i',
          gender: i % 2 == 0 ? '女' : '男',
          age: 20 + i,
        )
    };
  }
}

/// 边界条件测试数据
class CharacterRelationshipBoundaryCases {
  /// 自循环关系(source = target)
  static CharacterRelationship selfLoop() {
    return CharacterRelationship(
      id: 1,
      sourceCharacterId: 1,
      targetCharacterId: 1,
      relationType: RelationType.friend,
      startChapter: 0,
      novelUrl: 'test_novel',
    );
  }

  /// 最小字段关系(仅必填)
  static CharacterRelationship minimal() {
    return CharacterRelationship(
      sourceCharacterId: 1,
      targetCharacterId: 2,
      relationType: RelationType.friend,
      startChapter: 0,
      novelUrl: 'test_novel',
    );
  }

  /// 长文本关系
  static CharacterRelationship longText() {
    return CharacterRelationship(
      id: 1,
      sourceCharacterId: 1,
      targetCharacterId: 2,
      relationType: RelationType.friend,
      startChapter: 0,
      description: 'B' * 500,
      novelUrl: 'test_novel',
    );
  }
}
