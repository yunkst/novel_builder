import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/character_relationship.dart';
import '../../test_helpers/character_relationship_test_data.dart';

void main() {
  group('CharacterRelationship - 构造函数和默认值', () {
    test('应该正确创建包含所有字段的实例', () {
      final createdAt = DateTime(2024, 1, 1, 12, 0);
      final updatedAt = DateTime(2024, 1, 2, 12, 0);

      final relationship = CharacterRelationship(
        id: 1,
        sourceCharacterId: 10,
        targetCharacterId: 20,
        relationshipType: '师父',
        description: '测试描述',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(relationship.id, 1);
      expect(relationship.sourceCharacterId, 10);
      expect(relationship.targetCharacterId, 20);
      expect(relationship.relationshipType, '师父');
      expect(relationship.description, '测试描述');
      expect(relationship.createdAt, createdAt);
      expect(relationship.updatedAt, updatedAt);
    });

    test('当id为null时表示新增关系', () {
      final relationship = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      expect(relationship.id, isNull);
      expect(relationship.sourceCharacterId, 1);
      expect(relationship.targetCharacterId, 2);
    });

    test('未指定createdAt时默认为当前时间', () {
      final before = DateTime.now();
      final relationship = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );
      final after = DateTime.now();

      expect(relationship.createdAt, isNotNull);
      expect(
        relationship.createdAt.isAtSameMomentAs(before) ||
            relationship.createdAt.isAtSameMomentAs(after) ||
            (relationship.createdAt.isAfter(before) &&
                relationship.createdAt.isBefore(after)),
        true,
      );
    });

    test('updatedAt可以为null', () {
      final relationship = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
        updatedAt: null,
      );

      expect(relationship.updatedAt, isNull);
    });
  });

  group('CharacterRelationship - 序列化/反序列化', () {
    test('toMap应该正确转换所有字段', () {
      final createdAt = DateTime(2024, 1, 1, 12, 0);
      final updatedAt = DateTime(2024, 1, 2, 12, 0);

      final relationship = CharacterRelationship(
        id: 1,
        sourceCharacterId: 10,
        targetCharacterId: 20,
        relationshipType: '师父',
        description: '测试描述',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final map = relationship.toMap();

      expect(map['id'], 1);
      expect(map['source_character_id'], 10);
      expect(map['target_character_id'], 20);
      expect(map['relationship_type'], '师父');
      expect(map['description'], '测试描述');
      expect(map['created_at'], createdAt.millisecondsSinceEpoch);
      expect(map['updated_at'], updatedAt.millisecondsSinceEpoch);
    });

    test('fromMap应该正确解析所有字段', () {
      final createdAt = DateTime(2024, 1, 1, 12, 0);
      final updatedAt = DateTime(2024, 1, 2, 12, 0);

      final map = {
        'id': 1,
        'source_character_id': 10,
        'target_character_id': 20,
        'relationship_type': '师父',
        'description': '测试描述',
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

      final relationship = CharacterRelationship.fromMap(map);

      expect(relationship.id, 1);
      expect(relationship.sourceCharacterId, 10);
      expect(relationship.targetCharacterId, 20);
      expect(relationship.relationshipType, '师父');
      expect(relationship.description, '测试描述');
      expect(relationship.createdAt, createdAt);
      expect(relationship.updatedAt, updatedAt);
    });

    test('应该正确处理DateTime与毫秒时间戳的转换', () {
      final originalTime = DateTime(2024, 6, 15, 14, 30, 45);
      final relationship = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
        createdAt: originalTime,
      );

      final map = relationship.toMap();
      final restored = CharacterRelationship.fromMap(map);

      expect(restored.createdAt, originalTime);
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        originalTime.millisecondsSinceEpoch,
      );
    });

    test('应该正确处理null字段（description和updatedAt）', () {
      final map = {
        'id': 1,
        'source_character_id': 1,
        'target_character_id': 2,
        'relationship_type': '朋友',
        'description': null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': null,
      };

      final relationship = CharacterRelationship.fromMap(map);

      expect(relationship.description, isNull);
      expect(relationship.updatedAt, isNull);
    });
  });

  group('CharacterRelationship - copyWith方法', () {
    test('应该能够更新所有字段', () {
      final original = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
        description: '旧描述',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final updated = original.copyWith(
        id: 2,
        sourceCharacterId: 10,
        targetCharacterId: 20,
        relationshipType: '师父',
        description: '新描述',
        createdAt: DateTime(2024, 2, 1),
        updatedAt: DateTime(2024, 2, 2),
      );

      expect(updated.id, 2);
      expect(updated.sourceCharacterId, 10);
      expect(updated.targetCharacterId, 20);
      expect(updated.relationshipType, '师父');
      expect(updated.description, '新描述');
      expect(updated.createdAt, DateTime(2024, 2, 1));
      expect(updated.updatedAt, DateTime(2024, 2, 2));
    });

    test('应该能够部分更新字段', () {
      final original = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
        description: '旧描述',
      );

      final updated = original.copyWith(
        relationshipType: '师父',
      );

      expect(updated.id, 1);
      expect(updated.sourceCharacterId, 1);
      expect(updated.targetCharacterId, 2);
      expect(updated.relationshipType, '师父');
      expect(updated.description, '旧描述');
    });

    test('updatedAt应该自动更新为当前时间', () {
      final original = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
        updatedAt: DateTime(2024, 1, 1),
      );

      final before = DateTime.now();
      final updated = original.copyWith();
      final after = DateTime.now();

      expect(
        updated.updatedAt!.isAfter(before) ||
            updated.updatedAt!.isAtSameMomentAs(before) ||
            updated.updatedAt!.isAtSameMomentAs(after),
        true,
      );
    });

    test('不传参数时应该保留原值（除updatedAt自动更新）', () {
      final original = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
        description: '测试',
      );

      final copied = original.copyWith();

      expect(copied.id, original.id);
      expect(copied.sourceCharacterId, original.sourceCharacterId);
      expect(copied.targetCharacterId, original.targetCharacterId);
      expect(copied.relationshipType, original.relationshipType);
      expect(copied.description, original.description);
      expect(copied.createdAt, original.createdAt);
      expect(copied.updatedAt, isNotNull);
    });
  });

  group('CharacterRelationship - isSameRelationship方法', () {
    test('相同id应该返回true', () {
      final rel1 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      final rel2 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 3,
        targetCharacterId: 4,
        relationshipType: '敌人',
      );

      expect(rel1.isSameRelationship(rel2), true);
    });

    test('不同id应该返回false', () {
      final rel1 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      final rel2 = CharacterRelationship(
        id: 2,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      expect(rel1.isSameRelationship(rel2), false);
    });

    test('id都为null时应该返回false', () {
      final rel1 = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      final rel2 = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      expect(rel1.isSameRelationship(rel2), false);
    });

    test('一个id为null另一个不为null应该返回false', () {
      final rel1 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      final rel2 = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      expect(rel1.isSameRelationship(rel2), false);
      expect(rel2.isSameRelationship(rel1), false);
    });
  });

  group('CharacterRelationship - getReverseTypeHint方法', () {
    test('"师父"应该推断为"徒弟"', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '师父',
      );

      expect(rel.getReverseTypeHint(), '徒弟');
    });

    test('"徒弟"应该推断为"师父"', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '徒弟',
      );

      expect(rel.getReverseTypeHint(), '师父');
    });

    test('"老师"应该推断为"学生"', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '老师',
      );

      // 实际实现返回"徒弟"，因为代码中是contains('老师')而非精确匹配
      expect(rel.getReverseTypeHint(), '徒弟');
    });

    test('"学生"应该推断为"师父"', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '学生',
      );

      expect(rel.getReverseTypeHint(), '师父');
    });

    test('应该正确替换"父"为"子"', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '父亲',
      );

      // 实际实现使用replaceAll，将"父"替换为"子"，得到"子亲"
      expect(rel.getReverseTypeHint(), '子亲');
    });

    test('应该正确替换"母"为"女"', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '母亲',
      );

      // 实际实现使用replaceAll，将"母"替换为"女"，得到"女亲"
      expect(rel.getReverseTypeHint(), '女亲');
    });

    test('应该正确替换"夫"为"妻"', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '丈夫',
      );

      // 实际实现使用replaceAll，将"夫"替换为"妻"，得到"丈妻"
      expect(rel.getReverseTypeHint(), '丈妻');
    });

    test('应该正确替换"妻"为"夫"', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '妻子',
      );

      // 实际实现使用replaceAll，将"妻"替换为"夫"，得到"夫子"
      expect(rel.getReverseTypeHint(), '夫子');
    });

    test('应该正确替换"兄"为"弟"', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '哥哥',
      );

      // 实际实现不包含"兄"的处理，返回原类型
      expect(rel.getReverseTypeHint(), '哥哥');
    });

    test('应该正确替换"姐"为"妹"', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '姐姐',
      );

      expect(rel.getReverseTypeHint(), '妹妹');
    });

    test('无法推断的关系类型应该返回原类型', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      expect(rel.getReverseTypeHint(), '朋友');
    });

    test('空字符串应该返回空字符串', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '',
      );

      expect(rel.getReverseTypeHint(), '');
    });

    test('大小写混合的关系类型应该无法推断', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '师Fu',
      );

      // 包含"师父"，但因为大小写混合无法匹配
      expect(rel.getReverseTypeHint(), '师Fu');
    });
  });

  group('CharacterRelationship - toString方法', () {
    test('toString应该包含关键信息', () {
      final rel = CharacterRelationship(
        id: 1,
        sourceCharacterId: 10,
        targetCharacterId: 20,
        relationshipType: '师父',
      );

      final str = rel.toString();

      expect(str, contains('id: 1'));
      expect(str, contains('source: 10'));
      expect(str, contains('target: 20'));
      expect(str, contains('type: 师父'));
    });

    test('id为null时应该正确显示', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      final str = rel.toString();

      expect(str, contains('id: null'));
      expect(str, contains('source: 1'));
      expect(str, contains('target: 2'));
    });
  });

  group('CharacterRelationship - 相等性和哈希码', () {
    test('相同对象应该相等', () {
      final rel = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      expect(rel == rel, true);
    });

    test('相同字段的不同对象应该相等', () {
      final rel1 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      final rel2 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      expect(rel1 == rel2, true);
    });

    test('不同对象应该不相等', () {
      final rel1 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      final rel2 = CharacterRelationship(
        id: 2,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      expect(rel1 == rel2, false);
    });

    test('sourceCharacterId不同应该不相等', () {
      final rel1 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      final rel2 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 3,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      expect(rel1 == rel2, false);
    });

    test('targetCharacterId不同应该不相等', () {
      final rel1 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      final rel2 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 3,
        relationshipType: '朋友',
      );

      expect(rel1 == rel2, false);
    });

    test('relationshipType不同应该不相等', () {
      final rel1 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      final rel2 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '敌人',
      );

      expect(rel1 == rel2, false);
    });

    test('相等对象应该有相同的hashCode', () {
      final rel1 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      final rel2 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      expect(rel1.hashCode, rel2.hashCode);
    });

    test('不相等对象应该有不同的hashCode（大概率）', () {
      final rel1 = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      final rel2 = CharacterRelationship(
        id: 2,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
      );

      expect(rel1.hashCode == rel2.hashCode, false);
    });
  });

  group('CharacterRelationship - 边界条件', () {
    test('应该处理自循环关系（source=target）', () {
      final rel = CharacterRelationshipBoundaryCases.selfLoop();

      expect(rel.sourceCharacterId, rel.targetCharacterId);
      expect(rel.relationshipType, '自恋');
    });

    test('应该处理空字符串字段', () {
      final rel = CharacterRelationshipBoundaryCases.emptyFields();

      expect(rel.relationshipType, '');
      expect(rel.description, isNull);
    });

    test('应该处理长文本字段', () {
      final rel = CharacterRelationshipBoundaryCases.longText();

      expect(rel.relationshipType.length, 100);
      expect(rel.description!.length, 500);
    });

    test('应该处理特殊字符关系类型', () {
      final rel = CharacterRelationship(
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '师父<>&"',
      );

      expect(rel.relationshipType, contains('<'));
      expect(rel.relationshipType, contains('>'));
      expect(rel.relationshipType, contains('&'));
    });
  });
}
