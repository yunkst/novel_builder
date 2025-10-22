import 'dart:async';
import 'dart:collection';

import '../models/chapter.dart';
import 'api_service_wrapper.dart';
import 'database_service.dart';

class CacheProgressUpdate {
  final String novelUrl;
  final int cachedChapters;
  final int totalChapters;
  CacheProgressUpdate({
    required this.novelUrl,
    required this.cachedChapters,
    required this.totalChapters,
  });
}

/// 简单的后台缓存管理器：当 App 活跃时自动继续缓存小说
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final DatabaseService _db = DatabaseService();
  final ApiServiceWrapper _api = ApiServiceWrapper();

  final Queue<String> _queue = Queue<String>();
  final StreamController<CacheProgressUpdate> _progressController =
      StreamController<CacheProgressUpdate>.broadcast();

  bool _running = false;
  bool _appActive = false;
  bool _apiReady = false;

  Stream<CacheProgressUpdate> get progressStream => _progressController.stream;

  void setAppActive(bool active) {
    _appActive = active;
    if (_appActive) {
      _startIfNeeded();
    }
  }

  /// 将小说加入后台缓存队列
  void enqueueNovel(String novelUrl) {
    if (!_queue.contains(novelUrl)) {
      _queue.add(novelUrl);
    }
    _startIfNeeded();
  }

  void _startIfNeeded() {
    if (_running || !_appActive) return;
    _running = true;
    _run();
  }

  Future<void> _ensureApiReady() async {
    if (_apiReady) return;
    try {
      await _api.init();
      _apiReady = true;
    } catch (_) {
      // 忽略初始化错误（可能未配置后端），稍后重试
      _apiReady = false;
    }
  }

  Future<void> _run() async {
    while (_appActive) {
      if (_queue.isEmpty) {
        // 队列为空，停止运行，等待下一次唤醒
        _running = false;
        return;
      }

      final novelUrl = _queue.removeFirst();
      await _processNovel(novelUrl);
    }

    _running = false;
  }

  Future<void> _processNovel(String novelUrl) async {
    await _ensureApiReady();

    // 如果 API 未准备好，跳过本轮
    if (!_apiReady) return;

    // 获取章节列表与已缓存章节数
    final chapters = await _db.getCachedNovelChapters(novelUrl);
    final stats = await _db.getNovelCacheStats(novelUrl);
    int cachedCount = stats['cachedChapters'] ?? 0;
    final total = stats['totalChapters'] ?? chapters.length;

    // 如果没有章节列表，直接跳过
    if (chapters.isEmpty || total == 0) {
      return;
    }

    // 从第一个未缓存章节开始缓存
    for (var i = 0; i < chapters.length; i++) {
      if (!_appActive) break; // 仅在活跃时执行
      final chapter = chapters[i];

      // 已缓存的跳过
      final isCached = await _db.isChapterCached(chapter.url);
      if (isCached) continue;

      try {
        final content = await _api.getChapterContent(chapter.url);
        await _db.cacheChapter(novelUrl, Chapter(
          title: chapter.title,
          url: chapter.url,
          chapterIndex: chapter.chapterIndex,
        ), content);
        cachedCount += 1;
        _progressController.add(CacheProgressUpdate(
          novelUrl: novelUrl,
          cachedChapters: cachedCount,
          totalChapters: total,
        ));
      } catch (_) {
        // 单章失败不影响整体，继续尝试下一章
        continue;
      }
    }
  }

  void dispose() {
    _progressController.close();
  }
}