import '../../core/interfaces/repositories/i_chapter_repository.dart';
import '../../services/logger_service.dart';

/// 章节操作处理器
/// 负责章节的增删改操作
class ChapterActionHandler {
  final IChapterRepository _chapterRepo;
  final _log = LoggerService.instance;

  ChapterActionHandler({
    required IChapterRepository chapterRepository,
  }) : _chapterRepo = chapterRepository;

  /// 插入用户章节
  /// [novelUrl] 小说URL
  /// [title] 章节标题
  /// [content] 章节内容
  /// [insertIndex] 插入位置索引
  Future<void> insertChapter({
    required String novelUrl,
    required String title,
    required String content,
    required int insertIndex,
  }) async {
    _log.d(
      '开始插入用户章节: "$title", 位置: $insertIndex',
      category: LogCategory.ui,
      tags: ['chapter-list', 'insert'],
    );
    try {
      // [关键] 必须在 createCustomChapter 之前先腾出位置
      // 否则新章节的 chapterIndex 会与原章节冲突，导致排序错乱
      if (insertIndex >= 0) {
        await _chapterRepo.shiftChapterIndicesFrom(novelUrl, insertIndex);
      }
      await _chapterRepo.createCustomChapter(
        novelUrl,
        title,
        content,
        insertIndex,
      );
      _log.i(
        '用户章节插入成功: "$title", 位置: $insertIndex',
        category: LogCategory.ui,
        tags: ['chapter-list', 'insert'],
      );
    } catch (e, st) {
      _log.e(
        '用户章节插入失败: "$title" - $e',
        stackTrace: st.toString(),
        category: LogCategory.database,
        tags: ['chapter', 'insert'],
      );
      rethrow;
    }
  }

  /// 删除用户章节
  /// [chapterUrl] 章节URL
  Future<void> deleteChapter(String chapterUrl) async {
    _log.d(
      '开始删除用户章节: $chapterUrl',
      category: LogCategory.ui,
      tags: ['chapter-list', 'delete'],
    );
    try {
      await _chapterRepo.deleteCustomChapter(chapterUrl);
      _log.i(
        '用户章节删除成功: $chapterUrl',
        category: LogCategory.ui,
        tags: ['chapter-list', 'delete'],
      );
    } catch (e, st) {
      _log.e(
        '用户章节删除失败: $chapterUrl - $e',
        stackTrace: st.toString(),
        category: LogCategory.database,
        tags: ['chapter', 'delete'],
      );
      rethrow;
    }
  }

  /// 检查章节是否已缓存
  /// [chapterUrl] 章节URL
  /// 返回是否已缓存
  Future<bool> isChapterCached(String chapterUrl) async {
    try {
      return await _chapterRepo.isChapterCached(chapterUrl);
    } catch (e, st) {
      _log.e(
        '检查章节缓存状态失败: $chapterUrl - $e',
        stackTrace: st.toString(),
        category: LogCategory.database,
        tags: ['chapter', 'cache'],
      );
      rethrow;
    }
  }

}
