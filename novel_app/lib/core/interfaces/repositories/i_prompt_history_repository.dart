import '../../../models/prompt_history.dart';

abstract class IPromptHistoryRepository {
  Future<void> addOrUpdate(String promptText);
  Future<List<PromptHistory>> getAll({int? limit});
  Future<List<PromptHistory>> search(String keyword);
  Future<void> delete(int id);
  Future<void> deleteAll();
}
