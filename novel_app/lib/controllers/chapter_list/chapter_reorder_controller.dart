import '../../models/chapter.dart';
import '../../core/interfaces/repositories/i_chapter_repository.dart';

/// 章节重排控制器
/// 负责章节重排逻辑和保存
class ChapterReorderController {
  final IChapterRepository _chapterRepo;

  ChapterReorderController({
    required IChapterRepository chapterRepository,
  }) : _chapterRepo = chapterRepository;

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
    await _chapterRepo.updateChaptersOrder(novelUrl, chapters);
  }
}
