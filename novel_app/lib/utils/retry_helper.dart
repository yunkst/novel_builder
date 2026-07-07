/// 通用指数退避重试工具
///
/// 设计目标：
/// - 仅用于阻塞调用（[Future<T>]）；流式重试由调用方控制握手阶段后 [yield*]
/// - 默认仅重试瞬态错误（网络/超时/5xx），4xx 业务错误立即抛出
/// - 退避：initialDelay * multiplier^(attempt-1)，clamp 到 maxDelay
/// - 抖动：±jitterFactor（默认 25%），避免雷鸣群
///
/// 用法：
/// ```dart
/// final body = await withRetry(
///   () => client.postJson(url, headers, body),
///   config: const RetryConfig(maxAttempts: 3),
///   label: 'llm_post',
/// );
/// ```
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../services/logger_service.dart';

/// 区分可重试与不可重试 HTTP 错误
///
/// 5xx 走 [RetryableHttpException]，4xx 走 [NonRetryableHttpException]。
/// [RetryConfig.defaultShouldRetry] 据此决定是否重试。
class RetryableHttpException implements Exception {
  final int statusCode;
  final String body;
  final String url;
  const RetryableHttpException(this.statusCode, this.body, this.url);

  @override
  String toString() =>
      'RetryableHttpException(status=$statusCode, url=$url)';
}

class NonRetryableHttpException implements Exception {
  final int statusCode;
  final String body;
  final String url;
  const NonRetryableHttpException(this.statusCode, this.body, this.url);

  @override
  String toString() =>
      'NonRetryableHttpException(status=$statusCode, url=$url)';
}

/// 重试策略
class RetryConfig {
  /// 总尝试次数（含首次）。默认 3。
  final int maxAttempts;

  /// 首次重试前的等待。默认 1s。
  final Duration initialDelay;

  /// 单次退避上限。默认 30s。
  final Duration maxDelay;

  /// 退避倍数。默认 2.0（1s → 2s → 4s ...）。
  final double multiplier;

  /// 抖动比例 0..1，默认 0.25（±25%）。
  final double jitterFactor;

  /// 自定义重试判定。为 null 时用 [defaultShouldRetry]。
  final bool Function(Object error)? shouldRetry;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.jitterFactor = 0.25,
    this.shouldRetry,
  });

  /// 默认重试判定：网络/超时/5xx 重试，4xx / 解析错误不重试
  static bool defaultShouldRetry(Object error) {
    if (error is SocketException) return true;
    if (error is HandshakeException) return true;
    if (error is TimeoutException) return true;
    if (error is HttpException) return true;
    if (error is RetryableHttpException) return true;
    return false;
  }
}

final _rand = Random();

/// 用 [config] 包裹 [fn] 的执行，失败时按指数退避 + 抖动重试
///
/// [label] 仅用于日志标签（方便排查是哪个调用在重试）。
/// 最终失败时抛出**最后一次**的异常（不会用 RetryableHttpException 包它）。
Future<T> withRetry<T>(
  Future<T> Function() fn, {
  RetryConfig config = const RetryConfig(),
  String label = 'retry',
}) async {
  final should = config.shouldRetry ?? RetryConfig.defaultShouldRetry;
  Object? lastError;
  for (var attempt = 1; attempt <= config.maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (e) {
      lastError = e;
      if (attempt >= config.maxAttempts || !should(e)) {
        rethrow;
      }
      final delayMs = _computeDelayMs(attempt: attempt, config: config);
      LoggerService.instance.w(
        '$label 第 $attempt 次失败 (${e.runtimeType}: $e)，'
        '${delayMs}ms 后重试',
        category: LogCategory.network,
        tags: ['retry', label],
      );
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
  }
  // 理论上 for 循环总会 return 或 rethrow，到这里是兜底
  throw lastError ?? StateError('withRetry 未执行任何 attempt');
}

int _computeDelayMs({
  required int attempt,
  required RetryConfig config,
}) {
  final raw = config.initialDelay.inMilliseconds *
      pow(config.multiplier, attempt - 1);
  final capped = raw.clamp(0, config.maxDelay.inMilliseconds).toInt();
  final jitterRange = (capped * config.jitterFactor).toInt();
  final jitter = jitterRange == 0
      ? 0
      : _rand.nextInt(2 * jitterRange) - jitterRange;
  return (capped + jitter).clamp(0, config.maxDelay.inMilliseconds).toInt();
}