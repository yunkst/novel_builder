import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:novel_app/core/interfaces/repositories/i_prompt_tag_repository.dart';
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
    service = PromptTagService(_FakeRef(mockRepo));
  });

  group('buildMergedUserInput - 新拼接格式', () {
    test('空标签组应原样返回用户输入', () async {
      final result = await service.buildMergedUserInput('用户的提示词', []);

      expect(result, '用户的提示词');
    });

    test('单标签拼接格式', () async {
      when(mockRepo.getRandomPromptText(1, '紧张对峙'))
          .thenAnswer((_) async => '以环境描写烘托紧张感');

      final result = await service.buildMergedUserInput(
        '写一段对峙',
        [const TagGroup(categoryId: 1, name: '紧张对峙', count: 1, representativeId: 0)],
      );

      expect(result, contains('## 撰写要求'));
      expect(result, contains('【紧张对峙】'));
      expect(result, contains('以环境描写烘托紧张感'));
      expect(result, contains('## 用户指令'));
      expect(result, contains('写一段对峙'));
    });

    test('多标签用空行分隔', () async {
      when(mockRepo.getRandomPromptText(1, '紧张对峙'))
          .thenAnswer((_) async => 'PROMPT_A');
      when(mockRepo.getRandomPromptText(2, '心理活动'))
          .thenAnswer((_) async => 'PROMPT_B');
      when(mockRepo.getRandomPromptText(3, '动作描写'))
          .thenAnswer((_) async => 'PROMPT_C');

      final result = await service.buildMergedUserInput(
        'USER_INPUT',
        const [
          TagGroup(categoryId: 1, name: '紧张对峙', count: 1, representativeId: 0),
          TagGroup(categoryId: 2, name: '心理活动', count: 1, representativeId: 0),
          TagGroup(categoryId: 3, name: '动作描写', count: 1, representativeId: 0),
        ],
      );

      // 三个标签块用双换行分隔
      expect(result, contains('【紧张对峙】\nPROMPT_A\n\n【心理活动】\nPROMPT_B\n\n【动作描写】\nPROMPT_C'));
    });

    test('用户输入为空字符串时仍输出撰写要求区', () async {
      when(mockRepo.getRandomPromptText(1, '风格'))
          .thenAnswer((_) async => 'PROMPT_TEXT');

      final result = await service.buildMergedUserInput(
        '',
        [const TagGroup(categoryId: 1, name: '风格', count: 1, representativeId: 0)],
      );

      expect(result, contains('## 撰写要求'));
      expect(result, contains('## 用户指令'));
      expect(result, contains('PROMPT_TEXT'));
      // 不应该出现无意义的空标签区
    });

    test('标签无 prompt_text 时跳过该标签', () async {
      when(mockRepo.getRandomPromptText(1, '空标签'))
          .thenAnswer((_) async => null);
      when(mockRepo.getRandomPromptText(2, '有效标签'))
          .thenAnswer((_) async => 'VALID_PROMPT');

      final result = await service.buildMergedUserInput(
        'USER',
        const [
          TagGroup(categoryId: 1, name: '空标签', count: 1, representativeId: 0),
          TagGroup(categoryId: 2, name: '有效标签', count: 1, representativeId: 0),
        ],
      );

      expect(result, isNot(contains('【空标签】')));
      expect(result, contains('【有效标签】'));
      expect(result, contains('VALID_PROMPT'));
    });

    test('所有标签都无 prompt 时返回原样输入', () async {
      when(mockRepo.getRandomPromptText(any, any))
          .thenAnswer((_) async => null);

      final result = await service.buildMergedUserInput(
        'USER_INPUT',
        const [
          TagGroup(categoryId: 1, name: '标签1', count: 1, representativeId: 0),
          TagGroup(categoryId: 2, name: '标签2', count: 1, representativeId: 0),
        ],
      );

      expect(result, 'USER_INPUT');
    });

    test('完整输出结构（顺序：撰写要求 -> 标签列表 -> 用户指令）', () async {
      when(mockRepo.getRandomPromptText(1, 'A'))
          .thenAnswer((_) async => 'PA');

      final result = await service.buildMergedUserInput(
        'USER',
        [const TagGroup(categoryId: 1, name: 'A', count: 1, representativeId: 0)],
      );

      // 顺序验证
      final writingIdx = result.indexOf('## 撰写要求');
      final tagIdx = result.indexOf('【A】');
      final userIdx = result.indexOf('## 用户指令');
      final userInputIdx = result.indexOf('USER');

      expect(writingIdx, greaterThanOrEqualTo(0));
      expect(tagIdx, greaterThan(writingIdx));
      expect(userIdx, greaterThan(tagIdx));
      expect(userInputIdx, greaterThan(userIdx));
    });
  });
}

/// 简化的 _ref 替身，仅实现 PromptTagService 用到的 read 方法
///
/// PromptTagService 内部调用 `_ref.read(promptTagRepositoryProvider)`，
/// 我们拦截所有 read 调用，返回注入的 mock repo。
class _FakeRef {
  final IPromptTagRepository repo;
  _FakeRef(this.repo);

  T read<T>(Object provider) => repo as T;
}
