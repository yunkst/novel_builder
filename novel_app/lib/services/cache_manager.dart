import 'dart:async';
import 'dart:collection';

import 'api_service_wrapper.dart';
import 'database_service.dart';
import 'chapter_manager.dart';
import '../core/di/api_service_provider.dart';
import 'package:flutter/foundation.dart';

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

class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final DatabaseService _db = DatabaseService();
  final ApiServiceWrapper _api = ApiServiceProvider.instance;
  final ChapterManager _chapterManager = ChapterManager();
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
    if (_running || !_appActive || !_apiReady || _queue.isEmpty) {
      return;
    }
    _running = true;
    _processQueue();
  }

  Future<void> _processQueue() async {
    while (_queue.isNotEmpty && _running && _appActive) {
      final novelUrl = _queue.removeFirst();

      try {
        debugPrint('CacheManager: 开始缓存小说 $novelUrl');
        await _cacheNovel(novelUrl);
      } catch (e) {
        debugPrint('CacheManager: 缓存失败 $novelUrl: $e');
      }
    }
    _running = false;
  }

  Future<void> _cacheNovel(String novelUrl) async {
    try {
      final chapters = await _api.getChapters(novelUrl);
      int cachedCount = 0;

      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];

        // 发送进度更新
        _progressController.add(CacheProgressUpdate(
          novelUrl: novelUrl,
          cachedChapters: cachedCount,
          totalChapters: chapters.length,
        ));

        // 检查是否已缓存
        final isCached = await _db.isChapterCached(chapter.url);
        if (isCached) {
          cachedCount++;
          continue;
        }

        try {
          // 使用ChapterManager获取章节内容，避免重复请求
          final content = await _chapterManager.getChapterContent(
            chapter.url,
            fetchFunction: () => _api.getChapterContent(chapter.url),
          );
          if (content.isNotEmpty) {
            await _db.cacheChapter(
              novelUrl,
              chapter,
              content,
            );
            cachedCount++;
          }
        } catch (e) {
          debugPrint('CacheManager: 缓存章节失败 ${chapter.url}: $e');
        }

        // 避免过于频繁的请求
        if (i % 10 == 0) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // 最终进度更新
      _progressController.add(CacheProgressUpdate(
        novelUrl: novelUrl,
        cachedChapters: cachedCount,
        totalChapters: chapters.length,
      ));

    } catch (e) {
      debugPrint('CacheManager: 缓存小说失败 $novelUrl: $e');
      rethrow;
    }
  }

  /// 检查API是否可用
  Future<void> checkApiAvailability() async {
    try {
      await _api.checkImageToVideoHealth();
      _apiReady = true;
    } catch (e) {
      _apiReady = false;
      debugPrint('CacheManager: API不可用: $e');
    }
  }

  /// 清理缓存
  Future<void> clearCache() async {
    await _db.clearAllCache();
  }

  /// 清理特定小说的缓存
  Future<void> clearNovelCache(String novelUrl) async {
    await _db.clearNovelCache(novelUrl);
  }

  /// 停止缓存
  void stopCaching() {
    _running = false;
    _queue.clear();
  }

  void dispose() {
    _running = false;
    _queue.clear();
    _progressController.close();
  }
}