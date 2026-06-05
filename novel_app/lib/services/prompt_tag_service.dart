import '../models/tag_group.dart';
import '../core/providers/database_providers.dart';

/// 标签提示词拼接服务
///
/// 将选中标签的 prompt_text（同名随机选一条）拼接到用户输入前。
class PromptTagService {
  final dynamic _ref;

  PromptTagService(this._ref);

  /// 将选中标签的随机 prompt 拼接到 userInput 前
  ///
  /// 每个 TagGroup 同名多条中随机选一条。
  /// 格式: `<tag1 prompt>\n<tag2 prompt>\n\n<user input>`
  Future<String> buildMergedUserInput(
    String userInput,
    List<TagGroup> selectedGroups,
  ) async {
    if (selectedGroups.isEmpty) return userInput;
    final tagRepo = _ref.read(promptTagRepositoryProvider);

    final promptParts = <String>[];
    for (final group in selectedGroups) {
      final prompt = await tagRepo.getRandomPromptText(
        group.categoryId,
        group.name,
      );
      if (prompt != null && prompt.isNotEmpty) {
        promptParts.add(prompt);
      }
    }
    if (promptParts.isEmpty) return userInput;

    final merged = promptParts.join('\n');
    if (userInput.trim().isEmpty) return merged;
    return '$merged\n\n$userInput';
  }
}
