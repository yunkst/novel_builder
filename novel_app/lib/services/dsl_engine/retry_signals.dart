/// LLM 重试 UI 信号总线
///
/// 模块级单例 `RetrySignals` 持有 `ValueNotifier<RetryState?>`,供 UI
/// (RetryBanner) 通过 `ValueListenableBuilder` 订阅。
///
/// 信号来源:
/// - 传输层:IoLlmHttpClient.postJson/postJsonStream 通过 withRetry 的
///   onRetry 回调报告 transportRetry → reportTransport
/// - 回合层:agent_loop.dart 的 round-level catch 块直接调 reportRound
///   (不走事件流,绕开 shouldMainSessionHandleEvent 过滤 — spec §3.1.1 方案 B)
///
/// 多 session 串号限制:模块级单例同时只能显示一个 active retry,本次接受(YAGNI)。
/// factory reset:test 用 resetForTest() 复位 ValueNotifier。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:novel_app/utils/retry_helper.dart';

/// 重试层级
enum RetryLevel { transport, round }

/// 当前活跃的重试状态
@immutable
class RetryState {
  final RetryLevel level;
  final int attempt;
  final int maxAttempts;
  final int delayMs;
  final String errorCategory;
  final DateTime receivedAt;

  const RetryState({
    required this.level,
    required this.attempt,
    required this.maxAttempts,
    required this.delayMs,
    required this.errorCategory,
    required this.receivedAt,
  });
}

/// 模块级重试信号单例
class RetrySignals {
  static final RetrySignals instance = RetrySignals._();
  RetrySignals._();

  /// UI 端通过 ValueListenableBuilder 订阅;null = 无活跃重试,横幅不渲染
  ValueNotifier<RetryState?> notifier = ValueNotifier<RetryState?>(null);

  /// 传输层 withRetry 报告一次重试(覆盖式写入最新)
  void reportTransport({
    required int attempt,
    required int maxAttempts,
    required int delayMs,
    required Object error,
  }) {
    notifier.value = RetryState(
      level: RetryLevel.transport,
      attempt: attempt,
      maxAttempts: maxAttempts,
      delayMs: delayMs,
      errorCategory: categorizeRetryError(error),
      receivedAt: DateTime.now(),
    );
  }

  /// 回合层 agent_loop 报告一次重试
  void reportRound({
    required int attempt,
    required int maxAttempts,
    required int delayMs,
    required Object error,
  }) {
    notifier.value = RetryState(
      level: RetryLevel.round,
      attempt: attempt,
      maxAttempts: maxAttempts,
      delayMs: delayMs,
      errorCategory: categorizeRetryError(error),
      receivedAt: DateTime.now(),
    );
  }

  /// 重试结束(success / final failure / agent done):清空让横幅消失
  void clear() {
    notifier.value = null;
  }

  /// 测试用复位(重建 ValueNotifier);release 代码不应调用
  @visibleForTesting
  void resetForTest() {
    notifier.dispose();
    notifier = ValueNotifier<RetryState?>(null);
  }
}

/// 共享错误分类工具 — 传输层与回合层共用,避免映射逻辑重复
///
/// 429 → 限流
/// 408 → 请求超时
/// 4xx 其他 → 请求错误 {code}
/// 5xx → 服务端 {code}
/// Socket/HandshakeException → 网络断开
/// TimeoutException → 响应超时
/// 其它 → 重试中
String categorizeRetryError(Object error) {
  if (error is RetryableHttpException) {
    final code = error.statusCode;
    if (code == 429) return '限流';
    if (code == 408) return '请求超时';
    if (code >= 500) return '服务端 $code';
    return '请求错误 $code';
  }
  if (error is SocketException || error is HandshakeException) {
    return '网络断开';
  }
  if (error is TimeoutException) return '响应超时';
  return '重试中';
}
