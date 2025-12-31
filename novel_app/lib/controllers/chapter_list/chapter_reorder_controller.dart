import '../../models/chapter.dart';
import '../../services/database_service.dart';

/// 章节重排控制器
/// 负责章节重排逻辑和保存
class ChapterReorderController {
  final DatabaseService _databaseService;

  ChapterReorderController({
    required DatabaseService databaseService,
  }) : _databaseService = databaseService;

  /// 处理章节重排
  /// [oldIndex] 原始索引
  /// [newIndex] 新索引
  /// [chapters] 当前章节列表
  /// 返回重排后的章节列表
  List<Chapter> onReorder({
    required int oldIndex,
    required int newIndex,
    required List<Chapter> chapters,
  }) {
    int adjustedIndex = newIndex;
    if (oldIndex < newIndex) {
      adjustedIndex = newIndex - 1;
    }

    final Chapter item = chapters.removeAt(oldIndex);
    chapters.insert(adjustedIndex, item);

    return chapters;
  }

  /// 保存重排后的章节顺序
  /// [novelUrl] 小说URL
  /// [chapters] 重排后的章节列表
  Future<void> saveReorderedChapters({
    required String novelUrl,
    required List<Chapter> chapters,
  }) async {
    await _databaseService.updateChaptersOrder(novelUrl, chapters);
  }
}
