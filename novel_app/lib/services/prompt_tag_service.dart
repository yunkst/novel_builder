import '../models/tag_group.dart';
import '../core/providers/database_providers.dart';
import '../core/interfaces/repositories/i_prompt_tag_repository.dart';

/// 标签合并结果
///
/// 包含合并后的用户输入文本和实际使用的 tag 详情列表。
/// usedTags 供 AI 自省使用，让自省知道"具体用了哪些 tag"。
class MergedTagResult {
  /// 合并后的 user_input（标签撰写要求 + 用户原始指令）
  final String mergedInput;

  /// 实际使用的 tag 详情列表（含随机选中的变体信息）
  final List<UsedTagDetail> usedTags;

  const MergedTagResult({
    required this.mergedInput,
    required this.usedTags,
  });
}

/// 单个被使用的 tag 详情
class UsedTagDetail {
  final int tagId;
  final String name;
  final String reason;
  final String promptText;

  const UsedTagDetail({
    required this.tagId,
    required this.name,
    required this.reason,
    required this.promptText,
  });

  /// 格式化为自省 prompt 中的标签展示格式
  String toDisplayString() {
    final buffer = StringBuffer();
    buffer.write('【$name】\n');
    if (reason.isNotEmpty) {
      buffer.writeln('场景：$reason');
    }
    buffer.writeln('提示词：$promptText');
    return buffer.toString();
  }
}

/// 标签提示词拼接服务
///
/// 将选中标签的 prompt_text（同名随机选一条）拼接到用户输入前。
/// 输出结构：
/// ```
/// ## 撰写要求
/// 以下为根据用户选择的写作技巧标签生成的撰写要求，请遵循这些要求进行创作：
///
/// 【标签1】
/// prompt1
///
/// 【标签2】
/// prompt2
///
/// ## 用户指令
/// 用户原始输入
/// ```
class PromptTagService {
  /// 直接依赖：标签 Repository
  ///
  /// 推荐通过此构造函数注入，便于测试和依赖反转。
  final IPromptTagRepository tagRepo;

  /// 兼容旧调用：接受任意 ref 对象，从中读取 promptTagRepositoryProvider
  ///
  /// 生产代码可继续通过 `PromptTagService(ref)` 使用；
  /// 测试代码应使用主构造函数直接注入真实 Repository。
  PromptTagService.byRef(dynamic ref)
      : tagRepo = ref.read(promptTagRepositoryProvider);

  /// 默认构造函数：直接注入 Repository（推荐用于测试）
  PromptTagService(this.tagRepo);

  /// 将选中标签的随机 prompt 拼接到 userInput 前
  ///
  /// 每个 TagGroup 同名多条中随机选一条。
  /// selectedGroups 为空时返回空 usedTags + 原样 userInput。
  ///
  /// 返回 [MergedTagResult]，包含合并文本和使用的 tag 详情。
  Future<MergedTagResult> buildMergedUserInput(
    String userInput,
    List<TagGroup> selectedGroups,
  ) async {
    if (selectedGroups.isEmpty) {
      return MergedTagResult(
        mergedInput: userInput,
        usedTags: const [],
      );
    }

    final promptParts = <String>[];
    final usedTags = <UsedTagDetail>[];

    for (final group in selectedGroups) {
      // 使用 getRandomTag 获取完整 tag 信息（含 reason）
      final tag = await tagRepo.getRandomTag(group.categoryId, group.name);
      if (tag != null && tag.promptText.isNotEmpty) {
        promptParts.add('【${tag.name}】\n${tag.promptText}');
        usedTags.add(UsedTagDetail(
          tagId: tag.id ?? 0,
          name: tag.name,
          reason: tag.reason,
          promptText: tag.promptText,
        ));
      }
    }

    if (promptParts.isEmpty) {
      return MergedTagResult(
        mergedInput: userInput,
        usedTags: const [],
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('## 撰写要求');
    buffer.writeln('以下为根据用户选择的写作技巧标签生成的撰写要求，请遵循这些要求进行创作：');
    buffer.writeln();
    buffer.writeln(promptParts.join('\n\n'));
    buffer.writeln();
    buffer.writeln('## 用户指令');
    buffer.write(userInput);

    return MergedTagResult(
      mergedInput: buffer.toString(),
      usedTags: usedTags,
    );
  }
}
