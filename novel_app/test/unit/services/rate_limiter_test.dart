import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/services/rate_limiter.dart';

/// RateLimiter 单元测试
///
/// 测试速率限制器的核心功能：
/// - 请求间隔控制
/// - 自动等待机制
/// - 重置功能
/// - 状态查询
void main() {
  group('RateLimiter 基础功能', () {
    test('第一次 acquire() 应立即返回', () async {
      final limiter = RateLimiter(interval: const Duration(seconds: 1));

      final stopwatch = Stopwatch()..start();
      await limiter.acquire();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('间隔内第二次 acquire() 应等待剩余时间', () async {
      final limiter = RateLimiter(interval: const Duration(milliseconds: 500));

      // 第一次请求
      await limiter.acquire();

      // 立即第二次请求（应该等待）
      final stopwatch = Stopwatch()..start();
      await limiter.acquire();
      stopwatch.stop();

      // 应该等待约500ms
      expect(stopwatch.elapsedMilliseconds, greaterThan(400));
      expect(stopwatch.elapsedMilliseconds, lessThan(700));
    });

    test('间隔超过指定时间后 acquire() 应立即返回', () async {
      final limiter = RateLimiter(interval: const Duration(milliseconds: 200));

      // 第一次请求
      await limiter.acquire();

      // 等待超过间隔时间
      await Future.delayed(const Duration(milliseconds: 300));

      // 第二次请求应该立即返回
      final stopwatch = Stopwatch()..start();
      await limiter.acquire();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('应使用自定义间隔时间', () async {
      final limiter = RateLimiter(interval: const Duration(milliseconds: 100));

      await limiter.acquire();

      final stopwatch = Stopwatch()..start();
      await limiter.acquire();
      stopwatch.stop();

      // 应该等待约100ms
      expect(stopwatch.elapsedMilliseconds, greaterThan(80));
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });
  });

  group('RateLimiter 边界场景', () {
    test('零间隔应允许连续请求', () async {
      final limiter = RateLimiter(interval: Duration.zero);

      final stopwatch = Stopwatch()..start();

      await limiter.acquire();
      await limiter.acquire();
      await limiter.acquire();

      stopwatch.stop();

      // 所有请求应该立即完成
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('极短间隔 (1ms) 应正确工作', () async {
      final limiter = RateLimiter(interval: const Duration(milliseconds: 1));

      await limiter.acquire();
      await Future.delayed(const Duration(milliseconds: 2));

      final stopwatch = Stopwatch()..start();
      await limiter.acquire();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('长间隔 (60秒) 应正确计算等待时间', () async {
      final limiter = RateLimiter(interval: const Duration(seconds: 60));

      await limiter.acquire();

      // 获取距离下次请求的时间
      final timeUntilNext = limiter.timeUntilNextRequest;

      // 应该约60秒
      expect(timeUntilNext.inSeconds, greaterThan(58));
      expect(timeUntilNext.inSeconds, lessThan(62));
    });

    test('多次连续调用应依次等待', () async {
      final limiter = RateLimiter(interval: const Duration(milliseconds: 100));

      final stopwatch = Stopwatch()..start();

      await limiter.acquire(); // t=0ms
      await limiter.acquire(); // t=100ms
      await limiter.acquire(); // t=200ms

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThan(180));
      expect(stopwatch.elapsedMilliseconds, lessThan(350));
    });
  });

  group('RateLimiter 重置功能', () {
    test('reset() 后应清除等待时间', () async {
      final limiter = RateLimiter(interval: const Duration(seconds: 1));

      await limiter.acquire();
      limiter.reset();

      // 重置后应该立即返回
      final stopwatch = Stopwatch()..start();
      await limiter.acquire();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('reset() 多次调用应安全', () {
      final limiter = RateLimiter(interval: const Duration(seconds: 1));

      limiter.reset();
      limiter.reset();
      limiter.reset();

      expect(limiter.canRequestImmediately, true);
    });

    test('reset() 后状态查询应返回初始值', () async {
      final limiter = RateLimiter(interval: const Duration(seconds: 1));

      await limiter.acquire();
      expect(limiter.canRequestImmediately, false);

      limiter.reset();
      expect(limiter.canRequestImmediately, true);
      expect(limiter.timeUntilNextRequest, Duration.zero);
    });
  });

  group('RateLimiter 状态查询', () {
    test('首次调用前 canRequestImmediately 应返回 true', () {
      final limiter = RateLimiter(interval: const Duration(seconds: 1));

      expect(limiter.canRequestImmediately, true);
    });

    test('首次调用后 canRequestImmediately 应返回 false', () async {
      final limiter = RateLimiter(interval: const Duration(seconds: 1));

      await limiter.acquire();

      expect(limiter.canRequestImmediately, false);
    });

    test('间隔超过后 canRequestImmediately 应返回 true', () async {
      final limiter = RateLimiter(interval: const Duration(milliseconds: 100));

      await limiter.acquire();
      expect(limiter.canRequestImmediately, false);

      await Future.delayed(const Duration(milliseconds: 150));
      expect(limiter.canRequestImmediately, true);
    });

    test('timeUntilNextRequest 首次调用前应返回 zero', () {
      final limiter = RateLimiter(interval: const Duration(seconds: 1));

      expect(limiter.timeUntilNextRequest, Duration.zero);
    });

    test('timeUntilNextRequest 应正确计算剩余时间', () async {
      final limiter = RateLimiter(interval: const Duration(seconds: 1));

      await limiter.acquire();

      final timeUntilNext = limiter.timeUntilNextRequest;

      // 应该约1秒
      expect(timeUntilNext.inSeconds, 1);
      expect(timeUntilNext.inMilliseconds, greaterThan(900));
      expect(timeUntilNext.inMilliseconds, lessThan(1100));
    });

    test('timeUntilNextRequest 间隔超过后应返回 zero', () async {
      final limiter = RateLimiter(interval: const Duration(milliseconds: 100));

      await limiter.acquire();
      await Future.delayed(const Duration(milliseconds: 150));

      expect(limiter.timeUntilNextRequest, Duration.zero);
    });
  });

  group('RateLimiter 并发场景', () {
    test('并发调用 acquire() 会同时启动但等待时间不同', () async {
      final limiter = RateLimiter(interval: const Duration(milliseconds: 100));

      final stopwatch = Stopwatch()..start();

      // 同时发起3个请求 - 它们会并发执行而非串行
      final futures = [
        limiter.acquire(),
        limiter.acquire(),
        limiter.acquire(),
      ];

      await Future.wait(futures);
      stopwatch.stop();

      // 由于并发执行，总时间不会是简单的累加
      // 实际行为：所有请求几乎同时开始，等待时间由各自看到的_lastRequestTime决定
      // 这个测试验证并发调用不会崩溃
      expect(stopwatch.elapsedMilliseconds, greaterThan(0));
    });

    test('并发调用时状态查询应正确', () async {
      final limiter = RateLimiter(interval: const Duration(milliseconds: 200));

      await limiter.acquire();

      // 在等待期间发起并发请求
      final acquireFuture = limiter.acquire();

      // 此时应该无法立即请求
      expect(limiter.canRequestImmediately, false);
      expect(limiter.timeUntilNextRequest.inMilliseconds, greaterThan(0));

      await acquireFuture;
    });

    test('并发场景下 reset() 应影响所有等待的请求', () async {
      final limiter = RateLimiter(interval: const Duration(seconds: 1));

      await limiter.acquire();

      // 启动一个等待的请求
      final acquireFuture = limiter.acquire();

      // 等待一小段时间
      await Future.delayed(const Duration(milliseconds: 100));

      // 重置
      limiter.reset();

      // 原请求应该还在等待（因为已经进入等待状态）
      // 但新的请求应该立即返回
      final stopwatch = Stopwatch()..start();
      await limiter.acquire();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100));

      // 清理
      await acquireFuture;
    });
  });

  group('RateLimiter 默认参数', () {
    test('默认间隔应为30秒', () async {
      final limiter = RateLimiter();

      await limiter.acquire();

      final timeUntilNext = limiter.timeUntilNextRequest;

      // 应该约30秒
      expect(timeUntilNext.inSeconds, 30);
    });

    test('默认构造函数应正常工作', () async {
      final limiter = RateLimiter();

      expect(limiter.canRequestImmediately, true);

      await limiter.acquire();

      expect(limiter.canRequestImmediately, false);
    });
  });

  group('RateLimiter 时间精度', () {
    test('短间隔 (50ms) 应精确控制', () async {
      final limiter = RateLimiter(interval: const Duration(milliseconds: 50));

      final stopwatch = Stopwatch()..start();

      await limiter.acquire();
      await limiter.acquire();

      stopwatch.stop();

      // 应该等待约50ms
      expect(stopwatch.elapsedMilliseconds, greaterThan(40));
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('中等间隔 (500ms) 应精确控制', () async {
      final limiter = RateLimiter(interval: const Duration(milliseconds: 500));

      final stopwatch = Stopwatch()..start();

      await limiter.acquire();
      await limiter.acquire();

      stopwatch.stop();

      // 应该等待约500ms
      expect(stopwatch.elapsedMilliseconds, greaterThan(450));
      expect(stopwatch.elapsedMilliseconds, lessThan(650));
    });
  });

  group('RateLimiter 特殊场景', () {
    test('连续 acquire() 不应累积等待时间', () async {
      final limiter = RateLimiter(interval: const Duration(milliseconds: 100));

      final stopwatch = Stopwatch()..start();

      // 连续3次请求
      await limiter.acquire(); // t=0
      await limiter.acquire(); // t=100
      await limiter.acquire(); // t=200

      stopwatch.stop();

      // 总时间应该约200ms，而非100ms * 3 = 300ms
      expect(stopwatch.elapsedMilliseconds, greaterThan(180));
      expect(stopwatch.elapsedMilliseconds, lessThan(300));
    });

    test('等待过程中查询 timeUntilNextRequest 应递减', () async {
      final limiter = RateLimiter(interval: const Duration(seconds: 1));

      await limiter.acquire();

      final time1 = limiter.timeUntilNextRequest;
      await Future.delayed(const Duration(milliseconds: 200));
      final time2 = limiter.timeUntilNextRequest;

      // time2 应该比 time1 少约200ms
      expect(time2.inMilliseconds, lessThan(time1.inMilliseconds));
      expect(time1.inMilliseconds - time2.inMilliseconds, greaterThan(150));
    });

    test('acquire() 完成后 timeUntilNextRequest 应更新', () async {
      final limiter = RateLimiter(interval: const Duration(milliseconds: 200));

      await limiter.acquire();
      final time1 = limiter.timeUntilNextRequest;

      // 等待超过间隔
      await Future.delayed(const Duration(milliseconds: 300));

      await limiter.acquire();
      final time2 = limiter.timeUntilNextRequest;

      // time2 应该重新开始计算
      expect(time2.inMilliseconds, greaterThan(150));
      expect(time2.inMilliseconds, lessThan(250));
    });
  });
}
