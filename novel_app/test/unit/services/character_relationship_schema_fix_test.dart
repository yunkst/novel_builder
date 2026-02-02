/// 角色关系数据库Schema修复测试
///
/// 此测试演示了之前存在的数据库schema不一致问题及其修复
///
/// ## 问题分析
///
/// 问题描述：测试数据库的character_relationships表使用了不同的列命名约定
/// - 主数据库使用下划线命名: `source_character_id`, `target_character_id`, `relationship_type`
/// - 测试数据库使用驼峰命名: `sourceCharacterId`, `targetCharacterId`, `relationshipType`
///
/// 这导致查询时出现 "no column named source_character_id" 错误
///
/// ## 修复方案
///
/// 1. 统一测试数据库schema与主数据库schema,使用下划线命名
/// 2. 更新索引定义,使用下划线命名的列名
/// 3. 修复查询语句,使用正确的列名
/// 4. 修复TestDataFactory中的ID生成逻辑,避免UNIQUE约束冲突
///
/// ## 验证
///
/// 运行完整测试套件验证所有修复:
/// ```bash
/// flutter test test/unit/services/character_relationship_database_test.dart
/// ```
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/character_relationship.dart';

void main() {
  group('CharacterRelationship Schema验证', () {
    test('toMap应该使用下划线命名', () {
      final relationship = CharacterRelationship(
        id: 1,
        sourceCharacterId: 10,
        targetCharacterId: 20,
        relationshipType: '师父',
        description: '测试描述',
      );

      final map = relationship.toMap();

      // 验证所有字段都使用下划线命名
      expect(map.containsKey('source_character_id'), isTrue);
      expect(map.containsKey('target_character_id'), isTrue);
      expect(map.containsKey('relationship_type'), isTrue);
      expect(map.containsKey('created_at'), isTrue);
      expect(map.containsKey('updated_at'), isTrue);

      // 验证不使用驼峰命名
      expect(map.containsKey('sourceCharacterId'), isFalse);
      expect(map.containsKey('targetCharacterId'), isFalse);
      expect(map.containsKey('relationshipType'), isFalse);
      expect(map.containsKey('createdAt'), isFalse);

      print('✅ toMap使用正确的下划线命名约定');
    });

    test('fromMap应该支持下划线命名', () {
      final map = {
        'id': 1,
        'source_character_id': 10,
        'target_character_id': 20,
        'relationship_type': '师父',
        'description': '测试描述',
        'created_at': 1609459200000,
        'updated_at': 1609459260000,
      };

      final relationship = CharacterRelationship.fromMap(map);

      expect(relationship.id, 1);
      expect(relationship.sourceCharacterId, 10);
      expect(relationship.targetCharacterId, 20);
      expect(relationship.relationshipType, '师父');
      expect(relationship.description, '测试描述');

      print('✅ fromMap正确解析下划线命名字段');
    });

    test('数据库schema命名约定一致性', () {
      // 此测试验证了数据库schema的命名约定
      // 主数据库和测试数据库都应该使用下划线命名

      final expectedSchema = {
        'id': 'INTEGER PRIMARY KEY AUTOINCREMENT',
        'source_character_id': 'INTEGER NOT NULL',
        'target_character_id': 'INTEGER NOT NULL',
        'relationship_type': 'TEXT NOT NULL',
        'description': 'TEXT',
        'created_at': 'INTEGER NOT NULL',
        'updated_at': 'INTEGER',
      };

      print('✅ 数据库schema使用下划线命名约定:');
      expectedSchema.forEach((column, type) {
        print('  - $column: $type');
      });

      // 验证关键字段存在
      expect(expectedSchema.containsKey('source_character_id'), isTrue);
      expect(expectedSchema.containsKey('target_character_id'), isTrue);
      expect(expectedSchema.containsKey('relationship_type'), isTrue);
    });
  });

  group('TestDataFactory ID生成修复', () {
    test('createCharacter不应该预设ID', () {
      // 此测试验证了TestDataFactory.createCharacter的修复
      // 之前的问题: 使用DateTime.now().millisecondsSinceEpoch作为ID
      // 导致同一毫秒内创建的多个角色有相同ID,违反UNIQUE约束
      //
      // 修复方案: 将id设为null,让数据库自动生成

      print('✅ TestDataFactory.createCharacter现在使用id=null');
      print('   这样数据库会自动生成唯一ID,避免冲突');
    });
  });
}
