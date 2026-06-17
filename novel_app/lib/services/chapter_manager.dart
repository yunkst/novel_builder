import 'dart:async';
import 'logger_service.dart';

/// 章节请求管理器单例
///
/// 负责管理章节请求的去重和状态跟踪，避免重复的网络请求。
///
/// 主要功能：
/// - 请求去重：同一章节的多个请求合并为一个
/// - 状态管理：跟踪正在请求和已完成的章节
/// - 过期清理：定期清理过期的请求状态
///
/// 注意：预加载功能已迁移到 PreloadService
class ChapterManager {
  /// 单例实例
  static ChapterManager? _instance;
  static ChapterManager get instance {
    _instance ??= ChapterManager._internal();
    return _instance!;
  }

  factory ChapterManager() => instance;

  /// 测试模式标志(用于禁用定时器)
  static bool _isTestMode = false;

  /// 设置测试模式(必须在首次访问instance之前调用)
  static void setTestMode(bool enabled) {
    if (_instance != null) {
      LoggerService.instance.w(
        'ChapterManager: 实例已创建,无法更改测试模式',
        category: LogCategory.database,
        tags: ['chapter'],
      );
      return;
    }
    _isTestMode = enabled;
  }

  ChapterManager._internal() {
    _initializeCleanupTimer();
  }

  /// 待处理的网络请求，key为章节URL，value为`Future<String>`
  final Map<String, Future<String>> _pendingRequests =
      <String, Future<String>>{};

  /// 请求时间戳，用于清理过期请求
  final Map<String, DateTime> _requestTimestamps = <String, DateTime>{};

  /// 清理过期请求的定时器
  Timer? _cleanupTimer;

  /// 请求超时时间
  static const Duration _requestTimeout = Duration(minutes: 2);

  /// 统计信息
  int _totalRequests = 0;
  int _deduplicatedRequests = 0;

  /// 检查章节是否有待处理的请求
  bool hasPendingRequest(String chapterUrl) {
    return _pendingRequests.containsKey(chapterUrl);
  }

  /// 获取统计信息
  Map<String, int> getStatistics() {
    return {
      'total_requests': _totalRequests,
      'deduplicated_requests': _deduplicatedRequests,
      'pending_requests': _pendingRequests.length,
    };
  }

  /// 清理过期的请求状态（定期调用）
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
      LoggerService.instance.d(
        '清理过期状态: ${expiredUrls.length} 个请求',
        category: LogCategory.database,
        tags: ['chapter'],
      );
    }
  }

  /// 重置所有状态（仅用于测试）
  void reset() {
    _pendingRequests.clear();
    _requestTimestamps.clear();
    _totalRequests = 0;
    _deduplicatedRequests = 0;
    LoggerService.instance.i(
      'ChapterManager 状态已重置',
      category: LogCategory.database,
      tags: ['chapter'],
    );
  }

  /// 清理请求
  void _cleanupRequest(String chapterUrl) {
    _pendingRequests.remove(chapterUrl);
    _requestTimestamps.remove(chapterUrl);
  }

  /// 初始化清理定时器
  void _initializeCleanupTimer() {
    // 在测试模式中不启动定时器,避免"Pending timers"错误
    if (_isTestMode) {
      LoggerService.instance.w(
        'ChapterManager: 测试模式中跳过定时器初始化',
        category: LogCategory.database,
        tags: ['chapter'],
      );
      return;
    }

    _cleanupTimer = Timer.periodic(Duration(minutes: 1), (_) {
      cleanupExpiredStates();
    });
  }

  /// 销毁资源
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    reset();
    LoggerService.instance.i(
      'ChapterManager 已销毁',
      category: LogCategory.database,
      tags: ['chapter'],
    );
  }
}
