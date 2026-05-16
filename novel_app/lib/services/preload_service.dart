import 'dart:async';
import '../models/chapter.dart';
import '../utils/deque.dart';
import 'rate_limiter.dart';
import 'preload_task.dart';
import 'preload_progress_update.dart';
import '../repositories/chapter_repository.dart';
import 'api_service_wrapper.dart';
import 'logger_service.dart';

/// 全局预加载服务
///
/// 负责管理章节预加载任务队列，支持：
/// - 智能插队：当前小说的章节插入队列开头
/// - 速率限制：30秒处理一个任务
/// - 串行执行：全局唯一执行点
/// - 去重机制：自动过滤重复和已缓存章节
/// - 内存队列：App关闭自动清空
///
/// 架构说明：
/// - 使用依赖注入，通过 Riverpod Provider 管理
/// - ApiServiceWrapper 和 ChapterRepository 通过构造函数注入
/// - 不再使用单例模式，每次通过 Provider 获取实例
class PreloadService {
  // 核心组件
  final RateLimiter _rateLimiter = RateLimiter(interval: Duration(seconds: 30));
  final Deque<PreloadTask> _queue = Deque<PreloadTask>();
  final Set<String> _enqueuedUrls = {}; // 去重：已加入队列的URL

  // 进度通知（供章节列表页面实时更新缓存状态）
  final StreamController<PreloadProgressUpdate> _progressController =
      StreamController<PreloadProgressUpdate>.broadcast();

  Stream<PreloadProgressUpdate> get progressStream =>
      _progressController.stream;

  // 小说状态跟踪
  final Map<String, int> _novelCurrentIndex = {}; // novelUrl -> 当前阅读章节索引
  String? _lastActiveNovel; // 最后活跃的小说URL

  // 执行状态
  Completer<void>? _processingCompleter; // 🔒 使用Completer防止并发
  bool _shouldStop = false; // 停止标志（用于测试清理）
  int _totalProcessed = 0;
  int _totalFailed = 0;

  // 服务依赖（通过构造函数注入）
  final ApiServiceWrapper _apiService;
  final ChapterRepository _chapterRepository;

  /// 构造函数
  ///
  /// 通过依赖注入接收 ApiServiceWrapper 和 ChapterRepository
  PreloadService({
    required ApiServiceWrapper apiService,
    required ChapterRepository chapterRepository,
  })  : _apiService = apiService,
        _chapterRepository = chapterRepository {
    _logInitialization();
  }

  /// 记录初始化日志
  void _logInitialization() {
    LoggerService.instance.i(
      'PreloadService初始化完成',
      category: LogCategory.cache,
      tags: ['preload', 'init'],
    );
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

    // 使用ChapterRepository的批量检查方法
    final uncachedUrls =
        await _chapterRepository.filterUncachedChapters(chapterUrls);

    if (uncachedUrls.isEmpty) {
      LoggerService.instance.i(
        '✅ "$novelTitle" 所有章节已缓存',
        category: LogCategory.cache,
        tags: ['preload', novelUrl],
      );
      return;
    }

    // 查找当前章节在过滤后列表中的索引
    final currentChapterUrl =
        currentIndex >= 0 && currentIndex < chapterUrls.length
            ? chapterUrls[currentIndex]
            : null;
    final filteredIndex = currentChapterUrl != null
        ? uncachedUrls.indexOf(currentChapterUrl)
        : -1;

    // 创建任务列表（后续章节优先）
    // 使用过滤后的索引，避免数组越界
    final tasks = _createTasks(
      novelUrl,
      novelTitle,
      uncachedUrls,
      filteredIndex >= 0 ? filteredIndex : (uncachedUrls.length - 1),
    );

    // 去重并入队
    int addedCount = 0;
    for (final task in tasks) {
      if (!_enqueuedUrls.contains(task.chapterUrl)) {
        _queue.addLast(task);
        _enqueuedUrls.add(task.chapterUrl);
        addedCount++;
      }
    }

    if (addedCount > 0) {
      LoggerService.instance.i(
        '📚 开始预加载: $novelTitle, 当前第${currentIndex + 1}章, 待缓存$addedCount个',
        category: LogCategory.cache,
        tags: ['preload', novelUrl, 'start'],
      );

      // 启动处理（如果未在运行）
      _processQueue();
    } else {
      LoggerService.instance.d(
        '⏭️ 所有任务已在队列中',
        category: LogCategory.cache,
        tags: ['preload', novelUrl],
      );
    }
  }

  /// 创建预加载任务（后续章节优先）
  ///
  /// [currentIndex] 应该是基于 [chapterUrls] 的索引，必须保证在有效范围内
  List<PreloadTask> _createTasks(
    String novelUrl,
    String novelTitle,
    List<String> chapterUrls,
    int currentIndex,
  ) {
    final tasks = <PreloadTask>[];

    // 边界检查：确保索引在有效范围内
    if (chapterUrls.isEmpty) {
      LoggerService.instance.w(
        '章节列表为空，无法创建预加载任务',
        category: LogCategory.cache,
        tags: ['preload', 'warning'],
      );
      return tasks;
    }

    // 如果索引超出范围，默认使用最后一个章节
    final safeIndex = currentIndex.clamp(0, chapterUrls.length - 1);

    // 首先添加后续章节（优先级高）
    for (int i = safeIndex + 1; i < chapterUrls.length; i++) {
      tasks.add(PreloadTask(
        chapterUrl: chapterUrls[i],
        novelUrl: novelUrl,
        novelTitle: novelTitle,
        chapterIndex: i,
      ));
    }

    // 然后添加前序章节（优先级低）
    for (int i = safeIndex - 1; i >= 0; i--) {
      tasks.add(PreloadTask(
        chapterUrl: chapterUrls[i],
        novelUrl: novelUrl,
        novelTitle: novelTitle,
        chapterIndex: i,
      ));
    }

    return tasks;
  }

  /// 串行处理队列（智能速率限制：缓存章节无等待，爬虫章节30秒间隔）
  ///
  /// 🔒 并发安全: 使用 Completer 确保同一时间只有一个循环执行
  Future<void> _processQueue() async {
    // 🔒 原子检查: 如果已有Completer,说明正在处理
    if (_processingCompleter != null) {
      return;
    }

    // 🔒 创建新的Completer作为锁
    final completer = Completer<void>();
    _processingCompleter = completer;

    final startTime = DateTime.now();

    try {
      while (_queue.isNotEmpty && !_shouldStop) {
        // 从队列头部取出任务
        final task = _queue.removeFirst();
        _enqueuedUrls.remove(task.chapterUrl);

        try {
          // 标记正在预加载
          _chapterRepository.markAsPreloading(task.chapterUrl);

          // 获取内容（带来源标识）
          final result = await _apiService.getChapterContentWithSource(task.chapterUrl);

          // 保存到数据库
          final chapter = Chapter(
            url: task.chapterUrl,
            title: '',
            content: result.content,
          );
          await _chapterRepository.cacheChapter(
              task.novelUrl, chapter, result.content);

          _totalProcessed++;

          // 每处理5个汇总一次进度
          if (_totalProcessed % 5 == 0) {
            LoggerService.instance.d(
              '预加载进度: $_totalProcessed个已处理, $_totalFailed个失败, 剩余${_queue.length}个',
              category: LogCategory.cache,
              tags: ['preload', 'progress'],
            );
          }

          // 通知章节缓存完成（供章节列表页面更新UI）
          _progressController.add(PreloadProgressUpdate(
            novelUrl: task.novelUrl,
            chapterUrl: task.chapterUrl,
            isPreloading: _processingCompleter != null,
            cachedChapters: 0,
            totalChapters: 0,
          ));

          // 根据来源控制速率
          if (result.fromCache) {
            // 缓存命中：重置速率限制器，下一条可以立即获取
            _rateLimiter.reset();
          } else {
            // 爬虫抓取：等待30秒间隔后再获取下一条
            await _rateLimiter.acquire();
          }
        } catch (e) {
          _totalFailed++;
          // 失败时也等待间隔
          await _rateLimiter.acquire();
        }
      }

      final duration = DateTime.now().difference(startTime);
      LoggerService.instance.i(
        '✅ 预加载完成: 成功$_totalProcessed个, 失败$_totalFailed个, 耗时${duration.inSeconds}s',
        category: LogCategory.cache,
        tags: ['preload', 'complete'],
      );

      completer.complete(); // ✅ 标记完成
    } catch (e) {
      LoggerService.instance.e(
        '❌ 队列处理异常: $e',
        category: LogCategory.cache,
        tags: ['preload', 'error'],
      );
      completer.completeError(e); // ✅ 标记失败
    } finally {
      _processingCompleter = null; // ✅ 释放锁
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
  Future<void> clearQueue() async {
    // 设置停止标志,让正在运行的任务退出循环
    _shouldStop = true;

    // 清空队列
    _queue.clear();
    _enqueuedUrls.clear();
    _novelCurrentIndex.clear();
    _lastActiveNovel = null;
    _rateLimiter.reset();
    _totalProcessed = 0;
    _totalFailed = 0;

    // 等待正在运行的任务完成
    if (_processingCompleter != null && !_processingCompleter!.isCompleted) {
      try {
        await _processingCompleter!.future.timeout(
          Duration(seconds: 2),
          onTimeout: () {
            // 超时后强制重置
            _processingCompleter = null;
          },
        );
      } catch (e) {
        // 忽略错误,强制重置
      }
    }

    // 重置处理状态和停止标志
    _processingCompleter = null;
    _shouldStop = false;

    LoggerService.instance.i(
      '预加载队列已清空',
      category: LogCategory.cache,
      tags: ['preload', 'clear'],
    );
  }

  /// 暂停队列处理
  void pause() {
    if (isProcessing) {
      LoggerService.instance.i(
        '预加载已暂停（将在当前任务完成后停止）',
        category: LogCategory.cache,
        tags: ['preload', 'pause'],
      );
    }
  }

  /// 获取队列长度
  int get queueLength => _queue.length;

  /// 是否正在处理队列
  bool get isProcessing => _processingCompleter != null;

  /// 释放资源
  void dispose() {
    _progressController.close();
    _rateLimiter.reset();
    clearQueue();
  }
}
