/// 通用指数退避重试工具
///
/// 设计目标：
/// - 仅用于阻塞调用（[Future<T>]）；流式重试由调用方控制握手阶段后 [yield*]
/// - 默认重试所有 HTTP 错误（网络/超时/4xx/5xx）；非 HTTP 的 Dart 逻辑异常不重试
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

/// HTTP 错误统一走 [RetryableHttpException]
///
/// 所有 4xx/5xx 统一抛 [RetryableHttpException]，[RetryConfig.defaultShouldRetry]
/// 一律重试。非 HTTP 的 Dart 逻辑异常（FormatException/StateError 等）不重试。
class RetryableHttpException implements Exception {
  final int statusCode;
  final String body;
  final String url;

  /// 服务端 Retry-After 头解析后的毫秒数；null 表示服务端未提供。
  ///
  /// [withRetry] 优先使用此值（clamp 到 [RetryConfig.maxDelay]），
  /// 否则走指数退避。
  final int? retryAfterMs;

  /// [retryAfterMs] 为可选命名参数：旧式 `RetryableHttpException(503, '', '')`
  /// 三参调用仍合法且保持 const 构造。
  const RetryableHttpException(
    this.statusCode,
    this.body,
    this.url, {
    this.retryAfterMs,
  });

  @override
  String toString() => 'RetryableHttpException(status=$statusCode, url=$url'
      '${retryAfterMs != null ? ', retryAfter=${retryAfterMs}ms' : ''})';
}

/// 重试策略
class RetryConfig {
  /// 总尝试次数（含首次）。默认 8。
  ///
  /// 移动端折中：ci-code-reviewer 用 20 次硬刚，移动端用户体感差；
  /// 8 次 + 60s cap 最坏 ~123s，足够覆盖 LLM 限流恢复。
  final int maxAttempts;

  /// 首次重试前的等待。默认 500ms。
  final Duration initialDelay;

  /// 单次退避上限。默认 60s。
  final Duration maxDelay;

  /// 退避倍数。默认 2.0（500ms → 1s → 2s ...）。
  final double multiplier;

  /// 抖动比例 0..1，默认 0.25（±25%）。
  final double jitterFactor;

  /// 自定义重试判定。为 null 时用 [defaultShouldRetry]。
  final bool Function(Object error)? shouldRetry;

  const RetryConfig({
    this.maxAttempts = 8,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 60),
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
/// [onRetry] 可选回调：每次重试前触发，参数为 `(attempt, maxAttempts,
/// delayMs, error)`，可用于驱动 LLM 重试 UI 横幅等场景。默认 null，
/// 不传则完全向后兼容（旧调用点零行为变化）。回调抛出的异常会被吞掉，
/// 不影响重试主流程。
/// 最终失败时抛出**最后一次**的异常（不会用 RetryableHttpException 包它）。
Future<T> withRetry<T>(
  Future<T> Function() fn, {
  RetryConfig config = const RetryConfig(),
  String label = 'retry',
  void Function(int attempt, int maxAttempts, int delayMs, Object error)?
      onRetry,
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
      final delayMs = _computeDelayMs(
        attempt: attempt,
        config: config,
        retryAfterMs: e is RetryableHttpException ? e.retryAfterMs : null,
      );
      LoggerService.instance.w(
        '$label 第 $attempt 次失败 (${e.runtimeType}: $e)，'
        '${delayMs}ms 后重试',
        category: LogCategory.network,
        tags: ['retry', label],
      );
      // 通知调用方（用于 LLM 重试 UI 横幅等场景）；null 时不调用，
      // 完全向后兼容。回调抛错被吞掉，不影响重试主流程。
      if (onRetry != null) {
        try {
          onRetry(attempt, config.maxAttempts, delayMs, e);
        } catch (_) {
          // onRetry 异常被吞掉，不影响重试主流程
        }
      }
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
  }
  // 理论上 for 循环总会 return 或 rethrow，到这里是兜底
  throw lastError ?? StateError('withRetry 未执行任何 attempt');
}

int _computeDelayMs({
  required int attempt,
  required RetryConfig config,
  int? retryAfterMs,
}) {
  // 服务端 Retry-After 优先（权威指示）。clamp 到 maxDelay 防恶意大值。
  // 0 视为无指导意义，回退指数退避（防雷鸣群）。
  if (retryAfterMs != null && retryAfterMs > 0) {
    return retryAfterMs.clamp(0, config.maxDelay.inMilliseconds).toInt();
  }
  // 否则指数退避 + 抖动
  final raw =
      config.initialDelay.inMilliseconds * pow(config.multiplier, attempt - 1);
  final capped = raw.clamp(0, config.maxDelay.inMilliseconds).toInt();
  final jitterRange = (capped * config.jitterFactor).toInt();
  final jitter =
      jitterRange == 0 ? 0 : _rand.nextInt(2 * jitterRange) - jitterRange;
  return (capped + jitter).clamp(0, config.maxDelay.inMilliseconds).toInt();
}

/// 解析 HTTP Retry-After 头。返回毫秒数；失败返回 null。
///
/// 支持两种格式（RFC 7231 §7.1.3）：
/// - 整数秒：`Retry-After: 120` → 120000ms
/// - HTTP-date：`Retry-After: Wed, 21 Oct 2026 07:28:00 GMT` → 与 now 的差值
///
/// 解析失败/格式异常返回 null（调用方走指数退避），
/// 绝不抛异常——Retry-After 解析不能影响重试主流程。
int? parseRetryAfterMs(String? headerValue) {
  if (headerValue == null || headerValue.isEmpty) return null;
  final trimmed = headerValue.trim();
  // 整数秒
  final seconds = int.tryParse(trimmed);
  if (seconds != null) return seconds * 1000;
  // HTTP-date（dart:io HttpDate 同步解析）
  try {
    final dt = HttpDate.parse(trimmed);
    final diff = dt.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inMilliseconds;
  } catch (_) {
    return null;
  }
}

/// 判定 HTTP 状态码是否可重试（所有 4xx + 5xx）。
///
/// 自 2026-07-17 起所有 HTTP 错误统一重试：代理网关偶发 400/401、上游短暂
/// 故障等瞬态 4xx 也纳入重试，避免直接打断会话——宁可指数退避多等也尽量自愈。
///
/// - 4xx：含 400/401/403/404/408/422/429，一律重试
/// - 5xx：服务端错误，重试
///
/// 2xx/3xx 成功响应不进入此判断（调用方仅在 statusCode >= 400 时调用）。
bool isRetryableStatus(int statusCode) {
  return statusCode >= 400;
}
