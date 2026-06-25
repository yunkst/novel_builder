import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/prompt_tag_service.dart';
import 'package:novel_app/models/prompt_tag.dart';
import 'package:novel_app/models/tag_group.dart';
import 'package:novel_app/models/prompt_tag_category.dart';
import 'package:novel_app/repositories/prompt_tag_repository.dart';
import 'package:novel_app/repositories/prompt_tag_category_repository.dart';
import 'package:novel_app/core/database/database_connection.dart';

import '../../helpers/test_database_setup.dart';

/// PromptTagService 返回值改造测试
///
/// 验证 buildMergedUserInput 返回 MergedTagResult：
/// - mergedInput 格式正确
/// - usedTags 包含正确的 tag 详情
/// - 空标签组返回空结果
/// - UsedTagDetail.toDisplayString 格式
///
/// 使用真实 sqflite_common_ffi 内存数据库，不 mock Repository。
void main() {
  late PromptTagRepository tagRepo;
  late PromptTagCategoryRepository categoryRepo;
  late PromptTagService service;

  setUp(() async {
    final db = await TestDatabaseSetup.createInMemoryDatabase();
    final connection = DatabaseConnection.forTesting(db);
    tagRepo = PromptTagRepository(dbConnection: connection);
    categoryRepo = PromptTagCategoryRepository(dbConnection: connection);
    service = PromptTagService(tagRepo);
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
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ));
  }

  group('buildMergedUserInput - MergedTagResult', () {
    test('空标签组返回原样 userInput + 空 usedTags', () async {
      final result = await service.buildMergedUserInput('写一段打斗', []);

      expect(result.mergedInput, '写一段打斗');
      expect(result.usedTags, isEmpty);
    });

    test('单标签返回合并文本 + usedTags 含详情', () async {
      final catId = await createCategory('风格');
      await createTag(catId, '暴力美学', '注重力量感和冲击力',
          reason: '打斗、冲突');

      final result = await service.buildMergedUserInput('写一段打斗', [
        TagGroup(name: '暴力美学', count: 1, representativeId: 1, categoryId: catId),
      ]);

      expect(result.mergedInput, contains('## 撰写要求'));
      expect(result.mergedInput, contains('暴力美学'));
      expect(result.mergedInput, contains('写一段打斗'));
      expect(result.mergedInput, contains('## 用户指令'));

      expect(result.usedTags, hasLength(1));
      expect(result.usedTags.first.tagId, greaterThan(0));
      expect(result.usedTags.first.name, '暴力美学');
      expect(result.usedTags.first.reason, '打斗、冲突');
      expect(result.usedTags.first.promptText, '注重力量感和冲击力');
    });

    test('多标签按顺序拼接', () async {
      final catA = await createCategory('风格');
      final catB = await createCategory('场景');
      await createTag(catA, '暴力美学', '注重力量感', reason: '打斗');
      await createTag(catB, '紧张对峙', '短句加速节奏', reason: '对峙');

      final result = await service.buildMergedUserInput('写一段场景', [
        TagGroup(name: '暴力美学', count: 1, representativeId: 1, categoryId: catA),
        TagGroup(name: '紧张对峙', count: 1, representativeId: 2, categoryId: catB),
      ]);

      expect(result.usedTags, hasLength(2));
      expect(result.usedTags[0].name, '暴力美学');
      expect(result.usedTags[1].name, '紧张对峙');
      expect(result.mergedInput.indexOf('暴力美学'),
          lessThan(result.mergedInput.indexOf('紧张对峙')));
    });

    test('标签 prompt 为空时跳过该标签', () async {
      final catId = await createCategory('风格');
      await createTag(catId, '空标签', '', reason: '');

      final result = await service.buildMergedUserInput('写一段', [
        TagGroup(name: '空标签', count: 1, representativeId: 1, categoryId: catId),
      ]);

      expect(result.usedTags, isEmpty);
      expect(result.mergedInput, '写一段'); // 原样返回
    });

    test('不存在的标签名跳过该标签', () async {
      final catId = await createCategory('风格');

      final result = await service.buildMergedUserInput('写一段', [
        TagGroup(
            name: '不存在的标签', count: 1, representativeId: 1, categoryId: catId),
      ]);

      expect(result.usedTags, isEmpty);
      expect(result.mergedInput, '写一段');
    });
  });

  group('UsedTagDetail - toDisplayString', () {
    test('含 reason 时格式正确', () {
      const detail = UsedTagDetail(
        tagId: 1,
        name: '暴力美学',
        reason: '打斗、冲突',
        promptText: '注重力量感',
      );

      final display = detail.toDisplayString();

      expect(display, contains('【暴力美学】'));
      expect(display, contains('场景：打斗、冲突'));
      expect(display, contains('提示词：注重力量感'));
    });

    test('reason 为空时不输出场景行', () {
      const detail = UsedTagDetail(
        tagId: 1,
        name: '暴力美学',
        reason: '',
        promptText: '注重力量感',
      );

      final display = detail.toDisplayString();

      expect(display, contains('【暴力美学】'));
      expect(display, isNot(contains('场景：')));
      expect(display, contains('提示词：注重力量感'));
    });
  });
}