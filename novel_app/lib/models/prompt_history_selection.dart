import 'tag_group.dart';

/// 历史提示词选择结果
///
/// 从 PromptHistoryBottomSheet 返回时携带关联标签信息，
/// 调用方据此恢复输入框文本与已选标签状态。
class PromptHistorySelection {
  final String promptText;
  final List<TagGroup> tagGroups;

  const PromptHistorySelection({
    required this.promptText,
    this.tagGroups = const [],
  });
}
