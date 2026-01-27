import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';

/// 角色关系测试数据工厂
///
/// 提供可复用的测试数据生成方法，支持自定义和默认值
class CharacterRelationshipTestData {
  /// 创建测试用Character对象
  ///
  /// [id] 角色ID，默认为1
  /// [name] 角色名称，默认为"测试角色"
  /// [novelUrl] 小说URL，默认为"test_novel"
  /// [gender] 性别，默认为"男"
  /// [age] 年龄，默认为20
  static Character createTestCharacter({
    int? id,
    String name = '测试角色',
    String novelUrl = 'test_novel',
    String? gender,
    int? age,
  }) {
    return Character(
      id: id ?? 1,
      novelUrl: novelUrl,
      name: name,
      gender: gender ?? '男',
      age: age ?? 20,
      occupation: '测试职业',
      personality: '测试性格',
    );
  }

  /// 创建测试用CharacterRelationship对象
  ///
  /// [id] 关系ID，默认为null（新增关系）
  /// [sourceId] 源角色ID，默认为1
  /// [targetId] 目标角色ID，默认为2
  /// [type] 关系类型，默认为"师父"
  /// [description] 关系描述，默认为null
  /// [createdAt] 创建时间，默认为当前时间
  static CharacterRelationship createTestRelationship({
    int? id,
    int sourceId = 1,
    int targetId = 2,
    String type = '师父',
    String? description,
    DateTime? createdAt,
  }) {
    return CharacterRelationship(
      id: id,
      sourceCharacterId: sourceId,
      targetCharacterId: targetId,
      relationshipType: type,
      description: description,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// 创建测试用关系列表
  ///
  /// [count] 关系数量，默认为5
  /// [startId] 起始ID，默认为1
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
        relationshipType: '关系类型${index + 1}',
        description: '测试关系描述${index + 1}',
        createdAt: DateTime.now().subtract(Duration(days: index)),
      ),
    );
  }

  /// 创建包含出度和入度的关系列表
  ///
  /// 用于测试CharacterRelationshipScreen的Tab切换功能
  /// [characterId] 中心角色ID，默认为1
  static Map<String, List<CharacterRelationship>> createInOutRelationships({
    int characterId = 1,
  }) {
    final outgoing = [
      CharacterRelationship(
        id: 1,
        sourceCharacterId: characterId,
        targetCharacterId: 2,
        relationshipType: '师父',
        description: '他是我的师父',
      ),
      CharacterRelationship(
        id: 2,
        sourceCharacterId: characterId,
        targetCharacterId: 3,
        relationshipType: '朋友',
        description: '我们是好朋友',
      ),
    ];

    final incoming = [
      CharacterRelationship(
        id: 3,
        sourceCharacterId: 4,
        targetCharacterId: characterId,
        relationshipType: '徒弟',
        description: '我是他的徒弟',
      ),
      CharacterRelationship(
        id: 4,
        sourceCharacterId: 5,
        targetCharacterId: characterId,
        relationshipType: '兄弟',
        description: '我们是兄弟',
      ),
    ];

    return {'outgoing': outgoing, 'incoming': incoming};
  }

  /// 创建角色映射表
  ///
  /// 用于UI测试中查找角色信息
  /// [count] 角色数量，默认为5
  static Map<int, Character> createCharacterMap({
    int count = 5,
  }) {
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

  /// 常见关系类型及其反向类型
  ///
  /// 用于测试getReverseTypeHint方法
  static const Map<String, String> reverseRelationshipTypes = {
    '师父': '徒弟',
    '徒弟': '师父',
    '老师': '学生',
    '父亲': '儿子',
    '母亲': '女儿',
    '丈夫': '妻子',
    '妻子': '丈夫',
    '哥哥': '弟弟',
    '姐姐': '妹妹',
  };
}

/// 边界条件测试数据
class CharacterRelationshipBoundaryCases {
  /// 自循环关系（source = target）
  static CharacterRelationship selfLoop() {
    return CharacterRelationship(
      id: 1,
      sourceCharacterId: 1,
      targetCharacterId: 1,
      relationshipType: '自恋',
    );
  }

  /// 空字段关系
  static CharacterRelationship emptyFields() {
    return CharacterRelationship(
      id: null,
      sourceCharacterId: 1,
      targetCharacterId: 2,
      relationshipType: '',
      description: null,
    );
  }

  /// 长文本关系
  static CharacterRelationship longText() {
    return CharacterRelationship(
      id: 1,
      sourceCharacterId: 1,
      targetCharacterId: 2,
      relationshipType: 'A' * 100,
      description: 'B' * 500,
    );
  }
}
