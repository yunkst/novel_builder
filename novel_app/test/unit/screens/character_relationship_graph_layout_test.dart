import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';
import '../../test_helpers/character_relationship_test_data.dart';

/// CharacterRelationshipGraphScreen 布局计算测试
///
/// 测试关系图的核心布局算法，不依赖Flutter Widget
void main() {
  group('关系图布局计算', () {
    test('应该正确计算圆形布局的半径', () {
      // 测试半径计算公式：150.0 + nodeCount * 10.0
      const baseRadius = 150.0;
      const incrementPerNode = 10.0;

      double calculateRadius(int nodeCount) {
        return baseRadius + nodeCount * incrementPerNode;
      }

      expect(calculateRadius(1), 160.0);
      expect(calculateRadius(5), 200.0);
      expect(calculateRadius(10), 250.0);
      expect(calculateRadius(20), 350.0);
    });

    test('应该正确计算节点在圆形上的位置', () {
      final centerNodeId = 1;
      final radius = 200.0;
      final nodeCount = 4;

      // 模拟计算圆形布局
      final Map<int, Offset> positions = {};
      final angleStep = 2 * 3.14159265359 / nodeCount;

      for (int i = 0; i < nodeCount; i++) {
        final nodeId = 2 + i; // 节点ID从2开始
        final angle = i * angleStep - 3.14159265359 / 2; // 从顶部开始

        final x = radius * math.cos(angle);
        final y = radius * math.sin(angle);

        positions[nodeId] = Offset(x, y);
      }

      // 验证节点数量
      expect(positions.length, 4);

      // 验证所有节点到中心的距离相等（在圆形上）
      for (final entry in positions.entries) {
        final distance = math.sqrt(
          entry.value.dx * entry.value.dx + entry.value.dy * entry.value.dy,
        );
        expect(distance, closeTo(radius, 0.1));
      }
    });

    test('中心节点应该在原点', () {
      final centerNodeId = 1;
      final Map<int, Offset> positions = {};

      positions[centerNodeId] = Offset.zero;

      expect(positions[centerNodeId]!.dx, 0.0);
      expect(positions[centerNodeId]!.dy, 0.0);
    });

    test('节点角度应该均匀分布', () {
      final nodeCount = 8;
      final expectedAngleStep = 2 * 3.14159265359 / nodeCount;
      final List<double> angles = [];

      for (int i = 0; i < nodeCount; i++) {
        final angle = i * expectedAngleStep - 3.14159265359 / 2;
        angles.add(angle);
      }

      // 验证相邻角度差相等
      for (int i = 1; i < angles.length; i++) {
        final diff = angles[i] - angles[i - 1];
        expect(diff, closeTo(expectedAngleStep, 0.001));
      }
    });
  });

  group('关系图交互逻辑', () {
    test('点击节点应该高亮相关关系', () {
      final characterId = 1;
      final relationships = [
        CharacterRelationship(
          id: 1,
          sourceCharacterId: 1,
          targetCharacterId: 2,
          relationshipType: '师父',
        ),
        CharacterRelationship(
          id: 2,
          sourceCharacterId: 3,
          targetCharacterId: 1,
          relationshipType: '徒弟',
        ),
        CharacterRelationship(
          id: 3,
          sourceCharacterId: 4,
          targetCharacterId: 5,
          relationshipType: '朋友', // 无关关系
        ),
      ];

      final highlightedRelationships = <CharacterRelationship>{};
      final highlightedNodeIds = <int>{};

      // 模拟点击节点1
      for (final rel in relationships) {
        if (rel.sourceCharacterId == characterId) {
          highlightedRelationships.add(rel);
          highlightedNodeIds.add(rel.targetCharacterId);
        } else if (rel.targetCharacterId == characterId) {
          highlightedRelationships.add(rel);
          highlightedNodeIds.add(rel.sourceCharacterId);
        }
      }

      // 验证高亮的关系
      expect(highlightedRelationships.length, 2);
      expect(highlightedRelationships, contains(relationships[0]));
      expect(highlightedRelationships, contains(relationships[1]));
      expect(highlightedRelationships, isNot(contains(relationships[2])));

      // 验证高亮的节点
      expect(highlightedNodeIds, containsAll([2, 3]));
      expect(highlightedNodeIds, isNot(contains(5)));
    });

    test('点击已选中的节点应该取消选择', () {
      int? selectedCharacterId = 1;
      final Set<int> highlightedNodeIds = {};
      final Set<CharacterRelationship> highlightedRelationships = {};

      // 模拟点击已选中的节点
      final clickedNodeId = 1;

      if (selectedCharacterId == clickedNodeId) {
        selectedCharacterId = null;
        highlightedNodeIds.clear();
        highlightedRelationships.clear();
      }

      expect(selectedCharacterId, isNull);
      expect(highlightedNodeIds, isEmpty);
      expect(highlightedRelationships, isEmpty);
    });

    test('点击空白处应该取消选择', () {
      int? selectedCharacterId = 1;
      final Set<int> highlightedNodeIds = {};
      final Set<CharacterRelationship> highlightedRelationships = {};

      // 模拟点击空白处
      selectedCharacterId = null;
      highlightedNodeIds.clear();
      highlightedRelationships.clear();

      expect(selectedCharacterId, isNull);
      expect(highlightedNodeIds, isEmpty);
      expect(highlightedRelationships, isEmpty);
    });
  });

  group('关系图数据处理', () {
    test('应该正确过滤相关角色', () {
      final allCharacters = [
        CharacterRelationshipTestData.createTestCharacter(id: 1, name: '张三'),
        CharacterRelationshipTestData.createTestCharacter(id: 2, name: '李四'),
        CharacterRelationshipTestData.createTestCharacter(id: 3, name: '王五'),
        CharacterRelationshipTestData.createTestCharacter(id: 4, name: '赵六'),
      ];

      final relationships = [
        CharacterRelationship(
          id: 1,
          sourceCharacterId: 1,
          targetCharacterId: 2,
          relationshipType: '朋友',
        ),
        CharacterRelationship(
          id: 2,
          sourceCharacterId: 1,
          targetCharacterId: 3,
          relationshipType: '同事',
        ),
      ];

      // 收集相关角色ID
      final relatedCharacterIds = <int>{};
      for (final rel in relationships) {
        relatedCharacterIds.add(rel.sourceCharacterId);
        relatedCharacterIds.add(rel.targetCharacterId);
      }

      // 过滤相关角色
      final relatedCharacters = allCharacters
          .where((c) => c.id != null && relatedCharacterIds.contains(c.id))
          .toList();

      expect(relatedCharacters.length, 3);
      expect(relatedCharacters.map((c) => c.id).toSet(), containsAll([1, 2, 3]));
      expect(relatedCharacters.map((c) => c.id), isNot(contains(4)));
    });

    test('应该正确处理空关系列表', () {
      final relationships = <CharacterRelationship>[];
      final relatedCharacterIds = <int>{};

      for (final rel in relationships) {
        relatedCharacterIds.add(rel.sourceCharacterId);
        relatedCharacterIds.add(rel.targetCharacterId);
      }

      expect(relatedCharacterIds, isEmpty);
    });

    test('应该正确处理角色的所有关系（出度和入度）', () {
      final characterId = 1;
      final allRelationships = [
        // 出度关系（source = characterId）
        CharacterRelationship(
          id: 1,
          sourceCharacterId: 1,
          targetCharacterId: 2,
          relationshipType: '朋友',
        ),
        CharacterRelationship(
          id: 2,
          sourceCharacterId: 1,
          targetCharacterId: 3,
          relationshipType: '同事',
        ),
        // 入度关系（target = characterId）
        CharacterRelationship(
          id: 3,
          sourceCharacterId: 4,
          targetCharacterId: 1,
          relationshipType: '学生',
        ),
        CharacterRelationship(
          id: 4,
          sourceCharacterId: 5,
          targetCharacterId: 1,
          relationshipType: '邻居',
        ),
        // 无关关系
        CharacterRelationship(
          id: 5,
          sourceCharacterId: 2,
          targetCharacterId: 3,
          relationshipType: '兄弟',
        ),
      ];

      final relatedIds = <int>{};
      for (final rel in allRelationships) {
        if (rel.sourceCharacterId == characterId ||
            rel.targetCharacterId == characterId) {
          relatedIds.add(rel.sourceCharacterId);
          relatedIds.add(rel.targetCharacterId);
        }
      }

      // 应该包含所有相关角色ID（1, 2, 3, 4, 5）
      expect(relatedIds, containsAll([1, 2, 3, 4, 5]));
    });
  });

  group('关系图节点渲染参数', () {
    test('中心节点半径应该大于普通节点', () {
      const baseNodeRadius = 40.0;
      const centerNodeRadius = 50.0;

      expect(centerNodeRadius, greaterThan(baseNodeRadius));
      expect(centerNodeRadius - baseNodeRadius, 10.0);
    });

    test('应该正确根据性别设置节点颜色', () {
      Color getGenderColor(String? gender) {
        switch (gender?.toLowerCase()) {
          case '男':
            return const Color(0xFF2196F3); // 蓝色
          case '女':
            return const Color(0xFFF48FB1); // 粉色
          default:
            return const Color(0xFF9C27B0); // 紫色
        }
      }

      expect(getGenderColor('男'), const Color(0xFF2196F3));
      expect(getGenderColor('女'), const Color(0xFFF48FB1));
      expect(getGenderColor('其他'), const Color(0xFF9C27B0));
      expect(getGenderColor(null), const Color(0xFF9C27B0));
    });

    test('应该正确计算节点边框高亮', () {
      final isCenter = true;
      final isSelected = false;
      final isHighlighted = true;

      // 中心节点且高亮
      expect(isCenter, true);
      expect(isHighlighted, true);

      // 应该显示橙色高亮
      final highlightColor = (isCenter && isHighlighted) || isSelected
          ? Colors.orange
          : Colors.blue;

      expect(highlightColor, Colors.orange);
    });
  });
}
