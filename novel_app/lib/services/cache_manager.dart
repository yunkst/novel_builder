import 'dart:async';
import 'dart:collection';

import '../models/chapter.dart';
import '../models/cache_task.dart';
import 'api_service_wrapper.dart';
import 'database_service.dart';
import 'cache_sync_service.dart';
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

/// 增强的缓存管理器：集成本地和服务端缓存同步
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final DatabaseService _db = DatabaseService();
  final ApiServiceWrapper _api = ApiServiceWrapper();
  final CacheSyncService _syncService = CacheSyncService();

  final Queue<String> _queue = Queue<String>();
  final StreamController<CacheProgressUpdate> _progressController =
      StreamController<CacheProgressUpdate>.broadcast();

  bool _running = false;
  bool _appActive = false;
  bool _apiReady = false;

  // 服务端缓存任务跟踪
  final Map<int, CacheTask> _serverTasks = {};
  Timer? _serverTaskPollTimer;

  Stream<CacheProgressUpdate> get progressStream => _progressController.stream;

  void setAppActive(bool active) {
    _appActive = active;
    if (_appActive) {
      _startIfNeeded();
      // 应用恢复时开始同步服务端任务
      _startServerTaskSync();
    } else {
      // 应用进入后台时停止同步
      _stopServerTaskSync();
    }
  }

  /// 将小说加入后台缓存队列
  void enqueueNovel(String novelUrl) {
    if (!_queue.contains(novelUrl)) {
      _queue.add(novelUrl);
    }
    _startIfNeeded();
  }

  /// 应用启动时同步服务端缓存任务
  Future<void> syncOnAppStart() async {
    debugPrint('CacheManager: 开始同步服务端缓存任务');
    try {
      await _syncService.init();
      await _syncService.syncOnAppStart();

      // 获取最新的服务端任务列表
      final serverTasks = await _syncService.getAllServerTasks();
      _serverTasks.clear();
      for (final task in serverTasks) {
        _serverTasks[task.id] = task;
      }

      debugPrint('CacheManager: 同步了 ${serverTasks.length} 个服务端缓存任务');

      // 开始定期轮询运行中的任务
      _startServerTaskSync();
    } catch (e) {
      debugPrint('CacheManager: 同步服务端任务失败: $e');
    }
  }

  /// 开始同步服务端缓存任务
  void _startServerTaskSync() {
    _stopServerTaskSync();

    if (!_appActive) return;

    debugPrint('CacheManager: 开始同步服务端任务状态');
    _serverTaskPollTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _pollServerTasks();
    });
  }

  /// 停止同步服务端缓存任务
  void _stopServerTaskSync() {
    _serverTaskPollTimer?.cancel();
    _serverTaskPollTimer = null;
    debugPrint('CacheManager: 停止同步服务端任务状态');
  }

  /// 轮询服务端任务状态
  Future<void> _pollServerTasks() async {
    try {
      final serverTasks = await _syncService.getAllServerTasks();

      // 检查任务状态变化
      for (final task in serverTasks) {
        final cachedTask = _serverTasks[task.id];

        // 只处理运行中的任务，避免不必要的网络请求
        if (task.isRunning &&
            (cachedTask == null || cachedTask.status != task.status)) {
          // 推送进度更新
          _progressController.add(CacheProgressUpdate(
            novelUrl: task.novelUrl,
            cachedChapters: task.cachedChapters,
            totalChapters: task.totalChapters,
          ));

          debugPrint(
              'CacheManager: 任务 ${task.id} 状态更新: ${task.status} (${task.cachedChapters}/${task.totalChapters})');
        }

        _serverTasks[task.id] = task;
      }
    } catch (e) {
      debugPrint('CacheManager: 轮询服务端任务失败: $e');
    }
  }

  /// 创建服务端缓存任务
  Future<int?> createServerCacheTask(String novelUrl) async {
    try {
      await _ensureApiReady();
      final task = await _api.createCacheTask(novelUrl);

      if (task.id > 0) {
        _serverTasks[task.id] = task;
        debugPrint('CacheManager: 创建服务端缓存任务成功 - ${task.novelTitle}');
        return task.id;
      } else {
        debugPrint('CacheManager: 创建服务端缓存任务失败');
        return null;
      }
    } catch (e) {
      debugPrint('CacheManager: 创建服务端缓存任务异常: $e');
      return null;
    }
  }

  /// 取消服务端缓存任务
  Future<bool> cancelServerCacheTask(int taskId) async {
    try {
      await _ensureApiReady();
      final success = await _api.cancelCacheTask(taskId);

      if (success) {
        _serverTasks.remove(taskId);
        debugPrint('CacheManager: 取消服务端缓存任务成功 - 任务ID: $taskId');
        return true;
      } else {
        debugPrint('CacheManager: 取消服务端缓存任务失败');
        return false;
      }
    } catch (e) {
      debugPrint('CacheManager: 取消服务端缓存任务异常: $e');
      return false;
    }
  }

  /// 获取服务端缓存任务状态
  CacheTask? getServerTaskStatus(int taskId) {
    return _serverTasks[taskId];
  }

  /// 获取缓存同步服务实例
  CacheSyncService get syncService => _syncService;

  /// 获取所有服务端缓存任务
  List<CacheTask> getAllServerTasks() {
    return _serverTasks.values.toList();
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
        await _db.cacheChapter(
            novelUrl,
            Chapter(
              title: chapter.title,
              url: chapter.url,
              chapterIndex: chapter.chapterIndex,
            ),
            content);
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
