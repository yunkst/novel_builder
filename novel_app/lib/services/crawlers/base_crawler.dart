import '../../models/novel.dart';
import '../../models/chapter.dart';

/// 站点爬虫适配器接口
abstract class BaseCrawler {
  /// 站点基础 URL（用于识别与展示）
  String get baseUrl;
  /// 判断当前适配器是否支持该 URL（通常基于 host）
  bool supports(Uri uri);

  /// 搜索小说
  Future<List<Novel>> searchNovels(String keyword);

  /// 获取章节列表
  Future<List<Chapter>> getChapterList(String novelUrl);

  /// 获取章节内容
  Future<String> getChapterContent(String chapterUrl, {int retryCount = 0});
}