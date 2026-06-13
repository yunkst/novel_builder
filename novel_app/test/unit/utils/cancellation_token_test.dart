/// CancellationToken 取消令牌单元测试
///
/// 验证取消令牌的完整生命周期：
/// - cancel / isCancelled / cancelReason
/// - register 回调注册与取消注册
/// - 重复 cancel 保护
/// - createChildToken 父子级联
/// - throwIfCancelled 异常抛出
///
/// 运行:
///   cd novel_app
///   flutter test test/unit/utils/cancellation_token_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_app/utils/cancellation_token.dart';

void main() {
  group('CancellationToken', () {
    group('初始状态', () {
      test('应未取消', () {
        final token = CancellationToken();
        expect(token.isCancelled, isFalse);
        expect(token.cancelReason, isNull);
      });
    });

    group('cancel', () {
      test('应标记为已取消', () {
        final token = CancellationToken();
        token.cancel();

        expect(token.isCancelled, isTrue);
        expect(token.cancelReason, isNull);
      });

      test('应设置取消原因', () {
        final token = CancellationToken();
        token.cancel(reason: '用户手动取消');

        expect(token.isCancelled, isTrue);
        expect(token.cancelReason, '用户手动取消');
      });

      test('应触发已注册的回调', () {
        final token = CancellationToken();
        var callbackInvoked = false;
        token.register(() {
          callbackInvoked = true;
        });

        token.cancel();

        expect(callbackInvoked, isTrue);
      });

      test('应支持多个回调', () {
        final token = CancellationToken();
        var count = 0;
        token.register(() => count++);
        token.register(() => count++);
        token.register(() => count++);

        token.cancel();

        expect(count, 3);
      });

      test('重复 cancel 不应重复执行回调', () {
        final token = CancellationToken();
        var count = 0;
        token.register(() => count++);

        token.cancel();
        token.cancel();
        token.cancel();

        expect(count, 1);
      });

      test('回调异常不应阻止其他回调', () {
        final token = CancellationToken();
        var secondCalled = false;
        token.register(() => throw Exception('回调失败'));
        token.register(() {
          secondCalled = true;
        });

        token.cancel();

        expect(secondCalled, isTrue);
      });
    });

    group('register', () {
      test('应返回取消注册函数', () {
        final token = CancellationToken();
        var count = 0;
        final unregister = token.register(() => count++);

        unregister(); // 取消注册
        token.cancel();

        expect(count, 0);
      });

      test('已取消 token 的 register 应立即执行回调', () {
        final token = CancellationToken();
        token.cancel();

        var callbackInvoked = false;
        token.register(() {
          callbackInvoked = true;
        });

        expect(callbackInvoked, isTrue);
      });

      test('已取消 token 的 register 应返回空取消注册函数', () {
        final token = CancellationToken();
        token.cancel();

        final unregister = token.register(() {});
        // 不应抛出异常
        unregister();
      });
    });

    group('createChildToken', () {
      test('应创建子令牌', () {
        final parent = CancellationToken();
        final child = parent.createChildToken();

        expect(child, isA<CancellationToken>());
        expect(child.isCancelled, isFalse);
      });

      test('父令牌取消应级联取消子令牌', () {
        final parent = CancellationToken();
        final child = parent.createChildToken();

        parent.cancel();

        expect(child.isCancelled, isTrue);
      });

      test('级联取消应传递取消原因', () {
        final parent = CancellationToken();
        final child = parent.createChildToken();

        parent.cancel(reason: '超时取消');

        expect(child.isCancelled, isTrue);
        expect(child.cancelReason, isNotNull);
      });

      test('已取消的父令牌创建子令牌应立即标记为已取消', () {
        final parent = CancellationToken();
        parent.cancel();

        final child = parent.createChildToken();
        expect(child.isCancelled, isTrue);
      });

      test('子令牌取消不应影响父令牌', () {
        final parent = CancellationToken();
        final child = parent.createChildToken();

        child.cancel();

        expect(parent.isCancelled, isFalse);
      });

      test('多子令牌应全部被级联取消', () {
        final parent = CancellationToken();
        final child1 = parent.createChildToken();
        final child2 = parent.createChildToken();
        final child3 = parent.createChildToken();

        parent.cancel();

        expect(child1.isCancelled, isTrue);
        expect(child2.isCancelled, isTrue);
        expect(child3.isCancelled, isTrue);
      });
    });

    group('throwIfCancelled', () {
      test('未取消时不应抛出异常', () {
        final token = CancellationToken();
        expect(() => token.throwIfCancelled(), returnsNormally);
      });

      test('已取消时应抛出 OperationCancelledException', () {
        final token = CancellationToken();
        token.cancel(reason: '测试取消');

        expect(() => token.throwIfCancelled(),
            throwsA(isA<OperationCancelledException>()));
      });
    });

    group('OperationCancelledException', () {
      test('应包含消息和时间戳', () {
        final exception = OperationCancelledException('操作被取消');
        expect(exception.message, '操作被取消');
        expect(exception.cancelledAt, isA<DateTime>());
      });

      test('toString 应包含消息', () {
        final exception = OperationCancelledException('超时');
        expect(exception.toString(), contains('超时'));
        expect(exception.toString(), contains('OperationCancelledException'));
      });
    });
  });
}
