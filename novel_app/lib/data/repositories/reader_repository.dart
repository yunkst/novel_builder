import '../../models/chapter.dart';
import '../../services/api_service_wrapper.dart';
import '../../services/database_service.dart';
import '../../core/di/api_service_provider.dart';

class ReaderRepository {
  final ApiServiceWrapper _apiService = ApiServiceProvider.instance;
  final DatabaseService _databaseService = DatabaseService();

  /// 获取章节内容，封装了缓存优先、网络回退的逻辑。
  ///
  /// [novelUrl] 小说 URL，用于缓存。
  /// [chapter] 要获取的章节对象。
  /// [forceRefresh] 如果为 true，则会强制从网络获取并更新缓存。
  ///
  /// 返回章节内容的字符串。
  /// 如果发生错误，则会抛出异常。
  Future<String> getChapterContent(String novelUrl, Chapter chapter, {bool forceRefresh = false}) async {
    // 强制刷新逻辑：先删除缓存
    if (forceRefresh) {
      await _databaseService.deleteChapterCache(chapter.url);
    }

    // 场景1：本地章节
    if (DatabaseService.isLocalChapter(chapter.url)) {
      final content = await _databaseService.getCachedChapter(chapter.url);
      if (content != null && content.isNotEmpty) {
        return content;
      } else {
        throw Exception('本地章节内容不存在或为空');
      }
    }

    // 场景2：网络章节
    // 步骤 1: 尝试从缓存获取
    if (!forceRefresh) {
      final cachedContent = await _databaseService.getCachedChapter(chapter.url);
      if (cachedContent != null && cachedContent.isNotEmpty) {
        return cachedContent;
      }
    }

    // 步骤 2: 缓存未命中或强制刷新，从网络获取
    try {
      final content = await _apiService.getChapterContent(chapter.url, forceRefresh: forceRefresh);

      // 步骤 3: 验证内容并存入缓存
      if (content.isNotEmpty && content.length > 50) { // 验证内容有效性
        await _databaseService.cacheChapter(novelUrl, chapter, content);
        return content;
      } else {
        throw Exception('获取到的章节内容为空或过短');
      }
    } catch (e) {
      // 重新抛出异常，让调用方（UI层）处理
      rethrow;
    }
  }
}
