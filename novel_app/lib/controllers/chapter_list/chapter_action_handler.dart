import '../../models/chapter.dart';
import '../../services/database_service.dart';
import '../../services/chapter_service.dart';

/// 章节操作处理器
/// 负责章节的增删改操作
class ChapterActionHandler {
  final DatabaseService _databaseService;
  final ChapterService _chapterService;

  ChapterActionHandler({
    required DatabaseService databaseService,
    ChapterService? chapterService,
  })  : _databaseService = databaseService,
        _chapterService = chapterService ?? ChapterService();

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
    await _databaseService.insertUserChapter(
      novelUrl,
      title,
      content,
      insertIndex,
    );
  }

  /// 删除用户章节
  /// [chapterUrl] 章节URL
  Future<void> deleteChapter(String chapterUrl) async {
    await _databaseService.deleteUserChapter(chapterUrl);
  }

  /// 获取前文章节内容（用于上下文）
  ///
  /// 委托给 [ChapterService.getPreviousChaptersContent] 处理
  Future<List<String>> getPreviousChaptersContent({
    required List<Chapter> chapters,
    required int afterIndex,
  }) async {
    return await _chapterService.getPreviousChaptersContent(
      chapters: chapters,
      afterIndex: afterIndex,
    );
  }

  /// 检查章节是否已缓存
  /// [chapterUrl] 章节URL
  /// 返回是否已缓存
  Future<bool> isChapterCached(String chapterUrl) async {
    return await _databaseService.isChapterCached(chapterUrl);
  }
}
