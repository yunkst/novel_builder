import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/models/character.dart';
import 'package:novel_app/models/character_relationship.dart';
import 'package:novel_app/services/database_service.dart';
import '../../base/database_test_base.dart';

/// CharacterRelationship 数据库操作单元测试
///
/// 使用真实SQLite数据库测试关系数据的CRUD操作
/// 这是Widget测试的补充 - Widget测试关注UI，此测试关注数据
void main() {
  group('CharacterRelationship - 数据库操作', () {
    late DatabaseTestBase base;

    setUp(() async {
      base = DatabaseTestBase();
      await base.setUp();
    });

    tearDown(() async {
      await base.tearDown();
    });

    group('getOutgoingRelationships', () {
      test('应该返回角色的所有出度关系', () async {
        // 创建测试数据
        final novel = await base.createAndAddNovel();
        final char1 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '张三',
        );
        final char2 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '李四',
        );
        final char3 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '王五',
        );

        // 创建关系
        await base.createRelationship(
          sourceId: char1.id!,
          targetId: char2.id!,
          relationshipType: '师父',
          description: '张三是李四的师父',
        );
        await base.createRelationship(
          sourceId: char1.id!,
          targetId: char3.id!,
          relationshipType: '朋友',
          description: '张三和王五是朋友',
        );

        // 执行查询
        final result = await base.databaseService
            .getOutgoingRelationships(char1.id!);

        // 验证结果
        expect(result, hasLength(2));
        expect(
          result.any((r) =>
              r.sourceCharacterId == char1.id &&
              r.targetCharacterId == char2.id &&
              r.relationshipType == '师父'),
          isTrue,
        );
        expect(
          result.any((r) =>
              r.sourceCharacterId == char1.id &&
              r.targetCharacterId == char3.id &&
              r.relationshipType == '朋友'),
          isTrue,
        );
      });

      test('应该返回空列表如果角色没有出度关系', () async {
        final novel = await base.createAndAddNovel();
        final char1 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '张三',
        );

        final result = await base.databaseService
            .getOutgoingRelationships(char1.id!);

        expect(result, isEmpty);
      });

      test('应该只返回指定角色的出度关系', () async {
        final novel = await base.createAndAddNovel();
        final char1 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '张三',
        );
        final char2 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '李四',
        );
        final char3 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '王五',
        );

        // char1 → char2
        await base.createRelationship(
          sourceId: char1.id!,
          targetId: char2.id!,
          relationshipType: '师父',
        );
        // char3 → char2
        await base.createRelationship(
          sourceId: char3.id!,
          targetId: char2.id!,
          relationshipType: '徒弟',
        );

        // 查询char1的出度关系
        final result = await base.databaseService
            .getOutgoingRelationships(char1.id!);

        // 应该只返回1条关系
        expect(result, hasLength(1));
        expect(result[0].sourceCharacterId, char1.id);
        expect(result[0].targetCharacterId, char2.id);
        expect(result[0].relationshipType, '师父');
      });
    });

    group('getIncomingRelationships', () {
      test('应该返回角色的所有入度关系', () async {
        final novel = await base.createAndAddNovel();
        final char1 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '张三',
        );
        final char2 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '李四',
        );
        final char3 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '王五',
        );

        // 创建关系
        await base.createRelationship(
          sourceId: char2.id!,
          targetId: char1.id!,
          relationshipType: '徒弟',
        );
        await base.createRelationship(
          sourceId: char3.id!,
          targetId: char1.id!,
          relationshipType: '朋友',
        );

        // 执行查询
        final result = await base.databaseService
            .getIncomingRelationships(char1.id!);

        // 验证结果
        expect(result, hasLength(2));
        expect(
          result.any((r) =>
              r.sourceCharacterId == char2.id &&
              r.targetCharacterId == char1.id &&
              r.relationshipType == '徒弟'),
          isTrue,
        );
        expect(
          result.any((r) =>
              r.sourceCharacterId == char3.id &&
              r.targetCharacterId == char1.id &&
              r.relationshipType == '朋友'),
          isTrue,
        );
      });

      test('应该返回空列表如果角色没有入度关系', () async {
        final novel = await base.createAndAddNovel();
        final char1 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '张三',
        );

        final result = await base.databaseService
            .getIncomingRelationships(char1.id!);

        expect(result, isEmpty);
      });
    });

    group('createRelationship', () {
      test('应该插入新关系并返回ID', () async {
        final novel = await base.createAndAddNovel();
        final char1 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '张三',
        );
        final char2 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '李四',
        );

        final relationship = CharacterRelationship(
          sourceCharacterId: char1.id!,
          targetCharacterId: char2.id!,
          relationshipType: '师父',
          description: '张三是李四的师父',
        );

        final id = await base.databaseService.createRelationship(relationship);

        expect(id, isPositive);
        expect(id, isNotNull);
      });

      test('应该持久化关系到数据库', () async {
        final novel = await base.createAndAddNovel();
        final char1 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '张三',
        );
        final char2 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '李四',
        );

        final relationship = CharacterRelationship(
          sourceCharacterId: char1.id!,
          targetCharacterId: char2.id!,
          relationshipType: '师父',
          description: '描述信息',
        );

        final id = await base.databaseService.createRelationship(relationship);

        // 从数据库读取验证
        final result = await base.databaseService
            .getOutgoingRelationships(char1.id!);

        expect(result, hasLength(1));
        expect(result[0].id, id);
        expect(result[0].relationshipType, '师父');
        expect(result[0].description, '描述信息');
      });
    });

    group('updateRelationship', () {
      test('应该更新关系信息', () async {
        final novel = await base.createAndAddNovel();
        final char1 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '张三',
        );
        final char2 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '李四',
        );

        // 创建关系
        final relationship = await base.createRelationship(
          sourceId: char1.id!,
          targetId: char2.id!,
          relationshipType: '师父',
          description: '原始描述',
        );

        // 更新关系
        final updated = CharacterRelationship(
          id: relationship.id,
          sourceCharacterId: char1.id!,
          targetCharacterId: char2.id!,
          relationshipType: '朋友',
          description: '更新后的描述',
        );

        await base.databaseService.updateRelationship(updated);

        // 验证更新
        final result = await base.databaseService
            .getOutgoingRelationships(char1.id!);

        expect(result, hasLength(1));
        expect(result[0].relationshipType, '朋友');
        expect(result[0].description, '更新后的描述');
      });
    });

    group('deleteRelationship', () {
      test('应该删除关系', () async {
        final novel = await base.createAndAddNovel();
        final char1 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '张三',
        );
        final char2 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '李四',
        );

        final relationship = await base.createRelationship(
          sourceId: char1.id!,
          targetId: char2.id!,
          relationshipType: '师父',
        );

        // 删除前验证存在
        var result = await base.databaseService
            .getOutgoingRelationships(char1.id!);
        expect(result, hasLength(1));

        // 执行删除
        await base.databaseService.deleteRelationship(relationship.id!);

        // 删除后验证不存在
        result = await base.databaseService
            .getOutgoingRelationships(char1.id!);
        expect(result, isEmpty);
      });
    });

    group('复杂查询', () {
      test('应该处理双向关系', () async {
        final novel = await base.createAndAddNovel();
        final char1 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '张三',
        );
        final char2 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '李四',
        );

        // 创建双向关系
        await base.createRelationship(
          sourceId: char1.id!,
          targetId: char2.id!,
          relationshipType: '师父',
        );
        await base.createRelationship(
          sourceId: char2.id!,
          targetId: char1.id!,
          relationshipType: '徒弟',
        );

        // 验证双向关系
        final outgoing1 = await base.databaseService
            .getOutgoingRelationships(char1.id!);
        final incoming1 = await base.databaseService
            .getIncomingRelationships(char1.id!);

        expect(outgoing1, hasLength(1));
        expect(incoming1, hasLength(1));
        expect(outgoing1[0].relationshipType, '师父');
        expect(incoming1[0].relationshipType, '徒弟');
      });

      test('应该处理多对多关系', () async {
        final novel = await base.createAndAddNovel();
        final char1 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '张三',
        );
        final char2 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '李四',
        );
        final char3 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '王五',
        );

        // char1 与多个角色的关系
        await base.createRelationship(
          sourceId: char1.id!,
          targetId: char2.id!,
          relationshipType: '朋友',
        );
        await base.createRelationship(
          sourceId: char1.id!,
          targetId: char3.id!,
          relationshipType: '朋友',
        );

        // 多个角色与char1的关系
        await base.createRelationship(
          sourceId: char2.id!,
          targetId: char1.id!,
          relationshipType: '兄弟',
        );
        await base.createRelationship(
          sourceId: char3.id!,
          targetId: char1.id!,
          relationshipType: '兄弟',
        );

        // 验证多对多关系
        final outgoing1 = await base.databaseService
            .getOutgoingRelationships(char1.id!);
        final incoming1 = await base.databaseService
            .getIncomingRelationships(char1.id!);

        expect(outgoing1, hasLength(2));
        expect(incoming1, hasLength(2));
      });
    });

    group('边界情况', () {
      test('应该处理关系类型为空字符串', () async {
        final novel = await base.createAndAddNovel();
        final char1 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '张三',
        );
        final char2 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '李四',
        );

        await base.createRelationship(
          sourceId: char1.id!,
          targetId: char2.id!,
          relationshipType: '',
        );

        final result = await base.databaseService
            .getOutgoingRelationships(char1.id!);

        expect(result, hasLength(1));
        expect(result[0].relationshipType, '');
      });

      test('应该处理描述为null的情况', () async {
        final novel = await base.createAndAddNovel();
        final char1 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '张三',
        );
        final char2 = await base.createAndSaveCharacter(
          novelUrl: novel.url,
          name: '李四',
        );

        await base.createRelationship(
          sourceId: char1.id!,
          targetId: char2.id!,
          relationshipType: '朋友',
          description: null,
        );

        final result = await base.databaseService
            .getOutgoingRelationships(char1.id!);

        expect(result, hasLength(1));
        expect(result[0].description, null);
      });
    });
  });
}
