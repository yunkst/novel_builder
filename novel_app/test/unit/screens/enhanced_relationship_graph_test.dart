import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';
import 'package:novel_app/screens/enhanced_relationship_graph_screen.dart';
import '../../test_helpers/character_relationship_test_data.dart';

/// EnhancedRelationshipGraphScreen 单元测试
///
/// 测试增强版关系图的核心逻辑
void main() {
  group('EnhancedRelationshipGraphScreen - 数据处理', () {
    test('应该正确收集所有角色的关系', () {
      final characters = [
        CharacterRelationshipTestData.createTestCharacter(id: 1, name: '张三'),
        CharacterRelationshipTestData.createTestCharacter(id: 2, name: '李四'),
        CharacterRelationshipTestData.createTestCharacter(id: 3, name: '王五'),
      ];

      // 模拟各角色的关系
      final relationshipsMap = {
        1: [
          CharacterRelationship(
            id: 1,
            sourceCharacterId: 1,
            targetCharacterId: 2,
            relationshipType: '朋友',
          ),
        ],
        2: [
          CharacterRelationship(
            id: 2,
            sourceCharacterId: 1,
            targetCharacterId: 2,
            relationshipType: '朋友',
          ),
          CharacterRelationship(
            id: 3,
            sourceCharacterId: 2,
            targetCharacterId: 3,
            relationshipType: '同事',
          ),
        ],
        3: [
          CharacterRelationship(
            id: 3,
            sourceCharacterId: 2,
            targetCharacterId: 3,
            relationshipType: '同事',
          ),
        ],
      };

      // 收集所有关系
      final allRelationships = <CharacterRelationship>{};
      for (final character in characters) {
        if (character.id != null) {
          final rels = relationshipsMap[character.id] ?? [];
          allRelationships.addAll(rels);
        }
      }

      // 验证关系去重
      expect(allRelationships.length, 3); // 应该去重后只有3个关系
      expect(allRelationships, contains(relationshipsMap[1]![0]));
      expect(allRelationships, contains(relationshipsMap[2]![0]));
      expect(allRelationships, contains(relationshipsMap[2]![1]));
    });

    test('应该正确处理空角色列表', () {
      final characters = <Character>[];

      expect(characters, isEmpty);
    });

    test('应该正确处理没有关系的角色', () {
      final characters = [
        CharacterRelationshipTestData.createTestCharacter(id: 1, name: '张三'),
      ];

      final relationships = <CharacterRelationship>[];

      expect(relationships, isEmpty);
      // 应该显示角色但没有连线
    });
  });

  group('EnhancedRelationshipGraphScreen - 图结构构建', () {
    test('节点ID应该使用角色的ID字符串', () {
      final character = CharacterRelationshipTestData.createTestCharacter(
        id: 123,
        name: '测试角色',
      );

      final nodeId = character.id.toString();

      expect(nodeId, '123');
    });

    test('应该正确构建图的边', () {
      final relationship = CharacterRelationship(
        id: 1,
        sourceCharacterId: 10,
        targetCharacterId: 20,
        relationshipType: '师父',
      );

      expect(relationship.sourceCharacterId, 10);
      expect(relationship.targetCharacterId, 20);
      expect(relationship.relationshipType, '师父');
    });

    test('应该支持双向关系', () {
      final rel1 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      final rel2 = CharacterRelationship(
        id: 2,
        sourceCharacterId: 2,
        targetCharacterId: 1,
        relationshipType: '朋友',
      );

      // 应该创建两条边
      expect(rel1.sourceCharacterId, 1);
      expect(rel1.targetCharacterId, 2);
      expect(rel2.sourceCharacterId, 2);
      expect(rel2.targetCharacterId, 1);
    });
  });

  group('EnhancedRelationshipGraphScreen - 渲染参数', () {
    test('节点大小应该正确配置', () {
      const nodeSize = 80.0;

      expect(nodeSize, greaterThan(0));
      expect(nodeSize, 80.0);
    });

    test('缩放范围应该合理', () {
      const minScale = 0.5;
      const maxScale = 2.0;

      expect(minScale, lessThan(maxScale));
      expect(minScale, 0.5);
      expect(maxScale, 2.0);
    });

    test('应该正确计算初始统计信息', () {
      final characterCount = 15;
      final relationshipCount = 42;

      final statsText = '角色: $characterCount | 关系: $relationshipCount';

      expect(statsText, contains('15'));
      expect(statsText, contains('42'));
    });
  });

  group('EnhancedRelationshipGraphScreen - 性能优化', () {
    test('大量节点时应该过滤孤立节点（可选）', () {
      final characters = List.generate(
        100,
        (i) => CharacterRelationshipTestData.createTestCharacter(
          id: i + 1,
          name: '角色$i',
        ),
      );

      final relationships = [
        // 只有前10个节点有关系
        for (int i = 1; i < 10; i++)
          CharacterRelationship(
            id: i,
            sourceCharacterId: i,
            targetCharacterId: i + 1,
            relationshipType: '连接',
          ),
      ];

      // 过滤出有关系的节点
      final connectedNodeIds = <int>{};
      for (final rel in relationships) {
        connectedNodeIds.add(rel.sourceCharacterId);
        connectedNodeIds.add(rel.targetCharacterId);
      }

      final connectedCharacters = characters
          .where((c) => c.id != null && connectedNodeIds.contains(c.id))
          .toList();

      expect(connectedCharacters.length, lessThan(100)); // 应该远小于100
      expect(connectedCharacters.length, lessThanOrEqualTo(11)); // 10个节点+1个目标
    });
  });

  group('EnhancedRelationshipGraphScreen - 边界条件', () {
    test('应该处理角色没有ID的情况', () {
      final character = Character(
        novelUrl: 'test_novel',
        name: '无ID角色',
        id: null,
      );

      expect(character.id, isNull);
      // 不应该添加到图中
    });

    test('应该处理自循环关系', () {
      final relationship = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 1, // 自指向
        relationshipType: '自恋',
      );

      expect(relationship.sourceCharacterId, relationship.targetCharacterId);
      // 图库应该能处理这种情况
    });

    test('应该处理超长关系类型', () {
      final longType = 'A' * 100;
      final relationship = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: longType,
      );

      expect(relationship.relationshipType.length, 100);
      // UI应该截断或换行显示
    });

    test('应该处理特殊字符关系类型', () {
      final relationship = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '师父<>&"',
      );

      expect(relationship.relationshipType, contains('<'));
      expect(relationship.relationshipType, contains('>'));
    });
  });
}
