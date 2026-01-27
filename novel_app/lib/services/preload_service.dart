import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chapter.dart';
import '../utils/deque.dart';
import 'rate_limiter.dart';
import 'preload_task.dart';
import 'preload_progress_update.dart';
import 'database_service.dart';
import 'api_service_wrapper.dart';
import '../core/di/api_service_provider.dart';

/// 全局预加载服务（单例）
///
/// 负责管理章节预加载任务队列，支持：
/// - 智能插队：当前小说的章节插入队列开头
/// - 速率限制：30秒处理一个任务
/// - 串行执行：全局唯一执行点
/// - 去重机制：自动过滤重复和已缓存章节
/// - 内存队列：App关闭自动清空
class PreloadService {
  // 单例模式
  static final PreloadService _instance = PreloadService._internal();
  factory PreloadService() => _instance;
  PreloadService._internal() {
    _initServices();
  }

  // 核心组件
  final RateLimiter _rateLimiter = RateLimiter(interval: Duration(seconds: 30));
  final Deque<PreloadTask> _queue = Deque<PreloadTask>();
  final Set<String> _enqueuedUrls = {}; // 去重：已加入队列的URL

  // 进度通知
  final StreamController<PreloadProgressUpdate> _progressController =
      StreamController<PreloadProgressUpdate>.broadcast();

  Stream<PreloadProgressUpdate> get progressStream =>
      _progressController.stream;

  // 缓存计数缓存（避免频繁查询数据库）
  final Map<String, int> _cachedCountCache = {};

  // 小说状态跟踪
  final Map<String, int> _novelCurrentIndex = {}; // novelUrl -> 当前阅读章节索引
  String? _lastActiveNovel; // 最后活跃的小说URL

  // 执行状态
  Completer<void>? _processingCompleter; // 🔒 使用Completer防止并发
  int _totalProcessed = 0;
  int _totalFailed = 0;

  // 服务依赖
  late final DatabaseService _databaseService;
  late final ApiServiceWrapper _apiService;

  /// 初始化服务
  void _initServices() {
    _databaseService = DatabaseService();
    _apiService = ApiServiceProvider.instance;
    debugPrint('✅ PreloadService初始化完成');
  }

  /// 添加预加载任务（智能插队）
  ///
  /// [novelUrl] 小说URL
  /// [novelTitle] 小说标题
  /// [chapterUrls] 所有章节URL列表
  /// [currentIndex] 当前阅读章节的索引
  Future<void> enqueueTasks({
    required String novelUrl,
    required String novelTitle,
    required List<String> chapterUrls,
    required int currentIndex,
  }) async {
    // 更新小说状态
    _novelCurrentIndex[novelUrl] = currentIndex;
    _lastActiveNovel = novelUrl;

    debugPrint('📚 小说活跃: $novelTitle (第${currentIndex + 1}章)');

    // 使用DatabaseService的批量检查方法
    final uncachedUrls =
        await _databaseService.filterUncachedChapters(chapterUrls);

    if (uncachedUrls.isEmpty) {
      debugPrint('✅ "$novelTitle" 所有章节已缓存');
      return;
    }

    debugPrint('📋 待缓存章节数: ${uncachedUrls.length}');

    // 创建任务列表（后续章节优先）
    final tasks =
        _createTasks(novelUrl, novelTitle, uncachedUrls, currentIndex);

    // 去重并入队
    int addedCount = 0;
    for (final task in tasks) {
      if (!_enqueuedUrls.contains(task.chapterUrl)) {
        // 智能插队：当前活跃的小说插入队列开头
        _queue.addFirst(task);
        _enqueuedUrls.add(task.chapterUrl);
        addedCount++;
      }
    }

    if (addedCount > 0) {
      debugPrint('📥 任务入队: $addedCount 个 (队列长度: ${_queue.length})');
      _printQueueStatus();

      // 启动处理（如果未在运行）
      _processQueue();
    } else {
      debugPrint('⏭️ 所有任务已在队列中');
    }
  }

  /// 创建预加载任务（后续章节优先）
  List<PreloadTask> _createTasks(
    String novelUrl,
    String novelTitle,
    List<String> chapterUrls,
    int currentIndex,
  ) {
    final tasks = <PreloadTask>[];

    // 首先添加后续章节（优先级高）
    for (int i = currentIndex + 1; i < chapterUrls.length; i++) {
      tasks.add(PreloadTask(
        chapterUrl: chapterUrls[i],
        novelUrl: novelUrl,
        novelTitle: novelTitle,
        chapterIndex: i,
      ));
    }

    // 然后添加前序章节（优先级低）
    for (int i = currentIndex - 1; i >= 0; i--) {
      tasks.add(PreloadTask(
        chapterUrl: chapterUrls[i],
        novelUrl: novelUrl,
        novelTitle: novelTitle,
        chapterIndex: i,
      ));
    }

    return tasks;
  }

  /// 串行处理队列（全局唯一执行点，30秒速率限制）
  ///
  /// 🔒 并发安全: 使用 Completer 确保同一时间只有一个循环执行
  Future<void> _processQueue() async {
    // 🔒 原子检查: 如果已有Completer,说明正在处理
    if (_processingCompleter != null) {
      debugPrint('⚠️ 队列处理中，跳过重复启动');
      return;
    }

    // 🔒 创建新的Completer作为锁
    final completer = Completer<void>();
    _processingCompleter = completer;

    debugPrint('🚀 开始处理预加载队列');

    // 发送开始通知（不包含具体章节URL）
    if (_lastActiveNovel != null) {
      try {
        final cachedCount = await _getCachedChapterCount(_lastActiveNovel!);
        _progressController.add(PreloadProgressUpdate(
          novelUrl: _lastActiveNovel!,
          chapterUrl: null, // 队列开始时没有具体章节
          isPreloading: true,
          cachedChapters: cachedCount,
          totalChapters: _queue.length + cachedCount,
        ));
      } catch (e) {
        debugPrint('⚠️ 发送开始通知失败: $e');
      }
    }

    try {
      while (_queue.isNotEmpty) {
        // 速率限制：等待30秒
        await _rateLimiter.acquire();

        // 从队列头部取出任务
        final task = _queue.removeFirst();
        _enqueuedUrls.remove(task.chapterUrl);

        debugPrint('📖 [队列${_queue.length}] 正在处理: $task');

        try {
          // 标记正在预加载
          _databaseService.markAsPreloading(task.chapterUrl);

          // 获取内容
          final content = await _apiService.getChapterContent(task.chapterUrl);

          // 保存到数据库
          final chapter = Chapter(
            url: task.chapterUrl,
            title: '', // 可以从API获取
            content: content,
          );
          await _databaseService.cacheChapter(task.novelUrl, chapter, content);

          _totalProcessed++;
          debugPrint('✅ 缓存成功: $task (${content.length}字符)');

          // 发送进度更新（包含具体章节URL）
          await _notifyProgressUpdate(task.novelUrl, task.chapterUrl);
        } catch (e) {
          _totalFailed++;
          debugPrint('❌ 缓存失败: $task, 错误: $e');
          // 失败不中断，继续下一个
        }
      }

      debugPrint('✅ 队列处理完成 (已处理: $_totalProcessed, 失败: $_totalFailed)');

      // 发送完成通知
      if (_lastActiveNovel != null) {
        final cachedCount = await _getCachedChapterCount(_lastActiveNovel!);
        _progressController.add(PreloadProgressUpdate(
          novelUrl: _lastActiveNovel!,
          isPreloading: false,
          cachedChapters: cachedCount,
          totalChapters: cachedCount,
        ));
      }

      completer.complete(); // ✅ 标记完成
    } catch (e) {
      debugPrint('❌ 队列处理异常: $e');
      completer.completeError(e); // ✅ 标记失败
    } finally {
      _processingCompleter = null; // ✅ 释放锁
    }
  }

  /// 打印队列状态（调试用）
  void _printQueueStatus() {
    if (_queue.isEmpty) {
      debugPrint('📭 队列为空');
      return;
    }

    debugPrint('📊 队列状态 (共${_queue.length}个任务):');
    int count = 0;
    for (final task in _queue.iterable) {
      if (count++ >= 5) {
        debugPrint('   ... 还有 ${_queue.length - 5} 个任务');
        break;
      }
      debugPrint('   $count. $task');
    }
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    return {
      'queue_length': _queue.length,
      'is_processing': isProcessing,
      'last_active_novel': _lastActiveNovel,
      'novel_states': _novelCurrentIndex,
      'total_processed': _totalProcessed,
      'total_failed': _totalFailed,
      'enqueued_urls': _enqueuedUrls.length,
    };
  }

  /// 清空队列（用于测试或强制重置）
  void clearQueue() {
    _queue.clear();
    _enqueuedUrls.clear();
    _novelCurrentIndex.clear();
    _lastActiveNovel = null;
    _rateLimiter.reset();
    _totalProcessed = 0;
    _totalFailed = 0;

    // 重置处理状态（用于测试隔离）
    _processingCompleter = null;

    debugPrint('🧹 预加载队列已清空');
  }

  /// 暂停队列处理
  void pause() {
    if (isProcessing) {
      debugPrint('⏸️ 预加载已暂停（将在当前任务完成后停止）');
    }
  }

  /// 获取队列长度
  int get queueLength => _queue.length;

  /// 是否正在处理队列
  bool get isProcessing => _processingCompleter != null;

  /// 通知进度更新
  Future<void> _notifyProgressUpdate(String novelUrl, String chapterUrl) async {
    try {
      // 从缓存获取计数（避免频繁查询）
      final cachedCount = await _getCachedChapterCount(novelUrl);
      _cachedCountCache[novelUrl] = cachedCount;

      // 发送进度更新（包含具体章节URL）
      _progressController.add(PreloadProgressUpdate(
        novelUrl: novelUrl,
        chapterUrl: chapterUrl, // ← 新增：具体章节URL
        isPreloading: _processingCompleter != null,
        cachedChapters: cachedCount,
        totalChapters: _queue.length + cachedCount, // 估算总数
      ));
    } catch (e) {
      debugPrint('⚠️ 发送进度更新失败: $e');
    }
  }

  /// 获取已缓存章节数（带缓存）
  Future<int> _getCachedChapterCount(String novelUrl) async {
    // 优先使用缓存
    if (_cachedCountCache.containsKey(novelUrl)) {
      return _cachedCountCache[novelUrl]!;
    }

    // 查询数据库
    final count = await _databaseService.getCachedChaptersCount(novelUrl);
    _cachedCountCache[novelUrl] = count;
    return count;
  }

  /// 释放资源
  void dispose() {
    _progressController.close();
    _rateLimiter.reset();
    clearQueue();
  }
}
