import '../../models/chapter.dart';
import '../../services/database_service.dart';

/// 章节操作处理器
/// 负责章节的增删改操作
class ChapterActionHandler {
  final DatabaseService _databaseService;

  ChapterActionHandler({
    required DatabaseService databaseService,
  }) : _databaseService = databaseService;

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
  /// [chapters] 章节列表
  /// [afterIndex] 当前章节索引
  /// 返回前文章节内容的字符串列表
  Future<List<String>> getPreviousChaptersContent({
    required List<Chapter> chapters,
    required int afterIndex,
  }) async {
    final List<String> previousChapters = [];

    // 获取前5章的内容
    final startIndex = (afterIndex - 5).clamp(0, afterIndex);
    for (int i = startIndex; i <= afterIndex && i < chapters.length; i++) {
      final chapter = chapters[i];
      // 优先从缓存获取
      final content = await _databaseService.getCachedChapter(chapter.url);
      if (content != null && content.isNotEmpty) {
        previousChapters.add('第${i + 1}章 ${chapter.title}\n$content');
      } else {
        previousChapters.add('第${i + 1}章 ${chapter.title}\n（内容未缓存）');
      }
    }

    return previousChapters;
  }

  /// 检查章节是否已缓存
  /// [chapterUrl] 章节URL
  /// 返回是否已缓存
  Future<bool> isChapterCached(String chapterUrl) async {
    return await _databaseService.isChapterCached(chapterUrl);
  }
}
