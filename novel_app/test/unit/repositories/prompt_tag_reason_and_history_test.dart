import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/core/database/database_connection.dart';
import 'package:novel_app/repositories/prompt_tag_repository.dart';
import 'package:novel_app/repositories/prompt_tag_category_repository.dart';
import 'package:novel_app/repositories/prompt_tag_history_repository.dart';
import 'package:novel_app/models/prompt_tag.dart';
import 'package:novel_app/models/prompt_tag_category.dart';

import '../../helpers/test_database_setup.dart';

/// PromptTagRepository 新方法 + PromptTagHistoryRepository 测试
///
/// 验证：
/// - reason 字段读写
/// - getRandomTag 返回完整 PromptTag
/// - getAll 获取所有标签
/// - search 搜索 reason 字段
/// - PromptTagHistoryRepository CRUD
void main() {
  late PromptTagRepository tagRepo;
  late PromptTagCategoryRepository categoryRepo;
  late PromptTagHistoryRepository historyRepo;

  setUp(() async {
    final db = await TestDatabaseSetup.createInMemoryDatabase();
    final connection = DatabaseConnection.forTesting(db);
    tagRepo = PromptTagRepository(dbConnection: connection);
    categoryRepo = PromptTagCategoryRepository(dbConnection: connection);
    historyRepo = PromptTagHistoryRepository(dbConnection: connection);
  });

  // ============================================================
  // 辅助方法
  // ============================================================

  Future<int> createCategory(String name) async {
    final now = DateTime.now();
    return categoryRepo.save(PromptTagCategory(
      name: name,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<int> createTag(int categoryId, String name, String promptText,
      {String reason = ''}) async {
    final now = DateTime.now();
    return tagRepo.save(PromptTag(
      categoryId: categoryId,
      name: name,
      reason: reason,
      promptText: promptText,
      createdAt: now,
      updatedAt: now,
    ));
  }

  // ============================================================
  // reason 字段读写
  // ============================================================

  group('reason 字段', () {
    test('保存带 reason 的标签后能正确读取', () async {
      final catId = await createCategory('风格');
      await createTag(catId, '暴力美学', '注重力量感',
          reason: '打斗、冲突、力量对抗');

      final tags = await tagRepo.getByCategory(catId);

      expect(tags, hasLength(1));
      expect(tags.first.name, '暴力美学');
      expect(tags.first.reason, '打斗、冲突、力量对抗');
    });

    test('更新 reason 后能正确读取新值', () async {
      final catId = await createCategory('风格');
      final tagId =
          await createTag(catId, '暴力美学', '注重力量感', reason: '打斗场景');

      // 读取并更新
      final tags = await tagRepo.getByCategory(catId);
      final tag = tags.first;
      await tagRepo.save(tag.copyWith(reason: '打斗、冲突、力量对抗'));

      final updated = await tagRepo.getByCategory(catId);
      expect(updated.first.reason, '打斗、冲突、力量对抗');
    });

    test('空 reason 的标签正确保存和读取', () async {
      final catId = await createCategory('风格');
      await createTag(catId, '紧张对峙', '短句和断句');

      final tags = await tagRepo.getByCategory(catId);

      expect(tags.first.reason, '');
    });
  });

  // ============================================================
  // getRandomTag
  // ============================================================

  group('getRandomTag', () {
    test('返回完整 PromptTag 对象（含 reason）', () async {
      final catId = await createCategory('风格');
      await createTag(catId, '暴力美学', '注重力量感',
          reason: '打斗场景');

      final tag = await tagRepo.getRandomTag(catId, '暴力美学');

      expect(tag, isNotNull);
      expect(tag!.name, '暴力美学');
      expect(tag.reason, '打斗场景');
      expect(tag.promptText, '注重力量感');
    });

    test('同名多条标签随机返回其中一条', () async {
      final catId = await createCategory('风格');
      await createTag(catId, '紧张对峙', '短句加速节奏');
      await createTag(catId, '紧张对峙', '环境描写烘托紧张感');

      // 多次调用，验证返回的是两条中的一条
      final results = <String>{};
      for (int i = 0; i < 20; i++) {
        final tag = await tagRepo.getRandomTag(catId, '紧张对峙');
        if (tag != null) results.add(tag.promptText);
      }

      expect(results.length, greaterThanOrEqualTo(1));
      expect(results, containsAll(['短句加速节奏', '环境描写烘托紧张感']));
    });

    test('不存在的标签返回 null', () async {
      final catId = await createCategory('风格');

      final tag = await tagRepo.getRandomTag(catId, '不存在的标签');

      expect(tag, isNull);
    });
  });

  // ============================================================
  // getAll
  // ============================================================

  group('getAll', () {
    test('返回所有分类下的所有标签', () async {
      final catA = await createCategory('风格');
      final catB = await createCategory('场景');
      await createTag(catA, '暴力美学', '注重力量感');
      await createTag(catB, '画面感', '五感细节');

      final all = await tagRepo.getAll();

      expect(all, hasLength(2));
      expect(all.map((t) => t.name), containsAll(['暴力美学', '画面感']));
    });

    test('无标签时返回空列表', () async {
      final all = await tagRepo.getAll();

      expect(all, isEmpty);
    });
  });

  // ============================================================
  // search 包含 reason
  // ============================================================

  group('search 包含 reason 字段', () {
    test('搜索 reason 内容能找到标签', () async {
      final catId = await createCategory('风格');
      await createTag(catId, '暴力美学', '注重力量感',
          reason: '打斗、冲突、力量对抗');

      final results = await tagRepo.search('力量对抗');

      expect(results, hasLength(1));
      expect(results.first.name, '暴力美学');
    });

    test('搜索 name 仍然有效', () async {
      final catId = await createCategory('风格');
      await createTag(catId, '暴力美学', '注重力量感');

      final results = await tagRepo.search('暴力');

      expect(results, hasLength(1));
    });

    test('搜索 promptText 仍然有效', () async {
      final catId = await createCategory('风格');
      await createTag(catId, '暴力美学', '注重力量感');

      final results = await tagRepo.search('力量感');

      expect(results, hasLength(1));
    });
  });

  // ============================================================
  // PromptTagHistoryRepository
  // ============================================================

  group('PromptTagHistoryRepository', () {
    test('插入历史记录后能按 tagId 查询', () async {
      final entry = PromptTagHistoryEntry(
        tagId: 1,
        novelUrl: 'https://example.com/novel1',
        changeType: 'reason_adjust',
        oldValue: '打斗场景',
        newValue: '打斗、冲突、力量对抗',
        reason: '场景描述太窄',
        createdAt: DateTime(2026, 6, 23),
      );

      await historyRepo.insert(entry);

      final history = await historyRepo.getByTagId(1);

      expect(history, hasLength(1));
      expect(history.first.changeType, 'reason_adjust');
      expect(history.first.oldValue, '打斗场景');
      expect(history.first.newValue, '打斗、冲突、力量对抗');
      expect(history.first.reason, '场景描述太窄');
    });

    test('按 novelUrl 查询历史记录', () async {
      final now = DateTime.now();
      await historyRepo.insert(PromptTagHistoryEntry(
        tagId: 1,
        novelUrl: 'https://example.com/novel1',
        changeType: 'prompt_clarify',
        newValue: '新的提示词',
        reason: '测试1',
        createdAt: now,
      ));
      await historyRepo.insert(PromptTagHistoryEntry(
        tagId: 2,
        novelUrl: 'https://example.com/novel2',
        changeType: 'created',
        newValue: '新标签',
        reason: '测试2',
        createdAt: now,
      ));

      final history =
          await historyRepo.getByNovelUrl('https://example.com/novel1');

      expect(history, hasLength(1));
      expect(history.first.changeType, 'prompt_clarify');
    });

    test('getRecent 返回最近 N 条', () async {
      final now = DateTime.now();
      for (int i = 0; i < 5; i++) {
        await historyRepo.insert(PromptTagHistoryEntry(
          tagId: i + 1,
          novelUrl: 'https://example.com/novel1',
          changeType: 'reason_adjust',
          newValue: '修改$i',
          reason: '测试',
          createdAt: now.add(Duration(seconds: i)),
        ));
      }

      final recent = await historyRepo.getRecent(limit: 3);

      expect(recent, hasLength(3));
      // 最新记录在前（按 created_at DESC）
      expect(recent.first.newValue, '修改4');
    });

    test('无历史记录时返回空列表', () async {
      final history = await historyRepo.getByTagId(999);

      expect(history, isEmpty);
    });
  });
}
