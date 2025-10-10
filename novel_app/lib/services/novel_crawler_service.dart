import 'package:http/http.dart' as http;
import '../models/novel.dart';
import '../models/chapter.dart';
import 'crawlers/crawler_factory.dart';

class NovelCrawlerService {
  final String baseUrl = 'https://www.alicesw.com';
  final http.Client client;
  final CrawlerFactory _factory = CrawlerFactory();

  NovelCrawlerService() : client = http.Client() {
    // 添加默认请求头
  }

  // 统一通过各站点适配器内部管理请求配置与头部

  /// 搜索小说
  Future<List<Novel>> searchNovels(String keyword) async {
    if (keyword.isEmpty) return [];
    // 使用默认通用适配器进行搜索（无需 URL）
    final adapter = _factory.forUrl(baseUrl);
    return await adapter.searchNovels(keyword);
  }

  /// 获取章节列表
  Future<List<Chapter>> getChapterList(String novelUrl) async {
    final adapter = _factory.forUrl(novelUrl);
    return await adapter.getChapterList(novelUrl);
  }


  /// 获取章节内容
  Future<String> getChapterContent(String chapterUrl, {int retryCount = 0}) async {
    final adapter = _factory.forUrl(chapterUrl);
    return await adapter.getChapterContent(chapterUrl, retryCount: retryCount);
  }

  void dispose() {
    client.close();
  }
}
