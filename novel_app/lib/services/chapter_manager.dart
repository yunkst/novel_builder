import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chapter_content_result.dart';

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
      debugPrint('⚠️  ChapterManager: 实例已创建,无法更改测试模式');
      return;
    }
    _isTestMode = enabled;
  }

  ChapterManager._internal() {
    _initializeCleanupTimer();
  }

  /// 待处理的网络请求，key为章节URL，value为Future<ChapterContentResult>
  final Map<String, Future<ChapterContentResult>> _pendingRequests =
      <String, Future<ChapterContentResult>>{};

  /// 请求时间戳，用于清理过期请求
  final Map<String, DateTime> _requestTimestamps = <String, DateTime>{};

  /// 清理过期请求的定时器
  Timer? _cleanupTimer;

  /// 请求超时时间
  static const Duration _requestTimeout = Duration(minutes: 2);

  /// 统计信息
  int _totalRequests = 0;
  int _deduplicatedRequests = 0;

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
      final result = await _pendingRequests[chapterUrl]!;
      return result.content;
    }

    // 创建新请求
    debugPrint('🆕 发起章节请求: $chapterUrl');
    final requestFuture = _createRequest(chapterUrl, fetchFunction);
    _pendingRequests[chapterUrl] = requestFuture.then((r) => ChapterContentResult(content: r, fromCache: false));
    _requestTimestamps[chapterUrl] = DateTime.now();

    try {
      final result = await _pendingRequests[chapterUrl]!;
      return result.content;
    } catch (e) {
      debugPrint('❌ 章节请求失败: $chapterUrl, 错误: $e');
      rethrow;
    } finally {
      _cleanupRequest(chapterUrl);
    }
  }

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
      debugPrint('🧹 清理过期状态: ${expiredUrls.length} 个请求');
    }
  }

  /// 重置所有状态（仅用于测试）
  void reset() {
    _pendingRequests.clear();
    _requestTimestamps.clear();
    _totalRequests = 0;
    _deduplicatedRequests = 0;
    debugPrint('🔄 ChapterManager 状态已重置');
  }

  /// 创建网络请求
  Future<String> _createRequest(
      String chapterUrl, Future<String> Function() fetchFunction) async {
    try {
      return await fetchFunction();
    } catch (e) {
      debugPrint('❌ 网络请求失败: $chapterUrl, 错误: $e');
      rethrow;
    }
  }

  /// 清理请求
  void _cleanupRequest(String chapterUrl) {
    _pendingRequests.remove(chapterUrl);
    _requestTimestamps.remove(chapterUrl);
  }

  /// 获取章节内容（带来源标识，带请求去重）
  ///
  /// [chapterUrl] 章节URL
  /// [forceRefresh] 是否强制刷新，绕过所有缓存
  /// [fetchFunction] 实际的网络获取函数
  ///
  /// 返回 ChapterContentResult（包含 content 和 fromCache）
  Future<ChapterContentResult> getChapterContentWithSource(
    String chapterUrl, {
    bool forceRefresh = false,
    required Future<ChapterContentResult> Function() fetchFunction,
  }) async {
    _totalRequests++;

    if (forceRefresh) {
      debugPrint('🔄 强制刷新章节: $chapterUrl');
      return await fetchFunction();
    }

    // 检查是否已有相同请求在进行中
    if (_pendingRequests.containsKey(chapterUrl)) {
      _deduplicatedRequests++;
      debugPrint('🔗 请求去重: 复用现有请求 - $chapterUrl');
      return await _pendingRequests[chapterUrl]!;
    }

    debugPrint('🆕 发起章节请求: $chapterUrl');

    // 创建新请求并缓存 Future
    final requestFuture = _createRequestWithSource(chapterUrl, fetchFunction);
    _pendingRequests[chapterUrl] = requestFuture;
    _requestTimestamps[chapterUrl] = DateTime.now();

    try {
      final result = await requestFuture;
      return result;
    } catch (e) {
      debugPrint('❌ 章节请求失败: $chapterUrl, 错误: $e');
      rethrow;
    } finally {
      _cleanupRequest(chapterUrl);
    }
  }

  /// 创建网络请求（带来源）
  Future<ChapterContentResult> _createRequestWithSource(
      String chapterUrl, Future<ChapterContentResult> Function() fetchFunction) async {
    try {
      return await fetchFunction();
    } catch (e) {
      debugPrint('❌ 网络请求失败: $chapterUrl, 错误: $e');
      rethrow;
    }
  }

  /// 初始化清理定时器
  void _initializeCleanupTimer() {
    // 在测试模式中不启动定时器,避免"Pending timers"错误
    if (_isTestMode) {
      debugPrint('⚠️  ChapterManager: 测试模式中跳过定时器初始化');
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
    debugPrint('🗑️ ChapterManager 已销毁');
  }
}
