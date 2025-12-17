import '../../models/chapter.dart';
import '../utils/result.dart';

/// 章节数据访问抽象接口
abstract class ChapterRepository {
  /// 获取小说章节列表
  Future<Result<List<Chapter>>> getChapters(String novelUrl, {bool forceRefresh = false});

  /// 获取章节内容
  Future<Result<String>> getChapterContent(String chapterUrl);

  /// 缓存章节内容
  Future<Result<void>> cacheChapter(String novelUrl, Chapter chapter, String content);

  /// 批量缓存章节
  Future<Result<void>> cacheChapters(String novelUrl, List<Chapter> chapters);

  /// 更新章节内容
  Future<Result<void>> updateChapterContent(String chapterUrl, String content);

  /// 插入用户章节
  Future<Result<void>> insertUserChapter(String novelUrl, String title, String content, int insertIndex);

  /// 删除用户章节
  Future<Result<void>> deleteUserChapter(String chapterUrl);

  /// 创建自定义章节
  Future<Result<void>> createCustomChapter(String novelUrl, String title, String content);

  /// 获取缓存的章节数量
  Future<Result<int>> getCachedChaptersCount(String novelUrl);

  /// 清理小说缓存
  Future<Result<void>> clearNovelCache(String novelUrl);

  /// 检查章节是否已缓存
  Future<Result<bool>> isChapterCached(String chapterUrl);

  /// 获取最后阅读章节
  Future<Result<int>> getLastReadChapter(String novelUrl);

  /// 更新阅读进度
  Future<Result<void>> updateReadingProgress(String novelUrl, int chapterIndex, double progress);
}