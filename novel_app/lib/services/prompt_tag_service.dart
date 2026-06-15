import '../models/tag_group.dart';
import '../core/providers/database_providers.dart';

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
  final dynamic _ref;

  PromptTagService(this._ref);

  /// 将选中标签的随机 prompt 拼接到 userInput 前
  ///
  /// 每个 TagGroup 同名多条中随机选一条。
  /// selectedGroups 为空时原样返回 userInput。
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
        promptParts.add('【${group.name}】\n$prompt');
      }
    }
    if (promptParts.isEmpty) return userInput;

    final buffer = StringBuffer();
    buffer.writeln('## 撰写要求');
    buffer.writeln('以下为根据用户选择的写作技巧标签生成的撰写要求，请遵循这些要求进行创作：');
    buffer.writeln();
    buffer.writeln(promptParts.join('\n\n'));
    buffer.writeln();
    buffer.writeln('## 用户指令');
    buffer.write(userInput);
    return buffer.toString();
  }
}
