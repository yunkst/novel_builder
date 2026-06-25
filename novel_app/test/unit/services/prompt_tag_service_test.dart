import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/core/interfaces/repositories/i_prompt_tag_repository.dart';
import 'package:novel_app/models/prompt_tag.dart';
import 'package:novel_app/models/tag_group.dart';
import 'package:novel_app/services/prompt_tag_service.dart';

@GenerateMocks([IPromptTagRepository])
import 'prompt_tag_service_test.mocks.dart';

/// PromptTagService.buildMergedUserInput 拼接格式测试
///
/// 验证标签提示词的新拼接格式：
/// - 空标签组：原样返回
/// - 单标签：## 撰写要求 / 【标签名】 / ## 用户指令
/// - 多标签：用空行分隔
/// - 用户输入为空：只输出 ## 撰写要求 部分
/// - 标签无 prompt：跳过该标签
void main() {
  late MockIPromptTagRepository mockRepo;
  late PromptTagService service;

  setUp(() {
    mockRepo = MockIPromptTagRepository();
    service = PromptTagService(mockRepo);
  });

  PromptTag _makeTag({
    int? id,
    int categoryId = 1,
    String name = 'test',
    String reason = '',
    String promptText = 'PROMPT',
  }) {
    return PromptTag(
      id: id ?? 1,
      categoryId: categoryId,
      name: name,
      reason: reason,
      promptText: promptText,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('buildMergedUserInput - 新拼接格式', () {
    test('空标签组应原样返回用户输入', () async {
      final result = await service.buildMergedUserInput('用户的提示词', []);

      expect(result.mergedInput, '用户的提示词');
      expect(result.usedTags, isEmpty);
    });

    test('单标签拼接格式', () async {
      when(mockRepo.getRandomTag(1, '紧张对峙')).thenAnswer(
        (_) async => _makeTag(
          id: 10,
          name: '紧张对峙',
          promptText: '以环境描写烘托紧张感',
        ),
      );

      final result = await service.buildMergedUserInput(
        '写一段对峙',
        [const TagGroup(categoryId: 1, name: '紧张对峙', count: 1, representativeId: 0)],
      );

      expect(result.mergedInput, contains('## 撰写要求'));
      expect(result.mergedInput, contains('【紧张对峙】'));
      expect(result.mergedInput, contains('以环境描写烘托紧张感'));
      expect(result.mergedInput, contains('## 用户指令'));
      expect(result.mergedInput, contains('写一段对峙'));
      expect(result.usedTags.length, 1);
      expect(result.usedTags.first.name, '紧张对峙');
    });

    test('多标签用空行分隔', () async {
      when(mockRepo.getRandomTag(1, '紧张对峙'))
          .thenAnswer((_) async => _makeTag(name: '紧张对峙', promptText: 'PROMPT_A'));
      when(mockRepo.getRandomTag(2, '心理活动'))
          .thenAnswer((_) async => _makeTag(name: '心理活动', promptText: 'PROMPT_B'));
      when(mockRepo.getRandomTag(3, '动作描写'))
          .thenAnswer((_) async => _makeTag(name: '动作描写', promptText: 'PROMPT_C'));

      final result = await service.buildMergedUserInput(
        'USER_INPUT',
        const [
          TagGroup(categoryId: 1, name: '紧张对峙', count: 1, representativeId: 0),
          TagGroup(categoryId: 2, name: '心理活动', count: 1, representativeId: 0),
          TagGroup(categoryId: 3, name: '动作描写', count: 1, representativeId: 0),
        ],
      );

      // 三个标签块用双换行分隔
      expect(result.mergedInput, contains('【紧张对峙】\nPROMPT_A\n\n【心理活动】\nPROMPT_B\n\n【动作描写】\nPROMPT_C'));
      expect(result.usedTags.length, 3);
    });

    test('用户输入为空字符串时仍输出撰写要求区', () async {
      when(mockRepo.getRandomTag(1, '风格'))
          .thenAnswer((_) async => _makeTag(name: '风格', promptText: 'PROMPT_TEXT'));

      final result = await service.buildMergedUserInput(
        '',
        [const TagGroup(categoryId: 1, name: '风格', count: 1, representativeId: 0)],
      );

      expect(result.mergedInput, contains('## 撰写要求'));
      expect(result.mergedInput, contains('## 用户指令'));
      expect(result.mergedInput, contains('PROMPT_TEXT'));
    });

    test('标签无 prompt_text 时跳过该标签', () async {
      when(mockRepo.getRandomTag(1, '空标签'))
          .thenAnswer((_) async => _makeTag(name: '空标签', promptText: ''));
      when(mockRepo.getRandomTag(2, '有效标签'))
          .thenAnswer((_) async => _makeTag(name: '有效标签', promptText: 'VALID_PROMPT'));

      final result = await service.buildMergedUserInput(
        'USER',
        const [
          TagGroup(categoryId: 1, name: '空标签', count: 1, representativeId: 0),
          TagGroup(categoryId: 2, name: '有效标签', count: 1, representativeId: 0),
        ],
      );

      expect(result.mergedInput, isNot(contains('【空标签】')));
      expect(result.mergedInput, contains('【有效标签】'));
      expect(result.mergedInput, contains('VALID_PROMPT'));
    });

    test('getRandomTag 返回 null 时跳过该标签', () async {
      when(mockRepo.getRandomTag(1, '空标签'))
          .thenAnswer((_) async => null);
      when(mockRepo.getRandomTag(2, '有效标签'))
          .thenAnswer((_) async => _makeTag(name: '有效标签', promptText: 'VALID_PROMPT'));

      final result = await service.buildMergedUserInput(
        'USER',
        const [
          TagGroup(categoryId: 1, name: '空标签', count: 1, representativeId: 0),
          TagGroup(categoryId: 2, name: '有效标签', count: 1, representativeId: 0),
        ],
      );

      expect(result.mergedInput, isNot(contains('【空标签】')));
      expect(result.mergedInput, contains('【有效标签】'));
    });

    test('所有标签都无 prompt 时返回原样输入', () async {
      when(mockRepo.getRandomTag(any, any))
          .thenAnswer((_) async => null);

      final result = await service.buildMergedUserInput(
        'USER_INPUT',
        const [
          TagGroup(categoryId: 1, name: '标签1', count: 1, representativeId: 0),
          TagGroup(categoryId: 2, name: '标签2', count: 1, representativeId: 0),
        ],
      );

      expect(result.mergedInput, 'USER_INPUT');
      expect(result.usedTags, isEmpty);
    });

    test('完整输出结构（顺序：撰写要求 -> 标签列表 -> 用户指令）', () async {
      when(mockRepo.getRandomTag(1, 'A'))
          .thenAnswer((_) async => _makeTag(name: 'A', promptText: 'PA'));

      final result = await service.buildMergedUserInput(
        'USER',
        [const TagGroup(categoryId: 1, name: 'A', count: 1, representativeId: 0)],
      );

      final text = result.mergedInput;

      // 顺序验证
      final writingIdx = text.indexOf('## 撰写要求');
      final tagIdx = text.indexOf('【A】');
      final userIdx = text.indexOf('## 用户指令');
      final userInputIdx = text.indexOf('USER');

      expect(writingIdx, greaterThanOrEqualTo(0));
      expect(tagIdx, greaterThan(writingIdx));
      expect(userIdx, greaterThan(tagIdx));
      expect(userInputIdx, greaterThan(userIdx));
    });

    test('usedTags 包含完整的 tag 详情', () async {
      when(mockRepo.getRandomTag(1, '场景'))
          .thenAnswer((_) async => _makeTag(
                id: 42,
                name: '场景',
                reason: '用于描写环境',
                promptText: 'PROMPT_X',
              ));

      final result = await service.buildMergedUserInput(
        'USER',
        [const TagGroup(categoryId: 1, name: '场景', count: 1, representativeId: 0)],
      );

      expect(result.usedTags.length, 1);
      final tag = result.usedTags.first;
      expect(tag.tagId, 42);
      expect(tag.name, '场景');
      expect(tag.reason, '用于描写环境');
      expect(tag.promptText, 'PROMPT_X');
    });
  });
}
