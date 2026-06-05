import '../../../models/prompt_tag.dart';
import '../../../models/tag_group.dart';

abstract class IPromptTagRepository {
  Future<List<PromptTag>> getByCategory(int categoryId);
  Future<List<PromptTag>> search(String keyword, {int? categoryId});
  Future<int> save(PromptTag tag);
  Future<void> delete(int id);
  Future<void> deleteByCategory(int categoryId);
  Future<void> reorder(List<int> orderedIds);
  Future<List<PromptTag>> getByIds(List<int> ids);
  Future<List<TagGroup>> getGroupedByCategory(int categoryId);
  Future<String?> getRandomPromptText(int categoryId, String name);
}
