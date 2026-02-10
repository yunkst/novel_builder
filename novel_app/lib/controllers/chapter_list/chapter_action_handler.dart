import '../../core/interfaces/repositories/i_chapter_repository.dart';

/// 章节操作处理器
/// 负责章节的增删改操作
class ChapterActionHandler {
  final IChapterRepository _chapterRepo;

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
    await _chapterRepo.createCustomChapter(
      novelUrl,
      title,
      content,
      insertIndex,
    );
  }

  /// 删除用户章节
  /// [chapterUrl] 章节URL
  Future<void> deleteChapter(String chapterUrl) async {
    await _chapterRepo.deleteCustomChapter(chapterUrl);
  }

  /// 检查章节是否已缓存
  /// [chapterUrl] 章节URL
  /// 返回是否已缓存
  Future<bool> isChapterCached(String chapterUrl) async {
    return await _chapterRepo.isChapterCached(chapterUrl);
  }

  /// 批量检查章节是否已缓存
  ///
  /// [chapterUrls] 章节URL列表
  /// 返回 Map&lt;chapterUrl, isCached&gt;
  ///
  /// 性能优化：使用单次SQL查询替代逐个查询
  Future<Map<String, bool>> areChaptersCached(List<String> chapterUrls) async {
    return await _chapterRepo.getChaptersCacheStatus(chapterUrls);
  }
}
