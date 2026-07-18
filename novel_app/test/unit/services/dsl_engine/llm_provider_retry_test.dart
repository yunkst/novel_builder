/// IoLlmHttpClient 重试与 RetrySignals 接线测试
///
/// 注意:IoLlmHttpClient._httpClient 是私有 dart:io HttpClient 字段,
/// 无法直接注入替身。本测试聚焦 withRetry + onRetry 的连接逻辑
/// (onRetry → RetrySignals.reportTransport 的桥接),IoLlmHttpClient 内部
/// 实际接线由 analyze(编译期保证 onRetry lambda 类型正确)+ 后续集成/
/// 手动验收覆盖(spec DoD 已注明)。
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/services/dsl_engine/llm_provider_retry_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/dsl_engine/retry_signals.dart';
import 'package:novel_app/utils/retry_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LLM Provider 传输层重试 → RetrySignals', () {
    setUp(() => RetrySignals.instance.resetForTest());

    test('withRetry onRetry → RetrySignals.reportTransport 写入 transport state',
        () async {
      bool called = false;
      await withRetry(
        () async {
          if (!called) {
            called = true;
            throw const RetryableHttpException(503, '', '');
          }
          return 'ok';
        },
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 1),
        ),
        onRetry: (a, m, d, e) {
          RetrySignals.instance.reportTransport(
            attempt: a,
            maxAttempts: m,
            delayMs: d,
            error: e,
          );
        },
      );
      // 重试 1 次后成功,state 残留(因为没 clear)
      expect(RetrySignals.instance.notifier.value, isNotNull);
      expect(RetrySignals.instance.notifier.value!.attempt, 1);

      // 模拟 postJson 成功的 clear 行为
      RetrySignals.instance.clear();
      expect(RetrySignals.instance.notifier.value, isNull);
    });

    test('categorizeRetryError 经 onRetry 透传到 RetryState.errorCategory',
        () async {
      try {
        await withRetry(
          () async => throw const RetryableHttpException(429, 'body', ''),
          config: const RetryConfig(
            maxAttempts: 2,
            initialDelay: Duration(milliseconds: 1),
          ),
          onRetry: (a, m, d, e) {
            RetrySignals.instance.reportTransport(
              attempt: a,
              maxAttempts: m,
              delayMs: d,
              error: e,
            );
          },
        );
      } catch (_) {
        // 预期:2 次都失败,withRetry 最终 rethrow
      }

      final v = RetrySignals.instance.notifier.value!;
      expect(v.errorCategory, '限流');
      expect(v.maxAttempts, 2);
    });
  });
}
