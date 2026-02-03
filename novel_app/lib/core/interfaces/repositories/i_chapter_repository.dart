import '../../../models/chapter.dart';
import '../../../models/search_result.dart';

/// 章节数据仓库接口
///
/// 负责章节内容缓存、章节列表管理和用户自定义章节的数据访问操作
abstract class IChapterRepository {
  // ========== 章节缓存管理 ==========

  /// 检查章节是否已缓存（内存优先）
  ///
  /// [chapterUrl] 章节的URL
  /// 返回是否已缓存
  Future<bool> isChapterCached(String chapterUrl);

  /// 批量检查缓存状态，返回未缓存的章节URL列表
  ///
  /// [chapterUrls] 章节URL列表
  /// 返回未缓存的章节URL列表
  Future<List<String>> filterUncachedChapters(List<String> chapterUrls);

  /// 批量查询章节缓存状态
  ///
  /// [chapterUrls] 章节URL列表
  /// 返回章节URL到缓存状态的映射
  Future<Map<String, bool>> getChaptersCacheStatus(List<String> chapterUrls);

  // ========== 预加载状态管理 ==========

  /// 标记章节正在预加载
  ///
  /// [chapterUrl] 章节的URL
  void markAsPreloading(String chapterUrl);

  /// 检查章节是否正在预加载
  ///
  /// [chapterUrl] 章节的URL
  /// 返回是否正在预加载
  bool isPreloading(String chapterUrl);

  /// 清理内存状态
  void clearMemoryState();

  // ========== 章节内容CRUD ==========

  /// 缓存章节内容
  ///
  /// [novelUrl] 小说的URL
  /// [chapter] 章节对象
  /// [content] 章节内容
  /// 返回新插入记录的ID
  Future<int> cacheChapter(String novelUrl, Chapter chapter, String content);

  /// 更新章节内容
  ///
  /// [chapterUrl] 章节的URL
  /// [content] 新的章节内容
  /// 返回受影响的行数
  Future<int> updateChapterContent(String chapterUrl, String content);

  /// 删除章节缓存
  ///
  /// [chapterUrl] 章节的URL
  /// 返回受影响的行数
  Future<int> deleteChapterCache(String chapterUrl);

  /// 获取缓存的章节内容
  ///
  /// [chapterUrl] 章节的URL
  /// 返回章节内容，如果不存在则返回null
  Future<String?> getCachedChapter(String chapterUrl);

  /// 获取小说的所有缓存章节
  ///
  /// [novelUrl] 小说的URL
  /// 返回章节列表，按章节索引升序排列
  Future<List<Chapter>> getCachedChapters(String novelUrl);

  /// 删除小说的所有缓存章节
  ///
  /// [novelUrl] 小说的URL
  /// 返回受影响的行数
  Future<int> deleteCachedChapters(String novelUrl);

  // ========== AI伴读标记 ==========

  /// 检查章节是否已伴读
  ///
  /// [novelUrl] 小说的URL
  /// [chapterUrl] 章节的URL
  /// 返回是否已伴读
  Future<bool> isChapterAccompanied(String novelUrl, String chapterUrl);

  /// 标记章节为已伴读
  ///
  /// [novelUrl] 小说的URL
  /// [chapterUrl] 章节的URL
  Future<void> markChapterAsAccompanied(String novelUrl, String chapterUrl);

  /// 重置章节伴读标记
  ///
  /// [novelUrl] 小说的URL
  /// [chapterUrl] 章节的URL
  Future<void> resetChapterAccompaniedFlag(String novelUrl, String chapterUrl);

  // ========== 章节列表管理 ==========

  /// 缓存小说章节列表
  ///
  /// [novelUrl] 小说的URL
  /// [chapters] 章节列表
  Future<void> cacheNovelChapters(String novelUrl, List<Chapter> chapters);

  /// 获取缓存的章节列表
  ///
  /// [novelUrl] 小说的URL
  /// 返回章节列表，按章节索引升序排列
  Future<List<Chapter>> getCachedNovelChapters(String novelUrl);

  // ========== 用户自定义章节 ==========

  /// 判断是否为本地章节
  ///
  /// [chapterUrl] 章节的URL
  /// 返回是否为本地章节
  static bool isLocalChapter(String chapterUrl) {
    return chapterUrl.startsWith('custom://') ||
        chapterUrl.startsWith('user_chapter_');
  }

  /// 创建用户自定义章节
  ///
  /// [novelUrl] 小说的URL
  /// [title] 章节标题
  /// [content] 章节内容
  /// [index] 可选的章节索引，如果未提供则使用最大索引+1
  /// 返回新创建章节的索引
  Future<int> createCustomChapter(String novelUrl, String title, String content,
      [int? index]);

  /// 更新用户创建的章节内容
  ///
  /// [chapterUrl] 章节的URL
  /// [title] 新的章节标题
  /// [content] 新的章节内容
  Future<void> updateCustomChapter(
      String chapterUrl, String title, String content);

  /// 删除用户创建的章节
  ///
  /// [chapterUrl] 章节的URL
  Future<void> deleteCustomChapter(String chapterUrl);

  // ========== 阅读状态 ==========

  /// 标记章节为已读
  ///
  /// [novelUrl] 小说的URL
  /// [chapterUrl] 章节的URL
  Future<void> markChapterAsRead(String novelUrl, String chapterUrl);

  /// 获取已缓存的章节数量
  ///
  /// [novelUrl] 小说的URL
  /// 返回已缓存的章节数量
  Future<int> getCachedChaptersCount(String novelUrl);

  // ========== 章节排序 ==========

  /// 更新章节顺序
  ///
  /// [novelUrl] 小说的URL
  /// [chapters] 要排序的章节列表
  ///
  /// 批量更新章节的索引值，用于章节重排序功能
  Future<void> updateChaptersOrder(String novelUrl, List<Chapter> chapters);

  // ========== 章节内容搜索 ==========

  /// 搜索缓存章节内容
  ///
  /// [keyword] 搜索关键词
  /// [novelUrl] 可选的小说URL，用于限制搜索范围
  /// 返回匹配的章节搜索结果列表
  Future<List<ChapterSearchResult>> searchInCachedContent(
    String keyword, {
    String? novelUrl,
  });
}
