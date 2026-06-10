import '../../models/chapter.dart';
import '../../core/interfaces/repositories/i_chapter_repository.dart';
import '../../services/logger_service.dart';

/// 章节重排控制器
/// 负责章节重排逻辑和保存
class ChapterReorderController {
  final IChapterRepository _chapterRepo;
  final _log = LoggerService.instance;

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

    _log.i(
      '章节重排: "${item.title}" 从 $oldIndex 移动到 $adjustedIndex',
      category: LogCategory.ui,
      tags: ['chapter-list', 'reorder'],
    );

    return chapters;
  }

  /// 保存重排后的章节顺序
  /// [novelUrl] 小说URL
  /// [chapters] 重排后的章节列表
  Future<void> saveReorderedChapters({
    required String novelUrl,
    required List<Chapter> chapters,
  }) async {
    _log.d(
      '保存重排后的章节顺序: ${chapters.length}章',
      category: LogCategory.database,
      tags: ['chapter', 'reorder'],
    );
    try {
      await _chapterRepo.updateChaptersOrder(novelUrl, chapters);
      _log.i(
        '章节重排保存成功: ${chapters.length}章',
        category: LogCategory.ui,
        tags: ['chapter-list', 'reorder'],
      );
    } catch (e, st) {
      _log.e(
        '章节重排保存失败: $novelUrl - $e',
        stackTrace: st.toString(),
        category: LogCategory.database,
        tags: ['chapter', 'reorder'],
      );
      rethrow;
    }
  }
}
