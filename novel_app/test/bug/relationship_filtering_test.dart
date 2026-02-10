import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';

void main() {
  group('关系过滤逻辑测试', () {
    test('应该过滤掉包含未出现角色的关系', () {
      // 数据库中有3个角色
      final allCharacters = [
        Character(id: 1, novelUrl: 'test', name: '张三'),
        Character(id: 2, novelUrl: 'test', name: '李四'),
        Character(id: 3, novelUrl: 'test', name: '王五'),
      ];

      // 关系：张三 → 师徒 → 王五
      final allRelationships = [
        CharacterRelationship(
          id: 1,
          sourceCharacterId: 1, // 张三
          targetCharacterId: 3, // 王五
          relationshipType: '师徒',
        ),
      ];

      // 本章只出现了张三和李四
      final chapterCharacters = [
        allCharacters[0], // 张三
        allCharacters[1], // 李四
      ];

      // 模拟 FormatRelationshipsForAI 的过滤逻辑
      final Map<int, String> characterIdToName = {
        for (var c in chapterCharacters)
          if (c.id != null) c.id!: c.name,
      };

      // 过滤掉包含未出现角色的关系
      final validRelationships = allRelationships.where((r) {
        return characterIdToName.containsKey(r.sourceCharacterId) &&
            characterIdToName.containsKey(r.targetCharacterId);
      });

      // 格式化
      final relations = validRelationships.map((r) {
        final sourceName = characterIdToName[r.sourceCharacterId]!;
        final targetName = characterIdToName[r.targetCharacterId]!;
        return '$sourceName → ${r.relationshipType} → $targetName';
      }).join('\n');

      print('=== 测试结果 ===');
      print('本章角色: ${chapterCharacters.map((c) => c.name).join(", ")}');
      print('原始关系数: ${allRelationships.length}');
      print('过滤后关系数: ${validRelationships.length}');
      print('格式化结果: "$relations"');

      // 验证：关系被过滤，结果为空
      expect(validRelationships.isEmpty, isTrue);
      expect(relations, isEmpty);
      expect(relations, isNot(contains('未知角色')));

      print('✅ 测试通过：包含未出现角色的关系已被过滤');
    });

    test('应该保留所有角色都出现的关系', () {
      final allCharacters = [
        Character(id: 1, novelUrl: 'test', name: '张三'),
        Character(id: 2, novelUrl: 'test', name: '李四'),
      ];

      final allRelationships = [
        CharacterRelationship(
          id: 1,
          sourceCharacterId: 1,
          targetCharacterId: 2,
          relationshipType: '恋人',
        ),
      ];

      // 本章两个角色都出现了
      final chapterCharacters = allCharacters;

      final Map<int, String> characterIdToName = {
        for (var c in chapterCharacters)
          if (c.id != null) c.id!: c.name,
      };

      final validRelationships = allRelationships.where((r) {
        return characterIdToName.containsKey(r.sourceCharacterId) &&
            characterIdToName.containsKey(r.targetCharacterId);
      });

      final relations = validRelationships.map((r) {
        final sourceName = characterIdToName[r.sourceCharacterId]!;
        final targetName = characterIdToName[r.targetCharacterId]!;
        return '$sourceName → ${r.relationshipType} → $targetName';
      }).join('\n');

      print('=== 测试结果 ===');
      print('本章角色: ${chapterCharacters.map((c) => c.name).join(", ")}');
      print('关系数: ${validRelationships.length}');
      print('格式化结果: "$relations"');

      // 验证：关系被保留
      expect(validRelationships.length, 1);
      expect(relations, contains('张三 → 恋人 → 李四'));
      expect(relations, isNot(contains('未知角色')));

      print('✅ 测试通过：有效关系被保留');
    });

    test('应该正确处理混合场景：部分关系有效，部分关系无效', () {
      final allCharacters = [
        Character(id: 1, novelUrl: 'test', name: '主角'),
        Character(id: 2, novelUrl: 'test', name: '师父'),
        Character(id: 3, novelUrl: 'test', name: '师祖'),
      ];

      final allRelationships = [
        CharacterRelationship(
          id: 1,
          sourceCharacterId: 2, // 师父
          targetCharacterId: 3, // 师祖（未出现）
          relationshipType: '师徒',
        ),
        CharacterRelationship(
          id: 2,
          sourceCharacterId: 1, // 主角
          targetCharacterId: 2, // 师父
          relationshipType: '师徒',
        ),
      ];

      // 本章只出现了主角和师父
      final chapterCharacters = [
        allCharacters[0], // 主角
        allCharacters[1], // 师父
      ];

      final Map<int, String> characterIdToName = {
        for (var c in chapterCharacters)
          if (c.id != null) c.id!: c.name,
      };

      final validRelationships = allRelationships.where((r) {
        return characterIdToName.containsKey(r.sourceCharacterId) &&
            characterIdToName.containsKey(r.targetCharacterId);
      });

      final relations = validRelationships.map((r) {
        final sourceName = characterIdToName[r.sourceCharacterId]!;
        final targetName = characterIdToName[r.targetCharacterId]!;
        return '$sourceName → ${r.relationshipType} → $targetName';
      }).join('\n');

      print('=== 测试结果 ===');
      print('本章角色: ${chapterCharacters.map((c) => c.name).join(", ")}');
      print('原始关系数: ${allRelationships.length}');
      print('过滤后关系数: ${validRelationships.length}');
      print('过滤掉的关系数: ${allRelationships.length - validRelationships.length}');
      print('格式化结果:\n$relations');

      // 验证：只有第二条关系被保留
      expect(validRelationships.length, 1);
      expect(relations, contains('主角 → 师徒 → 师父'));
      expect(relations, isNot(contains('未知角色')));

      print('✅ 测试通过：混合场景处理正确');
    });

    test('应该记录被过滤的关系数量', () {
      final allRelationships = [
        CharacterRelationship(
            id: 1,
            sourceCharacterId: 1,
            targetCharacterId: 3,
            relationshipType: '师徒'),
        CharacterRelationship(
            id: 2,
            sourceCharacterId: 2,
            targetCharacterId: 3,
            relationshipType: '师徒'),
        CharacterRelationship(
            id: 3,
            sourceCharacterId: 1,
            targetCharacterId: 2,
            relationshipType: '朋友'),
      ];

      final chapterCharacters = [
        Character(id: 1, novelUrl: 'test', name: '张三'),
        Character(id: 2, novelUrl: 'test', name: '李四'),
        // 王五(id=3)未出现
      ];

      final Map<int, String> characterIdToName = {
        for (var c in chapterCharacters)
          if (c.id != null) c.id!: c.name,
      };

      final validRelationships = allRelationships.where((r) {
        return characterIdToName.containsKey(r.sourceCharacterId) &&
            characterIdToName.containsKey(r.targetCharacterId);
      }).toList();

      final filteredCount = allRelationships.length - validRelationships.length;

      print('=== 测试结果 ===');
      print('原始关系数: ${allRelationships.length}');
      print('过滤后关系数: ${validRelationships.length}');
      print('过滤掉的关系数: $filteredCount');

      // 验证：过滤了2条关系（1→3 和 2→3）
      expect(filteredCount, 2);
      expect(validRelationships.length, 1);

      print('✅ 测试通过：正确统计被过滤的关系数量');
    });
  });
}
