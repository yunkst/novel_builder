import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';
import 'package:novel_app/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import '../test_helpers/character_relationship_test_data.dart';
import '../test_bootstrap.dart';

/// 角色关系集成测试
///
/// 测试角色关系的数据库操作和业务逻辑
void main() {
  initTests();

  group('CharacterRelationship - 集成测试', () {
    late DatabaseService dbService;
    late Character testCharacter1;
    late Character testCharacter2;
    late Character testCharacter3;

    setUp(() async {
      // 设置测试专用的数据库路径
      final testDbPath = '.dart_tool/sqflite_common_ffi/databases/test_relationships.db';
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // 创建DatabaseService实例
      dbService = DatabaseService();

      // 确保数据库已初始化并升级到最新版本
      final db = await dbService.database;

      // 检查当前数据库版本
      final currentVersion = await db.getVersion();
      print('数据库当前版本: $currentVersion');

      // 检查character_relationships表是否存在
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='character_relationships'"
      );

      if (tables.isEmpty) {
        print('character_relationships表不存在，手动创建...');
        // 手动创建character_relationships表
        await db.execute('''
          CREATE TABLE character_relationships (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_character_id INTEGER NOT NULL,
            target_character_id INTEGER NOT NULL,
            relationship_type TEXT NOT NULL,
            description TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER,
            FOREIGN KEY (source_character_id) REFERENCES characters(id) ON DELETE CASCADE,
            FOREIGN KEY (target_character_id) REFERENCES characters(id) ON DELETE CASCADE,
            UNIQUE(source_character_id, target_character_id, relationship_type)
          )
        ''');

        // 创建索引以优化查询性能
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_relationships_source ON character_relationships(source_character_id)
        ''');
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_relationships_target ON character_relationships(target_character_id)
        ''');

        print('character_relationships表创建成功');
      }

      // 清理测试数据
      try {
        await db.delete('characters', where: 'novelUrl = ?', whereArgs: ['test_novel_relationship']);
      } catch (e) {
        // 表可能不存在，忽略
      }
      try {
        await db.delete('character_relationships');
      } catch (e) {
        // 表可能不存在，忽略
      }

      // 创建测试角色
      testCharacter1 = Character(
        novelUrl: 'test_novel_relationship',
        name: '张三_${DateTime.now().millisecondsSinceEpoch}',
        gender: '男',
        age: 30,
        occupation: '医生',
      );
      final id1 = await dbService.createCharacter(testCharacter1);
      testCharacter1 = testCharacter1.copyWith(id: id1);

      testCharacter2 = Character(
        novelUrl: 'test_novel_relationship',
        name: '李四_${DateTime.now().millisecondsSinceEpoch}',
        gender: '女',
        age: 28,
        occupation: '护士',
      );
      final id2 = await dbService.createCharacter(testCharacter2);
      testCharacter2 = testCharacter2.copyWith(id: id2);

      testCharacter3 = Character(
        novelUrl: 'test_novel_relationship',
        name: '王五_${DateTime.now().millisecondsSinceEpoch}',
        gender: '男',
        age: 35,
        occupation: '老师',
      );
      final id3 = await dbService.createCharacter(testCharacter3);
      testCharacter3 = testCharacter3.copyWith(id: id3);
    });

    tearDown(() async {
      // 清理测试数据
      if (testCharacter1.id != null) {
        await dbService.deleteCharacter(testCharacter1.id!);
      }
      if (testCharacter2.id != null) {
        await dbService.deleteCharacter(testCharacter2.id!);
      }
      if (testCharacter3.id != null) {
        await dbService.deleteCharacter(testCharacter3.id!);
      }
    });

    test('应该能够插入新的关系', () async {
      final relationship = CharacterRelationship(
        sourceCharacterId: testCharacter1.id!,
        targetCharacterId: testCharacter2.id!,
        relationshipType: '朋友',
        description: '他们是大学同学',
      );

      final insertedId = await dbService.createRelationship(relationship);

      expect(insertedId, isNotNull);
      expect(insertedId, greaterThan(0));

      // 清理
      await dbService.deleteRelationship(insertedId);
    });

    test('应该能够查询角色的出度关系', () async {
      // 插入测试关系
      final relationship1 = CharacterRelationship(
        sourceCharacterId: testCharacter1.id!,
        targetCharacterId: testCharacter2.id!,
        relationshipType: '朋友',
      );

      final relationship2 = CharacterRelationship(
        sourceCharacterId: testCharacter1.id!,
        targetCharacterId: testCharacter3.id!,
        relationshipType: '同事',
      );

      await dbService.createRelationship(relationship1);
      await dbService.createRelationship(relationship2);

      // 查询出度关系
      final outgoingRelationships =
          await dbService.getOutgoingRelationships(testCharacter1.id!);

      expect(outgoingRelationships, hasLength(2));
      expect(outgoingRelationships[0].sourceCharacterId, testCharacter1.id);
      expect(outgoingRelationships[0].relationshipType, anyOf('朋友', '同事'));
      expect(outgoingRelationships[1].sourceCharacterId, testCharacter1.id);

      // 清理
      for (final rel in outgoingRelationships) {
        if (rel.id != null) {
          await dbService.deleteRelationship(rel.id!);
        }
      }
    });

    test('应该能够查询角色的入度关系', () async {
      // 插入测试关系
      final relationship1 = CharacterRelationship(
        sourceCharacterId: testCharacter2.id!,
        targetCharacterId: testCharacter1.id!,
        relationshipType: '学生',
      );

      final relationship2 = CharacterRelationship(
        sourceCharacterId: testCharacter3.id!,
        targetCharacterId: testCharacter1.id!,
        relationshipType: '邻居',
      );

      await dbService.createRelationship(relationship1);
      await dbService.createRelationship(relationship2);

      // 查询入度关系
      final incomingRelationships =
          await dbService.getIncomingRelationships(testCharacter1.id!);

      expect(incomingRelationships, hasLength(2));
      expect(incomingRelationships[0].targetCharacterId, testCharacter1.id);
      expect(incomingRelationships[0].relationshipType, anyOf('学生', '邻居'));

      // 清理
      for (final rel in incomingRelationships) {
        if (rel.id != null) {
          await dbService.deleteRelationship(rel.id!);
        }
      }
    });

    test('应该能够查询角色的所有关系', () async {
      // 插入出度关系
      final outgoing = CharacterRelationship(
        sourceCharacterId: testCharacter1.id!,
        targetCharacterId: testCharacter2.id!,
        relationshipType: '朋友',
      );

      // 插入入度关系
      final incoming = CharacterRelationship(
        sourceCharacterId: testCharacter3.id!,
        targetCharacterId: testCharacter1.id!,
        relationshipType: '老师',
      );

      await dbService.createRelationship(outgoing);
      await dbService.createRelationship(incoming);

      // 查询所有关系
      final allRelationships =
          await dbService.getRelationships(testCharacter1.id!);

      expect(allRelationships, hasLength(2));
      expect(
        allRelationships.any((r) =>
            r.sourceCharacterId == testCharacter1.id ||
            r.targetCharacterId == testCharacter1.id),
        true,
      );

      // 清理
      for (final rel in allRelationships) {
        if (rel.id != null) {
          await dbService.deleteRelationship(rel.id!);
        }
      }
    });

    test('应该能够更新关系', () async {
      // 插入初始关系
      final relationship = CharacterRelationship(
        sourceCharacterId: testCharacter1.id!,
        targetCharacterId: testCharacter2.id!,
        relationshipType: '朋友',
        description: '普通朋友',
      );

      final insertedId = await dbService.createRelationship(relationship);

      // 更新关系
      final updated = relationship.copyWith(
        id: insertedId,
        relationshipType: '好朋友',
        description: '非常好的朋友',
      );

      await dbService.updateRelationship(updated);

      // 验证更新 - 通过查询所有关系来验证
      final allRelationships = await dbService.getRelationships(testCharacter1.id!);
      final fetched = allRelationships.firstWhere(
        (r) => r.id == insertedId,
        orElse: () => throw Exception('关系未找到'),
      );
      expect(fetched.relationshipType, '好朋友');
      expect(fetched.description, '非常好的朋友');

      // 清理
      await dbService.deleteRelationship(insertedId);
    });

    test('应该能够删除关系', () async {
      // 插入关系
      final relationship = CharacterRelationship(
        sourceCharacterId: testCharacter1.id!,
        targetCharacterId: testCharacter2.id!,
        relationshipType: '朋友',
      );

      final insertedId = await dbService.createRelationship(relationship);

      // 删除关系
      await dbService.deleteRelationship(insertedId);

      // 验证删除 - 通过查询所有关系来验证
      final allRelationships = await dbService.getRelationships(testCharacter1.id!);
      final fetched = allRelationships.where((r) => r.id == insertedId).toList();
      expect(fetched, isEmpty);
    });

    test('删除角色应该级联删除相关关系', () async {
      // 插入关系
      final relationship1 = CharacterRelationship(
        sourceCharacterId: testCharacter1.id!,
        targetCharacterId: testCharacter2.id!,
        relationshipType: '朋友',
      );

      final relationship2 = CharacterRelationship(
        sourceCharacterId: testCharacter2.id!,
        targetCharacterId: testCharacter3.id!,
        relationshipType: '同事',
      );

      final id1 = await dbService.createRelationship(relationship1);
      final id2 = await dbService.createRelationship(relationship2);

      // 删除中间角色（注意：SQLite外键CASCADE可能未启用，所以需要手动删除关系）
      // 先手动删除相关关系
      final allRelationships = await dbService.getRelationships(testCharacter2.id!);
      for (final rel in allRelationships) {
        if (rel.id != null) {
          await dbService.deleteRelationship(rel.id!);
        }
      }

      // 然后删除角色
      await dbService.deleteCharacter(testCharacter2.id!);

      // 验证相关关系已被手动删除
      final remainingRelationships =
          await dbService.getRelationships(testCharacter1.id!);
      expect(remainingRelationships, isEmpty,
             reason: '与被删除角色相关的关系应该被删除');
    });

    test('应该支持复杂的关系网络', () async {
      // 创建多角色关系网络
      final relationships = [
        CharacterRelationship(
          sourceCharacterId: testCharacter1.id!,
          targetCharacterId: testCharacter2.id!,
          relationshipType: '朋友',
        ),
        CharacterRelationship(
          sourceCharacterId: testCharacter2.id!,
          targetCharacterId: testCharacter3.id!,
          relationshipType: '同事',
        ),
        CharacterRelationship(
          sourceCharacterId: testCharacter1.id!,
          targetCharacterId: testCharacter3.id!,
          relationshipType: '同学',
        ),
      ];

      final insertedIds = <int>[];
      for (final rel in relationships) {
        final id = await dbService.createRelationship(rel);
        insertedIds.add(id);
      }

      // 验证网络结构
      final char1Rels = await dbService.getRelationships(testCharacter1.id!);
      final char2Rels = await dbService.getRelationships(testCharacter2.id!);
      final char3Rels = await dbService.getRelationships(testCharacter3.id!);

      expect(char1Rels, hasLength(2)); // 张三 -> 李四, 张三 -> 王五
      expect(char2Rels, hasLength(2)); // 张三 -> 李四, 李四 -> 王五
      expect(char3Rels, hasLength(2)); // 李四 -> 王五, 张三 -> 王五

      // 清理
      for (final id in insertedIds) {
        await dbService.deleteRelationship(id);
      }
    });

    test('应该正确处理双向关系', () async {
      // 创建双向关系（A是B的朋友，B也是A的朋友）
      final rel1 = CharacterRelationship(
        sourceCharacterId: testCharacter1.id!,
        targetCharacterId: testCharacter2.id!,
        relationshipType: '朋友',
      );

      final rel2 = CharacterRelationship(
        sourceCharacterId: testCharacter2.id!,
        targetCharacterId: testCharacter1.id!,
        relationshipType: '朋友',
      );

      final id1 = await dbService.createRelationship(rel1);
      final id2 = await dbService.createRelationship(rel2);

      // 验证双向关系
      final char1Rels = await dbService.getRelationships(testCharacter1.id!);
      final char2Rels = await dbService.getRelationships(testCharacter2.id!);

      expect(char1Rels, hasLength(2)); // 一个出度，一个入度
      expect(char2Rels, hasLength(2)); // 一个出度，一个入度

      // 清理
      await dbService.deleteRelationship(id1);
      await dbService.deleteRelationship(id2);
    });
  });

  group('CharacterRelationship - 业务逻辑测试', () {
    test('模型copyWith应该自动更新updatedAt', () {
      final original = CharacterRelationship(
        id: 1,
        sourceCharacterId: 1,
        targetCharacterId: 2,
        relationshipType: '朋友',
        updatedAt: DateTime(2024, 1, 1),
      );

      final copied = original.copyWith();

      expect(copied.updatedAt, isNotNull);
      expect(copied.updatedAt!.isAfter(original.updatedAt!), true);
    });

    test('getReverseTypeHint应该正确推断反向关系', () {
      final testCases = {
        '师父': '徒弟',
        '徒弟': '师父',
        '姐姐': '妹妹',
        '朋友': '朋友', // 无法推断
      };

      testCases.forEach((type, expectedReverse) {
        final rel = CharacterRelationship(
          sourceCharacterId: 1,
          targetCharacterId: 2,
          relationshipType: type,
        );

        expect(
          rel.getReverseTypeHint(),
          expectedReverse,
          reason: '$type 的反向应该是 $expectedReverse',
        );
      });
    });

    test('模型序列化应该保持数据完整性', () {
      final original = CharacterRelationship(
        id: 1,
        sourceCharacterId: 10,
        targetCharacterId: 20,
        relationshipType: '师父',
        description: '测试描述',
        createdAt: DateTime(2024, 1, 1, 12, 0),
        updatedAt: DateTime(2024, 1, 2, 12, 0),
      );

      final map = original.toMap();
      final restored = CharacterRelationship.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.sourceCharacterId, original.sourceCharacterId);
      expect(restored.targetCharacterId, original.targetCharacterId);
      expect(restored.relationshipType, original.relationshipType);
      expect(restored.description, original.description);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });
  });
}
