import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/database/database_connection.dart';
import 'package:novel_app/repositories/prompt_history_repository.dart';
import 'package:novel_app/models/prompt_history.dart';
import 'package:novel_app/models/saved_tag_group.dart';

import '../../helpers/test_database_setup.dart';

/// PromptHistoryRepository 集成测试
///
/// 使用真实内存数据库，验证 tag_group_ids JSON 字段的完整生命周期。
///
/// 测试覆盖：
/// - addOrUpdate: 新建提示词（带标签 / 不带标签）
/// - addOrUpdate: 更新已有提示词时合并标签
/// - getAll / search: 正确读取 tagGroups
/// - 旧数据兼容（无 tag_group_ids 字段）
/// - delete / deleteAll
void main() {
  late PromptHistoryRepository repo;

  setUp(() async {
    final db = await TestDatabaseSetup.createInMemoryDatabase();
    final connection = DatabaseConnection.forTesting(db);
    repo = PromptHistoryRepository(dbConnection: connection);
  });

  group('addOrUpdate - 标签快照', () {
    test('新建带标签的提示词，getAll 正确返回标签', () async {
      await repo.addOrUpdate('测试提示词', tagGroups: const [
        SavedTagGroup(categoryId: 1, name: '紧张对峙'),
        SavedTagGroup(categoryId: 2, name: '心理活动'),
      ]);

      final items = await repo.getAll();

      expect(items, hasLength(1));
      expect(items[0].promptText, '测试提示词');
      expect(items[0].tagGroups, hasLength(2));
      expect(items[0].tagGroups[0].name, '紧张对峙');
      expect(items[0].tagGroups[1].name, '心理活动');
    });

    test('新建不带标签的提示词，tagGroups 为空', () async {
      await repo.addOrUpdate('不带标签的提示词');

      final items = await repo.getAll();

      expect(items, hasLength(1));
      expect(items[0].tagGroups, isEmpty);
    });

    test('更新已有提示词时覆盖标签', () async {
      await repo.addOrUpdate('历史1', tagGroups: const [
        SavedTagGroup(categoryId: 1, name: '旧标签'),
      ]);

      await repo.addOrUpdate('历史1', tagGroups: const [
        SavedTagGroup(categoryId: 2, name: '新标签1'),
        SavedTagGroup(categoryId: 3, name: '新标签2'),
      ]);

      final items = await repo.getAll();

      expect(items, hasLength(1));
      expect(items[0].tagGroups, hasLength(2));
      expect(items[0].tagGroups[0].name, '新标签1');
    });

    test('更新时传空标签组，保留旧标签', () async {
      await repo.addOrUpdate('某个提示词', tagGroups: const [
        SavedTagGroup(categoryId: 1, name: '心理活动'),
      ]);

      // 不传 tagGroups（用户没选标签就保存了）
      await repo.addOrUpdate('某个提示词');

      final items = await repo.getAll();

      expect(items, hasLength(1));
      // 旧标签应该保留（空标签不覆盖已有数据）
      expect(items[0].tagGroups, hasLength(1));
      expect(items[0].tagGroups[0].name, '心理活动');
    });

    test('空字符串输入不写入', () async {
      await repo.addOrUpdate('  ');

      final items = await repo.getAll();

      expect(items, isEmpty);
    });
  });

  group('getAll / search - 标签读取', () {
    test('search 正确返回标签数据', () async {
      await repo.addOrUpdate('写一个场景', tagGroups: const [
        SavedTagGroup(categoryId: 2, name: '场景'),
      ]);
      await repo.addOrUpdate('写一个角色');

      final results = await repo.search('场景');

      expect(results, hasLength(1));
      expect(results[0].promptText, '写一个场景');
      expect(results[0].tagGroups[0].name, '场景');
    });
  });

  group('旧数据兼容', () {
    test('数据库中没有 tag_group_ids 列时，fromMap 返回空 tagGroups（内存表默认支持新列）', () async {
      // 由于 TestDatabaseSetup 已经执行 v26 迁移（新列已存在），
      // 这里验证写入 null → 读取为空列表的边界。
      await repo.addOrUpdate('旧数据迁移测试');

      final items = await repo.getAll();

      expect(items, hasLength(1));
      expect(items[0].tagGroups, isEmpty);
    });

    test('直接 INSERT 带 null tag_group_ids 的数据可读取', () async {
      final db = await repo.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('prompt_history', {
        'prompt_text': '原始旧数据',
        'created_at': now,
        'updated_at': now,
        'tag_group_ids': null,
      });

      final items = await repo.getAll();

      final old = items.firstWhere((i) => i.promptText == '原始旧数据');
      expect(old.tagGroups, isEmpty);
    });
  });

  group('delete', () {
    test('delete 正确删除指定记录', () async {
      await repo.addOrUpdate('要保留的');
      await repo.addOrUpdate('要删除的');

      final before = await repo.getAll();
      final target = before.firstWhere((i) => i.promptText == '要删除的');
      await repo.delete(target.id!);

      final after = await repo.getAll();
      expect(after, hasLength(1));
      expect(after.first.promptText, '要保留的');
    });

    test('deleteAll 清空全部记录', () async {
      await repo.addOrUpdate('记录1');
      await repo.addOrUpdate('记录2');

      await repo.deleteAll();

      final after = await repo.getAll();
      expect(after, isEmpty);
    });
  });
}
