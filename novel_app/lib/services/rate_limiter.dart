import 'dart:async';
import 'package:flutter/foundation.dart';

/// 速率限制器
///
/// 确保操作之间至少间隔指定的时间
class RateLimiter {
  /// 时间间隔
  final Duration interval;

  /// 上次请求的时间戳
  DateTime? _lastRequestTime;

  /// 创建速率限制器
  ///
  /// [interval] 时间间隔，默认30秒
  RateLimiter({this.interval = const Duration(seconds: 30)});

  /// 获取执行许可（自动等待）
  ///
  /// 如果距离上次请求不足interval时间，会自动等待剩余时间
  Future<void> acquire() async {
    if (_lastRequestTime == null) {
      // 第一次请求，无需等待
      _lastRequestTime = DateTime.now();
      return;
    }

    final elapsed = DateTime.now().difference(_lastRequestTime!);

    if (elapsed < interval) {
      // 需要等待剩余时间
      final waitTime = interval - elapsed;
      debugPrint('⏳ 速率限制: 等待 ${waitTime.inSeconds} 秒');
      await Future.delayed(waitTime);
    }

    // 更新最后请求时间
    _lastRequestTime = DateTime.now();
  }

  /// 重置速率限制器
  ///
  /// 重置后，下一次acquire()将立即返回
  void reset() {
    _lastRequestTime = null;
    debugPrint('🔄 速率限制器已重置');
  }

  /// 获取距离下次可请求的时间
  ///
  /// 如果可以立即请求，返回Duration.zero
  Duration get timeUntilNextRequest {
    if (_lastRequestTime == null) {
      return Duration.zero;
    }

    final elapsed = DateTime.now().difference(_lastRequestTime!);
    if (elapsed >= interval) {
      return Duration.zero;
    }

    return interval - elapsed;
  }

  /// 检查是否可以立即请求（无需等待）
  bool get canRequestImmediately {
    return timeUntilNextRequest == Duration.zero;
  }
}
