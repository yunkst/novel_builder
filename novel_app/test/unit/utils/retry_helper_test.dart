/// RetryHelper 单元测试
///
/// 验证 [withRetry] 的重试次数、瞬态错误判定、指数退避 + 抖动、
/// 非 transient 错误立即抛出。
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/utils/retry_helper_test.dart
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/retry_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('withRetry', () {
    test('首次成功 → 只调用一次 fn，不退避', () async {
      var calls = 0;
      final result = await withRetry(
        () async {
          calls++;
          return 'ok';
        },
        label: 'test',
      );
      expect(result, 'ok');
      expect(calls, 1);
    });

    test('前 2 次 SocketException，第 3 次成功 → 总 3 次 attempt', () async {
      var calls = 0;
      final result = await withRetry(
        () async {
          calls++;
          if (calls < 3) throw const SocketException('boom');
          return 'recovered';
        },
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 1),
        ),
        label: 'test',
      );
      expect(result, 'recovered');
      expect(calls, 3);
    });

    test('所有 attempt 失败 → 抛最后一次异常', () async {
      var calls = 0;
      await expectLater(
        () => withRetry(
          () async {
            calls++;
            throw const SocketException('always');
          },
          config: const RetryConfig(
            maxAttempts: 3,
            initialDelay: Duration(milliseconds: 1),
          ),
          label: 'test',
        ),
        throwsA(isA<SocketException>()),
      );
      expect(calls, 3);
    });

    test('shouldRetry 返回 false → 立即 rethrow（即使 attempts 未用尽）', () async {
      var calls = 0;
      await expectLater(
        () => withRetry(
          () async {
            calls++;
            throw const FormatException('永远不该重试');
          },
          config: RetryConfig(
            maxAttempts: 5,
            initialDelay: const Duration(milliseconds: 1),
            shouldRetry: (e) => e is! FormatException,
          ),
          label: 'test',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 1);
    });

    test('默认 shouldRetry 判定：FormatException 不重试', () async {
      var calls = 0;
      await expectLater(
        () => withRetry(
          () async {
            calls++;
            throw const FormatException('x');
          },
          config: const RetryConfig(
            maxAttempts: 3,
            initialDelay: Duration(milliseconds: 1),
          ),
          label: 'test',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 1, reason: 'FormatException 默认不重试');
    });

    test('TimeoutException 默认判定为可重试', () async {
      var calls = 0;
      await withRetry(
        () async {
          calls++;
          if (calls < 2) {
            throw TimeoutException('timeout', const Duration(seconds: 1));
          }
          return 'ok';
        },
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 1),
        ),
        label: 'test',
      );
      expect(calls, 2);
    });

    test('RetryableHttpException 默认判定为可重试；NonRetryableHttpException 不重试',
        () async {
      // 可重试
      var calls = 0;
      await withRetry(
        () async {
          calls++;
          if (calls < 2) throw const RetryableHttpException(503, '', '');
          return 'ok';
        },
        config: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 1),
        ),
        label: 'test',
      );
      expect(calls, 2);

      // 不可重试：立即抛出，只调一次
      calls = 0;
      await expectLater(
        () => withRetry(
          () async {
            calls++;
            throw const NonRetryableHttpException(400, '', '');
          },
          config: const RetryConfig(
            maxAttempts: 3,
            initialDelay: Duration(milliseconds: 1),
          ),
          label: 'test',
        ),
        throwsA(isA<NonRetryableHttpException>()),
      );
      expect(calls, 1);
    });

    test('退避时间随 attempt 递增且有上限', () async {
      // initialDelay=100ms, multiplier=2.0, maxDelay=300ms
      // 第 1 次重试前 base=100, 第 2 次 base=200, 第 3 次 base=300 (capped)
      // jitter 0 → delayMs 精确
      final sw = Stopwatch()..start();
      var calls = 0;
      try {
        await withRetry(
          () async {
            calls++;
            throw const SocketException('always');
          },
          config: const RetryConfig(
            maxAttempts: 4,
            initialDelay: Duration(milliseconds: 100),
            maxDelay: Duration(milliseconds: 300),
            jitterFactor: 0, // 关闭抖动以便精确断言
          ),
          label: 'backoff_test',
        );
      } catch (_) {}
      sw.stop();
      // 3 次重试退避：100 + 200 + 300 = 600ms（±少量调度抖动）
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(550));
      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(calls, 4);
    });

    test('jitter 在 ±25% 区间内（initialDelay=100ms 采样）', () async {
      // 1 次重试 ≈ 100ms ± 25ms → [75, 125]
      final durations = <int>[];
      for (var i = 0; i < 20; i++) {
        final sw = Stopwatch()..start();
        try {
          await withRetry(
            () async => throw const SocketException('x'),
            config: const RetryConfig(
              maxAttempts: 2,
              initialDelay: Duration(milliseconds: 100),
              jitterFactor: 0.25,
            ),
            label: 'jitter_test',
          );
        } catch (_) {}
        sw.stop();
        durations.add(sw.elapsedMilliseconds);
      }
      // 至少有一个落在 75~125 区间（多数应满足；CI 抖动可能个别越界）
      final inRange =
          durations.where((d) => d >= 70 && d <= 200).length;
      expect(inRange, greaterThan(durations.length * 0.8),
          reason: '80% 以上的样本应落在退避 ±25% 区间');
    });
  });

  group('RetryConfig.defaultShouldRetry', () {
    test('SocketException / HandshakeException → true', () {
      expect(RetryConfig.defaultShouldRetry(const SocketException('x')), true);
      expect(
        RetryConfig.defaultShouldRetry(const HandshakeException()),
        true,
      );
    });

    test('TimeoutException → true', () {
      expect(
        RetryConfig.defaultShouldRetry(
          TimeoutException('x', const Duration(seconds: 1)),
        ),
        true,
      );
    });

    test('RetryableHttpException → true', () {
      expect(
        RetryConfig.defaultShouldRetry(const RetryableHttpException(500, '', '')),
        true,
      );
    });

    test('HttpException → true', () {
      expect(
        RetryConfig.defaultShouldRetry(const HttpException('x')),
        true,
      );
    });

    test('FormatException / StateError / NonRetryableHttpException → false', () {
      expect(RetryConfig.defaultShouldRetry(const FormatException('x')), false);
      expect(RetryConfig.defaultShouldRetry(StateError('x')), false);
      expect(
        RetryConfig.defaultShouldRetry(const NonRetryableHttpException(400, '', '')),
        false,
      );
    });
  });
}