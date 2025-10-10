import 'base_crawler.dart';
import 'shukuge_crawler.dart';
import 'alice_sw_crawler.dart';

/// 爬虫工厂与注册表
class CrawlerFactory {
  static final CrawlerFactory _instance = CrawlerFactory._internal();
  final List<BaseCrawler> _registered = [];

  factory CrawlerFactory() {
    return _instance;
  }

  CrawlerFactory._internal() {
    // 注册适配器（按优先级从高到低）
    _registered.add(ShukugeCrawler());
    _registered.add(AliceSwCrawler());
  }

  void register(BaseCrawler crawler) {
    _registered.insert(0, crawler); // 新注册的适配器优先
  }

  /// 获取已注册的爬虫适配器列表（只读）
  List<BaseCrawler> get registered => List.unmodifiable(_registered);

  BaseCrawler forUrl(String url) {
    final uri = Uri.parse(url);
    for (final crawler in _registered) {
      if (crawler.supports(uri)) return crawler;
    }
    // 默认回退：返回第一个注册的适配器（当前为书库阁）
    return _registered.first;
  }
}