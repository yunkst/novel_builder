/// 统一章节管理单例
///
/// 负责管理所有章节相关的操作，包括：
/// - 章节内容获取
/// - 预加载管理
/// - 请求去重
/// - 状态同步
library chapter_manager;

import 'dart:async';
import 'dart:math';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// 统一章节管理器单例
///
/// 提供全局的章节管理功能，解决多实例重复请求问题
class ChapterManager {
  /// 单例实例
  static final ChapterManager _instance = ChapterManager._internal();
  factory ChapterManager() => _instance;
  ChapterManager._internal() {
    _initializeCleanupTimer();
  }

  /// 正在预加载的章节URL集合
  final Set<String> _preloadingChapters = <String>{};

  /// 应用生命周期内已预加载完成的章节URL集合
  final Set<String> _preloadedChapterUrls = <String>{};

  /// 待处理的网络请求 Map&lt;chapterUrl, Future&lt;String&gt;&gt;
  final Map<String, Future<String>> _pendingRequests = <String, Future<String>>{};

  /// 预加载任务 Map&lt;chapterUrl, Completer&lt;void&gt;&gt;
  final Map<String, Completer<void>> _preloadTasks = <String, Completer<void>>{};

  /// 请求时间戳，用于清理过期请求
  final Map<String, DateTime> _requestTimestamps = <String, DateTime>{};

  /// 清理过期请求的定时器
  Timer? _cleanupTimer;

  /// 请求超时时间
  static const Duration _requestTimeout = Duration(minutes: 2);

  /// 预加载超时时间
  static const Duration _preloadTimeout = Duration(minutes: 5);

  /// 统计信息
  int _totalRequests = 0;
  int _deduplicatedRequests = 0;
  int _preloadedChapters = 0;

  /// 获取章节内容（带请求去重）
  ///
  /// [chapterUrl] 章节URL
  /// [forceRefresh] 是否强制刷新，绕过所有缓存
  /// [fetchFunction] 实际的网络获取函数
  ///
  /// 返回章节内容字符串
  Future<String> getChapterContent(
    String chapterUrl, {
    bool forceRefresh = false,
    required Future<String> Function() fetchFunction,
  }) async {
    _totalRequests++;

    // 强制刷新总是创建新请求，不去重
    if (forceRefresh) {
      debugPrint('🔄 强制刷新章节: $chapterUrl');
      return await fetchFunction();
    }

    // 检查是否已有相同请求在进行中
    if (_pendingRequests.containsKey(chapterUrl)) {
      _deduplicatedRequests++;
      debugPrint('🔗 请求去重: 复用现有请求 - $chapterUrl');
      return _pendingRequests[chapterUrl]!;
    }

    // 创建新请求
    debugPrint('🆕 发起章节请求: $chapterUrl');
    final requestFuture = _createRequest(chapterUrl, fetchFunction);

    // 存储请求
    _pendingRequests[chapterUrl] = requestFuture;
    _requestTimestamps[chapterUrl] = DateTime.now();

    try {
      final result = await requestFuture;
      return result;
    } catch (e) {
      debugPrint('❌ 章节请求失败: $chapterUrl, 错误: $e');
      rethrow;
    } finally {
      // 清理完成的请求
      _cleanupRequest(chapterUrl);
    }
  }

  /// 预加载章节内容
  ///
  /// [chapterUrl] 章节URL
  /// [fetchFunction] 实际的网络获取函数
  /// [onProgress] 进度回调
  ///
  /// 返回预加载完成的Future
  Future<void> preloadChapter(
    String chapterUrl, {
    required Future<String> Function() fetchFunction,
    void Function(String)? onProgress,
  }) async {
    // 检查是否已预加载完成
    if (_preloadedChapterUrls.contains(chapterUrl)) {
      debugPrint('✅ 章节已预加载: $chapterUrl');
      return;
    }

    // 检查是否正在预加载
    if (_preloadingChapters.contains(chapterUrl)) {
      debugPrint('⏳ 等待预加载完成: $chapterUrl');
      return _waitForPreload(chapterUrl);
    }

    // 检查是否已有预加载任务
    if (_preloadTasks.containsKey(chapterUrl)) {
      debugPrint('⏳ 复用预加载任务: $chapterUrl');
      return _preloadTasks[chapterUrl]!.future;
    }

    // 创建新的预加载任务
    final completer = Completer<void>();
    _preloadTasks[chapterUrl] = completer;
    _preloadingChapters.add(chapterUrl);

    debugPrint('🚀 开始预加载章节: $chapterUrl');
    onProgress?.call('开始预加载: $chapterUrl');

    try {
      // 通过getChapterContent获取内容，确保请求去重
      final content = await getChapterContent(chapterUrl, fetchFunction: fetchFunction);

      if (content.isNotEmpty) {
        _preloadedChapterUrls.add(chapterUrl);
        _preloadedChapters++;
        debugPrint('✅ 预加载完成: $chapterUrl (${content.length} 字符)');
        onProgress?.call('预加载完成: $chapterUrl');
      } else {
        debugPrint('⚠️ 预加载内容为空: $chapterUrl');
        onProgress?.call('预加载内容为空: $chapterUrl');
      }

      completer.complete();
    } catch (e) {
      debugPrint('❌ 预加载失败: $chapterUrl, 错误: $e');
      onProgress?.call('预加载失败: $chapterUrl');
      completer.completeError(e);
    } finally {
      _preloadingChapters.remove(chapterUrl);
      _preloadTasks.remove(chapterUrl);
    }
  }

  /// 批量预加载章节
  ///
  /// [chapterUrls] 章节URL列表
  /// [fetchFunction] 网络获取函数
  /// [onProgress] 进度回调
  /// [maxConcurrent] 最大并发数
  ///
  /// 返回预加载完成的Future
  Future<void> preloadChapters(
    List<String> chapterUrls, {
    required Future<String> Function(String) fetchFunction,
    void Function(String, int, int)? onProgress,
    int maxConcurrent = 3,
  }) async {
    if (chapterUrls.isEmpty) return;

    debugPrint('📦 开始批量预加载: ${chapterUrls.length} 个章节');

    final semaphore = _Semaphore(maxConcurrent);
    final futures = <Future<void>>[];

    for (int i = 0; i < chapterUrls.length; i++) {
      final chapterUrl = chapterUrls[i];

      final future = semaphore.acquire().then((_) async {
        try {
          await preloadChapter(
            chapterUrl,
            fetchFunction: () => fetchFunction(chapterUrl),
            onProgress: (message) {
              onProgress?.call(message, i + 1, chapterUrls.length);
            },
          );
        } finally {
          semaphore.release();
        }
      });

      futures.add(future);
    }

    try {
      await Future.wait(futures);
      debugPrint('✅ 批量预加载完成: ${chapterUrls.length} 个章节');
    } catch (e) {
      debugPrint('⚠️ 批量预加载部分失败: $e');
    }
  }

  /// 检查章节是否正在处理中（预加载或已预加载）
  bool isChapterBeingProcessed(String chapterUrl) {
    return _preloadingChapters.contains(chapterUrl) ||
           _preloadedChapterUrls.contains(chapterUrl) ||
           _pendingRequests.containsKey(chapterUrl) ||
           _preloadTasks.containsKey(chapterUrl);
  }

  /// 检查章节是否已预加载
  bool isChapterPreloaded(String chapterUrl) {
    return _preloadedChapterUrls.contains(chapterUrl);
  }

  /// 检查章节是否正在预加载
  bool isChapterPreloading(String chapterUrl) {
    return _preloadingChapters.contains(chapterUrl);
  }

  /// 获取预加载状态统计
  Map<String, int> getStatistics() {
    return {
      'total_requests': _totalRequests,
      'deduplicated_requests': _deduplicatedRequests,
      'preloaded_chapters': _preloadedChapters,
      'pending_requests': _pendingRequests.length,
      'preloading_chapters': _preloadingChapters.length,
    };
  }

  /// 清理过期的预加载状态（定期调用）
  void cleanupExpiredStates() {
    final now = DateTime.now();
    final expiredUrls = <String>[];

    // 清理过期的请求时间戳
    _requestTimestamps.removeWhere((url, timestamp) {
      final isExpired = now.difference(timestamp) > _requestTimeout;
      if (isExpired) {
        expiredUrls.add(url);
      }
      return isExpired;
    });

    // 清理对应的待处理请求
    for (final url in expiredUrls) {
      _pendingRequests.remove(url);
    }

    if (expiredUrls.isNotEmpty) {
      debugPrint('🧹 清理过期状态: ${expiredUrls.length} 个请求');
    }
  }

  /// 重置所有状态（仅用于测试）
  void reset() {
    _preloadingChapters.clear();
    _preloadedChapterUrls.clear();
    _pendingRequests.clear();
    _preloadTasks.clear();
    _requestTimestamps.clear();
    _totalRequests = 0;
    _deduplicatedRequests = 0;
    _preloadedChapters = 0;
    debugPrint('🔄 ChapterManager 状态已重置');
  }

  /// 创建网络请求
  Future<String> _createRequest(String chapterUrl, Future<String> Function() fetchFunction) async {
    try {
      return await fetchFunction();
    } catch (e) {
      debugPrint('❌ 网络请求失败: $chapterUrl, 错误: $e');
      rethrow;
    }
  }

  /// 等待预加载完成
  Future<void> _waitForPreload(String chapterUrl) async {
    final task = _preloadTasks[chapterUrl];
    if (task != null) {
      return task.future.timeout(_preloadTimeout);
    }
  }

  /// 清理请求状态
  void _cleanupRequest(String chapterUrl) {
    _pendingRequests.remove(chapterUrl);
    _requestTimestamps.remove(chapterUrl);
  }

  /// 初始化清理定时器
  void _initializeCleanupTimer() {
    _cleanupTimer = Timer.periodic(Duration(minutes: 1), (_) {
      cleanupExpiredStates();
    });
  }

  /// 销毁资源
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    reset();
    debugPrint('🗑️ ChapterManager 已销毁');
  }
}

/// 简单的信号量实现，用于控制并发数量
class _Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  _Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}