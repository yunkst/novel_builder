import '../../../models/prompt_history.dart';
import '../../../models/saved_tag_group.dart';

abstract class IPromptHistoryRepository {
  /// 保存提示词（支持关联标签快照）
  Future<void> addOrUpdate(
    String promptText, {
    List<SavedTagGroup> tagGroups = const [],
  });

  Future<List<PromptHistory>> getAll({int? limit});
  Future<List<PromptHistory>> search(String keyword);
  Future<void> delete(int id);
  Future<void> deleteAll();
}
